import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';

/// Native start page shown for blank browser tabs.
///
/// Surfaces the app's content sources as "Open site" tiles — the browsery
/// stand-in for the old /sources screen. Searchable sources also offer a
/// secondary "Search" chip that drops into the existing search workflow.
class BrowserStartPage extends ConsumerWidget {
  const BrowserStartPage({super.key, required this.onOpenSite});

  /// Invoked with a normalized site URL when the user taps "Open site".
  final ValueChanged<String> onOpenSite;

  static const Map<String, _StartSiteMeta> _sites = {
    'Project Gutenberg': _StartSiteMeta(
      icon: Icons.auto_stories_rounded,
      description: '~75,000 free public-domain ebooks',
      homeUrl: 'https://www.gutenberg.org',
    ),
    'Open Library': _StartSiteMeta(
      icon: Icons.local_library_rounded,
      description: 'Borrow & read from the open web catalog',
      homeUrl: 'https://openlibrary.org',
    ),
    'Public Domain Library': _StartSiteMeta(
      icon: Icons.public_rounded,
      description: 'Public-domain books at a glance',
      homeUrl: 'https://publicdomainlibrary.org',
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(searchableSourcesProvider);
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        children: [
          Text(
            'Browse the web',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Open a site below, or type an address in the bar up top.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final source in sources) ...[
            if (_sites[source.sourceName] case final meta?)
              _StartSiteTile(
                title: source.sourceName,
                meta: meta,
                onOpen: () => onOpenSite(meta.homeUrl),
                onSearch: () => context.push(
                  '/sources/${Uri.encodeComponent(source.sourceName)}',
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _StartSiteMeta {
  const _StartSiteMeta({
    required this.icon,
    required this.description,
    required this.homeUrl,
  });

  final IconData icon;
  final String description;
  final String homeUrl;
}

class _StartSiteTile extends StatelessWidget {
  const _StartSiteTile({
    required this.title,
    required this.meta,
    required this.onOpen,
    required this.onSearch,
  });

  final String title;
  final _StartSiteMeta meta;
  final VoidCallback onOpen;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.primaryContainer,
                child: Icon(meta.icon, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      meta.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        avatar: const Icon(Icons.search, size: 16),
                        label: const Text('Search'),
                        visualDensity: VisualDensity.compact,
                        onPressed: onSearch,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}