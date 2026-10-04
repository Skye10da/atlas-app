import 'dart:math' as math;

/// Offline, deterministic extractive summarizer using TF-IDF sentence scoring.
///
/// 100% offline, zero AI, runs entirely in pure Dart.
class ExtractiveSummarizer {
  const ExtractiveSummarizer();

  static const _stopWords = {
    'a', 'about', 'above', 'after', 'again', 'against', 'all', 'am', 'an',
    'and', 'any', 'are', 'aren\'t', 'as', 'at', 'be', 'because', 'been',
    'before', 'being', 'below', 'between', 'both', 'but', 'by', 'can\'t',
    'cannot', 'could', 'couldn\'t', 'did', 'didn\'t', 'do', 'does', 'doesn\'t',
    'doing', 'don\'t', 'down', 'during', 'each', 'few', 'for', 'from',
    'further', 'had', 'hadn\'t', 'has', 'hasn\'t', 'have', 'haven\'t', 'having',
    'he', 'he\'d', 'he\'ll', 'he\'s', 'her', 'here', 'here\'s', 'hers',
    'herself', 'him', 'himself', 'his', 'how', 'how\'s', 'i', 'i\'d', 'i\'ll',
    'i\'m', 'i\'ve', 'if', 'in', 'into', 'is', 'isn\'t', 'it', 'it\'s', 'its',
    'itself', 'let\'s', 'me', 'more', 'most', 'mustn\'t', 'my', 'myself',
    'no', 'nor', 'not', 'of', 'off', 'on', 'once', 'only', 'or', 'other',
    'ought', 'our', 'ours', 'ourselves', 'out', 'over', 'own', 'same',
    'shan\'t', 'she', 'she\'d', 'she\'ll', 'she\'s', 'should', 'shouldn\'t',
    'so', 'some', 'such', 'than', 'that', 'that\'s', 'the', 'their', 'theirs',
    'them', 'themselves', 'then', 'there', 'there\'s', 'these', 'they',
    'they\'d', 'they\'ll', 'they\'re', 'they\'ve', 'this', 'those', 'through',
    'to', 'too', 'under', 'until', 'up', 'very', 'was', 'wasn\'t', 'we',
    'we\'d', 'we\'ll', 'we\'re', 'we\'ve', 'were', 'weren\'t', 'what',
    'what\'s', 'when', 'when\'s', 'where', 'where\'s', 'which', 'while',
    'who', 'who\'s', 'whom', 'why', 'why\'s', 'with', 'won\'t', 'would',
    'wouldn\'t', 'you', 'you\'d', 'you\'ll', 'you\'re', 'you\'ve', 'your',
    'yours', 'yourself', 'yourselves',
  };

  /// Extracts the most salient [targetSentences] from [text], preserving original narrative order.
  String summarize(String text, {int targetSentences = 3}) {
    final sentences = _splitSentences(text);
    if (sentences.isEmpty) return '';
    if (sentences.length <= targetSentences) {
      return sentences.join(' ');
    }

    // Tokenize each sentence into non-stopword terms
    final tokenizedSentences = sentences.map(_tokenize).toList();

    // Compute document frequency for all words across sentences
    final docFrequency = <String, int>{};
    for (final tokens in tokenizedSentences) {
      final seenInSentence = tokens.toSet();
      for (final word in seenInSentence) {
        docFrequency[word] = (docFrequency[word] ?? 0) + 1;
      }
    }

    final totalSentences = sentences.length;

    // Compute TF-IDF score for each sentence
    final scores = List<double>.filled(totalSentences, 0.0);

    for (var i = 0; i < totalSentences; i++) {
      final tokens = tokenizedSentences[i];
      if (tokens.isEmpty) continue;

      // Term frequencies in this sentence
      final termCounts = <String, int>{};
      for (final t in tokens) {
        termCounts[t] = (termCounts[t] ?? 0) + 1;
      }

      var rawScore = 0.0;
      for (final entry in termCounts.entries) {
        final term = entry.key;
        final docFreq = docFrequency[term] ?? 1;
        // In a single document, terms appearing across multiple sentences are central topic keywords
        final termWeight = 1.0 + math.log(docFreq.toDouble());
        rawScore += entry.value * termWeight;
      }

      // Position bias: slight boost to early and closing sentences
      var positionBonus = 1.0;
      if (i < 3) {
        positionBonus += 0.20 * (3 - i);
      } else if (i == totalSentences - 1) {
        positionBonus += 0.15;
      }

      // Dampen sentence length impact using square root of token length
      final lengthNorm = math.sqrt(tokens.length.toDouble());
      scores[i] = (rawScore / lengthNorm) * positionBonus;
    }

    // Rank sentence indices by score descending
    final indexedScores = List.generate(totalSentences, (i) => i);
    indexedScores.sort((a, b) => scores[b].compareTo(scores[a]));

    // Pick top sentence indices and sort back to chronological order
    final selectedIndices = indexedScores.take(targetSentences).toList()..sort();

    return selectedIndices.map((i) => sentences[i]).join(' ');
  }

  List<String> _splitSentences(String text) {
    // Split on sentence terminators while preserving quotation contexts
    final raw = text.split(RegExp(r'(?<=[.!?。！？]["\u201D\u2019]?)\s+'));
    return raw
        .map((s) => s.trim())
        .where((s) => s.length >= 15 && !s.startsWith('#'))
        .toList();
  }

  List<String> _tokenize(String sentence) {
    final words = sentence
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
        .split(RegExp(r'\s+'));

    return words
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toList();
  }
}
