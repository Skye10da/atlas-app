import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/molecules/app_snackbar.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/updater/domain/changelog_text.dart';
import 'package:atlas_app/updater/domain/entities/changelog_entry.dart';
import 'package:atlas_app/updater/domain/repositories/app_update_repository.dart';
import 'package:atlas_app/updater/presentation/providers/updater_providers.dart';

/// Settings → What's new: every release's notes, newest first, captured at
/// update time and refreshed from GitHub Releases when opened. Also the
/// landing page for the post-update banner.
class WhatsNewScreen extends ConsumerStatefulWidget {
  const WhatsNewScreen({super.key});

  @override
  ConsumerState<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends ConsumerState<WhatsNewScreen> {
  @override
  void initState() {
    super.initState();
    // Cached entries render from the initial build; this repairs/expands the
    // history from the network, surfacing only persistent errors.
    unawaited(_refreshOnOpen());
  }

  Future<void> _refreshOnOpen() async {
    try {
      await ref.read(changelogControllerProvider.notifier).refresh();
    } on AppUpdateException catch (e) {
      AppLogger.error('Changelog refresh failed on open', e);
    } catch (e, st) {
      AppLogger.error('Changelog refresh crashed on open', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(changelogControllerProvider);
    final currentBuild = ref.watch(
      updaterControllerProvider.select((value) => value.valueOrNull?.currentBuild),
    );

    return Scaffold(
      appBar: AppBar(title: const Text("What's new")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.shellContentMaxWidth,
          ),
          child: RefreshIndicator(
            onRefresh: () async {
              try {
                await ref.read(changelogControllerProvider.notifier).refresh();
              } on AppUpdateException catch (e) {
                AppSnackBar.showError(e.userMessage);
              } catch (_) {
                AppSnackBar.showError('Could not refresh the changelog.');
              }
            },
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      '$e',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'No release notes recorded yet. They appear here '
                          'after your first update, and whenever a new Atlas '
                          'release ships.',
                        ),
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) => _ChangelogCard(
                    entry: entries[index],
                    isInstalledVersion:
                        currentBuild == entries[index].versionCode,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// One version's notes, rendered from the cached release body.
class _ChangelogCard extends StatelessWidget {
  const _ChangelogCard({
    required this.entry,
    required this.isInstalledVersion,
  });

  final ChangelogEntry entry;
  final bool isInstalledVersion;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final released = entry.publishedAt;
    final dateText = released.year > 2000
        ? MaterialLocalizations.of(context).formatMediumDate(released)
        : '';

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        side: BorderSide(
          color: isInstalledVersion
              ? colors.primary.withValues(alpha: 0.4)
              : colors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isInstalledVersion
                      ? Icons.auto_awesome_rounded
                      : Icons.history_rounded,
                  size: 20,
                  color: isInstalledVersion
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Atlas ${entry.version}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (dateText.isNotEmpty)
                  Text(
                    dateText,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (isInstalledVersion) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Installed on this device',
                style: textTheme.labelSmall?.copyWith(color: colors.primary),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              entry.notes.trim().isEmpty
                  ? 'No release notes were published for this version.'
                  : ChangelogText.render(entry.notes),
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
