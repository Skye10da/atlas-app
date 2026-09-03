import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/application/book_search_service.dart';
import 'package:atlas_app/reader/domain/entities/book_search_result.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/reading_progress_snapshot.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/reader_repository_interface.dart';

class FakeReaderRepository implements ReaderRepositoryInterface {
  final Map<String, List<ChapterEntity>> chapters = {};
  final Map<String, String> contents = {};

  @override
  Future<Result<List<ChapterEntity>>> getChapters(String bookId) async {
    return Success(chapters[bookId] ?? []);
  }

  @override
  Stream<Result<List<ChapterEntity>>> watchChapters(String bookId) {
    return Stream.value(Success(chapters[bookId] ?? []));
  }

  @override
  Future<Result<String>> getChapterContent(String contentPath) async {
    final text = contents[contentPath];
    if (text != null) return Success(text);
    return const Failure(ValidationException('Not found'));
  }

  @override
  Future<Result<BookEntity>> getBookById(String id) async =>
      throw UnimplementedError();

  @override
  Future<Result<List<BookmarkEntity>>> getBookmarks(String bookId) async =>
      const Success([]);

  @override
  Future<Result<List<BookmarkEntity>>> getAllBookmarks() async =>
      const Success([]);

  @override
  Future<Result<void>> addBookmark(BookmarkEntity bookmark) async =>
      const Success(null);

  @override
  Future<Result<void>> removeBookmark(String bookmarkId) async =>
      const Success(null);

  @override
  Future<Result<ReadingProgressSnapshot?>> getReadingProgress(
    String bookId,
  ) async => const Success(null);

  @override
  Future<Result<void>> resetChapterContent(String bookId) async =>
      const Success(null);

  @override
  Future<Result<void>> saveProgress({
    required String userId,
    required String bookId,
    required String chapterId,
    required double percentage,
    required int position,
    required int totalPositions,
  }) async => const Success(null);

  @override
  Future<Result<void>> updateChapterContent(
    String bookId,
    int chapterIndex,
    String content,
  ) async => const Success(null);
}

void main() {
  late FakeReaderRepository fakeRepo;
  late BookSearchService searchService;

  setUp(() {
    fakeRepo = FakeReaderRepository();
    searchService = BookSearchService(fakeRepo);
  });

  group('BookSearchService', () {
    test('returns empty results for empty query', () async {
      final result = await searchService.searchBook(bookId: 'b1', query: '');
      expect(result, isA<Success>());
      expect((result as Success).value, isEmpty);
    });

    test('finds keyword occurrences and creates context snippets', () async {
      fakeRepo.chapters['b1'] = const [
        ChapterEntity(
          id: 'ch1',
          bookId: 'b1',
          index: 0,
          title: 'Chapter 1',
          contentPath: 'virtual/ch1.txt',
        ),
        ChapterEntity(
          id: 'ch2',
          bookId: 'b1',
          index: 1,
          title: 'Chapter 2',
          contentPath: 'virtual/ch2.txt',
        ),
      ];

      fakeRepo.contents['virtual/ch1.txt'] =
          'It was a dark and stormy night. The dragon slumbered in the deep mountain cave.';
      fakeRepo.contents['virtual/ch2.txt'] =
          'The brave warrior approached the dragon with a glowing sword of fire.';

      final result = await searchService.searchBook(bookId: 'b1', query: 'dragon');
      expect(result, isA<Success<List<BookSearchResult>>>());
      final matches = (result as Success<List<BookSearchResult>>).value;
      expect(matches.length, 2);

      expect(matches[0].chapterTitle, 'Chapter 1');
      expect(matches[0].chapterIndex, 0);
      expect(matches[0].snippet, contains('dragon'));

      expect(matches[1].chapterTitle, 'Chapter 2');
      expect(matches[1].chapterIndex, 1);
      expect(matches[1].snippet, contains('dragon'));
    });
  });
}
