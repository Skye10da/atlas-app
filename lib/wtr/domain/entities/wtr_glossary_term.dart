/// A single WTR-Lab glossary entry: the Chinese source term and the English
/// aliases the site substitutes for it while rendering a chapter.
///
/// The public per-novel glossary (`/api/v2/reader/terms/{rawId}.json`) stores
/// terms as `[[enAliases...], zh, type, ?, count]`; the AI reader response
/// embeds a per-chapter subset as `[en, zh]` pairs. Both shapes parse here.
class WtrGlossaryTerm {
  const WtrGlossaryTerm({required this.zh, required this.enAliases});

  /// Chinese source term (e.g. `林青青`).
  final String zh;

  /// English aliases, most common first (e.g. `['Lin Qingqing']`).
  final List<String> enAliases;

  /// The primary English substitution for [zh].
  String get en => enAliases.isNotEmpty ? enAliases.first : zh;

  /// Parses a public-glossary term: `[[aliases...], zh, type, ?, count]`.
  static WtrGlossaryTerm? fromPublicTerm(Object? raw) {
    if (raw is! List || raw.length < 2) return null;
    final zh = raw[1];
    if (zh is! String || zh.isEmpty) return null;
    final aliases = _aliasesOf(raw[0]);
    if (aliases.isEmpty) return null;
    return WtrGlossaryTerm(zh: zh, enAliases: aliases);
  }

  /// Parses an AI reader `glossary_data` term: `[en, zh]`.
  static WtrGlossaryTerm? fromAiTerm(Object? raw) {
    if (raw is! List || raw.length < 2) return null;
    final en = raw[0];
    final zh = raw[1];
    if (en is! String || en.isEmpty || zh is! String || zh.isEmpty) {
      return null;
    }
    return WtrGlossaryTerm(zh: zh, enAliases: [en]);
  }

  static List<String> _aliasesOf(Object? value) {
    if (value is String) return [value.trim()];
    if (value is List) {
      final aliases = <String>[];
      for (final entry in value) {
        if (entry is String) {
          final alias = entry.trim();
          if (alias.isNotEmpty) aliases.add(alias);
        } else if (entry is Map) {
          aliases.addAll(_aliasesOf(entry['value']));
        }
      }
      return aliases;
    }
    return const [];
  }
}
