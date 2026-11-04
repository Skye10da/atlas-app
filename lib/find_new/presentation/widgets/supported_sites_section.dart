import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/browser/presentation/screens/source_immersive_screen.dart';
import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/content_engine/registry/plugin_source.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/design_system/atoms/source_visuals.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';

/// The hub's live directory of every supported website (built-in catalogs
/// + installed plugins). Each card opens the site itself — its web home in
/// the immersive reader — never the per-site search page. An unknown home
/// disables the card instead of falling through to search.
class SupportedSitesSection extends ConsumerWidget {
  const SupportedSitesSection({
    this.totalSupportedSourcesCount,
    super.key,
  });

  /// Total site count from the discovery dashboard, when available
  /// (includes catalogs the search didn't discover locally yet).
  final int? totalSupportedSourcesCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sources = ref.watch(searchableSourcesProvider);
    final pluginAsync = ref.watch(pluginSourcesProvider);
    final pluginWarm = pluginAsync.hasValue;
    final dashboardCount = totalSupportedSourcesCount ?? 0;
    final count = dashboardCount > 0 ? dashboardCount : sources.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Supported sites',
              style: TextStyle(
                fontFamily: 'Fraunces',
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
                  '$count sites · View all',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (!pluginWarm)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Checking for plugin sites…',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        if (sources.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
            ),
            child: Row(
              children: [
                Icon(Icons.hub_outlined, color: cs.outline),
                const SizedBox(width: AppSpacing.smMd),
                Expanded(
                  child: Text(
                    'No sites available yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
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
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              clipBehavior: Clip.none,
              itemCount: sources.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _SiteCard(source: sources[index]);
              },
            ),
          ),
      ],
    );
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({required this.source});

  final SearchableSource source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isNovel = source.contentCategory == ContentCategory.novel;
    final (icon, boxBg, iconColor) = themedSourceVisuals(
      sourceName: source.sourceName,
      isNovel: isNovel,
      brightness: theme.brightness,
    );

    final homeUrl = sourceHomeUrl(
      source.sourceName,
      declaredHomeUrl:
          source is PluginSource ? (source as PluginSource).manifest.baseUrl : null,
    );
    final validHome = homeUrl != null &&
        Uri.tryParse(homeUrl)?.hasScheme == true;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: boxBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isDark ? iconColor.withValues(alpha: 0.9) : iconColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  source.sourceName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  // Never drops into the per-site search page — the card
                  // always aims at the source's own home in the browser.
                  onPressed: validHome
                      ? () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => SourceImmersiveScreen(
                                initialUrl: homeUrl,
                                sourceTitle: source.sourceName,
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.public_rounded, size: 16),
                  label: const Text('Open site'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

