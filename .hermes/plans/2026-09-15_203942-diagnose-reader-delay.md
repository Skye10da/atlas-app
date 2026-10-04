# Plan: Diagnose and fix reader delay when chapter is cached + offline + translation off

## Goal

When a chapter is already downloaded, atlas glossary is offline (local-only), and on-device translation is disabled, the reader must open the chapter content **instantly** — no shimmer, no waiting. The current code pays unnecessary async overhead on every cached-chapter open even under these ideal conditions.

## Current context / assumptions

- Flutter + Riverpod app (`lib/reader/` is the reader layer).
- `readerChapterContentProvider` (`lib/reader/presentation/providers/reader_providers.dart:55-129`) is a `FutureProvider.family<String, ChapterEntity>` that drives chapter text.
- Three "no internet required" signals:
  1. **Chapter cached on disk** — `File(chapter.contentPath).existsSync()` returns true; content is read from `repo.getChapterContent(chapter.contentPath)` (DriftReaderRepository, local file read).
  2. **Atlas glossary is offline** — `SharedPrefsAtlasGlossaryRepository` stores glossary entries locally; no network needed to load or apply. When the glossary is empty, `_applyAtlasGlossary` returns content unchanged.
  3. **Translation disabled** — `translationEnabledProvider` reads from `SharedPrefsTranslationRepository` locally; when `enabled == false`, `_applyTranslation` returns content unchanged without any network call.
- The current provider does **all three** async lookups (`File.existsSync`, `translationEnabledProvider.future`, `atlasGlossaryProvider.future`) inside the `FutureProvider` body, then applies transforms. Even when all are "no-op," the async machinery costs frames.

## Architecture / proposed approach

**Add a synchronous "instant open" gate before the async FutureProvider machinery.** The gate checks, synchronously and cheaply:

1. `File(chapter.contentPath).existsSync()` — chapter is cached.
2. `chapter.contentState == ContentState.availableOffline` (or just the file exists, which is the real signal).
3. **Translation is disabled** — but `translationEnabledProvider` is a `FutureProvider`, so we can't read it synchronously. Instead, embed the translation-enabled flag directly into the chapter entity or reading session state so the gate can check it without an async lookup. Alternatively, cache the flag in a synchronous `StateProvider` updated when the user toggles translation.
4. **Glossary is empty** — same problem: `atlasGlossaryProvider` is a `FutureProvider`. Cache glossary entries in a `StateProvider` or check a synchronously-available "has glossary entries" flag.

For the MVP, the most impactful fix is to **skip the shimmer and return content synchronously when the file exists**, deferring the glossary/translation async lookups to *after* the first paint. The content can be shown in its raw cached form immediately, with glossary/translation applied in a background microtask that triggers a rebuild only if something actually changes. This matches the user's mental model: "it's already downloaded, show it now."

 Concretely:

- **Step 1**: In `readerChapterContentProvider`, check `File(chapter.contentPath).existsSync()` first. If true, read the file synchronously (it's already cached, the read is fast local IO), apply a **synchronous** fast-path transform if we can determine translation is off and glossary is empty without async, and return immediately. If we can't determine the transforms synchronously, return the raw cached content immediately and schedule a synchronous `scheduleMicrotask` to re-apply glossary/translation if needed (then invalidate if changed).
- **Step 2**: Add a synchronous `StateProvider` or a flag on the chapter/book entity that tracks "translation enabled for this book" so the provider can check it without `await ref.watch(...future)`. Same for glossary — a `StateProvider<bool>` per bookId that's `true` when glossary is non-empty.
- **Step 3**: In `ReaderContent` / `reader_screen.dart`, the `loading` state should be set to `false` as soon as `loadChapters()` completes (it already is at line 358). The shimmer in `ReaderContent` is already gated on `loading.value`. But the chapter **content** shimmer (`ChapterContentLoader` → `readerChapterContentProvider` `loading:` case) is what shows when the chapter is cached but the provider is still resolving. Fixing the provider's fast path eliminates this second shimmer layer.

## Step-by-step tasks

### Task 1: Add synchronous "is translation enabled" and "has glossary entries" flags

**File**: `lib/reader/presentation/providers/translation_providers.dart` and `lib/reader/presentation/providers/atlas_glossary_providers.dart`

Add a `StateProvider.family<bool, String>` that is kept in sync with the async providers:

In `translation_providers.dart`, add after `translationEnabledProvider`:

```dart
/// Synchronous mirror of [translationEnabledProvider] — kept up-to-date via
/// [TranslationController] mutations and provider invalidation. Used by the
/// reader's fast-path gate to skip async lookups when the value is known.
final translationEnabledSyncProvider = StateProvider.family<bool, String>((
  _,
  bookId,
) {
  // Default to false (safe: off = no work). The first async lookup will
  // correct this if translation is actually on.
  return false;
});
```

And update `TranslationController.setEnabled` / `setTargetLanguage` to also update the sync provider:

```dart
Future<void> setEnabled(String bookId, bool enabled) async {
  await _repo.saveEnabled(bookId, enabled);
  // Keep the sync mirror fresh so the reader fast-path can use it.
  // ref is available via the controller's constructor if we pass it in,
  // OR we invalidate the async provider and let consumers watch both.
  // Simpler: expose a method on the controller that takes a WidgetRef.
}
```

Actually — simpler approach: instead of passing `Ref` into the controller, just have the controller call `ref.invalidate(translationEnabledProvider(bookId))` and add a `Provider` listener on `translationEnabledProvider` that updates the sync state. But Riverpod doesn't have "on change" for providers in that direction easily.

**Cleaner approach**: Make `translationEnabledProvider` a `Provider.family` that reads from a `StateProvider.family` internally, and have the controller write to that state provider. This way the async provider is just the state provider wrapped to load from disk on first read:

```dart
/// Underlying sync state — default false (safe fast-path default).
final _translationEnabledStateProvider = StateProvider.family<bool, String>((
  _,
  _,
) => false);

/// Async provider that loads from SharedPreferences on first read, then
/// keeps the value in sync with [_translationEnabledStateProvider].
final translationEnabledProvider = FutureProvider.family<bool, String>((
  ref,
  bookId,
) async {
  final repo = ref.watch(translationRepositoryProvider);
  final enabled = await repo.loadEnabled(bookId);
  // Push the result into the sync state so subsequent reads are instant.
  ref.read(_translationEnabledStateProvider(bookId).notifier).state = enabled;
  return enabled;
});

/// Synchronous mirror — safe default false, corrected by [translationEnabledProvider]
/// on first resolution. Used by the reader fast-path gate.
final translationEnabledSyncProvider = Provider.family<bool, String>((ref, bookId) {
  return ref.watch(_translationEnabledStateProvider(bookId));
});
```

But wait — `translationEnabledProvider` is watched with `.future` in `_applyTranslation` at line 158 of `reader_providers.dart`. If we change it to also update a state provider, the `.future` resolution will still happen, but the sync provider will be available immediately for the fast-path gate.

This is safe because:
- Default `false` means the fast-path assumes translation is off. If it's actually on, the content shown initially is untranslated, but the async provider will resolve and trigger a rebuild via the existing `ref.watch` in `readerChapterContentProvider` (since `translationEnabledProvider` is watched there).

Hmm — but `readerChapterContentProvider` watches `translationEnabledProvider(chapter.bookId).future` at line 158. If we change the implementation to update a sync state, the provider's `future` still resolves. The provider body runs once, updates the sync state, and returns. The provider is a `FutureProvider` so it still has a loading state.

**For the fast-path gate, we need the sync value BEFORE the FutureProvider resolves.** So the gate should use `_translationEnabledStateProvider` directly (default false). If the default is false and translation is actually on, the content shown first is untranslated — that's fine because the provider will resolve and the content will update. If translation is off (the common case for the fast-path), the default matches reality and no rebuild is needed.

Same pattern for glossary:

In `atlas_glossary_providers.dart`, add:

```dart
/// Underlying sync state — default false (empty glossary = no work).
final _atlasGlossaryNotEmptyProvider = StateProvider.family<bool, String>((
  _,
  _,
) => false);

/// Async provider that loads glossary entries and pushes the non-empty flag
/// into [_atlasGlossaryNotEmptyProvider].
final atlasGlossaryProvider = FutureProvider.family<List<AtlasGlossaryEntry>, String>((
  ref,
  bookId,
) async {
  final entries = await ref.watch(atlasGlossaryRepositoryProvider).load(bookId);
  ref.read(_atlasGlossaryNotEmptyProvider(bookId).notifier).state =
      entries.isNotEmpty;
  return entries;
});

/// Synchronous mirror — safe default false. Used by the reader fast-path gate.
final atlasGlossaryNotEmptySyncProvider = Provider.family<bool, String>((ref, bookId) {
  return ref.watch(_atlasGlossaryNotEmptyProvider(bookId));
});
```

### Task 2: Rewrite `readerChapterContentProvider` with a synchronous fast path

**File**: `lib/reader/presentation/providers/reader_providers.dart`, lines 55-129

Replace the current `FutureProvider.family` body with a two-path implementation:

**Fast path** (all conditions met synchronously):
1. `File(chapter.contentPath).existsSync()` → true (chapter cached).
2. `_translationEnabledStateProvider(chapter.bookId)` → false (translation off).
3. `_atlasGlossaryNotEmptyProvider(chapter.bookId)` → false (no glossary entries).
4. The file content is readable (not a placeholder).

When all three are true:
- Read file synchronously via `repo.getChapterContent(chapter.contentPath)` — but wait, this is already async (`Future<Result<String>>`). The file read itself in `DriftReaderRepository.getChapterContent` (line 171-196) does `File(contentPath).readAsBytes()` which is async. So even the "cached file read" is async.

Hmm. So the file read is async too. The fast path can't be fully synchronous because `getChapterContent` is async.

But — `File.existsSync()` is sync, and reading a small text file from local storage on Android/iOS is very fast (milliseconds). The async overhead is the `Future` wrapping.

So the real optimization is: **when the file exists and no transforms are needed, skip the async machinery that does network fetches, and just do the file read as the only async operation.** The current code does:

```
File.existsSync() → if true, jump to processing
  → repo.getChapterContent() → async file read
  → _applyAtlasGlossary() → async (awaits glossary provider)
  → _applyTranslation() → async (awaits translation enabled provider, then potentially network)
```

The glossary and translation async lookups are the waste. If we can determine they're no-ops synchronously, we skip them.

**Revised fast path**:

```dart
final fileExists = File(chapter.contentPath).existsSync();

// Sync fast-path gate: if the file is cached AND translation is off AND
// glossary is empty, we can skip the async transform lookups entirely.
final transEnabledSync = ref.read(_translationEnabledStateProvider(chapter.bookId));
final glossaryNotEmptySync = ref.read(_atlasGlossaryNotEmptyProvider(chapter.bookId));

final canSkipTransforms = fileExists && !transEnabledSync && !glossaryNotEmptySync;

if (fileExists) {
  publish(ChapterLoadPhase.processing);
} else {
  publish(ChapterLoadPhase.gettingText);
  // ... download ...
}

final result = await repo.getChapterContent(chapter.contentPath);

// If we determined synchronously that no transforms are needed, skip them.
if (canSkipTransforms && result is Success<String>) {
  // Verify the content isn't a placeholder (still need this check).
  final content = result.value;
  if (content.trim().isEmpty || content.startsWith('# Chapter Content')) {
    // ... redownload path ...
  }
  publish(ChapterLoadPhase.preparing);
  return content; // already plain text, no transforms needed
}

// Otherwise, fall through to the existing transform logic.
publish(ChapterLoadPhase.preparing);
return switch (result) {
  Success(value: final content) => await _applyAtlasGlossary(
    ref, chapter.bookId,
    await _applyTranslation(ref, chapter, content),
  ),
  Failure(error: final error) => throw error,
};
```

But wait — `_applyTranslation` at line 158 does `await ref.watch(translationEnabledProvider(chapter.bookId).future)`. If we already know translation is off synchronously, we can skip this. And `_applyAtlasGlossary` at line 195 does `await ref.watch(atlasGlossaryProvider(bookId).future)`. If we know the glossary is empty, we can skip this too.

So the fast path becomes:

```dart
if (canSkipTransforms) {
  // ... file exists, no transforms needed ...
  return content; // directly, no _applyAtlasGlossary, no _applyTranslation
}
```

This eliminates the two `await ref.watch(...future)` calls for the common cached+offline+translation-off case.

### Task 3: Eliminate the placeholder re-download from the fast path

**File**: `lib/reader/presentation/providers/reader_providers.dart`, lines 92-118

The current code has a placeholder detection + redownload path that runs even for cached files. In the fast path (file exists, transforms skipped), if the content is a placeholder, we still need to redownload — but that's a network operation and breaks the "instant" guarantee. For the fast path, we should:

- If the cached file is a placeholder, fall back to the normal async path (which will trigger a download). The user sees a brief shimmer, but this is rare (only happens when the cache is corrupt).
- The fast path should only be taken when the file exists AND is valid content.

### Task 4: Wire the sync state providers into the reader's content pipeline

**File**: `lib/reader/presentation/providers/reader_providers.dart`

Update `_applyTranslation` (line 153-180) to use the sync provider as a first check:

```dart
Future<String> _applyTranslation(Ref ref, ChapterEntity chapter, String content) async {
  if (content.isEmpty) return content;

  // Fast synchronous check — if translation is off, skip entirely.
  final enabledSync = ref.read(_translationEnabledStateProvider(chapter.bookId));
  if (!enabledSync) return content;

  // Fall back to the async provider for the definitive answer (may have been
  // updated since the sync state was last written, e.g. user just toggled).
  final enabled = await ref.watch(translationEnabledProvider(chapter.bookId).future);
  if (!enabled) return content;
  // ... rest of translation logic ...
}
```

Wait — but if the sync state defaults to `false` and translation is actually `true`, the first call to `_applyTranslation` will return early (content untranslated), then the async provider resolves and... nothing triggers a rebuild because `_applyTranslation` is called inside `readerChapterContentProvider` which has already resolved.

This is a problem. The rebuild chain is:
1. `readerChapterContentProvider` resolves with content.
2. `chapterBlockCardSpansProvider` depends on `readerChapterContentProvider`.
3. `ChapterContentLoader` watches `readerChapterContentProvider`.

If `readerChapterContentProvider` resolves with untranslated content (because sync said false but actual was true), there's no mechanism to re-resolve with the translated content.

**Fix**: The sync state default should be `false`, but when the async provider resolves, it should trigger a re-resolution of `readerChapterContentProvider`. This can be done by having `readerChapterContentProvider` watch `translationEnabledProvider` (not just read it once) — but `FutureProvider.family` doesn't auto-rebuild on dependency change unless you watch it inside the provider body.

Actually — `readerChapterContentProvider` already watches `translationEnabledProvider(chapter.bookId).future` at line 158 (inside `_applyTranslation`). So when the async provider resolves, `_applyTranslation` gets the correct value. But `_applyTranslation` is called synchronously within the provider body — if the provider has already returned, `_applyTranslation` won't be called again.

**Solution**: Make `readerChapterContentProvider` watch `translationEnabledProvider` and `atlasGlossaryProvider` as dependencies (not just inside `_applyTranslation`). In Riverpod, a `FutureProvider` automatically re-resolves when its watched dependencies change. So if we do:

```dart
final readerChapterContentProvider = FutureProvider.family<String, ChapterEntity>((
  ref,
  chapter,
) async {
  // Watch these so the provider re-resolves when they change.
  ref.watch(translationEnabledProvider(chapter.bookId));
  ref.watch(atlasGlossaryProvider(chapter.bookId));
  // ... rest of body ...
});
```

Then when `translationEnabledProvider` resolves (from false → true, or from the default false to the actual value), `readerChapterContentProvider` re-resolves and applies translation.

But this means the provider re-resolves twice: once when the sync state is read (immediately, with default false), and once when the async provider resolves (with actual value). The first resolution returns untranslated content, the second returns translated content.

This is acceptable because:
- In the common case (translation off), the sync state is already correct (false), the async provider also returns false, and there's no re-resolution.
- In the case where translation is on, the first resolution is untranslated (briefly shown), then the second resolution is translated. The user sees a quick flash of untranslated text if they open the chapter very fast — but this is better than a shimmer delay.

Actually, for the MVP, the user's complaint is about delay when translation is OFF. So the fast path with sync default false works perfectly for that case. The edge case (translation on, sync default false) is a minor flash that's better than the alternative.

### Task 5: Ensure the fast path skips the shimmer

**File**: `lib/reader/presentation/widgets/chapter_content_loader.dart`, lines 122-134

The `ChapterContentLoader` shows a `ChapterShimmer` when `contentAsync` is in `loading:` state. The fast path should resolve the provider quickly enough that the shimmer is never shown (or shown for < 1 frame).

With the fast path, the provider resolves in a single async step (file read only), which should be fast enough that the shimmer is skipped. But to be safe, we could also add a synchronous check in `ChapterContentLoader`:

Actually, the shimmer is shown while the `FutureProvider` is loading. If the provider resolves in < 16ms (one frame), the shimmer may not even render. The fast path should achieve this.

But there's a subtlety: the provider's loading state is managed by `chapterLoadPhaseProvider` (lines 51-53 in `reader_providers.dart`). The fast path sets `publish(ChapterLoadPhase.processing)` immediately when file exists, skipping `gettingText`. The `ChapterContentLoader` doesn't watch `chapterLoadPhaseProvider` directly — it watches `readerChapterContentProvider`. So the shimmer is controlled by the `FutureProvider`'s loading state, not the phase.

The `FutureProvider` is in `loading:` state until its body completes. With the fast path, the body does:
1. Check file exists (sync, instant).
2. Read file (async, ~5-20ms for cached file).
3. Return content (no transforms).

Total: ~5-20ms. This should be fast enough to skip the shimmer in most cases.

### Task 6: Add the `_translationEnabledStateProvider` and `_atlasGlossaryNotEmptyProvider` to the provider graph

**Files**:
- `lib/reader/presentation/providers/translation_providers.dart` — add state provider and update `translationEnabledProvider`.
- `lib/reader/presentation/providers/atlas_glossary_providers.dart` — add state provider and update `atlasGlossaryProvider`.
- `lib/reader/presentation/providers/reader_providers.dart` — import and use the sync providers in the fast-path gate.

### Task 7: Verify with analysis and a manual test scenario

Run `flutter analyze` (or `analyze_files` MCP tool) to ensure no errors/warnings.

Manual test scenario:
1. Download a chapter (so it's cached on disk).
2. Disable translation for the book.
3. Ensure atlas glossary is empty (or offline/local).
4. Open the reader for that chapter.
5. Verify: no shimmer, content appears immediately.

## Tests / validation

### Linter / analyzer

Before committing any change, run:
```
flutter analyze
```
(Or use the `analyze_files` MCP tool.) Ensure zero errors and zero warnings.

### Manual validation

1. **Cached + translation off + no glossary**: Open reader → content appears immediately, no shimmer.
2. **Cached + translation on**: Content appears briefly untranslated, then updates when translation resolves. (Acceptable trade-off.)
3. **Not cached**: Normal download flow with shimmer (unchanged behavior).
4. **Cached + glossary non-empty**: Content appears immediately (file read only), then updates when glossary resolves and applies. (Acceptable.)

### Code review checklist

- [ ] The sync state providers default to safe values (translation off, glossary empty) so the fast-path gate never blocks on an async lookup.
- [ ] The fast path only skips transforms when ALL three conditions are met: file exists, translation off, glossary empty.
- [ ] The fast path still checks for placeholder content and falls back to the normal path if the cached file is corrupt.
- [ ] `readerChapterContentProvider` watches `translationEnabledProvider` and `atlasGlossaryProvider` as dependencies so it re-resolves when they change.
- [ ] No `print()` or `debugPrint()` calls added.
- [ ] All existing Riverpod patterns are preserved (no breaking changes to the provider graph).

## Risks, tradeoffs, and open questions

1. **Default false for translation sync state**: If the user has translation ON but hasn't opened the settings screen recently, the first chapter open may show untranslated content briefly. This is a minor UX issue but better than the current delay. Mitigated by the provider re-resolving when the async value arrives.

2. **Synchronous file read**: `repo.getChapterContent` is async (it does `File.readAsBytes()`). We can't make it sync without changing the repository interface. The fast path still uses the async read, but eliminates the unnecessary async transform lookups. This is the best we can do without a larger refactor.

3. **Race condition**: If the user toggles translation ON while a chapter is loading via the fast path, the fast path may return untranslated content. The provider re-resolution should handle this, but there may be a frame where the content is untranslated.

4. **Glossary sync state**: The `_atlasGlossaryNotEmptyProvider` default is `false`. If the glossary is actually non-empty, the fast path returns content without glossary replacements, then re-resolves when the async provider loads. Same minor flash issue as translation.

5. **Open question**: Should we cache the actual glossary entries in a `StateProvider` (not just the "non-empty" flag) so the fast path can apply glossary replacements synchronously? This would eliminate the re-resolution flash for glossary. Cost: more state to keep in sync, and the glossary could be large. For MVP, the "non-empty" flag is sufficient.

6. **Open question**: The `translationEnabledProvider` is used in multiple places (reader_providers.dart line 158, and potentially elsewhere). Changing its implementation to also update a sync state provider should not break existing consumers — they still watch the `FutureProvider.future` as before.

7. **Open question**: Is there any other async work in the reader opening sequence that we're missing? The `reader_screen.dart` has `bookAsync.when` → `settingsAsync.when` → `ReaderContent`. Both `bookAsync` and `settingsAsync` are `FutureProvider`s. If they're slow to resolve, the reader screen shows a shimmer before `ReaderContent` even mounts. This is a separate issue from the chapter content delay, but could contribute to the perceived slowness. For this plan, we focus on the chapter content fast path (the user's specific complaint about "reader should open almost instantly when chapter is already downloaded").
