// Standalone probe for debugging the native smoke test outside the flutter
// test harness: load the locally built atlas_tts dylib, init, load voice,
// speak, count events, drain audio. Run until 0 (success) exit code:
//   dart run tool/smoke_probe.dart
// Optional args: [dylibPath] (default build/test/Debug/atlas_tts.dll).
//
// NOTE: calls shutdown() before exit — the NativeCallable.listener port keeps
// the process alive otherwise.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:atlas_tts/atlas_tts.dart';

// Windows only: preloads the sherpa-onnx runtime DLLs by absolute path so the
// loader satisfies atlas_tts.dll's import dependencies from already-loaded
// modules (base-name match) instead of searching PATH. Harmless no-op when
// the runtime DLLs are not present (sine-only build).
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
      print('probe: preloaded $name');
    } catch (_) {
      // Already loaded in this process — fine.
    }
  }
}

Future<void> main(List<String> args) async {
  print('probe: starting');
  final dylibPath = args.isNotEmpty
      ? args[0]
      : File('build/test/Debug/atlas_tts.dll').existsSync()
          ? 'build/test/Debug/atlas_tts.dll'
          : 'build/test/atlas_tts.dll';
  print('probe: dylib at $dylibPath');
  _preloadRuntimeDlls(dylibPath);

  final dylib = DynamicLibrary.open(dylibPath);
  for (final sym in [
    'atlas_tts_init',
    'atlas_tts_speak',
    'atlas_tts_take_audio',
  ]) {
    try {
      dylib.lookup<NativeFunction<Void Function()>>(sym);
      print('probe: symbol ok $sym');
    } on ArgumentError {
      print('probe: MISSING SYMBOL $sym');
      exitCode = 1;
    }
  }

  AtlasTts.bindingsFactory = () => AtlasTtsBindings(dylib);
  final error = AtlasTts.initialize(sampleRateHint: 22050);
  print('probe: init -> $error');
  if (error != null) {
    exitCode = 1;
    return;
  }
  final tts = AtlasTts.instance!;

  final events = <TtsEvent>[];
  final done = Completer<void>();
  final sub = tts.events.listen((e) {
    events.add(e);
    if (e is TtsError) print('probe: error event code=${e.code}');
    if (e is TtsChunkDrained) {
      print('probe: drained (request ${e.requestId})');
      done.complete();
    }
  }, cancelOnError: false);

  print('probe: loadVoice');
  print('probe: loadVoice -> ${tts.loadVoice("stub-pack")}');

  print('probe: speak');
  final rc = tts.speak('Hello Atlas native core, speak plainly please.',
      requestId: 1);
  print('probe: speak -> $rc');

  runZoned(() {
    done.future.timeout(const Duration(seconds: 10), onTimeout: () {
      print('probe: TIMEOUT waiting for drained; events so far:');
      for (final e in events) {
        print('      $e');
      }
      exitCode = 2;
    }).whenComplete(() {
      var total = 0;
      while (tts.queuedFrames > 0) {
        final chunk = tts.takeAudio(32768);
        if (chunk == null || chunk.isEmpty) break;
        total += chunk.length;
      }
      print('probe: drained $total samples; ${events.length} events total');
      sub.cancel();
      tts.stop();
    });
  });

  print('probe: cancellation phase');
  const longText = 'word word word word word again and again ';
  final rcLong = tts.speak(longText * 38, requestId: 2);
  print('probe: long speak -> $rcLong');

  final events2 = <TtsEvent>[];
  final done2 = Completer<void>();
  tts.events.listen((e) {
    events2.add(e);
    if (e is TtsChunkDrained) {
      if (e.requestId == 2) {
        print('probe: req2 drained UNEXPECTED (cancellation failed)');
        exitCode = 3;
      } else {
        print('probe: drained (request ${e.requestId})');
      }
      if (e.requestId == 3) done2.complete();
    }
  });

  sleep(const Duration(milliseconds: 300));
  print('probe: calling stop (queued=${tts.queuedFrames})');
  final stopRc = tts.stop();
  print('probe: stop -> $stopRc, queued=${tts.queuedFrames}');

  print('probe: re-speak after stop');
  final rc3 = tts.speak('Short tail after cancellation.', requestId: 3);
  print('probe: speak -> $rc3');
  if (rc3 == 0) {
    await done2.future.timeout(const Duration(seconds: 10), onTimeout: () {
      print('probe: TIMEOUT waiting for req3 drain; events2 so far:');
      for (final e in events2) {
        print('      $e');
      }
      exitCode = 2;
    });
    tts.stop();
  }
  tts.shutdown();
  print('probe: shutdown complete');
}
