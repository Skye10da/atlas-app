import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
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

  group('Recap snapshots (schema 18)', () {
    test('no snapshot returns null; save then load round-trips', () async {
      final before = await repository.getRecapSnapshot(
        bookId: 'book_1',
        readThroughId: 'default',
        chapterIndex: 5,
      );
      expect((before as Success<String?>).value, isNull);

      final save = await repository.saveRecapSnapshot(
        bookId: 'book_1',
        readThroughId: 'default',
        chapterIndex: 5,
        recapText: '### Recap up to chapter 5\n- Lin Dong joined the Lin Clan tournament.',
      );
      expect(save, isA<Success<void>>());

      final after = await repository.getRecapSnapshot(
        bookId: 'book_1',
        readThroughId: 'default',
        chapterIndex: 5,
      );
      expect(
        (after as Success<String?>).value,
        contains('Lin Dong joined the Lin Clan tournament'),
      );
    });

    test('the same key is replaced; different keys stay isolated', () async {
      await repository.saveRecapSnapshot(
        bookId: 'book_1',
        readThroughId: 'default',
        chapterIndex: 5,
        recapText: 'older recap',
      );
      await repository.saveRecapSnapshot(
        bookId: 'book_1',
        readThroughId: 'default',
        chapterIndex: 5,
        recapText: 'newer recap',
      );
      await repository.saveRecapSnapshot(
        bookId: 'book_1',
        readThroughId: 'rt2',
        chapterIndex: 5,
        recapText: 'other read-through recap',
      );
      await repository.saveRecapSnapshot(
        bookId: 'book_1',
        readThroughId: 'default',
        chapterIndex: 6,
        recapText: 'later chapter recap',
      );

      expect(
        (await repository.getRecapSnapshot(
          bookId: 'book_1',
          chapterIndex: 5,
        ) as Success<String?>).value,
        'newer recap',
      );
      expect(
        (await repository.getRecapSnapshot(
          bookId: 'book_1',
          readThroughId: 'rt2',
          chapterIndex: 5,
        ) as Success<String?>).value,
        'other read-through recap',
      );
      expect(
        (await repository.getRecapSnapshot(
          bookId: 'book_1',
          chapterIndex: 6,
        ) as Success<String?>).value,
        'later chapter recap',
      );
    });

    test('deleteBookStoryMemory clears snapshots with the rest of the book',
        () async {
      await repository.saveRecapSnapshot(
        bookId: 'book_1',
        chapterIndex: 5,
        recapText: 'doomed recap',
      );
      await repository.saveRecapSnapshot(
        bookId: 'book_2',
        chapterIndex: 5,
        recapText: 'surviving recap',
      );

      await repository.deleteBookStoryMemory('book_1');

      expect(
        (await repository.getRecapSnapshot(
          bookId: 'book_1',
          chapterIndex: 5,
        ) as Success<String?>).value,
        isNull,
      );
      expect(
        (await repository.getRecapSnapshot(
          bookId: 'book_2',
          chapterIndex: 5,
        ) as Success<String?>).value,
        'surviving recap',
      );
    });
  });
}
