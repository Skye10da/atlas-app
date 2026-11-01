import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:atlas_app/core/design_system/molecules/app_snackbar.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/updater/application/updater_controller.dart';
import 'package:atlas_app/updater/domain/changelog_text.dart';
import 'package:atlas_app/updater/domain/entities/app_release.dart';
import 'package:atlas_app/updater/domain/repositories/app_update_repository.dart';
import 'package:atlas_app/updater/presentation/providers/updater_providers.dart';

/// Settings → App updates: the settings UI for Atlas's self-updater
/// (docs/release.md). Shows the installed version, latest release, and drives
/// check → download → install on Android & Windows.
class AppUpdateSettingsScreen extends ConsumerWidget {
  const AppUpdateSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(updaterControllerProvider);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('App updates')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.shellContentMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            children: [
              Text(
                'Atlas updates itself directly from GitHub Releases — no app '
                'store involved. Builds are produced by the release workflow '
                'and verified against a SHA-256 manifest before installing.',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              stateAsync.when(
                loading: () => const Center(
                  heightFactor: 4,
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => _StatusCard(
                  icon: Icons.cloud_off_rounded,
                  color: colors.error,
                  title: 'Update state unavailable',
                  message: '$e',
                ),
                data: (state) => Column(
                  children: [
                    _VersionCard(
                      version: state.currentVersion,
                      buildCode: state.currentBuild,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const _WhatsNewCard(),                    const SizedBox(height: AppSpacing.sm),
                    _StatusCard.fromState(state, ref, context),
                    const SizedBox(height: AppSpacing.lg),
                    _SettingsCard.fromState(state, ref),
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

class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.version, required this.buildCode});

  final String version;
  final int buildCode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: Icon(Icons.apps, color: colors.primary),
        title: Text('Atlas $version'),
        subtitle: Text(
          'Installed (version code $buildCode)',
          style: textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Card linking to the full release-notes history (WhatsNewScreen, also the
/// landing page of the post-update banner).
class _WhatsNewCard extends StatelessWidget {
  const _WhatsNewCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: Icon(Icons.auto_awesome_rounded, color: colors.primary),
        title: const Text("What's new"),
        subtitle: const Text(
          "Every version's release notes, readable anytime.",
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/whats-new'),
      ),
    );
  }
}

/// Renders the phase-driven status line plus the primary action button.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.trailing,
    this.onPrimary,
    this.primaryLabel,
    this.onSecondary,
    this.secondaryLabel,
    this.onTertiary,
    this.tertiaryLabel,
  });

  factory _StatusCard.fromState(UpdaterState state, WidgetRef ref, BuildContext context) {
    return switch (state.phase) {
      UpdaterPhase.idle => _StatusCard(
          icon: Icons.update_rounded,
          color: Colors.blueGrey,
          title: 'Never checked',
          message: 'Tap "Check now" to look for a newer release.',
          primaryLabel: 'Check now',
          onPrimary: () => _checkNow(ref),
        ),
      UpdaterPhase.checking => const _StatusCard(
          icon: Icons.cloud_sync_outlined,
          color: Colors.blueGrey,
          title: 'Checking GitHub…',
          message: 'Asking the Releases feed for the newest build.',
        ),
      UpdaterPhase.upToDate => _StatusCard(
          icon: Icons.verified_rounded,
          color: Colors.green,
          title: 'You are up to date',
          message:
              'Installed: ${state.currentVersion}. Latest: ${state.release?.version ?? state.currentVersion}.',
          primaryLabel: 'Check again',
          onPrimary: () => _checkNow(ref),
        ),
      UpdaterPhase.available => _StatusCard(
          icon: Icons.install_mobile_rounded,
          color: Colors.blue,
          title: 'Atlas ${state.release?.version} is available',
          message:
              'A newer build is ready. Read the changelog before installing.',
          primaryLabel: 'Download update',
          onPrimary: state.installAvailable ? () => _startDownload(ref) : null,
          secondaryLabel: 'Skip this version',
          onSecondary: () =>
              ref.read(updaterControllerProvider.notifier).skipThisVersion(),
          tertiaryLabel: 'Read changelog',
          onTertiary: state.release == null
              ? null
              : () => _showReleaseNotesDialog(context, state.release!),
        ),
      UpdaterPhase.downloading => _StatusCard(
          icon: Icons.downloading_rounded,
          color: Colors.blue,
          title: 'Downloading… ${(state.downloadProgress * 100).toStringAsFixed(0)}%',
          message: 'The package is verified with SHA-256 as it downloads.',
          trailing: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: LinearProgressIndicator(value: state.downloadProgress),
          ),
        ),
      UpdaterPhase.readyToInstall => _StatusCard(
          icon: Icons.task_alt_rounded,
          color: Colors.green,
          title: 'Atlas ${state.release?.version ?? "update"} downloaded',
          message: 'Everything verified — install when you are ready.',
          primaryLabel: 'Install now',
          onPrimary: state.installAvailable
              ? () => ref.read(updaterControllerProvider.notifier).install()
              : null,
          secondaryLabel: 'Discard download',
          onSecondary: () =>
              ref.read(updaterControllerProvider.notifier).discardDownload(),
          tertiaryLabel: state.release == null ? null : 'Read changelog',
          onTertiary: state.release == null
              ? null
              : () => _showReleaseNotesDialog(context, state.release!),
        ),
      UpdaterPhase.installing => const _StatusCard(
          icon: Icons.autorenew_rounded,
          color: Colors.orange,
          title: 'Handing off to the installer…',
          message:
              'Windows: Atlas restarts when the swap finishes. Android: accept '
              'the system prompt.',
        ),
      UpdaterPhase.error => _StatusCard(
          icon: Icons.error_outline_rounded,
          color: Colors.red,
          title: 'Update error',
          message: state.error ?? 'Something went wrong.',
          primaryLabel: 'Close',
          onPrimary: () =>
              ref.read(updaterControllerProvider.notifier).dismissError(),
        ),
    };
  }

  static Future<void> _checkNow(WidgetRef ref) =>
      ref.read(updaterControllerProvider.notifier).checkNow();

  static Future<void> _startDownload(WidgetRef ref) async {
    try {
      await ref.read(updaterControllerProvider.notifier).startDownload();
    } on AppUpdateException catch (e) {
      AppSnackBar.showError(e.userMessage);
    } catch (_) {
      AppSnackBar.showError('Could not start the update download.');
    }
  }

  static Future<void> _openRelease(AppRelease? release) async {
    final url = release?.releaseUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Read-before-install: the pending release's notes in a dialog, with the
  /// GitHub page as the escape hatch for anything the renderer skips.
  static Future<void> _showReleaseNotesDialog(
    BuildContext context,
    AppRelease release,
  ) {
    final colors = Theme.of(context).colorScheme;
    final notes = release.notes ?? '';
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("What's new in Atlas ${release.version}"),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Text(
              notes.trim().isEmpty
                  ? 'No release notes were published for this version.'
                  : ChangelogText.render(notes),
              style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
          ),
        ),
        actions: [
          if (release.releaseUrl != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _openRelease(release);
              },
              child: const Text('View on GitHub'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final Widget? trailing;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            ?trailing,
            if (primaryLabel != null ||
                secondaryLabel != null ||
                tertiaryLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    if (primaryLabel != null)
                      FilledButton.icon(
                        onPressed: onPrimary,
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(primaryLabel!),
                      ),
                    if (secondaryLabel != null)
                      TextButton(
                        onPressed: onSecondary,
                        child: Text(secondaryLabel!),
                      ),
                    if (tertiaryLabel != null)
                      TextButton(
                        onPressed: onTertiary,
                        child: Text(tertiaryLabel!),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Auto-check toggle + release channel selection.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard.fromState(this.state, this.ref);

  final UpdaterState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = ref.read(updaterControllerProvider.notifier);
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: state.autoCheck,
            onChanged: controller.setAutoCheck,
            title: const Text('Check automatically'),
            subtitle: const Text(
              'Once per day at startup. You still choose when to install.',
            ),
          ),
          RadioGroup<UpdateChannel>(
            groupValue: state.channel,
            // The group delivers the selected value; null is impossible here.
            onChanged: (channel) {
              if (channel != null) controller.setChannel(channel);
            },
            child: const Column(
              children: [
                RadioListTile<UpdateChannel>(
                  value: UpdateChannel.stable,
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text('Stable releases only'),
                ),
                RadioListTile<UpdateChannel>(
                  value: UpdateChannel.beta,
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text('Include beta releases'),
                  subtitle: Text(
                    'Preview builds tagged as prereleases — expect rough edges.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
