# Atlas Neural TTS Engine — Design (NTD)

> Version: 0.6 — M3 Android slice implemented (AAudio backend + app-side
> pack gate)
> Status: M2 + M3 host slice + M3 Android slice complete (device-validated
> 2026-11-14: SM A528B / LineageOS 11, real VITS RTF 0.136 < 0.2 gate); M4
> complete (in-app neural narration confirmed on device via side-loaded pack)
> (`NeuralTtsDriver` behind the `SpeechDriver` contract, capability-gated
> selection in `speech_providers.dart`, native-bound driver tests green;
> the neural path stays dormant until the first voice pack is installed —
> the M5 downloader flips the gate). Remaining M3: AVAudioEngine (iOS,
> macOS host work) device backend. Changelog: v0.6 adds §6quater: the
> Android playback backend is **direct AAudio** (Oboe wrapper skipped —
> it adds nothing over our flat pull model), resolved from libaaudio.so
> via dlopen so the plugin keeps loading below API 26; `tryCreate()` now
> also requires an installed voice pack (sync probe; §6quater), so the
> neural driver stays parked on FlutterTtsDriver until the M5 CDN
> downloader lands. v0.5 implemented §4's M4 — `NeuralTtsDriver` wraps the atlas_tts
> session: pack resolution (`<docs>/atlas_tts/voices/<pack-id>`; unknown
> persisted ids degrade to the default pack), rate→length_scale remap,
> device-gated native pause (no re-synthesis on resume), stop/restart
> recovery, speak completion via playback-mode CHUNK_DRAINED (ids start at
> 1 — request id 0 collides with the core's "no pending drain" marker,
> recorded in `atlas_tts.h`), word-boundary UTF-8 byte offsets translated
> into Dart indices with surrogate-pair-safe mapping. Provider selection is
> capability-checked (`tryCreate`: platform guard + session init +
> enablePlayback probe), falling back to `FlutterTtsDriver` — active on all
> current platforms until Oboe/AVAudioEngine land. v0.4 implemented §4's
> M3 host slice — `atlas_tts_enable_playback` / `pause(on)` now drive a
> built-in playback device thread that pulls the §6 FIFO, and in playback
> mode `CHUNK_DRAINED` fires after the utterance is **played out** by the
> device (§6 semantics upgraded from "fully queued") — the worker defers
> via `render_done_id` and the device thread emits. Windows backend is
> **winmm waveOut**, not WASAPI: the first WASAPI implementation (shared
> mode, AUTOCONVERTPCM) is correct Code but
> `CoCreateInstance(CLSID_MMDeviceEnumerator)` answers `REGDB_E_CLASSNOTREG`
> on this dev host even though AudioSrv runs (audio COM classes stripped
> from HKCR — verified via registry + .NET COM activation from
> PowerShell); waveOut needs no COM classes. Public ABI is
> device-agnostic, so the Android/iOS backends (Oboe / AVAudioEngine) swap
> in without Dart-side changes. v0.3 implemented §4's M2 — sherpa-onnx
> **v1.13.8** (pinned; last line phonemizing in-process via espeak-ng-data —
> v2.x dropped that and requires a piper_phonemize frontend, see
> `atlas_tts/src/atlas_tts.c` header note), piper VITS voice packs
> (sherpa-onnx tts-models layout: `<voice>.onnx` + `tokens.txt` +
> `espeak-ng-data/`), incremental PCM via the generation progress callback
> feeding the §6 FIFO, sine retained as dev-only fallback, speak() now
> requires a loaded pack (ATLAS_ERR_NOT_READY). Host RTF ≈ 0.1–0.5 for
> amy-medium (num_threads=2, desktop CPU) — well inside real-time; the
> strict < 0.2 target is the M5 on-device gate. v0.2 implemented §4's M1
> and revised two ABI details discovered while building it: (a) the event
> callback carries payloads BY VALUE (NativeCallable.listener delivers
> asynchronously — pointer-backed payloads dangle); (b) rendered audio
> flows through a core-internal FIFO drained via `atlas_tts_take_audio`
> rather than pointer events, same reason (in M3 playback mode that FIFO
> is drained by the native device thread instead). Implemented plugin:
> `atlas_tts/` (iOS forwarder into `src/atlas_tts.c`, Android + Windows
> CMake; ffigen deferred until libclang is available, bindings
> hand-maintained). `atlas_tts` is now wired as a path dependency of the
> host app and ships `libatlas_tts.so` for arm64-v8a/armeabi-v7a/x86_64 in
> the Android APK (sine core until the sherpa-onnx Android prebuilt wiring
> lands with the M3 remainder).
> Companion to: ATLAS Speech Architecture (ASA) v1.2 (`atlas-speech-architecture.md`)
> Scope: Android + iOS first. Desktop (Windows/macOS/Linux) stays on `FlutterTtsDriver`.

---

## 1. Goal

Replace reliance on platform TTS (talking through `flutter_tts` → OS voices) with
Atlas's own on-device neural synthesis engine — our inference runtime, our model
runtime, our audio output path — while keeping the ASA contract untouched.

**Locked decisions:**

| Decision | Choice |
|---|---|
| Engine type | On-device neural (VITS-class model, ONNX inference) |
| Platforms | Android + iOS first; desktop remains on `FlutterTtsDriver` |
| Voice distribution | Download-on-demand voice packs via Atlas CDN |
| Audio pipeline | Custom native PCM pipeline (ring buffer → Oboe / AVAudioEngine) |
| Licensing | espeak-ng GPLv3 runtime usage **accepted** (owner's call, recorded) |
| Default voice | **No bundled voice** — the default pack is downloaded on demand
   (CDN) on first TTS use; `FlutterTtsDriver` platform TTS covers the gap
   until it arrives. Dev machines fetch a pack via
   `atlas_tts/tool/fetch_voice_pack.ps1` for tests only. |

**Why this is cheap to integrate.** The Speech subsystem was built for this
(ASA §13): `SpeechDriver` is the entire abstraction (ASA §4), `FlutterTtsDriver`
is the only file importing `flutter_tts`, and `SpeechEngine`/queue/UI talk only
to `SpeechDriver`. The custom engine slots in as **one new driver** plus
infrastructure behind it. `SpeechEngine` requires no changes.

---

## 2. Architecture Overview

```
┌─ Dart (main isolate) ─────────────────────────────────────────────┐
│  SpeechEngine / SpeechQueue / UI (UNCHANGED — ASA §2–§5)          │
│      │ SpeechDriver                                               │
│  NeuralTtsDriver  ← new: lib/reader/speech/drivers/               │
│      │             emits Driver* + DriverWordBoundary events      │
│  AtlasTtsController (FFI facade, lives in a background isolate)   │
└──────┬─────────────────────────────────────────────────────────────┘
       │ FFI — DynamicLibrary.open("libatlas_tts.so" / .dylib)
┌─ Native synthesis core (C++, "atlas_tts") ─────────────────────────┐
│  TextFrontend: normalize → tokenize → phonemes (espeak-ng data)   │
│  VitsModel (ONNX Runtime): phonemes → waveform → int16 PCM        │
│  RingBuffer: lock-free SPSC PCM fifo                              │
│  WorkQueue: synthesize chunk k+1 while chunk k plays (prefetch 1) │
└──────┬──────────────────────────────────────────────────────────────┘
       │ PCM, 24 kHz (or per-model rate) mono int16
┌─ Platform output ──────────────────────────────────────────────────┐
│  Android: Oboe (AAudio output stream)                             │
│  iOS:     AVAudioEngine + AVAudioUnitGenericOutput (render block) │
└────────────────────────────────────────────────────────────────────┘
```

**Nightmare-quality rule (from ASA §12):** every failure path below must end in a
`SpeechError`-recoverable state — if the neural engine dies, narration falls
back to the platform driver or restarts, never silently stops.

---

## 3. Component Design

### 3.1 Native plugin: `atlas_tts`

New FFI plugin, vendored into the repo (`flutter create --template=plugin_ffi`):

```
atlas_tts/
  native/atlas_tts/        # pure C++ core — no platform code
  android/…                # CMake → libatlas_tts.so (arm64-v8a, armeabi-v7a)
  ios/…                    # CocoaPods → libatlas_tts.a / dylib (arm64)
  lib/atlas_ttt.dart       # thin Dart entry, no UI
```

**Core dependency: sherpa-onnx** (Apache-2.0) — ships ONNX Runtime, VITS
support, espeak-ng phonemization, and its own inference thread pool. Fallback
option if sherpa-onnx must be rejected: raw ONNX Runtime + hand-rolled VITS
runtime (~an extra month of work; see §7 Licensing Gate).

**C ABI (tiny by design — everything is commands + callbacks):**

```c
int  atlas_tts_init(const AtlasTtsConfig* cfg, AtlasTtsEventCb cb);
int  atlas_tts_load_voice(const char* pack_path);        // model + config
int  atlas_tts_unload_voice(void);
int  atlas_tts_speak(const AtlasTtsRequest* req);        // text, lengthScale, noiseScale
int  atlas_tts_stop(void);                               // flush render + drain queue
int  atlas_tts_pause(int on);
```

Events pushed into `AtlasTtsEventCb` (invoked on the native event thread, never
the platform UI thread):

| Event | Meaning |
|---|---|
| `ATLAS_EVENT_VOICE_READY` | model loaded; first synthesis may start |
| `ATLAS_EVENT_WORD` | PCM-sample-anchored word boundary (chunk-local offset) |
| `ATLAS_EVENT_CHUNK_DRAINED` | a chunk finished playing (maps to sentence completion) |
| `ATLAS_EVENT_BUFFER_EMPTY` | playback underrun / stream drained |
| `ATLAS_EVENT_ERROR` | renderer or output failure (message attached) |

Threading: synthesis runs on native worker threads owned by the plugin. Dart
talks to it from a background isolate so model load (~1–3 s CPU) and inference
never touch the UI isolate.

### 3.2 Dart bindings & isolate model

- `lib/speech_native/atlas_tts_bindings.dart` — **ffigen**-generated from the C header.
- `lib/speech_native/atlas_tts_controller.dart` — `AtlasTtsController`: long-lived
  background isolate owning the native session. Ports:
  - Dart → native: `speak(item)`, `configure(…)`, `stop`, `loadVoice`, `unloadVoice`
  - Native → Dart: word boundaries (sample-count → text-offset mapping), per-chunk
    drain events, errors, buffer state.
- The controller bridges native events to the `events`/`stateStream` contract the
  driver code already uses (see `FlutterTtsDriver._wireCallbacks` as the pattern).

### 3.3 PCM playback pipeline

- **Ring buffer:** native core writes rendered PCM into a lock-free SPSC fifo;
  the platform output stream drains it in its render callback (Oboe
  `AudioStreamCallback` on Android; `AVAudioUnitGenericOutput` render block on
  iOS, sample-rate-converted by AVAudioEngine as needed). Implemented state
  (M3 host slice): the drain side is a dedicated native consumer thread
  pulling the FIFO — winmm waveOut (6 × 2048-frame chunks, ~93 ms latency
  each) on Windows; Oboe/AVAudioEngine replace only the device/loop functions
  on mobile. Drain semantics: while the playback device owns consumption,
  `CHUNK_DRAINED` for a request fires after **play-out completes** (FIFO
  empty + all device buffers finished + worker complete); without playback,
  the M1 semantics ("fully queued") remain, so the take_audio test path is
  unchanged.
- **Latency targets:** start playback once ~150 ms of the current chunk is
  buffered; keep ~600 ms of runway; drop runway to ~300 ms while user is seeking.
- **Why fully custom beats `just_audio` here:**
  1. gapless inter-sentence audio (no per-file seek gaps),
  2. sample-exact word-boundary timing,
  3. pause/resume = buffer gate, no resynthesis (fixes the flutter_tts
     "re-speak the whole sentence on resume" workaround documented in
     `FlutterTtsDriver.resume`),
  4. no temp files on disk.
- **Rate control:** VITS `length_scale` is the native speed knob. The existing
  `configure(rate:)` domain (flutter_tts 0.0–1.0-ish semantics) maps to
  `lengthScale = k / rate`; changes re-render the current sentence only — cheap
  because SpeechItems are sentence-sized (ASA §4). No DSP time-stretch in v1
  (render-at-new-rate sounds better and is simpler here).
- **Pitch:** VITS has no native pitch parameter. `configure(pitch:)` maps to
  `noise_scale` variance tuning; real pitch **is a voice-selection concern** in
  v1 (pick a voice whose mean pitch fits). Document the semantic difference from
  flutter_tts pitch in the Drake settings copy.
- **Volume:** int16 scaling applied at drain time inside the native core
  (avoids an extra resampling pass in Dart).
- **Interruptions:** the existing `audio_session` dependency still owns focus:
  - Android: audio focus — transient loss → duck (scale volume), full loss → `pause()`.
  - iOS: `AVAudioSession.category = .playback`; interruption notifications →
    `pause()` / `resume()`; `mixWithOthers` policy follows the narration tab toggle.
  The custom pipeline goes through audio_session helpers on the Dart side, which
  persist after switching output routes (headphones unplug → pause per OS spec).

### 3.4 `NeuralTtsDriver` — the SpeechDriver implementation

New file `lib/reader/speech/drivers/neural_tts_driver.dart` — drop-in for
`FlutterTtsDriver`, deliberately mirrors its shape:

| SpeechDriver method | NeuralTtsDriver behavior |
|---|---|
| `configure(rate, pitch, volume, voiceId, language)` | maps to `lengthScale` / `noiseScale` / drain gain / pack id / phoneme language; pack switch triggers `load_voice` |
| `speak(item)` | enqueue text to controller; returns immediately (unlike flutter_tts's await-completion mode — see Timing below) |
| `pause()` / `resume()` | native buffer gate; resumes sample-exact, no resynthesis |
| `stop()` | native stop → drain remaining buffer → `DriverCompleted`-equivalent or `stopped` |
| `listVoices()` | returns installed voice packs as `VoiceDescriptor`s (§3.5) — existing `_VoicePicker` UI works unchanged |
| `restart()` | unload + reload native voice instance (mirrors flutter_tts re-instantiation) |
| `dispose()` | natively tears down the session and closes stream controllers |

**Timing note.** `FlutterTtsDriver` sets `awaitSpeakCompletion(true)` so
`speak()` resolves when the item finishes — `SpeechEngine` relies on it (ASA §4).
The neural driver preserves that contract: `speak()` resolves when the underlying
chunk finishes draining (per-chunk `ATLAS_EVENT_CHUNK_DRAINED`), keeping the
engine's driving loop equivalent.

**Word boundaries.** Synthesis runs in sub-clause chunks (bounded by the
sentence splitter). While chunk *k* plays, chunk *k+1* renders. Word boundaries
are computed at render time from chunk-local text offsets plus live PCM-sample
tracking, then emitted as `DriverWordBoundary(start, end, word)` — more precise
than platform progress events.

**Fallback semantics.** If no pack is installed, `listVoices()` is empty and the
provider layer still resolves `FlutterTtsDriver` — the platform engine becomes
the *fallback*, not the primary. If the native engine errors mid-session
(ASA §12 recovery path): one retry of the current item, then fall back to
`FlutterTtsDriver` for the rest of the session and surface a one-shot notice,
not a crash.

### 3.5 Voice pack system (download-on-demand)

Reuses Atlas's content-pipeline patterns (the crypto dependency is already there
for plugin verification).

**Pack format:**

```
<pack-id>/manifest.json     # see below
<pack-id>/model.onnx        # 20–60 MB VITS variant
<pack-id>/tokens.txt
<pack-id>/espeak-ng-data/   # phonemization data scoped per-language
```

`manifest.json`:

```json
{
  "id": "en_US-lessac-medium",
  "name": "Atlas Voice — Lessac (EN, medium)",
  "language": "en",
  "locale": "en-US",
  "gender": "female",
  "sampleRate": 22050,
  "sizeBytes": 63000000,
  "modelFormatVersion": 1,
  "minAppVersion": "1.0.10",
  "files": { "model.onnx": {"sha256": "…"}, "tokens.txt": {"sha256": "…"} }
}
```

**Storage:**
- Drift tables: `voice_packs` (id, state: queued/downloading/ready/corrupt, bytes, verified).
- Files under `getApplicationDocumentsDirectory()/atlas_tts/voices/<pack-id>/`.
- The existing `VoiceCache` (ASA §6) gains pack-awareness rather than new persistence:
  `listVoices()` merges installed packs with the driver's platform voices.

**Delivery:**
- Manifests and files fetched over plain HTTP/HTTPS (existing `http` + cronet/cupertino
  setup); Supabase Storage is a candidate host, not a requirement.
- Streamed with resume support; sha256-verified before activation; atomic
  directory-swap on completion (write to `.tmp-<pack-id>`, rename on success);
  corrupt-partial cleanup on next scan.

**Model updates:**
- `modelFormatVersion` in each pack vs. the bundled runtime version. App refuses
  incompatible packs and prompts for a corrected download — prevents
  "engine update bricks downloaded voices".

**First-run UX:**
- Narration tab shows a "Get high-quality voices" entry point (fits the
  `_VoicePicker` flow). Until a pack is ready, Atlas transparently uses
  flutter_tts — no dead-end state.

**Status (v0.7 — Phase A+B done, catalog/download/gallery live):**

- **Catalog (Phase A)** — `voice_pack_manifest.dart` defines the CDN document:
  one `catalog.json` with `schemaVersion` (forward-compat guard at v1), voice
  **families** (one human voice) each carrying downloadable **flavors** — the
  explicit quality tiers Compact / Standard / Best, i.e. the piper low/medium/
  high variants — with per-file sha256. `VoicePackCatalogService`
  (`voice_pack_catalog.dart`) fetches with a 12 s timeout and caches the last
  good body in shared_prefs (`voice_pack_catalog_cache`); offline and
  newer-schema responses fall back to the cache, never an empty dead end.
  **Host (resolved): Hugging Face** — `kVoicePackCdnBase` points at
  `https://huggingface.co/Skye000/atlas-voice-packs/resolve/main`; public
  model repos serve directory-pathed downloads with no token, matching the
  app's `<base>/voices/<familyId>/<packId>/<file>` URL shape exactly. The
  catalog is generated from the local packs by
  `atlas_tts/tool/build_voice_catalog.ps1` (per-file sha256, recursive
  `espeak-ng-data/...` keys) and published with
  `atlas_tts/tool/publish_voice_packs.ps1` (`hf upload`). First catalog:
  family `piper-en_US-amy`, flavors Standard (amy-medium, RTF-validated)
  + Compact (amy-low — faster inference, similar size for this voice).
  `previewUrl` is null for v1: no sample clips generated yet, so gallery
  preview buttons render disabled until clips are added.
- **Downloader (Phase A)** — `voice_pack_downloader.dart`: queued →
  downloading → verifying → ready, sha256 per file, streamed in chunks (a
  60 MB model never materializes in memory), cooperative cancel between
  chunks, join-in-flight per pack, atomic `.tmp-<id>` → `<id>` rename.
  Failure lands in `corrupt` (retryable); startup `recoverStaleState()`
  demotes interrupted rows and deletes stale scratch dirs. Files land in
  `<docs>/atlas_tts/voices/<pack-id>/` — exactly the directory
  `NeuralTtsDriver.listVoices()`/_resolvePackDir already scan, so a ready
  pack is a usable voice with no driver rebuild (selection re-loads lazily
  via `configure()` → `_ensurePackLoaded`).
- **Persistence (Phase A)** — raw-SQL `voice_packs` Drift table (same
  precedent as `notification_history`; avoids a build_runner regen), plus
  per-family quality memory in shared_prefs (`voice_pack_quality_prefs`).
  `VoiceCache.clearMemory()` added so post-install invalidation re-queries
  the driver instead of serving the stale memory snapshot.
- **UI (Phase B)** — `VoiceGallerySheet`
  (`presentation/widgets/settings/voice_gallery_sheet.dart`):
  DraggableScrollableSheet bottom sheet; pack families first with ▶ CDN
  preview clips (just_audio, ~100 KB samples), the per-voice quality chips
  (Compact/Standard/Best with sizes; installed → tap selects, in-flight →
  live % + cancel, missing → download-then-auto-select), platform voices
  last. Narration tab restructured: `_VoiceCard` hero opens the gallery;
  everyday row = `NarrationSpeedControl` glass chip-pill + sleep timer;
  pitch slider only when a platform voice is selected (VITS has no pitch
  axis); Profiles section removed (presets were superseded by the speed
  pill); remaining switches collapsed under "Behavior & storage". A
  `VoicePill` on the Now Playing transport row shows the active voice and
  opens the gallery. Pack state in the gallery is **reactive**:
  `voicePackStatesProvider` streams the store and re-queries on every
  downloader `stateChangeStream` event, so an in-flight row shows its
  busy chip + live % + Cancel the moment a download starts (previously a
  one-shot FutureProvider, downloads ran with no indication until they
  finished); chip auto-select after a successful download reads the
  downloader's result, not the stale captured entry. Phase C polish
  (offline/cellular messaging, corrupt retry surfacing, delete-pack UI)
  still open.
- **Driver hot-swap (v0.8)** — pack install/delete now swaps the live
  driver: `SpeechEngine.swapDriver(SpeechDriver)` stops the old driver,
  rebinds its event stream, re-applies the session settings, and resumes
  mid-sentence playback on the new driver; the engine instance (and the
  audio_service handler bound to it) stays stable so OS media controls
  never lose their binding. `VoicePackController` drives the swap from
  `_maybeSwapDriver` on every terminal pack-state change: pack-ready →
  `NeuralTtsDriver.tryCreate()` now passes its pack-presence gate →
  neural takes over; last pack deleted → downgrade to platform TTS.
  `speechDriverEpochProvider` (bumped on each swap) re-resolves the
  driver-derived providers (`narrationStatusProvider`,
  `speechVoicesProvider`) from `engine.driver` instead of the
  app-start `speechDriverProvider` capture — that capture is what used
  to pin flutter_tts forever when no pack existed at boot. Injected
  test seams: `VoicePackController.neuralDriverFactory` /
  `platformDriverFactory`.
- **Narration UI overhaul (v0.8, Material 3 Expressive × liquid glass)** —
  `NowPlayingSheet` rebuilt as a stage: redundant "Now Playing" header and
  duplicated "Narration" heading removed; a palette-tinted cover hero with
  bigger typography; the karaoke lyric enlarged (16/17 px, w800 highlight);
  the seven-control transport row restructured into **two tiers** — a big
  expressive play/pause disc (64dp `GlassLens` droplet, springy
  `easeOutBack` icon morph, honors `disableAnimationsOf`) flanked by
  paragraph/sentence skips, and a centered glass strip (settings chip +
  speed dial + voice pill as a `Wrap` so narrow phones fold instead of
  shrinking); settings reveal is an `AnimatedSize` tonal capsule. The mini
  player is now a real `GlassCapsule` (blur 18) instead of an opaque
  Material card, and the Narration tab's voice card rides a `GlassLens`
  droplet with the "Behavior & storage" group rounded to match. Title/
  subtitle duplication fixed (book title no longer shown twice when no
  chapter title exists). New `test/reader/now_playing_sheet_test.dart`
  (hero, queue cursor, settings reveal, play-from-idle).

### 3.6 Text front-end

- Sentence splitting: **already exists** (`parser/sentence_splitter.dart`).
- Normalization (numbers → words, dates, abbreviations, currency): naive v1
  (pass-through), language-aware v1.5 — the neural model expects spelled-out
  text, so normalization quality gates pronunciation quality.
- Phonemization: sherpa-onnx's embedded **espeak-ng data**, shipped per pack
  (§7 Licensing Gate applies).

---

## 4. Engineering Phasing

| Phase | Deliverable |
|---|---|
| **M1 — Native skeleton** | `atlas_tts` FFI plugin compiles on Android+iOS; init/load/synthesize a sine; fgen bindings + isolate controller; stub-native tests. |
| **M2 — Real synthesis** | Load a piper VITS pack, render a sentence → int16 PCM; measure RTF (target < 0.2) and RAM on-device. |
| **M3 — Playback** | Oboe output (Android), then AVAudioEngine (iOS); ring buffer, pause/resume gating, drain events. **Host slice done (see 6ter); Android slice done AND device-validated (see 6quater) - direct AAudio (the Oboe wrapper is skipped, adding nothing over the flat pull model), dlopen-resolved so sub-API-26 devices degrade gracefully to the take_audio path; drained semantics = played-out like host winmm; the backend compiles into libatlas_tts.so for all three ABIs and the on-device example probe validates pacing + pause/resume (real VITS, RTF 0.136). ABI (`atlas_tts_enable_playback`, `pause`) is device-final so remaining backends (AVAudioEngine, iOS) drop in without touching Dart.** |
| **M4 — Driver integration** | `NeuralTtsDriver` behind `SpeechDriver`; word boundaries; swap logic in `speech_providers.dart` + flutter_tts fallback. **Done (v0.5): capability-gated selection, pack resolution, rate remap, native pause; dormant until the M3 mobile device lands, then auto-activates.** |
| **M5 — Voice packs** | Drift registry, downloader, verifier, atomic activation, `_VoicePicker` extension, engine-choice settings. **Phase A+B done (v0.7): CDN catalog + sha256 downloader + atomic activation (raw-SQL `voice_packs` table) + `VoiceGallerySheet` bottom sheet (quality chips, preview clips, progress) + Narration-tab revamp + Now-Playing voice pill; 20 pack tests + 11 widget tests green; packs **published live** to the public HF repo `Skye000/atlas-voice-packs` (catalog + both amy tiers verified HTTP 200, byte-identical, sha256-matching). Remaining: offline/cellular + corrupt-retry + delete-pack polish (Phase C).** |
| **M6 — Polish** | Prefetch tuning, low-RAM tier (int8 models), thermal guard, dispose/restart semantics, language-override path (`resolveVoiceIdForLanguage` for dictionary reads). |

---

## 5. Verification Plan (per test-build-verification rule)

Every phase ships with:

- **Dart unit tests** — driver contract tests (same suite used for
  `FlutterTtsDriver` semantics where appropriate), pack manifest/verifier tests,
  chunk word-boundary math.
- **Widget tests** — Narration tab pack entries, provider fallback states.
- **Scoped checks** — `dart analyze` per `lib/reader/speech` area +
  `flutter test` + `flutter build apk --debug`. iOS: `flutter build ios --no-codesign`
  when the iOS pod is touched.
- Native-side smoke tests runnable through the FFI smoke entrypoint in M1/M2.

---

## 6. Risks & Mitigations

1. **espeak-ng is GPLv3** — the phonemizer data/code inside sherpa-onnx is GPL.
   If Atlas is distributed closed/proprietary, *runtime* espeak usage is a
   licensing trap. Mitigation options (click before M2):
   a. prefer packs that ship non-GPL phoneme data, or
   b. entity-split: distribute packs pre-phonemized so the app never ships eSpeak data, or
   c. isolate espeak into a separately licensed downloadable component.
   **This is the §7 Licensing Gate — must be resolved before M2.**
2. **First-audio latency** — model load ~1–3 s once per session + ~300–700 ms per
   sentence render. Mitigated by load-on-narration-start (never at app boot) and the
   prefetch-ahead design.
3. **Memory on low-end Android** — ~60–120 MB dominant per loaded voice + inference
   peak. Design: single loaded voice at a time, unload-on-idle timer (e.g. 60 s),
   int8 model tier as the low-RAM fallback.
4. **Existing `voiceId` format mismatch** — `configure(voiceId:)` currently parses
   flutter_tts `name@locale` strings. Pack ids are driver-local: NeuralTtsDriver
   owns its own parsing, as the current code explicitly wants ("this gap is visible
   once real voice-selection UI is wired up").
5. **Desktop regression risk: none** — Windows/macOS/Linux keep `FlutterTtsDriver`;
   the NeuralTtsDriver is wired per-platform via providers.
6. **Model quality/licensing variance** — piper voices vary in tone; voice review
   feel is subjective. Mitigation: shortlist 2–3 voices per language, evaluate on
   device before exposing in `_VoicePicker`.

---

## 7. Open Decisions Required Before M2

1. ~~Licensing gate: espeak-ng GPLv3~~ — **accepted** (recorded above).
2. ~~Voice pack hosting~~ — **Atlas CDN**.
3. ~~Default bundled voice~~ — **revised 2026-11-05: nothing is bundled**; the
   default pack is pulled on demand (CDN) on first TTS use, with platform TTS
   as the until-then fallback. Lowered app size by one pack (20–64 MB); costs
   first-run network dependency (M5 download manager must handle offline /
   interrupted downloads; M4 driver keeps `FlutterTtsDriver` as fallback).
   Default pack flavor TBD in M5 — amy-low-int8 (20 MB) vs amy-medium (64 MB).

## 6bis. Licensing record (resolved 2026-11-04)

Runtime espeak-ng (GPLv3) usage within sherpa-onnx is accepted for Atlas. The
atlas_tts core itself is C/C++ linking sherpa-onnx statically or dynamically;
piper voices each carry their own license (see each pack manifest).

## 6ter. M3 host backend record (resolved 2026-11-05)

Windows dev-build playback uses **winmm waveOut**, not WASAPI. The WASAPI
shared-mode implementation was written first and is semantically identical,
but `CoCreateInstance(CLSID_MMDeviceEnumerator)` returns
`REGDB_E_CLASSNOTREG` on the dev host even though `AudioSrv` and
`AudioEndpointBuilder` run and `MmDevApi.dll` exists — the audio COM class
registrations are absent from `HKCR\CLSID\{BCDE0395-…}` (verified by direct
registry check and .NET COM activation from the same session). waveOut's
device mapper needs no COM class activation. Constraint: regaining WASAPI
(position-accurate endpoints, auto-convert, event-driven) requires fixing the
host OS image — out of scope for app code; the device layer is a swappable
internal, `Oboe`/`AVAudioEngine` unaffected. Headless CI hosts without an
audio endpoint degrade gracefully: `waveOutOpen` fails, the session stays
usable via `take_audio`, and the playback thread idles.

## 6quater. M3 Android backend record (resolved 2026-11-05)

Android playback uses **AAudio directly**, not the Oboe wrapper: Oboe is a
thin wrapper over the same AAudio output stream, and the flat pull-model
consumer needs none of its extras — keeping the plugin third-party-dependency-
free mattered more. Design constraints and behavior:

- **dlopen, not a hard link (`target_link_libraries(... aaudio)`)**: the
  gradle CMake sysroot is pinned
  to the plugin minSdk (24) where the aaudio headers/libs do not exist, and a
  hard link to `libaaudio.so` would make the whole plugin .so fail to load on
  sub-API-26 devices (taking the sine path down with it). Instead the backend
  resolves the ~14 AAudio entry points from `libaaudio.so` at runtime:
  API >= 26 gets playback; below it the backend marks itself unavailable and
  the take_audio consumer keeps working — the plugin never fails to load.
- **Same condvar pump as winmm**: one persistent thread, `requestPause`
  holds (no re-synthesis), drained fires when the FIFO is empty AND the
  worker set `render_done_id` — device tail bounded by AAudio's internal
  buffer (tens of ms), same acceptance policy as winmm's in-flight windows.
- **Pull model**: the AAudio data callback consumes the FIFO directly at
  device pace and zero-fills when dry (no underrun-exit). Idle playback keeps
  no stream open — the pump opens on the first queued frames after enable
  and parks the stream after each drained event.
- **Sample rate**: the session rate (22050) is requested explicitly;
  AudioFlinger resamples into the device mix.
- Verified first on host wheels: `flutter build apk` compiles the backend
  into `libatlas_tts.so` (arm64-v8a et al.); device validation runs the
  example probe (init -> enablePlayback -> dev-sine pack -> speak ->
  drained pacing + mid-flight pause/resume) on a real arm64 device.
- **Device-validated 2026-11-14** (SM A528B, LineageOS 11, arm64; the ROM's
  AAudio is the legacy AudioTrack shim, which is exactly the kind of surface
  this backend must survive):
  - Drained pacing is exact: short utterance 2.42 s audio drained at t=2.31 s;
    long utterance 6.49 s audio with a 2 s mid-flight pause hold drained at
    8.47 s (0.33 s render + audio + held time) — pause/resume holds play-out,
    no drift.
  - Real VITS (amy-medium side-loaded into the example): audio 7.49 s out of a
    1.02 s render = **RTF 0.136 on-device**, under the 0.2 M5 gate, with
    streamed playback (audio plays while rendering continues).
  - In-app chain confirmed: debuggable main app + `tool/install_pack_device
    .ps1` side-load -> pack gate passes -> `NeuralTtsDriver` narrates a book
    through VITS/AAudio (user-verified audible narration).
  - Three launch bugs fixed against the real device: `AA_PERF_NONE` must be
    10 (AAudio PERFORMANCE_MODE_NONE; 0 is invalid and open fails with
    -898), the pump only starts the stream with frames pending (an empty
    stream otherwise sits RUNNING pulling zeros at full power), and
    `post_event` is NULL-guarded against the shutdown race. The pack
    side-loader stages through `/data/local/tmp` — shell-pushed files under
    `/sdcard/Android/data/<app>` are unreadable to the app uid on
    scoped-storage ROMs.

**App-side activation gate (M4 refinement)**: with AAudio compiled in,
`enablePlayback` succeeds on modern Android devices — but until the M5 CDN
download manager ships, no pack can exist, and activating the neural driver
would turn working platform-TTS narration into SpeakErrors. `NeuralTtsDriver
.tryCreate` therefore now also requires an installed pack, probed
SYNCHRONOUSLY (the provider graph is sync; path_provider is async):
Android derives `/data/user/0/<pkg>/app_flutter` from `/proc/self/cmdline`,
matching path_provider's `Context.getDir("flutter", MODE_PRIVATE)`
convention; iOS climbs from `Platform.resolvedExecutable` to the `.app`
container + `/Documents`. Ambiguity answers false = FlutterTtsDriver keeps
narration. The M5 pack downloader writing into `<docs>/atlas_tts/voices`
flips the gate on the next app start (live re-selection tracked under M5).

---

## 8. File Map (proposed)

```
atlas_tts/                                   # new FFI plugin (vendored)
lib/speech_native/
  atlas_tts_bindings.dart                    # ffigen output
  atlas_tts_controller.dart                  # isolate + port façade
lib/reader/speech/drivers/neural_tts_driver.dart
lib/reader/speech/persistence/voice_packs.dart     # drift table + repository
lib/reader/speech/settings/narration_settings.dart      # engine selection field
lib/reader/presentation/widgets/settings/narration_tab.dart  # pack UI additions
speech/docs/neural-tts-engine-design.md     # this document
```

Drift schema change (packs table) follows the existing migration pattern in the
app's drift directory — no schema migration to `voice_cache` itself.
