import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/application/chapter_update_service.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/notifications/domain/entities/update_check_settings.dart';
import 'package:atlas_app/notifications/infrastructure/notification_service.dart';
import 'package:atlas_app/notifications/presentation/providers/update_check_settings_provider.dart';
import 'package:atlas_app/settings/presentation/widgets/settings_widgets.dart';

/// Global preferences for ongoing-novel chapter update checks.
class UpdateCheckSettingsScreen extends ConsumerStatefulWidget {
  const UpdateCheckSettingsScreen({super.key});

  @override
  ConsumerState<UpdateCheckSettingsScreen> createState() =>
      _UpdateCheckSettingsScreenState();
}

class _UpdateCheckSettingsScreenState
    extends ConsumerState<UpdateCheckSettingsScreen> {
  bool _checking = false;
  bool _testingNotification = false;

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(updateCheckSettingsProvider).valueOrNull ??
        const UpdateCheckSettings.defaults();

    return Scaffold(
      appBar: AppBar(title: const Text('Novel Updates')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          const SectionHeader(title: 'UPDATE CHECKING'),
          SettingsGroup(
            children: [
              SwitchTile(
                title: 'Check ongoing novels',
                subtitle:
                    'Periodically look for newly released chapters of novels '
                    'you track',
                value: settings.enabled,
                onChanged: ref
                    .read(updateCheckSettingsProvider.notifier)
                    .setEnabled,
              ),
              if (settings.enabled)
                ChoiceTile<int>(
                  title: 'Check interval',
                  value: settings.intervalHours,
                  options: const [
                    (6, 'Every 6 h'),
                    (12, 'Every 12 h'),
                    (24, 'Daily'),
                  ],
                  onChanged: ref
                      .read(updateCheckSettingsProvider.notifier)
                      .setIntervalHours,
                ),
            ],
          ),
          const SectionHeader(title: 'NOTIFICATIONS'),
          SettingsGroup(
            children: [
              SwitchTile(
                title: 'New-chapter notifications',
                subtitle:
                    'Show a system notification when new chapters '
                    'are found',
                value: settings.notificationsEnabled,
                onChanged: ref
                    .read(updateCheckSettingsProvider.notifier)
                    .setNotificationsEnabled,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: OutlinedButton.icon(
              icon: _testingNotification
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_active_outlined),
              label: const Text('Send test notification'),
              onPressed: _testingNotification
                  ? null
                  : () => _sendTestNotification(context),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: OutlinedButton.icon(
              icon: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Check all tracked novels now'),
              onPressed: _checking ? null : () => _runCheck(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runCheck(BuildContext context) async {
    setState(() => _checking = true);
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
            'Update check failed: '
            '${ChapterUpdateService.describeFailure(e)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _sendTestNotification(BuildContext context) async {
    setState(() => _testingNotification = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Test notification will appear in ~10 seconds '
          '(grant the notification permission if prompted).',
        ),
      ),
    );
    try {
      final ok = await UpdateNotificationService.instance
          .showTestNotification();
      if (ok) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Test notification not shown — permission denied or '
            'notifications unavailable.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Test notification failed.')),
      );
    } finally {
      if (mounted) setState(() => _testingNotification = false);
    }
  }
}
