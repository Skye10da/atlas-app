import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/import/epub_import_service.dart';
import 'package:atlas_app/core/seed/seed_data.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/domain/entities/bookshelf_layout.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';

enum LibrarySortOrder {
  titleAsc,
  titleDesc,
  author,
  recentlyAdded,
  recentlyRead,
}

final bookshelfLayoutProvider =
    StateProvider<BookshelfLayout>((ref) => BookshelfLayout.grid);

final librarySortProvider =
    StateProvider<LibrarySortOrder>((ref) => LibrarySortOrder.titleAsc);

final librarySearchQueryProvider = StateProvider<String>((ref) => '');

final libraryRepositoryProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return DriftLibraryRepository(db);
});

final libraryBooksProvider = FutureProvider<Result<List<BookEntity>>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getBooks();
});

final filteredLibraryProvider = Provider<List<BookEntity>>((ref) {
  final booksResult = ref.watch(libraryBooksProvider);
  final sortOrder = ref.watch(librarySortProvider);
  final query = ref.watch(librarySearchQueryProvider).toLowerCase();

  final books = booksResult.whenOrNull(
    data: (result) => result is Success<List<BookEntity>> ? result.value : null,
  ) ?? <BookEntity>[];

  final filtered = query.isEmpty
      ? books
      : books.where((b) =>
          b.title.toLowerCase().contains(query) ||
          (b.author?.toLowerCase().contains(query) ?? false)).toList();

  filtered.sort((a, b) => switch (sortOrder) {
    LibrarySortOrder.titleAsc => a.title.compareTo(b.title),
    LibrarySortOrder.titleDesc => b.title.compareTo(a.title),
    LibrarySortOrder.author => (a.author ?? '').compareTo(b.author ?? ''),
    LibrarySortOrder.recentlyAdded => b.createdAt.compareTo(a.createdAt),
    LibrarySortOrder.recentlyRead => switch ((a.lastOpenedAt, b.lastOpenedAt)) {
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
        (final aDate?, final bDate?) => bDate.compareTo(aDate),
      },
  });

  return filtered;
});

final librarySeedProvider = FutureProvider<Result<void>>((ref) async {
  final db = ref.watch(databaseProvider);
  final seed = SeedData(db);
  if (await seed.hasBooks()) {
    return const Success(null);
  }
  await seed.seed();
  return const Success(null);
});

final _libraryImportingProvider = StateProvider<bool>((ref) => false);

final libraryImportServiceProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return EpubImportService(db);
});

final libraryImportProvider = Provider((ref) {
  return _LibraryImportActions(ref);
});

class _LibraryImportActions {
  _LibraryImportActions(this._ref);

  final Ref _ref;

  bool get isImporting => _ref.read(_libraryImportingProvider);

  Future<Result<void>> import() async {
    _ref.read(_libraryImportingProvider.notifier).state = true;
    try {
      final service = _ref.read(libraryImportServiceProvider);
      final result = await service.pickAndImport();
      return result;
    } finally {
      _ref.read(_libraryImportingProvider.notifier).state = false;
    }
  }
}

final libraryDeleteProvider = Provider((ref) {
  return _LibraryDeleteActions(ref);
});

class _LibraryDeleteActions {
  _LibraryDeleteActions(this._ref);

  final Ref _ref;

  Future<Result<void>> delete(String bookId) async {
    final repo = _ref.read(libraryRepositoryProvider);
    return repo.deleteBook(bookId);
  }
}
