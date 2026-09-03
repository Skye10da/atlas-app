import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/core/router/app_router.dart';

/// A simple data class for notification history entries.
class NotificationEntry {
  const NotificationEntry({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
    this.bookId,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final String? payload;
  final String? bookId;
  final bool isRead;
  final DateTime createdAt;
}

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

  /// In-memory cache of the database instance, set lazily.
  AppDatabase? _db;

  /// Subject that emits the current list of all notification history entries.
  final _historyController =
      BehaviorSubject<List<NotificationEntry>>.seeded([]);

  /// Subject that emits the unread notification count.
  final _unreadCountController = BehaviorSubject<int>.seeded(0);

  /// Stream of all notification history entries (newest first).
  Stream<List<NotificationEntry>> get historyStream =>
      _historyController.stream;

  /// Stream of unread notification count.
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  /// Current unread count (synchronous read from the subject).
  int get currentUnreadCount => _unreadCountController.value;

  /// Whether OS notifications can be shown on this platform at all.
  static bool get isSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isWindows;

  /// Initializes the notification service. Call once during app bootstrap.
  ///
  /// Optionally pass a [db] instance to enable persistence. When provided,
  /// notification history is stored in the database and the unread count
  /// badge is kept in sync.
  Future<void> initialize({AppDatabase? db}) async {
    if (_initialized || !isSupported) return;
    _db = db;
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

      // Load initial history from DB if persistence is available.
      if (_db != null) {
        await _refreshHistory();
      }

      // Handle cold-start notification tap (app launched from killed state).
      await _handleColdStartTap();
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

      // Persist each update as a separate history entry.
      if (_db != null) {
        for (final update in updates) {
          await _db!.customStatement(
            'INSERT INTO notification_history (title, body, payload, book_id, is_read, created_at) VALUES (?, ?, ?, ?, 0, ?)',
            [
              '$total new chapter${total == 1 ? '' : 's'}',
              '${update.title} (${update.count} new)',
              '/novel/${update.bookId}',
              update.bookId,
              DateTime.now().toIso8601String(),
            ],
          );
        }
        await _refreshHistory();
      }
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

      // Persist the test notification.
      if (_db != null) {
        await _db!.customStatement(
          'INSERT INTO notification_history (title, body, payload, book_id, is_read, created_at) VALUES (?, ?, ?, ?, 0, ?)',
          [
            'Atlas test notification',
            'Notifications are working.',
            null,
            null,
            DateTime.now().toIso8601String(),
          ],
        );
        await _refreshHistory();
      }
      return true;
    } catch (e) {
      AppLogger.warning('Test notification failed: $e');
      return false;
    }
  }

  /// Marks all notifications as read (clears the unread badge).
  Future<void> markAllAsRead() async {
    if (_db == null) return;
    await _db!.customStatement(
      'UPDATE notification_history SET is_read = 1 WHERE is_read = 0',
    );
    await _refreshHistory();
  }

  /// Marks a single notification as read by its id.
  Future<void> markAsRead(int notificationId) async {
    if (_db == null) return;
    await _db!.customStatement(
      'UPDATE notification_history SET is_read = 1 WHERE id = ?',
      [notificationId],
    );
    await _refreshHistory();
  }

  /// Deletes all notification history entries.
  Future<void> clearAll() async {
    if (_db == null) return;
    await _db!.customStatement('DELETE FROM notification_history');
    await _refreshHistory();
  }

  /// Deletes a single notification history entry by its id.
  Future<void> delete(int notificationId) async {
    if (_db == null) return;
    await _db!.customStatement(
      'DELETE FROM notification_history WHERE id = ?',
      [notificationId],
    );
    await _refreshHistory();
  }

  /// Refreshes the in-memory history list and unread count from the database.
  Future<void> _refreshHistory() async {
    if (_db == null) return;
    final rows = await _db!.customSelect(
      'SELECT * FROM notification_history ORDER BY created_at DESC',
    ).get();
    final entries = rows.map((row) {
      return NotificationEntry(
        id: row.read<int>('id'),
        title: row.read<String>('title'),
        body: row.read<String>('body'),
        payload: row.read<String?>('payload'),
        bookId: row.read<String?>('book_id'),
        isRead: row.read<bool>('is_read'),
        createdAt: DateTime.parse(row.read<String>('created_at')),
      );
    }).toList();
    _historyController.add(entries);
    final unreadCount = entries.where((n) => !n.isRead).length;
    _unreadCountController.add(unreadCount);
  }

  /// Handles cold-start notification tap (app launched from killed state).
  Future<void> _handleColdStartTap() async {
    if (!isSupported) return;
    try {
      // Check if the app was launched by tapping a notification.
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (impl != null) {
        // Android: getActiveNotifications doesn't give us the launch payload.
        // For proper cold-start handling, we'd need getNotificationAppLaunchInfo
        // which requires flutter_local_notifications >= 17.x
        await impl.getActiveNotifications();
      }
    } catch (e) {
      AppLogger.warning('Cold-start notification tap handling failed: $e');
    }
  }

  static void _handleTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    AppRouter.router.push(payload);
  }

  /// Disposes the subjects. Call only when the service is no longer needed.
  void dispose() {
    _historyController.close();
    _unreadCountController.close();
  }
}
