import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';
import 'package:atlas_app/intelligence/orchestrator/ai_orchestrator.dart';
import 'package:atlas_app/intelligence/orchestrator/context/context_assembler.dart';
import 'package:atlas_app/intelligence/orchestrator/providers/ai_provider.dart';
import 'package:atlas_app/intelligence/orchestrator/providers/provider_registry.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_story_memory_repository.dart';

class FakeProvider implements AiProvider {
  FakeProvider(this._id, {this.streamFails, this.completes});

  final String _id;
  final String? completes;
  final Object? streamFails;

  int streamAttempts = 0;
  int completeAttempts = 0;

  @override
  String get id => _id;

  @override
  String get name => _id;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<String>> getAvailableModels() async => const [];

  @override
  Future<String> complete(AiPrompt prompt) async {
    completeAttempts++;
    if (completes == null) throw StateError('complete unavailable');
    return completes!;
  }

  @override
  Stream<String> completeStream(AiPrompt prompt) async* {
    streamAttempts++;
    final failure = streamFails;
    if (failure != null) {
      throw failure;
    }
    yield 'streamed-$_id';
  }
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  AiOrchestrator buildOrchestrator(List<AiProvider> providers) {
    final repository = DriftStoryMemoryRepository(db: db);
    final assembler = ContextAssembler(repository: repository);
    return AiOrchestrator(
      registry: ProviderRegistry(initialProviders: providers),
      assembler: assembler,
    );
  }

  AiTask makeTask() => const AiTask(
        bookId: 'book_1',
        position: ReaderPosition(bookId: 'book_1', currentChapter: 3),
        query: 'recap',
      );

  group('AiOrchestrator streaming fallback', () {
    test('healthy provider streams normally', () async {
      final provider = FakeProvider('good');
      final orchestrator = buildOrchestrator([provider]);

      final chunks = await orchestrator.executeStream(makeTask()).toList();
      expect(chunks.join(), 'streamed-good');
      expect(provider.streamAttempts, 1);
      expect(provider.completeAttempts, 0);
    });

    test('stream failure before first delta falls back to non-streaming completion',
        () async {
      final provider =
          FakeProvider('flaky', streamFails: StateError('sse broken'), completes: 'full answer');
      final orchestrator = buildOrchestrator([provider]);

      final chunks = await orchestrator.executeStream(makeTask()).toList();
      expect(chunks.join(), 'full answer');
      expect(provider.streamAttempts, 1);
      expect(provider.completeAttempts, 1);
    });

    test('provider that fails both paths falls through to the next provider',
        () async {
      final bad = FakeProvider('bad',
          streamFails: StateError('down'), completes: null);
      final good = FakeProvider('good');
      final orchestrator = buildOrchestrator([bad, good]);

      final chunks = await orchestrator.executeStream(makeTask()).toList();
      expect(chunks.join(), 'streamed-good');
      expect(bad.streamAttempts, 1);
      expect(bad.completeAttempts, 1);
      expect(good.streamAttempts, 1);
      expect(good.completeAttempts, 0);
    });

    test('mid-stream failure after emitted deltas is not silently restarted',
        () async {
      final provider = _MidStreamFailureProvider();
      final orchestrator = buildOrchestrator([provider]);

      await expectLater(
        orchestrator.executeStream(makeTask()).toList(),
        throwsStateError,
      );
      expect(provider.streamAttempts, 1);
      expect(provider.completeAttempts, 0);
    });

    test('every provider failing rethrows the last error', () async {
      final bad = FakeProvider('bad',
          streamFails: StateError('nope'), completes: null);
      final orchestrator = buildOrchestrator([bad]);

      await expectLater(
        orchestrator.executeStream(makeTask()).toList(),
        throwsStateError,
      );
    });

    test('no providers available throws a clear StateError', () async {
      final orchestrator = buildOrchestrator([]);
      await expectLater(
        orchestrator.executeStream(makeTask()).toList(),
        throwsStateError,
      );
    });
  });
}

/// Fails mid-stream: emits one delta, then throws.
class _MidStreamFailureProvider implements AiProvider {
  int streamAttempts = 0;
  int completeAttempts = 0;

  @override
  String get id => 'midfail';

  @override
  String get name => 'midfail';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<String>> getAvailableModels() async => const [];

  @override
  Future<String> complete(AiPrompt prompt) async {
    completeAttempts++;
    throw StateError('complete should never be reached');
  }

  @override
  Stream<String> completeStream(AiPrompt prompt) async* {
    streamAttempts++;
    yield 'partial-';
    throw StateError('connection reset mid-stream');
  }
}
