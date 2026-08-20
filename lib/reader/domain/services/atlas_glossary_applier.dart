import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';

/// Applies a book's user glossary to chapter text at render time.
///
/// The stored chapter content is never modified — the transformation runs when
/// content is handed to the reader, so adding or changing a term instantly
/// reshapes what the user sees without touching the download cache.
class AtlasGlossaryApplier {
  const AtlasGlossaryApplier._();

  /// Replaces every occurrence of each entry's [AtlasGlossaryEntry.term] with
  /// its active replacement, longest terms first so compound phrases win over
  /// their single-character parts. Matching happens in one left-to-right pass
  /// over the *original* text, so a replacement can never be re-replaced by a
  /// later term. Terms without a usable replacement are skipped.
  static String apply(String content, List<AtlasGlossaryEntry> entries) {
    if (content.isEmpty) return content;

    final rules = <(String, String)>[
      for (final entry in entries)
        if (entry.term.isNotEmpty)
          for (final replacement in [entry.activeReplacement])
            if (replacement != null && replacement != entry.term)
              (entry.term, replacement),
    ];
    if (rules.isEmpty) return content;

    rules.sort((a, b) => b.$1.length.compareTo(a.$1.length));

    final buffer = StringBuffer();
    var i = 0;
    while (i < content.length) {
      (String, String)? matched;
      for (final rule in rules) {
        if (content.startsWith(rule.$1, i)) {
          matched = rule;
          break;
        }
      }
      if (matched != null) {
        buffer.write(matched.$2);
        i += matched.$1.length;
      } else {
        buffer.write(content[i]);
        i++;
      }
    }
    return buffer.toString();
  }
}