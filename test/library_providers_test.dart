// ignore_for_file: avoid_dynamic_calls

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';

BooksCompanion _book({
  required String id,
  String title = 'Test Book',
  String? author,
  int totalChapters = 10,
}) => BooksCompanion(
  id: Value(id),
  title: Value(title),
  author: author != null ? Value(author) : const Value.absent(),
  format: const Value('epub'),
  filePath: const Value('/fake/path'),
  totalChapters: Value(totalChapters),
  createdAt: Value(DateTime(2025, 1, 1)),
  updatedAt: Value(DateTime(2025, 1, 1)),
);

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await Future<void>.delayed(const Duration(milliseconds: 50));
}

void main() {
  group('libraryBooksProvider reactivity', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.memory();
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() {
        container.dispose();
        db.close();
      });
    });

    List<BookEntity> booksFrom(AsyncValue<Result<List<BookEntity>>> async) {
      final result = async.valueOrNull;
      return result is Success<List<BookEntity>>
          ? result.value
          : <BookEntity>[];
    }

    test('re-emits when a book is inserted (import)', () async {
      final sub = container.listen(libraryBooksProvider, (_, _) {});
      await _settle();
      expect(booksFrom(container.read(libraryBooksProvider)), isEmpty);

      await db.into(db.books).insert(_book(id: 'b1', title: 'Imported'));
      await _settle();

      final books = booksFrom(container.read(libraryBooksProvider));
      expect(books, hasLength(1));
      expect(books.single.title, 'Imported');
      sub.close();
    });

    test('re-emits when the reader saves progress', () async {
      final sub = container.listen(libraryBooksProvider, (_, _) {});
      await db.into(db.books).insert(_book(id: 'b1'));
      await _settle();
      expect(
        booksFrom(container.read(libraryBooksProvider)).single.progress,
        isNull,
      );

      final readerRepo = DriftReaderRepository(db);
      await readerRepo.saveProgress(
        userId: 'local',
        bookId: 'b1',
        chapterId: 'ch3',
        percentage: 37.5,
        position: 20,
        totalPositions: 100,
      );
      await _settle();

      final books = booksFrom(container.read(libraryBooksProvider));
      expect(books.single.progress, 37.5);
      sub.close();
    });

    test('re-emits when progress advances further (upsert)', () async {
      final sub = container.listen(libraryBooksProvider, (_, _) {});
      await db.into(db.books).insert(_book(id: 'b1'));
      final readerRepo = DriftReaderRepository(db);

      await readerRepo.saveProgress(
        userId: 'local',
        bookId: 'b1',
        chapterId: 'ch1',
        percentage: 10,
        position: 1,
        totalPositions: 100,
      );
      await _settle();
      expect(
        booksFrom(container.read(libraryBooksProvider)).single.progress,
        10,
      );

      await readerRepo.saveProgress(
        userId: 'local',
        bookId: 'b1',
        chapterId: 'ch9',
        percentage: 90,
        position: 90,
        totalPositions: 100,
      );
      await _settle();

      final books = booksFrom(container.read(libraryBooksProvider));
      expect(books.single.progress, 90);
      expect(books.single.lastOpenedAt, isNull);
      sub.close();
    });
  });
}
