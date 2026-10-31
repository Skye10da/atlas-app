import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/providers/book_providers.dart';
import 'package:atlas_app/library/presentation/providers/chapter_download_provider.dart';
import 'package:atlas_app/library/presentation/widgets/batch_download_sheet.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

enum _ChapterFilter {
  all('All'),
  fresh('New'),
  unread('Unread'),
  downloaded('Downloaded');

  const _ChapterFilter(this.label);
  final String label;
}

enum _CellState { read, current, fresh, unread }

/// Chapter picker shared by every layout: chapters as a grid of number cells,
/// grouped into ranges ("arcs"), newest range first.
///
/// Cell states: read, current, new, unread (plus a dot when downloaded). The
/// range holding the reader's position is open by default; on wider panes the
/// two ranges before it are open too. Number of columns follows the width.
class ChapterNumberPicker extends HookConsumerWidget {
  const ChapterNumberPicker({super.key, required this.book});

  final BookEntity book;

  static const double _gap = 8;
  static const double _minCell = 46;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(bookChaptersProvider(book.id));
    final lastRead = ref.watch(lastReadChapterProvider(book.id)).valueOrNull;
    final filter = useState(_ChapterFilter.all);
    final expanded = useState<Set<int>?>(null);
    // Newest range first by default; toggled to oldest-first with the sort
    // button in the section header.
    final sortDesc = useState(true);
    final jump = useTextEditingController();

    return chaptersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: AppLoading(),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (chapters) {
        if (chapters.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final total = chapters.length;
        final currentIndex = lastRead?.index;
        final newStart = book.newChapterCount > 0
            ? total - book.newChapterCount
            : total;

        _CellState stateOf(ChapterEntity c) {
          if (currentIndex != null && c.index == currentIndex) {
            return _CellState.current;
          }
          if (currentIndex != null && c.index < currentIndex) {
            return _CellState.read;
          }
          if (c.index >= newStart) return _CellState.fresh;
          return _CellState.unread;
        }

        bool isDownloaded(ChapterEntity c) =>
            c.contentState == ContentState.availableOffline.index;

        bool matches(ChapterEntity c) => switch (filter.value) {
          _ChapterFilter.all => true,
          _ChapterFilter.fresh => stateOf(c) == _CellState.fresh,
          _ChapterFilter.unread =>
            stateOf(c) == _CellState.unread || stateOf(c) == _CellState.fresh,
          _ChapterFilter.downloaded => isDownloaded(c),
        };

        final groupSize = total <= 100 ? 10 : (total <= 500 ? 50 : 100);
        final groupCount = (total / groupSize).ceil();
        final downloadedCount = chapters.where(isDownloaded).length;

        void open(ChapterEntity c) =>
            context.push('/reader/${book.id}?chapterId=${c.id}');

        void jumpTo(String value) {
          final n = int.tryParse(value.trim());
          final target = n == null
              ? null
              : chapters.where((c) => c.index == n - 1).firstOrNull;
          if (target == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No chapter ${value.trim()} (1 – $total)')),
            );
            return;
          }
          jump.clear();
          open(target);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth - AppSpacing.md * 2;
            final cols = ((width + _gap) / (_minCell + _gap)).floor().clamp(
              4,
              12,
            );
            final cellWidth = (width - (cols - 1) * _gap) / cols;

            // Default: the group with the reader's position; on wider panes
            // also the two groups before it.
            final currentGroup = currentIndex == null
                ? 0
                : (currentIndex ~/ groupSize).clamp(0, groupCount - 1);
            final defaults = <int>{
              currentGroup,
              if (width >= 380) currentGroup - 1,
              if (width >= 380) currentGroup - 2,
            }..removeWhere((g) => g < 0 || g >= groupCount);
            final openGroups = expanded.value ?? defaults;

            void toggle(int g) {
              final next = Set<int>.from(openGroups);
              if (!next.remove(g)) next.add(g);
              expanded.value = next;
            }

            final groupWidgets = <Widget>[];
            final orderedGroups = sortDesc.value
                ? [for (var i = groupCount - 1; i >= 0; i--) i]
                : [for (var i = 0; i < groupCount; i++) i];
            for (final g in orderedGroups) {
              final start = g * groupSize;
              final end = (start + groupSize - 1).clamp(0, total - 1);
              final inGroup = chapters
                  .where((c) => c.index >= start && c.index <= end)
                  .toList();
              final visible = inGroup.where(matches).toList();
              if (visible.isEmpty) continue;
              final isOpen = openGroups.contains(g);
              final readCount = currentIndex == null
                  ? 0
                  : inGroup.where((c) => c.index <= currentIndex).length;

              groupWidgets.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: isOpen
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _GroupHeader(
                              title: 'Ch. ${start + 1} – ${end + 1}',
                              trailing: '$readCount / ${inGroup.length} read',
                              open: true,
                              onTap: () => toggle(g),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: _gap,
                              runSpacing: _gap,
                              children: [
                                // Cells are index-ascending; newest-first also
                                // reverses the order inside the open range.
                                for (final c in sortDesc.value
                                    ? visible.reversed
                                    : visible)
                                  _ChapterCell(
                                    width: cellWidth,
                                    chapter: c,
                                    state: stateOf(c),
                                    downloaded: isDownloaded(c),
                                    onTap: () => open(c),
                                  ),
                              ],
                            ),
                          ],
                        )
                      : _CollapsedGroup(
                          title: 'Ch. ${start + 1} – ${end + 1}',
                          trailing: '$readCount / ${inGroup.length} read',
                          progress: inGroup.isEmpty
                              ? 0
                              : readCount / inGroup.length,
                          onTap: () => toggle(g),
                        ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Chapters',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFamily: 'Fraunces',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          '$downloadedCount / $total saved',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Matches the _DownloadAllButton tonal affordance
                      // beside it: primary-coloured icon on the same 40px
                      // visual row.
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          foregroundColor: cs.primary,
                          iconSize: 20,
                        ),
                        tooltip: sortDesc.value ? 'Newest first' : 'Oldest first',
                        icon: Icon(
                          sortDesc.value
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                        ),
                        onPressed: () => sortDesc.value = !sortDesc.value,
                      ),
                      if (downloadedCount < total)
                        _DownloadAllButton(book: book, chapters: chapters),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in _ChapterFilter.values)
                        ChoiceChip(
                          label: Text(f.label),
                          selected: filter.value == f,
                          onSelected: (_) => filter.value = f,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.smMd),
                  TextField(
                    controller: jump,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.go,
                    onSubmitted: jumpTo,
                    decoration: InputDecoration(
                      hintText: 'Jump to chapter…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (groupWidgets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Text(
                        'No chapters match this filter.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ...groupWidgets,
                  const _Legend(),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.trailing,
    required this.open,
    required this.onTap,
  });

  final String title;
  final String trailing;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      button: true,
      expanded: open,
      label: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                open ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                trailing,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsedGroup extends StatelessWidget {
  const _CollapsedGroup({
    required this.title,
    required this.trailing,
    required this.progress,
    required this.onTap,
  });

  final String title;
  final String trailing;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      button: true,
      expanded: false,
      label: title,
      child: Material(
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      trailing,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterCell extends StatelessWidget {
  const _ChapterCell({
    required this.width,
    required this.chapter,
    required this.state,
    required this.downloaded,
    required this.onTap,
  });

  final double width;
  final ChapterEntity chapter;
  final _CellState state;
  final bool downloaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (Color bg, Color fg, Border? border, List<BoxShadow>? ring) =
        switch (state) {
          _CellState.current => (
            cs.primary,
            cs.onPrimary,
            null,
            [BoxShadow(color: cs.primary.withValues(alpha: 0.3), spreadRadius: 3)],
          ),
          _CellState.read => (
            cs.primaryContainer.withValues(alpha: 0.65),
            cs.onPrimaryContainer,
            null,
            null,
          ),
          _CellState.fresh => (
            cs.surfaceContainerLow,
            cs.onSurface,
            Border.all(color: cs.tertiary, width: 1.5),
            null,
          ),
          _CellState.unread => (
            cs.surfaceContainerLow,
            cs.onSurfaceVariant,
            Border.all(color: cs.outlineVariant),
            null,
          ),
        };

    final label = switch (state) {
      _CellState.current => 'current',
      _CellState.read => 'read',
      _CellState.fresh => 'new',
      _CellState.unread => 'unread',
    };

    return Semantics(
      button: true,
      label: 'Chapter ${chapter.index + 1}, $label'
          '${downloaded ? ', downloaded' : ''}',
      excludeSemantics: true,
      child: Tooltip(
        message: chapter.title,
        waitDuration: const Duration(milliseconds: 600),
        child: SizedBox(
          width: width,
          height: 40,
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: border,
                boxShadow: ring,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '${chapter.index + 1}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    if (downloaded)
                      Positioned(
                        right: 5,
                        bottom: 5,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: state == _CellState.current ? fg : cs.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadAllButton extends ConsumerWidget {
  const _DownloadAllButton({required this.book, required this.chapters});

  final BookEntity book;
  final List<ChapterEntity> chapters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(isBatchDownloadingProvider(book.id));
    return TextButton.icon(
      onPressed: busy
          ? null
          : () => BatchDownloadSheet.show(
              context,
              book: book,
              chapters: chapters,
            ),
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded, size: 18),
      label: Text(busy ? 'Downloading…' : 'Download'),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    Widget item(Color color, String text, {Border? border}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: border,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          item(cs.primaryContainer, 'read'),
          item(cs.primary, 'current'),
          item(
            Colors.transparent,
            'new',
            border: Border.all(color: cs.tertiary, width: 1.5),
          ),
          item(
            Colors.transparent,
            'unread',
            border: Border.all(color: cs.outlineVariant),
          ),
        ],
      ),
    );
  }
}
