// Dart facade over the atlas_tts C core (see src/atlas_tts.h and the NTD
// design doc in lib/reader/speech/docs/).
//
// Scope: event+FIFO ABI with the M2 VITS renderer and the M3 host playback
// consumer. By default audio is drained from Dart via [takeAudio]; with
// [enablePlayback] the native playback device thread consumes the FIFO
// instead and CHUNK_DRAINED then marks real play-out (device pacing).
//
// Threading: the native core invokes the event callback from its worker
// thread; NativeCallable.listener defers delivery to the nearest Dart event
// loop, which is why the C ABI carries only copy-safe scalars and why audio
// flows through the native FIFO + takeAudio().
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'atlas_tts_bindings.dart' as native;

export 'atlas_tts_bindings.dart'
    show AtlasTtsBindings, AtlasTtsEventKind, AtlasTtsResult;

// ---------------------------------------------------------------------------
// Typed events (mirrors native.AtlasTtsEvent payloads)
// ---------------------------------------------------------------------------

sealed class TtsEvent {
  const TtsEvent(this.requestId);

  final int requestId;
}

/// A voice pack finished loading (load_voice completed).
class TtsVoiceReady extends TtsEvent {
  const TtsVoiceReady() : super(0);
}

/// Word boundary at chunk-local [offset] into the utterance text.
class TtsWordBoundary extends TtsEvent {
  const TtsWordBoundary({
    required this.offset,
    required this.length,
    required int requestId,
  }) : super(requestId);

  final int offset;
  final int length;
}

/// Rendered PCM entered the native FIFO. Drain with [AtlasTts.takeAudio].
class TtsAudioQueued extends TtsEvent {
  const TtsAudioQueued({
    required this.frames,
    required this.startIndex,
    required this.sampleRate,
    required int requestId,
  }) : super(requestId);

  final int frames;
  final int startIndex;
  final int sampleRate;
}

/// The request is fully delivered to the FIFO (M1) / played (M3).
class TtsChunkDrained extends TtsEvent {
  const TtsChunkDrained({required int requestId}) : super(requestId);
}

/// Failure inside the core. [code] is an ATLAS_ERR_* value.
class TtsError extends TtsEvent {
  const TtsError({required this.code, required int requestId})
      : super(requestId);

  final int code;
}

// ---------------------------------------------------------------------------
// Facade
// ---------------------------------------------------------------------------

/// Single-session controller for the atlas_tts native core.
///
/// Where Dart can block, calls run on the calling isolate; heavy work
/// (initialization, voice loading, future ONNX inference) lives on native
/// threads, and the isolate that owns this object should be a background
/// isolate when wired into the speech driver (NTD §3.2).
class AtlasTts {
  AtlasTts._() : _bindings = bindingsFactory();

  /// Initializes the native session. One live session per process.
  ///
  /// Returns null on success, or the ATLAS_ERR_* code on failure.
  static int? initialize({int sampleRateHint = 0}) {
    assert(_instance == null, 'atlas_tts: one live session per process');
    final session = AtlasTts._();
    final result = session._init(sampleRateHint);
    if (result != native.AtlasTtsResult.ok) return result;
    _instance = session;
    return null;
  }

  /// The active session, or null before the first [initialize] call.
  static AtlasTts? get instance => _instance;

  static AtlasTts? _instance;

  final native.AtlasTtsBindings _bindings;

  /// Injectable for tests: the native smoke test points this at the locally
  /// built test dylib before [initialize].
  static native.AtlasTtsBindings Function() bindingsFactory = _loadBindings;

  static native.AtlasTtsBindings _loadBindings() {
    const libName = 'atlas_tts';
    final DynamicLibrary dylib;
    if (Platform.isMacOS || Platform.isIOS) {
      dylib = DynamicLibrary.open('$libName.framework/$libName');
    } else if (Platform.isAndroid || Platform.isLinux) {
      dylib = DynamicLibrary.open('lib$libName.so');
    } else if (Platform.isWindows) {
      dylib = DynamicLibrary.open('$libName.dll');
    } else {
      throw UnsupportedError(
          'atlas_tts: unsupported platform ${Platform.operatingSystem}');
    }
    return native.AtlasTtsBindings(dylib);
  }

  NativeCallable<native.AtlasTtsEventCbNative>? _eventCallable;
  final _events = StreamController<TtsEvent>.broadcast();

  /// Stream of typed core events. Failures inside the core (e.g. render
  /// failure) arrive as [TtsError]; do not throw out of consumer handlers.
  Stream<TtsEvent> get events => _events.stream;

  /// Sample rate the session renders at (0 defaults to 22050).
  int sampleRate = 0;

  int _init(int sampleRateHint) {
    final callable =
        NativeCallable<native.AtlasTtsEventCbNative>.listener(_onNativeEvent);
    final config = calloc<native.AtlasTtsConfig>();
    try {
      config.ref.sampleRateHint = sampleRateHint;
      config.ref.eventCb = callable.nativeFunction;
      config.ref.userData = nullptr;


      final code = _bindings.init(config);
      if (code == native.AtlasTtsResult.ok) {
        _eventCallable = callable; // keep alive
        sampleRate = sampleRateHint > 0 ? sampleRateHint : 22050;
        return native.AtlasTtsResult.ok;
      }
      callable.close(); // no session — drop the listener
      return code;
    } finally {
      calloc.free(config);
    }
  }

  void _onNativeEvent(
    int kind,
    int errorCode,
    int sampleRate,
    int sampleCount,
    int sampleIndex,
    int textOffset,
    int textLength,
    int requestId,
    Pointer<Void> userData,
  ) {
    switch (kind) {
      case native.AtlasTtsEventKind.voiceReady:
        _events.add(const TtsVoiceReady());
      case native.AtlasTtsEventKind.word:
        _events.add(TtsWordBoundary(
          offset: textOffset,
          length: textLength,
          requestId: requestId,
        ));
      case native.AtlasTtsEventKind.audioChunk:
        _events.add(TtsAudioQueued(
          frames: sampleCount,
          startIndex: sampleIndex,
          sampleRate: sampleRate,
          requestId: requestId,
        ));
      case native.AtlasTtsEventKind.chunkDrained:
        _events.add(TtsChunkDrained(requestId: requestId));
      case native.AtlasTtsEventKind.error:
        _events.add(TtsError(code: errorCode, requestId: requestId));
      default:
        // Unknown kind: tolerate forward-compatible ABIs silently.
        break;
    }
  }

  /// Loads a voice pack directory. The [TtsVoiceReady] event follows on
  /// [events] once the core is ready for [speak].
  int loadVoice(String packDir) {
    final textNative = packDir.toNativeUtf8();
    try {
      return _bindings.loadVoice(textNative.cast<Uint8>());
    } finally {
      calloc.free(textNative);
    }
  }

  int unloadVoice() => _bindings.unloadVoice();

  /// Starts rendering [text]. Returns immediately; results arrive on [events].
  /// Returns one of [native.AtlasTtsResult]; `errBusy` means a render is
  /// already in flight — call [stop] first.
  int speak(
    String text, {
    double lengthScale = 1.0,
    double noiseScale = 0.667,
    double volume = 1.0,
    int requestId = 0,
  }) {
    final textNative = text.toNativeUtf8();
    final req = calloc<native.AtlasTtsRequest>();
    try {
      req.ref.text = textNative.cast<Uint8>();
      req.ref.lengthScale = lengthScale;
      req.ref.noiseScale = noiseScale;
      req.ref.volume = volume;
      req.ref.requestId = requestId;
      return _bindings.speak(req);
    } finally {
      calloc.free(req);
      calloc.free(textNative);
    }
  }

  /// Drains up to [maxFrames] mono int16 samples from the native FIFO,
  /// oldest first. Returns null on argument error, otherwise a (possibly
  /// shorter) list — empty when nothing is queued yet.
  Int16List? takeAudio(int maxFrames) {
    if (maxFrames <= 0) return null;
    final dst = calloc<Int16>(maxFrames);
    try {
      final copied = _bindings.takeAudio(dst, maxFrames);
      if (copied <= 0) return Int16List(0);
      final out = Int16List(copied);
      out.setAll(0, dst.asTypedList(copied));
      return out;
    } finally {
      calloc.free(dst);
    }
  }

  /// Queued mono samples awaiting [takeAudio]. Diagnostics/backpressure only.
  int get queuedFrames => _bindings.queuedFrames();

  /// Cancels the in-flight render and drops queued audio.
  int stop() => _bindings.stopFn();

  /// Accepted since M1; with the playback device consumer active this
  /// pauses/resumes device pumping, otherwise it has no effect (M3).
  int pause(bool on) => _bindings.pauseFn(on ? 1 : 0);

  /// Hands FIFO consumption to the built-in playback device (M3). When
  /// enabled, CHUNK_DRAINED marks the utterance played out and [takeAudio]
  /// must not be used concurrently. Returns one of [native.AtlasTtsResult];
  /// errInternal means the platform device backend is not compiled in.
  int enablePlayback(bool on) => _bindings.enablePlaybackFn(on ? 1 : 0);

  /// Tears down the native session permanently. Invalidates this object.
  void shutdown() {
    _bindings.shutdownFn();
    _eventCallable?.close();
    _eventCallable = null;
    if (_events.isClosed) return;
    _events.close();
    if (_instance == this) _instance = null;
  }
}
