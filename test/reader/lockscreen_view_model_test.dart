import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart';
import 'package:atlas_app/reader/domain/entities/lockscreen_media_entity.dart';
import 'package:atlas_app/reader/domain/use_cases/update_lockscreen_media_use_case.dart';
import 'package:atlas_app/reader/infrastructure/repositories/lockscreen_repository.dart';
import 'package:atlas_app/reader/infrastructure/services/media_notification_service.dart';
import 'package:atlas_app/reader/presentation/view_models/lockscreen_view_model.dart';
import 'package:atlas_app/reader/speech/speech_driver.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/persistence/recovery_store.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';
import 'package:atlas_app/reader/speech/speech_queue.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';

class _FakeRecoveryStore implements RecoveryStore {
  @override
  Future<void> clear(String bookId) async {}
  @override
  Future<SpeechCheckpoint?> load(String bookId) async => null;
  @override
  Future<void> save(SpeechCheckpoint c) async {}
}

class _FakeDriver implements SpeechDriver {
  final _events = StreamController<SpeechDriverEvent>.broadcast();
  final _state = StreamController<DriverState>.broadcast();
  @override
  Stream<SpeechDriverEvent> get events => _events.stream;
  @override
  DriverState get state => DriverState.stopped;
  @override
  Stream<DriverState> get stateStream => _state.stream;
  @override
  Future<void> configure({required double rate, required double pitch, required double volume, String? voiceId, String? language}) async {}
  @override
  Future<void> speak(SpeechItem item) async {}
  @override
  Future<void> warmup(SpeechItem item) async {}
  @override
  Future<List<int>?> synthesizeToBytes(SpeechItem item) async => null;
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume(SpeechItem item) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<List<VoiceDescriptor>> listVoices() async => const [];
  @override
  Future<void> restart() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  test('LockscreenViewModel exposes state and handles pause', () async {
    final handler = BaseAudioHandler();
    final repo = LockscreenRepository(service: const MediaNotificationService(), handler: handler);
    final useCase = UpdateLockscreenMediaUseCase(repo);
    final engine = SpeechEngine(_FakeDriver(), _FakeRecoveryStore());

    final vm = LockscreenViewModel(repository: repo, useCase: useCase, engine: engine);

    // Simulate publishing via repo directly (ViewModel listens to engine events, but we can test direct)
    const entity = LockscreenMediaEntity(bookId: 'b1', bookTitle: 'Book', chapterTitle: 'Ch1', author: 'Atlas', isPlaying: true, playbackSpeed: 1.0);
    await repo.publish(entity);
    // ViewModel state is updated via events; initially null, after manual publish repo has cache
    expect(repo.cached?.isPlaying, true);

    await vm.pause();
    expect(vm.error, isNull);

    vm.dispose();
    await engine.dispose();
  });

  test('UpdateLockscreenMediaUseCase onChapterStarted publishes', () async {
    final handler = BaseAudioHandler();
    final repo = LockscreenRepository(service: const MediaNotificationService(), handler: handler);
    final useCase = UpdateLockscreenMediaUseCase(repo);
    final engine = SpeechEngine(_FakeDriver(), _FakeRecoveryStore());
    final session = SpeechSession(
      bookId: 'b1',
      chapterId: 'c1',
      queue: SpeechQueue([
        const SpeechItem(bookId: 'b1', chapterId: 'c1', paragraphIndex: 0, sentenceIndex: 0, text: 'Hello', language: 'en'),
      ]),
      settings: const NarrationSettings(),
      bookTitle: 'Book',
      author: 'Author',
    );
    await useCase.onChapterStarted(session, const ChapterStarted(chapterId: 'c1', chapterTitle: 'Ch 1', coverPath: null));
    expect(handler.mediaItem.value?.title, 'Ch 1');
    await engine.dispose();
  });
}
