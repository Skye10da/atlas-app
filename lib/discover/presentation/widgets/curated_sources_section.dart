import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:atlas_app/browser/presentation/screens/source_immersive_screen.dart';
import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_engine/registry/plugin_source.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

class CuratedSourcesSection extends StatelessWidget {
  const CuratedSourcesSection({
    super.key,
    required this.sources,
  });

  final List<SearchableSource> sources;

  static const Map<String, String> _knownHomeUrls = {
    'Project Gutenberg': 'https://www.gutenberg.org',
    'Open Library': 'https://openlibrary.org',
    'Public Domain Library': 'https://publicdomainlibrary.org',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Curated Sources & Catalogs',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push('/sources'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  '${sources.length} sources • View all',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.smMd),
        for (final source in sources.take(4)) ...[
          _SourceItemCard(
            source: source,
            knownHomeUrls: _knownHomeUrls,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _SourceItemCard extends StatelessWidget {
  const _SourceItemCard({
    required this.source,
    required this.knownHomeUrls,
  });

  final SearchableSource source;
  final Map<String, String> knownHomeUrls;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final isNovel = source.contentCategory == ContentCategory.novel;
    final pluginSource = source is PluginSource ? source as PluginSource : null;
    final homeUrl = pluginSource?.manifest.baseUrl ?? knownHomeUrls[source.sourceName];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  isNovel
                      ? Icons.auto_stories_rounded
                      : Icons.local_library_rounded,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.smMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.sourceName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isNovel ? 'Web novel catalog' : 'Free books library',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Search'),
                onPressed: () {
                  context.push(
                    '/sources/${Uri.encodeComponent(source.sourceName)}',
                  );
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              if (homeUrl != null)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Browse'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SourceImmersiveScreen(
                          initialUrl: homeUrl,
                          sourceTitle: source.sourceName,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
