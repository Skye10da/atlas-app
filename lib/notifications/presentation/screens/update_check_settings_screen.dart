import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/notifications/domain/entities/update_check_settings.dart';
import 'package:atlas_app/notifications/infrastructure/notification_service.dart';
import 'package:atlas_app/notifications/presentation/providers/update_check_settings_provider.dart';
import 'package:atlas_app/settings/presentation/widgets/settings_widgets.dart';

/// Global preferences for ongoing-novel chapter update checks.
class UpdateCheckSettingsScreen extends HookConsumerWidget {
  const UpdateCheckSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checking = useState(false);
    final testingNotification = useState(false);

    final settings =
        ref.watch(updateCheckSettingsProvider).valueOrNull ??
        const UpdateCheckSettings.defaults();
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Future<void> runCheck() async {
      checking.value = true;
      final messenger = ScaffoldMessenger.of(context);
      try {
        final result = await ref
            .read(chapterUpdateServiceProvider)
            .checkTrackedBooks();
        final message = result.booksWithUpdates == 0
            ? 'No new chapters found.'
            : 'Found ${result.totalNewChapters} new chapter(s) in '
                  '${result.booksWithUpdates} novel(s).';
        messenger.showSnackBar(SnackBar(content: Text(message)));
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Failed to check for updates: $e',
            ),
          ),
        );
      } finally {
        if (context.mounted) checking.value = false;
      }
    }

    Future<void> sendTestNotification() async {
      testingNotification.value = true;
      final messenger = ScaffoldMessenger.of(context);
      try {
        final success = await UpdateNotificationService.instance.showTestNotification(
          delay: Duration.zero,
        );
        if (success) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Test notification sent.')),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('Notifications are not permitted or supported on this device.')),
          );
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not send notification: $e')),
        );
      } finally {
        if (context.mounted) testingNotification.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Novel Updates',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formContentMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            children: [
              // 1. Info Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: colors.primaryContainer,
                      child: Icon(Icons.sync_rounded, color: colors.onPrimaryContainer, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.smMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Background Chapter Tracker',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Automatically queries web novel sources for fresh chapter releases',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 2. Frequency & Checking Section
              _CardSection(
                title: 'Check Schedule',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Check Ongoing Novels'),
                      subtitle: const Text('Periodically look for newly released chapters of tracked novels'),
                      value: settings.enabled,
                      onChanged: ref.read(updateCheckSettingsProvider.notifier).setEnabled,
                    ),
                    if (settings.enabled) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(),
                      const SizedBox(height: AppSpacing.sm),
                      ChoiceTile<int>(
                        title: 'Check Interval',
                        value: settings.intervalHours,
                        options: const [
                          (6, 'Every 6 hours'),
                          (12, 'Every 12 hours'),
                          (24, 'Once daily'),
                        ],
                        onChanged: ref.read(updateCheckSettingsProvider.notifier).setIntervalHours,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 3. Notifications Section
              _CardSection(
                title: 'Notifications',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Chapter Notifications'),
                      subtitle: const Text('Show a system notification when newly released chapters are discovered'),
                      value: settings.notificationsEnabled,
                      onChanged: ref.read(updateCheckSettingsProvider.notifier).setNotificationsEnabled,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 4. Actions Section
              _CardSection(
                title: 'Actions',
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.notifications_active_outlined, color: colors.primary),
                      title: const Text('Send Test Notification'),
                      subtitle: const Text('Verify that system alerts and channel sounds are working properly'),
                      trailing: testingNotification.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: testingNotification.value ? null : sendTestNotification,
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.refresh_rounded, color: colors.primary),
                      title: const Text('Check All Tracked Novels Now'),
                      subtitle: const Text('Run an immediate check across your entire library'),
                      trailing: checking.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: checking.value ? null : runCheck,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.smMd),
          child,
        ],
      ),
    );
  }
}
