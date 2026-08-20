/// Text tokenizer shared by the Search Indexer, Dictionary Indexer and
/// Character Extractor: splits on non-alphanumerics, lowercases, strips
/// possessives, and drops common stopwords so indexes stay compact.
class Tokenizer {
  const Tokenizer({Set<String>? stopwords})
    : stopwords = stopwords ?? _defaultStopwords;

  final Set<String> stopwords;

  static const _defaultStopwords = <String>{
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'but',
    'by',
    'for',
    'from',
    'has',
    'have',
    'he',
    'her',
    'hers',
    'him',
    'his',
    'i',
    'if',
    'in',
    'into',
    'is',
    'it',
    'its',
    'me',
    'my',
    'no',
    'nor',
    'not',
    'of',
    'on',
    'or',
    'our',
    'ours',
    'so',
    'than',
    'that',
    'the',
    'their',
    'theirs',
    'them',
    'then',
    'there',
    'these',
    'they',
    'this',
    'those',
    'to',
    'us',
    'was',
    'we',
    'were',
    'what',
    'when',
    'where',
    'which',
    'who',
    'whom',
    'why',
    'will',
    'with',
    'you',
    'your',
    'yours',
  };

  /// Tokenizes [text] into normalized, stopword-free terms in order.
  List<String> tokenize(String text) {
    final terms = <String>[];
    for (final match in RegExp(r"[A-Za-z][A-Za-z'\-]*").allMatches(text)) {
      var word = match.group(0)!.toLowerCase();
      if (word.endsWith("'s")) word = word.substring(0, word.length - 2);
      if (word.length < 2) continue;
      if (stopwords.contains(word)) continue;
      terms.add(word);
    }
    return terms;
  }
}
