import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/domain/repository_interfaces/library_repository_interface.dart';

final class DriftLibraryRepository implements LibraryRepositoryInterface {
  const DriftLibraryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<List<BookEntity>>> getBooks() async {
    try {
      final rows = await _booksQuery().get();
      return Success(rows.map(_toBookEntity).toList());
    } catch (e, st) {
      return Failure(DatabaseException('Failed to load books', e), st);
    }
  }

  @override
  Stream<Result<List<BookEntity>>> watchBooks() {
    return _booksQuery().watch().map((rows) {
      try {
        return Success<List<BookEntity>>(rows.map(_toBookEntity).toList());
      } catch (e, st) {
        return Failure<List<BookEntity>>(
          DatabaseException('Failed to load books', e),
          st,
        );
      }
    });
  }

  JoinedSelectStatement<HasResultSet, dynamic> _booksQuery() {
    return _db.select(_db.books).join([
      leftOuterJoin(
        _db.readingProgress,
        _db.readingProgress.bookId.equalsExp(_db.books.id),
      ),
    ]);
  }

  BookEntity _toBookEntity(TypedResult row) {
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
      updateTrackingEnabled: book.updateTrackingEnabled,
      lastCheckedAt: book.lastCheckedAt,
      newChapterCount: book.newChapterCount,
      hasUpdate: book.hasUpdate,
    );
  }

  @override
  Future<Result<BookEntity>> getBookById(String id) async {
    try {
      final rows = await (_db.select(_db.books).join([
        leftOuterJoin(
          _db.readingProgress,
          _db.readingProgress.bookId.equalsExp(_db.books.id),
        ),
      ])..where(_db.books.id.equals(id))).get();

      if (rows.isEmpty) {
        return Failure(NotFoundException('Book $id not found'));
      }

      final row = rows.first;
      final book = row.readTable(_db.books);
      final progress = row.readTableOrNull(_db.readingProgress);

      return Success(
        BookEntity(
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
          updateTrackingEnabled: book.updateTrackingEnabled,
          lastCheckedAt: book.lastCheckedAt,
          newChapterCount: book.newChapterCount,
          hasUpdate: book.hasUpdate,
        ),
      );
    } catch (e, st) {
      return Failure(DatabaseException('Failed to load book', e), st);
    }
  }

  @override
  Stream<Result<BookEntity>> watchBookById(String id) {
    final query = _db.select(_db.books).join([
      leftOuterJoin(
        _db.readingProgress,
        _db.readingProgress.bookId.equalsExp(_db.books.id),
      ),
    ])..where(_db.books.id.equals(id));

    return query.watch().map((rows) {
      if (rows.isEmpty) {
        return Failure<BookEntity>(NotFoundException('Book $id not found'));
      }
      try {
        return Success<BookEntity>(_toBookEntity(rows.first));
      } catch (e, st) {
        return Failure<BookEntity>(DatabaseException('Failed to load book', e), st);
      }
    });
  }

  @override
  Future<Result<void>> deleteBook(String id) async {
    try {
      final query = _db.select(_db.books)..where((b) => b.id.equals(id));
      final book = await query.getSingleOrNull();

      // DB rows go first: a locked/unreadable book directory (e.g. a file
      // still held open by the reader) must not leave a phantom book behind.
      await _db.transaction(() async {
        await (_db.delete(_db.readingProgress)..where((p) => p.bookId.equals(id))).go();
        await (_db.delete(_db.chapters)..where((c) => c.bookId.equals(id))).go();
        await (_db.delete(_db.bookmarks)..where((b) => b.bookId.equals(id))).go();
        // Legacy `characters` table: the schema-14 Story Memory migration
        // dropped it from pre-14 databases (fresh installs still recreate
        // it via createAll, and drift codegen cannot be regenerated in this
        // environment). Guard the delete so its absence doesn't abort the
        // whole book deletion (SqliteException "no such table").
        try {
          await _db.customStatement(
            'DELETE FROM characters WHERE book_id = ?',
            [id],
          );
        } catch (_) {}
        await (_db.delete(_db.books)..where((b) => b.id.equals(id))).go();
      });

      // Best-effort content-file cleanup.
      if (book?.filePath != null && book!.filePath.isNotEmpty) {
        final dir = Directory(book.filePath);
        if (await dir.exists()) {
          try {
            await dir.delete(recursive: true);
          } catch (e) {
            AppLogger.warning(
              'Removed book "$book.title" from the library but could not '
              'delete its content directory (${dir.path}): $e',
            );
          }
        }
      }

      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to delete book', e), st);
    }
  }

  @override
  Future<Result<void>> deleteBooks(List<String> ids) async {
    if (ids.isEmpty) return const Success(null);
    try {
      final query = _db.select(_db.books)..where((b) => b.id.isIn(ids));
      final books = await query.get();

      await _db.transaction(() async {
        await (_db.delete(_db.readingProgress)..where((p) => p.bookId.isIn(ids))).go();
        await (_db.delete(_db.chapters)..where((c) => c.bookId.isIn(ids))).go();
        await (_db.delete(_db.bookmarks)..where((b) => b.bookId.isIn(ids))).go();
        try {
          await _db.customStatement(
            'DELETE FROM characters WHERE book_id IN (${List.filled(ids.length, '?').join(',')})',
            ids,
          );
        } catch (_) {}
        await (_db.delete(_db.books)..where((b) => b.id.isIn(ids))).go();
      });

      // Best-effort content-file cleanup after the rows are gone.
      for (final book in books) {
        if (book.filePath.isNotEmpty) {
          final dir = Directory(book.filePath);
          if (await dir.exists()) {
            try {
              await dir.delete(recursive: true);
            } catch (e) {
              AppLogger.warning(
                'Removed "${book.title}" from the library but could not '
                'delete its content directory (${dir.path}): $e',
              );
            }
          }
        }
      }

      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to delete selected books', e), st);
    }
  }
  @override
  Future<Result<void>> deleteAllBooks() async {
    try {
      final books = await _db.select(_db.books).get();
      await _db.transaction(() async {
        await _db.delete(_db.readingProgress).go();
        await _db.delete(_db.chapters).go();
        await _db.delete(_db.bookmarks).go();
        try {
          await _db.customStatement('DELETE FROM characters');
        } catch (_) {}
        await _db.delete(_db.books).go();
      });
      for (final book in books) {
        if (book.filePath.isNotEmpty) {
          final dir = Directory(book.filePath);
          if (await dir.exists()) {
            try {
              await dir.delete(recursive: true);
            } catch (e) {
              AppLogger.warning(
                'Removed "${book.title}" from the library but could not '
                'delete its content directory (${dir.path}): $e',
              );
            }
          }
        }
      }
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to delete all books', e), st);
    }
  }

  @override
  Future<Result<void>> updateBook(
    String id, {
    String? title,
    String? author,
  }) async {
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
        BooksCompanion(lastOpenedAt: Value(DateTime.now())),
      );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to mark book as opened', e), st);
    }
  }

  @override
  Future<Result<void>> setUpdateTracking(String id, bool enabled) async {
    try {
      await (_db.update(_db.books)..where((b) => b.id.equals(id))).write(
        BooksCompanion(updateTrackingEnabled: Value(enabled)),
      );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to update tracking', e), st);
    }
  }

  @override
  Future<Result<void>> clearUpdateFlag(String id) async {
    try {
      await (_db.update(_db.books)..where((b) => b.id.equals(id))).write(
        const BooksCompanion(
          hasUpdate: Value(false),
          newChapterCount: Value(0),
        ),
      );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to clear update flag', e), st);
    }
  }

  List<String> _parseTags(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) return parsed.whereType<String>().toList();
    } catch (_) {}
    return raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }
}
