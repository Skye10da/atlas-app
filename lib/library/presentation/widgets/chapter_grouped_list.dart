import 'dart:math';

import 'package:flutter/material.dart';

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

class ChapterGroupedList extends StatefulWidget {
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
  State<ChapterGroupedList> createState() => _ChapterGroupedListState();
}

class _ChapterGroupedListState extends State<ChapterGroupedList> {
  final Set<int> _collapsedGroups = {};

  @override
  void initState() {
    super.initState();
    final groups = groupChapters(widget.chapters);
    if (groups.length > 3) {
      for (var i = 1; i < groups.length; i++) {
        _collapsedGroups.add(i);
      }
    }
  }

  void _toggleGroup(int groupIndex) {
    setState(() {
      if (_collapsedGroups.contains(groupIndex)) {
        _collapsedGroups.remove(groupIndex);
      } else {
        _collapsedGroups.add(groupIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;
    final groups = groupChapters(widget.chapters);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var g = 0; g < groups.length; g++) ...[
          _buildGroupHeader(g, groups[g], textTheme, cs),
          if (!_collapsedGroups.contains(g))
            for (final ch in groups[g]) _buildChapterItem(ch, textTheme, cs),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(
    int groupIndex,
    List<ChapterEntity> group,
    TextTheme textTheme,
    ColorScheme cs,
  ) {
    final start = group.first.index + 1;
    final end = group.last.index + 1;
    final isCollapsed = _collapsedGroups.contains(groupIndex);
    return InkWell(
      onTap: () => _toggleGroup(groupIndex),
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
    ChapterEntity ch,
    TextTheme textTheme,
    ColorScheme cs,
  ) {
    final isRead =
        widget.lastReadChapterIndex != null &&
        ch.index < widget.lastReadChapterIndex!;
    final isCurrent = ch.index == widget.lastReadChapterIndex;
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
          onTap: () => widget.onOpenReader?.call(ch.id),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
        ),
      ),
    );
  }
}
