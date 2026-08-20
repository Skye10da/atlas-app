import 'package:atlas_app/reader/speech/parser/sentence_splitter.dart';

/// Maps between a chapter's raw text, a character offset in that text, and a
/// *flat* sentence index into a deterministically rebuildable sequence of
/// sentences.
///
/// The sentence sequence is re-derived from raw text alone — paragraph
/// segments split on blank lines (`\n\s*\n`), then each paragraph split into
/// sentences — exactly as [SpeechSessionBuilder] derives its narration queue
/// and as narration highlights its current sentence. Because the sequence is
/// a pure function of the content (independent of font size, line height,
/// margins, theme, or screen size), a flat `sentenceIndex` is a stable,
/// layout-independent address for "an exact spot in a chapter" — the reading-
/// position equivalent of a SpeechCheckpoint's `sentenceIndex`.
class ChapterPositionResolver {
  const ChapterPositionResolver({this.splitter = const SentenceSplitter()});

  static final _paragraphBreak = RegExp(r'\n\s*\n');

  final SentenceSplitter splitter;

  /// Returns the paragraph segments of [content] in render order, recording
  /// each paragraph's start offset within the raw content. Only non-empty
  /// (after trim) paragraphs are kept, matching the narration pipeline and the
  /// reader's paragraph rendering.
  List<({int offset, String text})> paragraphsOf(String content) {
    final segments = <({int offset, String text})>[];
    var segStart = 0;
    for (final match in _paragraphBreak.allMatches(content)) {
      final seg = content.substring(segStart, match.start);
      if (seg.trim().isNotEmpty) segments.add((offset: segStart, text: seg));
      segStart = match.end;
    }
    final tail = content.substring(segStart);
    if (tail.trim().isNotEmpty) segments.add((offset: segStart, text: tail));
    return segments;
  }

  /// Builds the flat list of sentences across the whole chapter: each entry is
  /// the character offset (within [content]) of the first character of that
  /// sentence, keyed by its flat index.
  List<int> sentenceStartOffsets(String content) {
    final offsets = <int>[];
    for (final para in paragraphsOf(content)) {
      final raw = para.text;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final paraOffsetInRaw = raw.indexOf(trimmed);
      for (final span in splitter.splitParagraphSpans(trimmed)) {
        offsets.add(para.offset + paraOffsetInRaw + span.offset);
      }
    }
    return offsets;
  }

  /// The number of sentences in [content]'s reconstructed sequence.
  int totalSentences(String content) => sentenceStartOffsets(content).length;

  /// The character offset in [content] where the sentence at flat index
  /// [flatIndex] begins. Returns `null` when [flatIndex] is out of range or
  /// the content has no sentences. This is a direct, flat-indexed analogue of
  /// the narration highlight lookup.
  int? charOffsetForSentenceIndex(String content, int flatIndex) {
    if (flatIndex < 0) return null;
    final offsets = sentenceStartOffsets(content);
    if (offsets.isEmpty || flatIndex >= offsets.length) return null;
    return offsets[flatIndex];
  }

  /// Resolves both the flat sentence index for [charOffset] *and* the total
  /// sentence count in one pass — for callers that need both (e.g. persisting
  /// a reading position). Cheap when [content] has few sentences; always a
  /// single scan of the content.
  ({int index, int total}) resolve(String content, int charOffset) {
    final offsets = sentenceStartOffsets(content);
    if (offsets.isEmpty) return (index: 0, total: 0);
    var index = 0;
    if (charOffset < 0) {
      index = 0;
    } else if (charOffset >= content.length) {
      index = offsets.length - 1;
    } else {
      for (var i = offsets.length - 1; i >= 0; i--) {
        if (offsets[i] <= charOffset) {
          index = i;
          break;
        }
      }
    }
    return (index: index, total: offsets.length);
  }

  /// The flat sentence index for the character offset [charOffset], choosing
  /// the sentence whose start is closest at/before that offset (clamped to the
  /// valid range). Returns `null` for empty content.
  int? sentenceIndexForOffset(String content, int charOffset) {
    if (charOffset < 0) return null;
    final offsets = sentenceStartOffsets(content);
    if (offsets.isEmpty) return null;
    if (charOffset >= content.length) return offsets.length - 1;
    for (var i = offsets.length - 1; i >= 0; i--) {
      if (offsets[i] <= charOffset) return i;
    }
    return 0;
  }
}
