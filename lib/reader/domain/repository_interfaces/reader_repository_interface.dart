import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/reading_progress_snapshot.dart';

abstract interface class ReaderRepositoryInterface {
  Future<Result<List<ChapterEntity>>> getChapters(String bookId);
  Future<Result<String>> getChapterContent(String contentPath);
  Future<Result<void>> saveProgress({
    required String userId,
    required String bookId,
    required String chapterId,
    required double percentage,
    required int position,
    required int totalPositions,
  });
  Future<Result<ReadingProgressSnapshot?>> getReadingProgress(String bookId);
  Future<Result<BookEntity>> getBookById(String id);
  Future<Result<void>> updateChapterContent(
    String bookId,
    int chapterIndex,
    String content,
  );

  /// Drops every downloaded chapter of [bookId] back to the "not downloaded"
  /// state: the on-disk content (and any superseded versions) is removed so a
  /// subsequent read re-fetches it. Used when a WTR-Lab novel's translation
  /// service changes, since stored text was fetched under the old service.
  Future<Result<void>> resetChapterContent(String bookId);

  Future<Result<List<BookmarkEntity>>> getBookmarks(String bookId);
  Future<Result<void>> addBookmark(BookmarkEntity bookmark);
  Future<Result<void>> removeBookmark(String bookmarkId);
  Future<Result<List<BookmarkEntity>>> getAllBookmarks();
}
