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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from == 1) {
            await migrator.createTable(dictionaryWords);
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
