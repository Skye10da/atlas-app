import 'package:atlas_app/intelligence/infrastructure/parsing/negative_stoplist.dart';

class ItemCandidate {
  ItemCandidate({
    required this.name,
    required this.evidence,
    required this.occurrenceCount,
  });

  final String name;
  final List<String> evidence;
  int occurrenceCount;
}

/// Deterministic extractor for significant named weapons, artifacts, pills, and treasures.
///
/// Restricts extraction to explicit structural lexical patterns to prevent
/// generic common nouns from being misidentified.
class ItemExtractor {
  ItemExtractor({NegativeStoplist? negativeStoplist})
      : _negativeStoplist = negativeStoplist ?? const NegativeStoplist();

  final NegativeStoplist _negativeStoplist;

  static const List<String> _itemTypes = [
    'sword', 'blade', 'spear', 'halberd', 'saber', 'bow', 'staff', 'dagger',
    'armor', 'robes', 'ring', 'talisman', 'pill', 'cauldron', 'scroll',
    'mirror', 'bell', 'pagoda', 'banner', 'shield', 'artifact', 'treasure',
    'bead', 'pearl', 'flame', 'lotus', 'needle', 'seal',
  ];

  static final String _itemPattern = _itemTypes
      .map((s) => s[0].toUpperCase() + s.substring(1))
      .join('|');

  // e.g. "Stone Talisman", "Heavenly Flame", "Black Dragon Spear", "Nine Yin Pill"
  static final RegExp _structuredItemRegex = RegExp(
    r'\b([A-Z][a-zA-Z\x27\-]+(?:\s+[A-Z][a-zA-Z\x27\-]+){0,2}\s+(?:' +
        _itemPattern +
        r'))\b',
  );

  List<ItemCandidate> extract(String chapterText) {
    if (chapterText.trim().isEmpty) return const [];
    final candidates = <String, ItemCandidate>{};

    for (final m in _structuredItemRegex.allMatches(chapterText)) {
      final raw = m.group(1);
      if (raw != null) {
        final cleaned = _cleanItemName(raw);
        if (cleaned != null && !_negativeStoplist.contains(cleaned)) {
          final existing = candidates[cleaned];
          if (existing != null) {
            existing.occurrenceCount++;
          } else {
            candidates[cleaned] = ItemCandidate(
              name: cleaned,
              evidence: ['Item mention: "${m.group(0)}"'],
              occurrenceCount: 1,
            );
          }
        }
      }
    }

    // Binary filter: Only include items that are capitalized and structured
    return candidates.values.toList();
  }

  String? _cleanItemName(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'^[\W_]+|[\W_]+$'), '');
    if (cleaned.length < 3 || cleaned.length > 40) return null;
    return cleaned;
  }
}

