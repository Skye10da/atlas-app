import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/database/tables/books.dart';
import 'package:atlas_app/core/database/tables/chapters.dart';
import 'package:atlas_app/core/database/tables/reading_progress.dart';
import 'package:atlas_app/core/database/tables/bookmarks.dart';
import 'package:atlas_app/core/database/tables/settings.dart';
import 'package:atlas_app/core/database/tables/characters.dart';
import 'package:atlas_app/core/database/tables/dictionary_words.dart';
import 'package:atlas_app/core/database/tables/web_bookmarks.dart';
import 'package:atlas_app/core/database/tables/web_history.dart';
import 'package:atlas_app/core/database/tables/web_tabs.dart';
import 'package:atlas_app/core/database/tables/notification_history.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/story_schema.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Books,
    Chapters,
    ReadingProgress,
    Bookmarks,
    AppSettings,
    Characters,
    DictionaryWords,
    WebHistory,
    WebBookmarks,
    WebTabs,
    NotificationHistory,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.memory() : super(NativeDatabase.memory());

  AppDatabase.open(super.executor);

  @override
  int get schemaVersion => 15;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA journal_mode=WAL;');
      await customStatement('PRAGMA busy_timeout=5000;');
      await customStatement('PRAGMA synchronous=NORMAL;');
      // Ensure schema 11 and 12 tables exist even on initial / in-memory DB setups
      await customStatement('''
        CREATE TABLE IF NOT EXISTS notification_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          payload TEXT,
          book_id TEXT,
          is_read INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        );
      ''');
      await customStatement('''
        CREATE TABLE IF NOT EXISTS reading_sessions (
          id TEXT NOT NULL PRIMARY KEY,
          book_id TEXT NOT NULL,
          duration_seconds INTEGER NOT NULL,
          chapters_read INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          session_date INTEGER NOT NULL
        );
      ''');
      await customStatement('''
        CREATE TABLE IF NOT EXISTS reading_goals (
          id TEXT NOT NULL PRIMARY KEY,
          weekly_chapter_target INTEGER NOT NULL DEFAULT 20,
          daily_minute_target INTEGER NOT NULL DEFAULT 30,
          updated_at INTEGER NOT NULL
        );
      ''');
      await customStatement('''
        CREATE TABLE IF NOT EXISTS discover_cache (
          cache_key TEXT NOT NULL PRIMARY KEY,
          data_json TEXT NOT NULL,
          cached_at INTEGER NOT NULL,
          expires_at INTEGER NOT NULL
        );
      ''');
      // Ensure schema 14 Story Memory tables exist
      for (final stmt in StorySchema.createStatements) {
        await customStatement(stmt);
      }
    },
    onUpgrade: (migrator, from, to) async {
      if (from == 1) {
        await migrator.createTable(dictionaryWords);
      } else if (from == 2) {
        for (final col in [
          dictionaryWords.sourceSentence,
          dictionaryWords.sourceTitle,
          dictionaryWords.reviewLevel,
          dictionaryWords.reviewCount,
          dictionaryWords.lastReviewedAt,
          dictionaryWords.nextReviewAt,
        ]) {
          try {
            await migrator.addColumn(dictionaryWords, col);
          } catch (_) {}
        }
      }
      if (from <= 3) {
        for (final col in [books.sourceName, books.sourceId, books.sourceUrl]) {
          try {
            await migrator.addColumn(books, col as GeneratedColumn<Object>);
          } catch (_) {}
        }
        try {
          await migrator.addColumn(
            chapters,
            chapters.contentState as GeneratedColumn<Object>,
          );
        } catch (_) {}
      }
      if (from <= 4) {
        try {
          await migrator.addColumn(books, books.status);
        } catch (_) {}
      }
      if (from <= 5) {
        for (final col in [
          dictionaryWords.source,
          dictionaryWords.sourceLabel,
        ]) {
          try {
            await migrator.addColumn(dictionaryWords, col);
          } catch (_) {}
        }
      }
      if (from <= 6) {
        try {
          await migrator.addColumn(books, books.itemType);
        } catch (_) {}
        await migrator.database.customStatement(
          "UPDATE books SET item_type = 'novel' WHERE source_name = 'MVLEMPYR'",
        );
      }
      if (from <= 7) {
        // CDA v2.2 content versioning.
        try {
          await migrator.addColumn(chapters, chapters.version);
        } catch (_) {}
        try {
          await migrator.addColumn(chapters, chapters.checksum);
        } catch (_) {}
        try {
          await migrator.addColumn(chapters, chapters.previousVersionRef);
        } catch (_) {}
      }
      if (from <= 8) {
        // In-app browser persistence (schema 9).
        await migrator.createTable(webHistory);
        await migrator.createTable(webBookmarks);
        await migrator.createTable(webTabs);
      }
      if (from <= 9) {
        // Ongoing-novel update tracking (schema 10).
        for (final col in [
          books.updateTrackingEnabled,
          books.lastCheckedAt,
          books.newChapterCount,
          books.hasUpdate,
        ]) {
          try {
            await migrator.addColumn(books, col);
          } catch (_) {}
        }
      }
      if (from <= 10) {
        // Notification history (schema 11) — raw SQL because code generation is broken.
        await customStatement('''
          CREATE TABLE IF NOT EXISTS notification_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            payload TEXT,
            book_id TEXT,
            is_read INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          );
        ''');
      }
      if (from <= 11) {
        // Reading analytics & Discover caching (schema 12)
        await customStatement('''
          CREATE TABLE IF NOT EXISTS reading_sessions (
            id TEXT NOT NULL PRIMARY KEY,
            book_id TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            chapters_read INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL,
            session_date INTEGER NOT NULL
          );
        ''');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS reading_goals (
            id TEXT NOT NULL PRIMARY KEY,
            weekly_chapter_target INTEGER NOT NULL DEFAULT 20,
            daily_minute_target INTEGER NOT NULL DEFAULT 30,
            updated_at INTEGER NOT NULL
          );
        ''');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS discover_cache (
            cache_key TEXT NOT NULL PRIMARY KEY,
            data_json TEXT NOT NULL,
            cached_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL
          );
        ''');
      }
      if (from <= 12) {
        // Fix progress scale: 0..100 → 0..1 (thousands-scale 0.11% was inflating to 11%).
        // Detect 0..100 DB by max>1; then divide ALL rows (including 0.11% <1) by 100.
        try {
          final maxRow = await customSelect(
            'SELECT MAX(percentage) as m FROM reading_progress',
          ).getSingle();
          final maxVal = maxRow.read<double?>('m');
          if (maxVal != null && maxVal > 1.0) {
            await customStatement(
              'UPDATE reading_progress SET percentage = percentage / 100.0 WHERE percentage IS NOT NULL',
            );
          }
          // Clamp any over-100% legacy drift.
          await customStatement(
            'UPDATE reading_progress SET percentage = 1.0 WHERE percentage > 1.0',
          );
        } catch (_) {}
      }
      if (from <= 13) {
        // Story Memory & Intelligence layer (schema 14)
        for (final stmt in StorySchema.createStatements) {
          try {
            await customStatement(stmt);
          } catch (_) {}
        }
        try {
          await customStatement('DROP TABLE IF EXISTS characters;');
        } catch (_) {}
      }
      if (from <= 14) {
        // Story Memory Re-read Isolation (schema 15)
        await customStatement('''
          CREATE TABLE IF NOT EXISTS story_read_throughs (
            id TEXT NOT NULL,
            book_id TEXT NOT NULL,
            name TEXT NOT NULL,
            current_chapter INTEGER NOT NULL DEFAULT 1,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (book_id, id)
          );
        ''');
        try {
          await customStatement('CREATE INDEX IF NOT EXISTS idx_story_read_throughs_book ON story_read_throughs(book_id);');
        } catch (_) {}

        final tables = [
          'story_entities',
          'story_relationships',
          'story_events',
          'story_cooccurrences',
          'story_review_queue',
          'story_corrections',
        ];
        for (final table in tables) {
          try {
            await customStatement("ALTER TABLE $table ADD COLUMN read_through_id TEXT NOT NULL DEFAULT 'default';");
          } catch (_) {}
        }

        try {
          await customStatement('CREATE INDEX IF NOT EXISTS idx_story_entities_book_rt ON story_entities(book_id, read_through_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_story_entities_name_rt ON story_entities(book_id, read_through_id, canonical_name);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_story_rel_book_rt ON story_relationships(book_id, read_through_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_story_events_book_rt_ch ON story_events(book_id, read_through_id, chapter);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_story_cooccur_book_rt ON story_cooccurrences(book_id, read_through_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_story_review_book_rt_status ON story_review_queue(book_id, read_through_id, status);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_story_corr_book_rt ON story_corrections(book_id, read_through_id);');
        } catch (_) {}

        try {
          await customStatement('''
            INSERT OR IGNORE INTO story_read_throughs (id, book_id, name, current_chapter, is_active, created_at, updated_at)
            SELECT DISTINCT 'default', book_id, 'Primary Read', 1, 1, strftime('%s', 'now') * 1000, strftime('%s', 'now') * 1000
            FROM story_entities;
          ''');
        } catch (_) {}
      }
    },
  );

  Future<ReadingProgressData?> getReadingProgress(String bookId) => (select(
    readingProgress,
  )..where((p) => p.id.equals(bookId))).getSingleOrNull();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'atlas.db'));
    return NativeDatabase.createInBackground(file);
  });
}
