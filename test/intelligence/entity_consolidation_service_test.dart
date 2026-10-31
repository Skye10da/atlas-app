import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/graph/entity_consolidation_service.dart';
import 'package:atlas_app/intelligence/domain/entities/confidence.dart';
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/domain/entities/story_cooccurrence.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_story_memory_repository.dart';

/// Regression guard for the story-memory consolidation sweep: duplicates
/// spawned by per-chapter extraction (missed name variants) must merge
/// into one row instead of rendering multiply on the details screen.

StoryEntity _entity(
  String bookId,
  String name, {
  String? id,
  int mentionCount = 1,
  bool userConfirmed = false,
}) {
  return StoryEntity(
    id: id ?? 'ent_${bookId}_$name',
    bookId: bookId,
    type: StoryEntityType.character,
    canonicalName: name,
    confidenceScore: 0.80,
    tier: ConfidenceTier.high,
    userConfirmed: userConfirmed,
    firstSeenChapter: 1,
    lastSeenChapter: 12,
    mentionCount: mentionCount,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

Future<void> _persist(
  DriftStoryMemoryRepository repo,
  List<StoryEntity> entities, {
  List<StoryCooccurrence> edges = const [],
}) async {
  final saveRes = await repo.saveEntities(entities);
  expect(saveRes, isA<Success>());
  if (edges.isNotEmpty) {
    final edgesRes =
        await repo.updateCooccurrences(edges.first.bookId, edges);
    expect(edgesRes, isA<Success>());
  }
}

void main() {
  late AppDatabase db;
  late DriftStoryMemoryRepository repository;
  const bookId = 'book_test';

  setUp(() {
    db = AppDatabase.memory();
    repository = DriftStoryMemoryRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  EntityConsolidationService buildService({int maxQueuedReviewItems = 10}) =>
      EntityConsolidationService(
        repository: repository,
        maxQueuedReviewItems: maxQueuedReviewItems,
      );

  group('EntityConsolidationService.consolidateBook', () {
    test('merges duplicate rows that never co-occur into a single entity',
        () async {
      await _persist(repository, [
        _entity(bookId, 'Qing-Lin', mentionCount: 30),
        _entity(bookId, 'Qing Lin', mentionCount: 5),
      ]);

      final summary =
          await buildService().consolidateBook(bookId: bookId);

      expect(summary.ran, isTrue);
      expect(summary.mergedCount, 1);
      expect(summary.queuedCount, 0);

      final entitiesRes = await repository.getEntities(bookId);
      final entities = (entitiesRes as Success).value as List<StoryEntity>;
      expect(entities, hasLength(1));
      // The richer row survives; the absorbed name persists as an alias so
      // later extraction passes recognize both spellings as one entity.
      expect(entities.single.canonicalName, 'Qing-Lin');
      expect(entities.single.mentionCount, 35);
      expect(entities.single.aliases, contains('Qing Lin'));
    });

    test('keeps entities that co-occur anywhere in the book', () async {
      final a = _entity(bookId, 'Lin Dong', mentionCount: 20);
      final b = _entity(bookId, 'Lin Dongsheng', mentionCount: 4);
      await _persist(repository, [
        a,
        b,
      ], edges: [
        StoryCooccurrence(
          id: StoryCooccurrence.generateId(bookId, a.id, b.id),
          bookId: bookId,
          entityAId: a.id,
          entityBId: b.id,
          weight: 2,
          lastSeenChapter: 7,
        ),
      ]);

      final summary =
          await buildService().consolidateBook(bookId: bookId);

      expect(summary.mergedCount, 0);
      expect(summary.queuedCount, 0);
      final entitiesRes = await repository.getEntities(bookId);
      expect((entitiesRes as Success).value, hasLength(2));
    });

    test('never merges two user-confirmed entities, even exact duplicates',
        () async {
      await _persist(repository, [
        _entity(bookId, 'Xiao Yan', id: 'ent_dup_1', mentionCount: 30, userConfirmed: true),
        _entity(bookId, 'Xiao Yan', id: 'ent_dup_2', mentionCount: 5, userConfirmed: true),
      ]);

      final summary =
          await buildService().consolidateBook(bookId: bookId);

      expect(summary.mergedCount, 0);
      final entitiesRes = await repository.getEntities(bookId);
      expect((entitiesRes as Success).value, hasLength(2));
    });

    test('queues capped review items for below-bar near-miss duplicates',
        () async {
      // Each pair is subset-similar (~0.90) but below the 0.92 auto-merge
      // bar, and none of them ever co-occur.
      final a = _entity(bookId, 'Lin Dong', mentionCount: 20);
      final b = _entity(bookId, 'Lin Dongsheng', mentionCount: 4);
      final c = _entity(bookId, 'Xiao Yan', mentionCount: 20);
      final d = _entity(bookId, 'Xiao Yanshi', mentionCount: 4);
      await _persist(repository, [a, b, c, d]);

      final summary = await buildService(maxQueuedReviewItems: 1)
          .consolidateBook(bookId: bookId);

      expect(summary.ran, isTrue);
      expect(summary.mergedCount, 0);
      // The sweep floods nothing: 2 candidate pairs, 1 queued (cap).
      expect(summary.queuedCount, 1);

      final queueRes = await repository.getReviewQueue(bookId);
      final items = (queueRes as Success).value as List<ReviewItem>;
      expect(items, hasLength(1));
      expect(items.single.type, ReviewType.mergeCandidates);
      // Pointed at real rows so the review-queue merge acts on entities.
      expect(items.single.targetEntityId, 'ent_${bookId}_Lin Dong');
      expect(items.single.entityId, 'ent_${bookId}_Lin Dongsheng');
    });

    test('does not duplicate review items on a second sweep', () async {
      final a = _entity(bookId, 'Lin Dong', mentionCount: 20);
      final b = _entity(bookId, 'Lin Dongsheng', mentionCount: 4);
      await _persist(repository, [a, b]);

      final service = buildService();
      await service.consolidateBook(bookId: bookId);
      final second = await service.consolidateBook(bookId: bookId);

      expect(second.queuedCount, 0);
      final queueRes = await repository.getReviewQueue(bookId);
      expect((queueRes as Success).value, hasLength(1));
    });

    test('auto-merges are idempotent — second sweep is a no-op', () async {
      await _persist(repository, [
        _entity(bookId, 'Qing-Lin', mentionCount: 30),
        _entity(bookId, 'Qing Lin', mentionCount: 5),
      ]);

      final service = buildService();
      final first = await service.consolidateBook(bookId: bookId);
      expect(first.mergedCount, 1);

      final second = await service.consolidateBook(bookId: bookId);
      expect(second.mergedCount, 0);
    });

    test('handles a book with no entities', () async {
      final summary =
          await buildService().consolidateBook(bookId: 'book_empty');
      expect(summary.ran, isTrue);
      expect(summary.mergedCount, 0);
      expect(summary.queuedCount, 0);
    });
  });
}
