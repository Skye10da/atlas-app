import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';

class ReaderCommandPalette extends StatefulWidget {
  const ReaderCommandPalette({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterSelected,
    required this.onToggleBookmark,
    required this.isBookmarked,
    required this.onToggleSettings,
    required this.onTogglePanel,
    required this.onClose,
  });

  final List<ChapterEntity> chapters;
  final int currentChapterIndex;
  final void Function(int) onChapterSelected;
  final VoidCallback onToggleBookmark;
  final bool isBookmarked;
  final VoidCallback onToggleSettings;
  final VoidCallback onTogglePanel;
  final VoidCallback onClose;

  @override
  State<ReaderCommandPalette> createState() => _ReaderCommandPaletteState();
}

class _ReaderCommandPaletteState extends State<ReaderCommandPalette> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<_CommandItem> get _filteredCommands {
    final commands = _allCommands;
    if (_query.isEmpty) return commands;
    final q = _query.toLowerCase();
    return commands
        .where(
          (c) =>
              c.title.toLowerCase().contains(q) ||
              c.subtitle.toLowerCase().contains(q) ||
              '${c.index}'.contains(q),
        )
        .toList();
  }

  List<_CommandItem> get _allCommands => [
    _CommandItem(
      icon: Icons.list,
      title: 'Go to Chapter...',
      subtitle: 'Jump to a specific chapter',
      action: (idx) {},
    ),
    ...widget.chapters.map(
      (ch) => _CommandItem(
        icon: Icons.article_outlined,
        title: ch.title,
        subtitle: 'Chapter ${widget.chapters.indexOf(ch) + 1}',
        index: widget.chapters.indexOf(ch),
        isCurrent: widget.chapters.indexOf(ch) == widget.currentChapterIndex,
        action: (idx) => widget.onChapterSelected(idx),
      ),
    ),
    _CommandItem(
      icon: widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
      title: widget.isBookmarked
          ? 'Remove bookmark'
          : 'Bookmark current chapter',
      subtitle: 'Toggle bookmark for this chapter',
      action: (_) => widget.onToggleBookmark(),
    ),
    _CommandItem(
      icon: Icons.text_fields,
      title: 'Reading settings',
      subtitle: 'Font size, theme, layout',
      action: (_) => widget.onToggleSettings(),
    ),
    _CommandItem(
      icon: Icons.view_sidebar_outlined,
      title: 'Toggle side panel',
      subtitle: 'Show or hide the reader panel',
      action: (_) => widget.onTogglePanel(),
    ),
  ];

  void _executeSelected() {
    final items = _filteredCommands;
    if (items.isEmpty) return;
    if (_selectedIndex >= items.length) _selectedIndex = 0;
    items[_selectedIndex].action(items[_selectedIndex].index);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final items = _filteredCommands;

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          child: Container(color: Colors.black.withValues(alpha: 0.3)),
        ),
        Center(
          child: Material(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            elevation: 8,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          setState(
                            () => _selectedIndex = (_selectedIndex + 1).clamp(
                              0,
                              items.length - 1,
                            ),
                          );
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          setState(
                            () => _selectedIndex = (_selectedIndex - 1).clamp(
                              0,
                              items.length - 1,
                            ),
                          );
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.escape) {
                          widget.onClose();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        onChanged: (v) {
                          setState(() {
                            _query = v;
                            _selectedIndex = 0;
                          });
                        },
                        onSubmitted: (_) => _executeSelected(),
                        decoration: InputDecoration(
                          hintText: 'Search commands...',
                          prefixIcon: Icon(
                            Icons.search,
                            size: 20,
                            color: colors.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'No matching commands',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final item = items[i];
                          final isSelected = i == _selectedIndex;
                          return Material(
                            color: isSelected
                                ? colors.primaryContainer.withValues(alpha: 0.3)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                item.action(item.index);
                                widget.onClose();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 18,
                                      color: item.isCurrent
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: item.isCurrent
                                                  ? FontWeight.w600
                                                  : null,
                                              color: item.isCurrent
                                                  ? colors.primary
                                                  : colors.onSurface,
                                            ),
                                          ),
                                          if (item.subtitle.isNotEmpty)
                                            Text(
                                              item.subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (item.isCurrent)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Icon(
                                          Icons.check,
                                          size: 14,
                                          color: colors.primary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CommandItem {
  const _CommandItem({
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.index = -1,
    this.isCurrent = false,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int index;
  final bool isCurrent;
  final void Function(int index) action;
}
