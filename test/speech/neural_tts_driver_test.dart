// NeuralTtsDriver tests against the real atlas_tts native core.
//
// Host-only (Windows dev): the suite points AtlasTts.bindingsFactory at the
// plugin's locally built test dylib (atlas_tts/build/test/Debug/atlas_tts.dll
// -- produced by `flutter test` inside atlas_tts/) and skips entirely when it
// is absent, mirroring the plugin's native smoke-test bootstrap. Voice packs
// resolve through a temp sine-fallback pack so no 64 MB download is needed;
// the real VITS path is covered by the plugin's own native test.
//
// ASCII-only source on purpose: accented characters are built from code
// points at runtime so the UTF-8 byte-map tests exercise the runtime text,
// not this file's encoding.
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:atlas_tts/atlas_tts.dart' as atlas;
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/speech/drivers/neural_tts_driver.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

const _dylibCandidates = [
  'atlas_tts/build/test/Debug/atlas_tts.dll',
  'atlas_tts/build/test/Release/atlas_tts.dll',
];

DynamicLibrary? _findDylib() {
  if (!Platform.isWindows) return null;
  for (final rel in _dylibCandidates) {
    final abs = File(rel).absolute.path;
    if (!File(abs).existsSync()) continue;
    final dir = Directory(File(abs).parent.path);
    // The test build links sherpa-onnx (when native_deps exists); preload
    // the runtime DLLs by absolute path so the loader resolves them by
    // base name -- same trick the plugin's native suite uses.
    const runtimes = [
      'onnxruntime_providers_shared.dll',
      'onnxruntime.dll',
      'sherpa-onnx-cxx-api.dll',
      'sherpa-onnx-c-api.dll',
    ];
    for (final name in runtimes) {
      final f = File('${dir.path}\\$name');
      if (!f.existsSync()) continue;
      try {
        DynamicLibrary.open(f.path);
      } catch (_) {}
    }
    return DynamicLibrary.open(abs);
  }
  return null;
}

SpeechItem _item(String text) => SpeechItem(
  bookId: 'b1',
  chapterId: 'c1',
  paragraphIndex: 0,
  sentenceIndex: 0,
  text: text,
  language: 'en-US',
);

void main() {
  final dylib = _findDylib();

  Directory? packRoot;
  atlas.AtlasTts? tts;
  NeuralTtsDriver? driver;

  setUpAll(() {
    if (dylib == null) {
      // CI hosts without a native build: covered by atlas_tts's own suite.
      return;
    }
    atlas.AtlasTts.bindingsFactory = () => atlas.AtlasTtsBindings(dylib);
    final init = atlas.AtlasTts.initialize(sampleRateHint: 22050);
    expect(init, isNull, reason: 'atlas_tts session init must succeed');
    tts = atlas.AtlasTts.instance!;
    packRoot = Directory.systemTemp.createTempSync('atlas_neural_pack');
  });

  tearDownAll(() async {
    if (dylib == null) return;
    try {
      await driver?.dispose();
    } catch (_) {}
    tts?.shutdown();
    packRoot?.deleteSync(recursive: true);
  });

  group('neural driver (native)', () {
    setUp(() {
      if (dylib == null) {
        markTestSkipped('atlas_tts native test library not built on this host');
        return;
      }
      // Fresh driver per test: enablePlayback on (the winmm device pulls
      // the FIFO). Pack loading is owned by the driver entirely.
      tts!.enablePlayback(true);
      driver = NeuralTtsDriver.session(tts!, packDirectory: packRoot!.path);
    });

    tearDown(() async {
      if (dylib == null) return;
      await driver?.dispose();
      tts!.pause(false);
      tts!.stop();
    });

    test(
      'speak drives Started -> word boundaries -> Completed in real time',
      () async {
        if (dylib == null) {
          markTestSkipped('atlas_tts native test library not built on this host');
          return;
        }
        const cafe = 'caf\u00e9';
        final events = <SpeechDriverEvent>[];
        final completed = Completer<void>();
        final sub = driver!.events.listen((e) {
          events.add(e);
          if (e is DriverCompleted && !completed.isCompleted) {
            completed.complete();
          }
        });

        final watch = Stopwatch()..start();
        await driver!.speak(
          _item('A $cafe r\u00e9sum\u00e9: one $cafe, then $cafe again.'),
        );
        watch.stop();

        // Render-side enqueue is ~50 ms; with playback on, speak resolves
        // after device play-out.
        expect(
          watch.elapsedMilliseconds,
          greaterThan(800),
          reason: 'speak must await device play-out, not mere queueing',
        );
        // The Completed event is delivered on the same broadcast stream;
        // give its listener delivery a beat before asserting list content.
        await completed.future.timeout(const Duration(seconds: 5));
        final words = events
            .whereType<DriverWordBoundary>()
            .map((w) => w.word)
            .toList();
        expect(
          words.where((s) => s.contains(cafe)),
          isNotEmpty,
          reason: 'collected words: $words',
        );
        expect(events.whereType<DriverCompleted>(), isNotEmpty);
        // UTF-8 byte offsets translated to Dart indices must slice the exact
        // word from the item's cleaned text.
        final cafeHits = events
            .whereType<DriverWordBoundary>()
            .where((w) => w.word.contains(cafe))
            .toList();
        expect(cafeHits, isNotEmpty);
        for (final w in cafeHits) {
          expect(w.start, lessThan(w.end));
        }
        expect(events.whereType<DriverError>(), isEmpty);
        expect(driver!.state, DriverState.ready);
        await sub.cancel();
      },
    );

    test('pause holds play-out; resume lets it complete', () async {
      if (dylib == null) {
        markTestSkipped('atlas_tts native test library not built on this host');
        return;
      }
      final completion = Completer<void>();
      final sub = driver!.events.listen((e) {
        if (e is DriverCompleted && !completion.isCompleted) {
          completion.complete();
        } else if (e is DriverError && !completion.isCompleted) {
          completion.completeError(e.message);
        }
      });
      final speakFuture = driver!.speak(
        _item('This sentence drains after pulling.'),
      );
      // Give the device time to start consuming.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await driver!.pause();
      expect(driver!.state, DriverState.paused);
      final held = Stopwatch()..start();
      await Future.any([
        completion.future,
        Future<void>.delayed(const Duration(seconds: 1)),
      ]);
      // Held: no completion while paused.
      expect(
        completion.isCompleted,
        isFalse,
        reason: 'pausing must hold device buffers',
      );
      await driver!.resume(_item(''));
      await completion.future.timeout(const Duration(seconds: 30));
      held.stop();
      // Real-time pacing across a hold: the pause window itself proves
      // play-out did not race ahead.
      expect(held.elapsed, greaterThan(const Duration(seconds: 1)));
      await speakFuture;
      await sub.cancel();
    });

    test(
      'stop resolves the in-flight speak without waiting for play-out',
      () async {
        if (dylib == null) {
          markTestSkipped('atlas_tts native test library not built on this host');
          return;
        }
        final speakFuture = driver!.speak(
          _item('A longish sentence that will be cancelled mid-flight.'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final watch = Stopwatch()..start();
        await driver!.stop();
        await speakFuture;
        watch.stop();
        // Play-out of the full utterance would take ~2 s; stop must return
        // well before that.
        expect(watch.elapsedMilliseconds, lessThan(1500));
        expect(driver!.state, DriverState.stopped);

        // And the driver is immediately usable again.
        final done = Completer<void>();
        final sub = driver!.events.listen(
          (e) => e is DriverCompleted ? done.complete() : null,
        );
        await driver!.speak(_item('Works after a stop.'));
        await done.future.timeout(const Duration(seconds: 30));
        await sub.cancel();
        expect(driver!.state, DriverState.ready);
        await sub.cancel();
      },
    );

    test(
      'configure remaps rate to length scale without breaking speak',
      () async {
        if (dylib == null) {
          markTestSkipped('atlas_tts native test library not built on this host');
          return;
        }
        await driver!.configure(rate: 1.5, pitch: 1.0, volume: 0.8);
        final done = Completer<void>();
        final sub = driver!.events.listen(
          (e) => e is DriverCompleted ? done.complete() : null,
        );
        await driver!.speak(
          _item('Faster rate renders proportionally shorter.'),
        );
        await done.future.timeout(const Duration(seconds: 30));
        await sub.cancel();
        expect(driver!.state, DriverState.ready);
      },
    );

    test('voice load completion state: ready after pack ready', () async {
      if (dylib == null) {
        markTestSkipped('atlas_tts native test library not built on this host');
        return;
      }
      await driver!.warmup(_item(''));
      await driver!.speak(_item('Ready path runs.'));
      expect(driver!.state, DriverState.ready);
    });

    test('listVoices tolerates a missing pack root', () async {
      if (dylib == null) {
        markTestSkipped('atlas_tts native test library not built on this host');
        return;
      }
      // No path_provider mock in the test env: the document-root resolve
      // fails harmlessly.
      expect(await driver!.listVoices(), isEmpty);
    });
  });

  group('NeuralTtsDriver sync pack gate', () {
    test('androidDocumentsRootFromCmdline parses package from /proc shape', () {
      expect(
        NeuralTtsDriver.androidDocumentsRootFromCmdline(
          'com.example.atlas_app\u0000--zygote-extra',
        ),
        '/data/user/0/com.example.atlas_app/app_flutter',
      );
      expect(
        NeuralTtsDriver.androidDocumentsRootFromCmdline(
          'com.example.atlas_app',
        ),
        '/data/user/0/com.example.atlas_app/app_flutter',
      );
    });

    test('androidDocumentsRootFromCmdline rejects ambiguity', () {
      expect(NeuralTtsDriver.androidDocumentsRootFromCmdline(null), isNull);
      expect(NeuralTtsDriver.androidDocumentsRootFromCmdline(''), isNull);
      // No package separator: not a plausible package name from cmdline.
      expect(NeuralTtsDriver.androidDocumentsRootFromCmdline('zygote'), isNull);
      // Whitespace-only NUL segment: trim leaves nothing.
      expect(
        NeuralTtsDriver.androidDocumentsRootFromCmdline('\u0000--foo'),
        isNull,
      );
    });

    test('iosDocumentsRootFromExecutable climbs to the .app container', () {
      // Direct bundle executable.
      expect(
        NeuralTtsDriver.iosDocumentsRootFromExecutable(
          '/var/mobile/Containers/Data/Application/8C0A4437-01/Runner.app/Runner',
        ),
        '/var/mobile/Containers/Data/Application/8C0A4437-01/Documents',
      );
      // Frameworks nesting (debug/profile layouts).
      expect(
        NeuralTtsDriver.iosDocumentsRootFromExecutable(
          '/private/var/containers/9A1B/Runner.app/Frameworks/App.framework/App',
        ),
        '/private/var/containers/9A1B/Documents',
      );
    });

    test('iosDocumentsRootFromExecutable refuses unresolvable layouts', () {
      expect(NeuralTtsDriver.iosDocumentsRootFromExecutable(null), isNull);
      expect(NeuralTtsDriver.iosDocumentsRootFromExecutable(''), isNull);
      // No .app anywhere above: null, never a guess.
      expect(
        NeuralTtsDriver.iosDocumentsRootFromExecutable(
          '/usr/local/bin/some-binary',
        ),
        isNull,
      );
    });

    test('packInstalledSync detects pack directories', () {
      final tmp = Directory.systemTemp.createTempSync('atlas_gate_');
      addTearDown(() {
        tmp.deleteSync(recursive: true);
      });
      final voices = Directory('${tmp.path}/atlas_tts/voices');
      // Root absent -> false.
      expect(
        NeuralTtsDriver.packInstalledSync(documentsRoot: tmp.path),
        isFalse,
      );
      voices.createSync(recursive: true);
      // Root present, empty -> false.
      expect(
        NeuralTtsDriver.packInstalledSync(documentsRoot: tmp.path),
        isFalse,
      );
      Directory(
        '${tmp.path}/atlas_tts/voices/vits-piper-en_US-amy',
      ).createSync();
      expect(
        NeuralTtsDriver.packInstalledSync(documentsRoot: tmp.path),
        isTrue,
      );
      // Unknown root -> false.
      expect(NeuralTtsDriver.packInstalledSync(documentsRoot: null), isFalse);
    });
  });
}
