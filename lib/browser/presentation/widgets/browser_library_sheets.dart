import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/browser/domain/entities/web_bookmark.dart';
import 'package:atlas_app/browser/domain/entities/web_history_entry.dart';
import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

/// Presents a bottom-sheet stack of the persisted browsing history. Entries
/// open through [onOpenUrl]; a "Clear" action empties the history.
Future<void> showBrowserHistorySheet(
  BuildContext context, {
  required ValueChanged<String> onOpenUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _HistorySheet(onOpenUrl: onOpenUrl),
  );
}

/// Presents the persisted bookmarks. Entries open through [onOpenUrl]; the
/// trailing delete button removes a single bookmark.
Future<void> showBrowserBookmarksSheet(
  BuildContext context, {
  required ValueChanged<String> onOpenUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _BookmarksSheet(onOpenUrl: onOpenUrl),
  );
}

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet({required this.onOpenUrl});

  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(webHistoryProvider).value ?? const <WebHistoryEntry>[];
    return _SheetScaffold(
      title: 'History',
      actions: [
        if (history.isNotEmpty)
          TextButton(
            onPressed: () => ref.read(browserRepositoryProvider).clearHistory(),
            child: const Text('Clear'),
          ),
      ],
      child: history.isEmpty
          ? const _Empty(icon: Icons.history_rounded, label: 'No history yet')
          : ListView.separated(
              shrinkWrap: true,
              itemCount: history.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = history[index];
                return ListTile(
                  leading: const Icon(Icons.public_rounded, size: 20),
                  title: Text(
                    entry.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    entry.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenUrl(entry.url);
                  },
                );
              },
            ),
    );
  }
}

class _BookmarksSheet extends ConsumerWidget {
  const _BookmarksSheet({required this.onOpenUrl});

  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks =
        ref.watch(webBookmarksProvider).value ?? const <BrowserBookmark>[];
    return _SheetScaffold(
      title: 'Bookmarks',
      child: bookmarks.isEmpty
          ? const _Empty(
              icon: Icons.bookmark_add_outlined,
              label: 'Star a page to find it here',
            )
          : ListView.separated(
              shrinkWrap: true,
              itemCount: bookmarks.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final bookmark = bookmarks[index];
                return ListTile(
                  leading: const Icon(Icons.bookmark_rounded, size: 20),
                  title: Text(
                    bookmark.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    bookmark.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove bookmark',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => ref
                        .read(browserRepositoryProvider)
                        .removeBookmark(bookmark.id),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenUrl(bookmark.url);
                  },
                );
              },
            ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  ...?actions,
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
