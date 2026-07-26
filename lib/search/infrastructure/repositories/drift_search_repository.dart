import 'package:drift/drift.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/search/domain/entities/search_result_entity.dart';
import 'package:atlas_app/search/domain/repository_interfaces/search_repository_interface.dart';

final class DriftSearchRepository implements SearchRepositoryInterface {
  const DriftSearchRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<List<SearchResultEntity>>> search(String query) async {
    try {
      final pattern = '%$query%';
      final results = <SearchResultEntity>[];

      final books = await (_db.select(_db.books).join(
        [
          leftOuterJoin(
            _db.readingProgress,
            _db.readingProgress.bookId.equalsExp(_db.books.id),
          ),
        ],
      )..where(_db.books.title.like(pattern) | _db.books.author.like(pattern))).get();

      for (final row in books) {
        final book = row.readTable(_db.books);
        results.add(SearchResultEntity(
          kind: SearchResultKind.book,
          bookId: book.id,
          title: book.title,
          bookTitle: book.title,
          author: book.author,
          coverPath: book.coverPath,
          totalChapters: book.totalChapters,
        ));
      }

      final chapters = await (_db.select(_db.chapters).join(
        [
          innerJoin(
            _db.books,
            _db.books.id.equalsExp(_db.chapters.bookId),
          ),
        ],
      )..where(_db.chapters.title.like(pattern))).get();

      for (final row in chapters) {
        final chapter = row.readTable(_db.chapters);
        final book = row.readTable(_db.books);
        results.add(SearchResultEntity(
          kind: SearchResultKind.chapter,
          bookId: chapter.bookId,
          title: chapter.title,
          bookTitle: book.title,
          author: book.author,
          chapterIndex: chapter.index,
          chapterId: chapter.id,
          coverPath: book.coverPath,
          totalChapters: book.totalChapters,
        ));
      }

      return Success(results);
    } catch (e, st) {
      return Failure(DatabaseException('Search failed', e), st);
    }
  }
}
