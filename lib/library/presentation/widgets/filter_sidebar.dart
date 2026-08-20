import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/library/domain/entities/bookshelf_layout.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';

class FilterSidebar extends ConsumerWidget {
  const FilterSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final genres = ref.watch(availableGenresProvider);
    final category = ref.watch(libraryCategoryProvider);
    final genreFilter = ref.watch(libraryGenreFilterProvider);
    final sort = ref.watch(librarySortProvider);

    return Container(
      width: 200,
      color: cs.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Filters',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(
            'Category',
            style: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          SegmentedButton<LibraryCategory>(
            segments: const [
              ButtonSegment(value: LibraryCategory.books, label: Text('Books')),
              ButtonSegment(value: LibraryCategory.novels, label: Text('Novels')),
            ],
            selected: {category},
            onSelectionChanged: (selected) {
              ref.read(libraryCategoryProvider.notifier).state = selected.first;
              ref.read(libraryGenreFilterProvider.notifier).state = null;
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Genre',
              style: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in genres)
                  FilterChip(
                    label: Text(g, style: const TextStyle(fontSize: 11)),
                    selected: genreFilter == g,
                    onSelected: (selected) {
                      ref.read(libraryGenreFilterProvider.notifier).state =
                          selected ? g : null;
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Sort',
            style: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          RadioGroup<LibrarySortOrder>(
            groupValue: sort,
            onChanged: (v) {
              if (v != null) {
                ref.read(librarySortProvider.notifier).state = v;
              }
            },
            child: Column(
              children: LibrarySortOrder.values.map(
                (order) => RadioListTile<LibrarySortOrder>(
                  value: order,
                  title: Text(
                    switch (order) {
                      LibrarySortOrder.titleAsc => 'Title',
                      LibrarySortOrder.titleDesc => 'Title (desc)',
                      LibrarySortOrder.author => 'Author',
                      LibrarySortOrder.recentlyAdded => 'Recently added',
                      LibrarySortOrder.recentlyRead => 'Recently read',
                    },
                    style: const TextStyle(fontSize: 12),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'View',
            style: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          _buildLayoutToggle(ref),
        ],
      ),
    );
  }

  Widget _buildLayoutToggle(WidgetRef ref) {
    final current = ref.watch(bookshelfLayoutProvider);
    return Row(
      children: BookshelfLayout.values.map((layout) {
        final selected = layout == current;
        return IconButton(
          icon: Icon(layout.icon, size: 20),
          isSelected: selected,
          onPressed: () {
            ref.read(bookshelfLayoutProvider.notifier).state = layout;
          },
          tooltip: layout.label,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}
