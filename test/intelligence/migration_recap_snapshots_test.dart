// v17 → v18 migration: recap snapshots table is additive and does not disturb
// existing story-memory rows. Mirrors the harness pattern in migration_test.dart.
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:atlas_app/core/database/database.dart';

void main() {
  test('v17 to v18 migration (recap snapshots) creates story_recap_snapshots and preserves story memory', () async {
    final tempDir = await Directory.systemTemp.createTemp('atlas_migration');
    final file = p.join(tempDir.path, 'db.sqlite');

    final db = sqlite3.sqlite3.open(file);
    db.execute('PRAGMA user_version = 17');
    // Pre-existing story-memory rows that must survive the addititive bump.
    db.execute('''
      CREATE TABLE story_entities (
        id TEXT NOT NULL PRIMARY KEY,
        book_id TEXT NOT NULL,
        read_through_id TEXT NOT NULL DEFAULT 'default',
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
    ''');
    db.execute('''
      INSERT INTO story_entities (
        id, book_id, read_through_id, type, canonical_name, aliases,
        confidence_score, tier, user_confirmed, attributes,
        first_seen_chapter, last_seen_chapter, mention_count, created_at, updated_at
      ) VALUES (
        'e1', 'novel_1', 'default', 'character', 'Lin Dong', '[]', 0.95,
        'high', 0, '{}', 1, 10, 15, 1000, 2000
      );
    ''');
    db.dispose();

    final appDb = AppDatabase.open(NativeDatabase(File(file)));
    try {
      final version = await appDb.customSelect('PRAGMA user_version').getSingle();
      expect(version.data['user_version'], AppDatabase().schemaVersion);

      // Snapshot table exists and round-trips through the repository API.
      await appDb.customStatement('''
        INSERT INTO story_recap_snapshots (
          book_id, read_through_id, chapter_index, recap_text, generated_at
        ) VALUES ('novel_1', 'default', 5, 'recap text', 1000);
      ''');
      final rows = await appDb.customSelect(
        'SELECT recap_text FROM story_recap_snapshots WHERE book_id = ?',
        variables: [const Variable<String>('novel_1')],
      ).get();
      expect(rows.single.read<String>('recap_text'), 'recap text');

      // Pre-existing entity survived.
      final entities = await appDb.customSelect(
        'SELECT canonical_name FROM story_entities',
      ).get();
      expect(entities.single.read<String>('canonical_name'), 'Lin Dong');
    } finally {
      await appDb.close();
      tempDir.deleteSync(recursive: true);
    }
  });
}
