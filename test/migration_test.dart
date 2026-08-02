// ignore_for_file: avoid_dynamic_calls

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';

const _booksV6 = '''
CREATE TABLE "books" (
  "id" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "author" TEXT NULL,
  "cover_path" TEXT NULL,
  "description" TEXT NULL,
  "format" TEXT NOT NULL,
  "file_path" TEXT NOT NULL,
  "file_size" INTEGER NULL,
  "total_chapters" INTEGER NOT NULL,
  "language" TEXT NULL,
  "tags" TEXT NULL,
  "rating" REAL NULL,
  "created_at" INTEGER NOT NULL,
  "updated_at" INTEGER NOT NULL,
  "last_opened_at" INTEGER NULL,
  "source_name" TEXT NULL,
  "source_id" TEXT NULL,
  "source_url" TEXT NULL,
  "status" TEXT NULL,
  PRIMARY KEY ("id")
)
''';

const _readingProgressV6 = '''
CREATE TABLE "reading_progress" (
  "id" TEXT NOT NULL,
  "book_id" TEXT NOT NULL,
  "chapter_id" TEXT NOT NULL,
  "percentage" REAL NOT NULL,
  "position" INTEGER NOT NULL,
  "total_positions" INTEGER NOT NULL,
  "last_read_at" INTEGER NOT NULL,
  "reading_time_seconds" INTEGER NOT NULL,
  "is_completed" INTEGER NOT NULL DEFAULT 0 CHECK ("is_completed" IN (0, 1)),
  PRIMARY KEY ("id")
)
''';

const _chaptersV7 = '''
CREATE TABLE "chapters" (
  "id" TEXT NOT NULL,
  "book_id" TEXT NOT NULL,
  "index" INTEGER NOT NULL,
  "title" TEXT NOT NULL,
  "content_path" TEXT NOT NULL,
  "word_count" INTEGER NOT NULL,
  "content_state" INTEGER NOT NULL DEFAULT 0,
  "page_count" INTEGER NOT NULL,
  "created_at" INTEGER NOT NULL,
  PRIMARY KEY ("id")
)
''';

void main() {
  group('v6 to v7 migration (item_type)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('atlas_migration');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    Future<String> createV6Db({required bool withItemType}) async {
      final file = p.join(tempDir.path, 'atlas.db');
      final db = sqlite3.sqlite3.open(file);
      db.execute(_booksV6);
      db.execute(_readingProgressV6);
      if (withItemType) {
        db.execute(
            "ALTER TABLE books ADD COLUMN item_type TEXT NOT NULL DEFAULT 'book'");
      }
      db.execute(r'''
        INSERT INTO books (id, title, format, file_path, total_chapters,
        created_at, updated_at, source_name) VALUES
        ('g1', 'Gutenberg Book', 'epub', '/f/g', 10, 0, 0, 'Gutenberg'),
        ('m1', 'Mvlempyr Novel', 'web', '/f/m', 5, 0, 0, 'MVLEMPYR')
      ''');
      db.execute('PRAGMA user_version = 6');
      db.dispose();
      return file;
    }

    Future<void> expectMigratedBookCategories(String file) async {
      final appDb = AppDatabase.open(NativeDatabase(File(file)));
      try {
        final version = await appDb
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.data['user_version'], 8);

        final result = await DriftLibraryRepository(appDb).getBooks();
        expect(result, isA<Success<List<BookEntity>>>());
        final books = (result as Success).value;
        expect(books.length, 2);

        final gutenberg =
            books.firstWhere((b) => b.title == 'Gutenberg Book');
        final mvlempyr = books.firstWhere((b) => b.title == 'Mvlempyr Novel');
        expect(gutenberg.isNovel, isFalse);
        expect(gutenberg.itemType, ContentCategory.book);
        expect(mvlempyr.isNovel, isTrue);
        expect(mvlempyr.itemType, ContentCategory.novel);
      } finally {
        await appDb.close();
      }
    }

    test('adds item_type column and backfills novel on a plain v6 db',
        () async {
      final file = await createV6Db(withItemType: false);
      await expectMigratedBookCategories(file);
    });

    test('backfills novel when item_type already exists on a v6 db', () async {
      final file = await createV6Db(withItemType: true);
      await expectMigratedBookCategories(file);
    });
  });

  group('v7 to v8 migration (CDA content versioning)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('atlas_migration');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('adds version/checksum/previousVersionRef columns to chapters',
        () async {
      final file = p.join(tempDir.path, 'atlas.db');
      final db = sqlite3.sqlite3.open(file);
      db.execute(_booksV6);
      db.execute(_readingProgressV6);
      db.execute(_chaptersV7);
      db.execute('PRAGMA user_version = 7');
      db.dispose();

      final appDb = AppDatabase.open(NativeDatabase(File(file)));
      try {
        final version = await appDb
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.data['user_version'], 8);

        final cols =
            await appDb.customSelect('PRAGMA table_info(chapters)').get();
        final names = cols.map((r) => r.data['name']).toSet();
        expect(
            names,
            containsAll(
                ['version', 'checksum', 'previous_version_ref']));
      } finally {
        await appDb.close();
      }
    });
  });
}
