// dart:ffi bindings for atlas_tts/src/atlas_tts.h.
//
// Hand-maintained until libclang is available for ffigen (see ffigen.yaml for
// the intended regeneration). Layout must match the C ABI exactly; the native
// smoke test (test/atlas_tts_native_test.dart) pins field semantics.
//
// Generation rules: do not reorder struct fields or change pragma widths;
// update together with the header, then run the native smoke test.
import 'dart:ffi';

// Event kinds — mirror AtlasTtsEventKind in atlas_tts.h.
abstract final class AtlasTtsEventKind {
  static const int voiceReady = 1;
  static const int word = 2;
  static const int audioChunk = 3;
  static const int chunkDrained = 4;
  static const int error = 5;
}

// Return codes — mirror the anonymous enum in atlas_tts.h.
abstract final class AtlasTtsResult {
  static const int ok = 0;
  static const int errNotInit = -1;
  static const int errAlreadyInit = -2;
  static const int errInvalidArg = -3;
  static const int errNotReady = -4;
  static const int errBusy = -5;
  static const int errThread = -6;
  static const int errOverflow = -7;
  static const int errInternal = -8;
}

final class AtlasTtsRequest extends Struct {
  external Pointer<Uint8> text;
  @Float()
  external double lengthScale;
  @Float()
  external double noiseScale;
  @Float()
  external double volume;
  @Int64()
  external int requestId;
}

final class AtlasTtsConfig extends Struct {
  @Int32()
  external int sampleRateHint;
  external Pointer<NativeFunction<AtlasTtsEventCbNative>> eventCb;
  external Pointer<Void> userData;
}

typedef AtlasTtsEventCbNative =
    Void Function(
        Int32 kind,
        Int32 errorCode,
        Int32 sampleRate,
        Int32 sampleCount,
        Int32 sampleIndex,
        Int32 textOffset,
        Int32 textLength,
        Int64 requestId,
        Pointer<Void> userData);
typedef AtlasTtsInitNative = Int32 Function(Pointer<AtlasTtsConfig> config);
typedef AtlasTtsLoadVoiceNative = Int32 Function(Pointer<Uint8> packDir);
typedef AtlasTtsSpeakNative = Int32 Function(Pointer<AtlasTtsRequest> req);
typedef AtlasTtsTakeAudioNative =
    Int32 Function(Pointer<Int16> dst, Int32 maxFrames);
typedef AtlasTtsQueuedFramesNative = Int32 Function();
typedef AtlasTtsPauseNative = Int32 Function(Int32 on);
typedef AtlasTtsEnablePlaybackNative = Int32 Function(Int32 on);

final class AtlasTtsBindings {
  AtlasTtsBindings(this._dylib);

  final DynamicLibrary _dylib;

  late final init = _dylib
      .lookupFunction<AtlasTtsInitNative, int Function(
          Pointer<AtlasTtsConfig>)>('atlas_tts_init');

  late final loadVoice = _dylib
      .lookupFunction<AtlasTtsLoadVoiceNative, int Function(
          Pointer<Uint8>)>('atlas_tts_load_voice');

  late final unloadVoice = _dylib
      .lookupFunction<Int32 Function(), int Function()>(
          'atlas_tts_unload_voice');

  late final speak = _dylib
      .lookupFunction<AtlasTtsSpeakNative, int Function(
          Pointer<AtlasTtsRequest>)>('atlas_tts_speak');

  late final takeAudio = _dylib
      .lookupFunction<AtlasTtsTakeAudioNative, int Function(
          Pointer<Int16>, int)>('atlas_tts_take_audio');

  late final queuedFrames = _dylib
      .lookupFunction<AtlasTtsQueuedFramesNative, int Function()>(
          'atlas_tts_queued_frames');

  late final stopFn = _dylib
      .lookupFunction<Int32 Function(), int Function()>('atlas_tts_stop');

  late final pauseFn = _dylib
      .lookupFunction<AtlasTtsPauseNative, int Function(int)>(
          'atlas_tts_pause');

  late final enablePlaybackFn = _dylib
      .lookupFunction<AtlasTtsEnablePlaybackNative, int Function(int)>(
          'atlas_tts_enable_playback');

  late final shutdownFn = _dylib
      .lookupFunction<Void Function(), void Function()>('atlas_tts_shutdown');
}
