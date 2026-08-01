import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/router/navigation.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';

class SourceBrowserScreen extends ConsumerWidget {
  const SourceBrowserScreen({super.key});

  static const _sourceMeta = {
    'Project Gutenberg': _SourceMeta(Icons.auto_stories, '~75,000 free ebooks in the public domain'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(searchableSourcesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => popOrGoToLibrary(context),
        ),
        title: const Text('Browse Sources'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: sources.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final source = sources[index];
          final meta = _sourceMeta[source.sourceName] ??
              const _SourceMeta(Icons.library_books, 'Explore new books');

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(meta.icon, color: theme.colorScheme.onPrimaryContainer),
            ),
            title: Text(source.sourceName, style: theme.textTheme.titleMedium),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(meta.description, style: theme.textTheme.bodySmall),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/sources/${Uri.encodeComponent(source.sourceName)}'),
          );
        },
      ),
    );
  }
}

class _SourceMeta {
  const _SourceMeta(this.icon, this.description);
  final IconData icon;
  final String description;
}
