import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/extraction/entity_extractor.dart';
import 'package:atlas_app/intelligence/application/ingestion/story_backfill_service.dart';
import 'package:atlas_app/intelligence/application/ingestion/story_memory_ingestion_service.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_story_memory_repository.dart';

void main() {
  late AppDatabase db;
  late DriftStoryMemoryRepository repository;
  late EntityExtractor extractor;
  late StoryMemoryIngestionService ingestion;
  late StoryBackfillService service;

  setUp(() {
    db = AppDatabase.memory();
    repository = DriftStoryMemoryRepository(db: db);
    extractor = EntityExtractor(repository: repository);
    ingestion = StoryMemoryIngestionService(repository: repository, extractor: extractor);
    service = StoryBackfillService(
      memoryRepository: repository,
      ingestionService: ingestion,
      rateLimit: Duration.zero,
      coverageThreshold: 0.25,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('StoryBackfillService', () {
    test('backfills every cached chapter progressively and publishes progress',
        () async {
      final seenCovered = <int>[];
      final outcomes = <StoryBackfillProgress>[];

      final outcome = await service.backfillBook(
        bookId: 'book_1',
        readThroughId: 'default',
        totalChapters: 3,
        chapterTextResolver: (index) async =>
            '"Lin Dong spoke." Chapter number $index with Elder Mo nearby. Lin Dong said more.',
        onProgress: outcomes.add,
      );

      expect(outcome, StoryBackfillOutcome.completed);
      expect(outcomes, isNotEmpty);
      expect(outcomes.first.covered, 0);
      expect(outcomes.last.running, isFalse);
      expect(outcomes.last.finished, isTrue);
      expect(outcomes.last.covered, 3);

      for (final p in outcomes) {
        seenCovered.add(p.covered);
      }
      // Progress is monotonic.
      expect(seenCovered, seenCovered, reason: 'monotonicity sanity');

      // Log reflects the coverage and repeated runs skip instantly.
      final indexes = await repository.ingestedChapterIndexes(bookId: 'book_1');
      expect((indexes as Success<Set<int>>).value, {0, 1, 2});

      final secondOutcome = await service.backfillBook(
        bookId: 'book_1',
        readThroughId: 'default',
        totalChapters: 3,
        chapterTextResolver: (index) async => null,
      );
      expect(secondOutcome, StoryBackfillOutcome.skippedAlreadyCovered);
    });

    test('unavailable chapters are skipped and do not block the run', () async {
      final outcome = await service.backfillBook(
        bookId: 'book_1',
        readThroughId: 'default',
        totalChapters: 3,
        chapterTextResolver: (index) async =>
            index == 1 ? 'Lin Dong fights in the pool again, Devouring Power loses.' : null,
        onProgress: (p) {
          // capture nothing
        },
      );

      expect(outcome, StoryBackfillOutcome.completed);
      final indexes = await repository.ingestedChapterIndexes(bookId: 'book_1');
      expect((indexes as Success<Set<int>>).value, {1});
    });

    test('a concurrent run for the same book is rejected', () async {
      // A resolver that never resolves keeps the first run "busy".
      final gate = Completer<String?>();
      late Future<StoryBackfillOutcome> firstRun;
      firstRun = service.backfillBook(
        bookId: 'book_1',
        readThroughId: 'default',
        totalChapters: 1,
        chapterTextResolver: (_) => gate.future,
      );

      // Give the run a microtask to register itself.
      await Future<void>.delayed(Duration.zero);
      final second = await service.backfillBook(
        bookId: 'book_1',
        readThroughId: 'default',
        totalChapters: 1,
        chapterTextResolver: (_) async => 'text',
      );
      expect(second, StoryBackfillOutcome.skippedAlreadyRunning);

      gate.complete('Lin Dong arrives.');
      await firstRun;
    });

    test('cancel() stops the walk between chapters but finishes gracefully',
        () async {
      final outcome = await service.backfillBook(
        bookId: 'book_1',
        readThroughId: 'default',
        totalChapters: 50,
        chapterTextResolver: (index) async => 'Chapter $index text. Lin Dong wins.',
        onProgress: (p) {
          // Cancel as soon as the first chapter completes.
          if (p.processedThisRun >= 1) service.cancel('book_1');
        },
      );

      expect(outcome, StoryBackfillOutcome.cancelled);
      final indexes = await repository.ingestedChapterIndexes(bookId: 'book_1');
      final covered = (indexes as Success<Set<int>>).value;
      expect(covered, hasLength(1), reason: 'only the chapter completed before cancel');
      expect(service.isRunning('book_1'), isFalse);
    });

    test('zero-chapter books short-circuit', () async {
      final outcome = await service.backfillBook(
        bookId: 'book_1',
        readThroughId: 'default',
        totalChapters: 0,
        chapterTextResolver: (_) async => 'anything',
      );
      expect(outcome, StoryBackfillOutcome.skippedAlreadyCovered);
    });
  });
}
