import 'package:atlas_app/core/content_engine/models/atlas_document.dart';

/// Heuristic character/entity extraction: surfaces capitalized words that
/// appear in mid-sentence positions (i.e. not capitalized merely because they
/// start a sentence) and records them as `Annotation`s of type `character` (or
/// `place` for known place-name markers).
///
/// This is deliberately simple — a real NER pipeline is out of scope — but it
/// gives the reader a first-pass "who appears here" surface that later stages
/// (or an LLM) can refine.
class CharacterExtractor {
  const CharacterExtractor({this.minMentions = 2, this.minLength = 3});

  /// A candidate must appear this many times in mid-sentence position.
  final int minMentions;

  /// Ignore candidates shorter than this (filters initials, stray letters).
  final int minLength;

  static final _sentenceEnd = RegExp(r'[.!?]');
  static final _word = RegExp(r"[A-Za-z][A-Za-z']*");
  static const _stopwords = {
    'The',
    'A',
    'An',
    'And',
    'But',
    'Or',
    'Nor',
    'For',
    'Yet',
    'So',
    'He',
    'She',
    'It',
    'We',
    'They',
    'You',
    'I',
    'As',
    'At',
    'By',
    'To',
    'In',
    'On',
    'Of',
    'From',
    'With',
    'This',
    'That',
    'These',
    'Those',
    'His',
    'Her',
    'Their',
    'Our',
    'My',
    'Your',
  };
  static const _placeMarkers = {
    'City',
    'Town',
    'Village',
    'Kingdom',
    'Forest',
    'Mountain',
    'River',
    'Palace',
    'Castle',
    'School',
    'Tower',
    'Island',
    'Valley',
    'Harbor',
    'Harbour',
    'Province',
    'County',
    'Street',
    'Road',
    'District',
    'Hall',
  };

  /// Returns `type: character|place` annotations for repeated mid-sentence
  /// capitalized candidates, ordered by mention count descending.
  List<Annotation> extract(AtlasDocument document) {
    final counts = <String, int>{};
    for (final block in document.textBlocks) {
      for (final sentence in block.text.split(_sentenceEnd)) {
        final matches = _word.allMatches(sentence).toList();
        for (var i = 0; i < matches.length; i++) {
          if (i == 0) continue; // sentence-initial: too ambiguous
          final word = matches[i].group(0)!;
          if (!_isCandidate(word)) continue;
          counts[word] = (counts[word] ?? 0) + 1;
        }
      }
    }

    final sorted = counts.entries.where((e) => e.value >= minMentions).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .map(
          (e) => Annotation(
            text: e.key,
            type: _placeMarkers.contains(e.key) ? 'place' : 'character',
            target: '${document.metadata.sourceUrl ?? ''}#${e.key}',
          ),
        )
        .toList();
  }

  bool _isCandidate(String word) {
    if (word.length < minLength) return false;
    if (word[0] != word[0].toUpperCase()) return false;
    if (word != word[0].toUpperCase() + word.substring(1)) return false;
    if (_stopwords.contains(word)) return false;
    return true;
  }
}
