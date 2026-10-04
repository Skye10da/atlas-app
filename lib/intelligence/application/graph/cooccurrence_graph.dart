import 'package:atlas_app/intelligence/domain/entities/story_cooccurrence.dart';

/// Tracks pairwise entity co-occurrence frequency within chapters/scenes.
class CooccurrenceGraph {
  CooccurrenceGraph([List<StoryCooccurrence>? initialEdges]) {
    if (initialEdges != null) {
      for (final e in initialEdges) {
        _edges[e.id] = e;
      }
    }
  }

  final Map<String, StoryCooccurrence> _edges = {};

  List<StoryCooccurrence> get edges => _edges.values.toList();

  /// Updates co-occurrence weights for all pairwise combinations of [entityIds] appearing in [chapterIndex].
  List<StoryCooccurrence> recordCooccurrences({
    required String bookId,
    String readThroughId = 'default',
    required List<String> entityIds,
    required int chapterIndex,
  }) {
    if (entityIds.length < 2) return const [];
    final updated = <StoryCooccurrence>[];

    for (int i = 0; i < entityIds.length; i++) {
      for (int j = i + 1; j < entityIds.length; j++) {
        final id1 = entityIds[i];
        final id2 = entityIds[j];
        if (id1 == id2) continue;

        final edgeId = StoryCooccurrence.generateId(bookId, id1, id2, readThroughId: readThroughId);
        final existing = _edges[edgeId];

        final newEdge = StoryCooccurrence(
          id: edgeId,
          bookId: bookId,
          readThroughId: readThroughId,
          entityAId: id1.compareTo(id2) < 0 ? id1 : id2,
          entityBId: id1.compareTo(id2) < 0 ? id2 : id1,
          weight: (existing?.weight ?? 0) + 1,
          lastSeenChapter: chapterIndex,
        );

        _edges[edgeId] = newEdge;
        updated.add(newEdge);
      }
    }

    return updated;
  }

  /// Returns co-occurrence frequency between two entity IDs (0 if never seen together).
  int getWeight(String bookId, String id1, String id2, {String readThroughId = 'default'}) {
    final edgeId = StoryCooccurrence.generateId(bookId, id1, id2, readThroughId: readThroughId);
    return _edges[edgeId]?.weight ?? 0;
  }
}

