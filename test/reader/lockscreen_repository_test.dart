import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart';
import 'package:atlas_app/reader/domain/entities/lockscreen_media_entity.dart';
import 'package:atlas_app/reader/infrastructure/repositories/lockscreen_repository.dart';
import 'package:atlas_app/reader/infrastructure/services/media_notification_service.dart';

class _FakeHandler extends BaseAudioHandler {}

void main() {
  group('LockscreenRepository', () {
    late LockscreenRepository repo;
    late _FakeHandler handler;

    setUp(() {
      handler = _FakeHandler();
      repo = LockscreenRepository(service: const MediaNotificationService(), handler: handler);
    });

    test('fromSession maps SpeechSession to domain entity', () async {
      // Use minimal entity to verify transformation
      const entity = LockscreenMediaEntity(
        bookId: 'b1',
        bookTitle: 'Book',
        chapterTitle: 'Chapter 1',
        author: 'Atlas',
        isPlaying: true,
        playbackSpeed: 1.0,
        duration: Duration(minutes: 5),
        position: Duration.zero,
      );
      await repo.publish(entity);
      expect(repo.cached?.bookId, 'b1');
      expect(handler.mediaItem.value?.title, 'Chapter 1');
      expect(handler.playbackState.value.playing, true);
    });

    test('updatePlaybackState updates without mediaItem when cached', () async {
      const entity = LockscreenMediaEntity(
        bookId: 'b1',
        bookTitle: 'Book',
        chapterTitle: 'Ch 1',
        author: 'Atlas',
        isPlaying: true,
        playbackSpeed: 1.0,
      );
      await repo.publish(entity);
      await repo.updatePlaybackState(isPlaying: false, position: const Duration(seconds: 10), duration: const Duration(minutes: 5), speed: 1.0);
      expect(repo.cached?.isPlaying, false);
      expect(handler.playbackState.value.playing, false);
    });

    test('clear removes mediaItem', () async {
      const entity = LockscreenMediaEntity(bookId: 'b1', bookTitle: 'Book', chapterTitle: 'Ch 1', author: 'Atlas', isPlaying: true, playbackSpeed: 1.0);
      await repo.publish(entity);
      await repo.clear();
      expect(repo.cached, isNull);
      expect(handler.mediaItem.value, isNull);
    });
  });
}
