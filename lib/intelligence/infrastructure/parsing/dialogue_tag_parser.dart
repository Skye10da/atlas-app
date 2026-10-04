/// A dialogue attribution match extracted from chapter prose.
class DialogueTagMatch {
  const DialogueTagMatch({
    required this.speakerName,
    required this.tagVerb,
    required this.startIndex,
    required this.endIndex,
    required this.confidenceContribution,
  });

  /// The candidate speaker name extracted from the dialogue tag.
  final String speakerName;

  /// The dialogue speech verb (e.g. "said", "replied", "murmured", "asked").
  final String tagVerb;

  /// Character start offset within the searched paragraph/chapter.
  final int startIndex;

  /// Character end offset.
  final int endIndex;

  /// Baseline signal strength for dialogue attribution (typically 0.35 - 0.50).
  final double confidenceContribution;
}

/// Parses direct speech and nearby attribution verbs to identify speaker names.
class DialogueTagParser {
  const DialogueTagParser();

  static const List<String> _verbs = [
    'said', 'replied', 'asked', 'whispered', 'muttered', 'shouted', 'yelled',
    'screamed', 'cried', 'roared', 'growled', 'sneered', 'chuckled', 'laughed',
    'sighed', 'groaned', 'gasped', 'murmured', 'commanded', 'ordered', 'demanded',
    'barked', 'urged', 'snapped', 'breathed', 'snorted', 'nodded', 'added',
    'continued', 'inquired', 'retorted', 'pleaded', 'begged', 'declared',
    'mused', 'wondered', 'interrupted', 'echoed', 'threatened', 'warned',
  ];

  static final String _verbPattern = _verbs.join('|');

  // Match: "Speech quote" [,] said Name / Name said
  // Supports both straight ("...") and curly (“...”) quotes.
  static final RegExp _postSpeechSaidNameRegex = RegExp(
    r'["”]\s*(?:,?\s*)(?:' + _verbPattern + r')\s+([A-Z][a-zA-Z\x27\-]+(?:\s+[A-Z][a-zA-Z\x27\-]+){0,3})',
  );

  static final RegExp _postSpeechNameSaidRegex = RegExp(
    r'["”]\s*(?:,?\s*)([A-Z][a-zA-Z\x27\-]+(?:\s+[A-Z][a-zA-Z\x27\-]+){0,3})\s+(?:' + _verbPattern + r')\b',
  );

  // Match: Name said, "Speech quote"
  static final RegExp _preSpeechNameSaidRegex = RegExp(
    r'([A-Z][a-zA-Z\x27\-]+(?:\s+[A-Z][a-zA-Z\x27\-]+){0,3})\s+(?:' + _verbPattern + r')(?:\s*,\s*|\s*:\s*)["“]',
  );

  /// Extracts dialogue tag matches from [text].
  List<DialogueTagMatch> parse(String text) {
    if (text.isEmpty) return const [];
    final matches = <DialogueTagMatch>[];

    // 1. "..." said Name
    for (final m in _postSpeechSaidNameRegex.allMatches(text)) {
      final name = m.group(1)?.trim();
      if (name != null && _isValidNameCandidate(name)) {
        matches.add(
          DialogueTagMatch(
            speakerName: name,
            tagVerb: 'said',
            startIndex: m.start,
            endIndex: m.end,
            confidenceContribution: 0.45,
          ),
        );
      }
    }

    // 2. "..." Name said
    for (final m in _postSpeechNameSaidRegex.allMatches(text)) {
      final name = m.group(1)?.trim();
      if (name != null && _isValidNameCandidate(name)) {
        matches.add(
          DialogueTagMatch(
            speakerName: name,
            tagVerb: 'said',
            startIndex: m.start,
            endIndex: m.end,
            confidenceContribution: 0.45,
          ),
        );
      }
    }

    // 3. Name said, "..."
    for (final m in _preSpeechNameSaidRegex.allMatches(text)) {
      final name = m.group(1)?.trim();
      if (name != null && _isValidNameCandidate(name)) {
        matches.add(
          DialogueTagMatch(
            speakerName: name,
            tagVerb: 'said',
            startIndex: m.start,
            endIndex: m.end,
            confidenceContribution: 0.45,
          ),
        );
      }
    }

    return matches;
  }

  bool _isValidNameCandidate(String candidate) {
    if (candidate.length < 2 || candidate.length > 35) return false;
    // Don't accept pronouns alone
    final lower = candidate.toLowerCase();
    if (lower == 'he' || lower == 'she' || lower == 'they' || lower == 'it' ||
        lower == 'someone' || lower == 'anyone' || lower == 'nobody' ||
        lower == 'everyone' || lower == 'the man' || lower == 'the woman' ||
        lower == 'the boy' || lower == 'the girl') {
      return false;
    }
    return true;
  }
}

