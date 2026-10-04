import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/speech/parser/sentence_splitter.dart';
import 'package:atlas_app/reader/speech/pronunciation/apply_pronunciation_use_case.dart';
import 'package:atlas_app/reader/speech/pronunciation/models/pronunciation_rule.dart';
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
  const SpeechSessionBuilder({SentenceSplitter? splitter, ApplyPronunciationUseCase? pronunciationUseCase})
    : _splitter = splitter ?? const SentenceSplitter(),
      _pronunciationUseCase = pronunciationUseCase ?? const ApplyPronunciationUseCase();

  final SentenceSplitter _splitter;
  final ApplyPronunciationUseCase _pronunciationUseCase;

  static final _paragraphBreak = RegExp(r'\n\s*\n');

  SpeechSession build({
    required String bookId,
    required ChapterEntity chapter,
    required String content,
    required String language,
    required NarrationSettings settings,
    int sentenceIndex = 0,
    String? coverPath,
    String? bookTitle,
    String? author,
    String? chapterTitle,
    List<PronunciationRule> pronunciationRules = const [],
  }) {
    final rawParagraphs = content
        .split(_paragraphBreak)
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final paragraphs = <String>[];
    final title = (chapterTitle ?? chapter.title).trim();
    final shouldAnnounce =
        settings.announceChapterTitle &&
        title.isNotEmpty &&
        !content.trim().startsWith(title);
    if (shouldAnnounce) {
      paragraphs.add(title);
    }
    paragraphs.addAll(rawParagraphs);

    // Stability-isolated pronunciation: only when explicitly enabled
    final effectiveParagraphs = settings.pronunciationEnabled && pronunciationRules.isNotEmpty
        ? paragraphs.map((p) => _pronunciationUseCase.normalize(p, pronunciationRules)).toList()
        : paragraphs;

    var items = _splitter.splitChapter(
      bookId: bookId,
      chapterId: chapter.id,
      paragraphs: effectiveParagraphs,
      language: language,
      voiceId: settings.selectedVoiceId,
      speechRate: settings.speechRate,
    );

    // Second pass for SpeechItem-level idempotent normalize (handles rules that add boundaries)
    if (settings.pronunciationEnabled && pronunciationRules.isNotEmpty) {
      items = _pronunciationUseCase(items, pronunciationRules);
    }

    final queue = SpeechQueue(items);
    if (sentenceIndex > 0) queue.seekTo(sentenceIndex);

    return SpeechSession(
      bookId: bookId,
      chapterId: chapter.id,
      queue: queue,
      settings: settings,
      coverPath: coverPath,
      bookTitle: bookTitle,
      author: author,
    );
  }
}
