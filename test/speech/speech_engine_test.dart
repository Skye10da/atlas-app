import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/speech/persistence/recovery_store.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_driver.dart';
import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';
import 'package:atlas_app/reader/speech/speech_queue.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';

class FakeDriver implements SpeechDriver {
  final _events = StreamController<SpeechDriverEvent>.broadcast();
  final _state = StreamController<DriverState>.broadcast();
  DriverState _driverState = DriverState.ready;

  final spoken = <SpeechItem>[];
  int configureCount = 0;
  int restartCount = 0;

  @override
  Stream<SpeechDriverEvent> get events => _events.stream;
  @override
  DriverState get state => _driverState;
  @override
  Stream<DriverState> get stateStream => _state.stream;

  @override
  Future<void> configure({
    required double rate,
    required double pitch,
    required double volume,
    String? voiceId,
    String? language,
  }) async {
    configureCount++;
  }

  @override
  Future<void> speak(SpeechItem item) async {
    spoken.add(item);
    _driverState = DriverState.speaking;
  }

  @override
  Future<void> pause() async => _driverState = DriverState.paused;

  @override
  Future<void> resume(SpeechItem item) async => _driverState = DriverState.speaking;

  @override
  Future<void> stop() async => _driverState = DriverState.stopped;

  @override
  Future<List<VoiceDescriptor>> listVoices() async => const [];

  @override
  Future<void> restart() async {
    restartCount++;
    _driverState = DriverState.ready;
  }

  @override
  Future<void> dispose() async {
    await _events.close();
    await _state.close();
  }

  void emit(DriverState s) {
    _driverState = s;
    _state.add(s);
  }

  void complete() => _events.add(const DriverCompleted());

  void fail(String message) => _events.add(DriverError(message));
}

SpeechItem _item(int p, int s) => SpeechItem(
      bookId: 'b1',
      chapterId: 'c1',
      paragraphIndex: p,
      sentenceIndex: s,
      text: 'sentence $p/$s',
      language: 'en-US',
    );

SpeechSession _session() => SpeechSession(
      bookId: 'b1',
      chapterId: 'c1',
      queue: SpeechQueue([_item(0, 0), _item(0, 1), _item(1, 0)]),
      settings: const NarrationSettings(),
    );

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeDriver driver;
  late InMemoryRecoveryStore store;
  late SpeechEngine engine;
  late List<SpeechEvent> seen;

  setUp(() {
    driver = FakeDriver();
    store = InMemoryRecoveryStore();
    engine = SpeechEngine(driver, store);
    seen = [];
    engine.events.listen(seen.add);
  });

  tearDown(() async {
    await engine.dispose();
  });

  test('start speaks the first item and emits SentenceStarted', () async {
    await engine.loadSession(_session());
    await engine.start();
    await _flush();

    expect(driver.spoken.map((i) => i.text).toList(), ['sentence 0/0']);
    expect(seen.whereType<SentenceStarted>().length, 1);
  });

  test('completing items advances through the queue and ends with ChapterFinished', () async {
    await engine.loadSession(_session());
    await engine.start();
    await _flush();

    driver.complete();
    await _flush();
    expect(driver.spoken.map((i) => i.text).toList(), ['sentence 0/0', 'sentence 0/1']);
    expect(seen.whereType<SentenceFinished>().length, 1);
    expect(seen.whereType<ParagraphFinished>().length, 0); // mid-paragraph

    driver.complete();
    await _flush();
    expect(driver.spoken.length, 3); // paragraph 1 starts
    expect(seen.whereType<ParagraphFinished>().length, 1);

    driver.complete();
    await _flush();
    expect(seen.whereType<ChapterFinished>().length, 1);
    expect(seen.whereType<ChapterFinished>().first.chapterId, 'c1');
    expect(driver.spoken.length, 3); // does not speak beyond the chapter
  });

  test('checkpoint is flushed after every 5 sentences', () async {
    await engine.loadSession(_session());
    await engine.start();
    for (var i = 0; i < 5; i++) {
      driver.complete();
      await _flush();
    }
    final checkpoint = await store.load('b1');
    expect(checkpoint, isNotNull);
    expect(checkpoint!.chapterId, 'c1');
    expect(checkpoint.sentenceIndex, greaterThanOrEqualTo(2));
  });

  test('sleep timer stops at end of sentence once its duration elapses', () async {
    await engine.loadSession(_session());
    await engine.start();
    engine.setSleepTimer(
      const SleepTimerConfig(
        duration: Duration(milliseconds: 50),
        boundary: SleepTimerBoundary.endOfSentence,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    driver.complete();
    await _flush();

    expect(seen.whereType<SpeechStopped>().length, 1);
  });

  test('error recovery retries the item, then restarts, then gives up', () async {
    await engine.loadSession(_session());
    await engine.start();
    await _flush();

    final beforeRetry = driver.spoken.length;
    driver.fail('hiccup');
    await _flush();
    // Retried the same item once.
    expect(driver.spoken.length, beforeRetry + 1);
    expect(driver.restartCount, 0);

    driver.fail('hiccup again');
    await _flush();
    // Restart + one more speak.
    expect(driver.restartCount, 1);
    expect(driver.spoken.length, beforeRetry + 2);

    driver.fail('still failing');
    await _flush();
    // Restart already happened for this item - give up now.
    expect(driver.restartCount, 1);
    expect(driver.spoken.length, beforeRetry + 2);
    expect(seen.whereType<SpeechError>().length, 1);
  });
}