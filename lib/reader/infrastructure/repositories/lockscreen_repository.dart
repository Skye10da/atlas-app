import 'package:audio_service/audio_service.dart';

import 'package:atlas_app/reader/domain/entities/lockscreen_media_entity.dart';
import 'package:atlas_app/reader/infrastructure/services/media_notification_service.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';

/// Repository: single source of truth for lockscreen media.
/// Consumes [MediaNotificationService], exposes domain models to ViewModel.
class LockscreenRepository {
  LockscreenRepository({
    required MediaNotificationService service,
    required BaseAudioHandler handler,
  })  : _service = service,
        _handler = handler;

  final MediaNotificationService _service;
  final BaseAudioHandler _handler;

  LockscreenMediaEntity? _cached;

  LockscreenMediaEntity? get cached => _cached;

  /// Transforms `SpeechSession` + playback position to domain entity.
  LockscreenMediaEntity fromSession(
    SpeechSession session, {
    required Duration position,
    required Duration? duration,
    required bool isPlaying,
    required double speed,
  }) {
    return LockscreenMediaEntity(
      bookId: session.bookId,
      bookTitle: session.bookTitle ?? session.bookId,
      chapterTitle: session.currentItem?.text.split('\n').first ?? session.chapterId,
      author: session.author ?? 'Atlas',
      coverPath: session.coverPath,
      duration: duration,
      position: position,
      isPlaying: isPlaying,
      playbackSpeed: speed,
    );
  }

  /// Pushes domain entity to platform (audio_service) — handles art caching.
  Future<void> publish(LockscreenMediaEntity entity) async {
    _cached = entity;
    final item = await _service.buildMediaItem(entity);
    _handler.mediaItem.add(item);
    _handler.playbackState.add(
      _service.buildPlaybackState(
        isPlaying: entity.isPlaying,
        position: entity.position ?? Duration.zero,
        duration: entity.duration,
        speed: entity.playbackSpeed,
      ),
    );
  }

  Future<void> updatePlaybackState({
    required bool isPlaying,
    required Duration position,
    Duration? duration,
    required double speed,
  }) async {
    final base = _cached;
    if (base != null) {
      await publish(base.copyWith(isPlaying: isPlaying, position: position, duration: duration, playbackSpeed: speed));
    } else {
      _handler.playbackState.add(
        _service.buildPlaybackState(isPlaying: isPlaying, position: position, duration: duration, speed: speed),
      );
    }
  }

  Future<void> clear() async {
    _cached = null;
    _handler.mediaItem.add(null);
    _handler.playbackState.add(
      _service.buildPlaybackState(isPlaying: false, position: Duration.zero, duration: null, speed: 1.0),
    );
  }
}
