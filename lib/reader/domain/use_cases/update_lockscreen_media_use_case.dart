import 'package:atlas_app/reader/infrastructure/repositories/lockscreen_repository.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';

/// UseCase: translates `SpeechEvent` + `SpeechSession` into lockscreen updates.
/// Reused across multiple ViewModels (Reader, NowPlaying, MiniPlayer).
class UpdateLockscreenMediaUseCase {
  const UpdateLockscreenMediaUseCase(this._repo);

  final LockscreenRepository _repo;

  Future<void> onChapterStarted(SpeechSession session, ChapterStarted event) async {
    final duration = _estimateDuration(session);
    final entity = _repo.fromSession(
      session,
      position: Duration.zero,
      duration: duration,
      isPlaying: true,
      speed: 1.0,
    ).copyWith(chapterTitle: event.chapterTitle, coverPath: event.coverPath);
    await _repo.publish(entity);
  }

  Future<void> onSentenceStarted(SpeechSession? session, SentenceStarted event) async {
    if (session == null) return;
    final repo = _repo;
    // Reuse cached media but update position via playback state; title stays chapterTitle
    await repo.updatePlaybackState(isPlaying: true, position: _positionFor(session, event.item), duration: _estimateDuration(session), speed: 1.0);
  }

  Future<void> onPaused() async {
    final c = _repo.cached;
    if (c != null) await _repo.updatePlaybackState(isPlaying: false, position: c.position ?? Duration.zero, duration: c.duration, speed: c.playbackSpeed);
  }

  Future<void> onStopped() async => _repo.clear();

  Duration? _estimateDuration(SpeechSession session) {
    final q = session.queue;
    if (q.isEmpty) return null;
    Duration total = Duration.zero;
    for (var i = q.cursor; i < q.length; i++) {
      final it = q.itemAt(i);
      if (it?.estimatedDuration != null) total += it!.estimatedDuration!;
    }
    return total > Duration.zero ? total : const Duration(minutes: 5);
  }

  Duration _positionFor(SpeechSession session, dynamic item) {
    final q = session.queue;
    Duration pos = Duration.zero;
    for (var i = 0; i < q.cursor; i++) {
      final it = q.itemAt(i);
      if (it?.estimatedDuration != null) pos += it!.estimatedDuration!;
    }
    return pos;
  }
}
