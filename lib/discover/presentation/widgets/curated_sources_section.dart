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
    this.totalSupportedSourcesCount = 0,
  });

  final List<SearchableSource> sources;
  final int totalSupportedSourcesCount;

  static const Map<String, String> _knownHomeUrls = {
    'Project Gutenberg': 'https://www.gutenberg.org',
    'Open Library': 'https://openlibrary.org',
    'Standard Ebooks': 'https://standardebooks.org',
    'Feedbooks': 'https://www.feedbooks.com',
    'Public Domain Library': 'https://publicdomainlibrary.org',
    'Royal Road': 'https://www.royalroad.com',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = totalSupportedSourcesCount > 0
        ? totalSupportedSourcesCount
        : sources.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Content Sources',
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
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  '$count sources • View all',
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
        if (sources.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
            ),
            child: Row(
              children: [
                Icon(Icons.hub_outlined, color: colorScheme.outline),
                const SizedBox(width: AppSpacing.smMd),
                Expanded(
                  child: Text(
                    'No content sources currently installed.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/sources'),
                  child: const Text('Browse'),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: sources.length > 6 ? 6 : sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              return _SourcePillCard(
                source: source,
                knownHomeUrls: _knownHomeUrls,
              );
            },
          ),
      ],
    );
  }
}

class _SourcePillCard extends StatelessWidget {
  const _SourcePillCard({
    required this.source,
    required this.knownHomeUrls,
  });

  final SearchableSource source;
  final Map<String, String> knownHomeUrls;

  (IconData, Color, Color) _getSourceVisuals(String name, bool isNovel) {
    final lower = name.toLowerCase();
    if (lower.contains('gutenberg')) {
      return (
        Icons.account_balance_rounded,
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
      );
    }
    if (lower.contains('open library') || lower.contains('openlib')) {
      return (
        Icons.menu_book_rounded,
        const Color(0xFFE3F2FD),
        const Color(0xFF1976D2),
      );
    }
    if (lower.contains('standard')) {
      return (
        Icons.auto_stories_rounded,
        const Color(0xFFF3E5F5),
        const Color(0xFF7B1FA2),
      );
    }
    if (lower.contains('feedbook')) {
      return (
        Icons.library_books_rounded,
        const Color(0xFFE0F2F1),
        const Color(0xFF00796B),
      );
    }
    if (lower.contains('royal')) {
      return (
        Icons.military_tech_rounded,
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
      );
    }
    if (isNovel) {
      return (
        Icons.local_fire_department_rounded,
        const Color(0xFFFCE4EC),
        const Color(0xFFC2185B),
      );
    }
    return (
      Icons.language_rounded,
      const Color(0xFFF3EDF7),
      const Color(0xFF7C3AED),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isNovel = source.contentCategory == ContentCategory.novel;
    final pluginSource = source is PluginSource ? source as PluginSource : null;
    final homeUrl =
        pluginSource?.manifest.baseUrl ?? knownHomeUrls[source.sourceName];

    final (icon, lightBg, iconColor) =
        _getSourceVisuals(source.sourceName, isNovel);

    final boxBg = isDark ? iconColor.withValues(alpha: 0.2) : lightBg;
    final cardBg = isDark
        ? theme.colorScheme.surfaceContainerLow
        : const Color(0xFFF3EDF7);

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (homeUrl != null && homeUrl.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SourceImmersiveScreen(
                  initialUrl: homeUrl,
                  sourceTitle: source.sourceName,
                ),
              ),
            );
          } else {
            context.push(
              '/sources/${Uri.encodeComponent(source.sourceName)}',
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? theme.colorScheme.outlineVariant.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      source.sourceName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isNovel ? 'Web Novels' : 'Public Domain',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
