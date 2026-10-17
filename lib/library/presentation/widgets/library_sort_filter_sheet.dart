import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';

/// Opens the Library "Sort & filter" sheet (adaptive: bottom sheet on phones,
/// dialog / side panel on desktop, following the app's sheet preferences).
Future<void> showLibrarySortFilterSheet(BuildContext context) {
  return AppSheet.show<void>(
    context: context,
    id: 'library_sort_filter',
    title: 'Sort & filter',
    fitToContent: true,
    maxWidth: 520,
    child: const LibrarySortFilterSheet(),
  );
}

class LibrarySortFilterSheet extends ConsumerWidget {
  const LibrarySortFilterSheet({super.key});

  static const _sortOptions = <(LibrarySortOrder, String)>[
    (LibrarySortOrder.recentlyRead, 'Recent'),
    (LibrarySortOrder.recentlyUpdated, 'Updated'),
    (LibrarySortOrder.titleAsc, 'Title'),
    (LibrarySortOrder.author, 'Author'),
    (LibrarySortOrder.recentlyAdded, 'Added'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sort = ref.watch(librarySortProvider);
    final genres = ref.watch(availableGenresProvider);
    final genre = ref.watch(libraryGenreFilterProvider);
    final notifier = ref.read(libraryViewModelProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sort by',
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final option in _sortOptions)
                ChoiceChip(
                  label: Text(option.$2),
                  selected: sort == option.$1,
                  onSelected: (_) => notifier.setSortOrder(option.$1),
                ),
            ],
          ),
          if (genres.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text(
                  'Genre',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (genre != null)
                  TextButton(
                    onPressed: () => notifier.setGenreFilter(null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('All genres'),
                  selected: genre == null,
                  onSelected: (_) => notifier.setGenreFilter(null),
                ),
                for (final tag in genres)
                  ChoiceChip(
                    label: Text(tag),
                    selected: genre == tag,
                    onSelected: (selected) =>
                        notifier.setGenreFilter(selected ? tag : null),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
