import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/marketing/presentation/content/landing_content.dart';

/// Thin credibility strip under the hero: static, verifiable facts — high
/// trust per pixel, no vanity metrics — plus the repo link.
class LandingSocialProof extends StatelessWidget {
  const LandingSocialProof({super.key});

  Future<void> _openGithub() => launchUrl(
    Uri.parse(
      'https://github.com/Skye10da/atlas-app'
      '?utm_source=landing-social-proof',
    ),
    mode: LaunchMode.externalApplication,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final (value, label) in landingSocialProof)
            GlassCapsule(
              borderRadius: AppSpacing.borderRadiusFull,
              blur: 16,
              strong: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          InkWell(
            onTap: _openGithub,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
            child: GlassCapsule(
              borderRadius: AppSpacing.borderRadiusFull,
              blur: 16,
              strong: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 14, color: accent),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'star on GitHub',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
