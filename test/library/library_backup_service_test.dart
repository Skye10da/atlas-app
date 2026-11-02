import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/application/library_backup_service.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/infrastructure/services/annotations_storage_service.dart';

class MockAnnotationsStorageService extends AnnotationsStorageService {
  final Map<String, ReaderAnnotationsState> storage = {};

  @override
  Future<ReaderAnnotationsState?> loadAnnotations(String bookId) async {
    return storage[bookId];
  }

  @override
  Future<void> saveAnnotations(
    String bookId,
    ReaderAnnotationsState state,
  ) async {
    storage[bookId] = state;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockAnnotationsStorageService mockAnnotations;
  late Directory tempDir;
  late LibraryBackupService service;

  setUp(() async {
    db = AppDatabase.memory();
    mockAnnotations = MockAnnotationsStorageService();
    tempDir = await Directory.systemTemp.createTemp('atlas_backup_test_');
    service = LibraryBackupService(
      db,
      annotationsStorage: mockAnnotations,
      getDocumentsDirectory: () async => tempDir,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'exportBackupJson exports complete library state including novels, books, chapters, and exact reading positions',
    () async {
      // 1. Seed a regular book
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-1',
              title: 'Lord of the Rings',
              author: const Value('J.R.R. Tolkien'),
              format: 'epub',
              filePath: '/tmp/lotr.epub',
              totalChapters: 60,
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
              itemType: const Value('book'),
              tags: const Value('Fantasy, Epic'),
            ),
          );

      // 2. Seed a web novel
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'novel-1',
              title: 'Shadow Slave',
              author: const Value('Guiltythree'),
              format: 'novel',
              filePath: '/tmp/novels/shadow_slave',
              totalChapters: 1800,
              createdAt: DateTime(2026, 1, 2),
              updatedAt: DateTime(2026, 1, 2),
              itemType: const Value('novel'),
              sourceName: const Value('WebNovelSource'),
              sourceUrl: const Value('https://example.com/shadow_slave'),
              updateTrackingEnabled: const Value(true),
              newChapterCount: const Value(5),
              hasUpdate: const Value(true),
            ),
          );

      // 3. Seed chapters for the novel
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: 'novel-1_ch0',
              bookId: 'novel-1',
              index: 0,
              title: 'Chapter 1: Nightmare Begins',
              contentPath: '/tmp/novels/shadow_slave/0.txt',
              wordCount: 1500,
              pageCount: 5,
              createdAt: DateTime(2026, 1, 2),
              version: const Value(2),
              checksum: const Value('abc123sha'),
            ),
          );

      // 4. Seed exact reading progress with sentence / block position
      await db
          .into(db.readingProgress)
          .insert(
            ReadingProgressCompanion.insert(
              id: 'novel-1',
              bookId: 'novel-1',
              chapterId: 'novel-1_ch0',
              percentage: 0.42,
              position: 18,
              totalPositions: 45,
              lastReadAt: DateTime(2026, 1, 3),
              readingTimeSeconds: 4200,
              isCompleted: const Value(false),
            ),
          );

      // 5. Seed bookmark
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: 'bm-1',
              bookId: 'novel-1',
              chapterId: 'novel-1_ch0',
              position: 18,
              note: const Value('Sunny discovers the Fated attribute'),
              createdAt: DateTime(2026, 1, 3),
              updatedAt: DateTime(2026, 1, 3),
            ),
          );

      // 6. Seed character
      await db
          .into(db.characters)
          .insert(
            CharactersCompanion.insert(
              id: 'char-1',
              bookId: 'novel-1',
              name: 'Sunny',
              role: const Value('Protagonist'),
              aliases: const Value('Lost from Light, Sunless'),
              description: const Value('A cunning and pragmatic survivor.'),
              createdAt: DateTime(2026, 1, 2),
              updatedAt: DateTime(2026, 1, 2),
            ),
          );

      // 7. Seed dictionary word
      await db
          .into(db.dictionaryWords)
          .insert(
            DictionaryWordsCompanion.insert(
              id: 'word-1',
              word: 'Pragmatic',
              definition: 'Dealing with things sensibly and realistically.',
              language: 'en',
              languageLabel: 'English',
              partOfSpeech: 'adj',
              fullJson: '{}',
              savedAt: DateTime(2026, 1, 3),
              sourceTitle: const Value('Shadow Slave'),
            ),
          );

      // 8. Seed annotation in mock storage
      mockAnnotations.storage['novel-1'] = ReaderAnnotationsState(
        highlights: {
          'novel-1_ch0': [
            HighlightEntry(
              chapterId: 'novel-1_ch0',
              start: 10,
              end: 25,
              text: 'Fated to die',
              colorValue: 0xFFFFEB3B,
              createdAt: DateTime(2026, 1, 3),
            ),
          ],
        },
        notes: {
          'novel-1_ch0': [
            NoteEntry(
              id: 'note-1',
              chapterId: 'novel-1_ch0',
              text: 'Important turning point',
              sentence: 'Fated to die',
              createdAt: DateTime(2026, 1, 3),
            ),
          ],
        },
      );

      final jsonString = await service.exportBackupJson();
      expect(jsonString, isNotEmpty);

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['format'], equals('atlas_backup'));
      expect(decoded['version'], equals(2));

      final books = decoded['books'] as List<dynamic>;
      expect(books.length, equals(2));

      final novelEntry = books.cast<Map<String, dynamic>>().firstWhere(
        (b) => b['id'] == 'novel-1',
      );
      expect(novelEntry['itemType'], equals('novel'));
      expect(novelEntry['hasUpdate'], equals(true));
      expect(novelEntry['newChapterCount'], equals(5));

      final chapters = decoded['chapters'] as List<dynamic>;
      expect(chapters.length, equals(1));
      expect(
        (chapters.first as Map<String, dynamic>)['title'],
        equals('Chapter 1: Nightmare Begins'),
      );

      final progress = decoded['readingProgress'] as List<dynamic>;
      expect(progress.length, equals(1));
      expect(
        (progress.first as Map<String, dynamic>)['bookId'],
        equals('novel-1'),
      );
      expect(
        (progress.first as Map<String, dynamic>)['chapterId'],
        equals('novel-1_ch0'),
      );
      expect((progress.first as Map<String, dynamic>)['position'], equals(18));
      expect(
        (progress.first as Map<String, dynamic>)['totalPositions'],
        equals(45),
      );

      final bookmarks = decoded['bookmarks'] as List<dynamic>;
      expect(bookmarks.length, equals(1));
      expect(
        (bookmarks.first as Map<String, dynamic>)['note'],
        equals('Sunny discovers the Fated attribute'),
      );

      final characters = decoded['characters'] as List<dynamic>;
      expect(characters.length, equals(1));
      expect(
        (characters.first as Map<String, dynamic>)['name'],
        equals('Sunny'),
      );

      final words = decoded['dictionaryWords'] as List<dynamic>;
      expect(words.length, equals(1));
      expect(
        (words.first as Map<String, dynamic>)['word'],
        equals('Pragmatic'),
      );

      final annotations = decoded['annotations'] as Map<String, dynamic>;
      expect(annotations.containsKey('novel-1'), isTrue);
    },
  );

  test(
    'restoreBackupJson restores complete state and exact reading progress discoverable via getReadingProgress',
    () async {
      final sampleBackup = jsonEncode({
        'format': 'atlas_backup',
        'version': 2,
        'exportedAt': '2026-09-16T12:00:00.000',
        'books': [
          {
            'id': 'book-lotm',
            'title': 'Lord of Mysteries',
            'author': 'Cuttlefish That Loves Diving',
            'format': 'novel',
            'itemType': 'novel',
            'totalChapters': 1432,
            'filePath': '',
            'status': 'Completed',
            'tags': 'Mystery, Steampunk',
            'createdAt': '2026-01-01T00:00:00.000',
            'updatedAt': '2026-01-01T00:00:00.000',
          },
        ],
        'chapters': [
          {
            'id': 'lotm_ch100',
            'bookId': 'book-lotm',
            'index': 99,
            'title': 'Chapter 100: Clown',
            'contentPath': '/data/lotm/99.txt',
            'wordCount': 2200,
            'pageCount': 7,
            'contentState': 1,
            'version': 1,
          },
        ],
        'readingProgress': [
          {
            'id': 'book-lotm',
            'bookId': 'book-lotm',
            'chapterId': 'lotm_ch100',
            'percentage': 0.65,
            'position': 32,
            'totalPositions': 50,
            'readingTimeSeconds': 12800,
            'isCompleted': false,
            'lastReadAt': '2026-09-15T20:30:00.000',
          },
        ],
        'bookmarks': [
          {
            'id': 'bm-lotm-1',
            'bookId': 'book-lotm',
            'chapterId': 'lotm_ch100',
            'position': 32,
            'note': 'Klein performs as the Clown',
            'createdAt': '2026-09-15T20:30:00.000',
            'updatedAt': '2026-09-15T20:30:00.000',
          },
        ],
        'characters': [
          {
            'id': 'char-klein',
            'bookId': 'book-lotm',
            'name': 'Klein Moretti',
            'role': 'Protagonist',
            'aliases': 'The Fool, Sherlock Moriarty, Gehrman Sparrow',
            'createdAt': '2026-01-01T00:00:00.000',
            'updatedAt': '2026-01-01T00:00:00.000',
          },
        ],
        'dictionaryWords': [
          {
            'id': 'word-beyonder',
            'word': 'Beyonder',
            'definition':
                'An individual possessing supernatural potion powers.',
            'language': 'en',
            'languageLabel': 'English',
            'partOfSpeech': 'noun',
            'fullJson': '{}',
            'savedAt': '2026-09-15T20:30:00.000',
          },
        ],
        'annotations': {
          'book-lotm': {
            'highlights': {
              'lotm_ch100': [
                {
                  'chapterId': 'lotm_ch100',
                  'start': 0,
                  'end': 38,
                  'text': 'The Fool that doesnt belong to this era',
                  'colorValue': 4294961979,
                  'createdAt': '2026-09-15T20:30:00.000',
                },
              ],
            },
            'notes': {},
          },
        },
      });

      final result = await service.restoreBackupJson(sampleBackup);
      expect(result, isA<Success<BackupRestoreSummary>>());

      final summary = (result as Success<BackupRestoreSummary>).value;
      expect(summary.totalBooks, equals(1));
      expect(summary.novelsRestored, equals(1));
      expect(summary.chaptersRestored, equals(1));
      expect(summary.readingProgressRestored, equals(1));
      expect(summary.bookmarksRestored, equals(1));
      expect(summary.charactersRestored, equals(1));
      expect(summary.wordsRestored, equals(1));
      expect(summary.annotationsRestored, equals(1));

      // CRITICAL: Verify database query matches getReadingProgress(bookId)
      final progress = await db.getReadingProgress('book-lotm');
      expect(progress, isNotNull);
      expect(progress!.bookId, equals('book-lotm'));
      expect(progress.chapterId, equals('lotm_ch100'));
      expect(progress.position, equals(32));
      expect(progress.totalPositions, equals(50));
      expect(progress.percentage, equals(0.65));

      // Verify chapters restored
      final chapters = await (db.select(
        db.chapters,
      )..where((c) => c.bookId.equals('book-lotm'))).get();
      expect(chapters.length, equals(1));
      expect(chapters.first.title, equals('Chapter 100: Clown'));

      // Verify characters restored
      final characters = await (db.select(
        db.characters,
      )..where((c) => c.bookId.equals('book-lotm'))).get();
      expect(characters.length, equals(1));
      expect(characters.first.aliases, contains('The Fool'));

      // Verify annotations restored into service
      final savedAnnotations = mockAnnotations.storage['book-lotm'];
      expect(savedAnnotations, isNotNull);
      expect(savedAnnotations!.highlights.containsKey('lotm_ch100'), isTrue);
    },
  );

  test(
    'exportBackupArchive and inspectBackupBytes generate valid inspectable zip package',
    () async {
      // Seed book and progress
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-archive-test',
              title: 'Omniscient Reader Viewpoint',
              author: const Value('Sing Shong'),
              format: 'novel',
              filePath: '',
              totalChapters: 551,
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
              itemType: const Value('novel'),
            ),
          );

      await db
          .into(db.readingProgress)
          .insert(
            ReadingProgressCompanion.insert(
              id: 'book-archive-test',
              bookId: 'book-archive-test',
              chapterId: 'orv_ch50',
              percentage: 0.1,
              position: 12,
              totalPositions: 80,
              lastReadAt: DateTime(2026, 1, 2),
              readingTimeSeconds: 1500,
            ),
          );

      final archiveBytes = await service.exportBackupArchive();
      expect(archiveBytes, isNotEmpty);

      // Inspect archive
      final inspectResult = await service.inspectBackupBytes(archiveBytes);
      expect(inspectResult, isA<Success<BackupManifestSummary>>());

      final manifest = (inspectResult as Success<BackupManifestSummary>).value;
      expect(manifest.format, equals('atlas_archive'));
      expect(manifest.novelsCount, equals(1));
      expect(manifest.booksCount, equals(0));
      expect(manifest.readingProgressCount, equals(1));
    },
  );

  test(
    'restoreBackupBytes handles ZIP archive accurately and updates database',
    () async {
      // Prepare zip archive in memory with backup.json
      final manifestData = {
        'format': 'atlas_backup',
        'version': 2,
        'exportedAt': '2026-09-16T12:00:00.000',
        'books': [
          {
            'id': 'book-zip-1',
            'title': 'The Beginning After The End',
            'author': 'TurtleMe',
            'format': 'novel',
            'itemType': 'novel',
            'totalChapters': 480,
            'filePath': '',
            'createdAt': '2026-01-01T00:00:00.000',
            'updatedAt': '2026-01-01T00:00:00.000',
          },
        ],
        'readingProgress': [
          {
            'id': 'book-zip-1',
            'bookId': 'book-zip-1',
            'chapterId': 'tbate_ch120',
            'percentage': 0.25,
            'position': 15,
            'totalPositions': 60,
            'readingTimeSeconds': 3600,
            'lastReadAt': '2026-09-16T10:00:00.000',
          },
        ],
      };

      final jsonBytes = utf8.encode(jsonEncode(manifestData));
      final archive = Archive();
      archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));
      final zipBytes = ZipEncoder().encode(archive);

      final result = await service.restoreBackupBytes(zipBytes);
      expect(result, isA<Success<BackupRestoreSummary>>());

      final progress = await db.getReadingProgress('book-zip-1');
      expect(progress, isNotNull);
      expect(progress!.chapterId, equals('tbate_ch120'));
      expect(progress.position, equals(15));
    },
  );

  test('cleanRestore true deletes existing library before importing', () async {
    // Seed existing book
    await db
        .into(db.books)
        .insert(
          BooksCompanion.insert(
            id: 'old-book',
            title: 'Old Book To Be Replaced',
            format: 'epub',
            filePath: '',
            totalChapters: 10,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        );

    final sampleBackup = jsonEncode({
      'format': 'atlas_backup',
      'version': 2,
      'exportedAt': '2026-09-16T12:00:00.000',
      'books': [
        {
          'id': 'new-book',
          'title': 'Fresh Restored Book',
          'format': 'epub',
          'itemType': 'book',
          'totalChapters': 25,
          'filePath': '',
          'createdAt': '2026-02-01T00:00:00.000',
          'updatedAt': '2026-02-01T00:00:00.000',
        },
      ],
    });

    final result = await service.restoreBackupJson(
      sampleBackup,
      cleanRestore: true,
    );
    expect(result, isA<Success<BackupRestoreSummary>>());

    final allBooks = await db.select(db.books).get();
    expect(allBooks.length, equals(1));
    expect(allBooks.first.id, equals('new-book'));
  });

  test('restoreBackupJson fails safely on malformed format', () async {
    final invalidBackup = jsonEncode({'format': 'other_app', 'version': 1});
    final result = await service.restoreBackupJson(invalidBackup);
    expect(result, isA<Failure<BackupRestoreSummary>>());
  });

  test('export and cleanRestore tolerate a dropped legacy characters table '
      '(devices upgraded past schema 13)', () async {
    // Simulate an upgraded install: the Story Memory migration (schema 14)
    // dropped the legacy characters table while the drift model still
    // references it. Export must degrade to an empty list instead of
    // crashing ("no such table: characters"), and a clean restore of an
    // old backup containing characters must not abort the transaction.
    await db.customStatement('DROP TABLE characters');

    final exportJson = await service.exportBackupJson();
    final exported = jsonDecode(exportJson) as Map<String, dynamic>;
    expect(exported['characters'], isEmpty);

    final sampleBackup = jsonEncode({
      'format': 'atlas_backup',
      'version': 2,
      'exportedAt': '2026-09-16T12:00:00.000',
      'books': [
        {
          'id': 'book-upgrade',
          'title': 'Upgraded Install Book',
          'format': 'epub',
          'itemType': 'book',
          'totalChapters': 12,
          'filePath': '',
          'createdAt': '2026-01-01T00:00:00.000',
          'updatedAt': '2026-01-01T00:00:00.000',
        },
      ],
      'characters': [
        {
          'id': 'char-legacy',
          'bookId': 'book-upgrade',
          'name': 'Klein Moretti',
          'role': 'Protagonist',
          'createdAt': '2026-01-01T00:00:00.000',
          'updatedAt': '2026-01-01T00:00:00.000',
        },
      ],
    });

    final result = await service.restoreBackupJson(
      sampleBackup,
      cleanRestore: true,
    );
    expect(result, isA<Success<BackupRestoreSummary>>());

    final summary = (result as Success<BackupRestoreSummary>).value;
    expect(summary.totalBooks, equals(1)); // transaction completed
    expect(summary.charactersRestored, equals(0)); // section skipped
  });
}
