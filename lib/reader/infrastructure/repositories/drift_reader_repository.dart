import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/content_engine/models/content_hasher.dart';
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

      final book = await (_db.select(_db.books)..where((b) => b.id.equals(bookId))).getSingleOrNull();
      final totalChapters = book?.totalChapters ?? rows.length;

      final chapters = rows
          .map((c) => ChapterEntity(
                id: c.id,
                bookId: c.bookId,
                index: c.index,
                title: c.title,
                contentPath: c.contentPath,
                wordCount: c.wordCount,
                pageCount: c.pageCount,
                contentState: c.contentState,
                totalChapters: totalChapters,
                version: c.version,
                checksum: c.checksum,
                previousVersionRef: c.previousVersionRef,
              ))
          .toList();

      return Success(chapters);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to load chapters', e), st);
    }
  }

  @override
  Future<Result<void>> updateChapterContent(String bookId, int chapterIndex, String content) async {
    try {
      final row = await (_db.select(_db.chapters)
        ..where((c) => c.bookId.equals(bookId))
        ..where((c) => c.index.equals(chapterIndex))).getSingle();

      const hasher = ContentHasher();
      final newChecksum = hasher.sha256Of(content);
      final file = File(row.contentPath);
      var nextVersion = row.version;
      var previousVersionRef = row.previousVersionRef;

      final changed = row.checksum == null || row.checksum != newChecksum;
      if (changed) {
        if (row.checksum != null) {
          // Preserve the old version rather than silently overwriting.
          final archive = File('${row.contentPath}.v${row.version}');
          if (file.existsSync() && !archive.existsSync()) {
            await file.copy(archive.path);
          }
          nextVersion = row.version + 1;
          previousVersionRef = row.id;
        }
        await file.writeAsString(content);
      }

      await (_db.update(_db.chapters)
        ..where((c) => c.id.equals(row.id)))
        .write(ChaptersCompanion(
          contentState: Value(ContentState.availableOffline.index),
          version: Value(nextVersion),
          checksum: Value(newChecksum),
          previousVersionRef: Value(previousVersionRef),
        ));

      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to update chapter content', e), st);
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
  Future<Result<List<BookmarkEntity>>> getAllBookmarks() async {
    try {
      final rows = await (_db.select(_db.bookmarks)
        ..orderBy([(b) => OrderingTerm.desc(b.createdAt)])).get();
      return Success(rows.map(_toBookmarkEntity).toList());
    } catch (e, st) {
      return Failure(DatabaseException('Failed to load all bookmarks', e), st);
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
              note: bookmark.note != null ? Value(bookmark.note) : const Value.absent(),
              color: bookmark.color != null ? Value(bookmark.color) : const Value.absent(),
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
      await (_db.delete(_db.bookmarks)..where((b) => b.id.equals(bookmarkId))).go();
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to remove bookmark', e), st);
    }
  }

  BookmarkEntity _toBookmarkEntity(Bookmark row) {
    return BookmarkEntity(
      id: row.id,
      bookId: row.bookId,
      chapterId: row.chapterId,
      position: row.position,
      note: row.note,
      color: row.color,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
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
