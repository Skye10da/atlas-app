import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/browser/presentation/screens/source_immersive_screen.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_engine/registry/plugin_source.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/design_system/atoms/source_visuals.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';

/// The saved supported-sites directory, deliberately minimal: one small list
/// of rows arranged like bookmarks — icon dot, name, chevron. Tapping a row
/// opens that site's own web home in the immersive browser. Lives on the
/// Find new screen.
class SourceListSection extends ConsumerWidget {
  const SourceListSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sources = ref.watch(searchableSourcesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sources.length == 1 ? 'SUPPORTED SITE' : 'SUPPORTED SITES',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final source in sources)
          _SourceRow(
            sourceName: source.sourceName,
            isNovel: source.contentCategory == ContentCategory.novel,
            // The plugin manifest base URL is authoritative for plugin sites;
            // built-in/OPDS sources have no manifest base and fall back to
            // pluginSiteHomeUrls / knownSourceHomeUrls in sourceHomeUrl.
            declaredHomeUrl: source is PluginSource ? source.manifest.baseUrl : null,
          ),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.sourceName,
    required this.isNovel,
    this.declaredHomeUrl,
  });

  final String sourceName;
  final bool isNovel;
  /// Live plugin manifest base URL (e.g. `https://sleepytranslations.com`),
  /// when the source is a plugin. Takes precedence in `sourceHomeUrl`.
  final String? declaredHomeUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final (icon, boxBg, iconColor) = themedSourceVisuals(
      sourceName: sourceName,
      isNovel: isNovel,
      brightness: theme.brightness,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        // Open the source's own web home in the immersive browser — never the
        // per-site search page. `declaredHomeUrl` (the plugin manifest base)
        /// is authoritative so newly installed plugin sites open their real
        /// home even when they aren't yet listed in pluginSiteHomeUrls.
        onTap: () {
          final homeUrl = sourceHomeUrl(
            sourceName,
            declaredHomeUrl: declaredHomeUrl,
          );
          if (homeUrl == null) return;
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => SourceImmersiveScreen(
                initialUrl: homeUrl,
                sourceTitle: sourceName,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: boxBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color:
                      isDark ? iconColor.withValues(alpha: 0.9) : iconColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.outline.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

