import 'package:flutter/material.dart';

import 'package:atlas_app/library/presentation/providers/library_provider.dart';

class SortToolbar extends StatelessWidget {
  const SortToolbar({
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

    return Row(
      children: [
        ...options.map((o) {
          final selected = o.$1 == currentOrder;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(o.$2, style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (_) => onSort(o.$1),
              visualDensity: VisualDensity.compact,
            ),
          );
        }),
      ],
    );
  }
}
