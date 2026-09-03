import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:atlas_app/core/design_system/atoms/book_badge.dart';
import 'package:atlas_app/core/design_system/molecules/app_search_bar.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';

/// The chapter-list bottom sheet previously duplicated verbatim as
/// `_showChapterIndex` in both ContinuousReaderLayout and PagedReaderLayout.
/// The only thing that differed between the two call sites was what
/// happens on tap (scroll-to-chapter vs. page-jump-to-chapter), which is
/// now just [onChapterTap].
class ChapterIndexSheet extends HookWidget {
  const ChapterIndexSheet({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterTap,
  });

  final List<ChapterEntity> chapters;
  final int currentChapterIndex;
  final void Function(int index) onChapterTap;

  /// One-line [ListTile] (56) plus the trailing [Divider] (1). A fixed
  /// extent keeps [ListView] lazy while still knowing the full scroll range
  /// on the first frame, so the current chapter can be reached reliably.
  static const _itemExtent = 57.0;

  static void show(
    BuildContext context, {
    required String sheetId,
    required List<ChapterEntity> chapters,
    required int currentChapterIndex,
    required void Function(int index) onChapterTap,
  }) {
    AppSheet.show(
      context: context,
      id: sheetId,
      title: 'Chapters',
      initialHeight: 0.5,
      child: ChapterIndexSheet(
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        onChapterTap: onChapterTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollController = useScrollController(
      initialScrollOffset: currentChapterIndex * _itemExtent,
    );
    final searchController = useTextEditingController();
    final query = useState('');

    void centerOnCurrent([int attempt = 0]) {
      if (!context.mounted || !scrollController.hasClients) {
        if (attempt < 3) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => centerOnCurrent(attempt + 1),
          );
        }
        return;
      }
      final viewportHeight = scrollController.position.viewportDimension;
      final targetOffset =
          (currentChapterIndex * _itemExtent) -
          (viewportHeight / 2) +
          (_itemExtent / 2);
      final maxScroll = scrollController.position.maxScrollExtent;
      final clamped = targetOffset.clamp(0.0, maxScroll);
      scrollController.jumpTo(clamped);
    }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) => centerOnCurrent());
      return null;
    }, const []);

    final q = query.value.trim().toLowerCase();
    final matches = useMemoized(() {
      if (q.isEmpty) {
        return [
          for (var i = 0; i < chapters.length; i++)
            (i, chapters[i]),
        ];
      }
      return [
        for (var i = 0; i < chapters.length; i++)
          if (chapters[i].title.toLowerCase().contains(q))
            (i, chapters[i]),
      ];
    }, [q, chapters]);

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AppSearchBar(
            controller: searchController,
            hint: 'Filter chapters…',
            onChanged: (val) => query.value = val,
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            itemCount: matches.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final (originalIndex, chapter) = matches[i];
              final isCurrent = originalIndex == currentChapterIndex;
              final isRead = originalIndex < currentChapterIndex;
              final chapterNum = originalIndex + 1;

              final (statusBadge, badgeVariant) = switch (chapter.contentState) {
                1 => ('Processing', BookBadgeVariant.secondary),
                3 => ('Error', BookBadgeVariant.error),
                _ => (null, BookBadgeVariant.neutral),
              };

              return ListTile(
                selected: isCurrent,
                selectedTileColor: colorScheme.primary.withValues(alpha: 0.08),
                selectedColor: colorScheme.primary,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: isCurrent
                      ? colorScheme.primary
                      : isRead
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : colorScheme.surfaceContainerHighest,
                  child: isRead
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: colorScheme.primary,
                        )
                      : Text(
                          '$chapterNum',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isCurrent
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chapter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isCurrent
                              ? colorScheme.primary
                              : isRead
                              ? colorScheme.onSurface.withValues(alpha: 0.7)
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (statusBadge != null) ...[
                      const SizedBox(width: 8),
                      BookBadge(
                        label: statusBadge,
                        variant: badgeVariant,
                        isCompact: true,
                      ),
                    ],
                  ],
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onChapterTap(originalIndex);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
