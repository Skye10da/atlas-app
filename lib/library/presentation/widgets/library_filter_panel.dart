import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/library/presentation/providers/library_provider.dart';

/// Compact library filters rendered inside the desktop menu sidebar.
///
/// Holds the true library filters — Category (Books/Novels) and Genre — sized
/// to fit the nav sidebar column. Sort and View are handled by the shelf
/// header toolbar. The genre list is collapsed into a dropdown so a long tag
/// list never overflows the sidebar.
class LibraryFilterPanel extends ConsumerWidget {
  const LibraryFilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final genres = ref.watch(availableGenresProvider);
    final category = ref.watch(libraryCategoryProvider);
    final genreFilter = ref.watch(libraryGenreFilterProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Filters',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          Text(
            'Genre',
            style: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          _GenreMenu(genres: genres, selected: genreFilter),
        ],
      ],
    );
  }
}

class _GenreMenu extends ConsumerWidget {
  const _GenreMenu({required this.genres, required this.selected});

  final List<String> genres;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return MenuAnchor(
      builder: (context, controller, child) {
        return OutlinedButton.icon(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.filter_alt_outlined, size: 18),
          label: Text(
            selected ?? 'All genres',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: selected == null
                ? cs.onSurfaceVariant
                : cs.primary,
            side: BorderSide(color: cs.outlineVariant),
          ),
        );
      },
      menuChildren: [
        MenuItemButton(
          onPressed: () =>
              ref.read(libraryGenreFilterProvider.notifier).state = null,
          leadingIcon: Icon(selected == null ? Icons.check : null, size: 18),
          child: const Text('All genres'),
        ),
        for (final g in genres)
          MenuItemButton(
            onPressed: () =>
                ref.read(libraryGenreFilterProvider.notifier).state = g,
            leadingIcon: Icon(selected == g ? Icons.check : null, size: 18),
            child: Text(g, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }
}
