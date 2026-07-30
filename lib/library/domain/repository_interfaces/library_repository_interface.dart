import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

abstract interface class LibraryRepositoryInterface {
  Future<Result<List<BookEntity>>> getBooks();
  Future<Result<BookEntity>> getBookById(String id);
  Future<Result<void>> deleteBook(String id);
  Future<Result<void>> deleteAllBooks();
  Future<Result<void>> updateBook(String id, {String? title, String? author});
  Future<Result<void>> markAsOpened(String id);
}
