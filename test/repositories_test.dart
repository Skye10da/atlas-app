// ignore_for_file: avoid_dynamic_calls

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/domain/entities/reading_progress_snapshot.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';

AppDatabase _createDb() => AppDatabase.memory();

BooksCompanion _book({
  required String id,
  String title = 'Test Book',
  String? author,
  String format = 'epub',
  int totalChapters = 10,
  DateTime? createdAt,
  DateTime? updatedAt,
}) =>
    BooksCompanion(
      id: Value(id),
      title: Value(title),
      author: author != null ? Value(author) : const Value.absent(),
      format: Value(format),
      filePath: const Value('/fake/path'),
      totalChapters: Value(totalChapters),
      createdAt: Value(createdAt ?? DateTime(2025, 1, 1)),
      updatedAt: Value(updatedAt ?? DateTime(2025, 1, 1)),
    );

ChaptersCompanion _chapter({
  required String id,
  required String bookId,
  int index = 0,
  String title = 'Chapter 1',
  int wordCount = 100,
}) =>
    ChaptersCompanion(
      id: Value(id),
      bookId: Value(bookId),
      index: Value(index),
      title: Value(title),
      contentPath: Value('/fake/$id.html'),
      wordCount: Value(wordCount),
      pageCount: const Value(1),
      createdAt: Value(DateTime(2025, 1, 1)),
    );

void main() {
  group('DriftLibraryRepository', () {
    late AppDatabase db;
    late DriftLibraryRepository repo;

    setUp(() async {
      db = _createDb();
      repo = DriftLibraryRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    group('getBooks', () {
      test('returns empty list when no books', () async {
        final result = await repo.getBooks();
        expect(result, isA<Success<List<BookEntity>>>());
        expect((result as Success).value, isEmpty);
      });

      test('returns all books with null progress', () async {
        await db.into(db.books).insert(_book(id: 'b1', title: 'Alpha'));
        await db.into(db.books).insert(_book(id: 'b2', title: 'Beta'));

        final result = await repo.getBooks();
        expect(result, isA<Success<List<BookEntity>>>());
        final books = (result as Success).value;
        expect(books.length, 2);
        expect(books[0].title, 'Alpha');
        expect(books[1].title, 'Beta');
        expect(books[0].progress, isNull);
      });

      test('includes progress percentage when progress exists', () async {
        await db.into(db.books).insert(_book(id: 'b1'));
        await db.into(db.readingProgress).insert(ReadingProgressCompanion(
              id: const Value('b1'),
              bookId: const Value('b1'),
              chapterId: const Value('ch1'),
              percentage: const Value(42.5),
              position: const Value(0),
              totalPositions: const Value(0),
              lastReadAt: Value(DateTime.now()),
              readingTimeSeconds: const Value(0),
            ));

        final result = await repo.getBooks();
        final books = (result as Success).value;
        expect(books[0].progress, 42.5);
      });
    });

    group('watchBooks', () {
      test('re-emits when a book is added and when progress changes', () async {
        final events = <Result<List<BookEntity>>>[];
        final sub = repo.watchBooks().listen(events.add);

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(events, hasLength(1));
        expect((events.first as Success).value, isEmpty);

        await db.into(db.books).insert(_book(id: 'b1', title: 'Alpha'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(events, hasLength(2));
        expect((events.last as Success).value, hasLength(1));

        await db.into(db.readingProgress).insert(ReadingProgressCompanion(
              id: const Value('b1'),
              bookId: const Value('b1'),
              chapterId: const Value('ch1'),
              percentage: const Value(66.5),
              position: const Value(0),
              totalPositions: const Value(0),
              lastReadAt: Value(DateTime.now()),
              readingTimeSeconds: const Value(0),
            ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect((events.last as Success).value.single.progress, 66.5);

        await sub.cancel();
      });
    });

    group('getBookById', () {
      test('returns book when it exists', () async {
        await db.into(db.books).insert(
            _book(id: 'b1', title: 'Unique Book', author: 'Author A'));

        final result = await repo.getBookById('b1');
        expect(result, isA<Success<BookEntity>>());
        final book = (result as Success).value;
        expect(book.title, 'Unique Book');
        expect(book.author, 'Author A');
      });

      test('returns Failure when book does not exist', () async {
        final result = await repo.getBookById('nonexistent');
        expect(result, isA<Failure<BookEntity>>());
        expect((result as Failure).error, isA<NotFoundException>());
      });

      test('returns book with progress', () async {
        await db.into(db.books).insert(_book(id: 'b1'));
        await db.into(db.readingProgress).insert(ReadingProgressCompanion(
              id: const Value('b1'),
              bookId: const Value('b1'),
              chapterId: const Value('ch1'),
              percentage: const Value(75.0),
              position: const Value(0),
              totalPositions: const Value(0),
              lastReadAt: Value(DateTime.now()),
              readingTimeSeconds: const Value(0),
            ));

        final result = await repo.getBookById('b1');
        final book = (result as Success).value;
        expect(book.progress, 75.0);
      });

      test('preserves format and filePath so readers can route PDFs', () async {
        await db.into(db.books).insert(_book(id: 'pdf', format: 'pdf'));

        final result = await repo.getBookById('pdf');
        final book = (result as Success).value;
        expect(book.format, 'pdf');
        expect(book.filePath, '/fake/path');
      });
    });

    group('deleteBook', () {
      test('deletes book and related data', () async {
        await db.into(db.books).insert(_book(id: 'b1'));
        await db.into(db.chapters).insert(_chapter(id: 'ch1', bookId: 'b1'));
        await db.into(db.readingProgress).insert(ReadingProgressCompanion(
              id: const Value('b1'),
              bookId: const Value('b1'),
              chapterId: const Value('ch1'),
              percentage: const Value(50),
              position: const Value(0),
              totalPositions: const Value(0),
              lastReadAt: Value(DateTime.now()),
              readingTimeSeconds: const Value(0),
            ));

        final result = await repo.deleteBook('b1');
        expect(result, isA<Success<void>>());

        final book = await (db.select(db.books)..where((b) => b.id.equals('b1')))
            .getSingleOrNull();
        expect(book, isNull);
        final chapters = await (db.select(db.chapters)..where((c) => c.bookId.equals('b1')))
            .get();
        expect(chapters, isEmpty);
        final progress = await (db.select(db.readingProgress)
              ..where((p) => p.bookId.equals('b1')))
            .get();
        expect(progress, isEmpty);
      });

      test('returns success for non-existent book', () async {
        final result = await repo.deleteBook('nonexistent');
        expect(result, isA<Success<void>>());
      });
    });

    group('updateBook', () {
      test('updates title and author', () async {
        await db.into(db.books).insert(_book(id: 'b1', title: 'Old Title'));

        final result = await repo.updateBook('b1',
            title: 'New Title', author: 'New Author');
        expect(result, isA<Success<void>>());

        final book = await (db.select(db.books)..where((b) => b.id.equals('b1')))
            .getSingle();
        expect(book.title, 'New Title');
        expect(book.author, 'New Author');
      });

      test('updates only title when author is null', () async {
        await db.into(db.books)
            .insert(_book(id: 'b1', title: 'Old Title', author: 'Original Author'));

        final result = await repo.updateBook('b1', title: 'New Title');
        expect(result, isA<Success<void>>());

        final book = await (db.select(db.books)..where((b) => b.id.equals('b1')))
            .getSingle();
        expect(book.title, 'New Title');
        expect(book.author, 'Original Author');
      });
    });
  });

  group('DriftReaderRepository', () {
    late AppDatabase db;
    late DriftReaderRepository repo;

    setUp(() async {
      db = _createDb();
      repo = DriftReaderRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    group('getChapters', () {
      test('returns empty list when book has no chapters', () async {
        final result = await repo.getChapters('b1');
        expect(result, isA<Success<List<ChapterEntity>>>());
        expect((result as Success).value, isEmpty);
      });

      test('returns chapters ordered by index', () async {
        await db.into(db.books).insert(_book(id: 'b1'));
        await db.into(db.chapters)
            .insert(_chapter(id: 'ch2', bookId: 'b1', index: 1, title: 'Second'));
        await db.into(db.chapters)
            .insert(_chapter(id: 'ch1', bookId: 'b1', index: 0, title: 'First'));
        await db.into(db.chapters)
            .insert(_chapter(id: 'ch3', bookId: 'b1', index: 2, title: 'Third'));

        final result = await repo.getChapters('b1');
        final chapters = (result as Success).value;
        expect(chapters.map((c) => c.title), ['First', 'Second', 'Third']);
      });
    });

    group('saveProgress', () {
      test('inserts new progress record', () async {
        final result = await repo.saveProgress(
          userId: 'local',
          bookId: 'b1',
          chapterId: 'ch1',
          percentage: 33.3,
          position: 0,
          totalPositions: 0,
        );
        expect(result, isA<Success<void>>());

        final progress = await db.getReadingProgress('b1');
        expect(progress, isNotNull);
        expect(progress!.percentage, closeTo(33.3, 0.01));
      });

      test('updates existing progress record (upsert)', () async {
        await db.into(db.readingProgress).insert(ReadingProgressCompanion(
              id: const Value('b1'),
              bookId: const Value('b1'),
              chapterId: const Value('ch1'),
              percentage: const Value(10),
              position: const Value(0),
              totalPositions: const Value(0),
              lastReadAt: Value(DateTime(2025, 1, 1)),
              readingTimeSeconds: const Value(0),
            ));

        await repo.saveProgress(
          userId: 'local',
          bookId: 'b1',
          chapterId: 'ch1',
          percentage: 90.0,
          position: 0,
          totalPositions: 0,
        );

        final progress = await db.getReadingProgress('b1');
        expect(progress!.percentage, closeTo(90.0, 0.01));
      });

      test('persists exact-position resume fields read back via getReadingProgress',
          () async {
        await repo.saveProgress(
          userId: 'local',
          bookId: 'b1',
          chapterId: 'ch7',
          percentage: 55.5,
          position: 128,
          totalPositions: 240,
        );

        final result = await repo.getReadingProgress('b1');
        expect(result, isA<Success<ReadingProgressSnapshot?>>());
        final snapshot = (result as Success).value;
        expect(snapshot, isNotNull);
        expect(snapshot!.bookId, 'b1');
        expect(snapshot.chapterId, 'ch7');
        expect(snapshot.percentage, closeTo(55.5, 0.01));
        expect(snapshot.position, 128);
        expect(snapshot.totalPositions, 240);
      });

      test('getReadingProgress returns null snapshot for unknown book', () async {
        final result = await repo.getReadingProgress('missing');
        expect(result, isA<Success<ReadingProgressSnapshot?>>());
        expect((result as Success).value, isNull);
      });
    });

    group('bookmarks', () {
      test('add and list bookmarks for a book', () async {
        final bookmark = BookmarkEntity(
          id: 'bm1',
          bookId: 'b1',
          chapterId: 'ch1',
          position: 42,
          note: 'Important passage',
          color: null,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        );

        final addResult = await repo.addBookmark(bookmark);
        expect(addResult, isA<Success<void>>());

        final listResult = await repo.getBookmarks('b1');
        final bookmarks = (listResult as Success).value;
        expect(bookmarks.length, 1);
        expect(bookmarks[0].note, 'Important passage');
      });

      test('remove bookmark', () async {
        final bookmark = BookmarkEntity(
          id: 'bm1',
          bookId: 'b1',
          chapterId: 'ch1',
          position: 42,
          note: null,
          color: null,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        );

        await repo.addBookmark(bookmark);
        final removeResult = await repo.removeBookmark('bm1');
        expect(removeResult, isA<Success<void>>());

        final listResult = await repo.getBookmarks('b1');
        expect((listResult as Success).value, isEmpty);
      });

      test('getAllBookmarks returns bookmarks across books', () async {
        await repo.addBookmark(BookmarkEntity(
          id: 'bm1',
          bookId: 'b1',
          chapterId: 'ch1',
          position: 1,
          note: null,
          color: null,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ));
        await repo.addBookmark(BookmarkEntity(
          id: 'bm2',
          bookId: 'b2',
          chapterId: 'ch1',
          position: 2,
          note: null,
          color: null,
          createdAt: DateTime(2025, 1, 2),
          updatedAt: DateTime(2025, 1, 2),
        ));

        final result = await repo.getAllBookmarks();
        final bookmarks = (result as Success).value;
        expect(bookmarks.length, 2);
      });
    });

    group('getBookById', () {
      test('returns book when it exists', () async {
        await db.into(db.books)
            .insert(_book(id: 'b1', title: 'Reader Book', author: 'Test Author'));

        final result = await repo.getBookById('b1');
        expect(result, isA<Success<BookEntity>>());
        final book = (result as Success).value;
        expect(book.title, 'Reader Book');
      });
    });
  });
}
