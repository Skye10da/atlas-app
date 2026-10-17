import 'package:flutter/material.dart';

import 'package:atlas_app/library/presentation/view_models/library_state.dart';

/// Underlined status tabs (All / Reading / Updated / Unread / Finished) for
/// the Library shelf, with optional trailing actions (sort & filter, layout)
/// docked at the end of the same row.
class LibraryStatusTabs extends StatelessWidget {
  const LibraryStatusTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.updatedCount = 0,
    this.trailing = const <Widget>[],
  });

  final LibraryStatusFilter selected;
  final ValueChanged<LibraryStatusFilter> onSelected;

  /// Badge shown on the "Updated" tab: how many novels have new chapters.
  final int updatedCount;

  /// Actions shown after the tabs (not scrolled with them).
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in LibraryStatusFilter.values)
                    _StatusTab(
                      label: filter.label,
                      selected: filter == selected,
                      badgeCount: filter == LibraryStatusFilter.updated
                          ? updatedCount
                          : 0,
                      onTap: () => onSelected(filter),
                    ),
                ],
              ),
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? cs.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: selected ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: cs.tertiary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
