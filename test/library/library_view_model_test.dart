import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/domain/entities/bookshelf_layout.dart';
import 'package:atlas_app/library/domain/repository_interfaces/library_repository_interface.dart';
import 'package:atlas_app/library/presentation/view_models/library_state.dart';
import 'package:atlas_app/library/presentation/view_models/library_view_model.dart';

class FakeLibraryRepository implements LibraryRepositoryInterface {
  final _controller = StreamController<Result<List<BookEntity>>>.broadcast();
  List<BookEntity> books = [];

  void emit(List<BookEntity> newBooks) {
    books = newBooks;
    _controller.add(Success(newBooks));
  }

  void emitError(AppException error) {
    _controller.add(Failure(error));
  }

  @override
  Stream<Result<List<BookEntity>>> watchBooks() => _controller.stream;

  @override
  Future<Result<List<BookEntity>>> getBooks() async => Success(books);

  @override
  Future<Result<void>> deleteBook(String id) async {
    books.removeWhere((b) => b.id == id);
    emit(List.from(books));
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteBooks(List<String> ids) async {
    books.removeWhere((b) => ids.contains(b.id));
    emit(List.from(books));
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteAllBooks() async {
    books.clear();
    emit([]);
    return const Success(null);
  }

  @override
  Future<Result<BookEntity>> getBookById(String id) async =>
      Success(books.firstWhere((b) => b.id == id));

  @override
  Stream<Result<BookEntity>> watchBookById(String id) =>
      _controller.stream.map((res) {
        if (res is Success<List<BookEntity>>) {
          return Success(res.value.firstWhere((b) => b.id == id));
        }
        return const Failure(NotFoundException('Book not found'));
      });

  @override
  Future<Result<void>> updateBook(
    String id, {
    String? title,
    String? author,
  }) async => const Success(null);

  @override
  Future<Result<void>> markAsOpened(String id) async => const Success(null);

  @override
  Future<Result<void>> setUpdateTracking(String id, bool enabled) async =>
      const Success(null);

  @override
  Future<Result<void>> clearUpdateFlag(String id) async => const Success(null);

  void dispose() {
    _controller.close();
  }
}

BookEntity _createBook({
  required String id,
  required String title,
  String? author,
  ContentCategory itemType = ContentCategory.novel,
  List<String> tags = const [],
  DateTime? lastOpenedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 1, 1);
  return BookEntity(
    id: id,
    title: title,
    author: author,
    format: 'epub',
    totalChapters: 10,
    itemType: itemType,
    tags: tags,
    lastOpenedAt: lastOpenedAt,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

void main() {
  group('LibraryViewModel', () {
    late FakeLibraryRepository repository;
    late LibraryViewModel viewModel;

    setUp(() {
      repository = FakeLibraryRepository();
      viewModel = LibraryViewModel(repository: repository);
    });

    tearDown(() {
      viewModel.dispose();
      repository.dispose();
    });

    test('initial state is AsyncLoading until repository emits books', () async {
      expect(viewModel.state.isLoading, isTrue);

      final book1 = _createBook(
        id: '1',
        title: 'Alpha Novel',
        tags: ['Fantasy'],
      );
      repository.emit([book1]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.state.hasValue, isTrue);
      final state = viewModel.state.value!;
      expect(state.books.length, 1);
      expect(state.filteredBooks.length, 1);
      expect(state.availableGenres, ['Fantasy']);
    });

    test('category filter separates books from novels', () async {
      final novel = _createBook(
        id: '1',
        title: 'Shadow Slave',
        itemType: ContentCategory.novel,
      );
      final regularBook = _createBook(
        id: '2',
        title: 'Clean Code',
        itemType: ContentCategory.book,
      );
      repository.emit([novel, regularBook]);
      await Future<void>.delayed(Duration.zero);

      // Default category is novels
      expect(viewModel.state.value!.filteredBooks.single.title, 'Shadow Slave');

      // Switch to books
      viewModel.setCategory(LibraryCategory.books);
      expect(viewModel.state.value!.filteredBooks.single.title, 'Clean Code');
    });

    test('search query filters by title and author case-insensitively', () async {
      final novel1 = _createBook(
        id: '1',
        title: 'Lord of the Mysteries',
        author: 'Cuttlefish',
      );
      final novel2 = _createBook(
        id: '2',
        title: 'Reverend Insanity',
        author: 'Gu Zhen Ren',
      );
      repository.emit([novel1, novel2]);
      await Future<void>.delayed(Duration.zero);

      // Search by partial title
      viewModel.setSearchQuery('mysteries');
      expect(
        viewModel.state.value!.filteredBooks.map((b) => b.title),
        ['Lord of the Mysteries'],
      );

      // Search by author
      viewModel.setSearchQuery('zhen');
      expect(
        viewModel.state.value!.filteredBooks.map((b) => b.title),
        ['Reverend Insanity'],
      );

      // Clear search
      viewModel.setSearchQuery('');
      expect(viewModel.state.value!.filteredBooks.length, 2);
    });

    test('genre filtering and filterByGenre', () async {
      final novel1 = _createBook(
        id: '1',
        title: 'Novel A',
        tags: ['Fantasy', 'Action'],
      );
      final novel2 = _createBook(id: '2', title: 'Novel B', tags: ['Sci-Fi']);
      repository.emit([novel1, novel2]);
      await Future<void>.delayed(Duration.zero);

      viewModel.setGenreFilter('Sci-Fi');
      expect(
        viewModel.state.value!.filteredBooks.map((b) => b.title),
        ['Novel B'],
      );

      // filterByGenre sets tag and forces novel category
      viewModel.setCategory(LibraryCategory.books);
      viewModel.filterByGenre('Action');
      expect(viewModel.state.value!.category, LibraryCategory.novels);
      expect(
        viewModel.state.value!.filteredBooks.map((b) => b.title),
        ['Novel A'],
      );
    });

    test('layout switching and desktop selection toggle', () async {
      final novel = _createBook(id: 'book-1', title: 'Novel');
      repository.emit([novel]);
      await Future<void>.delayed(Duration.zero);

      viewModel.setLayout(BookshelfLayout.list);
      expect(viewModel.state.value!.layout, BookshelfLayout.list);

      viewModel.selectBook('book-1');
      expect(viewModel.state.value!.selectedBookId, 'book-1');

      // Tapping the same book again deselects it
      viewModel.selectBook('book-1');
      expect(viewModel.state.value!.selectedBookId, isNull);
    });

    test('recentBooks returns top 3 recently opened books', () async {
      final n1 = _createBook(
        id: '1',
        title: 'N1',
        lastOpenedAt: DateTime(2026, 1, 1),
      );
      final n2 = _createBook(
        id: '2',
        title: 'N2',
        lastOpenedAt: DateTime(2026, 1, 5),
      );
      final n3 = _createBook(
        id: '3',
        title: 'N3',
        lastOpenedAt: DateTime(2026, 1, 10),
      );
      final n4 = _createBook(
        id: '4',
        title: 'N4',
        lastOpenedAt: DateTime(2026, 1, 3),
      );
      final n5 = _createBook(id: '5', title: 'N5', lastOpenedAt: null);

      repository.emit([n1, n2, n3, n4, n5]);
      await Future<void>.delayed(Duration.zero);

      final recent = viewModel.state.value!.recentBooks;
      expect(recent.length, 3);
      expect(recent[0].title, 'N3'); // Jan 10
      expect(recent[1].title, 'N2'); // Jan 5
      expect(recent[2].title, 'N4'); // Jan 3
    });

    test('deleteBook and deleteAllBooks delegate to repository', () async {
      final n1 = _createBook(id: '1', title: 'N1');
      final n2 = _createBook(id: '2', title: 'N2');
      repository.emit([n1, n2]);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.state.value!.books.length, 2);

      await viewModel.deleteBook('1');
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.state.value!.books.length, 1);
      expect(viewModel.state.value!.books.single.id, '2');

      await viewModel.deleteAllBooks();
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.state.value!.books, isEmpty);
    });

    test('deleteBooks deletes multiple books in repository', () async {
      final n1 = _createBook(id: '1', title: 'N1');
      final n2 = _createBook(id: '2', title: 'N2');
      final n3 = _createBook(id: '3', title: 'N3');
      repository.emit([n1, n2, n3]);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.state.value!.books.length, 3);

      await viewModel.deleteBooks(['1', '3']);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.state.value!.books.length, 1);
      expect(viewModel.state.value!.books.single.id, '2');
    });
  });
}
