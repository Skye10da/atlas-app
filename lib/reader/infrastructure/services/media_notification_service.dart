import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/reader/domain/entities/lockscreen_media_entity.dart';

/// Service: wraps platform `audio_service` / `SMTC` / `MPRIS`.
/// Stateless — returns raw `MediaItem` / `PlaybackState` models.
class MediaNotificationService {
  const MediaNotificationService();

  /// Builds `MediaItem` from domain entity, resolving cover fallback.
  Future<MediaItem> buildMediaItem(LockscreenMediaEntity entity) async {
    final artUri = await _resolveArtUri(entity.coverPath);
    return MediaItem(
      id: entity.mediaId,
      title: entity.chapterTitle,
      artist: entity.author,
      album: entity.bookTitle,
      genre: 'Audiobook',
      displayTitle: entity.chapterTitle,
      displaySubtitle: entity.bookTitle,
      displayDescription: entity.author,
      artUri: artUri,
      duration: entity.duration,
      extras: {
        'bookId': entity.bookId,
        'chapterTitle': entity.chapterTitle,
        'isTts': true,
      },
    );
  }

  Future<Uri?> _resolveArtUri(String? coverPath) async {
    if (coverPath != null) {
      try {
        if (await File(coverPath).exists()) return Uri.file(coverPath);
      } catch (_) {}
    }
    return _fallbackArtUri();
  }

  Future<Uri?> _fallbackArtUri() async {
    try {
      final data = await rootBundle.load('assets/icon.png');
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'tts_fallback_cover.png'));
      if (!file.existsSync() || await file.length() == 0) {
        await file.writeAsBytes(data.buffer.asUint8List());
      }
      return Uri.file(file.path);
    } catch (_) {
      return null;
    }
  }

  PlaybackState buildPlaybackState({
    required bool isPlaying,
    required Duration position,
    Duration? duration,
    required double speed,
  }) {
    final processingState = isPlaying ? AudioProcessingState.ready : AudioProcessingState.idle;
    return PlaybackState(
      controls: _controlsFor(playing: isPlaying),
      androidCompactActionIndices: const [0, 1, 3],
      processingState: processingState,
      playing: isPlaying,
      updatePosition: position,
      bufferedPosition: duration ?? Duration.zero,
      speed: speed,
      systemActions: const {
        MediaAction.seek,
        MediaAction.setSpeed,
        MediaAction.fastForward,
        MediaAction.rewind,
      },
    );
  }

  List<MediaControl> _controlsFor({required bool playing}) => [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ];
}
