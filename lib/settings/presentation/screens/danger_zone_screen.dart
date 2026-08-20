import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';

class DangerZoneScreen extends ConsumerWidget {
  const DangerZoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Danger Zone')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Destructive actions that cannot be undone.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: colors.error.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.delete_sweep_rounded,
                    color: colors.error,
                  ),
                  title: const Text('Delete All Books'),
                  subtitle: const Text('Remove every book from your library'),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colors.onSurfaceVariant,
                  ),
                  onTap: () => _confirmDeleteAllBooks(context, ref),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_rounded,
                    color: colors.error,
                  ),
                  title: const Text('Delete All Novels'),
                  subtitle: const Text(
                    'Remove only content from content acquisition',
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colors.onSurfaceVariant,
                  ),
                  onTap: () => _confirmDeleteAllNovels(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAllBooks(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 40,
        ),
        title: const Text('Delete All Books?'),
        content: const Text(
          'This will permanently remove all books, chapters, '
          'reading progress, and bookmarks from your library. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteAllBooks(context, ref);
            },
            icon: const Icon(Icons.delete_sweep_rounded),
            label: const Text('Delete All'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllBooks(BuildContext context, WidgetRef ref) async {
    final deleteActions = ref.read(libraryDeleteProvider);
    final result = await deleteActions.deleteAll();
    if (!context.mounted) return;

    if (result is Success) {
      ref.invalidate(libraryBooksProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All books deleted')));
    } else if (result is Failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${result.error.userMessage}')),
      );
    }
  }

  void _confirmDeleteAllNovels(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 40,
        ),
        title: const Text('Delete All Novels?'),
        content: const Text(
          'This will remove all novels imported via content acquisition. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteAllBooks(context, ref);
            },
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Delete All'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}
