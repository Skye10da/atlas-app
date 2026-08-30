import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/molecules/app_empty_state.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

class EnrichedBookmark {
  const EnrichedBookmark({
    required this.bookmark,
    this.book,
    this.chapter,
  });

  final BookmarkEntity bookmark;
  final BookEntity? book;
  final ChapterEntity? chapter;
}

final enrichedBookmarksProvider =
    FutureProvider<List<EnrichedBookmark>>((ref) async {
      final bookmarks = await ref.watch(allBookmarksProvider.future);
      if (bookmarks.isEmpty) return const [];

      final libRepo = ref.watch(libraryRepositoryProvider);
      final readerRepo = ref.watch(readerRepositoryProvider);

      final List<EnrichedBookmark> enriched = [];
      final Map<String, BookEntity?> bookCache = {};
      final Map<String, Map<String, ChapterEntity>> chapterCache = {};

      for (final bm in bookmarks) {
        if (!bookCache.containsKey(bm.bookId)) {
          final bookRes = await libRepo.getBookById(bm.bookId);
          bookCache[bm.bookId] =
              bookRes is Success<BookEntity> ? bookRes.value : null;
        }
        if (!chapterCache.containsKey(bm.bookId)) {
          final chRes = await readerRepo.getChapters(bm.bookId);
          chapterCache[bm.bookId] =
              chRes is Success<List<ChapterEntity>>
                  ? {for (final c in chRes.value) c.id: c}
                  : {};
        }
        final book = bookCache[bm.bookId];
        final chapter = chapterCache[bm.bookId]?[bm.chapterId];
        enriched.add(
          EnrichedBookmark(bookmark: bm, book: book, chapter: chapter),
        );
      }
      return enriched;
    });

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(enrichedBookmarksProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved Bookmarks',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: bookmarksAsync.when(
        loading: () => const AppLoading(),
        error: (_, _) => const AppEmptyState(
          title: 'Could not load bookmarks',
          icon: Icons.bookmark_border,
        ),
        data: (bookmarks) {
          if (bookmarks.isEmpty) {
            return const AppEmptyState(
              title: 'No bookmarks yet',
              message: 'Bookmark chapters while reading to see them here.',
              icon: Icons.bookmark_border,
            );
          }

          // Group bookmarks by bookId
          final grouped = <String, List<EnrichedBookmark>>{};
          for (final item in bookmarks) {
            grouped.putIfAbsent(item.bookmark.bookId, () => []).add(item);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            itemCount: grouped.length,
            itemBuilder: (context, groupIndex) {
              final entry = grouped.entries.elementAt(groupIndex);
              final bookItems = entry.value;
              final book = bookItems.first.book;
              final bookTitle = book?.title ?? 'Unknown Book';

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_stories,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              bookTitle,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${bookItems.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ...bookItems.map((item) {
                      final bm = item.bookmark;
                      final ch = item.chapter;
                      final chapterTitle =
                          ch?.title ??
                          (bm.position > 0
                              ? 'Chapter ${bm.position + 1}'
                              : 'Chapter');
                      final timeAgo = _formatTimestamp(bm.createdAt);

                      return Dismissible(
                        key: ValueKey(bm.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.borderRadiusMd,
                            ),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                        onDismissed: (_) async {
                          final repo = ref.read(readerRepositoryProvider);
                          await repo.removeBookmark(bm.id);
                          ref.invalidate(allBookmarksProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Bookmark removed'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () async {
                                    await repo.addBookmark(bm);
                                    ref.invalidate(allBookmarksProvider);
                                  },
                                ),
                              ),
                            );
                          }
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          elevation: 0,
                          color: colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.borderRadiusMd,
                            ),
                            side: BorderSide(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            leading: book?.coverPath != null
                                ? BookCover(
                                    coverPath: book!.coverPath,
                                    width: 38,
                                    height: 52,
                                  )
                                : CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        colorScheme.primaryContainer,
                                    child: Icon(
                                      Icons.bookmark_rounded,
                                      size: 18,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                            title: Text(
                              chapterTitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              children: [
                                if (bm.note != null && bm.note!.isNotEmpty) ...[
                                  Expanded(
                                    child: Text(
                                      bm.note!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                ],
                                Text(
                                  timeAgo,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            onTap: () => context.push(
                              '/reader/${bm.bookId}?chapterId=${bm.chapterId}',
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
