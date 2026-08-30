import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/application/chapter_update_service.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/domain/entities/bookshelf_layout.dart';
import 'package:atlas_app/library/domain/repository_interfaces/library_repository_interface.dart';
import 'package:atlas_app/library/presentation/view_models/library_state.dart';

class LibraryViewModel extends StateNotifier<AsyncValue<LibraryState>> {
  LibraryViewModel({required LibraryRepositoryInterface repository})
    : _repository = repository,
      super(const AsyncLoading()) {
    _subscription = _repository.watchBooks().listen(
      _onBooksEmitted,
      onError: (Object error, StackTrace stack) {
        state = AsyncError(error, stack);
      },
    );
  }

  final LibraryRepositoryInterface _repository;
  StreamSubscription<Result<List<BookEntity>>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onBooksEmitted(Result<List<BookEntity>> result) {
    switch (result) {
      case Success(value: final books):
        final current = state.valueOrNull ?? const LibraryState();
        final (filtered, recent, genres) = _computeDerived(
          books: books,
          category: current.category,
          genreFilter: current.genreFilter,
          searchQuery: current.searchQuery,
          sortOrder: current.sortOrder,
        );
        state = AsyncData(
          current.copyWith(
            books: books,
            filteredBooks: filtered,
            recentBooks: recent,
            availableGenres: genres,
          ),
        );
      case Failure(error: final error):
        state = AsyncError(error, StackTrace.current);
    }
  }

  void setLayout(BookshelfLayout layout) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(layout: layout));
  }

  void setSortOrder(LibrarySortOrder sortOrder) {
    final current = state.valueOrNull;
    if (current == null) return;
    final (filtered, recent, genres) = _computeDerived(
      books: current.books,
      category: current.category,
      genreFilter: current.genreFilter,
      searchQuery: current.searchQuery,
      sortOrder: sortOrder,
    );
    state = AsyncData(
      current.copyWith(
        sortOrder: sortOrder,
        filteredBooks: filtered,
        recentBooks: recent,
        availableGenres: genres,
      ),
    );
  }

  void setSearchQuery(String query) {
    final current = state.valueOrNull;
    if (current == null) return;
    final (filtered, recent, genres) = _computeDerived(
      books: current.books,
      category: current.category,
      genreFilter: current.genreFilter,
      searchQuery: query,
      sortOrder: current.sortOrder,
    );
    state = AsyncData(
      current.copyWith(
        searchQuery: query,
        filteredBooks: filtered,
        recentBooks: recent,
        availableGenres: genres,
      ),
    );
  }

  void setCategory(LibraryCategory category) {
    final current = state.valueOrNull;
    if (current == null) return;
    final (filtered, recent, genres) = _computeDerived(
      books: current.books,
      category: category,
      genreFilter: null,
      searchQuery: current.searchQuery,
      sortOrder: current.sortOrder,
    );
    state = AsyncData(
      current.copyWith(
        category: category,
        clearGenreFilter: true,
        filteredBooks: filtered,
        recentBooks: recent,
        availableGenres: genres,
      ),
    );
  }

  void setGenreFilter(String? genre) {
    final current = state.valueOrNull;
    if (current == null) return;
    final (filtered, recent, genres) = _computeDerived(
      books: current.books,
      category: current.category,
      genreFilter: genre,
      searchQuery: current.searchQuery,
      sortOrder: current.sortOrder,
    );
    state = AsyncData(
      current.copyWith(
        genreFilter: genre,
        clearGenreFilter: genre == null,
        filteredBooks: filtered,
        recentBooks: recent,
        availableGenres: genres,
      ),
    );
  }

  void filterByGenre(
    String tag, {
    LibraryCategory category = LibraryCategory.novels,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;
    final (filtered, recent, genres) = _computeDerived(
      books: current.books,
      category: category,
      genreFilter: tag,
      searchQuery: current.searchQuery,
      sortOrder: current.sortOrder,
    );
    state = AsyncData(
      current.copyWith(
        category: category,
        genreFilter: tag,
        filteredBooks: filtered,
        recentBooks: recent,
        availableGenres: genres,
      ),
    );
  }

  void selectBook(String? bookId) {
    final current = state.valueOrNull;
    if (current == null) return;
    // Tapping the same book again closes the panel
    final newId = current.selectedBookId == bookId ? null : bookId;
    state = AsyncData(
      current.copyWith(
        selectedBookId: newId,
        clearSelectedBookId: newId == null,
      ),
    );
  }

  Future<LibraryUpdateCheckResult?> checkUpdates(
    ChapterUpdateService service,
  ) async {
    final current = state.valueOrNull;
    if (current == null || current.isCheckingUpdates) return null;

    state = AsyncData(current.copyWith(isCheckingUpdates: true));
    try {
      final result = await service.checkTrackedBooks();
      return result;
    } finally {
      final latest = state.valueOrNull;
      if (latest != null) {
        state = AsyncData(latest.copyWith(isCheckingUpdates: false));
      }
    }
  }

  Future<Result<void>> deleteBook(String bookId) {
    return _repository.deleteBook(bookId);
  }

  Future<Result<void>> deleteBooks(List<String> bookIds) {
    return _repository.deleteBooks(bookIds);
  }

  Future<Result<void>> deleteAllBooks() {
    return _repository.deleteAllBooks();
  }

  static (List<BookEntity>, List<BookEntity>, List<String>) _computeDerived({
    required List<BookEntity> books,
    required LibraryCategory category,
    required String? genreFilter,
    required String searchQuery,
    required LibrarySortOrder sortOrder,
  }) {
    final allTags = books.expand((b) => b.tags).toSet().toList()..sort();

    final categoryFiltered = switch (category) {
      LibraryCategory.books => books.where((b) => !b.isNovel).toList(),
      LibraryCategory.novels => books.where((b) => b.isNovel).toList(),
    };

    final genreFiltered =
        genreFilter != null && genreFilter.isNotEmpty
            ? categoryFiltered
                .where((b) => b.tags.contains(genreFilter))
                .toList()
            : categoryFiltered;

    final query = searchQuery.trim().toLowerCase();
    final searchFiltered =
        query.isEmpty
            ? genreFiltered
            : genreFiltered.where((b) {
              final matchTitle = b.title.toLowerCase().contains(query);
              final matchAuthor =
                  b.author?.toLowerCase().contains(query) ?? false;
              return matchTitle || matchAuthor;
            }).toList();

    searchFiltered.sort((a, b) {
      return switch (sortOrder) {
        LibrarySortOrder.titleAsc => a.title.compareTo(b.title),
        LibrarySortOrder.titleDesc => b.title.compareTo(a.title),
        LibrarySortOrder.author => (a.author ?? '').compareTo(b.author ?? ''),
        LibrarySortOrder.recentlyAdded => b.createdAt.compareTo(a.createdAt),
        LibrarySortOrder.recentlyRead => switch ((
          a.lastOpenedAt,
          b.lastOpenedAt,
        )) {
          (null, null) => 0,
          (null, _) => 1,
          (_, null) => -1,
          (final aDate?, final bDate?) => bDate.compareTo(aDate),
        },
        LibrarySortOrder.recentlyUpdated => b.updatedAt.compareTo(a.updatedAt),
      };
    });

    final recentlyRead =
        [...searchFiltered]..sort((a, b) {
          return switch ((a.lastOpenedAt, b.lastOpenedAt)) {
            (null, null) => 0,
            (null, _) => 1,
            (_, null) => -1,
            (final aDate?, final bDate?) => bDate.compareTo(aDate),
          };
        });
    final recent = recentlyRead.take(3).toList();

    return (searchFiltered, recent, allTags);
  }
}
