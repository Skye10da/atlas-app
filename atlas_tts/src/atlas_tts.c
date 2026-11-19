// Atlas TTS core â€” M2 implementation: neural (VITS via sherpa-onnx) with an
// M1 sine dev fallback for packs without a model.
// See the header and lib/reader/speech/docs/neural-tts-engine-design.md (NTD).
//
// Hook points for later phases, kept explicit so the future rewrites touch
// only the marked functions:
//   - vits_chunk_cb(): incremental PCM slicing (M4: placeholder word pacing)
//   - the audio FIFO consumer: M3 swaps atlas_tts_take_audio polling for the
//     playback device's pull, driven by the same condvar below
//
// sherpa-onnx plumbing (compiled in only when ATLAS_TTS_WITH_SHERPA is
// defined; builds without it fall back to the sine renderer but REJECT real
// packs rather than pretending):
//   - v1.13.8 (last 1.x): phonemizes in-process via espeak-ng-data
//   - v2.x dropped that; when the monorepo switches, phonemization must move
//     into the core (piper_phonemize) before touching the v2 API
#include "atlas_tts.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef ATLAS_TTS_WITH_SHERPA
#include "sherpa-onnx/c-api/c-api.h"
#endif

#define ATLAS_DEFAULT_SAMPLE_RATE 22050
#define ATLAS_SINE_HZ 440.0
#define ATLAS_SINE_AMPLITUDE 8000  // headroom for volume scaling without clip
#define ATLAS_CHUNK_FRAMES 4096
// Proportional-rate heuristic until VITS durations exist (M2): ~55 ms per
// character at length_scale 1.0 â€” close to normal speech density.
#define ATLAS_MS_PER_CHAR 55.0
// Render-side backpressure ceiling: ~6 s of mono audio at the default rate.
// The worker blocks (instead of growing memory unboundedly) while Dart is
// slower to drain than we are to render.
#define ATLAS_MAX_FIFO_FRAMES 131072

#if _WIN32
#include <windows.h>
// Statically-initialized primitives (SRWLOCK/CONDITION_VARIABLE are valid
// zeroed via their *_INIT constants), so no init-order coupling: any of the
// public functions may lock g_session.mutex before atlas_tts_init runs.
#define ATLAS_MUTEX SRWLOCK
#define ATLAS_COND CONDITION_VARIABLE
#define ATLAS_MUTEX_STATIC_INIT {SRWLOCK_INIT}
#define ATLAS_MUTEX_LOCK(m) AcquireSRWLockExclusive(&(m))
#define ATLAS_MUTEX_UNLOCK(m) ReleaseSRWLockExclusive(&(m))
#define ATLAS_COND_STATIC_INIT {CONDITION_VARIABLE_INIT}
#define ATLAS_COND_WAIT(c, m) SleepConditionVariableSRW(&(c), &(m), INFINITE, 0)
#define ATLAS_COND_SIGNAL(c) WakeConditionVariable(&(c))
#define ATLAS_THREAD HANDLE
#define ATLAS_THREAD_CREATE(t, fn, arg) \
  ((*(t) = CreateThread(NULL, 0, (fn), (arg), 0, NULL)) != NULL ? 0 : ATLAS_ERR_THREAD)
#define ATLAS_THREAD_JOIN(t) WaitForSingleObject((t), INFINITE)
#define ATLAS_THREAD_CLOSE(t) CloseHandle((t))
#define ATLAS_STRDUP _strdup
#else
#include <dirent.h>
#include <pthread.h>
#include <unistd.h>
#define ATLAS_MUTEX pthread_mutex_t
#define ATLAS_COND pthread_cond_t
#define ATLAS_MUTEX_STATIC_INIT PTHREAD_MUTEX_INITIALIZER
#define ATLAS_MUTEX_LOCK(m) pthread_mutex_lock(&(m))
#define ATLAS_MUTEX_UNLOCK(m) pthread_mutex_unlock(&(m))
#define ATLAS_COND_STATIC_INIT PTHREAD_COND_INITIALIZER
#define ATLAS_COND_WAIT(c, m) pthread_cond_wait(&(c), &(m))
#define ATLAS_COND_SIGNAL(c) pthread_cond_signal(&(c))
#define ATLAS_THREAD pthread_t
#define ATLAS_THREAD_CREATE(t, fn, arg) pthread_create((t), NULL, (fn), (arg))
#define ATLAS_THREAD_JOIN(t) pthread_join((t), NULL)
#define ATLAS_THREAD_CLOSE(t) ((void)0)
#define ATLAS_STRDUP strdup
#endif

// One chunk of rendered PCM waiting to be drained. Freestanding monomorphic
// node so M3's device pull can consume at frame granularity without changing
// the producer.
typedef struct atlas_audio_node_t {
  struct atlas_audio_node_t* next;
  int16_t* data;
  int32_t count;        // frames in data
  int32_t consumed;     // frames already copied out
  int64_t start_index;  // utterance-global position of data[0]
} atlas_audio_node_t;

typedef struct {
  // immutable after init
  atlas_tts_event_cb_t cb;
  void* user_data;
  int32_t sample_rate;

  // guarded by mutex
  ATLAS_MUTEX mutex;
  ATLAS_COND cond;             // signals: worker exit, backpressure release
  atlas_audio_node_t* audio_head;
  atlas_audio_node_t* audio_tail;
  int64_t audio_frames;        // queued mono samples awaiting take_audio
  int worker_live;             // thread running, not yet finalized
  int thread_created;          // a thread handle exists (cleared at shutdown)
  int stop_requested;          // cancel current render
  int request_in_flight;       // speak() started and not finished
  char* text;                  // malloc'd copy; worker frees it on exit
  float length_scale;
  float noise_scale;
  float volume;
  int64_t request_id;

  int voice_mode;              // 0 none (speak rejected), 1 sine dev pack,
                               // 2 neural (sherpa-onnx owns `sherpa`)
#ifdef ATLAS_TTS_WITH_SHERPA
  const SherpaOnnxOfflineTts* sherpa;  // valid iff voice_mode == 2
#endif

  // Playback device consumer (M3 host slice). The thread pulls the FIFO so
  // Dart no longer polls with take_audio; CHUNK_DRAINED fires when the
  // device actually played the utterance out. Mobile device backends
  // (Oboe / AVAudioEngine) land with the platform builds.
  int playback_requested;      // device consumer requested on
  int playback_paused;         // pause(on) while playback_requested
  int playback_exit;           // thread teardown (shutdown)
  int64_t render_done_id;      // request finished; playback thread owes the
                               // CHUNK_DRAINED event for this id
  ATLAS_THREAD playback_thread;  // valid when playback_thread_created
  int playback_thread_created;

  ATLAS_THREAD thread;         // valid when thread_created
} atlas_session_t;

// Process-global session. The mutex/cond use static initializers on both
// platforms, so every public entry may lock before atlas_tts_init runs â€”
// the cb!=NULL checks make those spikes cheap no-ops anyway.
static atlas_session_t g_session = {
    .mutex = ATLAS_MUTEX_STATIC_INIT,
    .cond = ATLAS_COND_STATIC_INIT,
};

// ---------------------------------------------------------------------------
// Event plumbing â€” value-parameter callback (see header for why no pointers).
// ---------------------------------------------------------------------------

static void post_event(int32_t kind, int32_t error_code, int32_t sample_rate,
                       int32_t sample_count, int32_t sample_index,
                       int32_t text_offset, int32_t text_length,
                       int64_t request_id) {
  // Call sites check cb under the mutex before releasing it, but shutdown
  // may null it in between; a NULL check here keeps that benign.
  if (g_session.cb == NULL) return;
  g_session.cb(kind, error_code, sample_rate, sample_count, sample_index,
               text_offset, text_length, request_id, g_session.user_data);
}

static void post_error(int32_t code, int64_t request_id) {
  post_event(ATLAS_EVENT_ERROR, code, 0, 0, 0, 0, 0, request_id);
}

// ---------------------------------------------------------------------------
// Audio FIFO. Producer: worker. Consumer: take_audio (Dart) in M1, the
// playback device in M3. Both sides always hold the session mutex.
// ---------------------------------------------------------------------------

static void audio_queue_drop_locked(void) {
  atlas_audio_node_t* n = g_session.audio_head;
  while (n != NULL) {
    atlas_audio_node_t* next = n->next;
    free(n->data);
    free(n);
    n = next;
  }
  g_session.audio_head = NULL;
  g_session.audio_tail = NULL;
  g_session.audio_frames = 0;
}

// Fills chunk with frames rendering starting at start_index; APPLIES INPUT
// MUTEX contract: caller holds the mutex OR passes held=0 and the function
// acquires it. Returns 0 on success.
//
// OWNERSHIP: `data` is consumed ONLY on success (queued). On any failure the
// buffer is left untouched and the CALLER frees it â€” never free inside the
// failure paths here, or cancellation burns the buffer twice.
//
// Return: 0 success, 1 stopped (cancellation â€” NOT an error), -1 internal
// failure (posts ATLAS_EVENT_ERROR at the caller's discretion).
static int audio_queue_push(int16_t* data, int32_t count, int64_t start_index) {
  ATLAS_MUTEX_LOCK(g_session.mutex);

  // Backpressure: block while the consumer is behind, waking on stop or drain.
  while (g_session.audio_frames >= (int64_t)ATLAS_MAX_FIFO_FRAMES &&
         !g_session.stop_requested) {
    ATLAS_COND_SIGNAL(g_session.cond);
    ATLAS_COND_WAIT(g_session.cond, g_session.mutex);
  }
  if (g_session.stop_requested) {
    ATLAS_MUTEX_UNLOCK(g_session.mutex);
    return 1;
  }

  atlas_audio_node_t* node = malloc(sizeof(atlas_audio_node_t));
  if (node == NULL) {
    ATLAS_MUTEX_UNLOCK(g_session.mutex);
    return -1;
  }
  node->next = NULL;
  node->data = data;
  node->count = count;
  node->consumed = 0;
  node->start_index = start_index;

  if (g_session.audio_tail == NULL) {
    g_session.audio_head = node;
  } else {
    g_session.audio_tail->next = node;
  }
  g_session.audio_tail = node;
  g_session.audio_frames += count;
  ATLAS_MUTEX_UNLOCK(g_session.mutex);
  return 0;
}

// Copies up to max frames from the FIFO into dst, freeing consumed nodes
// (mutex held; releases backpressure waiters via the cond). Returns the
// frame count copied. Shared by the Dart take_audio path and the playback
// device consumer.
static int32_t atlas_audio_pop_locked(int16_t* dst, int32_t max_frames) {
  int32_t copied = 0;
  atlas_audio_node_t* n = g_session.audio_head;
  while (n != NULL && copied < max_frames) {
    const int32_t avail = n->count - n->consumed;
    const int32_t take =
        (avail <= (max_frames - copied)) ? avail : (max_frames - copied);
    memcpy(dst + copied, n->data + n->consumed,
           (size_t)take * sizeof(int16_t));
    copied += take;
    n->consumed += take;
    if (n->consumed == n->count) {
      atlas_audio_node_t* next = n->next;
      free(n->data);
      free(n);
      g_session.audio_head = next;
      if (next == NULL) g_session.audio_tail = NULL;
      n = next;
    }
  }
  g_session.audio_frames -= copied;
  ATLAS_COND_SIGNAL(g_session.cond);  // release backpressure, if any
  return copied;
}

FFI_PLUGIN_EXPORT int32_t atlas_tts_take_audio(int16_t* dst,
                                               int32_t max_frames) {
  if (dst == NULL || max_frames <= 0) return ATLAS_ERR_INVALID_ARG;

  ATLAS_MUTEX_LOCK(g_session.mutex);
  const int32_t copied = atlas_audio_pop_locked(dst, max_frames);
  ATLAS_MUTEX_UNLOCK(g_session.mutex);
  return copied;
}

FFI_PLUGIN_EXPORT int32_t atlas_tts_queued_frames(void) {
  ATLAS_MUTEX_LOCK(g_session.mutex);
  const int64_t frames = g_session.audio_frames;
  ATLAS_MUTEX_UNLOCK(g_session.mutex);
  if (frames > 0x7FFFFFFF) return 0x7FFFFFFF;
  return (int32_t)frames;
}

// ---------------------------------------------------------------------------
// Playback device consumer â€” M3 host slice. The thread pulls the FIFO so
// Dart no longer polls with take_audio; CHUNK_DRAINED fires when the device
// actually played the utterance out. Mobile: Oboe/AVAudioEngine land with
// the platform builds, driven by the same condvar; only the device/loop
// functions below differ per platform.
//
// Windows host backend: winmm waveOut (no COM). WASAPI shared-mode was the
// first choice but CoCreateInstance(MMDeviceEnumerator) answers
// REGDB_E_CLASSNOTREG on hosts whose COM class registration is stripped
// (observed: AudioSrv running, HKCR\CLSID\{BCDE0395-...} absent); waveOut's
// device mapper needs no registry classes and exists back to the beginning
// of Windows. Session PCM is mono int16 at the session rate; the mapper
// handles device format differences.
//
// Lifecycle: one persistent thread started lazily by
// atlas_tts_enable_playback(1). The thread owns the device handle, applies
// pause via waveOutPause/Restart, and emits CHUNK_DRAINED itself once the
// FIFO is empty AND all in-flight device buffers finished AND the worker
// marked the request complete (render_done_id) â€” "played through the
// device", not merely queued.
//
// Session sample rate is sampled when the device is created; a later
// load_voice with a different rate requires disable+enable (documented in
// the header). When playback owns the drain, the worker does NOT emit
// CHUNK_DRAINED itself.
// ---------------------------------------------------------------------------
#if _WIN32
#include <mmsystem.h>

// Small queue keeps drain latency low; each buffer ~93 ms at 22050 Hz.
#define ATLAS_PLAYBACK_BUFFERS 6
#define ATLAS_PLAYBACK_BUFFER_FRAMES 2048

static DWORD WINAPI playback_loop(LPVOID arg) {
  (void)arg;

  HWAVEOUT hwo = NULL;
  int device_ok = 0;
  int paused_on_device = 0;
  WAVEFORMATEX fmt;
  ZeroMemory(&fmt, sizeof(fmt));
  fmt.wFormatTag = WAVE_FORMAT_PCM;
  fmt.nChannels = 1;
  fmt.nSamplesPerSec = g_session.sample_rate;
  fmt.wBitsPerSample = 16;
  fmt.nBlockAlign = 2;
  fmt.nAvgBytesPerSec = fmt.nSamplesPerSec * 2;

  const MMRESULT open =
      waveOutOpen(&hwo, WAVE_MAPPER, &fmt, 0, 0, CALLBACK_NULL);
  if (open != MMSYSERR_NOERROR) {
    // No usable device: the session keeps working for the take_audio
    // consumer path; this thread idles until playback is disabled again.
    fprintf(stderr, "atlas-playback: waveOutOpen failed, result=%lu\n",
            (unsigned long)open);
    hwo = NULL;
  } else {
    device_ok = 1;
  }

  WAVEHDR hdrs[ATLAS_PLAYBACK_BUFFERS];
  ZeroMemory(hdrs, sizeof(hdrs));
  int16_t* buffers[ATLAS_PLAYBACK_BUFFERS] = {0};
  if (device_ok) {
    for (int i = 0; i < ATLAS_PLAYBACK_BUFFERS; i++) {
      buffers[i] = malloc(sizeof(int16_t) * ATLAS_PLAYBACK_BUFFER_FRAMES);
      if (buffers[i] == NULL) {
        device_ok = 0;
        hwo = NULL;
        break;
      }
      hdrs[i].lpData = (LPSTR)buffers[i];
    }
  }

  while (1) {
    ATLAS_MUTEX_LOCK(g_session.mutex);
    if (g_session.playback_exit) {
      ATLAS_MUTEX_UNLOCK(g_session.mutex);
      break;
    }
    const int on = g_session.playback_requested;
    const int paused = g_session.playback_paused;
    // Playback paused at the device while gated off or user-paused. While
    // off, in-flight buffers hold (waveOutPause) instead of being dropped.
    const int kernel_paused = paused || !on;
    const int64_t queued = g_session.audio_frames;
    const int64_t done_id = g_session.render_done_id;
    const int cb_alive = g_session.cb != NULL;
    ATLAS_MUTEX_UNLOCK(g_session.mutex);
    if (device_ok && kernel_paused != paused_on_device) {
      if (kernel_paused) {
        waveOutPause(hwo);
      } else {
        waveOutRestart(hwo);
      }
      paused_on_device = kernel_paused;
    }

    if (!on) {
      Sleep(20);
      continue;
    }

    if (device_ok) {
      // Reap finished buffers so they become free again, and count how
      // many are still queued on the device.
      int in_flight = 0;
      for (int i = 0; i < ATLAS_PLAYBACK_BUFFERS; i++) {
        if (hdrs[i].dwFlags & WHDR_DONE) {
          waveOutUnprepareHeader(hwo, &hdrs[i], sizeof(WAVEHDR));
          hdrs[i].dwFlags = 0;
        }
        if (hdrs[i].dwFlags & WHDR_PREPARED) in_flight++;
      }

      // Fill every free buffer with FIFO audio. After waveOutWrite the
      // header stays WHDR_PREPARED until fully played (WHDR_DONE then set).
      for (int i = 0; i < ATLAS_PLAYBACK_BUFFERS; i++) {
        if (hdrs[i].dwFlags & WHDR_PREPARED) continue;  // parked on device
        int32_t pull = 0;
        ATLAS_MUTEX_LOCK(g_session.mutex);
        pull = atlas_audio_pop_locked(buffers[i],
                                      ATLAS_PLAYBACK_BUFFER_FRAMES);
        ATLAS_MUTEX_UNLOCK(g_session.mutex);
        if (pull == 0) break;  // FIFO dry for this tick
        hdrs[i].dwBufferLength = (DWORD)pull * 2;
        hdrs[i].dwFlags = 0;
        hdrs[i].dwLoops = 0;
        if (waveOutPrepareHeader(hwo, &hdrs[i], sizeof(WAVEHDR)) ==
                MMSYSERR_NOERROR &&
            waveOutWrite(hwo, &hdrs[i], sizeof(WAVEHDR)) ==
                MMSYSERR_NOERROR) {
          continue;
        }
        // Write failure: drop the chunk rather than spin on a broken
        // device; the worker keeps producing and the FIFO backpressure
        // (ATLAS_MAX_FIFO_FRAMES) bounds drift as usual.
        hdrs[i].dwFlags = 0;
        fprintf(stderr, "atlas-playback: waveOutWrite failed\n");
        break;
      }

      // Drained: the worker finished, the FIFO is empty, and everything
      // submitted to the device has fully played out.
      if (cb_alive && done_id != 0 && queued == 0 && in_flight == 0) {
        ATLAS_MUTEX_LOCK(g_session.mutex);
        g_session.render_done_id = 0;
        ATLAS_MUTEX_UNLOCK(g_session.mutex);
        post_event(ATLAS_EVENT_CHUNK_DRAINED, 0, 0, 0, 0, 0, 0, done_id);
      }
    }

    Sleep(5);
  }

  if (device_ok) {
    waveOutReset(hwo);  // cancel in-flight buffers on teardown
    for (int i = 0; i < ATLAS_PLAYBACK_BUFFERS; i++) {
      if (hdrs[i].dwFlags & WHDR_PREPARED) {
        waveOutUnprepareHeader(hwo, &hdrs[i], sizeof(WAVEHDR));
        hdrs[i].dwFlags = 0;
      }
    }
    waveOutClose(hwo);
  }
  for (int i = 0; i < ATLAS_PLAYBACK_BUFFERS; i++) free(buffers[i]);

  ATLAS_MUTEX_LOCK(g_session.mutex);
  g_session.playback_thread_created = 0;
  ATLAS_MUTEX_UNLOCK(g_session.mutex);
  return 0;
}
#elif defined(__ANDROID__)
// M3 Android slice: AAudio output stream — the same primitive the Oboe
// wrapper sits on, used directly to avoid a third-party build dependency.
// Loaded through dlopen("libaaudio.so") instead of -l: the gradle CMake
// sysroot pins the gradle minSdk (24) where aaudio benchmarks/headers do not
// exist, and a hard link would make the whole plugin .so fail to load below
// API 26. Dynamic resolution keeps that floor: missing libaaudio degrades
// this backend to "device_ok = 0" (take_audio path) instead of breaking the
// plugin.
//
// Model parity with the winmm slice: one persistent condvar-driven thread;
// AAudio runs a PULL callback that consumes the FIFO at device pace; the
// pump applies pause via requestPause/Start and emits CHUNK_DRAINED when
// the FIFO + the render are both drained (device buffer lag bounded by the
// internal AAudio buffer, ~tens of ms).
//
// Sample rate is requested explicitly (22050): AudioFlinger resamples
// non-native stream rates into the device mix for us.
#include <dlfcn.h>
#include <pthread.h>

// Minimal AAudio ABI subset (values from aaudio/AAudio.h, stable API 26).
#define AA_DIR_OUTPUT 0
#define AAUDIO_OK 0
#define AA_FORMAT_PCM_I16 1
// Performance mode enum (aaudio.h): NONE=10, POWER_SAVING=11, LOW_LATENCY=12.
// 0 is NOT valid here ("validate unknown performance mode" -> -898).
#define AA_PERF_NONE 10
#define AA_RESULT_CONTINUE 0
// Stream states (public enum order, API 26+):
#define AA_STATE_UNINITIALIZED 0
#define AA_STATE_OPEN 1
#define AA_STATE_STARTING 2
#define AA_STATE_STARTED 3
#define AA_STATE_PAUSING 4
#define AA_STATE_PAUSED 5
#define AA_STATE_FLUSHING 6
#define AA_STATE_FLUSHED 7
#define AA_STATE_STOPPING 8
#define AA_STATE_STOPPED 9
#define AA_STATE_CLOSING 10
#define AA_STATE_CLOSED 11
#define AA_STATE_DISCONNECTED 12

typedef struct atlas_aa_builder atlas_aa_builder_t;
typedef struct atlas_aa_stream atlas_aa_stream_t;
typedef int32_t (*atlas_aa_data_cb_t)(atlas_aa_stream_t*, void*, int16_t*,
                                      int32_t);

typedef struct {
  void* lib;
  int ok;
  int32_t (*createBuilder)(atlas_aa_builder_t**);
  void (*setDirection)(atlas_aa_builder_t*, int32_t);
  void (*setSampleRate)(atlas_aa_builder_t*, int32_t);
  void (*setChannelCount)(atlas_aa_builder_t*, int32_t);
  void (*setFormat)(atlas_aa_builder_t*, int32_t);
  void (*setPerformanceMode)(atlas_aa_builder_t*, int32_t);
  void (*setDataCallback)(atlas_aa_builder_t*, atlas_aa_data_cb_t, void*);
  int32_t (*open)(atlas_aa_builder_t*, atlas_aa_stream_t**);
  int32_t (*requestStart)(atlas_aa_stream_t*);
  int32_t (*requestPause)(atlas_aa_stream_t*);
  int32_t (*requestStop)(atlas_aa_stream_t*);
  int32_t (*getState)(atlas_aa_stream_t*);
  int32_t (*close)(atlas_aa_stream_t*);
  int32_t (*deleteBuilder)(atlas_aa_builder_t*);
} atlas_aa_api_t;

static atlas_aa_api_t g_aa;

static int atlas_aa_load(void) {
  if (g_aa.ok) return 1;
  // Match the system's actual link name: libaaudio.so is public since 26.
  g_aa.lib = dlopen("libaaudio.so", RTLD_NOW | RTLD_LOCAL);
  if (g_aa.lib == NULL) return 0;

#define AA_SYM(field, name)                                        \
  do {                                                             \
    void* sym = dlsym(g_aa.lib, name);                             \
    if (sym == NULL) goto fail;                                    \
    *(void**)&g_aa.field = sym;                                    \
  } while (0)

  AA_SYM(createBuilder, "AAudio_createStreamBuilder");
  AA_SYM(setDirection, "AAudioStreamBuilder_setDirection");
  AA_SYM(setSampleRate, "AAudioStreamBuilder_setSampleRate");
  AA_SYM(setChannelCount, "AAudioStreamBuilder_setChannelCount");
  AA_SYM(setFormat, "AAudioStreamBuilder_setFormat");
  AA_SYM(setPerformanceMode, "AAudioStreamBuilder_setPerformanceMode");
  AA_SYM(setDataCallback, "AAudioStreamBuilder_setDataCallback");
  AA_SYM(open, "AAudioStreamBuilder_openStream");
  AA_SYM(requestStart, "AAudioStream_requestStart");
  AA_SYM(requestPause, "AAudioStream_requestPause");
  AA_SYM(requestStop, "AAudioStream_requestStop");
  AA_SYM(getState, "AAudioStream_getState");
  AA_SYM(close, "AAudioStream_close");
  AA_SYM(deleteBuilder, "AAudioStreamBuilder_delete");
#undef AA_SYM
  g_aa.ok = 1;
  return 1;
fail:
  dlclose(g_aa.lib);
  g_aa.lib = NULL;
  return 0;
}

// Real-time callback owned by AAudio: pure consumer of the FIFO. Returns
// silence when the queue is dry so the stream keeps running instead of
// dying on an underrun (drained emission is driven by the pump thread).
static int32_t atlas_aa_callback(atlas_aa_stream_t* stream, void* userData,
                                  int16_t* data, int32_t frames) {
  (void)stream;
  (void)userData;
  int32_t pulled = 0;
  if (frames > 0) {
    ATLAS_MUTEX_LOCK(g_session.mutex);
    pulled = atlas_audio_pop_locked(data, frames);
    ATLAS_MUTEX_UNLOCK(g_session.mutex);
  }
  // Zero-fill anything the FIFO did not have so the device never underruns.
  for (int32_t i = pulled; i < frames; i++) {
    data[i] = 0;
  }
  return AA_RESULT_CONTINUE;
}

// Device phases this pump commands (dev_state tracks what we last asked the
// device for, so no request is repeated).
enum { AA_DEV_IDLE = 0, AA_DEV_RUNNING = 1, AA_DEV_PAUSED = 2 };

static void* playback_loop(void* arg) {
  (void)arg;

  int device_ok = atlas_aa_load();
  if (!device_ok) {
    // API < 26 or exotic ROM: idle until playback is disabled again; the
    // take_audio consumer path keeps working.
    fprintf(stderr, "atlas-playback: libaaudio.so unavailable\n");
  }

  atlas_aa_stream_t* stream = NULL;
  int dev_state = AA_DEV_IDLE;

  while (1) {
    ATLAS_MUTEX_LOCK(g_session.mutex);
    if (g_session.playback_exit) {
      ATLAS_MUTEX_UNLOCK(g_session.mutex);
      break;
    }
    const int on = g_session.playback_requested;
    const int paused = g_session.playback_paused;
    const int64_t queued = g_session.audio_frames;
    const int64_t done_id = g_session.render_done_id;
    const int cb_alive = g_session.cb != NULL;
    ATLAS_MUTEX_UNLOCK(g_session.mutex);

    if (!on) {
      // Park the device: no frames may arrive until playback is re-enabled.
      if (device_ok && stream != NULL && dev_state != AA_DEV_IDLE) {
        g_aa.requestStop(stream);
        dev_state = AA_DEV_IDLE;
      }
      usleep(20000);
      continue;
    }

    // Lazily open a fresh stream whenever audio is pending; idle playback
    // (no utterance) keeps no stream open.
    if (device_ok && stream == NULL && queued > 0) {
      atlas_aa_builder_t* builder = NULL;
      if (g_aa.createBuilder(&builder) == AAUDIO_OK && builder != NULL) {
        g_aa.setDirection(builder, AA_DIR_OUTPUT);
        g_aa.setSampleRate(builder, g_session.sample_rate);
        g_aa.setChannelCount(builder, 1);
        g_aa.setFormat(builder, AA_FORMAT_PCM_I16);
        g_aa.setPerformanceMode(builder, AA_PERF_NONE);
        g_aa.setDataCallback(builder, atlas_aa_callback, NULL);
        if (g_aa.open(builder, &stream) != AAUDIO_OK) {
          fprintf(stderr, "atlas-playback: AAudio openStream failed\n");
          stream = NULL;
        }
        g_aa.deleteBuilder(builder);
      } else {
        fprintf(stderr, "atlas-playback: AAudio builder failed\n");
      }
      if (stream != NULL) dev_state = AA_DEV_IDLE;  // stopped until started
    }

    // Device phase machine. getState also detects headphone unplug etc.
    // A fresh start only happens with frames actually pending: an empty
    // stream would sit RUNNING pulling zero-filled audio at full power.
    if (device_ok && stream != NULL) {
      const int32_t aa_state = g_aa.getState(stream);
      if (aa_state == AA_STATE_DISCONNECTED) {
        // Drop the dead stream; a pending queue reopens on a later tick.
        g_aa.close(stream);
        stream = NULL;
        dev_state = AA_DEV_IDLE;
      } else if (paused && dev_state == AA_DEV_RUNNING) {
        g_aa.requestPause(stream);
        dev_state = AA_DEV_PAUSED;
      } else if (!paused && queued > 0 && dev_state != AA_DEV_RUNNING) {
        // Covers fresh-stream start and resume after pause. requestStart
        // on a paused or stopped stream both lead back to STARTED.
        g_aa.requestStart(stream);
        dev_state = AA_DEV_RUNNING;
      }
    }

    // Drained: worker finished AND the FIFO is empty. Play-out bookkeeping
    // matches the winmm slice (the callback has consumed everything that was
    // queued); residual device buffer delay is bounded by AAudio's internal
    // buffer (tens of ms) and accepted like winmm's in-flight tail.
    if (cb_alive && done_id != 0 && queued == 0) {
      ATLAS_MUTEX_LOCK(g_session.mutex);
      g_session.render_done_id = 0;
      ATLAS_MUTEX_UNLOCK(g_session.mutex);
      post_event(ATLAS_EVENT_CHUNK_DRAINED, 0, 0, 0, 0, 0, 0, done_id);
      // Nothing new until the next request parks the stream again.
      if (device_ok && stream != NULL) {
        g_aa.requestStop(stream);
        dev_state = AA_DEV_IDLE;
      }
    }

    usleep(5000);
  }

  if (device_ok) {
    if (stream != NULL) {
      g_aa.requestStop(stream);
      g_aa.close(stream);
    }
    dlclose(g_aa.lib);
    g_aa.lib = NULL;
    g_aa.ok = 0;
  }

  ATLAS_MUTEX_LOCK(g_session.mutex);
  g_session.playback_thread_created = 0;
  ATLAS_MUTEX_UNLOCK(g_session.mutex);
  return NULL;
}
#endif  // platform switch for the playback backends

// ---------------------------------------------------------------------------
// Voice packs (M2). A pack dir follows the sherpa-onnx tts-models layout:
//   <voice>.onnx, tokens.txt, espeak-ng-data/
// A directory without a neural model is an M1 sine dev pack (tests and
// experiments only). speak() before any pack load answers ATLAS_ERR_NOT_READY.
// ---------------------------------------------------------------------------
enum {
  ATLAS_VOICE_NONE = 0,    // no pack loaded
  ATLAS_VOICE_SINE = 1,    // M1 dev fallback
  ATLAS_VOICE_NEURAL = 2,  // sherpa-onnx VITS
};

#define ATLAS_PATH_MAX 1024

static char* atlas_pack_join(const char* dir, const char* name) {
  const size_t need = strlen(dir) + strlen(name) + 2;
  char* out = malloc(need);
  if (out == NULL) return NULL;
  snprintf(out, need, "%s/%s", dir, name);
  return out;
}

// ASCII-only case-insensitive suffix check; pack filenames are ASCII.
static int atlas_ends_with_ci(const char* s, const char* suffix) {
  const size_t ls = strlen(s);
  const size_t lf = strlen(suffix);
  if (lf > ls) return 0;
  for (size_t i = 0; i < lf; i++) {
    char a = s[ls - lf + i];
    const char b = suffix[i];
    if (a >= 'A' && a <= 'Z') a = (char)(a - 'A' + 'a');
    if (a != b) return 0;
  }
  return 1;
}

// Malloc'd path of the first "<name>.onnx" in dir (skipping .onnx.json
// configs), or NULL when the dir has no neural model. Caller frees.
static char* atlas_find_voice_model(const char* dir) {
#ifdef _WIN32
  char pattern[ATLAS_PATH_MAX];
  if (strlen(dir) + 9 > sizeof(pattern)) return NULL;
  snprintf(pattern, sizeof(pattern), "%s\\*.onnx*", dir);
  WIN32_FIND_DATAA fd;
  HANDLE h = FindFirstFileA(pattern, &fd);
  if (h == INVALID_HANDLE_VALUE) return NULL;
  char* found = NULL;
  do {
    const char* name = fd.cFileName;
    if (atlas_ends_with_ci(name, ".onnx.json")) continue;
    if (atlas_ends_with_ci(name, ".onnx")) {
      found = atlas_pack_join(dir, name);
      break;
    }
  } while (FindNextFileA(h, &fd));
  FindClose(h);
  return found;
#else
  DIR* d = opendir(dir);
  if (d == NULL) return NULL;
  char* found = NULL;
  struct dirent* e;
  while ((e = readdir(d)) != NULL) {
    if (atlas_ends_with_ci(e->d_name, ".onnx.json")) continue;
    if (atlas_ends_with_ci(e->d_name, ".onnx")) {
      found = atlas_pack_join(dir, e->d_name);
      break;
    }
  }
  closedir(d);
  return found;
#endif
}

#ifdef ATLAS_TTS_WITH_SHERPA
// Opens the sherpa-onnx session for a VITS pack and publishes
// (sherpa, voice_mode = NEURAL, sample_rate = model rate) under the mutex.
// Synchronous and heavy (~seconds): load_voice stays a one-time call until
// M4 makes pack loading asynchronous.
static int atlas_sherpa_open(const char* dir, const char* model) {
  char* tokens = atlas_pack_join(dir, "tokens.txt");
  char* espeak = atlas_pack_join(dir, "espeak-ng-data");
  if (tokens == NULL || espeak == NULL) {
    free(tokens);
    free(espeak);
    return ATLAS_ERR_INTERNAL;
  }
  SherpaOnnxOfflineTtsConfig cfg;
  memset(&cfg, 0, sizeof(cfg));
  cfg.model.num_threads = 2;
  cfg.model.provider = "cpu";
  cfg.model.debug = 0;
  cfg.model.vits.model = model;
  cfg.model.vits.tokens = tokens;
  cfg.model.vits.data_dir = espeak;
  // sherpa-onnx copies all config strings during create, so the local
  // buffers may die right after.
  const SherpaOnnxOfflineTts* tts = SherpaOnnxCreateOfflineTts(&cfg);
  free(tokens);
  free(espeak);
  if (tts == NULL) return ATLAS_ERR_INTERNAL;

  const int32_t rate = SherpaOnnxOfflineTtsSampleRate(tts);
  ATLAS_MUTEX_LOCK(g_session.mutex);
  g_session.sherpa = tts;
  g_session.voice_mode = ATLAS_VOICE_NEURAL;
  if (rate > 0) g_session.sample_rate = rate;
  ATLAS_MUTEX_UNLOCK(g_session.mutex);

  post_event(ATLAS_EVENT_VOICE_READY, 0, rate, 0, 0, 0, 0, 0);
  return ATLAS_OK;
}
#endif

// Detaches the loaded voice from the session (mutex held). Returns the
// neural engine handle if one was live â€” the caller destroys it outside the
// mutex (sherpa destruction blocks for a while). NULL when nothing/sine.
static void* atlas_voice_take_locked(void) {
#ifdef ATLAS_TTS_WITH_SHERPA
  const SherpaOnnxOfflineTts* v = g_session.sherpa;
  g_session.sherpa = NULL;
#else
  void* v = NULL;
#endif
  g_session.voice_mode = ATLAS_VOICE_NONE;
  return (void*)v;
}

static void atlas_destroy_voice_handle(void* handle) {
#ifdef ATLAS_TTS_WITH_SHERPA
  if (handle != NULL) {
    SherpaOnnxDestroyOfflineTts((const SherpaOnnxOfflineTts*)handle);
  }
#else
  (void)handle;
#endif
}

// ---------------------------------------------------------------------------
// Renderer (M1: sine placeholder). M2 replaces render_transform_sample with
// VITS output; the chunk/event pacing below stays structurally the same.
// ---------------------------------------------------------------------------

// Per-sample waveform generator. amplitude in int16 headroom, in [0, 32767].
static int16_t render_transform_sample(int64_t absolute_sample, float volume) {
  double phase = 2.0 * 3.14159265358979323846 * ATLAS_SINE_HZ *
                 ((double)absolute_sample / (double)g_session.sample_rate);
  double value = (double)ATLAS_SINE_AMPLITUDE * sin(phase);
  if (volume < 0.0f) volume = 0.0f;
  if (volume > 1.0f) volume = 1.0f;
  value *= (double)volume;
  if (value > 32767.0) value = 32767.0;
  if (value < -32768.0) value = -32768.0;
  return (int16_t)value;
}

static int64_t ms_to_samples(double ms) {
  return (int64_t)(ms / 1000.0 * (double)g_session.sample_rate + 0.5);
}

// Tokenize text into word records (M1: split on whitespace, word = maximal
// non-space run; sample positions assigned proportionally by character span â€”
// placeholder pacing until VITS durations exist in M2).
typedef struct {
  int32_t offset;  // chunk-local code-unit offset
  int32_t length;
  int64_t start_sample;
} atlas_word_plan_t;

static atlas_word_plan_t* build_word_plan(const char* text,
                                          int64_t total_samples,
                                          int* out_count) {
  const size_t len = strlen(text);
  const int64_t span = len > 0 ? (int64_t)len : 1;
  const double samples_per_char = (double)total_samples / (double)span;

  // Upper bound on words = number of characters.
  atlas_word_plan_t* words = malloc(sizeof(atlas_word_plan_t) * (len + 1));
  if (words == NULL) return NULL;
  int count = 0;
  int64_t i = 0;
  while (i < (int64_t)len) {
    while (i < (int64_t)len &&
           (text[i] == ' ' || text[i] == '\t' || text[i] == '\r' ||
            text[i] == '\n')) {
      i++;
    }
    if (i >= (int64_t)len) break;
    const int64_t start = i;
    while (i < (int64_t)len &&
           !(text[i] == ' ' || text[i] == '\t' || text[i] == '\r' ||
             text[i] == '\n')) {
      i++;
    }
    words[count].offset = (int32_t)start;
    words[count].length = (int32_t)(i - start);
    words[count].start_sample = (int64_t)((double)start * samples_per_char);
    count++;
  }
  *out_count = count;
  return words;
}

static void emit_word_event(int32_t offset, int32_t length, int64_t request_id) {
  post_event(ATLAS_EVENT_WORD, 0, 0, 0, 0, offset, length, request_id);
}

static void emit_audio_chunk_event(int32_t frames, int64_t start_index,
                                   int64_t request_id) {
  post_event(ATLAS_EVENT_AUDIO_CHUNK, 0, g_session.sample_rate, frames,
             (int32_t)start_index, 0, 0, request_id);
}

static void emit_drained(int64_t request_id) {
  post_event(ATLAS_EVENT_CHUNK_DRAINED, 0, 0, 0, 0, 0, 0, request_id);
}

#ifdef ATLAS_TTS_WITH_SHERPA
// Per-request state threaded through the sherpa-onnx incremental callback.
typedef struct atlas_vits_ctx_t {
  float volume;
  int64_t request_id;
  int64_t start_index;    // utterance-global position of the next chunk
  int cancelled;          // stop requested: generation aborts, silently
  int failed;             // internal failure: worker posts one ERROR
  const atlas_word_plan_t* words;
  int word_count;
  int next_word;
  double text_len;        // UTF-8 byte length (offsets are byte-based, like M1)
} atlas_vits_ctx_t;

// sherpa-onnx generation callback: runs on the worker thread inside
// SherpaOnnxOfflineTtsGenerateWithConfig. Converts float PCM to clamped
// int16 (per-request volume applied), feeds the FIFO (blocking on
// backpressure), and emits WORD/AUDIO_CHUNK events in stream order.
// Return 0 aborts generation â€” the cancellation path.
static int32_t atlas_vits_chunk_cb(const float* samples, int32_t n,
                                   float progress, void* arg) {
  atlas_vits_ctx_t* ctx = arg;

  if (!ctx->cancelled && ctx->words != NULL) {
    while (ctx->next_word < ctx->word_count) {
      const double frac =
          ctx->text_len > 0.0
              ? (double)ctx->words[ctx->next_word].offset / ctx->text_len
              : 1.0;
      if (frac > (double)progress) break;
      emit_word_event(ctx->words[ctx->next_word].offset,
                      ctx->words[ctx->next_word].length, ctx->request_id);
      ctx->next_word++;
    }
  }
  if (ctx->cancelled) return 0;
  if (n <= 0) return 1;

  int16_t* pcm = malloc(sizeof(int16_t) * (size_t)n);
  if (pcm == NULL) {
    ctx->failed = 1;
    ctx->cancelled = 1;
    return 0;
  }
  float volume = ctx->volume;
  if (volume < 0.0f) volume = 0.0f;
  if (volume > 1.0f) volume = 1.0f;
  for (int32_t i = 0; i < n; i++) {
    const float v = samples[i] * 32767.0f * volume;
    if (v > 32767.0f) {
      pcm[i] = 32767;
    } else if (v < -32768.0f) {
      pcm[i] = -32768;
    } else {
      pcm[i] = (int16_t)v;
    }
  }
  const int pushed = audio_queue_push(pcm, n, ctx->start_index);
  if (pushed != 0) {
    // push reports cancellation (1) or failure (-1); neither is queued.
    free(pcm);
    if (pushed < 0) ctx->failed = 1;
    ctx->cancelled = 1;
    return 0;
  }
  emit_audio_chunk_event(n, ctx->start_index, ctx->request_id);
  ctx->start_index += n;
  return 1;
}
#endif

// Worker: renders the current request into chunks, queues PCM, emits
// WORD FOLLOWED-AT-PACE + AUDIO_CHUNK events, then CHUNK_DRAINED. Watches
// stop_requested. Guarantees, before exiting: request_in_flight = 0 and
// worker_live = 0 (both under the mutex, then cond signalled).
#if _WIN32
static DWORD WINAPI render_worker(LPVOID arg)
#else
static void* render_worker(void* arg)
#endif
{
  (void)arg;
  ATLAS_MUTEX_LOCK(g_session.mutex);

  // Ownership of g_session.text transfers to the worker (freed below under
  // the mutex); mutex is dropped during the render loop so stop() can poke
  // stop_requested.
  char* text = g_session.text;
  const float length_scale =
      g_session.length_scale > 0.0f ? g_session.length_scale : 1.0f;
  const float volume = g_session.volume;
  const int64_t request_id = g_session.request_id;
  const int mode = g_session.voice_mode;
#ifdef ATLAS_TTS_WITH_SHERPA
  const SherpaOnnxOfflineTts* const sherpa = g_session.sherpa;
#endif
  const size_t text_len = text != NULL ? strlen(text) : 0;
  ATLAS_MUTEX_UNLOCK(g_session.mutex);

  if (text == NULL) {
    post_error(ATLAS_ERR_INTERNAL, request_id);
    ATLAS_MUTEX_LOCK(g_session.mutex);
    g_session.worker_live = 0;
    g_session.request_in_flight = 0;
    ATLAS_COND_SIGNAL(g_session.cond);
    ATLAS_MUTEX_UNLOCK(g_session.mutex);
    return 0;
  }

  int cancelled = 0;
  int word_count = 0;
  atlas_word_plan_t* words = NULL;
  int next_word = 0;

  if (mode == ATLAS_VOICE_NEURAL) {
#ifdef ATLAS_TTS_WITH_SHERPA
    // M2: VITS generation. start_sample in the plan is a sine-path concept;
    // word pacing derives from generation progress, so pass a no-op span.
    words = build_word_plan(text, 0, &word_count);
    atlas_vits_ctx_t ctx = {
        .volume = volume,
        .request_id = request_id,
        .start_index = 0,
        .words = words,
        .word_count = word_count,
        .text_len = (double)text_len,
    };
    SherpaOnnxGenerationConfig gcfg;
    memset(&gcfg, 0, sizeof(gcfg));
    gcfg.sid = 0;
    gcfg.speed = length_scale >= 0.05f ? 1.0f / length_scale : 1.0f;
    const SherpaOnnxGeneratedAudio* audio =
        SherpaOnnxOfflineTtsGenerateWithConfig(sherpa, text, &gcfg,
                                               atlas_vits_chunk_cb, &ctx);
    if (audio != NULL) SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);
    if (ctx.failed) post_error(ATLAS_ERR_INTERNAL, request_id);
    cancelled = ctx.cancelled;
#else
    // Neural voice requested but the core was built without sherpa-onnx:
    // loud, explicit failure rather than a silent sine downgrade.
    post_error(ATLAS_ERR_INTERNAL, request_id);
    cancelled = 1;
#endif
  } else {
    // M1 sine dev path (also covers suspicious modes defensively).
    const double duration_ms =
        (double)text_len * ATLAS_MS_PER_CHAR * length_scale;
    const int64_t total_samples =
        ms_to_samples(duration_ms < 200.0 ? 200.0 : (duration_ms > 60000.0
                                                         ? 60000.0
                                                         : duration_ms));
    words = build_word_plan(text, total_samples, &word_count);
    int16_t* scratch = malloc(sizeof(int16_t) * ATLAS_CHUNK_FRAMES);
    int64_t rendered = 0;

    while (rendered < total_samples) {
      ATLAS_MUTEX_LOCK(g_session.mutex);
      const int stopping = g_session.stop_requested;
      ATLAS_MUTEX_UNLOCK(g_session.mutex);
      if (stopping) {
        cancelled = 1;
        break;
      }

      if (words != NULL) {
        while (next_word < word_count &&
               words[next_word].start_sample <= rendered) {
          emit_word_event(words[next_word].offset, words[next_word].length,
                          request_id);
          next_word++;
        }
      }

      const int32_t frames = (int32_t)((total_samples - rendered >
                                        (int64_t)ATLAS_CHUNK_FRAMES)
                                           ? ATLAS_CHUNK_FRAMES
                                           : (total_samples - rendered));
      for (int32_t j = 0; j < frames; j++) {
        scratch[j] = render_transform_sample(rendered + j, volume);
      }
      // audio_queue_push takes ownership of a fresh allocation ONLY on
      // success; on failure the buffer is still ours to free.
      int16_t* owned = malloc(sizeof(int16_t) * frames);
      if (owned != NULL) memcpy(owned, scratch, (size_t)frames * sizeof(int16_t));
      const int pushed = owned == NULL ? -1
                                       : audio_queue_push(owned, frames,
                                                          rendered);
      if (pushed != 0) {
        // push reports success (0), cancellation (1), or failure (-1). Only
        // the last is an error; stopping is the normal cancel path.
        free(owned);
        if (pushed < 0) post_error(ATLAS_ERR_INTERNAL, request_id);
        cancelled = 1;
        break;
      }
      emit_audio_chunk_event(frames, rendered, request_id);
      rendered += frames;
    }

    if (scratch != NULL) free(scratch);
  }

  if (!cancelled && words != NULL && next_word < word_count) {
    // Flush trailing words (sine: proportional start lies at/past the end;
    // neural: past the final progress tick).
    while (next_word < word_count) {
      emit_word_event(words[next_word].offset, words[next_word].length,
                      request_id);
      next_word++;
    }
  }

  if (words != NULL) free(words);

  ATLAS_MUTEX_LOCK(g_session.mutex);
  const int finished = !cancelled;
  free(g_session.text);
  g_session.text = NULL;
  g_session.worker_live = 0;
  g_session.request_in_flight = 0;
  // In playback mode the device consumer owns CHUNK_DRAINED: it fires once
  // the utterance is actually played out, flagged via render_done_id.
  const int playback_owns_drained = finished && g_session.playback_requested;
  if (playback_owns_drained) {
    g_session.render_done_id = request_id;
  }
  ATLAS_MUTEX_UNLOCK(g_session.mutex);

  ATLAS_COND_SIGNAL(g_session.cond);
  // Emit AFTER releasing the mutex: the callback may (albeit unusually)
  // re-enter take_audio/queued_frames, which lock this mutex.
  if (finished && !playback_owns_drained) emit_drained(request_id);
  return 0;
}

// ---------------------------------------------------------------------------
// Public ABI
// ---------------------------------------------------------------------------

FFI_PLUGIN_EXPORT int atlas_tts_init(const atlas_tts_config_t* config) {
  if (config == NULL || config->event_cb == NULL) return ATLAS_ERR_INVALID_ARG;

  ATLAS_MUTEX_LOCK(g_session.mutex);
  if (g_session.cb != NULL) {
    ATLAS_MUTEX_UNLOCK(g_session.mutex);
    return ATLAS_ERR_ALREADY_INIT;
  }
  g_session.cb = config->event_cb;
  g_session.user_data = config->user_data;
  g_session.sample_rate =
      config->sample_rate_hint > 0 ? config->sample_rate_hint
                                   : ATLAS_DEFAULT_SAMPLE_RATE;
  g_session.worker_live = 0;
  g_session.thread_created = 0;
  g_session.stop_requested = 0;
  g_session.request_in_flight = 0;
  g_session.text = NULL;
  g_session.playback_requested = 0;
  g_session.playback_paused = 0;
  g_session.playback_exit = 0;
  g_session.render_done_id = 0;
  g_session.playback_thread_created = 0;
  ATLAS_MUTEX_UNLOCK(g_session.mutex);
  return ATLAS_OK;
}

FFI_PLUGIN_EXPORT int atlas_tts_load_voice(const char* pack_dir) {
  if (g_session.cb == NULL) return ATLAS_ERR_NOT_INIT;
  if (pack_dir == NULL || pack_dir[0] == '\0') return ATLAS_ERR_INVALID_ARG;

  atlas_tts_unload_voice();  // pack switch: join worker, drop FIFO + engine

#ifdef ATLAS_TTS_WITH_SHERPA
  char* model = atlas_find_voice_model(pack_dir);
  if (model == NULL) {
    // No neural model in the dir: M1 sine dev pack (never ships).
    ATLAS_MUTEX_LOCK(g_session.mutex);
    g_session.voice_mode = ATLAS_VOICE_SINE;
    ATLAS_MUTEX_UNLOCK(g_session.mutex);
    post_event(ATLAS_EVENT_VOICE_READY, 0, 0, 0, 0, 0, 0, 0);
    return ATLAS_OK;
  }
  const int rc = atlas_sherpa_open(pack_dir, model);
  free(model);
  return rc;
#else
  // Built without the neural backend: real packs must not be silently
  // downgraded, so only the sine dev pack loads here and the caller sees
  // the failure loudly in the log/event stream.
  ATLAS_MUTEX_LOCK(g_session.mutex);
  g_session.voice_mode = ATLAS_VOICE_SINE;
  ATLAS_MUTEX_UNLOCK(g_session.mutex);
  post_event(ATLAS_EVENT_VOICE_READY, 0, 0, 0, 0, 0, 0, 0);
  return ATLAS_OK;
#endif
}

FFI_PLUGIN_EXPORT int atlas_tts_unload_voice(void) {
  if (g_session.cb == NULL) return ATLAS_ERR_NOT_INIT;
  atlas_tts_stop();  // joins the worker + drops queued audio.
  ATLAS_MUTEX_LOCK(g_session.mutex);
  void* stale = atlas_voice_take_locked();
  ATLAS_MUTEX_UNLOCK(g_session.mutex);
  atlas_destroy_voice_handle(stale);
  return ATLAS_OK;
}

FFI_PLUGIN_EXPORT int atlas_tts_speak(atlas_tts_request_t* req) {
  if (g_session.cb == NULL) return ATLAS_ERR_NOT_INIT;
  if (req == NULL || req->text == NULL) return ATLAS_ERR_INVALID_ARG;

  ATLAS_MUTEX_LOCK(g_session.mutex);
  if (g_session.voice_mode == ATLAS_VOICE_NONE) {
    ATLAS_MUTEX_UNLOCK(g_session.mutex);
    return ATLAS_ERR_NOT_READY;
  }
  if (g_session.request_in_flight) {
    ATLAS_MUTEX_UNLOCK(g_session.mutex);
    return ATLAS_ERR_BUSY;
  }
  char* copy = ATLAS_STRDUP(req->text);
  if (copy == NULL) {
    ATLAS_MUTEX_UNLOCK(g_session.mutex);
    return ATLAS_ERR_INTERNAL;
  }
  g_session.text = copy;
  g_session.length_scale = req->length_scale;
  g_session.noise_scale = req->noise_scale;
  g_session.volume = req->volume;
  g_session.request_id = req->request_id;
  g_session.stop_requested = 0;
  g_session.request_in_flight = 1;
  g_session.worker_live = 1;

  if (ATLAS_THREAD_CREATE(&g_session.thread, render_worker, NULL) != 0) {
    g_session.worker_live = 0;
    g_session.thread_created = 0;
    g_session.request_in_flight = 0;
    free(copy);
    g_session.text = NULL;
    ATLAS_MUTEX_UNLOCK(g_session.mutex);
    return ATLAS_ERR_THREAD;
  }
  g_session.thread_created = 1;
  ATLAS_MUTEX_UNLOCK(g_session.mutex);
  return ATLAS_OK;
}

FFI_PLUGIN_EXPORT int atlas_tts_stop(void) {
  if (g_session.cb == NULL) return ATLAS_ERR_NOT_INIT;

  ATLAS_MUTEX_LOCK(g_session.mutex);
  if (!g_session.request_in_flight) {
    audio_queue_drop_locked();
    g_session.render_done_id = 0;  // suppress a stale playback-side drained
    ATLAS_MUTEX_UNLOCK(g_session.mutex);
    return ATLAS_OK;
  }
  g_session.stop_requested = 1;
  // Wake both the worker and any backpressure wait so the finalize section
  // below runs promptly.
  ATLAS_COND_SIGNAL(g_session.cond);
  while (g_session.request_in_flight) {
    ATLAS_COND_WAIT(g_session.cond, g_session.mutex);
  }
  // The worker reached its final critical section: drop undelivered audio.
  audio_queue_drop_locked();
  g_session.render_done_id = 0;  // cancelled render never plays out
  ATLAS_MUTEX_UNLOCK(g_session.mutex);
  return ATLAS_OK;
}

FFI_PLUGIN_EXPORT int atlas_tts_pause(int on) {
  if (g_session.cb == NULL) return ATLAS_ERR_NOT_INIT;
  // M3: gates the playback device consumer while playback is active;
  // with playback off (take_audio path) it is accepted and has no effect.
#if defined(_WIN32) || defined(__ANDROID__)
  ATLAS_MUTEX_LOCK(g_session.mutex);
  g_session.playback_paused = (g_session.playback_requested && on) ? 1 : 0;
  ATLAS_MUTEX_UNLOCK(g_session.mutex);
#else
  (void)on;
#endif
  return ATLAS_OK;
}

FFI_PLUGIN_EXPORT int atlas_tts_enable_playback(int on) {
  if (g_session.cb == NULL) return ATLAS_ERR_NOT_INIT;
#if !defined(_WIN32) && !defined(__ANDROID__)
  (void)on;
  // M3 iOS: AVAudioEngine lands with the macOS-host build.
  return ATLAS_ERR_INTERNAL;
#else
  ATLAS_MUTEX_LOCK(g_session.mutex);
  if (on) {
    if (g_session.playback_thread_created) {
      g_session.playback_requested = 1;
      ATLAS_COND_SIGNAL(g_session.cond);
      ATLAS_MUTEX_UNLOCK(g_session.mutex);
      return ATLAS_OK;
    }
    g_session.playback_requested = 1;
    if (ATLAS_THREAD_CREATE(&g_session.playback_thread, playback_loop, NULL) !=
        0) {
      g_session.playback_requested = 0;
      ATLAS_MUTEX_UNLOCK(g_session.mutex);
      return ATLAS_ERR_THREAD;
    }
    g_session.playback_thread_created = 1;
    ATLAS_MUTEX_UNLOCK(g_session.mutex);
    return ATLAS_OK;
  }
  g_session.playback_requested = 0;
  g_session.playback_paused = 0;
  g_session.render_done_id = 0;
  ATLAS_MUTEX_UNLOCK(g_session.mutex);
  ATLAS_COND_SIGNAL(g_session.cond);
  return ATLAS_OK;
#endif
}

FFI_PLUGIN_EXPORT void atlas_tts_shutdown(void) {
  if (g_session.cb == NULL) return;
  atlas_tts_stop();
  atlas_tts_unload_voice();  // stops worker again (no-op) + frees the engine

  // Wind the playback device consumer down BEFORE the event callback dies:
  // its threads use the callback and the cond.
  ATLAS_MUTEX_LOCK(g_session.mutex);
  const int was_playback = g_session.playback_thread_created;
  const ATLAS_THREAD playback_handle = g_session.playback_thread;
  g_session.playback_thread_created = 0;
  if (was_playback) {
    g_session.playback_exit = 1;
    g_session.playback_requested = 0;
    ATLAS_COND_SIGNAL(g_session.cond);
  }
  ATLAS_MUTEX_UNLOCK(g_session.mutex);
  if (was_playback) {
    ATLAS_THREAD_JOIN(playback_handle);
    ATLAS_THREAD_CLOSE(playback_handle);
  }

  ATLAS_MUTEX_LOCK(g_session.mutex);
  g_session.cb = NULL;
  g_session.user_data = NULL;
  g_session.sample_rate = 0;
  const int was_created = g_session.thread_created;
  g_session.thread_created = 0;
  g_session.worker_live = 0;  // stop() above guaranteed the worker finished.
  ATLAS_MUTEX_UNLOCK(g_session.mutex);

  if (was_created) {
    ATLAS_THREAD_JOIN(g_session.thread);
    ATLAS_THREAD_CLOSE(g_session.thread);
  }
}
