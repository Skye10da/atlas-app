import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/library/presentation/providers/book_providers.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_shimmer.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf_reader_content.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_content.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

class ReaderScreen extends HookConsumerWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      final db = ref.read(databaseProvider);
      unawaited(DriftLibraryRepository(db).markAsOpened(bookId));
      return null;
    }, [bookId]);

    final repo = ref.watch(readerRepositoryProvider);
    final settingsAsync = ref.watch(readingSettingsProvider);
    final bookAsync = ref.watch(bookDetailsProvider(bookId));

    return bookAsync.when(
      loading: () => _readerShimmer(context),
      error: (_, _) => _readerShimmer(context),
      data: (book) {
        // PDFs keep their original pages and render through a native PDF
        // viewer instead of the chapter-based reader.
        if (book.format == 'pdf') {
          final dir = book.filePath;
          if (dir != null && dir.isNotEmpty) {
            final params = GoRouterState.of(context).uri.queryParameters;
            final page = int.tryParse(params['page'] ?? '');
            return PdfReaderContent(
              bookId: bookId,
              pdfPath: p.join(dir, 'book.pdf'),
              initialPageNumber: (page != null && page > 0) ? page : null,
            );
          }
        }

        return settingsAsync.when(
          loading: () => _readerShimmer(context),
          error: (_, _) => _readerShimmer(context),
          data: (settings) => ReaderContent(
            repo: repo,
            bookId: bookId,
            settings: settings,
          ),
        );
      },
    );
  }

  Widget _readerShimmer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: ReadingViewTheme.paper.resolve(colorScheme).background,
      body: const ChapterShimmer(vt: ReadingViewTheme.paper),
    );
  }
}
