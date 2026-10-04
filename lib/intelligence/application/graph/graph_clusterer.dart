import 'package:atlas_app/intelligence/application/graph/cooccurrence_graph.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/infrastructure/parsing/transliteration_matcher.dart';

class MergeProposal {
  const MergeProposal({
    required this.keepEntity,
    required this.absorbedEntity,
    required this.similarityScore,
    required this.cooccurrenceCount,
    required this.shouldAutoMerge,
    required this.evidence,
  });

  final StoryEntity keepEntity;
  final StoryEntity absorbedEntity;
  final double similarityScore;
  final int cooccurrenceCount;
  final bool shouldAutoMerge;
  final List<String> evidence;
}

/// Evaluates entity similarity and co-occurrence graphs to discover alias clusters.
class GraphClusterer {
  GraphClusterer({TransliterationMatcher? matcher})
      : _matcher = matcher ?? const TransliterationMatcher();

  final TransliterationMatcher _matcher;

  /// Analyzes known entities and co-occurrence weights to detect merge candidates.
  List<MergeProposal> findMergeCandidates({
    required List<StoryEntity> entities,
    required CooccurrenceGraph graph,
    required String bookId,
  }) {
    if (entities.length < 2) return const [];
    final proposals = <MergeProposal>[];

    for (int i = 0; i < entities.length; i++) {
      for (int j = i + 1; j < entities.length; j++) {
        final e1 = entities[i];
        final e2 = entities[j];

        // Only evaluate entities of the same type
        if (e1.type != e2.type) continue;

        final similarity = _matcher.similarity(e1.canonicalName, e2.canonicalName);
        if (similarity < 0.75) continue;

        final cooccurrences = graph.getWeight(bookId, e1.id, e2.id);

        // If they frequently co-occur, they are distinct entities (e.g. Master and Disciple with similar clan names)
        if (cooccurrences >= 2) continue;

        // Determine which entity to keep (the one with higher mentions or higher confidence)
        final keep = (e1.mentionCount >= e2.mentionCount) ? e1 : e2;
        final absorbed = (keep.id == e1.id) ? e2 : e1;

        final evidence = <String>[
          'Name similarity: ${(similarity * 100).toStringAsFixed(1)}%',
          'Co-occurrence frequency: $cooccurrences (never in same scene)',
        ];

        // Auto-merge if similarity is very high and they never co-occur
        final shouldAutoMerge = similarity >= 0.92 && cooccurrences == 0;

        proposals.add(
          MergeProposal(
            keepEntity: keep,
            absorbedEntity: absorbed,
            similarityScore: similarity,
            cooccurrenceCount: cooccurrences,
            shouldAutoMerge: shouldAutoMerge,
            evidence: evidence,
          ),
        );
      }
    }

    return proposals;
  }
}

