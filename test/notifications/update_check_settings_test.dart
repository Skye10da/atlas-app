import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas_app/notifications/domain/entities/update_check_settings.dart';
import 'package:atlas_app/notifications/infrastructure/update_check_settings_store.dart';

void main() {
  group('UpdateCheckSettings', () {
    test('defaults match specifications', () {
      const settings = UpdateCheckSettings.defaults();
      expect(settings.enabled, isTrue);
      expect(settings.intervalHours, 24);
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.wifiOnly, isFalse);
      expect(settings.quietHoursEnabled, isFalse);
      expect(settings.quietHoursStart, 22);
      expect(settings.quietHoursEnd, 7);
      expect(settings.soundEnabled, isTrue);
      expect(settings.vibrationEnabled, isTrue);
      expect(settings.autoDownloadChapters, isFalse);
      expect(settings.groupingMode, NotificationGroupingMode.both);
    });

    test('copyWith updates fields correctly', () {
      const original = UpdateCheckSettings.defaults();
      final updated = original.copyWith(
        enabled: false,
        intervalHours: 6,
        wifiOnly: true,
        quietHoursEnabled: true,
        quietHoursStart: 23,
        quietHoursEnd: 8,
        soundEnabled: false,
        vibrationEnabled: false,
        autoDownloadChapters: true,
        groupingMode: NotificationGroupingMode.individual,
      );

      expect(updated.enabled, isFalse);
      expect(updated.intervalHours, 6);
      expect(updated.wifiOnly, isTrue);
      expect(updated.quietHoursEnabled, isTrue);
      expect(updated.quietHoursStart, 23);
      expect(updated.quietHoursEnd, 8);
      expect(updated.soundEnabled, isFalse);
      expect(updated.vibrationEnabled, isFalse);
      expect(updated.autoDownloadChapters, isTrue);
      expect(updated.groupingMode, NotificationGroupingMode.individual);
    });
  });

  group('UpdateCheckSettingsStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and loads extended settings round-trip', () async {
      final store = UpdateCheckSettingsStore();
      const settings = UpdateCheckSettings(
        enabled: true,
        intervalHours: 3,
        notificationsEnabled: true,
        wifiOnly: true,
        quietHoursEnabled: true,
        quietHoursStart: 21,
        quietHoursEnd: 6,
        soundEnabled: false,
        vibrationEnabled: true,
        autoDownloadChapters: true,
        groupingMode: NotificationGroupingMode.bundled,
      );

      await store.save(settings);
      final loaded = await UpdateCheckSettingsStore.load();

      expect(loaded.enabled, isTrue);
      expect(loaded.intervalHours, 3);
      expect(loaded.notificationsEnabled, isTrue);
      expect(loaded.wifiOnly, isTrue);
      expect(loaded.quietHoursEnabled, isTrue);
      expect(loaded.quietHoursStart, 21);
      expect(loaded.quietHoursEnd, 6);
      expect(loaded.soundEnabled, isFalse);
      expect(loaded.vibrationEnabled, isTrue);
      expect(loaded.autoDownloadChapters, isTrue);
      expect(loaded.groupingMode, NotificationGroupingMode.bundled);
    });

    group('isWithinQuietHours', () {
      test('returns false when quiet hours is disabled', () {
        const settings = UpdateCheckSettings(
          enabled: true,
          intervalHours: 24,
          notificationsEnabled: true,
          quietHoursEnabled: false,
          quietHoursStart: 22,
          quietHoursEnd: 7,
        );

        final atMidnight = DateTime(2026, 9, 10, 0, 30);
        expect(UpdateCheckSettingsStore.isWithinQuietHours(atMidnight, settings), isFalse);
      });

      test('handles midnight-crossing window correctly (22:00 to 07:00)', () {
        const settings = UpdateCheckSettings(
          enabled: true,
          intervalHours: 24,
          notificationsEnabled: true,
          quietHoursEnabled: true,
          quietHoursStart: 22,
          quietHoursEnd: 7,
        );

        expect(UpdateCheckSettingsStore.isWithinQuietHours(DateTime(2026, 9, 10, 21, 59), settings), isFalse);
        expect(UpdateCheckSettingsStore.isWithinQuietHours(DateTime(2026, 9, 10, 22, 0), settings), isTrue);
        expect(UpdateCheckSettingsStore.isWithinQuietHours(DateTime(2026, 9, 10, 23, 30), settings), isTrue);
        expect(UpdateCheckSettingsStore.isWithinQuietHours(DateTime(2026, 9, 10, 0, 0), settings), isTrue);
        expect(UpdateCheckSettingsStore.isWithinQuietHours(DateTime(2026, 9, 10, 6, 59), settings), isTrue);
        expect(UpdateCheckSettingsStore.isWithinQuietHours(DateTime(2026, 9, 10, 7, 0), settings), isFalse);
        expect(UpdateCheckSettingsStore.isWithinQuietHours(DateTime(2026, 9, 10, 14, 0), settings), isFalse);
      });

      test('handles same-day standard window correctly (13:00 to 17:00)', () {
        const settings = UpdateCheckSettings(
          enabled: true,
          intervalHours: 24,
          notificationsEnabled: true,
          quietHoursEnabled: true,
          quietHoursStart: 13,
          quietHoursEnd: 17,
        );

        expect(UpdateCheckSettingsStore.isWithinQuietHours(DateTime(2026, 9, 10, 12, 59), settings), isFalse);
        expect(UpdateCheckSettingsStore.isWithinQuietHours(DateTime(2026, 9, 10, 13, 0), settings), isTrue);
        expect(UpdateCheckSettingsStore.isWithinQuietHours(DateTime(2026, 9, 10, 16, 59), settings), isTrue);
        expect(UpdateCheckSettingsStore.isWithinQuietHours(DateTime(2026, 9, 10, 17, 0), settings), isFalse);
      });
    });
  });
}
