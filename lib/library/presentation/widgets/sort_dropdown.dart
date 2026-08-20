import 'package:flutter/material.dart';

import 'package:atlas_app/library/presentation/providers/library_provider.dart';

class SortDropdown extends StatelessWidget {
  const SortDropdown({
    super.key,
    required this.currentOrder,
    required this.onSort,
  });

  final LibrarySortOrder currentOrder;
  final void Function(LibrarySortOrder) onSort;

  @override
  Widget build(BuildContext context) {
    final options = [
      (LibrarySortOrder.recentlyRead, 'Recent'),
      (LibrarySortOrder.titleAsc, 'Title'),
      (LibrarySortOrder.author, 'Author'),
      (LibrarySortOrder.recentlyAdded, 'Added'),
    ];
    final currentLabel = options
        .firstWhere(
          (o) => o.$1 == currentOrder,
          orElse: () => (currentOrder, 'Sort'),
        )
        .$2;

    return PopupMenuButton<LibrarySortOrder>(
      tooltip: 'Sort',
      initialValue: currentOrder,
      onSelected: onSort,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      itemBuilder: (_) => [
        ...options.map((o) {
          final selected = o.$1 == currentOrder;
          return PopupMenuItem(
            value: o.$1,
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  child: selected
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
                Text(o.$2, style: const TextStyle(fontSize: 13)),
              ],
            ),
          );
        }),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sort,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(currentLabel, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }
}
