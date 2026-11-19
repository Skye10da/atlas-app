// Native smoke test for the atlas_tts core (M1, NTD §3.1).
//
// Builds the C core with CMake for the HOST platform, then loads the shared
// library directly from the build directory and drives the whole
// init -> speak -> events -> takeAudio -> drained pipeline against the real
// native implementation.
//
// This doubles as the header/ABI pinning test: struct layout or ABI
// regressions surface here as load failures or event-shape mismatches.
//
// cmake discovery order: ATLAS_TTS_CMAKE env var, PATH, VS-bundled install.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:atlas_tts/atlas_tts.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// CMake bootstrap
// ---------------------------------------------------------------------------

/// Builds the shared library for the host and returns its absolute path.
String _buildDylib() {
  final projectDir = _projectRoot();
  final sourceDir = Directory('${projectDir.path}/src');
  final buildDir = Directory('${projectDir.path}/build/test');
  buildDir.createSync(recursive: true);

  final cmake = _findCmake();
  final env = {'PATH': Platform.environment['PATH'] ?? ''};

  final configureArgs = [
    '-S', sourceDir.path,
    '-B', buildDir.path,
    '-DCMAKE_BUILD_TYPE=Debug',
  ];
  // Neural backend (M2): enable sherpa-onnx when the runtime is fetched.
  if (Directory('${projectDir.path}/native_deps').existsSync()) {
    configureArgs.add('-DATLAS_SHERPA_RUNTIME:PATH=${projectDir.path}\\native_deps');
  }

  final config = Process.runSync(
    cmake,
    configureArgs,
    environment: env,
    runInShell: true,
  );
  if (config.exitCode != 0) {
    fail('cmake configure failed:\n${config.stdout}${config.stderr}');
  }

  final build = Process.runSync(
    cmake,
    ['--build', buildDir.path, '--config', 'Debug'],
    environment: env,
    runInShell: true,
  );
  if (build.exitCode != 0) {
    fail('cmake build failed:\n${build.stdout}${build.stderr}');
  }

  return _locateDylib(buildDir.path);
}

/// Locates a cmake executable: env var, PATH, then VS install locations.
String _findCmake() {
  final env = Platform.environment['ATLAS_TTS_CMAKE'];
  if (env != null && env.isNotEmpty) return env;

  final pathHit = _which('cmake');
  if (pathHit != null) return pathHit;

  for (final root in [
    r'C:\Program Files\Microsoft Visual Studio',
    r'C:\Program Files (x86)\Microsoft Visual Studio',
  ]) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    final found = _findFiles(dir, 'cmake.exe', maxDepth: 10);
    final canonical = found
        .where((p) => p.endsWith(r'CMake\bin\cmake.exe'))
        .toList();
    if (canonical.isNotEmpty) return canonical.first;
    if (found.isNotEmpty) return found.first;
  }
  fail('cmake not found; set ATLAS_TTS_CMAKE, or install CMake');
}

List<String> _findFiles(Directory root, String name, {int maxDepth = 8}) {
  final found = <String>[];
  final lowerName = name.toLowerCase();
  void walk(Directory dir, int depth) {
    if (depth > maxDepth) return;
    for (final e in dir.listSync(followLinks: false)) {
      if (e is File) {
        final fileName = e.path.split(Platform.pathSeparator).last;
        if (fileName.toLowerCase() == lowerName) found.add(e.path);
      } else if (e is Directory) {
        walk(e, depth + 1);
      }
    }
  }

  walk(root, 0);
  return found;
}

String? _which(String exe) {
  if (Platform.isWindows) {
    final out = Process.runSync('where', [exe], runInShell: true);
    if (out.exitCode == 0 && out.stdout.toString().trim().isNotEmpty) {
      return out.stdout.toString().trim().split('\n').first.trim();
    }
    return null;
  }
  final out = Process.runSync('which', [exe]);
  if (out.exitCode == 0) return out.stdout.toString().trim();
  return null;
}

String _locateDylib(String buildPath) {
  final expected = ['Debug/atlas_tts.dll', 'atlas_tts.dll', 'libatlas_tts.so'];
  for (final rel in expected) {
    for (final base in [buildPath, '$buildPath/src']) {
      final f = File('$base/$rel');
      if (f.existsSync()) return f.path;
    }
  }
  throw StateError(
      'built library not found under $buildPath (looked for: $expected)');
}

Directory _projectRoot() {
  var cwd = Directory.current;
  for (var i = 0; i < 5; i++) {
    if (Directory('${cwd.path}/src/atlas_tts.h').existsSync()) return cwd;
    final pubspec = File('${cwd.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: atlas_tts')) {
      return cwd;
    }
    final parent = cwd.parent;
    if (parent.path == cwd.path) break;
    cwd = parent;
  }
  throw StateError(
      'atlas_tts project root not found from ${Directory.current.path}');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late final AtlasTts tts;

  setUpAll(() {
    final String dylibPath;
    try {
      dylibPath = _buildDylib();
      _preloadRuntimeDlls(dylibPath);
      AtlasTts.bindingsFactory = () =>
          AtlasTtsBindings(DynamicLibrary.open(dylibPath));
      final error = AtlasTts.initialize(sampleRateHint: 22050);
      expect(error, isNull, reason: 'atlas_tts_init failed: $error');
      tts = AtlasTts.instance!;
      // Speak requires a loaded voice (ATLAS_ERR_NOT_READY otherwise). The
      // stub dir has no model, so the core takes the M1 sine dev fallback
      // for the placeholder-paced tests below; the VITS test at the end
      // loads the real piper pack.
      tts.loadVoice('stub-pack-dir');
    } catch (e, st) {
      // Surface the full native-side context: test reporters can hide
      // process-crash details.
      print('setUpAll FAILED: $e\n$st');
      rethrow;
    }
  });

  test('exposes the pinned ABI symbols', () {
    final dylib = DynamicLibrary.process(); // populated by initialize
    for (final symbol in [
      'atlas_tts_init',
      'atlas_tts_load_voice',
      'atlas_tts_unload_voice',
      'atlas_tts_speak',
      'atlas_tts_take_audio',
      'atlas_tts_queued_frames',
      'atlas_tts_stop',
      'atlas_tts_pause',
      'atlas_tts_enable_playback',
      'atlas_tts_shutdown',
    ]) {
      expect(_providesSymbol(dylib, symbol), isTrue, reason: 'missing $symbol');
    }
  });

  test('loadVoice announces readiness', () async {
    final envoy = _EventEnv(tts);
    tts.loadVoice('stub-pack-dir');
    await envoy.waitUntilSub(
      tts,
      () => envoy.events.any((e) => e is TtsVoiceReady),
      reason: 'load_voice must emit VOICE_READY',
    );
    envoy.close();
  });

  test('sine render: word events, PCM shape, drained', () async {
    const text = 'Hello world, this is Atlas speaking with its own engine.';
    final envoy = _EventEnv(tts);

    final rc = tts.speak(text, volume: 1.0, requestId: 7);
    expect(rc, 0, reason: 'speak should accept a fresh session');

    await envoy.waitUntilSub(
      tts,
      () => envoy.events.any((e) => e is TtsChunkDrained),
      reason: 'speak must complete with CHUNK_DRAINED',
      timeoutSeconds: 60,
    );

    // Word boundaries: one per token, non-decreasing offsets, in range.
    final words = envoy.events.whereType<TtsWordBoundary>().toList();
    final tokensInText =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    expect(words, hasLength(tokensInText.length),
        reason: 'one WORD event per token');
    var lastOffset = -1;
    for (final w in words) {
      expect(w.offset, greaterThanOrEqualTo(0));
      expect(w.offset + w.length, lessThanOrEqualTo(text.length));
      expect(w.offset, greaterThanOrEqualTo(lastOffset),
          reason: 'word offsets must be non-decreasing');
      lastOffset = w.offset;
      expect(w.requestId, 7);
    }
    // First word starts at the text start (placeholder pacing property).
    expect(words.first.offset, 0);

    // Drain the FIFO fully, then verify the PCM.
    final samples = <int>[];
    while (tts.queuedFrames > 0) {
      final chunk = tts.takeAudio(16384);
      if (chunk == null || chunk.isEmpty) break;
      samples.addAll(chunk);
    }

    expect(samples.length, greaterThanOrEqualTo(22050),
        reason: 'at least a second of audio for this text');

    // 440 Hz at 22050 Hz -> ~50.1 samples/period, 2 zero-crossings each =>
    // ~880 crossings per second of audio.
    final crossings = _countZeroCrossings(samples);
    final seconds = samples.length / 22050.0;
    final crossingsPerSecond = crossings / seconds;
    expect(crossingsPerSecond, closeTo(880, 150),
        reason: 'signal must be a sine near 440 Hz');

    // Amplitude: 8000 headroom peak at volume 1.0, no clipping.
    var peak = 0;
    for (final s in samples) {
      if (s.abs() > peak) peak = s.abs();
    }
    expect(peak, greaterThan(6000));
    expect(peak, lessThanOrEqualTo(8000));

    // FIFO fully drained and request ids echoed.
    expect(tts.queuedFrames, 0);
    final chunkIds =
        envoy.events.whereType<TtsAudioQueued>().map((e) => e.requestId).toSet();
    expect(chunkIds, {7});
    final drainedIds = envoy.events
        .whereType<TtsChunkDrained>()
        .map((e) => e.requestId)
        .toSet();
    expect(drainedIds, {7});
    expect(envoy.events.whereType<TtsError>(), isEmpty);

    envoy.close();
  });

  test('stop cancels a long render; the session accepts a new request',
      () async {
    final longText = 'word ' * 300;
    final envoy = _EventEnv(tts);

    final rc = tts.speak(longText, requestId: 11);
    expect(rc, 0);

    // Give the worker time to queue some audio, then cancel.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(tts.stop(), 0);

    // Cancellation drops queued audio; a fresh speak works immediately.
    expect(tts.queuedFrames, 0);
    final rc2 = tts.speak('Short tail.', requestId: 12);
    expect(rc2, 0);

    await envoy.waitUntilSub(
      tts,
      () => envoy.events
          .any((e) => e is TtsChunkDrained && e.requestId == 12),
      reason: 'post-cancellation speak must finish',
      timeoutSeconds: 60,
    );
    final drainedIds = envoy.events
        .whereType<TtsChunkDrained>()
        .map((e) => e.requestId)
        .toSet();
    expect(drainedIds, contains(12));
    expect(drainedIds, isNot(contains(11)),
        reason: 'cancelled render must not emit CHUNK_DRAINED');
    expect(envoy.events.whereType<TtsError>(), isEmpty);
    envoy.close();
  });

  test('concurrent speak is rejected or serialized; stop resets', () {
    tts.stop();
    final rc1 = tts.speak('first', requestId: 21);
    expect(rc1, 0);
    final rc2 = tts.speak('second', requestId: 22);
    expect(
      rc2,
      anyOf(0, AtlasTtsResult.errBusy),
      reason: 'concurrent speak either serializes (0) or reports BUSY',
    );
    tts.stop();
  });

  test('takeAudio rejects invalid arguments', () {
    expect(tts.takeAudio(-1), isNull);
    expect(tts.takeAudio(0), isNull);
  });

  test('pause is accepted (no-op without playback)', () {
    expect(tts.pause(true), 0);
    expect(tts.pause(false), 0);
  });

  test(
      'neural VITS render: piper pack loads, real speech drains, RTF sane',
      () async {
    final packDir =
        Directory('${_projectRoot().path}/voices/vits-piper-en_US-amy-medium');
    if (!packDir.existsSync()) {
      // Fetch first: tool/fetch_voice_pack.ps1 (see README). Skipping keeps
      // sine-only dev machines green without hiding the test.
      print('SKIPPED: default voice pack not fetched at ${packDir.path}');
      return;
    }

    final envoy = _EventEnv(tts);
    expect(tts.stop(), 0); // clean slate; affects nothing sine either way
    expect(tts.loadVoice(packDir.path), 0,
        reason: 'real pack load must succeed');

    // Model load is heavy (ONNX import); VOICE_READY carries the model rate.
    await envoy.waitUntilSub(
      tts,
      () => envoy.events.any((e) => e is TtsVoiceReady),
      reason: 'VITS pack must reach VOICE_READY',
      timeoutSeconds: 120,
    );

    const text = 'Atlas reads this page aloud with its own neural voice.';
    final watch = Stopwatch()..start();
    final rc = tts.speak(text, volume: 1.0, requestId: 31);
    expect(rc, 0);

    await envoy.waitUntilSub(
      tts,
      () => envoy.events.any(
          (e) => e is TtsChunkDrained && e.requestId == 31),
      reason: 'VITS utterance must finish with CHUNK_DRAINED',
      timeoutSeconds: 120,
    );
    watch.stop();

    // Drain everything the worker queued.
    final chunks = envoy.events.whereType<TtsAudioQueued>().toList()
      ..retainWhere((e) => e.requestId == 31);
    expect(chunks, isNotEmpty, reason: 'VITS must emit AUDIO_CHUNK events');
    final sampleRate = chunks.first.sampleRate;
    expect(sampleRate, greaterThan(8000), reason: 'model rate sanity');

    final samples = <int>[];
    while (tts.queuedFrames > 0) {
      final chunk = tts.takeAudio(16384);
      if (chunk == null || chunk.isEmpty) break;
      samples.addAll(chunk);
    }
    final seconds = samples.length / sampleRate;
    print(
        'VITS: ${samples.length} samples @ $sampleRate Hz '
        '(${seconds.toStringAsFixed(2)} s audio, '
        'wall ${watch.elapsedMilliseconds} ms, RTF '
        '${(watch.elapsedMilliseconds / 1000 / seconds).toStringAsFixed(3)})');

    expect(samples.length, greaterThan(16000),
        reason: 'a full sentence of speech');
    expect(tts.queuedFrames, 0);
    expect(envoy.events.whereType<TtsError>(), isEmpty);

    // Real-time capable (NTD M2 exit criterion: RTF < 1.0 here; the strict
    // on-device <0.2 target is measured on Android/iOS in M5).
    final rtf = watch.elapsedMilliseconds / 1000 / seconds;
    expect(rtf, lessThan(1.0), reason: 'VITS must be real-time capable');

    envoy.close();
  });

  test(
      'playback device consumes the FIFO; CHUNK_DRAINED fires after play-out',
      () async {
    // M3 host slice: with playback enabled the same sine utterance must be
    // consumed by the device thread itself (no takeAudio calls) and drained
    // only after the device actually played it out.
    expect(tts.enablePlayback(true), 0);
    try {
      const text = 'Playback is consumed by the device now, no polling.';
      final envoy = _EventEnv(tts);
      final watch = Stopwatch()..start();
      final rc = tts.speak(text, volume: 1.0, requestId: 41);
      expect(rc, 0);

      await envoy.waitUntilSub(
        tts,
        () =>
            envoy.events.any((e) => e is TtsChunkDrained && e.requestId == 41),
        reason: 'device consumer must deliver CHUNK_DRAINED when played out',
        timeoutSeconds: 30,
      );
      watch.stop();

      // Real-time pacing: render-side queueing alone takes ~50 ms; the
      // drained event must come after actual audio playback (>= 1 s here).
      expect(watch.elapsedMilliseconds, greaterThan(1000),
          reason: 'drained must follow device play-out, not mere queueing');
      // The FIFO is fully consumed: zero leftover after drained, and no
      // take_audio was ever called.
      expect(tts.queuedFrames, 0);

      expect(
        envoy.events.whereType<TtsAudioQueued>().map((e) => e.requestId),
        contains(41),
        reason: 'AUDIO_CHUNK events still announce progress',
      );
      expect(envoy.events.whereType<TtsError>(), isEmpty);
      envoy.close();
    } finally {
      expect(tts.enablePlayback(false), 0);
      expect(tts.stop(), 0);
    }
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
      print('host: preloaded $name');
    } catch (_) {
      // Already loaded in this process — fine.
    }
  }
}

bool _providesSymbol(DynamicLibrary dylib, String name) {
  try {
    dylib.lookup<NativeFunction<Void Function()>>(name);
    return true;
  } on ArgumentError {
    return false;
  }
}

int _countZeroCrossings(List<int> samples) {
  var count = 0;
  for (var i = 1; i < samples.length; i++) {
    if ((samples[i - 1] < 0) != (samples[i] < 0)) count++;
  }
  return count;
}

/// Subscribes to [tts.events], captures them, and waits for conditions.
class _EventEnv {
  final events = <TtsEvent>[];
  late final StreamSubscription<TtsEvent> _sub;

  _EventEnv(AtlasTts tts) {
    _sub = tts.events.listen(events.add, cancelOnError: false);
  }

  Future<void> waitUntilSub(
    AtlasTts tts,
    bool Function() condition, {
    required String reason,
    int timeoutSeconds = 30,
  }) {
    final completer = Completer<void>();
    final timer = Timer.periodic(const Duration(milliseconds: 5), (_) {
      if (!completer.isCompleted && condition()) {
        completer.complete();
      }
    });
    return completer.future
        .timeout(Duration(seconds: timeoutSeconds), onTimeout: () {
      fail('timeout ($reason); events so far: ${events.length}');
    }).whenComplete(timer.cancel);
  }

  void close() {
    _sub.cancel();
  }
}

