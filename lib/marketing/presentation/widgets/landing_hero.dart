import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/marketing/presentation/content/landing_content.dart';

/// Centered hero for the public Atlas landing page.
///
/// [deviceSummary] ("Windows (x64)" / "macOS (Apple silicon)") comes from the
/// device detector; when present the primary CTA names the resolved download
/// and a micro-line explains the auto-matching. When detection degraded, the
/// hero shows the neutral "Download the app" rather than a pretend match.
class LandingHero extends StatelessWidget {
  const LandingHero({
    super.key,
    required this.versionLabel,
    required this.onDownload,
    required this.onSeeHow,
    this.deviceSummary,
  });

  final String versionLabel;
  final VoidCallback onDownload;
  final VoidCallback onSeeHow;
  final String? deviceSummary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl * 2,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeroVersionPill(
                versionLabel: versionLabel,
                accent: colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                constraints: const BoxConstraints(maxWidth: 920),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Text(
                    landingHeroHeadline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontSize: 54,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.6,
                      height: 1.05,
                      color: colorScheme.onSurface,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                landingHeroSubhead,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Wrap, not Row: the smart label ("Download for Windows (x64)")
              // plus the secondary action can outgrow narrow phones — flow to
              // a second line instead of clipping.
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  _HeroPrimaryCta(
                    accent: colorScheme.primary,
                    label: deviceSummary == null
                        ? 'Download the app'
                        : 'Download for $deviceSummary',
                    onPressed: onDownload,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _HeroSecondaryCta(
                    accent: colorScheme.primary,
                    onPressed: onSeeHow,
                  ),
                ],
              ),
              if (deviceSummary != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Detected automatically — always the right build.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeroStat(value: '6+', label: 'Reading sources'),
                  _HeroStat(value: '100%', label: 'Offline-first'),
                  _HeroStat(value: 'AI', label: 'Native'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroVersionPill extends StatelessWidget {
  const _HeroVersionPill({required this.versionLabel, required this.accent});

  final String versionLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCapsule(
      borderRadius: AppSpacing.borderRadiusFull,
      blur: 20,
      strong: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 14, color: accent),
            const SizedBox(width: 6),
            Text(
              'v$versionLabel · Latest release',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPrimaryCta extends StatelessWidget {
  const _HeroPrimaryCta({
    required this.accent,
    required this.label,
    required this.onPressed,
  });

  final Color accent;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      child: GlassCapsule(
        borderRadius: AppSpacing.borderRadiusFull,
        blur: 24,
        strong: true,
        fill: accent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download, size: 18, color: colorScheme.onPrimary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSecondaryCta extends StatelessWidget {
  const _HeroSecondaryCta({required this.accent, required this.onPressed});

  final Color accent;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      child: GlassCapsule(
        borderRadius: AppSpacing.borderRadiusFull,
        blur: 24,
        strong: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_downward, size: 16, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'See how it works',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
