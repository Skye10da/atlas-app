import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/router/navigation.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/library/presentation/providers/book_providers.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

final novelActionsControllerProvider =
    StateNotifierProvider<NovelActionsController, AsyncValue<void>>((ref) {
  return NovelActionsController(ref);
});

class NovelActionsController extends StateNotifier<AsyncValue<void>> {
  NovelActionsController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> confirmDelete(BuildContext context, String bookId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete novel?'),
        content: const Text(
          'This will permanently remove the novel and all reading progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        final db = _ref.read(databaseProvider);
        final repo = DriftLibraryRepository(db);
        final result = await repo.deleteBook(bookId);
        if (result is Failure) {
          throw Exception(result.error.userMessage);
        }
        _ref.invalidate(libraryBooksProvider);
        if (context.mounted) {
          popOrGoToLibrary(context);
        }
      });
    }
  }

  Future<void> changeWtrService(String bookId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = _ref.read(readerRepositoryProvider);
      await repo.resetChapterContent(bookId);
      _ref.invalidate(bookChaptersProvider(bookId));
      _ref.invalidate(novelChaptersProvider(bookId));
    });
  }

  Future<void> exportNovel(BuildContext context, BookEntity book) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = _ref.read(novelExportServiceProvider);
      final res = await service.exportToEpub(
        bookId: book.id,
        outputDirectory: dir,
      );
      if (res is Failure<String>) throw Exception(res.error.userMessage);
    });
  }

  Future<void> checkForUpdates(BuildContext context, String bookId, {bool showSnackbars = true}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final updateService = _ref.read(chapterUpdateServiceProvider);
      final outcome = await updateService.refreshBook(bookId);

      _ref.invalidate(bookDetailsProvider(bookId));
      _ref.invalidate(bookChaptersProvider(bookId));
      _ref.invalidate(novelChaptersProvider(bookId));
      _ref.invalidate(libraryBooksProvider);

      if (showSnackbars && context.mounted) {
        if (outcome.success) {
          final msg = outcome.newChapters > 0
              ? 'Found ${outcome.newChapters} new chapter(s)'
              : 'Already up to date';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(outcome.error ?? 'Failed to check for updates'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    });
  }

  Future<void> acknowledgeUpdates(String bookId) async {
    final db = _ref.read(databaseProvider);
    final repo = DriftLibraryRepository(db);
    final bookRes = await repo.getBookById(bookId);
    if (bookRes is Success<BookEntity> && bookRes.value.hasUpdate) {
      await repo.clearUpdateFlag(bookId);
      _ref.invalidate(bookDetailsProvider(bookId));
      _ref.invalidate(libraryBooksProvider);
    }
  }
}
