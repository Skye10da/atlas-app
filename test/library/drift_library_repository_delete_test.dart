import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);

  final Directory dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      '${dir.path}/documents';
}

void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('delete_repro_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> seedBook() async {
    final bookDir = '${tempDir.path}/books/test_delete';
    await Directory(bookDir).create(recursive: true);
    await db
        .into(db.books)
        .insert(
          BooksCompanion.insert(
            id: 'test_delete',
            title: 'Test Delete',
            format: 'novel',
            totalChapters: 2,
            filePath: bookDir,
            itemType: Value(ContentCategory.novel.name),
            sourceName: const Value('fake'),
            sourceUrl: const Value('https://example.com/novel'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
    await db.batch((batch) {
      batch.insertAll(
        db.chapters,
        [
          for (var i = 0; i < 2; i++)
            ChaptersCompanion.insert(
              id: 'test_delete_ch$i',
              bookId: 'test_delete',
              index: i,
              title: 'Chapter ${i + 1}',
              contentPath: '$bookDir/$i.txt',
              wordCount: 10,
              pageCount: 1,
              createdAt: DateTime.now(),
            ),
        ],
      );
    });
  }

  test('deleteBook succeeds when the legacy characters table is absent', () async {
    await seedBook();
    // Pre-14 live databases dropped `characters` during the Story Memory
    // migration. Deletion used to abort with SqliteException "no such table"
    // and surface as "Something went wrong while loading your data."
    await db.customStatement('DROP TABLE characters');

    final repo = DriftLibraryRepository(db);
    final result = await repo.deleteBook('test_delete');

    expect(result.isSuccess, isTrue);
    final rows = await repo.getBooks();
    expect(rows.valueOrNull, isEmpty);
  });

  test('deleteBooks succeeds when the legacy characters table is absent', () async {
    await seedBook();
    await db.customStatement('DROP TABLE characters');

    final repo = DriftLibraryRepository(db);
    final result = await repo.deleteBooks(['test_delete']);

    expect(result.isSuccess, isTrue);
    final rows = await repo.getBooks();
    expect(rows.valueOrNull, isEmpty);
  });
}

