import 'dart:io';

import 'package:drift/drift.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/domain/repository_interfaces/library_repository_interface.dart';

final class DriftLibraryRepository implements LibraryRepositoryInterface {
  const DriftLibraryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<List<BookEntity>>> getBooks() async {
    try {
      final rows = await (_db.select(_db.books).join(
        [
          leftOuterJoin(
            _db.readingProgress,
            _db.readingProgress.bookId.equalsExp(_db.books.id),
          ),
        ],
      )).get();

      final books = rows.map((row) {
        final book = row.readTable(_db.books);
        final progress = row.readTableOrNull(_db.readingProgress);
        return BookEntity(
          id: book.id,
          title: book.title,
          author: book.author,
          coverPath: book.coverPath,
          format: book.format,
          totalChapters: book.totalChapters,
          createdAt: book.createdAt,
          updatedAt: book.updatedAt,
          lastOpenedAt: book.lastOpenedAt,
          progress: progress?.percentage,
        );
      }).toList();

      return Success(books);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to load books', e), st);
    }
  }

  @override
  Future<Result<BookEntity>> getBookById(String id) async {
    try {
      final query = _db.select(_db.books)..where((b) => b.id.equals(id));
      final book = await query.getSingle();
      return Success(BookEntity(
        id: book.id,
        title: book.title,
        author: book.author,
        coverPath: book.coverPath,
        format: book.format,
        totalChapters: book.totalChapters,
        createdAt: book.createdAt,
        updatedAt: book.updatedAt,
        lastOpenedAt: book.lastOpenedAt,
      ));
    } catch (e, st) {
      return Failure(DatabaseException('Book not found', e), st);
    }
  }

  @override
  Future<Result<void>> deleteBook(String id) async {
    try {
      final query = _db.select(_db.books)..where((b) => b.id.equals(id));
      final book = await query.getSingleOrNull();

      if (book?.filePath != null) {
        final dir = Directory(book!.filePath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }

      await (_db.delete(_db.readingProgress)..where((p) => p.bookId.equals(id))).go();
      await (_db.delete(_db.chapters)..where((c) => c.bookId.equals(id))).go();
      await (_db.delete(_db.books)..where((b) => b.id.equals(id))).go();

      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to delete book', e), st);
    }
  }
}
