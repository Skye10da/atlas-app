import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';

int _groupSize(int total) {
  if (total <= 100) return 10;
  if (total <= 500) return 50;
  return 100;
}

List<List<ChapterEntity>> groupChapters(List<ChapterEntity> chapters) {
  final size = _groupSize(chapters.length);
  final groups = <List<ChapterEntity>>[];
  for (var i = 0; i < chapters.length; i += size) {
    groups.add(chapters.sublist(i, min(i + size, chapters.length)));
  }
  return groups;
}

class ChapterGroupedList extends HookWidget {
  const ChapterGroupedList({
    super.key,
    required this.chapters,
    this.lastReadChapterIndex,
    this.onOpenReader,
  });

  final List<ChapterEntity> chapters;
  final int? lastReadChapterIndex;
  final void Function(String? chapterId)? onOpenReader;

  @override
  Widget build(BuildContext context) {
    final groups = useMemoized(() => groupChapters(chapters), [chapters]);
    final collapsedGroups = useState<Set<int>>(() {
      final set = <int>{};
      if (groups.length > 3) {
        for (var i = 1; i < groups.length; i++) {
          set.add(i);
        }
      }
      return set;
    }());

    void toggleGroup(int groupIndex) {
      final next = Set<int>.from(collapsedGroups.value);
      if (next.contains(groupIndex)) {
        next.remove(groupIndex);
      } else {
        next.add(groupIndex);
      }
      collapsedGroups.value = next;
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var g = 0; g < groups.length; g++) ...[
          _buildGroupHeader(
            g,
            groups[g],
            textTheme,
            cs,
            collapsedGroups.value.contains(g),
            () => toggleGroup(g),
          ),
          if (!collapsedGroups.value.contains(g))
            for (final ch in groups[g]) _buildChapterItem(context, ch, textTheme, cs),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(
    int groupIndex,
    List<ChapterEntity> group,
    TextTheme textTheme,
    ColorScheme cs,
    bool isCollapsed,
    VoidCallback onToggle,
  ) {
    final start = group.first.index + 1;
    final end = group.last.index + 1;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Chapters $start–$end',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
            Icon(
              isCollapsed ? Icons.expand_more : Icons.expand_less,
              color: cs.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterItem(
    BuildContext context,
    ChapterEntity ch,
    TextTheme textTheme,
    ColorScheme cs,
  ) {
    final isRead =
        lastReadChapterIndex != null &&
        ch.index < lastReadChapterIndex!;
    final isCurrent = ch.index == lastReadChapterIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: isCurrent
                ? cs.primary
                : isRead
                ? cs.primaryContainer
                : cs.surfaceContainerHighest,
            child: isRead
                ? Icon(Icons.check, size: 14, color: cs.onPrimaryContainer)
                : Text(
                    '${ch.index + 1}',
                    style: textTheme.labelSmall?.copyWith(
                      color: isCurrent ? cs.onPrimary : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          title: Text(
            ch.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w600 : null,
              color: isRead ? cs.onSurfaceVariant : null,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            size: 18,
            color: cs.onSurfaceVariant,
          ),
          onTap: () => onOpenReader?.call(ch.id),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
        ),
      ),
    );
  }
}
