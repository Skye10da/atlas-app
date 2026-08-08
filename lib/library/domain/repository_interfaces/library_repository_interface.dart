import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

abstract interface class LibraryRepositoryInterface {
  Future<Result<List<BookEntity>>> getBooks();

  /// Emits the current shelf contents and re-emits whenever a book or its
  /// reading progress row changes, so listeners reflect new imports, deletes
  /// and progress updates without manual invalidation.
  Stream<Result<List<BookEntity>>> watchBooks();

  Future<Result<BookEntity>> getBookById(String id);
  Future<Result<void>> deleteBook(String id);
  Future<Result<void>> deleteAllBooks();
  Future<Result<void>> updateBook(String id, {String? title, String? author});
  Future<Result<void>> markAsOpened(String id);
}
