import 'package:atlas_app/reader/speech/speech_models.dart';

/// Splits chapter paragraph text into SpeechItems. Deliberately takes plain
/// paragraph strings rather than an AtlasDocument directly, so this file
/// has no dependency on the reader/content-engine's exact document shape —
/// whatever calls this just needs to pass `List<String>` paragraph text
/// plus the metadata each resulting SpeechItem needs.
class SentenceSplitter {
  const SentenceSplitter();

  /// Conservative shared ceiling below both Android's
  /// getMaxSpeechInputLength and iOS's practical AVSpeechUtterance limit,
  /// so the same split works cross-platform without per-platform
  /// branching (ASA §4).
  static const int maxChunkChars = 3800;

  List<SpeechItem> splitChapter({
    required String bookId,
    required String chapterId,
    required List<String> paragraphs,
    required String language,
    String? voiceId,
  }) {
    final items = <SpeechItem>[];
    for (var pIndex = 0; pIndex < paragraphs.length; pIndex++) {
      final sentences = _splitSentences(paragraphs[pIndex]);
      var sIndex = 0;
      for (final sentence in sentences) {
        for (final piece in _hardSplitIfTooLong(sentence, maxChunkChars)) {
          if (piece.trim().isEmpty) continue;
          items.add(SpeechItem(
            bookId: bookId,
            chapterId: chapterId,
            paragraphIndex: pIndex,
            sentenceIndex: sIndex,
            text: piece.trim(),
            language: language,
            voiceId: voiceId,
          ));
          sIndex++;
        }
      }
    }
    return items;
  }

  /// Splits on '.', '!', '?' followed by whitespace (or end of string),
  /// while avoiding splits on common abbreviations and decimal numbers.
  /// This mirrors the sentence-boundary heuristic already used by the
  /// reader's word-lookup context menu (`_sentenceAround` in
  /// PagedReaderLayout) — worth eventually sharing one implementation
  /// between the two rather than maintaining two similar heuristics.
  List<String> _splitSentences(String paragraph) =>
      splitParagraphSpans(paragraph).map((s) => s.text).toList();

  /// Splits [paragraph] into sentence substrings, returning each one with the
  /// character offset of its first character within the trimmed paragraph.
  /// Callers can use the offsets to pin a specific [SpeechItem.sentenceIndex]
  /// to its exact position in the rendered text even when the same words
  /// (e.g. a character's name) appear earlier in the chapter.
  List<({String text, int offset})> splitParagraphSpans(String paragraph) {
    final text = paragraph.trim();
    if (text.isEmpty) return const [];

    final spans = <({String text, int offset})>[];
    final buffer = StringBuffer();
    var sentenceStart = 0;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(char);

      final isTerminator = char == '.' || char == '!' || char == '?';
      if (!isTerminator) continue;

      final nextChar = i + 1 < text.length ? text[i + 1] : null;
      final isEnd = nextChar == null || nextChar == ' ' || nextChar == '\n';
      if (!isEnd) continue;

      if (char == '.' && _looksLikeAbbreviationOrDecimal(text, i)) continue;

      final raw = buffer.toString();
      final sentence = raw.trim();
      if (sentence.isNotEmpty) {
        spans.add((
          text: sentence,
          offset: sentenceStart + raw.indexOf(sentence),
        ));
      }
      buffer.clear();
      sentenceStart = i + 1;
    }

    final restRaw = buffer.toString();
    final rest = restRaw.trim();
    if (rest.isNotEmpty) {
      spans.add((text: rest, offset: sentenceStart + restRaw.indexOf(rest)));
    }
    return spans;
  }

  static final _abbreviations = {
    'mr', 'mrs', 'ms', 'dr', 'prof', 'sr', 'jr', 'st', 'vs', 'etc', 'e.g', 'i.e',
  };

  bool _looksLikeAbbreviationOrDecimal(String text, int dotIndex) {
    // Decimal number: digit immediately before and after the dot.
    final before = dotIndex > 0 ? text[dotIndex - 1] : '';
    final after = dotIndex + 1 < text.length ? text[dotIndex + 1] : '';
    if (_isDigit(before) && _isDigit(after)) return true;

    // Abbreviation: the word ending at this dot matches a known list.
    var start = dotIndex;
    while (start > 0 && text[start - 1] != ' ' && text[start - 1] != '\n') {
      start--;
    }
    final word = text.substring(start, dotIndex).toLowerCase();
    return _abbreviations.contains(word);
  }

  bool _isDigit(String s) => s.isNotEmpty && s.codeUnitAt(0) >= 48 && s.codeUnitAt(0) <= 57;

  List<String> _hardSplitIfTooLong(String sentence, int maxChars) {
    if (sentence.length <= maxChars) return [sentence];
    // Fall back to splitting on the nearest whitespace before the limit,
    // so we don't cut a word in half.
    final pieces = <String>[];
    var remaining = sentence;
    while (remaining.length > maxChars) {
      var splitAt = remaining.lastIndexOf(' ', maxChars);
      if (splitAt <= 0) splitAt = maxChars;
      pieces.add(remaining.substring(0, splitAt).trim());
      remaining = remaining.substring(splitAt).trim();
    }
    if (remaining.isNotEmpty) pieces.add(remaining);
    return pieces;
  }
}
