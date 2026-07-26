import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/molecules/app_empty_state.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(allBookmarksProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: bookmarksAsync.when(
        loading: () => const AppLoading(),
        error: (_, _) => const AppEmptyState(
          title: 'Could not load bookmarks',
          icon: Icons.bookmark_border,
        ),
        data: (bookmarks) {
          if (bookmarks.isEmpty) {
            return const AppEmptyState(
              title: 'No bookmarks yet',
              message: 'Bookmark chapters while reading to see them here.',
              icon: Icons.bookmark_border,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: bookmarks.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, index) {
              final bm = bookmarks[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.bookmark,
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                  title: const Text('Chapter', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    'Book ${bm.bookId}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () => context.push('/reader/${bm.bookId}?chapter=${bm.chapterId}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
