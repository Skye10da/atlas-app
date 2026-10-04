import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/intelligence/application/query/query_engine.dart';
import 'package:atlas_app/intelligence/domain/entities/confidence.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/entities/story_event.dart';
import 'package:atlas_app/intelligence/domain/entities/story_relationship.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_story_memory_repository.dart';

void main() {
  late AppDatabase db;
  late DriftStoryMemoryRepository repository;
  late QueryEngine engine;

  setUp(() async {
    db = AppDatabase.memory();
    repository = DriftStoryMemoryRepository(db: db);
    engine = QueryEngine(repository: repository);

    // Seed test entities
    final linDong = StoryEntity(
      id: 'book1:ent:lin_dong',
      bookId: 'book1',
      type: StoryEntityType.character,
      canonicalName: 'Lin Dong',
      aliases: const ['Martial Ancestor'],
      confidenceScore: 0.95,
      tier: ConfidenceTier.high,
      userConfirmed: true,
      firstSeenChapter: 1,
      lastSeenChapter: 10,
      mentionCount: 25,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final elderMo = StoryEntity(
      id: 'book1:ent:elder_mo',
      bookId: 'book1',
      type: StoryEntityType.character,
      canonicalName: 'Elder Mo',
      aliases: const ['Mo'],
      confidenceScore: 0.90,
      tier: ConfidenceTier.high,
      userConfirmed: true,
      firstSeenChapter: 1,
      lastSeenChapter: 5,
      mentionCount: 12,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final city = StoryEntity(
      id: 'book1:ent:black_water_city',
      bookId: 'book1',
      type: StoryEntityType.location,
      canonicalName: 'Black Water City',
      aliases: const [],
      confidenceScore: 0.85,
      tier: ConfidenceTier.high,
      userConfirmed: true,
      firstSeenChapter: 2,
      lastSeenChapter: 8,
      mentionCount: 9,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repository.saveEntities([linDong, elderMo, city]);

    // Seed relationship
    await repository.saveRelationship(
      StoryRelationship(
        id: 'book1:rel:1',
        bookId: 'book1',
        sourceEntityId: linDong.id,
        targetEntityId: elderMo.id,
        relationType: 'mentor',
        confidenceScore: 0.90,
        chapterEstablished: 1,
        createdAt: DateTime.now(),
      ),
    );

    // Seed events
    await repository.saveEvents([
      StoryEvent(
        id: 'book1:ev:1',
        bookId: 'book1',
        chapter: 1,
        summary: 'Lin Dong met Elder Mo in the Great Wasteland.',
        involvedEntityIds: [linDong.id, elderMo.id],
        confidenceScore: 0.90,
        createdAt: DateTime.now(),
      ),
      StoryEvent(
        id: 'book1:ev:2',
        bookId: 'book1',
        chapter: 2,
        summary: 'They arrived at Black Water City and entered the auction hall.',
        involvedEntityIds: [linDong.id, city.id],
        confidenceScore: 0.85,
        createdAt: DateTime.now(),
      ),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  group('QueryEngine', () {
    test('answers "Who is Lin Dong?" correctly', () async {
      final answer = await engine.executeQuery(
        bookId: 'book1',
        query: 'Who is Lin Dong?',
      );

      expect(answer, contains('Lin Dong'));
      expect(answer, contains('character'));
      expect(answer, contains('Martial Ancestor'));
    });

    test('answers "How does Lin Dong know Mo?" relationship query', () async {
      final answer = await engine.executeQuery(
        bookId: 'book1',
        query: 'How does Lin Dong know Mo?',
      );

      expect(answer, contains('mentor'));
      expect(answer, contains('Chapter 1'));
    });

    test('answers "Where is Black Water City?" query', () async {
      final answer = await engine.executeQuery(
        bookId: 'book1',
        query: 'Where is Black Water City?',
      );

      expect(answer, contains('Black Water City'));
      expect(answer, contains('location'));
      expect(answer, contains('Chapter 2'));
    });

    test('answers "Catch me up" recap query', () async {
      final answer = await engine.executeQuery(
        bookId: 'book1',
        query: 'Catch me up',
        readerChapter: 2,
      );

      expect(answer, contains('Story Recap'));
      expect(answer, contains('Lin Dong met Elder Mo'));
    });

    test('returns not found message for unknown entity', () async {
      final answer = await engine.executeQuery(
        bookId: 'book1',
        query: 'Who is Gandalf?',
      );

      expect(answer, contains('couldn\'t find'));
      expect(answer, contains('Gandalf'));
    });
  });
}

