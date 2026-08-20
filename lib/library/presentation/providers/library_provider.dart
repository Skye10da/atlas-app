import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/content_acquisition/services/import_service.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/import/epub_import_service.dart';
import 'package:atlas_app/core/import/file_open_providers.dart';
import 'package:atlas_app/core/import/pdf_import_service.dart';
import 'package:atlas_app/core/seed/seed_data.dart';
import 'package:atlas_app/library/application/atlas_source_import_service.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/domain/entities/bookshelf_layout.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';

enum LibrarySortOrder {
  titleAsc,
  titleDesc,
  author,
  recentlyAdded,
  recentlyRead,
}

enum LibraryCategory { books, novels }

final bookshelfLayoutProvider = StateProvider<BookshelfLayout>(
  (ref) => BookshelfLayout.grid,
);

final librarySortProvider = StateProvider<LibrarySortOrder>(
  (ref) => LibrarySortOrder.titleAsc,
);

final librarySearchQueryProvider = StateProvider<String>((ref) => '');

final libraryCategoryProvider = StateProvider<LibraryCategory>(
  (ref) => LibraryCategory.novels,
);

final libraryGenreFilterProvider = StateProvider<String?>((ref) => null);

/// The book currently shown in the detail panel on desktop. Null when no
/// panel is open. Setting this on desktop opens the panel; tapping the same
/// book again clears it (closes the panel).
final selectedBookIdProvider = StateProvider<String?>((ref) => null);

/// Derives the set of all unique genres across every book in the library,
/// sorted alphabetically. Used by the filter sidebar to populate genre chips.
final availableGenresProvider = Provider<List<String>>((ref) {
  final booksResult = ref.watch(libraryBooksProvider);
  final books =
      booksResult.whenOrNull(
        data: (result) =>
            result is Success<List<BookEntity>> ? result.value : null,
      ) ??
      <BookEntity>[];
  final allTags = books.expand((b) => b.tags).toSet().toList();
  allTags.sort();
  return allTags;
});

final libraryRepositoryProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return DriftLibraryRepository(db);
});

/// Reactive shelf source: re-emits whenever a book or its reading-progress row
/// changes, so the library reflects new imports, deletes and reader progress
/// immediately without opening/closing dialogs or manual invalidation.
final libraryBooksProvider = StreamProvider<Result<List<BookEntity>>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchBooks();
});

final filteredLibraryProvider = Provider<List<BookEntity>>((ref) {
  final booksResult = ref.watch(libraryBooksProvider);
  final sortOrder = ref.watch(librarySortProvider);
  final query = ref.watch(librarySearchQueryProvider).toLowerCase();
  final category = ref.watch(libraryCategoryProvider);
  final genreFilter = ref.watch(libraryGenreFilterProvider);

  final books =
      booksResult.whenOrNull(
        data: (result) =>
            result is Success<List<BookEntity>> ? result.value : null,
      ) ??
      <BookEntity>[];

  final categoryFiltered = switch (category) {
    LibraryCategory.books => books.where((b) => !b.isNovel).toList(),
    LibraryCategory.novels => books.where((b) => b.isNovel).toList(),
  };

  final genreFiltered = genreFilter != null && genreFilter.isNotEmpty
      ? categoryFiltered.where((b) => b.tags.contains(genreFilter)).toList()
      : categoryFiltered;

  final searchFiltered = query.isEmpty
      ? genreFiltered
      : genreFiltered
            .where(
              (b) =>
                  b.title.toLowerCase().contains(query) ||
                  (b.author?.toLowerCase().contains(query) ?? false),
            )
            .toList();

  searchFiltered.sort(
    (a, b) => switch (sortOrder) {
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
    },
  );

  return searchFiltered;
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

enum ImportStage { downloading, processing, done, idle }

class ImportProgress {
  const ImportProgress({required this.stage, this.message});
  final ImportStage stage;
  final String? message;
}

final _libraryImportingProvider = StateProvider<ImportProgress>(
  (ref) => const ImportProgress(stage: ImportStage.idle),
);

final libraryImportServiceProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return EpubImportService(db);
});

final pdfImportServiceProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return PdfImportService(db);
});

final atlasSourceImportServiceProvider = Provider((ref) {
  return const AtlasSourceImportService();
});

final libraryImportProvider = Provider((ref) {
  return _LibraryImportActions(ref);
});

class _LibraryImportActions {
  _LibraryImportActions(this._ref);

  final Ref _ref;

  bool get isImporting {
    final stage = _ref.read(_libraryImportingProvider).stage;
    return stage == ImportStage.downloading || stage == ImportStage.processing;
  }

  ImportProgress get progress => _ref.read(_libraryImportingProvider);

  /// Opens the unified "Add to library" sheet in combined mode — URL field,
  /// file picker, and browse sources all on one screen.  The sheet's
  /// [onImport] callback routes URL imports through the engine and file
  /// imports through [OpenedFileImportService.importBytes] so the
  /// extension-routing logic lives in exactly one place.
  Future<Result<ImportOutcome>> importLocal(BuildContext context) async {
    final importer = _ref.read(openedFileImportServiceProvider);

    final outcome = await showImportUrlSheet(
      context,
      mode: ImportSheetMode.combined,
      title: 'Add to library',
      onImport: (bytes, fileName, url, onProgress) async {
        if (bytes == null || fileName == null) {
          if (url != null && url.isNotEmpty) {
            final engine = _ref.read(contentAcquisitionEngineProvider);
            return engine.importAndSave(url, onProgress: onProgress);
          }
          throw const CancelledException();
        }
        onProgress(0.1);
        final result = await importer.importBytes(bytes, fileName);
        onProgress(1.0);
        if (result is Success<ImportOutcome>) return result.value;
        if (result is Failure<ImportOutcome>) {
          throw ImportException(result.error.userMessage);
        }
        throw const CancelledException();
      },
    );

    if (outcome == null) return const Failure(CancelledException());
    return Success(outcome);
  }
}

class CancelledException extends AppException {
  const CancelledException() : super('Import cancelled.');
  @override
  String get code => 'CANCELLED';
  @override
  String get userMessage => 'Import cancelled.';
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

  Future<Result<void>> deleteAll() async {
    final repo = _ref.read(libraryRepositoryProvider);
    return repo.deleteAllBooks();
  }
}
