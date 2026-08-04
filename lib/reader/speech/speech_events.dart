import 'package:atlas_app/reader/speech/speech_models.dart';

/// Events emitted by SpeechEngine. The Reader (and any other UI) should
/// only ever listen to this stream — never to a SpeechDriver's events or
/// audio_service's playbackState directly. That indirection is what keeps
/// a future driver swap (see ASA §13) from touching the Reader at all.
sealed class SpeechEvent {
  const SpeechEvent();
}

class SpeechStarted extends SpeechEvent {
  const SpeechStarted(this.item);
  final SpeechItem item;
}

class SentenceStarted extends SpeechEvent {
  const SentenceStarted(this.item);
  final SpeechItem item;
}

class SentenceFinished extends SpeechEvent {
  const SentenceFinished(this.item);
  final SpeechItem item;
}

class ParagraphFinished extends SpeechEvent {
  const ParagraphFinished(this.item);
  final SpeechItem item;
}

class ChapterFinished extends SpeechEvent {
  const ChapterFinished(this.chapterId);
  final String chapterId;
}

class SpeechPaused extends SpeechEvent {
  const SpeechPaused();
}

class SpeechStopped extends SpeechEvent {
  const SpeechStopped();
}

class SpeechCompleted extends SpeechEvent {
  const SpeechCompleted();
}

class SpeechError extends SpeechEvent {
  const SpeechError(this.message, {this.item});
  final String message;
  final SpeechItem? item;
}

class WordBoundary extends SpeechEvent {
  const WordBoundary(this.item, this.start, this.end, this.word);
  final SpeechItem item;
  final int start;
  final int end;
  final String word;
}

/// Lower-level events a SpeechDriver implementation emits; SpeechEngine
/// translates these (plus its own queue bookkeeping) into the SpeechEvent
/// stream above. Kept separate so a driver never needs to know about
/// paragraphs/chapters/queues — only about the single item it was asked
/// to speak.
sealed class SpeechDriverEvent {
  const SpeechDriverEvent();
}

class DriverStarted extends SpeechDriverEvent {
  const DriverStarted();
}

class DriverPaused extends SpeechDriverEvent {
  const DriverPaused();
}

class DriverResumed extends SpeechDriverEvent {
  const DriverResumed();
}

class DriverCompleted extends SpeechDriverEvent {
  const DriverCompleted();
}

class DriverError extends SpeechDriverEvent {
  const DriverError(this.message);
  final String message;
}

class DriverWordBoundary extends SpeechDriverEvent {
  const DriverWordBoundary(this.start, this.end, this.word);
  final int start;
  final int end;
  final String word;
}
