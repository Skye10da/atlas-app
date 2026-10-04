/// Manages genre-specific honorifics, titles, and familial forms.
class HonorificDictionary {
  const HonorificDictionary();

  /// Xianxia / Wuxia prefix titles
  static const Set<String> xianxiaPrefixes = {
    'daoist', 'elder', 'young master', 'sect leader', 'senior brother',
    'senior sister', 'junior brother', 'junior sister', 'grandmaster',
    'patriarch', 'ancestor', 'venerable', 'sovereign', 'monarch',
    'emperor', 'empress', 'fairy', 'immortal', 'alchemist', 'master',
    'hall master', 'pavilion master', 'clan leader', 'great elder',
  };

  /// Western fantasy titles
  static const Set<String> westernPrefixes = {
    'lord', 'lady', 'sir', 'dame', 'duke', 'duchess', 'baron', 'baroness',
    'count', 'countess', 'earl', 'marquess', 'king', 'queen', 'prince',
    'princess', 'archmage', 'grand mage', 'mage', 'captain', 'general',
    'commander', 'knight', 'father', 'bishop', 'pope', 'priest',
  };

  /// Korean and Japanese honorific suffixes (transliterated)
  static const Set<String> suffixes = {
    '-ge', '-er', '-jie', '-shixiong', '-shidi', '-shijie', '-shimei',
    '-sama', '-san', '-kun', '-chan', '-sensei', '-senpai', '-dono',
    '-hyung', '-oppa', '-noona', '-unnie', '-sunbae',
  };

  /// Returns true if [word] is an honorific prefix.
  bool isPrefix(String word) {
    final lower = word.toLowerCase().trim();
    return xianxiaPrefixes.contains(lower) || westernPrefixes.contains(lower);
  }

  /// Returns true if [token] ends with a recognized honorific suffix.
  bool hasSuffix(String token) {
    final lower = token.toLowerCase().trim();
    for (final s in suffixes) {
      if (lower.endsWith(s)) return true;
    }
    return false;
  }

  /// Strips known prefixes or suffixes from [nameCandidate] to resolve to a base name.
  String stripHonorifics(String nameCandidate) {
    var cleaned = nameCandidate.trim();

    // Check prefixes (longest first)
    final allPrefixes = [...xianxiaPrefixes, ...westernPrefixes]
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final p in allPrefixes) {
      if (cleaned.toLowerCase().startsWith('$p ')) {
        cleaned = cleaned.substring(p.length).trim();
        break;
      }
    }

    // Check suffixes
    for (final s in suffixes) {
      if (cleaned.toLowerCase().endsWith(s)) {
        cleaned = cleaned.substring(0, cleaned.length - s.length).trim();
        break;
      }
    }

    return cleaned;
  }

  /// Extracts candidate name pairs from text matching `[Title] [Name]`.
  List<HonorificMatch> extractHonorificMentions(String text) {
    final results = <HonorificMatch>[];
    final allPrefixes = [...xianxiaPrefixes, ...westernPrefixes];

    for (final prefix in allPrefixes) {
      // e.g. "Young Master Lin", "Elder Mo"
      final prefixPattern = _toCaseFlexiblePattern(prefix);
      final pattern = RegExp(
        r'\b' + prefixPattern + r'\s+([A-Z][a-zA-Z\x27\-]+(?:\s+[A-Z][a-zA-Z\x27\-]+)?)\b',
      );

      for (final m in pattern.allMatches(text)) {
        final rawName = m.group(1)?.trim();
        if (rawName != null && rawName.length >= 2) {
          results.add(
            HonorificMatch(
              honorific: prefix,
              baseName: rawName,
              fullExpression: m.group(0) ?? '',
              startIndex: m.start,
              endIndex: m.end,
              confidenceContribution: 0.35,
            ),
          );
        }
      }
    }

    return results;
  }

  String _toCaseFlexiblePattern(String prefix) {
    return prefix.split(' ').map((word) {
      if (word.isEmpty) return '';
      final first = word[0];
      final rest = word.substring(1);
      return '[${first.toUpperCase()}${first.toLowerCase()}]$rest';
    }).join(r'\s+');
  }
}

class HonorificMatch {
  const HonorificMatch({
    required this.honorific,
    required this.baseName,
    required this.fullExpression,
    required this.startIndex,
    required this.endIndex,
    required this.confidenceContribution,
  });

  final String honorific;
  final String baseName;
  final String fullExpression;
  final int startIndex;
  final int endIndex;
  final double confidenceContribution;
}
