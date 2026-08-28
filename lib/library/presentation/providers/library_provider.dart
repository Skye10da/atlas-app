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
import 'package:atlas_app/library/presentation/view_models/library_state.dart';
import 'package:atlas_app/library/presentation/view_models/library_view_model.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';

export 'package:atlas_app/library/presentation/view_models/library_state.dart';
export 'package:atlas_app/library/presentation/view_models/library_view_model.dart';

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

/// The unified Library ViewModel managing reactive shelf state, filtering,
/// sorting, layout modes, update-checks, and deletions.
final libraryViewModelProvider =
    StateNotifierProvider<LibraryViewModel, AsyncValue<LibraryState>>((ref) {
      final repo = ref.watch(libraryRepositoryProvider);
      return LibraryViewModel(repository: repo);
    });

/// Backward-compatible bridge provider: derives filtered books from the ViewModel.
final filteredLibraryProvider = Provider<List<BookEntity>>((ref) {
  final state = ref.watch(libraryViewModelProvider).valueOrNull;
  return state?.filteredBooks ?? const <BookEntity>[];
});

/// Backward-compatible bridge provider: derives available genres from the ViewModel.
final availableGenresProvider = Provider<List<String>>((ref) {
  final state = ref.watch(libraryViewModelProvider).valueOrNull;
  return state?.availableGenres ?? const <String>[];
});

/// Backward-compatible bridge provider: derives bookshelf layout from the ViewModel.
final bookshelfLayoutProvider = Provider<BookshelfLayout>((ref) {
  final state = ref.watch(libraryViewModelProvider).valueOrNull;
  return state?.layout ?? BookshelfLayout.grid;
});

/// Backward-compatible bridge provider: derives sort order from the ViewModel.
final librarySortProvider = Provider<LibrarySortOrder>((ref) {
  final state = ref.watch(libraryViewModelProvider).valueOrNull;
  return state?.sortOrder ?? LibrarySortOrder.titleAsc;
});

/// Backward-compatible bridge provider: derives search query from the ViewModel.
final librarySearchQueryProvider = Provider<String>((ref) {
  final state = ref.watch(libraryViewModelProvider).valueOrNull;
  return state?.searchQuery ?? '';
});

/// Backward-compatible bridge provider: derives category from the ViewModel.
final libraryCategoryProvider = Provider<LibraryCategory>((ref) {
  final state = ref.watch(libraryViewModelProvider).valueOrNull;
  return state?.category ?? LibraryCategory.novels;
});

/// Backward-compatible bridge provider: derives genre filter from the ViewModel.
final libraryGenreFilterProvider = Provider<String?>((ref) {
  final state = ref.watch(libraryViewModelProvider).valueOrNull;
  return state?.genreFilter;
});

/// Backward-compatible bridge provider: derives selected book id from the ViewModel.
final selectedBookIdProvider = Provider<String?>((ref) {
  final state = ref.watch(libraryViewModelProvider).valueOrNull;
  return state?.selectedBookId;
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

  Future<Result<void>> delete(String bookId) {
    return _ref.read(libraryViewModelProvider.notifier).deleteBook(bookId);
  }

  Future<Result<void>> deleteAll() {
    return _ref.read(libraryViewModelProvider.notifier).deleteAllBooks();
  }
}
