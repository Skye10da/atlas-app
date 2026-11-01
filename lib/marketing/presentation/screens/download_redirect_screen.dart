import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/marketing/domain/services/landing_analytics.dart';
import 'package:atlas_app/marketing/presentation/providers/landing_providers.dart';

/// `/#/download` — social-inline CTA destination ("grab it at
/// atlas-app.dev/download").
///
/// Flow: resolve the visitor's device + the latest release → fire the native
/// download once → show a receipt with a manual escape hatch. Fires exactly
/// once per screen entry (rebuilds never re-trigger), and degrades honestly
/// to the releases page when no artifact matched.
class DownloadRedirectScreen extends ConsumerStatefulWidget {
  const DownloadRedirectScreen({super.key});

  @override
  ConsumerState<DownloadRedirectScreen> createState() =>
      _DownloadRedirectScreenState();
}

class _DownloadRedirectScreenState
    extends ConsumerState<DownloadRedirectScreen> {
  bool _triggered = false;
  bool _fired = false;
  String? _launchedUrl;
  ProviderSubscription<SmartDownloadState>? _subscription;

  @override
  void initState() {
    super.initState();
    // Trigger as soon as BOTH the release lookup and the device probe have
    // settled — no guessing from curated fallbacks.
    _subscription = ref.listenManual<SmartDownloadState>(
      smartDownloadProvider,
      (_, _) => _maybeTrigger(),
    );
    _maybeTrigger();
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  void _maybeTrigger() {
    if (_triggered) return;
    final deviceReady = ref.read(deviceProfileProvider).hasValue;
    if (!deviceReady) return; // wait for the detector to settle
    final smart = ref.read(smartDownloadProvider);
    if (!smart.isExactMatch) {
      _triggered = true; // no confident match; the fallback UI is the receipt
      return;
    }
    _triggered = true;
    unawaited(_fireDownload(smart));
  }

  Future<void> _fireDownload(SmartDownloadState smart) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    LandingAnalytics.event(
      LandingAnalytics.downloadClickEvent,
      params: <String, Object?>{
        'os': smart.profile.summary,
        'version': smart.release.versionLabel,
        'file': smart.resolved.fileName ?? '',
        'entry': 'redirect',
      },
    );
    try {
      await ref
          .read(downloadLauncherProvider)
          .launch(
            url: smart.resolved.downloadUrl,
            suggestedFileName: smart.resolved.fileName ?? 'atlas.zip',
          );
      if (!mounted) return;
      setState(() {
        _fired = true;
        _launchedUrl = smart.resolved.downloadUrl;
      });
    } catch (_) {
      // Launch failure leaves the interstitial; the direct-link and
      // releases-page escape hatches are always visible below.
    }
  }

  @override
  Widget build(BuildContext context) {
    final smart = ref.watch(smartDownloadProvider);
    final deviceAsync = ref.watch(deviceProfileProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A12)
          : const Color(0xFFF6F3EC),
      body: Center(
        child: GlassCapsule(
          borderRadius: 32,
          blur: 24,
          strong: true,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    smart.isExactMatch
                        ? Icons.download_rounded
                        : Icons.open_in_new_rounded,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    smart.isExactMatch
                        ? (_fired
                              ? 'Your download is running'
                              : 'Starting your download…')
                        : 'Pick your Atlas build',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    switch ((smart.isExactMatch, _fired)) {
                      (true, true) =>
                        '${smart.resolved.label} from the latest release. If the browser blocked it, use the direct link below.',
                      (true, false) =>
                        'Detected ${smart.profile.summary} — resolving the latest matching artifact…',
                      (false, false) =>
                        'We could not confidently match an artifact for your device. Choose from every published build instead.',
                      (false, true) => 'Choose from every published build.',
                    },
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (smart.isExactMatch && _fired) ...[
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(_launchedUrl ?? ''),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Direct download link'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(smart.release.releasePageUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.folder_outlined),
                    label: const Text('All downloads on GitHub'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text('Back to the site'),
                  ),
                  if (deviceAsync.isLoading) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
