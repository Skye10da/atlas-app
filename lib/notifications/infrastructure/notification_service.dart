import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/core/router/app_router.dart';

/// Thin wrapper around `flutter_local_notifications` for "new chapters"
/// notifications.
///
/// Tapping a notification deep-links to the novel's details screen via the
/// payload (a go_router path). Initialization failures are logged and
/// swallowed: notifications are a nice-to-have and must never break startup,
/// including on platforms where the plugin is unsupported.
class UpdateNotificationService {
  UpdateNotificationService._();

  static final UpdateNotificationService instance =
      UpdateNotificationService._();

  static const _channelId = 'chapter_updates';
  static const _channelName = 'New chapters';
  static const _channelDescription =
      'Notifies when tracked ongoing novels release new chapters';
  static const _summaryId = 42001;
  static const _testNotificationId = 42002;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Whether OS notifications can be shown on this platform at all.
  static bool get isSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isWindows;

  Future<void> initialize() async {
    if (_initialized || !isSupported) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
          windows: WindowsInitializationSettings(
            appName: 'Atlas',
            appUserModelId: 'com.atlas.app',
            guid: '7f6e5d4c-3b2a-4918-8a7b-6c5d4e3f2a1b',
          ),
        ),
        onDidReceiveNotificationResponse: _handleTap,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
            ),
          );
      _initialized = true;
    } catch (e) {
      AppLogger.warning('Notification init failed: $e');
    }
  }

  /// Requests the POST_NOTIFICATIONS runtime permission (Android 13+) or
  /// alerts/badge permissions (iOS/macOS). Returns true when granted or when
  /// no permission is required on this platform.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await initialize();
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
      if (Platform.isIOS || Platform.isMacOS) {
        final impl = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await impl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      }
      return true;
    } catch (e) {
      AppLogger.warning('Notification permission request failed: $e');
      return false;
    }
  }

  /// Shows one summary notification for all books that gained chapters, e.g.
  /// "3 new chapters — Shadow Slave (2), Other Novel (1)".
  Future<void> showUpdateSummary(
    List<({String title, String bookId, int count})> updates,
  ) async {
    if (!_initialized || updates.isEmpty) return;
    final total = updates.fold<int>(0, (sum, u) => sum + u.count);
    final detail = updates.length == 1
        ? '${updates.first.title} (${updates.first.count})'
        : updates.map((u) => '${u.title} (${u.count})').join(', ');
    try {
      // Single-book updates deep-link straight to that novel; multi-book
      // summaries land in the library.
      final payload = updates.length == 1
          ? '/novel/${updates.first.bookId}'
          : '/library';
      await _plugin.show(
        id: _summaryId,
        title: '$total new chapter${total == 1 ? '' : 's'}',
        body: detail,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      AppLogger.warning('Failed to show update notification: $e');
    }
  }

  /// Shows a test notification after [delay] to verify the notification
  /// pipeline end-to-end. Requests the OS permission first when needed.
  /// Returns false if permission was denied or the notification failed.
  Future<bool> showTestNotification({
    Duration delay = const Duration(seconds: 10),
  }) async {
    final granted = await requestPermission();
    if (!granted) {
      AppLogger.warning('Test notification skipped: permission not granted');
      return false;
    }
    await Future<void>.delayed(delay);
    if (!_initialized) return false;
    try {
      await _plugin.show(
        id: _testNotificationId,
        title: 'Atlas test notification',
        body: 'Notifications are working. Shown ${delay.inSeconds}s after launch.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
      return true;
    } catch (e) {
      AppLogger.warning('Test notification failed: $e');
      return false;
    }
  }

  static void _handleTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    AppRouter.router.push(payload);
  }
}
