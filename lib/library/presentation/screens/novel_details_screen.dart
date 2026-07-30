import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/library/presentation/widgets/novel/genre_tag_row.dart';
import 'package:atlas_app/library/presentation/widgets/novel/novel_hero_header.dart';
import 'package:atlas_app/library/presentation/widgets/novel/source_attribution.dart';
import 'package:atlas_app/library/presentation/widgets/novel/synopsis_card.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

class NovelDetailsScreen extends ConsumerStatefulWidget {
  const NovelDetailsScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<NovelDetailsScreen> createState() => _NovelDetailsScreenState();
}

class _NovelDetailsScreenState extends ConsumerState<NovelDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final repo = DriftLibraryRepository(db);

    return FutureBuilder<Result<BookEntity>>(
      future: repo.getBookById(widget.bookId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: AppLoading());
        }

        final bookData = snapshot.data;
        if (bookData is! Success<BookEntity>) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Failed to load novel')),
          );
        }

        final book = bookData.value;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 360,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: NovelHeroHeader(book: book),
                ),
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    GenreTagRow(book: book),
                    const SizedBox(height: AppSpacing.lg),
                    SynopsisCard(book: book),
                    const SizedBox(height: AppSpacing.lg),
                    SourceAttribution(book: book),
                    const SizedBox(height: AppSpacing.lg),
                    _ChapterSectionHeader(
                      bookId: widget.bookId,
                      totalChapters: book.totalChapters,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ChapterPanel(bookId: widget.bookId),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChapterSectionHeader extends ConsumerWidget {
  const _ChapterSectionHeader({
    required this.bookId,
    required this.totalChapters,
  });

  final String bookId;
  final int totalChapters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(novelChaptersProvider(bookId));
    final downloadingSet = ref.watch(chapterDownloadingSetProvider);
    final isDownloadingAll = chapters.maybeWhen(
      data: (list) => list.any((ch) => downloadingSet.contains(ch.id)),
      orElse: () => false,
    );

    final downloadedCount = chapters.maybeWhen(
      data: (list) => list.where((ch) => ch.contentState == ContentState.availableOffline.index).length,
      orElse: () => 0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Text(
            'Chapters',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
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
                    : () => _downloadAll(ref, bookId),
                icon: isDownloadingAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(
                  isDownloadingAll ? 'Downloading...' : 'All',
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

  Future<void> _downloadAll(WidgetRef ref, String bookId) async {
    final service = ref.read(chapterDownloadServiceProvider);
    final downloadingSet = ref.read(chapterDownloadingSetProvider.notifier);
    final chapters = await ref.read(novelChaptersProvider(bookId).future);
    final notDownloaded = chapters
        .where((ch) => ch.contentState != ContentState.availableOffline.index)
        .toList();

    for (final ch in notDownloaded) {
      downloadingSet.update((set) => set..add(ch.id));
    }

    await service.downloadAllChapters(bookId);

    for (final ch in notDownloaded) {
      downloadingSet.update((set) => set..remove(ch.id));
    }

    ref.invalidate(novelChaptersProvider(bookId));
  }
}

class _ChapterPanel extends ConsumerStatefulWidget {
  const _ChapterPanel({required this.bookId});

  final String bookId;

  @override
  ConsumerState<_ChapterPanel> createState() => _ChapterPanelState();
}

class _ChapterPanelState extends ConsumerState<_ChapterPanel> {
  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(novelChaptersProvider(widget.bookId));
    final downloadingSet = ref.watch(chapterDownloadingSetProvider);

    return chaptersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: AppLoading(),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (chapters) {
        if (chapters.isEmpty) return const SizedBox.shrink();
        final totalChapters = chapters.first.totalChapters;
        final groups = _groupChapters(totalChapters);
        final colors = Theme.of(context).colorScheme;

        return Column(
          children: groups.map((group) {
            final isFirst = group == groups.first;
            return _ChapterGroup(
              title: group.title,
              chapters: chapters.where((c) => c.index >= group.start && c.index <= group.end).toList(),
              isFirst: isFirst,
              isLast: group == groups.last,
              colors: colors,
              downloadingSet: downloadingSet,
              onTap: (chapterIndex) {
                context.push('/reader/${widget.bookId}?chapter=$chapterIndex');
              },
              onDownload: (chapterIndex) => _downloadChapter(chapterIndex),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _downloadChapter(int chapterIndex) async {
    final service = ref.read(chapterDownloadServiceProvider);
    final downloadingSet = ref.read(chapterDownloadingSetProvider.notifier);
    final chapters = await ref.read(novelChaptersProvider(widget.bookId).future);
    final ch = chapters.firstWhere((c) => c.index == chapterIndex);

    downloadingSet.update((set) => set..add(ch.id));

    await service.downloadChapter(widget.bookId, chapterIndex);

    downloadingSet.update((set) => set..remove(ch.id));
    ref.invalidate(novelChaptersProvider(widget.bookId));
  }

  List<_ChapterGroupInfo> _groupChapters(int total) {
    final groupSize = total <= 100 ? 10 : (total <= 500 ? 50 : 100);
    final groups = <_ChapterGroupInfo>[];
    for (int start = 0; start < total; start += groupSize) {
      final end = min(start + groupSize - 1, total - 1);
      final label = total <= 100
          ? '${start + 1} - ${end + 1}'
          : 'Ch. ${start + 1} - ${end + 1}';
      groups.add(_ChapterGroupInfo(title: label, start: start, end: end));
    }
    return groups;
  }
}

class _ChapterGroupInfo {
  const _ChapterGroupInfo({required this.title, required this.start, required this.end});
  final String title;
  final int start;
  final int end;
}

class _ChapterGroup extends StatefulWidget {
  const _ChapterGroup({
    required this.title,
    required this.chapters,
    required this.isFirst,
    required this.isLast,
    required this.colors,
    required this.downloadingSet,
    required this.onTap,
    required this.onDownload,
  });

  final String title;
  final List<ChapterEntity> chapters;
  final bool isFirst;
  final bool isLast;
  final ColorScheme colors;
  final Set<String> downloadingSet;
  final void Function(int chapterIndex) onTap;
  final void Function(int chapterIndex) onDownload;

  @override
  State<_ChapterGroup> createState() => _ChapterGroupState();
}

class _ChapterGroupState extends State<_ChapterGroup> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isFirst || widget.isLast;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppSpacing.md,
        widget.isFirst ? 0 : AppSpacing.xs,
        AppSpacing.md,
        widget.isLast ? 0 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: widget.colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Text(
                    widget.title,
                    style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.chapters.length}',
                    style: textTheme.bodySmall?.copyWith(color: widget.colors.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: widget.colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            ...widget.chapters.map((ch) => _ChapterTile(
              chapter: ch,
              isDownloading: widget.downloadingSet.contains(ch.id),
              onTap: () => widget.onTap(ch.index),
              onDownload: ch.contentState != ContentState.availableOffline.index
                  ? () => widget.onDownload(ch.index)
                  : null,
            )),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.isDownloading,
    required this.onTap,
    this.onDownload,
  });

  final ChapterEntity chapter;
  final bool isDownloading;
  final VoidCallback onTap;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDownloaded = chapter.contentState == ContentState.availableOffline.index;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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
                  ? Icon(Icons.check, size: 14, color: colors.onPrimaryContainer)
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
                  color: isDownloaded ? colors.onSurface : colors.onSurface.withValues(alpha: 0.7),
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
                  style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
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
            else if (onDownload != null)
              IconButton(
                onPressed: onDownload,
                icon: Icon(Icons.download_rounded, size: 18, color: colors.primary),
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
