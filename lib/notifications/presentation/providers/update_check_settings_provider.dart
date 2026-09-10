import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/notifications/domain/entities/update_check_settings.dart';
import 'package:atlas_app/notifications/infrastructure/background_update_check.dart';
import 'package:atlas_app/notifications/infrastructure/notification_service.dart';
import 'package:atlas_app/notifications/infrastructure/update_check_settings_store.dart';

/// Exposes the persisted [UpdateCheckSettings] and persists mutations,
/// re-registering the OS-level periodic task whenever the interval or the
/// master toggle changes.
class UpdateCheckSettingsNotifier extends AsyncNotifier<UpdateCheckSettings> {
  @override
  Future<UpdateCheckSettings> build() => UpdateCheckSettingsStore.load();

  Future<void> _persist(UpdateCheckSettings settings) async {
    state = AsyncData(settings);
    await UpdateCheckSettingsStore().save(settings);
    // Keep the synchronous mirror in sync for the in-app scheduler.
    ref.read(updateCheckIntervalHoursProvider.notifier).state =
        settings.intervalHours;
    await initializeBackgroundUpdateChecks(settings);
  }

  Future<void> setEnabled(bool enabled) async {
    await _persist(
      (state.valueOrNull ?? const UpdateCheckSettings.defaults()).copyWith(
        enabled: enabled,
      ),
    );
  }

  Future<void> setIntervalHours(int hours) async {
    await _persist(
      (state.valueOrNull ?? const UpdateCheckSettings.defaults()).copyWith(
        intervalHours: hours,
      ),
    );
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (enabled) {
      await UpdateNotificationService.instance.requestPermission();
    }
    await _persist(
      (state.valueOrNull ?? const UpdateCheckSettings.defaults()).copyWith(
        notificationsEnabled: enabled,
      ),
    );
  }

  Future<void> setWifiOnly(bool wifiOnly) async {
    await _persist(
      (state.valueOrNull ?? const UpdateCheckSettings.defaults()).copyWith(
        wifiOnly: wifiOnly,
      ),
    );
  }

  Future<void> setQuietHoursEnabled(bool enabled) async {
    await _persist(
      (state.valueOrNull ?? const UpdateCheckSettings.defaults()).copyWith(
        quietHoursEnabled: enabled,
      ),
    );
  }

  Future<void> setQuietHoursWindow({
    required int start,
    required int end,
  }) async {
    await _persist(
      (state.valueOrNull ?? const UpdateCheckSettings.defaults()).copyWith(
        quietHoursStart: start,
        quietHoursEnd: end,
      ),
    );
  }

  Future<void> setSoundEnabled(bool enabled) async {
    await _persist(
      (state.valueOrNull ?? const UpdateCheckSettings.defaults()).copyWith(
        soundEnabled: enabled,
      ),
    );
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    await _persist(
      (state.valueOrNull ?? const UpdateCheckSettings.defaults()).copyWith(
        vibrationEnabled: enabled,
      ),
    );
  }

  Future<void> setAutoDownloadChapters(bool enabled) async {
    await _persist(
      (state.valueOrNull ?? const UpdateCheckSettings.defaults()).copyWith(
        autoDownloadChapters: enabled,
      ),
    );
  }

  Future<void> setGroupingMode(NotificationGroupingMode mode) async {
    await _persist(
      (state.valueOrNull ?? const UpdateCheckSettings.defaults()).copyWith(
        groupingMode: mode,
      ),
    );
  }
}

final updateCheckSettingsProvider =
    AsyncNotifierProvider<UpdateCheckSettingsNotifier, UpdateCheckSettings>(
      UpdateCheckSettingsNotifier.new,
    );

/// Synchronous mirror of the persisted check interval, consumed by the
/// in-app [TaskScheduler] resolver. Seeded at bootstrap from persisted
/// settings.
final updateCheckIntervalHoursProvider = StateProvider<int>((ref) => 24);
