// Standalone probe for the M3 playback device consumer: enable playback,
// speak (sine dev pack), and confirm CHUNK_DRAINED arrives after actual
// device play-out with the FIFO consumed by the device thread.
//   dart run tool/playback_probe.dart
// (stderr carries the native `atlas-playback:` traces.)
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:atlas_tts/atlas_tts.dart';

void _preloadRuntimeDlls(String dylibPath) {
  const order = [
    'onnxruntime_providers_shared.dll',
    'onnxruntime.dll',
    'sherpa-onnx-cxx-api.dll',
    'sherpa-onnx-c-api.dll',
  ];
  final dir = File(dylibPath).parent;
  for (final name in order) {
    final f = File('${dir.path}\\$name');
    if (!f.existsSync()) continue;
    try {
      DynamicLibrary.open(f.path);
    } catch (_) {}
  }
}

Future<void> main() async {
  final dylibPath = 'build/test/Debug/atlas_tts.dll';
  _preloadRuntimeDlls(dylibPath);
  final dylib = DynamicLibrary.open(dylibPath);
  AtlasTts.bindingsFactory = () => AtlasTtsBindings(dylib);
  final err = AtlasTts.initialize(sampleRateHint: 22050);
  print('init -> $err');
  final tts = AtlasTts.instance!;

  final done = Completer<void>();
  final events = <TtsEvent>[];
  tts.events.listen((e) {
    events.add(e);
    print('event: $e');
    if (e is TtsChunkDrained) done.complete();
  });

  print('loadVoice -> ${tts.loadVoice("stub-pack")}');
  print('enablePlayback -> ${tts.enablePlayback(true)}');
  await Future<void>.delayed(const Duration(milliseconds: 100));
  final watch = Stopwatch()..start();
  final rc = tts.speak('Hello from the playback device probe.', requestId: 7);
  print('speak -> $rc');
  await done.future.timeout(const Duration(seconds: 30), onTimeout: () {
    print('TIMEOUT; events=${events.length} queued=${tts.queuedFrames}');
    exitCode = 1;
  });
  if (exitCode == 0 || done.isCompleted) {
    watch.stop();
    print(
        'drained after ${watch.elapsedMilliseconds} ms; '
        'queued=${tts.queuedFrames}');
  }
  tts.stop();
  tts.enablePlayback(false);
  tts.shutdown();
  print('done');
}
