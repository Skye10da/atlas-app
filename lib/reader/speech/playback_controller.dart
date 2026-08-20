import 'package:audio_service/audio_service.dart';

import 'package:atlas_app/reader/speech/speech_engine.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';

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

  @override
  Future<void> play() => _engine.start();

  @override
  Future<void> pause() => _engine.pause();

  @override
  Future<void> stop() async {
    await _engine.stop();
    await super.stop();
  }

  /// Not part of BaseAudioHandler's standard surface, but exposed for the
  /// Reader to call resume distinctly from a fresh play() where relevant
  /// (e.g. resuming after a driver-level pause rather than starting a new
  /// session).
  Future<void> resumeSpeech() => _engine.resume();

  void _onSpeechEvent(SpeechEvent event) {
    final current = playbackState.value;
    switch (event) {
      case SentenceStarted():
        playbackState.add(
          current.copyWith(
            controls: _controlsFor(playing: true),
            processingState: AudioProcessingState.ready,
            playing: true,
          ),
        );
      case SpeechPaused():
        playbackState.add(
          current.copyWith(
            controls: _controlsFor(playing: false),
            playing: false,
          ),
        );
      case SpeechStopped():
        playbackState.add(
          current.copyWith(
            controls: _controlsFor(playing: false),
            playing: false,
            processingState: AudioProcessingState.idle,
          ),
        );
      case SpeechCompleted():
        playbackState.add(
          current.copyWith(
            playing: false,
            processingState: AudioProcessingState.completed,
          ),
        );
      case SpeechError():
        playbackState.add(
          current.copyWith(
            playing: false,
            processingState: AudioProcessingState.error,
          ),
        );
      // ChapterFinished, SentenceFinished, ParagraphFinished, WordBoundary
      // deliberately don't touch playbackState — they're Reader-facing
      // (chapter navigation, highlighting), not OS-media-session-facing.
      // The Reader's own narration provider listens to _engine.events
      // directly for those, per ASA §6/§7.
      default:
        break;
    }
  }

  List<MediaControl> _controlsFor({required bool playing}) => [
    MediaControl.skipToPrevious,
    playing ? MediaControl.pause : MediaControl.play,
    MediaControl.stop,
    MediaControl.skipToNext,
  ];
}
