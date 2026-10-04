import 'package:atlas_app/intelligence/infrastructure/parsing/negative_stoplist.dart';

class FactionCandidate {
  FactionCandidate({
    required this.name,
    required this.evidence,
    required this.occurrenceCount,
  });

  final String name;
  final List<String> evidence;
  int occurrenceCount;
}

/// Deterministic extractor for factions, sects, clans, and organizations.
class FactionExtractor {
  FactionExtractor({NegativeStoplist? negativeStoplist})
      : _negativeStoplist = negativeStoplist ?? const NegativeStoplist();

  final NegativeStoplist _negativeStoplist;

  static const List<String> _factionSuffixes = [
    'sect', 'clan', 'family', 'pavilion', 'hall', 'alliance',
    'guild', 'empire', 'kingdom', 'dynasty', 'academy', 'palace',
    'association', 'union', 'order', 'gang', 'society',
  ];

  static final String _suffixPattern = _factionSuffixes
      .map((s) => s[0].toUpperCase() + s.substring(1))
      .join('|');

  // e.g. "Lin Clan", "Dao Sect", "Great Yan Empire", "Misty Cloud Sect"
  static final RegExp _suffixedFactionRegex = RegExp(
    r'\b([A-Z][a-zA-Z\x27\-]+(?:\s+[A-Z][a-zA-Z\x27\-]+){0,2}\s+(?:' +
        _suffixPattern +
        r'))\b',
  );

  List<FactionCandidate> extract(String chapterText) {
    if (chapterText.trim().isEmpty) return const [];
    final candidates = <String, FactionCandidate>{};

    for (final m in _suffixedFactionRegex.allMatches(chapterText)) {
      final raw = m.group(1);
      if (raw != null) {
        final cleaned = _cleanFactionName(raw);
        if (cleaned != null && !_negativeStoplist.contains(cleaned)) {
          final existing = candidates[cleaned];
          if (existing != null) {
            existing.occurrenceCount++;
          } else {
            candidates[cleaned] = FactionCandidate(
              name: cleaned,
              evidence: ['Organization mention: "${m.group(0)}"'],
              occurrenceCount: 1,
            );
          }
        }
      }
    }

    return candidates.values.toList();
  }

  String? _cleanFactionName(String raw) {
    var cleaned = raw.trim().replaceAll(RegExp(r'^[\W_]+|[\W_]+$'), '');
    if (cleaned.toLowerCase().startsWith('the ')) {
      cleaned = cleaned.substring(4).trim();
    }
    if (cleaned.length < 3 || cleaned.length > 40) return null;
    return cleaned;
  }
}
