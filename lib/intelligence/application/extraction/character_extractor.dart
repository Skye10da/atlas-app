import 'package:atlas_app/intelligence/application/extraction/confidence_scorer.dart';
import 'package:atlas_app/intelligence/infrastructure/parsing/dialogue_tag_parser.dart';
import 'package:atlas_app/intelligence/infrastructure/parsing/honorific_dictionary.dart';
import 'package:atlas_app/intelligence/infrastructure/parsing/negative_stoplist.dart';

/// A candidate character mention with its corroborating evidence and signals.
class CharacterCandidate {
  CharacterCandidate({
    required this.name,
    required this.signals,
    required this.evidence,
    required this.occurrenceCount,
    required this.firstOffset,
  });

  final String name;
  final Set<ExtractionSignalType> signals;
  final List<String> evidence;
  int occurrenceCount;
  final int firstOffset;
}

/// Deterministic character extractor using dialogue tags, honorifics, and proper-noun frequency.
class CharacterExtractor {
  CharacterExtractor({
    DialogueTagParser? dialogueTagParser,
    HonorificDictionary? honorificDictionary,
    NegativeStoplist? negativeStoplist,
  })  : _dialogueTagParser = dialogueTagParser ?? const DialogueTagParser(),
        _honorificDictionary = honorificDictionary ?? const HonorificDictionary(),
        _negativeStoplist = negativeStoplist ?? const NegativeStoplist();

  final DialogueTagParser _dialogueTagParser;
  final HonorificDictionary _honorificDictionary;
  final NegativeStoplist _negativeStoplist;

  // General proper noun pattern: 1-3 capitalized tokens e.g. "Xiao Yan", "Old Ancestor"
  static final RegExp _properNounRegex = RegExp(
    r'\b([A-Z][a-zA-Z\x27\-]+(?:\s+[A-Z][a-zA-Z\x27\-]+){0,2})\b',
  );

  /// Extracts character candidates from [chapterText].
  List<CharacterCandidate> extract(String chapterText) {
    if (chapterText.trim().isEmpty) return const [];

    final candidateMap = <String, CharacterCandidate>{};

    void recordCandidate(
      String rawName,
      ExtractionSignalType signal,
      String evidenceSnippet,
      int offset,
    ) {
      final name = _cleanCandidateName(rawName);
      if (name == null || _negativeStoplist.contains(name)) return;

      final existing = candidateMap[name];
      if (existing != null) {
        existing.signals.add(signal);
        if (existing.evidence.length < 5) {
          existing.evidence.add(evidenceSnippet);
        }
        existing.occurrenceCount++;
      } else {
        candidateMap[name] = CharacterCandidate(
          name: name,
          signals: {signal},
          evidence: [evidenceSnippet],
          occurrenceCount: 1,
          firstOffset: offset,
        );
      }
    }

    // 1. Dialogue tag matches (High signal)
    final dialogueMatches = _dialogueTagParser.parse(chapterText);
    for (final m in dialogueMatches) {
      recordCandidate(
        m.speakerName,
        ExtractionSignalType.dialogueTag,
        'Spoke in dialogue: "${m.tagVerb} ${m.speakerName}"',
        m.startIndex,
      );
    }

    // 2. Honorific mentions (Medium signal)
    final honorificMatches = _honorificDictionary.extractHonorificMentions(chapterText);
    for (final m in honorificMatches) {
      recordCandidate(
        m.baseName,
        ExtractionSignalType.honorificMention,
        'Addressed with title: "${m.fullExpression}"',
        m.startIndex,
      );
    }

    // 2b. Structured panel names (Scout HUD + Talent panels) — reuses football grammar
    // Covers: `> Name : Kevin "Kev" Jones` and `[Yoon Jung-ho]` / `[Ho-young]`
    // High signal (structuredPattern 0.55) to capture panel-only youths.
    final scoutNameRegex = RegExp(
      r'^\s*>?\s*Name\s*[:：]\s*(.+)$',
      multiLine: true,
    );
    for (final m in scoutNameRegex.allMatches(chapterText)) {
      final raw = m.group(1)!.trim();
      // Strip trailing footnote after name line (e.g. "Kevin "Kev" Jones")
      // Keep as is — _cleanCandidateName will strip outer punctuation
      recordCandidate(
        raw,
        ExtractionSignalType.structuredPattern,
        'Scout panel: Name: $raw',
        m.start,
      );
    }

    final bracketNameRegex = RegExp(r'^\s*\[([^\]]+)\]\s*$', multiLine: true);
    for (final m in bracketNameRegex.allMatches(chapterText)) {
      final inner = m.group(1)!.trim();
      final lower = inner.toLowerCase();
      if (lower.startsWith('possessed talents')) continue;
      if (lower.startsWith('select the talent')) continue;
      if (lower.startsWith('it will take')) continue;
      if (inner.contains('→') || inner.contains('↑')) continue;
      if (inner.length < 2 || inner.length > 35) continue;
      // Single bracket name like Yoon Jung-ho, Ho-young, Cha Du-ri
      recordCandidate(
        inner,
        ExtractionSignalType.structuredPattern,
        'Talent panel: [$inner]',
        m.start,
      );
    }

    // 3. Proper noun scanning across text
    for (final m in _properNounRegex.allMatches(chapterText)) {
      final rawName = m.group(1);
      if (rawName != null) {
        final cleaned = _cleanCandidateName(rawName);
        if (cleaned != null && candidateMap.containsKey(cleaned)) {
          // If already known from dialogue or honorific, increment count
          candidateMap[cleaned]!.occurrenceCount++;
        }
      }
    }

    return candidateMap.values.toList();
  }

  String? _cleanCandidateName(String raw) {
    var cleaned = raw.trim();
    // Strip trailing punctuation or apostrophes
    cleaned = cleaned.replaceAll(RegExp(r'^[\W_]+|[\W_]+$'), '');
    // Strip honorific prefixes/suffixes if present
    cleaned = _honorificDictionary.stripHonorifics(cleaned);

    if (cleaned.length < 2 || cleaned.length > 35) return null;
    return cleaned;
  }
}

