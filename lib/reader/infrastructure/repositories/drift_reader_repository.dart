import 'dart:io';

import 'package:drift/drift.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/reader_repository_interface.dart';

final class DriftReaderRepository implements ReaderRepositoryInterface {
  const DriftReaderRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<List<ChapterEntity>>> getChapters(String bookId) async {
    try {
      final rows = await (_db.select(_db.chapters)
        ..where((c) => c.bookId.equals(bookId))
        ..orderBy([(c) => OrderingTerm.asc(c.index)])).get();

      final chapters = rows
          .map((c) => ChapterEntity(
                id: c.id,
                bookId: c.bookId,
                index: c.index,
                title: c.title,
                contentPath: c.contentPath,
                wordCount: c.wordCount,
                pageCount: c.pageCount,
              ))
          .toList();

      return Success(chapters);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to load chapters', e), st);
    }
  }

  @override
  Future<Result<String>> getChapterContent(String contentPath) async {
    try {
      final file = File(contentPath);
      if (!await file.exists()) {
        return const Success('# Chapter Content\n\nThe content file was not found.');
      }
      final content = await file.readAsString();
      return Success(content);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to read chapter', e), st);
    }
  }

  @override
  Future<Result<void>> saveProgress({
    required String userId,
    required String bookId,
    required String chapterId,
    required double percentage,
    required int position,
    required int totalPositions,
  }) async {
    try {
      await _db.into(_db.readingProgress).insertOnConflictUpdate(
            ReadingProgressCompanion(
              id: Value(bookId),
              bookId: Value(bookId),
              chapterId: Value(chapterId),
              percentage: Value(percentage),
              position: Value(position),
              totalPositions: Value(totalPositions),
              lastReadAt: Value(DateTime.now()),
              readingTimeSeconds: const Value(0),
            ),
          );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to save progress', e), st);
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
  Future<Result<List<BookmarkEntity>>> getBookmarks(String bookId) async {
    try {
      final rows = await (_db.select(_db.bookmarks)
        ..where((b) => b.bookId.equals(bookId))
        ..orderBy([(b) => OrderingTerm.desc(b.createdAt)])).get();
      return Success(rows.map(_toBookmarkEntity).toList());
    } catch (e, st) {
      return Failure(DatabaseException('Failed to load bookmarks', e), st);
    }
  }

  @override
  Future<Result<void>> addBookmark(BookmarkEntity bookmark) async {
    try {
      await _db.into(_db.bookmarks).insert(
            BookmarksCompanion(
              id: Value(bookmark.id),
              bookId: Value(bookmark.bookId),
              chapterId: Value(bookmark.chapterId),
              position: Value(bookmark.position),
              note: Value(bookmark.note),
              color: Value(bookmark.color),
              createdAt: Value(bookmark.createdAt),
              updatedAt: Value(bookmark.updatedAt),
            ),
          );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to add bookmark', e), st);
    }
  }

  @override
  Future<Result<void>> removeBookmark(String bookmarkId) async {
    try {
      await (_db.delete(_db.bookmarks)
        ..where((b) => b.id.equals(bookmarkId))).go();
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to remove bookmark', e), st);
    }
  }

  BookmarkEntity _toBookmarkEntity(Bookmark b) => BookmarkEntity(
        id: b.id,
        bookId: b.bookId,
        chapterId: b.chapterId,
        position: b.position,
        note: b.note,
        color: b.color,
        createdAt: b.createdAt,
        updatedAt: b.updatedAt,
      );
}
