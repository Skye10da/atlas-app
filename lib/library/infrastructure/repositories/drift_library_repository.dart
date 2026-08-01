import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
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
          description: book.description,
          language: book.language,
          tags: _parseTags(book.tags),
          rating: book.rating,
          status: book.status,
          fileSize: book.fileSize,
          filePath: book.filePath,
          sourceName: book.sourceName,
          sourceId: book.sourceId,
          sourceUrl: book.sourceUrl,
          itemType: ContentCategory.fromName(book.itemType),
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
      final rows = await (_db.select(_db.books).join(
        [
          leftOuterJoin(
            _db.readingProgress,
            _db.readingProgress.bookId.equalsExp(_db.books.id),
          ),
        ],
      )..where(_db.books.id.equals(id))).get();

      if (rows.isEmpty) {
        return Failure(NotFoundException('Book $id not found'));
      }

      final row = rows.first;
      final book = row.readTable(_db.books);
      final progress = row.readTableOrNull(_db.readingProgress);

      return Success(BookEntity(
        id: book.id,
        title: book.title,
        author: book.author,
        coverPath: book.coverPath,
        format: book.format,
        totalChapters: book.totalChapters,
        description: book.description,
        language: book.language,
        tags: _parseTags(book.tags),
        rating: book.rating,
        status: book.status,
        fileSize: book.fileSize,
        sourceName: book.sourceName,
        sourceId: book.sourceId,
        sourceUrl: book.sourceUrl,
        itemType: ContentCategory.fromName(book.itemType),
        createdAt: book.createdAt,
        updatedAt: book.updatedAt,
        lastOpenedAt: book.lastOpenedAt,
        progress: progress?.percentage,
      ));
    } catch (e, st) {
      return Failure(DatabaseException('Failed to load book', e), st);
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

  @override
  Future<Result<void>> deleteAllBooks() async {
    try {
      final books = await _db.select(_db.books).get();
      for (final book in books) {
        if (book.filePath.isNotEmpty) {
          final dir = Directory(book.filePath);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        }
      }
      await _db.delete(_db.readingProgress).go();
      await _db.delete(_db.chapters).go();
      await _db.delete(_db.bookmarks).go();
      await _db.delete(_db.books).go();
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to delete all books', e), st);
    }
  }

  @override
  Future<Result<void>> updateBook(String id, {String? title, String? author}) async {
    try {
      await (_db.update(_db.books)..where((b) => b.id.equals(id))).write(
        BooksCompanion(
          title: title != null ? Value(title) : const Value.absent(),
          author: author != null ? Value(author) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to update book', e), st);
    }
  }

  @override
  Future<Result<void>> markAsOpened(String id) async {
    try {
      await (_db.update(_db.books)..where((b) => b.id.equals(id))).write(
        BooksCompanion(
          lastOpenedAt: Value(DateTime.now()),
        ),
      );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to mark book as opened', e), st);
    }
  }

  List<String> _parseTags(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) return parsed.whereType<String>().toList();
    } catch (_) {}
    return raw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }
}
