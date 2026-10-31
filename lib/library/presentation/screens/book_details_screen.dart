import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/session/session_refresh_service.dart';
import 'package:atlas_app/core/router/navigation.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/library/presentation/widgets/chapter_grouped_list.dart';
import 'package:atlas_app/library/presentation/widgets/detail_header.dart';
import 'package:atlas_app/library/presentation/widgets/open_reader.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

class BookDetailsScreen extends ConsumerWidget {
  const BookDetailsScreen({
    super.key,
    required this.bookId,
    this.isEmbedded = false,
    this.onClose,
  });

  final String bookId;
  final bool isEmbedded;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(_bookDetailsProvider(bookId));

    return bookAsync.when(
      loading: () => isEmbedded
          ? const Center(child: CircularProgressIndicator())
          : const Scaffold(body: AppLoading()),
      error: (err, _) => isEmbedded
          ? Center(child: Text(err.toString()))
          : Scaffold(
              body: AppErrorState(
                message: 'Could not load book details.',
                technicalDetails: err.toString(),
              ),
            ),
      data: (result) => switch (result) {
        Success(value: final data) => _BookDetailsBody(
          book: data.book,
          chapters: data.chapters,
          lastReadChapterIndex: data.lastReadChapterIndex,
          onOpenReader: (chapterId) => openReader(
            bookId: bookId,
            ref: ref,
            context: context,
            book: data.book,
            chapters: data.chapters,
            lastReadChapterId: data.lastReadChapterId,
            chapterId: chapterId,
            onReturn: () => ref.invalidate(_bookDetailsProvider(bookId)),
          ),
          onDelete: () => _deleteBook(bookId, ref, context),
          onEditMetadata: (t, a) => _editMetadata(bookId, ref, t, a),
          isEmbedded: isEmbedded,
          onClose: onClose,
        ),
        Failure(error: final err) =>
          isEmbedded
              ? Center(child: Text(err.userMessage))
              : Scaffold(
                  body: AppErrorState(
                    message: err.userMessage,
                    technicalDetails: err.message,
                  ),
                ),
      },
    );
  }
}

Future<void> _deleteBook(
  String bookId,
  WidgetRef ref,
  BuildContext context,
) async {
  final db = ref.read(databaseProvider);
  final repo = DriftLibraryRepository(db);
  final r = await repo.deleteBook(bookId);
  if (context.mounted) {
    if (r is Success) {
      ref.invalidate(libraryBooksProvider);
      popOrGoToLibrary(context);
    } else if (r is Failure) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(r.error.userMessage)));
    }
  }
}

Future<void> _editMetadata(
  String bookId,
  WidgetRef ref,
  String? title,
  String? author,
) async {
  final db = ref.read(databaseProvider);
  final repo = DriftLibraryRepository(db);
  await repo.updateBook(bookId, title: title, author: author);
  ref.invalidate(_bookDetailsProvider(bookId));
}

final _bookDetailsProvider =
    FutureProvider.family<Result<_BookDetailsData>, String>((
      ref,
      bookId,
    ) async {
      final db = ref.watch(databaseProvider);
      final libRepo = DriftLibraryRepository(db);
      final readerRepo = DriftReaderRepository(db);

      final booksResult = await libRepo.getBookById(bookId);
      if (booksResult is Failure<BookEntity>) {
        return Failure<_BookDetailsData>(
          booksResult.error,
          booksResult.stackTrace,
        );
      }

      final book = (booksResult as Success<BookEntity>).value;

      final chaptersResult = await readerRepo.getChapters(bookId);
      if (chaptersResult is Failure<List<ChapterEntity>>) {
        return Failure<_BookDetailsData>(
          chaptersResult.error,
          chaptersResult.stackTrace,
        );
      }

      final chapters = (chaptersResult as Success<List<ChapterEntity>>).value;

      final progressRow = await db.getReadingProgress(bookId);
      final lastReadChapterIndex = progressRow != null
          ? chapters.indexWhere((c) => c.id == progressRow.chapterId)
          : -1;

      return Success(
        _BookDetailsData(
          book: book,
          chapters: chapters,
          lastReadChapterIndex: lastReadChapterIndex >= 0
              ? lastReadChapterIndex
              : null,
          lastReadChapterId: lastReadChapterIndex >= 0
              ? progressRow!.chapterId
              : null,
        ),
      );
    });

class _BookDetailsData {
  const _BookDetailsData({
    required this.book,
    required this.chapters,
    this.lastReadChapterIndex,
    this.lastReadChapterId,
  });
  final BookEntity book;
  final List<ChapterEntity> chapters;
  // Display-only: which position to show as "read up to" in the chapter
  // list. Never used for navigation — see lastReadChapterId for that.
  final int? lastReadChapterIndex;
  // Navigation identity for "Continue Reading" — the chapter actually
  // resumed is always resolved by id, never by a re-derived index.
  final String? lastReadChapterId;
}

class _BookDetailsBody extends HookConsumerWidget {
  const _BookDetailsBody({
    required this.book,
    required this.chapters,
    required this.onOpenReader,
    required this.onDelete,
    this.lastReadChapterIndex,
    this.onEditMetadata,
    this.isEmbedded = false,
    this.onClose,
  });

  final BookEntity book;
  final List<ChapterEntity> chapters;
  final VoidCallback onDelete;
  final int? lastReadChapterIndex;
  final Future<void> Function(String title, String? author)? onEditMetadata;
  final void Function(String? chapterId)? onOpenReader;
  final bool isEmbedded;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final progress = book.progressPercent;
    final isRedownloading = useState(false);
    final redownloadProgress = useState<(int, int)?>(null);
    final hasProgress = progress > 0.005;
    final inProgress = hasProgress && progress < 99.995;

    final topBar = DetailTopBar(
      leading: IconButton(
        icon: Icon(isEmbedded ? Icons.close : Icons.arrow_back_rounded),
        tooltip: isEmbedded ? 'Close' : 'Back',
        onPressed: isEmbedded ? onClose : () => popOrGoToLibrary(context),
      ),
      actions: isEmbedded
          ? const <Widget>[]
          : [
              if (isRedownloading.value)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.cloud_download_outlined),
                  tooltip: 'Redownload all chapters',
                  onPressed: () => _redownloadAll(
                    context,
                    ref,
                    isRedownloading,
                    redownloadProgress,
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit details',
                onPressed: isRedownloading.value
                    ? null
                    : () => _editMetadata(context),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete book',
                onPressed: isRedownloading.value
                    ? null
                    : () => _deleteBook(context),
              ),
            ],
    );

    final header = DetailHeader(
      book: book,
      isEmbedded: isEmbedded,
      meta: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (book.format.isNotEmpty)
            DetailPill(label: book.format.toUpperCase()),
          DetailPill(
            label:
                '${chapters.length} chapter${chapters.length == 1 ? '' : 's'}',
          ),
          if (hasProgress) DetailPill(label: '${progress.toStringAsFixed(0)}% read'),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inProgress) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: book.progress01,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            onPressed: () => onOpenReader?.call(null),
            icon: Icon(
              hasProgress ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
            ),
            label: Text(hasProgress ? 'Continue Reading' : 'Start Reading'),
          ),
        ],
      ),
    );

    final chapterWidgets = <Widget>[
      if (isRedownloading.value)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Card(
            color: cs.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      redownloadProgress.value == null
                          ? 'Redownloading chapters…'
                          : 'Redownloading ${redownloadProgress.value!.$1}/${redownloadProgress.value!.$2} chapters…',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          '${chapters.length} Chapter${chapters.length == 1 ? '' : 's'}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: 'Fraunces',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      ChapterGroupedList(
        chapters: chapters,
        lastReadChapterIndex: lastReadChapterIndex,
        onOpenReader: onOpenReader,
      ),
      const SizedBox(height: 16),
    ];

    // Wide windows: header on the left, chapters filling the rest.
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final twoPane =
            !isEmbedded && constraints.maxWidth >= AppBreakpoints.tablet;
        if (!twoPane) {
          return Column(
            children: [
              topBar,
              Expanded(child: ListView(children: [header, ...chapterWidgets])),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 400,
              child: Column(
                children: [
                  topBar,
                  Expanded(child: ListView(children: [header])),
                ],
              ),
            ),
            VerticalDivider(
              width: 1,
              color: cs.outlineVariant.withValues(alpha: 0.6),
            ),
            Expanded(child: ListView(children: chapterWidgets)),
          ],
        );
      },
    );

    if (isEmbedded) return content;
    return Scaffold(body: SafeArea(bottom: false, child: content));
  }

  void _deleteBook(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete book?'),
        content: const Text(
          'This will permanently remove the book and all reading progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editMetadata(BuildContext context) {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Metadata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(labelText: 'Author'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final t = titleController.text.trim();
              if (t.isNotEmpty) {
                onEditMetadata?.call(t, authorController.text.trim());
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _redownloadAll(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<bool> isRedownloading,
    ValueNotifier<(int, int)?> progress,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redownload all chapters?'),
        content: Text(
          'This will re-fetch all ${chapters.length} chapters from the source and overwrite the cached files (original language).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Redownload'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    isRedownloading.value = true;
    progress.value = (0, chapters.length);
    try {
      final service = ref.read(chapterDownloadServiceProvider);
      final results = await service.redownloadAllChapters(
        book.id,
        onProgress: (done, total) {
          if (context.mounted) progress.value = (done, total);
        },
      );
      if (!context.mounted) return;
      final failures = results.whereType<Failure>().length;
      // Refresh book details so chapter states update.
      ref.invalidate(_bookDetailsProvider(book.id));
      // Also invalidate any cached chapter content in the reader.
      for (final ch in chapters) {
        ref.invalidate(readerChapterContentProvider(ch));
      }

      // A bot-check wall on the source origin is recoverable: offer the same
      // quick re-verify the reader and import sheet use, then retry.
      final bookOrigin = SessionRefreshService.originOf(book.sourceUrl);
      final latched = SessionRefreshService.instance.lastInvalidOrigin.value;
      final challenge =
          failures > 0 &&
          bookOrigin != null &&
          latched != null &&
          SessionRefreshService.sameOrigin(latched, bookOrigin);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            challenge
                ? 'Redownload blocked by a bot check. Re-verify the session to continue.'
                : failures == 0
                ? 'Redownloaded ${chapters.length} chapters'
                : 'Redownloaded ${chapters.length - failures}/${chapters.length} chapters ($failures failed)',
          ),
          duration: challenge
              ? const Duration(seconds: 8)
              : const Duration(seconds: 4),
          action: SnackBarAction(
            label: challenge ? 'Re-verify' : 'Dismiss',
            onPressed: !challenge
                ? () {}
                : () => unawaited(() async {
                    final ok = await SessionRefreshService.instance
                        .ensureFresh(
                          bookOrigin,
                          seedUrl: Uri.tryParse(book.sourceUrl ?? ''),
                        );
                    if (!ok || !context.mounted) return;
                    // Re-run the same bulk redownload now that fresh cookies
                    // are captured for the origin.
                    isRedownloading.value = true;
                    progress.value = (0, chapters.length);
                    try {
                      final retry = await ref
                          .read(chapterDownloadServiceProvider)
                          .redownloadAllChapters(
                            book.id,
                            onProgress: (done, total) {
                              if (context.mounted) {
                                progress.value = (done, total);
                              }
                            },
                          );
                      if (!context.mounted) return;
                      ref.invalidate(_bookDetailsProvider(book.id));
                      for (final ch in chapters) {
                        ref.invalidate(readerChapterContentProvider(ch));
                      }
                      final stillFailing = retry.whereType<Failure>().length;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            stillFailing == 0
                                ? 'Redownloaded ${chapters.length} chapters'
                                : 'Redownloaded ${chapters.length - stillFailing}/${chapters.length} chapters ($stillFailing failed)',
                          ),
                        ),
                      );
                    } finally {
                      if (context.mounted) {
                        isRedownloading.value = false;
                        progress.value = null;
                      }
                    }
                  }()),
          ),
        ),
      );
    } finally {
      if (context.mounted) {
        isRedownloading.value = false;
        progress.value = null;
      }
    }
  }
}
