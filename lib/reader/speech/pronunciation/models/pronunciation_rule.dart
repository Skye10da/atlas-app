// ignore_for_file: sort_constructors_first
/// Domain model for pronunciation / pronoun normalization.
/// Immutable, JSON-serializable for SharedPreferences persistence.
class PronunciationRule {
  const PronunciationRule({
    required this.id,
    required this.pattern,
    required this.replacement,
    this.isRegex = false,
    this.isEnabled = true,
  });

  final String id;
  final String pattern;
  final String replacement;
  final bool isRegex;
  final bool isEnabled;

  PronunciationRule copyWith({
    String? pattern,
    String? replacement,
    bool? isRegex,
    bool? isEnabled,
  }) {
    return PronunciationRule(
      id: id,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      isRegex: isRegex ?? this.isRegex,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pattern': pattern,
        'replacement': replacement,
        'isRegex': isRegex,
        'isEnabled': isEnabled,
      };

  factory PronunciationRule.fromJson(Map<String, dynamic> json) {
    return PronunciationRule(
      id: json['id'] as String,
      pattern: json['pattern'] as String,
      replacement: json['replacement'] as String,
      isRegex: json['isRegex'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }
}

/// Default catalog — common pronoun/punctuation expansions.
/// All `isEnabled=true` by default, user can toggle/remove.
abstract final class PronounCatalog {
  static const List<PronunciationRule> defaults = [
    PronunciationRule(id: 'unicodeEllipsisDouble', pattern: '……', replacement: ', ', isRegex: false),
    PronunciationRule(id: 'unicodeEllipsis', pattern: '…', replacement: ', ', isRegex: false),
    PronunciationRule(id: 'multiDots', pattern: r'\.{3,}', replacement: ', ', isRegex: true),
    PronunciationRule(id: 'ellipsis', pattern: '...', replacement: ', ', isRegex: false),
    PronunciationRule(id: 'ellipsis2', pattern: '..', replacement: ', ', isRegex: false),
    PronunciationRule(id: 'emDash', pattern: '--', replacement: ' — ', isRegex: false),
    PronunciationRule(id: 'emDash3', pattern: '---', replacement: ' — ', isRegex: false),
    PronunciationRule(id: 'quoteDouble', pattern: '"""', replacement: '"', isRegex: false),
    PronunciationRule(id: 'quoteSingle', pattern: "'''", replacement: "'", isRegex: false),
    PronunciationRule(id: 'smartQuoteDouble', pattern: '""', replacement: '"', isRegex: false),
    PronunciationRule(id: 'smartQuoteSingle', pattern: "''", replacement: "'", isRegex: false),
    PronunciationRule(id: 'copyright', pattern: '(c)', replacement: '©', isRegex: false),
    PronunciationRule(id: 'registered', pattern: '(r)', replacement: '®', isRegex: false),
    PronunciationRule(id: 'trademark', pattern: '(tm)', replacement: '™', isRegex: false),
  ];

  static List<PronunciationRule> cloneDefaults() =>
      defaults.map((r) => PronunciationRule(id: r.id, pattern: r.pattern, replacement: r.replacement, isRegex: r.isRegex, isEnabled: r.isEnabled)).toList();
}
