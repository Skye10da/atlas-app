import 'package:atlas_app/intelligence/application/graph/cooccurrence_graph.dart';
import 'package:atlas_app/intelligence/domain/entities/story_cooccurrence.dart';
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
  const GraphClusterer({TransliterationMatcher? matcher})
      : _matcher = matcher ?? const TransliterationMatcher();

  final TransliterationMatcher _matcher;

  /// Similarity floor for proposing a merge at all.
  static const double proposalSimilarity = 0.75;

  /// Pairs that co-occur at least this often are distinct entities
  /// (e.g. Master and Disciple with similar clan names).
  static const int distinctCooccurrenceFloor = 2;

  /// Auto-merge bar: very high similarity and never co-present.
  static const double autoMergeSimilarity = 0.92;

  /// Decides one same-type entity pair. Returns null when the pair is
  /// safely distinct; otherwise the merge proposal. Shared by the
  /// per-chapter scan (`findMergeCandidates`) and the whole-book
  /// consolidation sweep ([EntityConsolidationService]) so merge semantics
  /// stay identical in both.
  static MergeProposal? evaluatePair({
    required TransliterationMatcher matcher,
    required StoryEntity e1,
    required StoryEntity e2,
    required int cooccurrences,
  }) {
    // If they frequently co-occur, they are distinct entities (e.g. Master
    // and Disciple with similar clan names)
    if (cooccurrences >= distinctCooccurrenceFloor) return null;

    final similarity = matcher.similarity(e1.canonicalName, e2.canonicalName);
    if (similarity < proposalSimilarity) return null;

    // Determine which entity to keep (the one with higher mentions or higher confidence)
    final keep = (e1.mentionCount >= e2.mentionCount) ? e1 : e2;
    final absorbed = (keep.id == e1.id) ? e2 : e1;

    final evidence = <String>[
      'Name similarity: ${(similarity * 100).toStringAsFixed(1)}%',
      'Co-occurrence frequency: $cooccurrences (never in same scene)',
    ];

    // Auto-merge if similarity is very high and they never co-occur
    final shouldAutoMerge =
        similarity >= autoMergeSimilarity && cooccurrences == 0;

    return MergeProposal(
      keepEntity: keep,
      absorbedEntity: absorbed,
      similarityScore: similarity,
      cooccurrenceCount: cooccurrences,
      shouldAutoMerge: shouldAutoMerge,
      evidence: evidence,
    );
  }

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

        final cooccurrences = graph.getWeight(bookId, e1.id, e2.id);
        final proposal = evaluatePair(
          matcher: _matcher,
          e1: e1,
          e2: e2,
          cooccurrences: cooccurrences,
        );
        if (proposal != null) proposals.add(proposal);
      }
    }

    return proposals;
  }

  /// Pure/static re-entry used by the extraction pass to run this scan
  /// inside a background isolate: rebuilds the graph from the persisted
  /// + newly recorded edges and runs the same pair evaluation.
  static List<MergeProposal> findMergeCandidatesFromEdges({
    required List<StoryEntity> entities,
    required String bookId,
    List<StoryCooccurrence> persistedEdges = const [],
    TransliterationMatcher? matcher,
  }) {
    final graph = CooccurrenceGraph(persistedEdges);
    return GraphClusterer(matcher: matcher).findMergeCandidates(
      entities: entities,
      graph: graph,
      bookId: bookId,
    );
  }
}

