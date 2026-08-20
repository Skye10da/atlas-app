import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/library/presentation/screens/book_details_screen.dart';
import 'package:atlas_app/library/presentation/screens/novel_details_screen.dart';

/// A panel shown alongside the library on wider screens.
/// Loads the book to determine its format, then embeds the
/// corresponding details screen (book or novel) in compact mode.
class BookDetailPanel extends ConsumerWidget {
  const BookDetailPanel({
    super.key,
    required this.bookId,
    required this.onClose,
  });

  final String bookId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(_panelBookProvider(bookId));

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(err.toString())),
        data: (result) => switch (result) {
          Success(value: final book) =>
            book.isNovel
                ? NovelDetailsScreen(
                    bookId: bookId,
                    isEmbedded: true,
                    onClose: onClose,
                  )
                : BookDetailsScreen(
                    bookId: bookId,
                    isEmbedded: true,
                    onClose: onClose,
                  ),
          Failure(error: final err) => Center(child: Text(err.userMessage)),
        },
      ),
    );
  }
}

/// Lightweight provider that fetches just the book entity so we can
/// determine whether it's a novel or a regular book.
final _panelBookProvider = FutureProvider.autoDispose
    .family<Result<BookEntity>, String>((ref, bookId) async {
      final db = ref.read(databaseProvider);
      return DriftLibraryRepository(db).getBookById(bookId);
    });
