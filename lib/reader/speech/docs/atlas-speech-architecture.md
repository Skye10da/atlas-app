# ATLAS Speech Architecture (ASA)
> Version: 1.2 — Implementation-ready
> Status: Approved for implementation
> Changelog: v1.2 adds a `SpeechSession` to unify queue/checkpoint/settings
> state, wraps the raw queue in a `SpeechQueue`, makes driver state explicit
> instead of callback-implicit, structures the voice cache as
> `VoiceDescriptor`s, adds an Error Recovery path, and freezes the folder
> structure. No architectural changes from v1.1 — this pass is entirely
> implementation-simplifying, not new abstraction.

---

# 1. The Speech Pipeline

Unchanged from v1.1 — this remains the canonical mental model:

```
Reader → Paragraph Provider → Sentence Splitter → Speech Queue
  → Speech Engine → Speech Driver → Progress Tracker → Reader Sync
                                   → Playback Controller → audio_service
```

---

# 2. Speech Session

Queue, checkpoint, and settings were three separately-managed things in
v1.1. In practice they're one unit of state — "what is currently being
narrated, from where, and how" — so v1.2 unifies them into a single object
that both the recovery store and the engine operate on:

```dart
class SpeechSession {
  SpeechSession({
    required this.bookId,
    required this.chapterId,
    required this.queue,
    required this.currentIndex,
    required this.settings,
    this.elapsed = Duration.zero,
  });

  final String bookId;
  final String chapterId;
  final SpeechQueue queue;
  int currentIndex;
  final NarrationSettings settings;
  Duration elapsed;

  SpeechItem? get currentItem => queue.itemAt(currentIndex);

  /// The minimal serializable shape persisted by the Recovery Store —
  /// re-deriving the full queue from chapterId+bookId on restore rather
  /// than persisting SpeechItem text verbatim.
  SpeechCheckpoint toCheckpoint() => SpeechCheckpoint(
        bookId: bookId,
        chapterId: chapterId,
        sentenceIndex: currentIndex,
        elapsed: elapsed,
      );
}

class SpeechCheckpoint {
  const SpeechCheckpoint({
    required this.bookId,
    required this.chapterId,
    required this.sentenceIndex,
    required this.elapsed,
  });
  final String bookId;
  final String chapterId;
  final int sentenceIndex;
  final Duration elapsed;
}
```

`SpeechEngine` now holds one `SpeechSession?` instead of separate queue/
index/settings fields — this is what makes §8's "Restore Queue" startup
step a single, explicit operation instead of three.

---

# 3. Speech Queue

Wraps `List<SpeechItem>` so queue navigation logic lives in one place
instead of being reimplemented (or subtly diverging) wherever the engine
touches `_index`:

```dart
class SpeechQueue {
  SpeechQueue(this._items);

  final List<SpeechItem> _items;
  int _cursor = 0;

  SpeechItem? get current => itemAt(_cursor);
  SpeechItem? itemAt(int i) => (i >= 0 && i < _items.length) ? _items[i] : null;
  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;
  int get cursor => _cursor;

  SpeechItem? next() {
    if (_cursor + 1 >= _items.length) return null;
    return itemAt(++_cursor);
  }

  SpeechItem? previous() {
    if (_cursor - 1 < 0) return null;
    return itemAt(--_cursor);
  }

  SpeechItem? peekNext() => itemAt(_cursor + 1);

  List<SpeechItem> remaining() => _items.sublist(_cursor);

  void reset() => _cursor = 0;

  void seekTo(int index) {
    if (index >= 0 && index < _items.length) _cursor = index;
  }
}
```

`SpeechEngine` calls `session.queue.next()`/`.current` instead of indexing
a raw list directly — this is the change that keeps queue logic from
scattering across the engine as more call sites are added later.

---

# 4. Speech Driver

Interface unchanged from v1.1 in spirit, now with explicit state instead of
relying solely on callback timing to infer it:

```dart
enum DriverState { ready, speaking, paused, stopped, error }

abstract class SpeechDriver {
  Stream<SpeechDriverEvent> get events;
  DriverState get state;
  Stream<DriverState> get stateStream;

  Future<void> configure({required double rate, required double pitch, String? voiceId});
  Future<void> speak(SpeechItem item);
  Future<void> pause();
  Future<void> resume(SpeechItem item);
  Future<void> stop();
  Future<List<VoiceDescriptor>> listVoices();
}
```

Explicit state matters for the same reason §5's structured `SpeechSession`
does: "infer current state from the last callback received" is exactly the
kind of implicit logic that's hard to debug when something goes wrong
mid-session — an explicit `state`/`stateStream` gives both the engine and
any future debug/logging tooling a direct source of truth instead of
reconstructing it.

---

# 5. Voice Descriptor

Replaces v1.1's plain voice-ID caching with a structured object, so the
narration settings UI can group/filter/label voices properly instead of
showing a bare list of opaque IDs:

```dart
class VoiceDescriptor {
  const VoiceDescriptor({
    required this.id,
    required this.language,
    required this.locale,
    this.gender,
    this.quality,
  });

  final String id;
  final String language;   // e.g. 'en'
  final String locale;     // e.g. 'en-AU'
  final String? gender;    // platform-reported where available
  final String? quality;   // platform-reported where available
}
```

The Voice Cache (§9, unchanged pipeline from v1.1) now stores
`List<VoiceDescriptor>` rather than raw platform maps.

---

# 6. Speech Events

Unchanged from v1.1 (§5 of that version) — `SpeechStarted`,
`SentenceStarted`, `SentenceFinished`, `ParagraphFinished`,
`ChapterFinished`, `SpeechPaused`, `SpeechStopped`, `SpeechCompleted`,
`SpeechError`, `WordBoundary`. Reader listens only to this stream.

---

# 7. Reader ↔ Speech Ownership

Unchanged from v1.1 — Speech emits `ChapterFinished` and stops; Reader
decides whether to load the next chapter. This remains the fix for the
original v1.0 hidden-side-effect issue.

---

# 8. Startup Sequence

Refined from v1.1 to make queue reconstruction an explicit step rather
than folding it into "restore checkpoint":

```
App Start
  ↓
Initialize audio_service
  ↓
Initialize Speech Driver
  ↓
Validate Driver          — confirm the configured voice/language is still
  ↓                        installed/available; fall back to platform
  ↓                        default and surface a one-time notice if not
Restore Session           — read the last SpeechCheckpoint, if any
  ↓
Restore Queue             — re-derive the SpeechQueue for
  ↓                         checkpoint.chapterId from the current
  ↓                         AtlasDocument, seek to checkpoint.sentenceIndex
Reader decides             — resume automatically, or wait for an explicit
  ↓                         "resume narration" tap (see v1.1 §12 rationale)
Ready
```

"Validate Driver" is new: a voice that was available when the checkpoint
was saved may not be installed on this device/session (a user cleared TTS
language data, or restored to a different device) — checking this before
attempting to restore avoids a confusing silent failure or wrong-voice
narration on resume.

---

# 9. Voice Cache

Pipeline unchanged from v1.1; storage type updated per §5:

```
App Start → driver.listVoices() → List<VoiceDescriptor>
  → cache in memory + persist to disk → Settings screen reads from cache
```

---

# 10. Recovery Checkpoints

Pipeline unchanged from v1.1 (debounced flush: every 5 sentences or 10
seconds, whichever first) — now operating on `SpeechSession.toCheckpoint()`
(§2) rather than three separately-tracked values.

---

# 11. Sleep Timer

Unchanged from v1.1 — duration × boundary (immediate/sentence/paragraph/
chapter), implemented as a `_stopAtBoundary` flag the engine checks in its
`SentenceFinished`/`ParagraphFinished`/`ChapterFinished` handling.

---

# 12. Error Recovery

New in v1.2. A single transient driver failure (a platform TTS engine
hiccup, a momentary crash-and-restart on some OEM Android builds) shouldn't
end the whole session:

```
SpeechError from driver
  ↓
Retry the current SpeechItem once, same driver instance
  ↓
Still failing → restart the driver (re-initialize FlutterTtsDriver)
  ↓
Restore the current SpeechItem from the SpeechSession, resume from there
  ↓
Still failing after restart → give up: emit SpeechError to the Reader,
  stop cleanly, leave the last good SpeechCheckpoint in place so the user
  can manually resume rather than losing their place
```

This lives inside `SpeechEngine`, not the driver itself — the driver only
ever reports `DriverState.error`/`SpeechError`; retry-and-restart policy is
engine-level so it stays consistent across whichever driver is active
(§13 of v1.1).

---

# 13. Folder Structure (frozen)

```
lib/reader/speech/
  speech_engine.dart
  speech_driver.dart
  speech_session.dart
  speech_queue.dart
  playback_controller.dart
  speech_events.dart
  speech_models.dart          # SpeechItem, VoiceDescriptor
  drivers/
    flutter_tts_driver.dart
  parser/
    sentence_splitter.dart
  persistence/
    recovery_store.dart
  settings/
    narration_settings.dart
```

Nested under `lib/reader/` rather than promoted to a top-level `lib/speech/`
— the subsystem is driver-agnostic internally, but its only consumer today
is the Reader, and nothing here requires it to be reachable from outside
that feature. Worth revisiting only if a second consumer actually shows up
(e.g. a standalone audiobook-import feature that has no chapter/reader
context at all) — same "wait for evidence" principle as everywhere else in
Atlas's architecture docs, not a decision to preempt now.
