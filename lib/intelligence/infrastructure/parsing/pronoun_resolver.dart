/// Ultra-conservative pronoun resolver for same-paragraph clause binding.
class PronounResolver {
  const PronounResolver();

  /// Given a pronoun occurrence and recent candidate names in the preceding sentence,
  /// resolves the pronoun if and only if exactly one candidate is unambiguous.
  String? resolve({
    required String pronoun,
    required List<String> recentCandidatesInParagraph,
  }) {
    final lower = pronoun.toLowerCase().trim();
    if (lower != 'he' && lower != 'him' && lower != 'his' &&
        lower != 'she' && lower != 'her' && lower != 'hers') {
      return null;
    }

    // Only resolve if there is strictly one unambiguous candidate in the immediate vicinity
    final uniqueCandidates = recentCandidatesInParagraph.toSet();
    if (uniqueCandidates.length == 1) {
      return uniqueCandidates.first;
    }

    // Multiple or zero candidates => ambiguous, emit nothing
    return null;
  }
}

