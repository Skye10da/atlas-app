import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/reader/speech/persistence/shared_prefs_recovery_store.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';

void main() {
  group('SharedPrefsRecoveryStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('round-trips a checkpoint per book', () async {
      final store = SharedPrefsRecoveryStore();
      await store.save(
        const SpeechCheckpoint(
          bookId: 'b1',
          chapterId: 'c3',
          sentenceIndex: 42,
          elapsed: Duration(seconds: 90),
        ),
      );

      final loaded = await store.load('b1');
      expect(loaded, isNotNull);
      expect(loaded!.bookId, 'b1');
      expect(loaded.chapterId, 'c3');
      expect(loaded.sentenceIndex, 42);
      expect(loaded.elapsed, const Duration(seconds: 90));

      expect(await store.load('other-book'), isNull);
    });

    test('clear removes only the targeted book', () async {
      final store = SharedPrefsRecoveryStore();
      await store.save(
        const SpeechCheckpoint(
          bookId: 'b1',
          chapterId: 'c1',
          sentenceIndex: 0,
          elapsed: Duration.zero,
        ),
      );
      await store.save(
        const SpeechCheckpoint(
          bookId: 'b2',
          chapterId: 'c1',
          sentenceIndex: 0,
          elapsed: Duration.zero,
        ),
      );
      await store.clear('b1');

      expect(await store.load('b1'), isNull);
      expect(await store.load('b2'), isNotNull);
    });
  });

  group('NarrationSettings', () {
    test('json round-trip preserves all fields', () {
      const settings = NarrationSettings(
        speechRate: 1.3,
        speechPitch: 0.9,
        selectedVoiceId: 'voice@en-AU',
        sleepTimer: SleepTimerConfig(
          duration: Duration(minutes: 15),
          boundary: SleepTimerBoundary.endOfParagraph,
        ),
        syncScrollToNarration: true,
        autoAdvanceChapter: false,
        activeProfile: 'Fast Reading',
      );

      final restored = NarrationSettings.fromJson(settings.toJson());
      expect(restored.speechRate, 1.3);
      expect(restored.speechPitch, 0.9);
      expect(restored.selectedVoiceId, 'voice@en-AU');
      expect(restored.sleepTimer?.duration, const Duration(minutes: 15));
      expect(restored.sleepTimer?.boundary, SleepTimerBoundary.endOfParagraph);
      expect(restored.syncScrollToNarration, isTrue);
      expect(restored.autoAdvanceChapter, isFalse);
      expect(restored.activeProfile, 'Fast Reading');
    });

    test('missing keys fall back to defaults', () {
      final restored = NarrationSettings.fromJson(const {});
      expect(restored.speechRate, 1.0);
      expect(restored.speechPitch, 1.0);
      expect(restored.selectedVoiceId, isNull);
      expect(restored.sleepTimer, isNull);
      expect(restored.autoAdvanceChapter, isTrue);
    });

    test('copyWith can clear the sleep timer', () {
      const settings = NarrationSettings(
        sleepTimer: SleepTimerConfig(
          duration: Duration(minutes: 5),
          boundary: SleepTimerBoundary.endOfChapter,
        ),
      );
      final cleared = settings.copyWith(clearSleepTimer: true);
      expect(cleared.sleepTimer, isNull);
    });

    test('applying a profile sets activeProfile and values', () {
      const settings = NarrationSettings();
      final applied = NarrationProfile.fastReading.applyTo(settings);
      expect(applied.speechRate, 1.35);
      expect(applied.activeProfile, 'Fast Reading');
    });
  });
}