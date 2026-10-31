import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/intelligence/domain/entities/confidence.dart';
import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/entities/story_relationship.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_story_memory_repository.dart';
import 'package:atlas_app/intelligence/orchestrator/context/context_assembler.dart';

void main() {
  late AppDatabase db;
  late DriftStoryMemoryRepository repository;
  late ContextAssembler assembler;

  setUp(() {
    db = AppDatabase.memory();
    repository = DriftStoryMemoryRepository(db: db);
    assembler = ContextAssembler(repository: repository);
  });

  tearDown(() async {
    await db.close();
  });

  const position = ReaderPosition(bookId: 'book_1', currentChapter: 10);

  Future<void> seedEntities() async {
    StoryEntity entity({
      required String id,
      required String name,
      List<String> aliases = const [],
      StoryEntityType type = StoryEntityType.character,
      int firstSeen = 1,
      int mentionCount = 1,
    }) =>
        StoryEntity(
          id: id,
          bookId: 'book_1',
          type: type,
          canonicalName: name,
          aliases: aliases,
          confidenceScore: 0.9,
          tier: ConfidenceTier.high,
          firstSeenChapter: firstSeen,
          lastSeenChapter: 10,
          mentionCount: mentionCount,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

    await repository.saveEntities([
      entity(id: 'e_lindong', name: 'Lin Dong', mentionCount: 40, firstSeen: 1),
      entity(id: 'e_qingtan', name: 'Ling Qingzhu', aliases: ['Qingzhu'], mentionCount: 25),
      entity(
        id: 'e_talisman',
        name: 'Stone Talisman',
        type: StoryEntityType.item,
        mentionCount: 12,
      ),
      entity(
        id: 'e_blackwater',
        name: 'Black Water City',
        type: StoryEntityType.location,
        mentionCount: 9,
      ),
      // Spoiler entity: first seen after the reader's chapter 10.
      entity(id: 'e_future', name: 'Future Lord', firstSeen: 20, mentionCount: 80),
    ]);
  }

  Future<void> seedScenes() async {
    await repository.saveScenes('book_1', 5, [
      'Lin Dong grasped the Stone Talisman as it hummed with primal energy.',
      'Black Water City stretched out under the dusk sky.',
      'An uneventful afternoon at the market.',
    ]);
    await repository.saveScenes('book_1', 40, [
      'This late chapter scene mentions Lin Dong after the spoiler limit.',
    ]);
  }

  group('Query-aware context assembly', () {
    test('entities beyond the reader chapter are excluded even when queried',
        () async {
      await seedEntities();

      final package = await assembler.assemblePackage(
        position: position,
        userQuery: 'who is Future Lord',
      );

      final names = package.entityContext.map((e) => e.canonicalName).toList();
      expect(names, isNot(contains('Future Lord')));
    });

    test('query relevance reranks matching entities to the front', () async {
      await seedEntities();

      final package = await assembler.assemblePackage(
        position: position,
        userQuery: 'tell me about the Stone Talisman',
      );

      expect(package.entityContext.first.canonicalName, 'Stone Talisman');
      expect(package.relevanceScores['e_talisman'], greaterThan(0));
      // Unrelated entities keep zero relevance.
      expect(package.relevanceScores.containsKey('e_blackwater'), isFalse);
    });

    test('without a query the entity order stays stable (no rerank)', () async {
      await seedEntities();

      final package = await assembler.assemblePackage(position: position);
      expect(package.relevanceScores, isEmpty);
      // Spoiler entity filtered; rest preserved.
      expect(package.entityContext, hasLength(4));
    });

    test('scene excerpts are BM25-relevant and spoiler-capped', () async {
      await seedEntities();
      await seedScenes();

      final package = await assembler.assemblePackage(
        position: position,
        userQuery: 'Stone Talisman hummed',
      );

      expect(package.sceneExcerpts, hasLength(1));
      expect(package.sceneExcerpts.first, contains('Stone Talisman'));
      expect(
        package.sceneExcerpts.any((s) => s.contains('late chapter')),
        isFalse,
        reason: 'Chapter-40 scene must never leak to a chapter-10 reader',
      );
    });

    test('short or missing queries skip the scene search', () async {
      await seedEntities();
      await seedScenes();

      final none = await assembler.assemblePackage(position: position);
      expect(none.sceneExcerpts, isEmpty);

      final tiny = await assembler.assemblePackage(
        position: position,
        userQuery: 'a?',
      );
      expect(tiny.sceneExcerpts, isEmpty);
    });
  });

  group('Relationship layer (spoiler cap)', () {
    test('relationshipContext excludes later-established links', () async {
      await seedEntities();
      await repository.saveRelationship(StoryRelationship(
        id: 'r1',
        bookId: 'book_1',
        sourceEntityId: 'e_lindong',
        targetEntityId: 'e_qingtan',
        relationType: 'allies_with',
        confidenceScore: 0.4,
        chapterEstablished: 2,
        createdAt: DateTime(2026, 1, 1),
      ));
      await repository.saveRelationship(StoryRelationship(
        id: 'r2',
        bookId: 'book_1',
        sourceEntityId: 'e_qingtan',
        targetEntityId: 'e_talisman',
        relationType: 'wields',
        confidenceScore: 0.95,
        chapterEstablished: 15,
        createdAt: DateTime(2026, 1, 1),
      ));

      final package = await assembler.assemblePackage(position: position);
      final ids = package.relationshipContext.map((r) => r.id).toList();
      expect(ids, contains('r1'));
      expect(ids, isNot(contains('r2')));
    });

    test('assemblePrompt renders relationships with entity names', () async {
      await seedEntities();
      await repository.saveRelationship(StoryRelationship(
        id: 'r1',
        bookId: 'book_1',
        sourceEntityId: 'e_lindong',
        targetEntityId: 'e_qingtan',
        relationType: 'allies_with',
        confidenceScore: 0.4,
        chapterEstablished: 2,
        createdAt: DateTime(2026, 1, 1),
      ));

      final prompt = await assembler.assemblePrompt(
        position: position,
        userQuery: 'how are Lin Dong and Qingzhu related?',
      );
      expect(prompt.systemPrompt, contains('Lin Dong —[allies_with]→ Ling Qingzhu'));
    });
  });

  group('Prompt assembly layers', () {
    test('system prompt carries the spoiler cap and memory; scenes land in the user prompt',
        () async {
      await seedEntities();
      await seedScenes();

      final prompt = await assembler.assemblePrompt(
        position: position,
        userQuery: 'Stone Talisman hummed',
        history: [
          const ChatMessagePayload(role: 'user', content: 'who is Lin Dong?'),
          const ChatMessagePayload(role: 'assistant', content: 'A martial artist of the Lin Clan.'),
        ],
      );

      final system = prompt.systemPrompt;
      expect(system, contains('STRICT SPOILER RULE'));
      expect(system, contains('Chapter 10'));
      expect(system, contains('### Story Entities:'));
      expect(system.contains('### Relevant Scene Excerpts'), isFalse);

      final user = prompt.userPrompt;
      expect(user, contains('### Previous Conversation:'));
      expect(user, contains('who is Lin Dong?'));
      expect(user, contains('### Relevant Scene Excerpts:'));
      expect(user, contains('User Query: Stone Talisman hummed'));
      expect(prompt.cacheSystemPrompt, isTrue);
    });

    test('history respects the layer token budget', () async {
      await seedEntities();

      final prompt = await assembler.assemblePrompt(
        position: position,
        userQuery: 'recap',
        history: [
          ChatMessagePayload(role: 'user', content: 'x ' * 2000),
        ],
      );

      final historyStart = prompt.userPrompt.indexOf('### Previous Conversation:');
      final historyEnd = prompt.userPrompt.indexOf('User Query:');
      final historyBlock = prompt.userPrompt.substring(historyStart, historyEnd);
      // historyBudget = 1200 tokens ≈ 4800 chars.
      expect(historyBlock.length, lessThanOrEqualTo(1200 * 4 + 10));
    });
  });
}
