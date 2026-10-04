// ignore_for_file: avoid_dynamic_calls

import 'dart:io';

import 'package:drift/drift.dart' show Variable;
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
          "ALTER TABLE books ADD COLUMN item_type TEXT NOT NULL DEFAULT 'book'",
        );
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
        expect(version.data['user_version'], 15);

        final result = await DriftLibraryRepository(appDb).getBooks();
        expect(result, isA<Success<List<BookEntity>>>());
        final books = (result as Success).value;
        expect(books.length, 2);

        final gutenberg = books.firstWhere((b) => b.title == 'Gutenberg Book');
        final mvlempyr = books.firstWhere((b) => b.title == 'Mvlempyr Novel');
        expect(gutenberg.isNovel, isFalse);
        expect(gutenberg.itemType, ContentCategory.book);
        expect(mvlempyr.isNovel, isTrue);
        expect(mvlempyr.itemType, ContentCategory.novel);
      } finally {
        await appDb.close();
      }
    }

    test(
      'adds item_type column and backfills novel on a plain v6 db',
      () async {
        final file = await createV6Db(withItemType: false);
        await expectMigratedBookCategories(file);
      },
    );

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

    test(
      'adds version/checksum/previousVersionRef columns to chapters',
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
          expect(version.data['user_version'], 15);

          final cols = await appDb
              .customSelect('PRAGMA table_info(chapters)')
              .get();
          final names = cols.map((r) => r.data['name']).toSet();
          expect(
            names,
            containsAll(['version', 'checksum', 'previous_version_ref']),
          );
        } finally {
          await appDb.close();
        }
      },
    );
  });

  group('v9 to v10 migration (update tracking)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('atlas_migration');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('adds update-tracking columns with safe defaults', () async {
      final file = p.join(tempDir.path, 'atlas.db');
      final db = sqlite3.sqlite3.open(file);
      db.execute(_booksV6);
      db.execute(_readingProgressV6);
      db.execute(_chaptersV7);
      db.execute(r'''
        INSERT INTO books (id, title, format, file_path, total_chapters,
        created_at, updated_at) VALUES
        ('b1', 'Tracked Novel', 'web', '/f/b', 5, 0, 0)
      ''');
      db.execute('PRAGMA user_version = 9');
      db.dispose();

      final appDb = AppDatabase.open(NativeDatabase(File(file)));
      try {
        final version = await appDb
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.data['user_version'], 15);

        final cols = await appDb.customSelect('PRAGMA table_info(books)').get();
        final names = cols.map((r) => r.data['name']).toSet();
        expect(
          names,
          containsAll([
            'update_tracking_enabled',
            'last_checked_at',
            'new_chapter_count',
            'has_update',
          ]),
        );

        final row = await appDb
            .customSelect(
              'SELECT update_tracking_enabled, new_chapter_count, has_update '
              'FROM books WHERE id = ?',
              variables: [Variable.withString('b1')],
            )
            .getSingle();
        expect(row.data['update_tracking_enabled'], 1);
        expect(row.data['new_chapter_count'], 0);
        expect(row.data['has_update'], 0);
      } finally {
        await appDb.close();
      }
    });
  });

  group('v13 to v14 migration (Story Memory & Intelligence layer)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('atlas_migration_v14');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('creates story tables and drops characters table on upgrade from v13', () async {
      final file = p.join(tempDir.path, 'atlas.db');
      final db = sqlite3.sqlite3.open(file);
      db.execute(_booksV6);
      db.execute(_readingProgressV6);
      db.execute(_chaptersV7);
      db.execute('''
        CREATE TABLE characters (
          id TEXT NOT NULL PRIMARY KEY,
          book_id TEXT NOT NULL,
          name TEXT NOT NULL
        );
      ''');
      db.execute('PRAGMA user_version = 13');
      db.dispose();

      final appDb = AppDatabase.open(NativeDatabase(File(file)));
      try {
        final version = await appDb
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.data['user_version'], 15);

        // Check story_entities table exists
        final entityCols = await appDb.customSelect('PRAGMA table_info(story_entities)').get();
        final entityColNames = entityCols.map((r) => r.data['name']).toSet();
        expect(
          entityColNames,
          containsAll([
            'id',
            'book_id',
            'type',
            'canonical_name',
            'confidence_score',
            'tier',
            'user_confirmed',
            'attributes',
            'mention_count',
          ]),
        );

        // Check relationships, events, cooccurrences, review queue, corrections tables exist
        final tables = await appDb.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table'",
        ).get();
        final tableNames = tables.map((r) => r.data['name']).toSet();
        expect(
          tableNames,
          containsAll([
            'story_entities',
            'story_relationships',
            'story_events',
            'story_cooccurrences',
            'story_review_queue',
            'story_corrections',
            'story_scenes_fts',
          ]),
        );

        // Verify characters table was dropped
        expect(tableNames.contains('characters'), isFalse);
      } finally {
        await appDb.close();
      }
    });
  });

  group('v14 to v15 migration (Story Memory Re-read Isolation)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('atlas_migration_v15');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('adds read-throughs table, read_through_id columns, and backfills default read-through', () async {
      final file = p.join(tempDir.path, 'atlas.db');
      final db = sqlite3.sqlite3.open(file);
      db.execute(_booksV6);
      db.execute(_readingProgressV6);
      db.execute(_chaptersV7);
      // Create v14 story tables without read_through_id
      db.execute('''
        CREATE TABLE story_entities (
          id TEXT NOT NULL PRIMARY KEY,
          book_id TEXT NOT NULL,
          type TEXT NOT NULL,
          canonical_name TEXT NOT NULL,
          aliases TEXT,
          confidence_score REAL NOT NULL,
          tier TEXT NOT NULL,
          user_confirmed INTEGER NOT NULL DEFAULT 0,
          attributes TEXT,
          first_seen_chapter INTEGER NOT NULL DEFAULT 1,
          last_seen_chapter INTEGER NOT NULL DEFAULT 1,
          mention_count INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
        CREATE TABLE story_relationships (
          id TEXT NOT NULL PRIMARY KEY,
          book_id TEXT NOT NULL,
          source_entity_id TEXT NOT NULL,
          target_entity_id TEXT NOT NULL,
          relation_type TEXT NOT NULL,
          confidence_score REAL NOT NULL,
          chapter_established INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE story_events (
          id TEXT NOT NULL PRIMARY KEY,
          book_id TEXT NOT NULL,
          chapter INTEGER NOT NULL,
          summary TEXT NOT NULL,
          involved_entity_ids TEXT,
          confidence_score REAL NOT NULL,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE story_cooccurrences (
          id TEXT NOT NULL PRIMARY KEY,
          book_id TEXT NOT NULL,
          entity_a_id TEXT NOT NULL,
          entity_b_id TEXT NOT NULL,
          weight INTEGER NOT NULL DEFAULT 1,
          last_seen_chapter INTEGER NOT NULL
        );
        CREATE TABLE story_review_queue (
          id TEXT NOT NULL PRIMARY KEY,
          book_id TEXT NOT NULL,
          type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          target_entity_id TEXT,
          candidate_name TEXT NOT NULL,
          target_name TEXT,
          confidence_score REAL NOT NULL,
          similarity_score REAL,
          cooccurrence_count INTEGER NOT NULL DEFAULT 0,
          evidence_json TEXT,
          status TEXT NOT NULL DEFAULT 'pending',
          chapter_index INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE story_corrections (
          id TEXT NOT NULL PRIMARY KEY,
          book_id TEXT NOT NULL,
          pattern TEXT NOT NULL,
          decision TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''');

      // Insert pre-existing entity in v14 db
      db.execute('''
        INSERT INTO story_entities (
          id, book_id, type, canonical_name, aliases, confidence_score, tier,
          user_confirmed, attributes, first_seen_chapter, last_seen_chapter,
          mention_count, created_at, updated_at
        ) VALUES (
          'e1', 'novel_1', 'character', 'Lin Dong', '[]', 0.95, 'high',
          1, '{}', 1, 10, 15, 1000, 2000
        );
      ''');
      db.execute('PRAGMA user_version = 14');
      db.dispose();

      final appDb = AppDatabase.open(NativeDatabase(File(file)));
      try {
        final version = await appDb
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.data['user_version'], 15);

        // Check story_read_throughs table exists
        final tables = await appDb.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table'",
        ).get();
        final tableNames = tables.map((r) => r.data['name']).toSet();
        expect(tableNames, contains('story_read_throughs'));

        // Check read_through_id column added to story_entities
        final entityCols = await appDb.customSelect('PRAGMA table_info(story_entities)').get();
        final entityColNames = entityCols.map((r) => r.data['name']).toSet();
        expect(entityColNames, contains('read_through_id'));

        // Check default read-through record was backfilled for novel_1
        final readThroughRows = await appDb.customSelect(
          'SELECT * FROM story_read_throughs WHERE book_id = ?',
          variables: [Variable.withString('novel_1')],
        ).get();
        expect(readThroughRows.length, 1);
        expect(readThroughRows.first.data['id'], 'default');
        expect(readThroughRows.first.data['name'], 'Primary Read');
        expect(readThroughRows.first.data['is_active'], 1);

        // Check existing entity has read_through_id = 'default'
        final entityRows = await appDb.customSelect(
          'SELECT read_through_id FROM story_entities WHERE id = ?',
          variables: [Variable.withString('e1')],
        ).get();
        expect(entityRows.first.data['read_through_id'], 'default');
      } finally {
        await appDb.close();
      }
    });
  });
}

