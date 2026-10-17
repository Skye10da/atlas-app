import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/content_acquisition/application/chapter_update_service.dart';
import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/design_system/molecules/app_snackbar.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';

/// Opens the unified "Add to library" sheet and routes to the new book.
///
/// Shared by the Library screen and the app shell's centre "+" action so the
/// import flow lives in exactly one place.
Future<void> addToLibrary(BuildContext context, WidgetRef ref) async {
  final actions = ref.read(libraryImportProvider);
  final result = await actions.importLocal(context);
  if (!context.mounted) return;
  ref.invalidate(libraryBooksProvider);
  if (result is Success<ImportOutcome>) {
    if (result.value.bookId.startsWith('batch:')) {
      final count = result.value.bookId.split(':').last;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully imported $count books.')),
      );
    } else {
      final route = result.value.category == ContentCategory.novel
          ? '/novel/${result.value.bookId}'
          : '/book/${result.value.bookId}';
      unawaited(context.push(route));
    }
  }
}

/// Checks every tracked novel for new chapters and reports the outcome in a
/// snackbar. Shared by the controls row and the insights panel.
Future<void> checkAllLibraryUpdates(BuildContext context, WidgetRef ref) async {
  try {
    final service = ref.read(chapterUpdateServiceProvider);
    final result = await ref
        .read(libraryViewModelProvider.notifier)
        .checkUpdates(service);
    if (result == null) return;
    if (!context.mounted) return;
    final message = result.booksWithUpdates == 0
        ? 'No new chapters found.'
        : 'Found ${result.totalNewChapters} new chapter(s) in '
              '${result.booksWithUpdates} novel(s).';
    AppSnackBar.show(message);
  } catch (e) {
    if (!context.mounted) return;
    AppSnackBar.showError(
      'Update check failed: ${ChapterUpdateService.describeFailure(e)}',
    );
  }
}
