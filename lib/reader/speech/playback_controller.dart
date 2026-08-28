import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';

import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';

/// The audio_service-facing half of the Speech Service (ASA §2). Delegates
/// all queue/sentence logic to SpeechEngine and only translates its
/// SpeechEvent stream into audio_service's PlaybackState/MediaItem model —
/// this is the *only* place that translation happens, so audio_service
/// concerns never leak into SpeechEngine and vice versa.
class AtlasPlaybackController extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  AtlasPlaybackController(this._engine) {
    _engine.events.listen(_onSpeechEvent);
  }

  final SpeechEngine _engine;

  String? _currentBookId;
  String? _currentBookTitle;
  String? _currentAuthor;
  String? _currentCoverPath;
  String? _currentChapterTitle;
  Duration? _totalSessionDuration;
  Duration _currentPosition = Duration.zero;
  double _playbackSpeed = 1.0;
  Timer? _positionTimer;

  @override
  Future<void> play() async {
    await _updateMediaItemIfNeeded();
    await _engine.start();
    _startPositionTimer();
  }

  @override
  Future<void> pause() {
    _positionTimer?.cancel();
    _positionTimer = null;
    return _engine.pause();
  }

  @override
  Future<void> stop() async {
    _positionTimer?.cancel();
    _positionTimer = null;
    await _engine.stop();
    await _clearMediaItem();
    _currentPosition = Duration.zero;
    await super.stop();
  }

  /// Not part of BaseAudioHandler's standard surface, but exposed for the
  /// Reader to call resume distinctly from a fresh play() where relevant
  /// (e.g. resuming after a driver-level pause rather than starting a new
  /// session).
  Future<void> resumeSpeech() async {
    await _updateMediaItemIfNeeded();
    await _engine.resume();
    _startPositionTimer();
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (playbackState.value.playing) {
        _currentPosition += const Duration(milliseconds: 500) * _playbackSpeed;
        _updatePlaybackStatePosition();
      }
    });
  }

  void _onSpeechEvent(SpeechEvent event) {
    final current = playbackState.value;
    switch (event) {
      case SentenceStarted():
        playbackState.add(
          current.copyWith(
            controls: _controlsFor(playing: true),
            processingState: AudioProcessingState.ready,
            playing: true,
            speed: _playbackSpeed,
            systemActions: {MediaAction.setSpeed},
          ),
        );
      case SpeechPaused():
        _positionTimer?.cancel();
        _positionTimer = null;
        playbackState.add(
          current.copyWith(
            controls: _controlsFor(playing: false),
            playing: false,
            speed: _playbackSpeed,
            systemActions: {MediaAction.setSpeed},
          ),
        );
      case SpeechStopped():
        _positionTimer?.cancel();
        _positionTimer = null;
        _currentPosition = Duration.zero;
        playbackState.add(
          current.copyWith(
            controls: _controlsFor(playing: false),
            playing: false,
            processingState: AudioProcessingState.idle,
            updatePosition: Duration.zero,
            speed: _playbackSpeed,
            systemActions: {MediaAction.setSpeed},
          ),
        );
      case SpeechCompleted():
        _positionTimer?.cancel();
        _positionTimer = null;
        _currentPosition = Duration.zero;
        playbackState.add(
          current.copyWith(
            playing: false,
            processingState: AudioProcessingState.completed,
            updatePosition: _totalSessionDuration ?? Duration.zero,
            speed: _playbackSpeed,
            systemActions: {MediaAction.setSpeed},
          ),
        );
      case SpeechError():
        _positionTimer?.cancel();
        _positionTimer = null;
        playbackState.add(
          current.copyWith(
            playing: false,
            processingState: AudioProcessingState.error,
            speed: _playbackSpeed,
            systemActions: {MediaAction.setSpeed},
          ),
        );
      case ChapterStarted(
        chapterId: final chapterId,
        chapterTitle: final chapterTitle,
        coverPath: final coverPath,
      ):
        _handleChapterStarted(chapterId, chapterTitle, coverPath);
      case WordBoundary(
        item: final item,
        start: final start,
        end: final end,
        word: _,
      ):
        // Update position based on word boundary - correct drift from periodic timer
        _updatePositionFromWordBoundary(item, start, end);
      // ChapterFinished, SentenceFinished, ParagraphFinished
      // deliberately don't touch playbackState — they're Reader-facing
      // (chapter navigation, highlighting), not OS-media-session-facing.
      // The Reader's own narration provider listens to _engine.events
      // directly for those, per ASA §6/§7.
      default:
        break;
    }
  }

  void _updatePositionFromWordBoundary(SpeechItem item, int start, int end) {
    final session = _engine.session;
    if (session == null || _totalSessionDuration == null) return;

    // Calculate position based on queue cursor and word boundary within current sentence
    final queue = session.queue;
    if (queue.isEmpty) return;

    // Estimate position: sum of durations of completed sentences + progress in current sentence
    Duration position = Duration.zero;
    for (int i = 0; i < queue.cursor; i++) {
      final qItem = queue.itemAt(i);
      if (qItem?.estimatedDuration != null) {
        position += qItem!.estimatedDuration!;
      }
    }

    // Add progress within current sentence based on word boundary
    final currentItem = queue.current;
    if (currentItem != null && currentItem.estimatedDuration != null) {
      final sentenceLength = item.text.length;
      if (sentenceLength > 0) {
        final wordProgress = end / sentenceLength;
        final sentenceDuration = currentItem.estimatedDuration!;
        final progressMs = (sentenceDuration.inMilliseconds * wordProgress).round();
        position += Duration(milliseconds: progressMs);
      }
    }

    _currentPosition = position;
    _updatePlaybackStatePosition();
  }

  void _updatePlaybackStatePosition() {
    final current = playbackState.value;
    playbackState.add(
      current.copyWith(
        updatePosition: _currentPosition,
        bufferedPosition: _totalSessionDuration ?? Duration.zero,
        speed: _playbackSpeed,
        systemActions: {MediaAction.setSpeed},
      ),
    );
  }

  Future<void> _handleChapterStarted(
    String chapterId,
    String chapterTitle,
    String? coverPath,
  ) async {
    final session = _engine.session;
    if (session == null) return;

    _currentBookId = session.bookId;
    _currentBookTitle = session.bookTitle ?? session.bookId;
    _currentAuthor = session.author ?? 'Atlas';
    _currentCoverPath = coverPath ?? session.coverPath;
    _currentChapterTitle = chapterTitle;

    // Calculate total remaining duration from queue
    _totalSessionDuration = _calculateTotalDuration(session);
    _currentPosition = Duration.zero;

    await _updateMediaItem(
      chapterTitle: chapterTitle,
      coverPath: _currentCoverPath,
    );
  }

  Duration? _calculateTotalDuration(SpeechSession session) {
    final queue = session.queue;
    if (queue.isEmpty) return null;

    // Sum estimated durations of all remaining items in queue
    Duration total = Duration.zero;
    for (int i = queue.cursor; i < queue.length; i++) {
      final item = queue.itemAt(i);
      if (item?.estimatedDuration != null) {
        total += item!.estimatedDuration!;
      } else if (item != null) {
        // Fallback: estimate from text length (~10 chars/sec at 1x speed)
        final charsPerSec = (10 * _playbackSpeed).round().clamp(1, 100);
        total += Duration(seconds: (item.text.length / charsPerSec).ceil());
      }
    }
    // Ensure non-null fallback
    return total > Duration.zero ? total : const Duration(minutes: 5);
  }

  Future<void> _updateMediaItemIfNeeded() async {
    final session = _engine.session;
    if (session == null) return;

    _currentBookId = session.bookId;
    _currentBookTitle = session.bookTitle ?? session.bookId;
    _currentAuthor = session.author ?? 'Atlas';
    _currentCoverPath = session.coverPath;
    // Use first sentence of current item as chapter title fallback
    _currentChapterTitle = session.currentItem?.text.split('\n').first;

    _totalSessionDuration = _calculateTotalDuration(session);
    _currentPosition = Duration.zero;

    final item = session.currentItem;
    if (item != null) {
      await _updateMediaItem(
        chapterTitle: _currentChapterTitle ?? item.text.split('\n').first,
        coverPath: _currentCoverPath,
      );
    }
  }

  Future<void> _updateMediaItem({
    required String chapterTitle,
    String? coverPath,
  }) async {
    Uri? artUri;
    if (coverPath != null && await File(coverPath).exists()) {
      artUri = Uri.file(coverPath);
    }

    final newMediaItem = MediaItem(
      id: 'tts_$_currentBookId',
      title: chapterTitle, // Chapter title
      artist: _currentBookTitle ?? 'Atlas', // Book title as artist (subtitle)
      album: _currentAuthor ?? 'Atlas', // Author as album
      artUri: artUri,
      duration: _totalSessionDuration,
      extras: {
        'bookId': _currentBookId,
        'chapterTitle': chapterTitle,
        'isTts': true,
      },
    );

    // Emit to the internal BehaviorSubject via the mediaItem getter
    mediaItem.add(newMediaItem);
  }

  Future<void> _clearMediaItem() async {
    _positionTimer?.cancel();
    _positionTimer = null;
    mediaItem.add(null);
    _currentBookId = null;
    _currentBookTitle = null;
    _currentAuthor = null;
    _currentCoverPath = null;
    _currentChapterTitle = null;
    _totalSessionDuration = null;
    _currentPosition = Duration.zero;
  }

  @override
  Future<void> skipToNext() async {
    await _engine.skipNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _engine.skipPrevious();
  }

  @override
  Future<void> seek(Duration position) async {
    // Seek is handled by the engine seeking to the appropriate sentence
    // We update our local position tracking
    _currentPosition = position;
    final current = playbackState.value;
    playbackState.add(
      current.copyWith(
        updatePosition: position,
        speed: _playbackSpeed,
        systemActions: {MediaAction.setSpeed},
      ),
    );
    // Note: Actual seeking to sentence is handled by the engine's skipNext/skipPrevious
    // For fine-grained seeking, we'd need to implement sentence-level seeking in the engine
  }

  /// Set playback speed (0.5x to 2.0x)
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed.clamp(0.5, 2.0);
    await _engine.updateSettings(
      _engine.session?.settings.copyWith(speechRate: _playbackSpeed) ??
          NarrationSettings(speechRate: _playbackSpeed),
    );
    // Update controls to reflect new speed
    _updatePlaybackStateControls();
  }

  void _updatePlaybackStateControls() {
    final current = playbackState.value;
    playbackState.add(
      current.copyWith(
        controls: _controlsFor(playing: current.playing),
        speed: _playbackSpeed,
        systemActions: {MediaAction.setSpeed},
      ),
    );
  }

  List<MediaControl> _controlsFor({required bool playing}) => [
    MediaControl.skipToPrevious,
    playing ? MediaControl.pause : MediaControl.play,
    MediaControl.stop,
    MediaControl.skipToNext,
  ];
}