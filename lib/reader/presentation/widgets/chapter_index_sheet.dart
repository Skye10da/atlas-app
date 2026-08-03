import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/molecules/app_search_bar.dart';
import 'package:atlas_app/core/design_system/organisms/draggable_bottom_sheet.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';

/// The chapter-list bottom sheet previously duplicated verbatim as
/// `_showChapterIndex` in both ContinuousReaderLayout and PagedReaderLayout.
/// The only thing that differed between the two call sites was what
/// happens on tap (scroll-to-chapter vs. page-jump-to-chapter), which is
/// now just [onChapterTap].
class ChapterIndexSheet extends StatefulWidget {
  const ChapterIndexSheet({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterTap,
  });

  final List<ChapterEntity> chapters;
  final int currentChapterIndex;
  final void Function(int index) onChapterTap;

  static void show(
    BuildContext context, {
    required String sheetId,
    required List<ChapterEntity> chapters,
    required int currentChapterIndex,
    required void Function(int index) onChapterTap,
  }) {
    DraggableBottomSheet.show(
      context: context,
      id: sheetId,
      initialHeight: 0.5,
      child: ChapterIndexSheet(
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        onChapterTap: onChapterTap,
      ),
    );
  }

  @override
  State<ChapterIndexSheet> createState() => _ChapterIndexSheetState();
}

class _ChapterIndexSheetState extends State<ChapterIndexSheet> {
  /// One-line [ListTile] (56) plus the trailing [Divider] (1). A fixed
  /// extent keeps [ListView] lazy while still knowing the full scroll range
  /// on the first frame, so the current chapter can be reached reliably.
  static const _itemExtent = 57.0;

  late final ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: widget.currentChapterIndex * _itemExtent,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnCurrent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Matched chapters as (original index, chapter) so the displayed number
  /// stays the real chapter number even when the list is filtered.
  List<(int, ChapterEntity)> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      return [
        for (var i = 0; i < widget.chapters.length; i++)
          (i, widget.chapters[i]),
      ];
    }
    return [
      for (var i = 0; i < widget.chapters.length; i++)
        if (widget.chapters[i].title.toLowerCase().contains(q))
          (i, widget.chapters[i]),
    ];
  }

  void _centerOnCurrent([int attempt = 0]) {
    if (!mounted || !_scrollController.hasClients) {
      if (attempt < 3) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _centerOnCurrent(attempt + 1));
      }
      return;
    }
    final position = _scrollController.position;
    final target = (widget.currentChapterIndex * _itemExtent) +
        (_itemExtent / 2) -
        (position.viewportDimension / 2);
    _scrollController.jumpTo(
      target.clamp(0.0, position.maxScrollExtent),
    );
  }

  void _jumpToOffset(double offset) {
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          final position = _scrollController.position;
          _scrollController.jumpTo(
            offset.clamp(0.0, position.maxScrollExtent),
          );
        }
      });
      return;
    }
    final position = _scrollController.position;
    _scrollController.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
  }

  void _onSearchChanged(String value) {
    final wasFiltering = _query.trim().isNotEmpty;
    setState(() => _query = value);
    if (value.trim().isEmpty) {
      if (wasFiltering) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnCurrent());
      }
    } else {
      _jumpToOffset(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Chapters',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        AppSearchBar(
          controller: _searchController,
          onChanged: _onSearchChanged,
          hint: 'Search chapters',
        ),
        const Divider(height: 1),
        Expanded(
          child: matches.isEmpty
              ? Center(
                  child: Text(
                    'No chapters found',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemExtent: _itemExtent,
                  itemCount: matches.length,
                  itemBuilder: (context, idx) {
                    final (originalIdx, ch) = matches[idx];
                    final isCurrent = originalIdx == widget.currentChapterIndex;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: isCurrent
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            child: Text(
                              '${originalIdx + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isCurrent
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : null,
                              ),
                            ),
                          ),
                          title: Text(
                            ch.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isCurrent ? FontWeight.w600 : null,
                            ),
                          ),
                          trailing: isCurrent
                              ? Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onChapterTap(originalIdx);
                          },
                        ),
                        const Divider(height: 1, indent: 16),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
