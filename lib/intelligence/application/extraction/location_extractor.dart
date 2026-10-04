import 'package:atlas_app/intelligence/infrastructure/parsing/negative_stoplist.dart';

class LocationCandidate {
  LocationCandidate({
    required this.name,
    required this.evidence,
    required this.occurrenceCount,
  });

  final String name;
  final List<String> evidence;
  int occurrenceCount;
}

/// Deterministic location extractor using arrival/departure patterns and geographical suffixes.
class LocationExtractor {
  LocationExtractor({NegativeStoplist? negativeStoplist})
      : _negativeStoplist = negativeStoplist ?? const NegativeStoplist();

  final NegativeStoplist _negativeStoplist;

  static const List<String> _locationSuffixes = [
    'mountain', 'mountains', 'peak', 'valley', 'forest', 'river', 'lake',
    'city', 'town', 'village', 'realm', 'domain', 'island', 'islands',
    'sea', 'ocean', 'cave', 'pass', 'palace', 'pavilion', 'hall',
    'canyon', 'desert', 'plains', 'plateau', 'ruins', 'temple',
  ];

  static final String _suffixPattern = _locationSuffixes
      .map((s) => s[0].toUpperCase() + s.substring(1))
      .join('|');

  // e.g. "Cloud Mist Mountain", "Qingyang City", "Heavenly Demon Valley"
  static final RegExp _suffixedLocationRegex = RegExp(
    r'\b([A-Z][a-zA-Z\x27\-]+(?:\s+[A-Z][a-zA-Z\x27\-]+){0,2}\s+(?:' +
        _suffixPattern +
        r'))\b',
  );

  // Arrival / travel patterns: "arrived at X", "entered X", "departed for X"
  static final RegExp _arrivalRegex = RegExp(
    r'\b(?:arrived at|entered|reached|traveled to|departed for|returned to|heading towards)\s+([A-Z][a-zA-Z\x27\-]+(?:\s+[A-Z][a-zA-Z\x27\-]+){0,2})\b',
    caseSensitive: false,
  );

  List<LocationCandidate> extract(String chapterText) {
    if (chapterText.trim().isEmpty) return const [];
    final candidates = <String, LocationCandidate>{};

    void record(String name, String evidence) {
      final cleaned = _cleanLocationName(name);
      if (cleaned == null || _negativeStoplist.contains(cleaned)) return;

      final existing = candidates[cleaned];
      if (existing != null) {
        if (existing.evidence.length < 5) existing.evidence.add(evidence);
        existing.occurrenceCount++;
      } else {
        candidates[cleaned] = LocationCandidate(
          name: cleaned,
          evidence: [evidence],
          occurrenceCount: 1,
        );
      }
    }

    // 1. Suffixed locations
    for (final m in _suffixedLocationRegex.allMatches(chapterText)) {
      final matchText = m.group(1);
      if (matchText != null) {
        record(matchText, 'Geographical landmark: "$matchText"');
      }
    }

    // 2. Arrival patterns
    for (final m in _arrivalRegex.allMatches(chapterText)) {
      final matchText = m.group(1);
      if (matchText != null) {
        record(matchText, 'Travel movement: "${m.group(0)}"');
      }
    }

    return candidates.values.toList();
  }

  String? _cleanLocationName(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'^[\W_]+|[\W_]+$'), '');
    if (cleaned.length < 3 || cleaned.length > 40) return null;
    return cleaned;
  }
}

