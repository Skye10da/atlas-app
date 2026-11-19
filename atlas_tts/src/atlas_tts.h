// Atlas TTS core — C ABI. See lib/reader/speech/docs/neural-tts-engine-design.md
// (NTD) for the architecture this implements.
//
// M1 (NTD §4) native skeleton + M2 neural synthesis behind this one ABI:
// a VITS voice pack (sherpa-onnx) renders on the worker thread, with the M1
// sine renderer kept as an explicit dev fallback for model-less test packs.
// Audio flows through an internal FIFO that Dart drains with
// atlas_tts_take_audio; the platform output device (Oboe/AVAudioEngine, M3)
// replaces the FIFO consumer, so the render side does not change shape in M3.
//
// Threading model:
// - atlas_tts_speak() starts a render on a worker thread and returns
//   immediately; results arrive through the event callback registered in
//   atlas_tts_init().
// - The callback may be invoked asynchronously (Dart NativeCallable.listener
//   defers delivery to the Dart event loop), so ALL payloads are copy-safe
//   scalars:
//     * audio is held in the core's internal FIFO until
//       atlas_tts_take_audio() copies it out and frees it;
//     * word boundaries carry chunk-local offsets only — the caller owns the
//       utterance text and maps offsets itself (the NeuralTtsDriver spoke the
//       text, so matching offsets into its own copy is exact);
//     * errors carry a code, not a string.
//
// One session per process (mobile usage: at most one narration engine). All
// functions return ATLAS_OK (0) on success or a negative ATLAS_ERR_* code.
#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

enum {
  ATLAS_OK = 0,
  ATLAS_ERR_NOT_INIT = -1,
  ATLAS_ERR_ALREADY_INIT = -2,
  ATLAS_ERR_INVALID_ARG = -3,
  ATLAS_ERR_NOT_READY = -4,   // speak() before a voice pack is loaded (M2)
  ATLAS_ERR_BUSY = -5,        // speak() while another request is in flight
  ATLAS_ERR_THREAD = -6,      // thread creation failed
  ATLAS_ERR_OVERFLOW = -7,    // take_audio buffer smaller than requested chunk
  ATLAS_ERR_INTERNAL = -8,
};

// Event kinds. See the atlas_tts_event_cb_t comment for per-kind payloads.
typedef enum {
  ATLAS_EVENT_VOICE_READY = 1,   // voice loaded (load_voice completed)
  ATLAS_EVENT_WORD = 2,          // word boundary (text_offset/text_length)
  ATLAS_EVENT_AUDIO_CHUNK = 3,   // audio queued (see sample_count/sample_index)
  ATLAS_EVENT_CHUNK_DRAINED = 4, // utterance fully delivered into the FIFO (M1)
                                 // / played through the output device (M3)
  ATLAS_EVENT_ERROR = 5,         // error_code carries the reason
} AtlasTtsEventKind;

// Callback invoked (possibly asynchronously) outside the calling thread.
// All payloads are passed BY VALUE: NativeCallable.listener delivers the
// callee's arguments through a Dart port after the callback returns, so no
// pointer-owned memory may back the payload (stack structs die immediately).
//
// Per-kind payload (other parameters are 0/unused):
//   ATLAS_EVENT_VOICE_READY     sample_rate = model output rate (0 for the
//                               sine dev fallback)
//   ATLAS_EVENT_WORD            textOffset/textLength (chunk-local offsets)
//   ATLAS_EVENT_AUDIO_CHUNK     sampleRate/sampleCount/sampleIndex — PCM
//                               samples are inside the core FIFO, drained by
//                               atlas_tts_take_audio() in FIFO order
//   ATLAS_EVENT_CHUNK_DRAINED   none — with playback enabled this marks the
//                               utterance PLAYED OUT by the device consumer;
//                               without playback it marks the FIFO fully
//                               queued (M1 semantics)
//                               (note: request id 0 is never drained by the
//                               playback consumer — the pending-drain marker
//                               uses 0 as "unset"; callers must start ids at 1)
//   ATLAS_EVENT_ERROR           errorCode (an ATLAS_ERR_* value)
typedef void (*atlas_tts_event_cb_t)(int32_t kind,
                                     int32_t error_code,
                                     int32_t sample_rate,
                                     int32_t sample_count,
                                     int32_t sample_index,
                                     int32_t text_offset,
                                     int32_t text_length,
                                     int64_t request_id,
                                     void* user_data);

typedef struct atlas_tts_request_t {
  const char* text;      // UTF-8, NUL-terminated; owned by caller for the
                         // duration of the atlas_tts_speak() call only.
  float length_scale;    // >0.0; 1.0 = default speaking rate. Smaller = faster.
  float noise_scale;     // >=0.0; 0.667 = default. Higher = more pitch variance.
  float volume;          // 0.0..1.0 linear gain (applied at render in M1).
  int64_t request_id;    // caller-chosen id echoed in all events.
} atlas_tts_request_t;

typedef struct atlas_tts_config_t {
  int32_t sample_rate_hint;  // 0 = use the core default rate.
  atlas_tts_event_cb_t event_cb;
  void* user_data;           // passed through to every callback invocation.
} atlas_tts_config_t;

// Initialize the core. Exactly one live session per process.
FFI_PLUGIN_EXPORT int atlas_tts_init(const atlas_tts_config_t* config);

// Load a voice pack directory. Two accepted layouts:
//   * sherpa-onnx tts-models pack (M2): <voice>.onnx + tokens.txt +
//     espeak-ng-data/ — loads the VITS engine, publishes _VOICE_READY with
//     sample_rate = model output rate, and speak() then renders neural speech;
//   * a directory without a model: the M1 sine dev fallback is activated
//     (tests/experiments only — never ships). Loading a pack while a render
//     is in flight first stops it (same contract as atlas_tts_stop()).
// Loading is synchronous; the neural path blocks for seconds (model import).
// Returns ATLAS_OK (0) or a negative ATLAS_ERR_* code.
FFI_PLUGIN_EXPORT int atlas_tts_load_voice(const char* pack_dir);

// Unload the current pack (cancels any in-flight render first).
FFI_PLUGIN_EXPORT int atlas_tts_unload_voice(void);

// Start rendering `req->text` on the worker thread. Returns immediately.
// Requires a loaded voice pack (ATLAS_ERR_NOT_READY otherwise). Emits
// ATLAS_EVENT_WORD and ATLAS_EVENT_AUDIO_CHUNK events as rendering
// progresses, then ATLAS_EVENT_CHUNK_DRAINED.
FFI_PLUGIN_EXPORT int atlas_tts_speak(atlas_tts_request_t* req);

// Copy queued PCM out of the core FIFO, oldest first, and free the native
// side of what is copied. Copies at most `max_frames` mono int16 samples.
// Returns the number of mono samples copied, or a negative ATLAS_ERR_* code.
// Non-blocking: returns 0 when the FIFO is empty (Dart retries on the next
// event; M3's output thread blocks instead using the internal condvar).
FFI_PLUGIN_EXPORT int32_t atlas_tts_take_audio(int16_t* dst,
                                              int32_t max_frames);

// Total mono samples currently queued (drained by take_audio). Diagnostics /
// backpressure planning; safe to call from the event thread.
FFI_PLUGIN_EXPORT int32_t atlas_tts_queued_frames(void);

// Cancel the in-flight render (if any) and drop queued audio. Joins the
// worker before returning, so it is safe to speak() again right after.
FFI_PLUGIN_EXPORT int atlas_tts_stop(void);

// M3 gates playback here. With the playback device consumer active this
// pauses/resumes device pumping; without playback (take_audio path) it is
// accepted and has no effect.
FFI_PLUGIN_EXPORT int atlas_tts_pause(int on);

// M3: hands FIFO consumption to the built-in playback device: winmm waveOut
// on the Windows host (no COM), AAudio on Android (loaded via
// dlopen("libaaudio.so") so the plugin keeps loading below API 26 and the
// missing backend just degrades to the take_audio path; the Oboe wrapper is
// deliberately skipped — this backend is direct AAudio), AVAudioEngine on
// iOS device builds. When enabled, CHUNK_DRAINED fires after the device
// played the utterance out (not merely queued) and take_audio becomes a
// no-op consumer — use it or the device, not both.
//
// Device timing/format notes:
// - creates its consumer thread lazily on the first enable; disable only
//   stops pumping and the thread stays alive for the session lifetime;
// - the session sample rate is captured when the device is created — after
//   load_voice() changes the rate, disable + re-enable to rebuild it;
// - returns ATLAS_ERR_INTERNAL on platforms whose device backend is not
//   compiled in (currently iOS; Android resolves the backend at runtime via
//   dlopen and answers ok even where libaaudio.so is absent — without a
//   device the drained event would never fire, so callers on sub-API-26
//   devices must not activate playback);
FFI_PLUGIN_EXPORT int atlas_tts_enable_playback(int on);

// Tear down the session: stops worker, frees FIFO. Safe to call twice.
FFI_PLUGIN_EXPORT void atlas_tts_shutdown(void);

#ifdef __cplusplus
}  // extern "C"
#endif
