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

  group('Scenes (FTS5) & ingestion log persistence', () {
    test('saveScenes writes, searchScenes reads, re-save replaces', () async {
      await repository.saveScenes('book_1', 1, [
        'Lin Dong fights the Devouring Power in the deep pool.',
        'The Martial Ancestor leaves a stone seal behind.',
      ]);

      final res = await repository.searchScenes('book_1', 'devouring');
      expect(res, isA<Success<List<String>>>());
      final hits = (res as Success<List<String>>).value;
      expect(hits.length, 1);
      expect(hits.first, contains('Devouring Power'));

      // Re-save with different scenes: delete-then-insert must not duplicate.
      await repository.saveScenes('book_1', 1, [
        'A completely rewritten scene about Xiao Yan instead.',
      ]);
      final afterRewrite = await repository.searchScenes('book_1', 'devouring');
      expect((afterRewrite as Success<List<String>>).value, isEmpty);
      final newXiao = await repository.searchScenes('book_1', 'Xiao Yan');
      expect((newXiao as Success<List<String>>).value, hasLength(1));
    });

    test('isChapterIngested / recordChapterIngestion guard on text hash', () async {
      final before = await repository.isChapterIngested('book_1', 'default', 5, 'hash_a');
      expect((before as Success<bool>).value, isFalse);

      await repository.recordChapterIngestion('book_1', 'default', 5, 'hash_a');

      final sameHash = await repository.isChapterIngested('book_1', 'default', 5, 'hash_a');
      expect((sameHash as Success<bool>).value, isTrue);

      final differentHash = await repository.isChapterIngested('book_1', 'default', 5, 'hash_b');
      expect((differentHash as Success<bool>).value, isFalse);

      // Another chapter / read-through is unaffected.
      final otherChapter = await repository.isChapterIngested('book_1', 'default', 6, 'hash_a');
      expect((otherChapter as Success<bool>).value, isFalse);
      final otherRt = await repository.isChapterIngested('book_1', 'rt_x', 5, 'hash_a');
      expect((otherRt as Success<bool>).value, isFalse);
    });

    test('deleteBookStoryMemory clears the ingestion log and scenes', () async {
      await repository.saveScenes('book_1', 1, ['Scene A. Scene B continues here.']);
      await repository.saveScenes('book_2', 1, ['Unrelated scene that must survive.']);
      await repository.recordChapterIngestion('book_1', 'default', 1, 'hash_a');

      await repository.deleteBookStoryMemory('book_1');

      final log = await repository.isChapterIngested('book_1', 'default', 1, 'hash_a');
      expect((log as Success<bool>).value, isFalse);
      final scenes = await repository.searchScenes('book_1', 'Scene');
      expect((scenes as Success<List<String>>).value, isEmpty);
      // Other books untouched.
      final survivors = await repository.searchScenes('book_2', 'scene');
      expect((survivors as Success<List<String>>).value, isNotEmpty);
    });
  });
}
