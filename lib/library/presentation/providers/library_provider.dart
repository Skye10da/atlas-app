import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/import/epub_import_service.dart';
import 'package:atlas_app/core/import/pdf_import_service.dart';
import 'package:atlas_app/core/seed/seed_data.dart';
import 'package:atlas_app/library/application/atlas_source_import_service.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/domain/entities/bookshelf_layout.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/library/presentation/widgets/import_progress_dialog.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';

enum LibrarySortOrder {
  titleAsc,
  titleDesc,
  author,
  recentlyAdded,
  recentlyRead,
}

enum LibraryCategory { books, novels }

final bookshelfLayoutProvider =
    StateProvider<BookshelfLayout>((ref) => BookshelfLayout.grid);

final librarySortProvider =
    StateProvider<LibrarySortOrder>((ref) => LibrarySortOrder.titleAsc);

final librarySearchQueryProvider = StateProvider<String>((ref) => '');

final libraryCategoryProvider =
    StateProvider<LibraryCategory>((ref) => LibraryCategory.novels);

final libraryGenreFilterProvider = StateProvider<String?>((ref) => null);

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

  final books = booksResult.whenOrNull(
    data: (result) => result is Success<List<BookEntity>> ? result.value : null,
  ) ?? <BookEntity>[];

  final categoryFiltered = switch (category) {
    LibraryCategory.books => books.where((b) => !b.isNovel).toList(),
    LibraryCategory.novels => books.where((b) => b.isNovel).toList(),
  };

  final genreFiltered = genreFilter != null && genreFilter.isNotEmpty
      ? categoryFiltered.where((b) => b.tags.contains(genreFilter)).toList()
      : categoryFiltered;

  final searchFiltered = query.isEmpty
      ? genreFiltered
      : genreFiltered.where((b) =>
          b.title.toLowerCase().contains(query) ||
          (b.author?.toLowerCase().contains(query) ?? false)).toList();

  searchFiltered.sort((a, b) => switch (sortOrder) {
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

final _libraryImportingProvider = StateProvider<ImportProgress>((ref) => const ImportProgress(stage: ImportStage.idle));

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

  void _setStage(ImportStage stage, [String? message]) {
    _ref.read(_libraryImportingProvider.notifier).state = ImportProgress(stage: stage, message: message);
  }

  Future<Result<String?>> import() async {
    _setStage(ImportStage.processing, 'Importing EPUB...');
    try {
      final service = _ref.read(libraryImportServiceProvider);
      final result = await service.pickAndImport();
      if (result is Success) _setStage(ImportStage.done, 'Done');
      return result;
    } finally {
      if (_ref.read(_libraryImportingProvider).stage != ImportStage.done) {
        _setStage(ImportStage.idle);
      }
    }
  }

  Future<Result<String?>> importPdf() async {
    _setStage(ImportStage.processing, 'Importing PDF...');
    try {
      final service = _ref.read(pdfImportServiceProvider);
      final result = await service.pickAndImport();
      if (result is Success) _setStage(ImportStage.done, 'Done');
      return result;
    } finally {
      if (_ref.read(_libraryImportingProvider).stage != ImportStage.done) {
        _setStage(ImportStage.idle);
      }
    }
  }

  /// Picks a `.atlas` source-link package and re-imports the linked novel
  /// through its original source, mirroring the URL-import progress dialog.
  Future<Result<ImportOutcome>> importAtlas(BuildContext context) async {
    _setStage(ImportStage.processing, 'Importing Atlas package...');
    try {
      final service = _ref.read(atlasSourceImportServiceProvider);
      final pickResult = await service.pickSourceUrl();
      if (pickResult is Failure<String?>) {
        return Failure<ImportOutcome>(pickResult.error);
      }
      final sourceUrl = (pickResult as Success<String?>).value;
      if (sourceUrl == null) return const Failure(CancelledException());

      final engine = _ref.read(contentAcquisitionEngineProvider);
      final progress = ValueNotifier<double>(0);
      final importFuture = engine.importAndSave(
        sourceUrl,
        onProgress: (p) => progress.value = p,
      );

      if (!context.mounted) {
        try { await importFuture; } catch (_) {}
        return const Failure(CancelledException());
      }

      final succeeded = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ImportProgressDialog(
          future: importFuture,
          progress: progress,
        ),
      );

      if (succeeded != true) {
        try { await importFuture; } catch (_) {}
        return const Failure(CancelledException());
      }

      final outcome = await importFuture;
      _setStage(ImportStage.done, 'Done');
      return Success(outcome);
    } finally {
      if (_ref.read(_libraryImportingProvider).stage != ImportStage.done) {
        _setStage(ImportStage.idle);
      }
    }
  }

  Future<Result<ImportOutcome>> importUrl(
    BuildContext context, {
    String title = 'Import from URL',
    String labelText = 'Book URL',
    String hintText = 'https://example.com/book.epub',
    String buttonLabel = 'Import',
  }) async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => ImportUrlDialog(
        title: title,
        labelText: labelText,
        hintText: hintText,
        buttonLabel: buttonLabel,
      ),
    );
    if (url == null) return const Failure(CancelledException());

    final engine = _ref.read(contentAcquisitionEngineProvider);
    final progress = ValueNotifier<double>(0);
    final importFuture = engine.importAndSave(
      url,
      onProgress: (p) => progress.value = p,
    );

    if (!context.mounted) {
      try { await importFuture; } catch (_) {}
      return const Failure(CancelledException());
    }

    final succeeded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportProgressDialog(
        future: importFuture,
        progress: progress,
      ),
    );

    if (succeeded != true) {
      try { await importFuture; } catch (_) {}
      return const Failure(CancelledException());
    }

    final outcome = await importFuture;
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

class ImportException extends AppException {
  const ImportException(super.message);
  @override
  String get code => 'IMPORT_ERROR';
  @override
  String get userMessage => message;
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
