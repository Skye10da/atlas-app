# 0.4.2

* Android AAudio backend, three fixes from on-device validation (SM A528B /
  LineageOS 11): the performance mode passed to the builder is now the real
  `AAUDIO_PERFORMANCE_MODE_NONE` (10) — the placeholder 0 made
  `openStream` fail with `-898 ILLEGAL_ARGUMENT`; the pump phase machine only
  starts the stream while frames are pending (an empty stream otherwise sits
  RUNNING pulling zero-filled audio at full power) and pauses only from
  RUNNING; `post_event` NULL-guards the callback against the shutdown race.
* Example probe: request ids start at 1 (id 0 is the core's unset-drain
  marker and never receives CHUNK_DRAINED in playback mode); logging back on
  `debugPrint`, the only logcat-visible channel for a detached Android app.
* `tool/install_pack_device.ps1` stages the pack through
  `/data/local/tmp/atlas_tts_pack_stage` — shell-pushed files under
  `/sdcard/Android/data/<app>` are unreadable to the app uid on
  scoped-storage ROMs (Android 11+).
* Device validation record: drained pacing exact (2.42 s audio drained at
  2.31 s; 6.49 s audio + 2 s pause hold drained at 8.47 s), pause/resume
  holds play-out, and real VITS (amy-medium) renders 7.49 s of audio in
  1.02 s — **RTF 0.136 on-device, under the 0.2 M5 gate**. In-app neural
  narration via the M4 pack gate confirmed on device with a side-loaded
  pack.

# 0.4.1

* M3 Android slice: **direct AAudio** playback backend (Oboe wrapper skipped —
  it adds nothing over the flat pull model). The backend resolves the AAudio
  entry points from `libaaudio.so` via dlopen at thread start, so the plugin
  .so keeps loading below API 26 (graceful take_audio degradation) and the
  gradle minSdk floor is untouched. Pull-model data callback consumes the
  FIFO at device pace and zero-fills on dry reads; the pump opens the stream
  on first queued frames, parks it after each drained event, and maps
  `pause(on)` to `requestPause`. Compiled into `libatlas_tts.so` (arm64 et
  al.) with unchanged public ABI; the shared CMake gained no Android-only
  link entries.
* App-side (M4 refinement): `NeuralTtsDriver.tryCreate` now also requires an
  installed voice pack (synchronous sandbox probe, see NTD §6quater) — the
  neural driver stays parked on platform TTS until a pack exists.

# 0.3.0

* M3 host slice: playback device consumer — `atlas_tts_enable_playback(1)` /
  `pause(on)` now drive a native playback thread that pulls the FIFO
  (winmm waveOut on Windows; Oboe/AVAudioEngine on mobile to come). In
  playback mode `CHUNK_DRAINED` fires only after real-time play-out and
  `take_audio` is mutually exclusive; the worker's drained emission is
  superseded via `render_done_id`. `tool/playback_probe.dart` verifies an
  audible end-to-end utterance on the host.
* Android: the shared CMake build compiles for the Android Gradle Plugin
  (sine core; 16 KB page-size links); `libatlas_tts.so` ships in the host
  app APK across arm64-v8a / armeabi-v7a / x86_64. ABI note: request id 0
  is reserved on the core side ("unset" marker) — callers start ids at 1.

# 0.2.0

* M2: real neural synthesis behind the same ABI — sherpa-onnx v1.13.8 VITS
  (espeak-ng phonemization in-process), piper voice pack loading
  (`<voice>.onnx` + `tokens.txt` + `espeak-ng-data/`), incremental PCM via the
  generation callback into the existing FIFO, sine retained as dev-only
  fallback, `speak()` requires a loaded pack (`ATLAS_ERR_NOT_READY`).
  `tool/fetch_voice_pack.ps1` fetches the pinned runtime + default voice.

# 0.1.0

* M1: native skeleton — session/voice/render ABI, event callback, audio FIFO,
  sine placeholder renderer, Dart facade + bindings, host smoke test.
