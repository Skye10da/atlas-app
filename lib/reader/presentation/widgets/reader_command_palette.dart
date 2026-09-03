import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';

class ReaderCommandPalette extends HookWidget {
  const ReaderCommandPalette({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterSelected,
    required this.onToggleBookmark,
    required this.isBookmarked,
    required this.onToggleSettings,
    this.onOpenAnnotations,
    required this.onClose,
  });

  final List<ChapterEntity> chapters;
  final int currentChapterIndex;
  final void Function(int) onChapterSelected;
  final VoidCallback onToggleBookmark;
  final bool isBookmarked;
  final VoidCallback onToggleSettings;
  final VoidCallback? onOpenAnnotations;
  final VoidCallback onClose;

  List<_CommandItem> _buildAllCommands() => [
    _CommandItem(
      icon: Icons.list,
      title: 'Go to Chapter...',
      subtitle: 'Jump to a specific chapter',
      action: (idx) {},
    ),
    ...chapters.map(
      (ch) => _CommandItem(
        icon: Icons.article_outlined,
        title: ch.title,
        subtitle: 'Chapter ${chapters.indexOf(ch) + 1}',
        index: chapters.indexOf(ch),
        isCurrent: chapters.indexOf(ch) == currentChapterIndex,
        action: (idx) => onChapterSelected(idx),
      ),
    ),
    _CommandItem(
      icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
      title: isBookmarked ? 'Remove bookmark' : 'Bookmark current chapter',
      subtitle: 'Toggle bookmark for this chapter',
      action: (_) => onToggleBookmark(),
    ),
    if (onOpenAnnotations != null)
      _CommandItem(
        icon: Icons.bookmarks_outlined,
        title: 'Annotations & Notes',
        subtitle: 'View saved notes, quotes, and highlights',
        action: (_) => onOpenAnnotations!(),
      ),
    _CommandItem(
      icon: Icons.text_fields,
      title: 'Reading settings',
      subtitle: 'Font size, theme, layout',
      action: (_) => onToggleSettings(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final searchController = useTextEditingController();
    final focusNode = useFocusNode();
    final query = useState('');
    final selectedIndex = useState(0);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => focusNode.requestFocus(),
      );
      return null;
    }, const []);

    final allCommands = _buildAllCommands();
    final items = useMemoized(() {
      if (query.value.isEmpty) return allCommands;
      final q = query.value.toLowerCase();
      return allCommands
          .where(
            (c) =>
                c.title.toLowerCase().contains(q) ||
                c.subtitle.toLowerCase().contains(q) ||
                '${c.index}'.contains(q),
          )
          .toList();
    }, [query.value, allCommands]);

    void executeSelected() {
      if (items.isEmpty) return;
      var idx = selectedIndex.value;
      if (idx >= items.length) idx = 0;
      items[idx].action(items[idx].index);
      onClose();
    }

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        GestureDetector(
          onTap: onClose,
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
                          selectedIndex.value = (selectedIndex.value + 1).clamp(
                            0,
                            items.length - 1,
                          );
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          selectedIndex.value = (selectedIndex.value - 1).clamp(
                            0,
                            items.length - 1,
                          );
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.escape) {
                          onClose();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: searchController,
                        focusNode: focusNode,
                        onChanged: (v) {
                          query.value = v;
                          selectedIndex.value = 0;
                        },
                        onSubmitted: (_) => executeSelected(),
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
                          final isSelected = i == selectedIndex.value;
                          return Material(
                            color: isSelected
                                ? colors.primaryContainer.withValues(alpha: 0.3)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                item.action(item.index);
                                onClose();
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
