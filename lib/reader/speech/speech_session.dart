import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';
import 'package:atlas_app/reader/speech/speech_queue.dart';

/// Unifies queue position, checkpoint, and settings into the single unit
/// of state that both SpeechEngine and the Recovery Store operate on
/// (ASA §2). Previously (v1.1) these were three separately-tracked things;
/// unifying them is what makes startup's "Restore Queue" a single
/// operation instead of three reconciled ones.
class SpeechSession {
  SpeechSession({
    required this.bookId,
    required this.chapterId,
    required this.queue,
    required this.settings,
    this.elapsed = Duration.zero,
  });

  final String bookId;
  final String chapterId;
  final SpeechQueue queue;
  NarrationSettings settings;
  Duration elapsed;

  SpeechItem? get currentItem => queue.current;

  SpeechCheckpoint toCheckpoint() => SpeechCheckpoint(
        bookId: bookId,
        chapterId: chapterId,
        sentenceIndex: queue.cursor,
        elapsed: elapsed,
      );
}

/// The minimal serializable shape persisted by the Recovery Store. The
/// full SpeechQueue (and its SpeechItem text) is re-derived from
/// chapterId+bookId on restore rather than persisted verbatim — see ASA
/// §8, "Restore Queue".
class SpeechCheckpoint {
  const SpeechCheckpoint({
    required this.bookId,
    required this.chapterId,
    required this.sentenceIndex,
    required this.elapsed,
  });

  factory SpeechCheckpoint.fromJson(Map<String, dynamic> json) => SpeechCheckpoint(
        bookId: json['bookId'] as String,
        chapterId: json['chapterId'] as String,
        sentenceIndex: json['sentenceIndex'] as int,
        elapsed: Duration(milliseconds: json['elapsedMs'] as int),
      );

  final String bookId;
  final String chapterId;
  final int sentenceIndex;
  final Duration elapsed;

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'chapterId': chapterId,
        'sentenceIndex': sentenceIndex,
        'elapsedMs': elapsed.inMilliseconds,
      };
}
