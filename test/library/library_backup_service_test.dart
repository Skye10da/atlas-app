import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/application/library_backup_service.dart';

void main() {
  late AppDatabase db;
  late LibraryBackupService service;

  setUp(() {
    db = AppDatabase.memory();
    service = LibraryBackupService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('exportBackupJson exports books, progress, bookmarks, and words', () async {
    // Seed test book
    await db.into(db.books).insert(
      BooksCompanion.insert(
        id: 'book-1',
        title: 'Lord of Mysteries',
        author: const Value('Cuttlefish'),
        format: 'novel',
        filePath: '',
        totalChapters: 1400,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    // Seed progress
    await db.into(db.readingProgress).insert(
      ReadingProgressCompanion.insert(
        id: 'prog-1',
        bookId: 'book-1',
        chapterId: 'ch-10',
        percentage: 0.15,
        position: 5,
        totalPositions: 100,
        lastReadAt: DateTime(2026, 1, 2),
        readingTimeSeconds: 3600,
      ),
    );

    // Seed bookmark
    await db.into(db.bookmarks).insert(
      BookmarksCompanion.insert(
        id: 'bm-1',
        bookId: 'book-1',
        chapterId: 'ch-10',
        position: 5,
        note: const Value('Praise the Fool!'),
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 1, 2),
      ),
    );

    // Seed word
    await db.into(db.dictionaryWords).insert(
      DictionaryWordsCompanion.insert(
        id: 'word-1',
        word: 'Mysteries',
        definition: 'Something that is difficult or impossible to understand.',
        language: 'en',
        languageLabel: 'English',
        partOfSpeech: 'noun',
        fullJson: '{}',
        savedAt: DateTime(2026, 1, 2),
      ),
    );

    final jsonString = await service.exportBackupJson();
    expect(jsonString, isNotEmpty);

    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    expect(decoded['format'], equals('atlas_backup'));
    expect(decoded['version'], equals(1));
    expect((decoded['books'] as List).length, equals(1));
    expect((decoded['readingProgress'] as List).length, equals(1));
    expect((decoded['bookmarks'] as List).length, equals(1));
    expect((decoded['dictionaryWords'] as List).length, equals(1));
  });

  test('restoreBackupJson restores data accurately into empty database', () async {
    final sampleBackup = jsonEncode({
      'format': 'atlas_backup',
      'version': 1,
      'exportedAt': '2026-08-29T00:00:00.000',
      'books': [
        {
          'id': 'book-restore-1',
          'title': 'Shadow Slave',
          'author': 'Guiltythree',
          'format': 'novel',
          'totalChapters': 1800,
          'filePath': '',
          'createdAt': '2026-01-01T00:00:00.000',
          'updatedAt': '2026-01-01T00:00:00.000',
        },
      ],
      'readingProgress': [
        {
          'id': 'prog-restore-1',
          'bookId': 'book-restore-1',
          'chapterId': 'ch-50',
          'percentage': 0.25,
          'position': 20,
          'totalPositions': 200,
          'readingTimeSeconds': 5400,
          'isCompleted': false,
          'lastReadAt': '2026-01-05T00:00:00.000',
        },
      ],
      'bookmarks': [
        {
          'id': 'bm-restore-1',
          'bookId': 'book-restore-1',
          'chapterId': 'ch-50',
          'position': 20,
          'note': 'Sunny reaches the citadel',
          'createdAt': '2026-01-05T00:00:00.000',
          'updatedAt': '2026-01-05T00:00:00.000',
        },
      ],
      'dictionaryWords': [
        {
          'id': 'word-restore-1',
          'word': 'Treacherous',
          'definition': 'Guilty of or involving betrayal or deception.',
          'language': 'en',
          'languageLabel': 'English',
          'partOfSpeech': 'adj',
          'fullJson': '{}',
          'savedAt': '2026-01-05T00:00:00.000',
        },
      ],
    });

    final result = await service.restoreBackupJson(sampleBackup);
    expect(result, isA<Success<BackupRestoreSummary>>());

    final summary = (result as Success<BackupRestoreSummary>).value;
    expect(summary.booksRestored, equals(1));
    expect(summary.bookmarksRestored, equals(1));
    expect(summary.wordsRestored, equals(1));

    // Verify database state
    final books = await db.select(db.books).get();
    expect(books.length, equals(1));
    expect(books.first.title, equals('Shadow Slave'));

    final bookmarks = await db.select(db.bookmarks).get();
    expect(bookmarks.length, equals(1));
    expect(bookmarks.first.note, equals('Sunny reaches the citadel'));
  });

  test('restoreBackupJson fails safely on malformed format', () async {
    final invalidBackup = jsonEncode({'format': 'other_app', 'version': 1});
    final result = await service.restoreBackupJson(invalidBackup);
    expect(result, isA<Failure<BackupRestoreSummary>>());
  });
}

