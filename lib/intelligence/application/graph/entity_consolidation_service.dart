import 'dart:isolate';

import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/extraction/entity_extractor.dart';
import 'package:atlas_app/intelligence/application/graph/cooccurrence_graph.dart';
import 'package:atlas_app/intelligence/application/graph/graph_clusterer.dart';
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/domain/entities/story_cooccurrence.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/infrastructure/parsing/transliteration_matcher.dart';
import 'package:atlas_app/intelligence/domain/repositories/story_memory_repository.dart';

/// Outcome of one [`EntityConsolidationService.consolidateBook`] sweep.
class ConsolidationSummary {
  const ConsolidationSummary({
    required this.ran,
    this.mergedCount = 0,
    this.queuedCount = 0,
    this.error,
  });

  /// False when the sweep was skipped (another run in flight for the same
  /// book) or failed early — [error] carries the underlying failure.
  final bool ran;
  final int mergedCount;
  final int queuedCount;
  final Object? error;
}

/// Whole-book deduplication sweep for story-memory entities.
///
/// Per-chapter extraction can spawn duplicate rows when a name variant
/// slips past the first-mention fuzzy match — common with translated
/// names ("Lin Dongsheng" extracted alongside a later "Elder Lin"
/// variant, etc.). The in-chapter clusterer never sees those pairs
/// because it only evaluates entities co-present in one chapter, and
/// nothing ever executed its proposals; duplicates therefore persisted.
///
/// This sweep runs the shared [GraphClusterer.evaluatePair] decision over
/// the book's FULL entity list against the PERSISTED co-occurrence graph:
/// pairs that met anywhere in the book are treated as distinct, while
/// high-similarity never-co-occurring pairs are merged (similarity ≥
/// [GraphClusterer.autoMergeSimilarity]) or queued for manual review below
/// that bar — capped, so a first sweep over a messy book floods nothing.
///
/// A sweep only pairs entities that never appear together anywhere in the
/// book, so it is strictly more conservative than the per-chapter bar and
/// safe to run on the details-page open path.
class EntityConsolidationService {
  EntityConsolidationService({
    required StoryMemoryRepository repository,
    TransliterationMatcher? matcher,
    this.maxQueuedReviewItems = 10,
  })  : _repository = repository,
        _matcher = matcher ?? const TransliterationMatcher();

  final StoryMemoryRepository _repository;
  final TransliterationMatcher _matcher;
  final int maxQueuedReviewItems;

  /// Pure/static pairwise scan over the book's entities against the persisted
  /// co-occurrence graph. Executed inside [Isolate.run] by [consolidateBook]
  /// (with an inline fallback for restricted runtimes) so the Levenshtein
  /// work never janks the UI thread.
  static _ConsolidationScanResult _consolidationScanSync({
    required List<StoryEntity> entities,
    required String bookId,
    required String readThroughId,
    required List<StoryCooccurrence> cooccurrenceEdges,
    TransliterationMatcher? matcher,
  }) {
    final effectiveMatcher = matcher ?? const TransliterationMatcher();
    final graph = CooccurrenceGraph(cooccurrenceEdges);

    final autoMergePairs = <({StoryEntity keep, StoryEntity absorbed})>[];
    final reviewCandidates = <_PairCandidate>[];
    for (final bucket in _bucketedByTypeStatic(entities, effectiveMatcher)) {
      for (int i = 0; i < bucket.length; i++) {
        for (int j = i + 1; j < bucket.length; j++) {
          final e1 = bucket[i].entity;
          final e2 = bucket[j].entity;
          if (!bucket[i].plausiblePair(bucket[j])) continue;

          final cooccurrences = graph.getWeight(
            bookId,
            e1.id,
            e2.id,
            readThroughId: readThroughId,
          );
          // Sweep bar: pairs that met anywhere are distinct. Stricter
          // than the per-chapter evaluator's <2 ceiling on purpose.
          if (cooccurrences > 0) continue;

          final similarity = effectiveMatcher.similarity(e1.canonicalName, e2.canonicalName);
          if (similarity < GraphClusterer.proposalSimilarity) continue;

          final keep = (e1.mentionCount >= e2.mentionCount) ? e1 : e2;
          final absorbed = (keep.id == e1.id) ? e2 : e1;

          if (similarity >= GraphClusterer.autoMergeSimilarity) {
            autoMergePairs.add((keep: keep, absorbed: absorbed));
          } else {
            reviewCandidates.add(_PairCandidate(keep: keep, absorbed: absorbed, similarity: similarity));
          }
        }
      }
    }
    return _ConsolidationScanResult(autoMergePairs: autoMergePairs, reviewCandidates: reviewCandidates);
  }

  static List<List<_EntityEntry>> _bucketedByTypeStatic(
    List<StoryEntity> entities,
    TransliterationMatcher m,
  ) {
    final buckets = <String, List<_EntityEntry>>{};
    for (final e in entities) {
      final norm = m.normalizeName(e.canonicalName);
      (buckets[e.type.id] ??= []).add(_EntityEntry(
        entity: e,
        norm: norm,
        length: norm.length,
        soundex: m.soundexCode(e.canonicalName),
      ));
    }
    return buckets.values.toList();
  }

  /// Book/read-through keys with a sweep in flight, preventing overlapping
  /// runs when the details page is opened while a backfill sweeps on.
  final Set<String> _activeRuns = {};

  /// Consolidates duplicate entity rows for one book / read-through.
  ///
  /// Best-effort by design: any repository failure is reported through the
  /// returned summary's [ConsolidationSummary.error] instead of throwing,
  /// so callers can fire-and-forget the sweep like the ingestion pipeline.
  Future<ConsolidationSummary> consolidateBook({
    required String bookId,
    String readThroughId = 'default',
  }) async {
    final runKey = '$bookId|$readThroughId';
    if (!_activeRuns.add(runKey)) {
      return const ConsolidationSummary(ran: false);
    }
    try {
      final entitiesRes = await _repository.getEntities(bookId, readThroughId: readThroughId);
      if (entitiesRes is! Success<List<StoryEntity>>) {
        return ConsolidationSummary(
          ran: false,
          error: (entitiesRes as Failure).error,
        );
      }
      final entities = entitiesRes.value;
      if (entities.length < 2) return const ConsolidationSummary(ran: true);

      final coocRes = await _repository.getCooccurrences(bookId, readThroughId: readThroughId);
      final coocEdges =
          coocRes is Success<List<StoryCooccurrence>> ? coocRes.value : const <StoryCooccurrence>[];

      final pendingRes = await _repository.pendingReviewItemKeys(
        bookId: bookId,
        readThroughId: readThroughId,
      );
      final pendingKeys = pendingRes is Success<Set<String>>
          ? {...pendingRes.value}
          : <String>{};

      // Phase 1 — find candidate pairs. Entities are bucketed per type and
      // prefiltered (same Soundex, plausible Levenshtein length band, or
      // subset match) so full similarity runs only on plausible pairs. The
      // scan is O(type-bucket²) with Levenshtein inside, so it runs in a
      // background isolate when the runtime allows, keeping the details-page
      // open path light.
      final unionFind = _UnionFind();
      for (final e in entities) {
        unionFind.make(e.id);
      }

      _ConsolidationScanResult scan;
      try {
        scan = await Isolate.run(
          () => _consolidationScanSync(
            entities: entities,
            bookId: bookId,
            readThroughId: readThroughId,
            cooccurrenceEdges: coocEdges,
            matcher: _matcher,
          ),
        );
      } catch (_) {
        // Restricted runtimes (flutter_test VM, sandboxed embedders): run
        // the same scan inline.
        scan = _consolidationScanSync(
          entities: entities,
          bookId: bookId,
          readThroughId: readThroughId,
          cooccurrenceEdges: coocEdges,
          matcher: _matcher,
        );
      }

      final reviewCandidates = scan.reviewCandidates;
      for (final merge in scan.autoMergePairs) {
        final keepRoot = _autoMergeRoot(merge.keep, merge.absorbed);
        if (keepRoot == null) continue; // both user-confirmed: hands off
        unionFind.union(keepRoot, (keepRoot == merge.keep.id) ? merge.absorbed.id : merge.keep.id);
      }

      // Phase 2 — execute auto-merges. Each cluster merges its members into
      // a single root (user-confirmed first, then mentioncount, then
      // confidence), so absorb chains resolve without dangling rows.
      int mergedCount = 0;
      final absorbedIds = <String>{};
      for (final cluster in unionFind.clustersWhere((members) => members.length > 1)) {
        final root = _pickClusterRoot(cluster, entityById: {for (final e in entities) e.id: e});
        for (final member in cluster) {
          if (member == root) continue;
          if (absorbedIds.contains(member)) continue;
          final mergeRes = await _repository.mergeEntities(
            bookId,
            readThroughId: readThroughId,
            keepEntityId: root,
            absorbedEntityId: member,
          );
          if (mergeRes is Success<StoryEntity>) {
            absorbedIds.add(member);
            mergedCount++;
          }
        }
      }

      // Phase 3 — queue review items for near-misses below the auto-merge
      // bar. Merge chains void the candidates on either absorbed side; the
      // cap keeps a first sweep over a messy book from flooding the queue.
      final queuedItems = <ReviewItem>[];
      int queuedCount = 0;
      for (final candidate in reviewCandidates) {
        if (queuedItems.length >= maxQueuedReviewItems) break;
        if (absorbedIds.contains(candidate.keep.id) ||
            absorbedIds.contains(candidate.absorbed.id)) {
          continue;
        }
        final key =
            '${ReviewType.mergeCandidates.id}|${candidate.absorbed.id}|${candidate.absorbed.canonicalName}';
        if (pendingKeys.contains(key)) continue;
        pendingKeys.add(key);
        queuedItems.add(ReviewItem(
          id: EntityExtractor.generateReviewId(bookId, 'consolidate'),
          bookId: bookId,
          readThroughId: readThroughId,
          type: ReviewType.mergeCandidates,
          entityId: candidate.absorbed.id,
          targetEntityId: candidate.keep.id,
          candidateName: candidate.absorbed.canonicalName,
          targetName: candidate.keep.canonicalName,
          confidenceScore: 0.70,
          similarityScore: candidate.similarity,
          evidence: [
            'Name similarity: ${(candidate.similarity * 100).toStringAsFixed(1)}%',
            'Never appear together in the book: consolidation sweep',
          ],
          chapterIndex: candidate.absorbed.lastSeenChapter,
          createdAt: DateTime.now(),
        ));
        queuedCount++;
      }
      if (queuedItems.isNotEmpty) {
        await _repository.saveReviewItems(queuedItems);
      }

      return ConsolidationSummary(
        ran: true,
        mergedCount: mergedCount,
        queuedCount: queuedCount,
      );
    } catch (e) {
      return ConsolidationSummary(ran: false, error: e);
    } finally {
      _activeRuns.remove(runKey);
    }
  }

  /// Chooses the auto-merge direction for a pair. Returns null only when
  /// both sides are user-confirmed — two human-approved entities are never
  /// merged programmatically. When exactly one side is user-confirmed the
  /// confirmed row becomes the merge root (a user-approved row is never
  /// silently deleted), and otherwise the more-mentioned entity wins.
  String? _autoMergeRoot(StoryEntity e1, StoryEntity e2) {
    if (e1.userConfirmed && e2.userConfirmed) return null;
    if (e2.userConfirmed && !e1.userConfirmed) return e2.id;
    if (e1.userConfirmed && !e2.userConfirmed) return e1.id;
    return (e1.mentionCount >= e2.mentionCount) ? e1.id : e2.id;
  }

  String _pickClusterRoot(
    List<String> memberIds, {
    required Map<String, StoryEntity> entityById,
  }) {
    StoryEntity best = entityById[memberIds.first]!;
    for (final id in memberIds) {
      final e = entityById[id]!;
      if ((e.userConfirmed && !best.userConfirmed) ||
          (e.userConfirmed == best.userConfirmed &&
              (e.mentionCount > best.mentionCount ||
                  (e.mentionCount == best.mentionCount &&
                      e.confidenceScore > best.confidenceScore)))) {
        best = e;
      }
    }
    return best.id;
  }
}

/// Result DTO of the static pairwise scan — sendable across [Isolate.run].
class _ConsolidationScanResult {
  const _ConsolidationScanResult({
    required this.autoMergePairs,
    required this.reviewCandidates,
  });

  final List<({StoryEntity keep, StoryEntity absorbed})> autoMergePairs;
  final List<_PairCandidate> reviewCandidates;
}

class _EntityEntry {
  const _EntityEntry({
    required this.entity,
    required this.norm,
    required this.length,
    required this.soundex,
  });

  final StoryEntity entity;
  final String norm;
  final int length;
  final String soundex;

  /// Same prefilter as the extraction pass's [findFuzzyAliasMatch]: only
  /// same-Soundex, plausible-length-band, or subset-matching names run the
  /// full similarity check.
  bool plausiblePair(_EntityEntry other) {
    final sameSoundex = soundex.isNotEmpty && soundex == other.soundex;
    final lenDelta = (length - other.length).abs().toDouble();
    final plausibleBand =
        lenDelta <= 0.25 * ((length > other.length) ? length : other.length) + 1;
    final subsetPlausible = length > 2 &&
        other.length > 2 &&
        (norm.contains(other.norm) || other.norm.contains(norm));
    return sameSoundex || plausibleBand || subsetPlausible;
  }
}

class _PairCandidate {
  const _PairCandidate({
    required this.keep,
    required this.absorbed,
    required this.similarity,
  });

  final StoryEntity keep;
  final StoryEntity absorbed;
  final double similarity;
}

/// Minimal union-find over entity ids for clustering merge chains.
class _UnionFind {
  final Map<String, String> _parent = {};

  void make(String id) => _parent.putIfAbsent(id, () => id);

  String find(String id) {
    var root = id;
    while (_parent[root] != root) {
      root = _parent[root]!;
    }
    // Path compression
    var current = id;
    while (_parent[current] != root) {
      final next = _parent[current]!;
      _parent[current] = root;
      current = next;
    }
    return root;
  }

  void union(String keepId, String absorbedId) {
    _parent[find(absorbedId)] = find(keepId);
  }

  List<List<String>> clustersWhere(bool Function(List<String> members) test) {
    final groups = <String, List<String>>{};
    for (final id in _parent.keys) {
      (groups[find(id)] ??= []).add(id);
    }
    return [for (final g in groups.values) if (test(g)) g];
  }
}
