import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/account/presentation/providers/local_account_providers.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/discover/presentation/providers/reading_analytics_providers.dart';
import 'package:atlas_app/notifications/presentation/providers/update_check_settings_provider.dart';
import 'package:atlas_app/onboarding/domain/entities/onboarding_draft.dart';
import 'package:atlas_app/onboarding/domain/repository_interfaces/onboarding_repository_interface.dart';

/// Applies the onboarding choices. Every step is best-effort and independent:
/// a failure (denied permission, locked database) is logged and never traps
/// the user in the flow, and completion is always recorded last.
class OnboardingFinisher {
  const OnboardingFinisher(this._ref, this._repository);

  final Ref _ref;
  final OnboardingRepositoryInterface _repository;

  Future<void> finish(OnboardingDraft draft) async {
    await _step('create local account', () {
      return _ref
          .read(localAccountProvider.notifier)
          .saveProfile(
            displayName: draft.displayName,
            avatarColorIndex: draft.avatarColorIndex,
          );
    });

    final weekly = draft.weeklyChapterTarget;
    final daily = draft.dailyMinuteTarget;
    if (weekly != null || daily != null) {
      await _step('save reading goal', () {
        return _ref
            .read(readingAnalyticsServiceProvider)
            .updateGoal(weeklyChapterTarget: weekly, dailyMinuteTarget: daily);
      });
    }

    if (draft.enableUpdateNotifications) {
      await _step('enable update notifications', () {
        return _ref
            .read(updateCheckSettingsProvider.notifier)
            .setNotificationsEnabled(true);
      });
    }

    await _step('mark onboarding completed', _repository.markCompleted);
  }

  Future<void> _step(String label, Future<void> Function() body) async {
    try {
      await body();
    } catch (e, st) {
      AppLogger.error('Onboarding step "$label" failed', e, st);
    }
  }
}
