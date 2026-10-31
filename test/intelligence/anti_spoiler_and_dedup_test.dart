import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/domain/entities/story_relationship.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_story_memory_repository.dart';

void main() {
  late AppDatabase db;
  late DriftStoryMemoryRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = DriftStoryMemoryRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  StoryRelationship rel({
    required String id,
    required String source,
    required String target,
    required int chapterEstablished,
  }) =>
      StoryRelationship(
        id: id,
        bookId: 'book_1',
        sourceEntityId: source,
        targetEntityId: target,
        relationType: 'allies_with',
        confidenceScore: 0.8,
        chapterEstablished: chapterEstablished,
        createdAt: DateTime(2026, 1, 1),
      );

  group('Chapter-bounded relationships (anti-spoiler)', () {
    test('getRelationships without maxChapter returns everything', () async {
      await repository.saveRelationship(rel(id: 'r1', source: 'a', target: 'b', chapterEstablished: 1));
      await repository.saveRelationship(rel(id: 'r2', source: 'a', target: 'c', chapterEstablished: 40));

      final res = await repository.getRelationships('book_1', entityId: 'a');
      expect((res as Success<List<StoryRelationship>>).value, hasLength(2));
    });

    test('getRelationships with maxChapter hides later-established links', () async {
      await repository.saveRelationship(rel(id: 'r1', source: 'a', target: 'b', chapterEstablished: 1));
      await repository.saveRelationship(rel(id: 'r2', source: 'a', target: 'c', chapterEstablished: 40));

      final res = await repository.getRelationships('book_1', entityId: 'a', maxChapter: 10);
      final ids = (res as Success<List<StoryRelationship>>).value.map((r) => r.id).toList();
      expect(ids, ['r1']);
    });

    test('maxChapter boundary is inclusive', () async {
      await repository.saveRelationship(rel(id: 'r1', source: 'a', target: 'b', chapterEstablished: 10));
      await repository.saveRelationship(rel(id: 'r2', source: 'a', target: 'c', chapterEstablished: 11));

      final res = await repository.getRelationships('book_1', entityId: 'a', maxChapter: 10);
      final ids = (res as Success<List<StoryRelationship>>).value.map((r) => r.id).toList();
      expect(ids, ['r1']);
    });

    test('read-through isolation still applies with maxChapter', () async {
      await repository.saveRelationship(rel(id: 'r1', source: 'a', target: 'b', chapterEstablished: 1));

      final res = await repository.getRelationships('book_1', readThroughId: 'rt_other', maxChapter: 99);
      expect((res as Success<List<StoryRelationship>>).value, isEmpty);
    });
  });

  group('Review queue dedup guard', () {
    ReviewItem item({
      required String id,
      required ReviewType type,
      required String entityId,
      required String candidateName,
    }) =>
        ReviewItem(
          id: id,
          bookId: 'book_1',
          readThroughId: 'default',
          type: type,
          entityId: entityId,
          candidateName: candidateName,
          confidenceScore: 0.65,
          chapterIndex: 3,
          createdAt: DateTime(2026, 1, 1),
        );

    test('hasPendingReviewItem is false before save / true after', () async {
      final before = await repository.hasPendingReviewItem(
        bookId: 'book_1',
        type: ReviewType.newEntity,
        entityId: 'prov_Xiao Yan',
        candidateName: 'Xiao Yan',
      );
      expect((before as Success<bool>).value, isFalse);

      await repository.saveReviewItem(
        item(
          id: 'rev_1',
          type: ReviewType.newEntity,
          entityId: 'prov_Xiao Yan',
          candidateName: 'Xiao Yan',
        ),
      );

      final after = await repository.hasPendingReviewItem(
        bookId: 'book_1',
        type: ReviewType.newEntity,
        entityId: 'prov_Xiao Yan',
        candidateName: 'Xiao Yan',
      );
      expect((after as Success<bool>).value, isTrue);
    });

    test('guard distinguishes type, entity and candidate', () async {
      await repository.saveReviewItem(
        item(
          id: 'rev_1',
          type: ReviewType.newEntity,
          entityId: 'prov_Xiao Yan',
          candidateName: 'Xiao Yan',
        ),
      );

      // Different candidate → not a duplicate.
      final otherCandidate = await repository.hasPendingReviewItem(
        bookId: 'book_1',
        type: ReviewType.newEntity,
        entityId: 'prov_Yao Chen',
        candidateName: 'Yao Chen',
      );
      expect((otherCandidate as Success<bool>).value, isFalse);

      // Different type → not a duplicate.
      final otherType = await repository.hasPendingReviewItem(
        bookId: 'book_1',
        type: ReviewType.mergeCandidates,
        entityId: 'prov_Xiao Yan',
        candidateName: 'Xiao Yan',
      );
      expect((otherType as Success<bool>).value, isFalse);
    });

    test('resolved items no longer count as pending duplicates', () async {
      await repository.saveReviewItem(
        item(
          id: 'rev_1',
          type: ReviewType.newEntity,
          entityId: 'prov_Lin Dong',
          candidateName: 'Lin Dong',
        ),
      );
      await repository.resolveReviewItem('rev_1', ReviewStatus.resolved);

      final res = await repository.hasPendingReviewItem(
        bookId: 'book_1',
        type: ReviewType.newEntity,
        entityId: 'prov_Lin Dong',
        candidateName: 'Lin Dong',
      );
      expect((res as Success<bool>).value, isFalse);
    });

    test('read-through scope is respected', () async {
      await repository.saveReviewItem(
        item(
          id: 'rev_1',
          type: ReviewType.newEntity,
          entityId: 'prov_Lin Dong',
          candidateName: 'Lin Dong',
        ),
      );

      final otherRt = await repository.hasPendingReviewItem(
        bookId: 'book_1',
        readThroughId: 'rt_second',
        type: ReviewType.newEntity,
        entityId: 'prov_Lin Dong',
        candidateName: 'Lin Dong',
      );
      expect((otherRt as Success<bool>).value, isFalse);
    });
  });
}
