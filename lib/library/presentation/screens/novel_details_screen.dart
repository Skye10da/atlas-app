import 'dart:async';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/atoms/book_badge.dart';
import 'package:atlas_app/core/design_system/molecules/confirm_delete_dialog.dart';
import 'package:atlas_app/core/design_system/molecules/milestone_celebration_dialog.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/router/navigation.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/library/presentation/providers/book_providers.dart';
import 'package:atlas_app/library/presentation/providers/chapter_download_provider.dart';
import 'package:atlas_app/library/presentation/providers/chapter_expansion_provider.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/library/presentation/providers/novel_actions_controller.dart';
import 'package:atlas_app/library/presentation/widgets/batch_download_sheet.dart';
import 'package:atlas_app/library/presentation/widgets/import_progress_dialog.dart';
import 'package:atlas_app/library/presentation/widgets/novel/continue_reading_card.dart';
import 'package:atlas_app/library/presentation/widgets/novel/genre_tag_row.dart';
import 'package:atlas_app/library/presentation/widgets/novel/novel_hero_header.dart';
import 'package:atlas_app/library/presentation/widgets/novel/source_attribution.dart';
import 'package:atlas_app/library/presentation/widgets/novel/synopsis_card.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_novel_identity.dart';
import 'package:atlas_app/wtr/presentation/widgets/wtr_translation_selector.dart';

class NovelDetailsScreen extends HookConsumerWidget {
  const NovelDetailsScreen({
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
    useEffect(() {
      unawaited(
        ref.read(novelActionsControllerProvider.notifier).acknowledgeUpdates(bookId),
      );
      return null;
    }, [bookId]);

    final bookAsync = ref.watch(bookDetailsProvider(bookId));
    final actionsState = ref.watch(novelActionsControllerProvider);
    final isDesktop = AppBreakpoints.isDesktop(context);

    return bookAsync.when(
      loading: () => isEmbedded
          ? const Center(child: CircularProgressIndicator())
          : const Scaffold(body: AppLoading()),
      error: (err, _) => isEmbedded
          ? Center(child: Text('Failed to load novel: $err'))
          : Scaffold(
              appBar: AppBar(),
              body: Center(child: Text('Failed to load novel: $err')),
            ),
      data: (book) {
        final isWtrLab = isWtrLabSource(
          sourceUrl: book.sourceUrl,
          sourceName: book.sourceName,
        );
        final wtrRawId = isWtrLab
            ? wtrRawIdOf(sourceId: book.sourceId, sourceUrl: book.sourceUrl)
            : null;

        final scrollView = CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: isEmbedded ? 240 : 360,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: NovelHeroHeader(
                  book: book,
                  isEmbedded: isEmbedded,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              leading: isEmbedded
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    )
                  : null,
              actions: [
                IconButton(
                  icon: actionsState.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: 'Check for updates',
                  onPressed: actionsState.isLoading
                      ? null
                      : () => ref
                          .read(novelActionsControllerProvider.notifier)
                          .checkForUpdates(context, bookId),
                ),
                if (book.isNovel)
                  IconButton(
                    icon: Icon(
                      book.updateTrackingEnabled
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                    ),
                    tooltip: book.updateTrackingEnabled
                        ? 'Stop tracking updates'
                        : 'Track updates',
                    onPressed: () async {
                      final db = ref.read(databaseProvider);
                      await DriftLibraryRepository(db).setUpdateTracking(
                        book.id,
                        !book.updateTrackingEnabled,
                      );
                      ref.invalidate(bookDetailsProvider(bookId));
                      ref.invalidate(libraryBooksProvider);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.file_upload_outlined),
                  tooltip: 'Export',
                  onPressed: () => _exportNovel(context, ref, book),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete novel',
                  onPressed: () => _confirmDelete(context, ref, bookId),
                ),
                const SizedBox(width: 4),
              ],
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  if (wtrRawId != null)
                    WtrTranslationSelector(
                      rawId: wtrRawId,
                      onServiceChanged: () => ref
                          .read(novelActionsControllerProvider.notifier)
                          .changeWtrService(bookId),
                    ),
                  if (wtrRawId != null) const SizedBox(height: AppSpacing.sm),
                  ContinueReadingCard(book: book),
                  const SizedBox(height: AppSpacing.sm),
                  _ReadingTriviaCard(book: book),
                  const SizedBox(height: AppSpacing.sm),
                  GenreTagRow(book: book),
                  const SizedBox(height: AppSpacing.lg),
                  SynopsisCard(book: book),
                  const SizedBox(height: AppSpacing.lg),
                  SourceAttribution(book: book),
                  const SizedBox(height: AppSpacing.lg),
                  _ChapterSectionHeader(
                    book: book,
                    totalChapters: book.totalChapters,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ChapterPanel(bookId: bookId),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        );

        final refreshableScrollView = RefreshIndicator(
          onRefresh: () => ref
              .read(novelActionsControllerProvider.notifier)
              .checkForUpdates(context, bookId, showSnackbars: false),
          child: scrollView,
        );

        if (isEmbedded) return refreshableScrollView;

        return Scaffold(
          body: isDesktop
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: refreshableScrollView,
                  ),
                )
              : refreshableScrollView,
        );
      },
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String bookId,
  ) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete novel?',
      message: 'This will permanently remove the novel and all reading progress.',
      confirmLabel: 'Delete',
    );
    if (confirmed == true && context.mounted) {
      final db = ref.read(databaseProvider);
      final repo = DriftLibraryRepository(db);
      final r = await repo.deleteBook(bookId);
      if (context.mounted) {
        if (r is Success) {
          ref.invalidate(libraryBooksProvider);
          popOrGoToLibrary(context);
        } else if (r is Failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(r.error.userMessage)),
          );
        }
      }
    }
  }

  static Future<void> _exportNovel(
    BuildContext context,
    WidgetRef ref,
    BookEntity book,
  ) async {
    final format = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _ExportFormatSheet(book: book),
    );
    if (format == null || !context.mounted) return;

    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null || !context.mounted) return;

    final service = ref.read(novelExportServiceProvider);
    final progress = ValueNotifier<double>(0);

    final Future<Result<String>> exportFuture;
    if (format == 'epub') {
      exportFuture = service.exportToEpub(
        bookId: book.id,
        outputDirectory: dir,
        onFetchProgress: (done, total) =>
            progress.value = total == 0 ? 1 : done / total,
      );
    } else {
      exportFuture = service.exportSourceLink(
        bookId: book.id,
        outputDirectory: dir,
      );
    }

    if (!context.mounted) {
      try {
        await exportFuture;
      } catch (_) {}
      return;
    }

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportProgressDialog(
        future: exportFuture,
        progress: progress,
        label: 'Exporting...',
      ),
    );

    if (!context.mounted) return;
    final result = await exportFuture;
    final message = switch (result) {
      Success(value: final path) => 'Exported to $path',
      Failure(error: final error) => error.userMessage,
    };
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ExportFormatSheet extends StatelessWidget {
  const _ExportFormatSheet({required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Export ${book.title}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            _listTile(
              icon: Icons.menu_book_rounded,
              iconColor: cs.primary,
              title: 'EPUB (full text)',
              subtitle: 'Self-contained offline file with every chapter.',
              onTap: () => Navigator.of(context).pop('epub'),
            ),
            _listTile(
              icon: Icons.link_rounded,
              iconColor: cs.tertiary,
              title: 'Atlas link (.atlas)',
              subtitle:
                  'Lightweight package relinking to the original source; '
                  'chapters re-fetch on demand.',
              onTap: () => Navigator.of(context).pop('atlas'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class _ChapterSectionHeader extends ConsumerWidget {
  const _ChapterSectionHeader({
    required this.book,
    required this.totalChapters,
  });

  final BookEntity book;
  final int totalChapters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(bookChaptersProvider(book.id));
    final isDownloadingAll = ref.watch(isBatchDownloadingProvider(book.id));

    final downloadedCount = chaptersAsync.maybeWhen(
      data: (list) => list
          .where((ch) => ch.contentState == ContentState.availableOffline.index)
          .length,
      orElse: () => 0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Text(
            'Chapters',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            '$downloadedCount / $totalChapters',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (downloadedCount < totalChapters) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 28,
              child: TextButton.icon(
                onPressed: isDownloadingAll
                    ? null
                    : () {
                        final list = chaptersAsync.valueOrNull ?? [];
                        BatchDownloadSheet.show(
                          context,
                          book: book,
                          chapters: list,
                        );
                      },
                icon: isDownloadingAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(
                  isDownloadingAll ? 'Downloading...' : 'Download',
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChapterPanel extends ConsumerWidget {
  const _ChapterPanel({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(bookChaptersProvider(bookId));

    return chaptersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: AppLoading(),
      ),
      error: (error, stack) => const SizedBox.shrink(),
      data: (chapters) {
        if (chapters.isEmpty) return const SizedBox.shrink();
        final totalChapters = chapters.length;
        final groups = _groupChapters(totalChapters);

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final groupChapters = chapters
                .where((c) => c.index >= group.start && c.index <= group.end)
                .toList();

            return _ChapterGroup(
              bookId: bookId,
              groupIndex: index,
              title: group.title,
              chapters: groupChapters,
              isFirst: index == 0,
              isLast: index == groups.length - 1,
            );
          },
        );
      },
    );
  }

  List<({String title, int start, int end})> _groupChapters(int total) {
    final groupSize = total <= 100 ? 10 : (total <= 500 ? 50 : 100);
    final groups = <({String title, int start, int end})>[];
    for (int start = 0; start < total; start += groupSize) {
      final end = min(start + groupSize - 1, total - 1);
      final label = total <= 100
          ? '${start + 1} - ${end + 1}'
          : 'Ch. ${start + 1} - ${end + 1}';
      groups.add((title: label, start: start, end: end));
    }
    return groups;
  }
}

class _ChapterGroup extends ConsumerWidget {
  const _ChapterGroup({
    required this.bookId,
    required this.groupIndex,
    required this.title,
    required this.chapters,
    required this.isFirst,
    required this.isLast,
  });

  final String bookId;
  final int groupIndex;
  final String title;
  final List<ChapterEntity> chapters;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupKey = '$bookId:$groupIndex';
    final isExpanded = ref.watch(chapterGroupExpandedProvider(groupKey));
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppSpacing.md,
        isFirst ? 0 : AppSpacing.xs,
        AppSpacing.md,
        isLast ? 0 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              ref.read(chapterGroupExpandedProvider(groupKey).notifier).state =
                  !isExpanded;
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    title,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${chapters.length}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final ch = chapters[index];
                return _ChapterTile(
                  bookId: bookId,
                  chapter: ch,
                  onTap: () => context.push(
                    '/reader/$bookId?chapterId=${ch.id}',
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ChapterTile extends ConsumerWidget {
  const _ChapterTile({
    required this.bookId,
    required this.chapter,
    required this.onTap,
  });

  final String bookId;
  final ChapterEntity chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDownloading = ref.watch(
      isChapterDownloadingProvider(chapter.id),
    );
    final colors = Theme.of(context).colorScheme;
    final isDownloaded =
        chapter.contentState == ContentState.availableOffline.index;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDownloaded
                    ? colors.primaryContainer
                    : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isDownloaded
                  ? Icon(
                      Icons.check,
                      size: 14,
                      color: colors.onPrimaryContainer,
                    )
                  : Text(
                      '${chapter.index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                chapter.title,
                style: TextStyle(
                  fontSize: 14,
                  color: isDownloaded
                      ? colors.onSurface
                      : colors.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (chapter.wordCount > 0 && !isDownloading)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  _formatWords(chapter.wordCount),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            if (isDownloading)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (!isDownloaded)
              IconButton(
                onPressed: () => ref
                    .read(chapterDownloadControllerProvider.notifier)
                    .downloadSingle(bookId, chapter),
                icon: Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: colors.primary,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Download chapter',
              ),
          ],
        ),
      ),
    );
  }

  String _formatWords(int count) {
    if (count < 1000) return '${count}w';
    return '${(count / 1000).toStringAsFixed(1)}kw';
  }
}

class _ReadingTriviaCard extends StatelessWidget {
  const _ReadingTriviaCard({required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final progressPct = ((book.progress ?? 0.0) * 100).toInt().clamp(0, 100);
    final totalCh = book.totalChapters;
    final readCh = (totalCh * (progressPct / 100)).round();
    final remainingCh = (totalCh - readCh).clamp(0, totalCh);
    final estMinutes = remainingCh * 3;
    final estHours = (estMinutes / 60).toStringAsFixed(1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        onTap: () {
          if (progressPct >= 100) {
            MilestoneCelebrationDialog.show(
              context,
              milestone: MilestoneType.firstBookFinished,
              customMessage: 'You finished reading ${book.title}! Outstanding journey.',
            );
          } else if (progressPct >= 50) {
            MilestoneCelebrationDialog.show(
              context,
              milestone: MilestoneType.hundredChapters,
              customMessage: 'Over half-way through ${book.title} ($progressPct%). Keep pushing forward!',
            );
          } else {
            MilestoneCelebrationDialog.show(
              context,
              milestone: MilestoneType.streakThreeDays,
              customMessage: 'Reading ${book.title} ($readCh / $totalCh chapters). Great momentum!',
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Reading Insights',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  BookBadge(
                    label: progressPct >= 100
                        ? 'Completed'
                        : (progressPct > 0 ? 'Reading' : 'Unread'),
                    variant: progressPct >= 100
                        ? BookBadgeVariant.tertiary
                        : (progressPct > 0
                            ? BookBadgeVariant.primary
                            : BookBadgeVariant.neutral),
                    isCompact: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.smMd),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _TriviaCol(label: 'Progress', value: '$progressPct%'),
                  _TriviaCol(label: 'Read', value: '$readCh / $totalCh'),
                  _TriviaCol(label: 'Est. Left', value: '${estHours}h'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TriviaCol extends StatelessWidget {
  const _TriviaCol({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
