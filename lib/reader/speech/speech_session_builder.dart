import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/speech/parser/sentence_splitter.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_queue.dart';
import 'package:atlas_app/reader/speech/speech_session.dart';

/// Builds a [SpeechSession] for a chapter from its plain-text content.
///
/// Paragraphs are derived from blank-line-separated runs (the same shape the
/// Reader renders), then split into sentence-sized [SpeechItem]s. This is the
/// Reader-side implementation of ASA §8's "Restore Queue": the queue is never
/// persisted verbatim, just re-derived from chapterId+bookId and seeked to the
/// checkpointed sentence index.
class SpeechSessionBuilder {
  const SpeechSessionBuilder({SentenceSplitter? splitter})
    : _splitter = splitter ?? const SentenceSplitter();

  final SentenceSplitter _splitter;

  static final _paragraphBreak = RegExp(r'\n\s*\n');

  SpeechSession build({
    required String bookId,
    required ChapterEntity chapter,
    required String content,
    required String language,
    required NarrationSettings settings,
    int sentenceIndex = 0,
  }) {
    final paragraphs = content
        .split(_paragraphBreak)
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final items = _splitter.splitChapter(
      bookId: bookId,
      chapterId: chapter.id,
      paragraphs: paragraphs,
      language: language,
      voiceId: settings.selectedVoiceId,
    );

    final queue = SpeechQueue(items);
    if (sentenceIndex > 0) queue.seekTo(sentenceIndex);

    return SpeechSession(
      bookId: bookId,
      chapterId: chapter.id,
      queue: queue,
      settings: settings,
    );
  }
}