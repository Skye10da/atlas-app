import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/marketing/domain/services/landing_analytics.dart';
import 'package:atlas_app/marketing/domain/services/release_asset_resolver.dart';
import 'package:atlas_app/marketing/presentation/providers/landing_providers.dart';

/// Final conversion section: the smart download.
///
/// One click delivers the correct release artifact for the visitor's device
/// (OS + CPU architecture auto-detected via `DeviceProfileService`); when no
/// asset can be confidently matched the primary action honestly falls back to
/// the GitHub releases page, never to a guessed file.
class LandingDownloadCta extends ConsumerWidget {
  const LandingDownloadCta({super.key});

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final deviceAsync = ref.watch(deviceProfileProvider);
    final smart = ref.watch(smartDownloadProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.32),
              colorScheme.primary.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xl,
            horizontal: AppSpacing.lg,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Get Atlas',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'One click — the right build for your device.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  switch (deviceAsync) {
                    AsyncLoading() => const _DetectingPill(),
                    _ => _SmartDownloadButton(state: smart),
                  },
                  const SizedBox(height: AppSpacing.md),
                  if (smart.profile.isDetected) ...[
                    Text(
                      'Detected: ${smart.profile.summary} · release ${smart.release.versionLabel}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _GlassPillButton(
                    accent: colorScheme.primary,
                    icon: Icons.open_in_new,
                    label: 'Release notes',
                    onPressed: () => _open(smart.release.releasePageUrl),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ManualDownloadGrid(
                    downloads: smart.allDownloads,
                    resolvedUrl: smart.resolved.downloadUrl,
                    fallbackUrl: smart.release.releasePageUrl,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary action, live state: exact artifact → one-click native download;
/// otherwise an honest "see all downloads" external link.
class _SmartDownloadButton extends ConsumerWidget {
  const _SmartDownloadButton({required this.state});

  final SmartDownloadState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final exact = state.isExactMatch;
    final sizeLabel = humanizeBytes(state.resolved.sizeBytes ?? 0);
    final subtitle = exact
        ? [
            state.resolved.fileName ?? '',
            if (sizeLabel.isNotEmpty) sizeLabel,
          ].where((part) => part.isNotEmpty).join(' · ')
        : 'No build matched automatically — pick one below or browse releases.';

    Future<void> onPrimary() async {
      if (exact) {
        LandingAnalytics.event(
          LandingAnalytics.downloadClickEvent,
          params: <String, Object?>{
            'os': state.profile.summary,
            'version': state.release.versionLabel,
            'file': state.resolved.fileName ?? '',
          },
        );
        await ref
            .watch(downloadLauncherProvider)
            .launch(
              url: state.resolved.downloadUrl,
              suggestedFileName: state.resolved.fileName ?? 'atlas.zip',
            );
        return;
      }
      LandingAnalytics.event(
        LandingAnalytics.fallbackClickEvent,
        params: <String, Object?>{
          'os': state.profile.summary,
          'version': state.release.versionLabel,
        },
      );
      await launchUrl(
        Uri.parse(state.resolved.downloadUrl),
        mode: LaunchMode.externalApplication,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onPrimary,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
          child: GlassCapsule(
            borderRadius: AppSpacing.borderRadiusFull,
            blur: 24,
            strong: true,
            fill: colorScheme.primary,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    exact ? Icons.download : Icons.open_in_new,
                    size: 18,
                    color: colorScheme.onPrimary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    state.resolved.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Shimmer glass shell shown while release data / device detection are in
/// flight — never a guessed platform label.
class _DetectingPill extends StatelessWidget {
  const _DetectingPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCapsule(
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
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'Resolving your download…',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Manual chooser for every artifact in the current release plus an external
/// "All releases" escape hatch. The resolved-combo item carries a small "your
/// device" tick so it is obvious which pill equals the smart button.
class _ManualDownloadGrid extends ConsumerWidget {
  const _ManualDownloadGrid({
    required this.downloads,
    required this.resolvedUrl,
    required this.fallbackUrl,
  });

  final List<ResolvedDownload> downloads;
  final String resolvedUrl;
  final String fallbackUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    if (downloads.isEmpty) {
      return _GlassPillButton(
        accent: accent,
        icon: Icons.open_in_new,
        label: 'Browse all downloads on GitHub',
        onPressed: () => launchUrl(
          Uri.parse(fallbackUrl),
          mode: LaunchMode.externalApplication,
        ),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (!downloads.any((d) => d.downloadUrl == resolvedUrl))
          _PlatformButton(
            label: 'All releases',
            isDetectedPick: false,
            externalUrl: fallbackUrl,
          ),
        for (final download in downloads)
          _PlatformButton(
            label: download.label,
            isDetectedPick: download.downloadUrl == resolvedUrl,
            sizeLabel: humanizeBytes(download.sizeBytes ?? 0),
            externalUrl: null,
            directUrl: download.downloadUrl,
            fileName: download.fileName ?? 'atlas.zip',
          ),
      ],
    );
  }
}

/// Grid pill. When [externalUrl] is set the tap opens GitHub; otherwise the
/// tap runs the native download flow through [DownloadLauncher].
class _PlatformButton extends ConsumerWidget {
  const _PlatformButton({
    required this.label,
    required this.isDetectedPick,
    this.externalUrl,
    this.directUrl,
    this.fileName,
    this.sizeLabel = '',
  });

  final String label;
  final bool isDetectedPick;
  final String? externalUrl;
  final String? directUrl;
  final String? fileName;
  final String sizeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final caption = '${isDetectedPick ? 'your device · ' : ''}$sizeLabel'
        .trim();

    Future<void> onTap() async {
      final external = externalUrl;
      if (external != null) {
        await launchUrl(
          Uri.parse(external),
          mode: LaunchMode.externalApplication,
        );
        return;
      }
      LandingAnalytics.event(
        LandingAnalytics.platformPickEvent,
        params: <String, Object?>{'file': fileName ?? '', 'label': label},
      );
      await ref
          .watch(downloadLauncherProvider)
          .launch(url: directUrl!, suggestedFileName: fileName ?? 'atlas.zip');
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      child: GlassCapsule(
        borderRadius: AppSpacing.borderRadiusFull,
        blur: 18,
        strong: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download, size: 16, color: accent),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (isDetectedPick) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(Icons.check_circle, size: 14, color: accent),
                  ],
                ],
              ),
              if (caption.isNotEmpty)
                Text(
                  caption,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDetectedPick
                        ? accent
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPillButton extends StatelessWidget {
  const _GlassPillButton({
    required this.accent,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Color accent;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      child: GlassCapsule(
        borderRadius: AppSpacing.borderRadiusFull,
        blur: 18,
        strong: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
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
