import 'dart:math' as math;

/// String similarity and transliteration variant matching for romanized names.
class TransliterationMatcher {
  const TransliterationMatcher();

  /// Normalizes a name by stripping hyphens, apostrophes, and collapsing spaces.
  String normalizeName(String name) {
    return name
        .replaceAll(RegExp(r'[\x27\x22\-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  /// Calculates a combined similarity score (0.0 to 1.0) using normalized
  /// Levenshtein distance and phonetic matching.
  double similarity(String a, String b) {
    if (a == b) return 1.0;
    final normA = normalizeName(a);
    final normB = normalizeName(b);
    if (normA == normB) return 1.0;
    if (normA.isEmpty || normB.isEmpty) return 0.0;

    // Direct subset / prefix match e.g. "Dong" in "Lin Dong"
    if (normA.length > 2 && normB.length > 2) {
      if (normA.contains(normB) || normB.contains(normA)) {
        final ratio = math.min(normA.length, normB.length) / math.max(normA.length, normB.length);
        if (ratio >= 0.5) {
          return 0.80 + (ratio * 0.15);
        }
      }
    }

    final editDist = _levenshteinDistance(normA, normB);
    final maxLen = math.max(normA.length, normB.length);
    final levSim = 1.0 - (editDist / maxLen);

    // Phonetic code boost
    final soundexA = _soundex(normA);
    final soundexB = _soundex(normB);
    final phoneticMatch = (soundexA.isNotEmpty && soundexA == soundexB);

    if (phoneticMatch) {
      return math.min(1.0, levSim + 0.15);
    }

    return levSim;
  }

  /// Returns true if [a] and [b] are likely spelling/transliteration variants of the same entity.
  bool isPotentialAlias(String a, String b, {double threshold = 0.75}) {
    return similarity(a, b) >= threshold;
  }

  /// Phonetic Soundex code of a normalized name. Extraction passes use this
  /// to build a cheap per-type phonetic index once per chapter, so fuzzy alias
  /// matching only runs the (expensive) full similarity on plausible buckets
  /// instead of every known entity.
  String soundexCode(String name) => _soundex(normalizeName(name));

  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final v0 = List<int>.generate(s2.length + 1, (i) => i);
    final v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = math.min(
          v1[j] + 1,
          math.min(v0[j + 1] + 1, v0[j] + cost),
        );
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }

  String _soundex(String s) {
    final clean = s.replaceAll(RegExp(r'[^a-z]'), '');
    if (clean.isEmpty) return '';

    final first = clean[0].toUpperCase();
    final chars = clean.substring(1);
    final code = StringBuffer(first);

    String lastCode = _soundexDigit(first.toLowerCase());

    for (int i = 0; i < chars.length && code.length < 4; i++) {
      final digit = _soundexDigit(chars[i]);
      if (digit != '0' && digit != lastCode) {
        code.write(digit);
      }
      lastCode = digit;
    }

    while (code.length < 4) {
      code.write('0');
    }

    return code.toString();
  }

  String _soundexDigit(String char) {
    switch (char) {
      case 'b': case 'f': case 'p': case 'v':
        return '1';
      case 'c': case 'g': case 'j': case 'k': case 'q': case 's': case 'x': case 'z':
        return '2';
      case 'd': case 't':
        return '3';
      case 'l':
        return '4';
      case 'm': case 'n':
        return '5';
      case 'r':
        return '6';
      default:
        return '0';
    }
  }
}

