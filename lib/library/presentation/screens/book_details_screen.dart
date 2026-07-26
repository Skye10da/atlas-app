import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';

class BookDetailsScreen extends ConsumerWidget {
  const BookDetailsScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(_bookDetailsProvider(bookId));

    return bookAsync.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (err, _) => Scaffold(
        body: AppErrorState(
          message: 'Could not load book details.',
          technicalDetails: err.toString(),
        ),
      ),
      data: (result) => switch (result) {
        Success(value: final data) => _BookDetailsView(
            book: data.book,
            chapters: data.chapters,
            lastReadChapterIndex: data.lastReadChapterIndex,
            onDelete: () async {
              final db = ref.read(databaseProvider);
              final repo = DriftLibraryRepository(db);
              final r = await repo.deleteBook(bookId);
              if (context.mounted) {
                if (r is Success) {
                  ref.invalidate(libraryBooksProvider);
                  context.pop();
                } else if (r is Failure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(r.error.userMessage)),
                  );
                }
              }
            },
          ),
        Failure(error: final err) => Scaffold(
            body: AppErrorState(
              message: err.userMessage,
              technicalDetails: err.message,
            ),
          ),
      },
    );
  }
}

final _bookDetailsProvider =
    FutureProvider.family<Result<_BookDetailsData>, String>(
        (ref, bookId) async {
  final db = ref.watch(databaseProvider);
  final libRepo = DriftLibraryRepository(db);
  final readerRepo = DriftReaderRepository(db);

  final booksResult = await libRepo.getBookById(bookId);
  if (booksResult is Failure<BookEntity>) {
    return Failure<_BookDetailsData>(booksResult.error, booksResult.stackTrace);
  }

  final book = (booksResult as Success<BookEntity>).value;

  final chaptersResult = await readerRepo.getChapters(bookId);
  if (chaptersResult is Failure<List<ChapterEntity>>) {
    return Failure<_BookDetailsData>(
        chaptersResult.error, chaptersResult.stackTrace);
  }

  final chapters = (chaptersResult as Success<List<ChapterEntity>>).value;

  final progressRow = await db.getReadingProgress(bookId);
  final lastReadChapterIndex = progressRow != null
      ? chapters.indexWhere((c) => c.id == progressRow.chapterId)
      : -1;

  return Success(_BookDetailsData(
    book: book,
    chapters: chapters,
    lastReadChapterIndex: lastReadChapterIndex >= 0 ? lastReadChapterIndex : null,
  ));
});

class _BookDetailsData {
  const _BookDetailsData({
    required this.book,
    required this.chapters,
    this.lastReadChapterIndex,
  });
  final BookEntity book;
  final List<ChapterEntity> chapters;
  final int? lastReadChapterIndex;
}

class _BookDetailsView extends StatelessWidget {
  const _BookDetailsView({
    required this.book,
    required this.chapters,
    required this.onDelete,
    this.lastReadChapterIndex,
  });

  final BookEntity book;
  final List<ChapterEntity> chapters;
  final VoidCallback onDelete;
  final int? lastReadChapterIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = book.progress ?? 0;
    const headerHeight = 320.0;

    return Scaffold(
      body: ListView(
        children: [
          SizedBox(
            height: headerHeight,
            child: Stack(
              children: [
                if (book.coverPath != null)
                  Positioned.fill(
                    child: ImageFiltered(
                      imageFilter:
                          ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Image.file(
                        File(book.coverPath!),
                        fit: BoxFit.cover,
                        cacheWidth: (MediaQuery.of(context).size.width * 3).round(),
                        cacheHeight: (headerHeight * 3).round(),
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.white),
                          onPressed: () => _deleteBook(context),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Hero(
                        tag: 'book-cover-${book.id}',
                        child: BookCover(
                          coverPath: book.coverPath,
                          width: 100,
                          height: 150,
                          format: book.format,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              book.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (book.author != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                book.author!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                book.format.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _openReader(context),
                                icon: Icon(
                                  progress > 0
                                      ? Icons.play_arrow
                                      : Icons.menu_book,
                                ),
                                label: Text(progress > 0
                                    ? 'Continue Reading'
                                    : 'Start Reading'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (progress > 0 && progress < 100)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
              child: _ProgressCard(
                  progress: progress, totalChapters: book.totalChapters),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Icon(Icons.list_alt,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${chapters.length} Chapter${chapters.length == 1 ? '' : 's'}',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          ...chapters.map((ch) => _ChapterTile(
                chapter: ch,
                lastReadChapterIndex: lastReadChapterIndex,
                onTap: () =>
                    _openReader(context, chapterIndex: ch.index),
              )),
          const SizedBox(height: AppSpacing.xl * 2),
        ],
      ),
    );
  }

  void _openReader(BuildContext context, {int? chapterIndex}) {
    final uri =
        '/reader/${book.id}${chapterIndex != null ? '?chapter=$chapterIndex' : ''}';
    context.push(uri);
  }

  void _deleteBook(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete book?'),
        content: const Text(
            'This will permanently remove the book and all reading progress.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
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
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard(
      {required this.progress, required this.totalChapters});

  final double progress;
  final int totalChapters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Reading Progress', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${progress.round()}% complete · $totalChapters chapters',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.onTap,
    this.lastReadChapterIndex,
  });

  final ChapterEntity chapter;
  final VoidCallback onTap;
  final int? lastReadChapterIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRead = lastReadChapterIndex != null && chapter.index < lastReadChapterIndex!;
    final isCurrent = chapter.index == lastReadChapterIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ListTile(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: isCurrent
                ? theme.colorScheme.primary
                : isRead
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
            child: isRead
                ? Icon(Icons.check, size: 14,
                    color: theme.colorScheme.onPrimaryContainer)
                : Text(
                    '${chapter.index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isCurrent
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          title: Text(
            chapter.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w600 : null,
              color: isRead ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
          trailing: Icon(Icons.chevron_right,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        ),
      ),
    );
  }
}
