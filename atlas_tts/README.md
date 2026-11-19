# atlas_tts

Atlas's in-app neural TTS core — native synthesis with **no platform TTS
engine**. Design: `lib/reader/speech/docs/neural-tts-engine-design.md` (NTD)
in the host app.

## Status: M3 host + Android slices device-validated (RTF 0.136 on-device) on top of M2 + M4 in-app

- C core (`src/atlas_tts.h/.c`): session init, voice pack loading, VITS
  synthesis via sherpa-onnx (pinned **v1.13.8**, the last line that phonemizes
  in-process via `espeak-ng-data` — see NTD before touching v2.x), incremental
  PCM through the internal FIFO, scalar event callbacks, cancellation, and the
  M1 sine renderer as an explicit dev fallback for model-less test packs.
- Playback device consumer (M3): `atlas_tts_enable_playback(1)` hands FIFO
  consumption to a native playback thread. Windows host uses **winmm
  waveOut** (no COM; the first WASAPI attempt was dropped because
  `CoCreateInstance(MMDeviceEnumerator)` answers `REGDB_E_CLASSNOTREG` on
  hosts with stripped audio COM registration). Android uses **direct AAudio**
  (the Oboe wrapper is skipped — it adds nothing over the flat pull model),
  resolved from `libaaudio.so` via dlopen so the plugin keeps loading below
  API 26 — those devices simply degrade to the take_audio consumer. With
  playback enabled, `CHUNK_DRAINED` fires after the device **played the
  utterance out** (not merely queued) and `take_audio` must not be used. iOS
  (AVAudioEngine) lands with the macOS-host build (M3 remainder).
- `speak()` requires a loaded pack (`ATLAS_ERR_NOT_READY` otherwise); a pack
  dir without a `*.onnx` model activates the sine fallback (dev only).
- Dart facade (`lib/atlas_tts.dart`): typed event stream, `NativeCallable.listener`
  bridging, single-session lifecycle, `enablePlayback`.
- Bindings (`lib/atlas_tts_bindings.dart`): hand-maintained `dart:ffi` bindings.
  `ffigen.yaml` is set up for regeneration once libclang is available.

- Device-validated 2026-11-14 (SM A528B / LineageOS 11): example probe runs
  the full sine chain (drained pacing exact, mid-flight pause/resume holds)
  and the real VITS pack — **RTF 0.136 < 0.2**, streamed through AAudio. The
  side-loaded-pack gate was confirmed in the main app (debug build): a book
  narrates via `NeuralTtsDriver`. See NTD §6quater for the record.

Next phases (NTD 4): M3 remainder = AVAudioEngine output on iOS (macOS-host
work); M5 = voice pack downloads (CDN; nothing is bundled — the default pack
is downloaded on first use; on-device RTF < 0.2 gate). M4 driver:
`atlas_app` `lib/reader/speech/drivers/neural_tts_driver.dart` — its
`tryCreate()` now also requires an installed pack beside the platform +
playback probes (sync gate; see NTD §6quater), so the neural driver stays
parked until the first download makes one available.

## Native dependencies

`native_deps/` (sherpa-onnx runtime + C-API header) and
`voices/vits-piper-en_US-amy-medium/` (dev/test voice pack, ~64 MB) are **not
in git** — fetch them once:

```
powershell -ExecutionPolicy Bypass -File tool\fetch_voice_pack.ps1
```

The fetch is for dev/test only: the shipped app downloads voice packs on
demand (CDN) and bundles none (NTD §7.3). Pinned at sherpa-onnx v1.13.8; the
test build enables the neural backend automatically when `native_deps/`
exists (`-DATLAS_SHERPA_RUNTIME` otherwise).

## Test

```
flutter test
```

The native smoke test (`test/atlas_tts_native_test.dart`) builds the C core
with CMake for the host (locating the VS-bundled cmake if needed) and drives
the real event/audio pipeline: sine rendering, cancellation, and — when the
voice pack is fetched — a full VITS utterance with an RTF report
(asserted < 1.0; on-device target is NTD M5's < 0.2). The playback test makes
real sound through the host's audio device (waveOut) and asserts the drained
event follows device play-out, not mere queueing. Set `ATLAS_TTS_CMAKE`
to point at a cmake binary explicitly.
