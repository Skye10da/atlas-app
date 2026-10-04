import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/domain/entities/confidence.dart';
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/entities/story_event.dart';
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

  group('DriftStoryMemoryRepository - Entities', () {
    final character = StoryEntity(
      id: 'char_1',
      bookId: 'book_123',
      type: StoryEntityType.character,
      canonicalName: 'Lin Dong',
      aliases: const ['Martial Ancestor', 'Dong-ge'],
      confidenceScore: 0.85,
      tier: ConfidenceTier.high,
      userConfirmed: false,
      attributes: const {'cultivation': 'Nirvana Stage'},
      firstSeenChapter: 1,
      lastSeenChapter: 50,
      mentionCount: 42,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('saves and retrieves an entity', () async {
      final saveRes = await repository.saveEntity(character);
      expect(saveRes, isA<Success<void>>());

      final fetchRes = await repository.getEntityById('char_1');
      expect(fetchRes, isA<Success<StoryEntity?>>());
      final fetched = (fetchRes as Success<StoryEntity?>).value;
      expect(fetched, isNotNull);
      expect(fetched!.canonicalName, 'Lin Dong');
      expect(fetched.aliases, containsAll(['Martial Ancestor', 'Dong-ge']));
      expect(fetched.tier, ConfidenceTier.high);
      expect(fetched.attributes['cultivation'], 'Nirvana Stage');
    });

    test('finds entity by exact canonical name and alias', () async {
      await repository.saveEntity(character);

      // By canonical name (case-insensitive)
      final byName = await repository.findEntityByNameOrAlias('book_123', 'lin dong');
      expect(byName, isA<Success<StoryEntity?>>());
      expect((byName as Success<StoryEntity?>).value?.id, 'char_1');

      // By alias
      final byAlias = await repository.findEntityByNameOrAlias('book_123', 'Dong-ge');
      expect(byAlias, isA<Success<StoryEntity?>>());
      expect((byAlias as Success<StoryEntity?>).value?.id, 'char_1');

      // Non-existent
      final missing = await repository.findEntityByNameOrAlias('book_123', 'Xiao Yan');
      expect(missing, isA<Success<StoryEntity?>>());
      expect((missing as Success<StoryEntity?>).value, isNull);
    });

    test('merges two entities correctly', () async {
      final absorbed = StoryEntity(
        id: 'char_2',
        bookId: 'book_123',
        type: StoryEntityType.character,
        canonicalName: 'Lin-dong',
        aliases: const ['Young Master Lin'],
        confidenceScore: 0.60,
        tier: ConfidenceTier.medium,
        userConfirmed: false,
        attributes: const {'weapon': 'Heavenly Scale Halberd'},
        firstSeenChapter: 2,
        lastSeenChapter: 60,
        mentionCount: 15,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.saveEntity(character);
      await repository.saveEntity(absorbed);

      final mergeRes = await repository.mergeEntities(
        'book_123',
        keepEntityId: 'char_1',
        absorbedEntityId: 'char_2',
      );

      expect(mergeRes, isA<Success<StoryEntity>>());
      final merged = (mergeRes as Success<StoryEntity>).value;
      expect(merged.canonicalName, 'Lin Dong');
      expect(merged.aliases, containsAll(['Martial Ancestor', 'Dong-ge', 'Lin-dong', 'Young Master Lin']));
      expect(merged.mentionCount, 42 + 15);
      expect(merged.firstSeenChapter, 1);
      expect(merged.lastSeenChapter, 60);
      expect(merged.attributes['cultivation'], 'Nirvana Stage');
      expect(merged.attributes['weapon'], 'Heavenly Scale Halberd');

      // Absorbed entity is deleted
      final absorbedFetch = await repository.getEntityById('char_2');
      expect((absorbedFetch as Success<StoryEntity?>).value, isNull);
    });
  });

  group('DriftStoryMemoryRepository - Relationships & Events', () {
    test('saves and retrieves relationships', () async {
      final rel = StoryRelationship(
        id: 'rel_1',
        bookId: 'book_123',
        sourceEntityId: 'char_1',
        targetEntityId: 'char_3',
        relationType: 'brother',
        confidenceScore: 0.85,
        chapterEstablished: 5,
        createdAt: DateTime.now(),
      );

      await repository.saveRelationship(rel);
      final res = await repository.getRelationships('book_123', entityId: 'char_1');
      expect(res, isA<Success<List<StoryRelationship>>>());
      final list = (res as Success<List<StoryRelationship>>).value;
      expect(list.length, 1);
      expect(list.first.relationType, 'brother');
    });

    test('saves and retrieves events filtered by chapter', () async {
      final event1 = StoryEvent(
        id: 'evt_1',
        bookId: 'book_123',
        chapter: 5,
        summary: 'Lin Dong acquired the Stone Talisman.',
        involvedEntityIds: const ['char_1', 'item_talisman'],
        confidenceScore: 0.9,
        createdAt: DateTime.now(),
      );

      final event2 = StoryEvent(
        id: 'evt_2',
        bookId: 'book_123',
        chapter: 50,
        summary: 'Lin Dong defeated Lin Langtian in the clan gathering.',
        involvedEntityIds: const ['char_1', 'char_rival'],
        confidenceScore: 0.95,
        createdAt: DateTime.now(),
      );

      await repository.saveEvents([event1, event2]);

      // Filtered to chapter <= 10
      final res = await repository.getEvents('book_123', maxChapter: 10);
      expect(res, isA<Success<List<StoryEvent>>>());
      final list = (res as Success<List<StoryEvent>>).value;
      expect(list.length, 1);
      expect(list.first.id, 'evt_1');
    });
  });

  group('DriftStoryMemoryRepository - Review Queue & Cascade Deletion', () {
    test('saves, retrieves, and resolves review items', () async {
      final item = ReviewItem(
        id: 'rev_1',
        bookId: 'book_123',
        type: ReviewType.newEntity,
        entityId: 'char_provisional',
        candidateName: 'Mysterious Elder',
        confidenceScore: 0.45,
        evidence: const ['Matched dialogue tag: said Mysterious Elder'],
        chapterIndex: 12,
        createdAt: DateTime.now(),
      );

      await repository.saveReviewItem(item);
      final pending = await repository.getReviewQueue('book_123');
      expect((pending as Success<List<ReviewItem>>).value.length, 1);

      await repository.resolveReviewItem('rev_1', ReviewStatus.resolved);
      final pendingAfter = await repository.getReviewQueue('book_123');
      expect((pendingAfter as Success<List<ReviewItem>>).value.isEmpty, isTrue);

      final resolved = await repository.getReviewQueue('book_123', status: ReviewStatus.resolved);
      expect((resolved as Success<List<ReviewItem>>).value.length, 1);
    });

    test('deletes all story memory on cascade delete', () async {
      await repository.saveEntity(
        StoryEntity(
          id: 'e1',
          bookId: 'book_delete_test',
          type: StoryEntityType.character,
          canonicalName: 'Test Char',
          confidenceScore: 0.9,
          tier: ConfidenceTier.high,
          firstSeenChapter: 1,
          lastSeenChapter: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await repository.deleteBookStoryMemory('book_delete_test');
      final entities = await repository.getEntities('book_delete_test');
      expect((entities as Success<List<StoryEntity>>).value.isEmpty, isTrue);
    });
  });
}
