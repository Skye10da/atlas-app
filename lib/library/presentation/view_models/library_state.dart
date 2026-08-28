import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/domain/entities/bookshelf_layout.dart';

enum LibrarySortOrder {
  titleAsc,
  titleDesc,
  author,
  recentlyAdded,
  recentlyRead,
  recentlyUpdated,
}

enum LibraryCategory { books, novels }

class LibraryState {
  const LibraryState({
    this.layout = BookshelfLayout.grid,
    this.sortOrder = LibrarySortOrder.titleAsc,
    this.searchQuery = '',
    this.category = LibraryCategory.novels,
    this.genreFilter,
    this.selectedBookId,
    this.isCheckingUpdates = false,
    this.books = const <BookEntity>[],
    this.filteredBooks = const <BookEntity>[],
    this.recentBooks = const <BookEntity>[],
    this.availableGenres = const <String>[],
  });

  final BookshelfLayout layout;
  final LibrarySortOrder sortOrder;
  final String searchQuery;
  final LibraryCategory category;
  final String? genreFilter;
  final String? selectedBookId;
  final bool isCheckingUpdates;
  final List<BookEntity> books;
  final List<BookEntity> filteredBooks;
  final List<BookEntity> recentBooks;
  final List<String> availableGenres;

  LibraryState copyWith({
    BookshelfLayout? layout,
    LibrarySortOrder? sortOrder,
    String? searchQuery,
    LibraryCategory? category,
    String? genreFilter,
    bool clearGenreFilter = false,
    String? selectedBookId,
    bool clearSelectedBookId = false,
    bool? isCheckingUpdates,
    List<BookEntity>? books,
    List<BookEntity>? filteredBooks,
    List<BookEntity>? recentBooks,
    List<String>? availableGenres,
  }) {
    return LibraryState(
      layout: layout ?? this.layout,
      sortOrder: sortOrder ?? this.sortOrder,
      searchQuery: searchQuery ?? this.searchQuery,
      category: category ?? this.category,
      genreFilter: clearGenreFilter ? null : (genreFilter ?? this.genreFilter),
      selectedBookId:
          clearSelectedBookId ? null : (selectedBookId ?? this.selectedBookId),
      isCheckingUpdates: isCheckingUpdates ?? this.isCheckingUpdates,
      books: books ?? this.books,
      filteredBooks: filteredBooks ?? this.filteredBooks,
      recentBooks: recentBooks ?? this.recentBooks,
      availableGenres: availableGenres ?? this.availableGenres,
    );
  }
}
