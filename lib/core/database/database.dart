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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.memory() : super(NativeDatabase.memory());

  AppDatabase.open(super.executor);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
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
            for (final col in [
              books.sourceName,
              books.sourceId,
              books.sourceUrl,
            ]) {
              try {
                await migrator.addColumn(books, col as GeneratedColumn<Object>);
              } catch (_) {}
            }
            try {
              await migrator.addColumn(chapters, chapters.contentState as GeneratedColumn<Object>);
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
        },
      );

  Future<ReadingProgressData?> getReadingProgress(String bookId) =>
      (select(readingProgress)..where((p) => p.id.equals(bookId))).getSingleOrNull();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'atlas.db'));
    return NativeDatabase.createInBackground(file);
  });
}
