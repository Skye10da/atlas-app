import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/query/query_engine.dart';
import 'package:atlas_app/intelligence/domain/entities/confidence.dart';
import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/entities/story_event.dart';
import 'package:atlas_app/intelligence/domain/entities/story_relationship.dart';
import 'package:atlas_app/intelligence/domain/repositories/story_memory_repository.dart';
import 'package:atlas_app/intelligence/orchestrator/ai_orchestrator.dart';
import 'package:atlas_app/intelligence/presentation/chat/chat_controller.dart';

class _MockStoryMemoryRepository extends Mock implements StoryMemoryRepository {}

/// A spy orchestrator: records whether it was invoked and replies with a fixed string.
class _SpyOrchestrator implements AiOrchestrator {
  bool executeTaskCalled = false;

  @override
  Stream<String> executeStream(AiTask task) async* {
    executeTaskCalled = true;
    yield 'stream-response';
  }

  @override
  Future<String> executeTask(AiTask task) async {
    executeTaskCalled = true;
    return 'AI companion says hello.';
  }
}

StoryEntity _linDong() => StoryEntity(
      id: 'book_1:ent:lin_dong',
      bookId: 'book_1',
      type: StoryEntityType.character,
      canonicalName: 'Lin Dong',
      aliases: const ['Dong-ge'],
      confidenceScore: 0.9,
      tier: ConfidenceTier.high,
      firstSeenChapter: 1,
      lastSeenChapter: 3,
      mentionCount: 12,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

const _position = ReaderPosition(bookId: 'book_1', readThroughId: 'default', currentChapter: 3);

void main() {
  late _MockStoryMemoryRepository repo;

  setUp(() {
    repo = _MockStoryMemoryRepository();
    when(() => repo.findEntityByNameOrAlias(
          any(),
          any(),
          readThroughId: any(named: 'readThroughId'),
        )).thenAnswer((_) async => const Success(null));
    when(() => repo.getEntities(
          any(),
          readThroughId: any(named: 'readThroughId'),
        )).thenAnswer((_) async => const Success(<StoryEntity>[]));
    when(() => repo.getRelationships(
          any(),
          readThroughId: any(named: 'readThroughId'),
          entityId: any(named: 'entityId'),
          maxChapter: any(named: 'maxChapter'),
        )).thenAnswer((_) async => const Success(<StoryRelationship>[]));
    when(() => repo.getEvents(
          any(),
          readThroughId: any(named: 'readThroughId'),
          maxChapter: any(named: 'maxChapter'),
          involvedEntityIds: any(named: 'involvedEntityIds'),
        )).thenAnswer((_) async => const Success(<StoryEvent>[]));
    when(() => repo.searchScenes(
          any(),
          any(),
          readThroughId: any(named: 'readThroughId'),
          maxChapter: any(named: 'maxChapter'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => const Success(<String>[]));
  });

  QueryEngine engineWithKnownEntity() {
    when(() => repo.findEntityByNameOrAlias(
          'book_1',
          'Lin Dong',
          readThroughId: any(named: 'readThroughId'),
        )).thenAnswer((_) async => Success(_linDong()));
    when(() => repo.getEntities('book_1', readThroughId: any(named: 'readThroughId')))
        .thenAnswer((_) async => Success([_linDong()]));
    return QueryEngine(repository: repo);
  }

  group('ChatController orchestrator routing', () {
    test('non-factual query routes to the orchestrator (Layer 3)', () async {
      final orchestrator = _SpyOrchestrator();
      final controller = ChatController(
        bookId: 'book_1',
        queryEngine: QueryEngine(repository: repo),
        orchestrator: orchestrator,
      );

      await controller.sendMessage(
        text: 'why does the sky change color tonight',
        position: _position,
      );

      expect(orchestrator.executeTaskCalled, isTrue);
      final state = controller.state;
      expect(state.isThinking, isFalse);
      final last = state.messages.last;
      expect(last.role, 'assistant');
      expect(last.source, 'ai_orchestrator');
      expect(last.content, 'AI companion says hello.');
    });

    test('resolvable factual query is answered offline — orchestrator not used', () async {
      final orchestrator = _SpyOrchestrator();
      final controller = ChatController(
        bookId: 'book_1',
        queryEngine: engineWithKnownEntity(),
        orchestrator: orchestrator,
      );

      await controller.sendMessage(
        text: 'who is Lin Dong',
        position: _position,
      );

      expect(orchestrator.executeTaskCalled, isFalse);
      final last = controller.state.messages.last;
      expect(last.role, 'assistant');
      expect(last.source, 'offline_memory');
      expect(last.content, contains('Lin Dong'));
    });

    test('fallback orchestrator is resolved lazily when none is injected', () async {
      var resolverCalled = false;
      final controller = ChatController(
        bookId: 'book_1',
        queryEngine: QueryEngine(repository: repo),
        orchestratorResolver: () async {
          resolverCalled = true;
          return _SpyOrchestrator();
        },
      );

      await controller.sendMessage(
        text: 'why does the sky change color tonight',
        position: _position,
      );

      expect(resolverCalled, isTrue);
      expect(controller.state.messages.last.source, 'ai_orchestrator');
    });

    test('no orchestrator and no offline resolution → offline engine fallback', () async {
      final controller = ChatController(
        bookId: 'book_1',
        queryEngine: QueryEngine(repository: repo),
      );

      await controller.sendMessage(
        text: 'why does the sky change color tonight',
        position: _position,
      );

      final last = controller.state.messages.last;
      expect(last.role, 'assistant');
      expect(last.source, 'offline_memory');
      expect(last.content, isNotEmpty);
    });
  });
}
