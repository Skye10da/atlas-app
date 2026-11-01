import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show WidgetsBinding, AppLifecycleState;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/design_system/molecules/app_toast.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/core/router/app_router.dart';
import 'package:atlas_app/notifications/domain/entities/update_check_settings.dart';
import 'package:atlas_app/notifications/infrastructure/update_check_settings_store.dart';

/// True when the app window is visible right now — in that case notifications
/// surface as in-app glass toast pills instead of OS drawer entries.
bool _appIsForeground() {
  try {
    if (!WidgetsBinding.instance.isRootWidgetAttached) return false;
    return WidgetsBinding.instance.lifecycleState ==
        AppLifecycleState.resumed;
  } catch (_) {
    // Background isolate or binding not built: not foreground.
    return false;
  }
}


/// Top-level callback for notification actions invoked when the app is in
/// background or terminated.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  final actionId = response.actionId;
  final payload = response.payload;
  if (actionId == 'mark_read' && payload != null) {
    if (payload.startsWith('/novel/')) {
      final bookId = payload.replaceFirst('/novel/', '');
      final db = AppDatabase();
      try {
        await db.customStatement(
          'UPDATE notification_history SET is_read = 1 WHERE book_id = ?',
          [bookId],
        );
        await db.customStatement(
          'UPDATE books SET has_update = 0, new_chapter_count = 0 WHERE id = ?',
          [bookId],
        );
      } catch (e) {
        AppLogger.warning('Background notification action failed: $e');
      } finally {
        await db.close();
      }
    }
  }
}

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
  String? _pendingLaunchPayload;

  /// Consumes and clears any pending cold-start launch payload.
  String? consumePendingLaunchPayload() {
    final payload = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    return payload;
  }

  /// In-memory cache of the database instance, set lazily.
  AppDatabase? _db;

  /// Subject that emits the current list of all notification history entries.
  final _historyController = BehaviorSubject<List<NotificationEntry>>.seeded(
    [],
  );

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
  ///
  /// On web kIsWeb short-circuits before the `dart:io` Platform reads — its
  /// stub throws "Unsupported operation" there; notifications surface as
  /// in-app glass pills instead.
  static bool get isSupported =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isLinux ||
          Platform.isWindows);

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
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
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

  /// Ensures an Android notification channel exists for the given novel.
  Future<void> ensureNovelChannel({
    required String bookId,
    required String title,
    bool sound = true,
    bool vibration = true,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final channel = AndroidNotificationChannel(
        'novel_$bookId',
        '$title Updates',
        description: 'New chapter releases for $title',
        importance: Importance.high,
        playSound: sound,
        enableVibration: vibration,
      );
      await androidPlugin?.createNotificationChannel(channel);
    } catch (e) {
      AppLogger.warning('Failed to create novel channel $bookId: $e');
    }
  }

  /// Deletes a novel's Android notification channel when untracked or deleted.
  Future<void> deleteNovelChannel(String bookId) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.deleteNotificationChannel(
        channelId: 'novel_$bookId',
      );
    } catch (e) {
      AppLogger.warning('Failed to delete novel channel $bookId: $e');
    }
  }

  /// Shows notification(s) for all books that gained chapters.
  /// Respects quiet hours, sound/vibration preferences, per-novel channels,
  /// and grouping preferences.
  Future<void> showUpdateSummary(
    List<({String title, String bookId, int count})> updates, {
    UpdateCheckSettings? settings,
  }) async {
    if (!_initialized || updates.isEmpty) return;
    final config = settings ?? await UpdateCheckSettingsStore.load();
    final now = DateTime.now();

    // 1. Always record in local notification_history database first
    if (_db != null) {
      for (final update in updates) {
        await _db!.customStatement(
          'INSERT INTO notification_history (title, body, payload, book_id, is_read, created_at) VALUES (?, ?, ?, ?, 0, ?)',
          [
            '${update.title} has new chapters',
            '${update.count} new chapter${update.count == 1 ? '' : 's'} available',
            '/novel/${update.bookId}',
            update.bookId,
            now.toIso8601String(),
          ],
        );
      }
      await _refreshHistory();
    }

    // 2. Check if OS notifications are disabled or quiet hours are active
    if (!config.notificationsEnabled) return;
    if (UpdateCheckSettingsStore.isWithinQuietHours(now, config)) {
      AppLogger.info('Notification suppressed due to active quiet hours');
      return;
    }

    const groupKey = 'com.atlas.chapter_updates';
    final total = updates.fold<int>(0, (sum, u) => sum + u.count);

    try {
      final showIndividual =
          config.groupingMode == NotificationGroupingMode.individual ||
          config.groupingMode == NotificationGroupingMode.both ||
          updates.length == 1;

      final showSummary =
          config.groupingMode == NotificationGroupingMode.bundled ||
          (config.groupingMode == NotificationGroupingMode.both &&
              updates.length > 1);

      if (showIndividual) {
        for (final update in updates) {
          // App open: surface as a glass droplet pill instead of the OS
          // drawer; tapping deep-links exactly like the OS notification.
          if (_appIsForeground()) {
            AppToast.show(
              '${update.title} (${update.count})',
              tone: AppToastTone.read,
              action: AppToastAction(
                'Open',
                () => AppRouter.router.push('/novel/${update.bookId}'),
              ),
            );
            continue;
          }

          await ensureNovelChannel(
            bookId: update.bookId,
            title: update.title,
            sound: config.soundEnabled,
            vibration: config.vibrationEnabled,
          );

          final notificationId = (update.bookId.hashCode.abs() % 40000) + 1000;
          await _plugin.show(
            id: notificationId,
            title: update.title,
            body:
                '📖 ${update.count} new chapter${update.count == 1 ? '' : 's'} available',
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                'novel_${update.bookId}',
                '${update.title} Updates',
                channelDescription: 'New chapter releases for ${update.title}',
                groupKey: groupKey,
                importance: Importance.high,
                priority: Priority.high,
                playSound: config.soundEnabled,
                enableVibration: config.vibrationEnabled,
                actions: [
                  const AndroidNotificationAction(
                    'read_now',
                    'Read Now',
                    showsUserInterface: true,
                  ),
                  const AndroidNotificationAction(
                    'mark_read',
                    'Mark Read',
                    cancelNotification: true,
                  ),
                ],
              ),
              iOS: DarwinNotificationDetails(
                threadIdentifier: update.bookId,
                presentAlert: true,
                presentBadge: true,
                presentSound: config.soundEnabled,
              ),
            ),
            payload: '/novel/${update.bookId}',
          );
        }
      }

      if (showSummary && !kIsWeb && Platform.isAndroid) {
        final detail = updates.map((u) => '${u.title} (${u.count})').join(', ');
        if (_appIsForeground()) {
          AppToast.show(
            detail,
            tone: AppToastTone.sparkle,
            action: AppToastAction(
              'Open',
              () => AppRouter.router.push('/library'),
            ),
          );
          return; // summary is the last thing this method does
        }
        await _plugin.show(
          id: _summaryId,
          title: '✨ $total new chapter${total == 1 ? '' : 's'}',
          body: detail,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              groupKey: groupKey,
              setAsGroupSummary: true,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              playSound: config.soundEnabled,
              enableVibration: config.vibrationEnabled,
            ),
          ),
          payload: '/library',
        );
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
        title: '🎙️ Atlas test notification',
        body:
            '✅ Notifications are working. Shown ${delay.inSeconds}s after launch.',
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

  /// Marks all notifications for a specific novel as read and resets the book update badge.
  Future<void> markNovelAsRead(String bookId) async {
    if (_db == null) return;
    await _db!.customStatement(
      'UPDATE notification_history SET is_read = 1 WHERE book_id = ?',
      [bookId],
    );
    await _db!.customStatement(
      'UPDATE books SET has_update = 0, new_chapter_count = 0 WHERE id = ?',
      [bookId],
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

  /// Deletes multiple notification history entries by their ids.
  Future<void> deleteMultiple(Set<int> ids) async {
    if (_db == null || ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await _db!.customStatement(
      'DELETE FROM notification_history WHERE id IN ($placeholders)',
      ids.toList(),
    );
    await _refreshHistory();
  }

  /// Marks multiple notification history entries as read.
  Future<void> markMultipleAsRead(Set<int> ids) async {
    if (_db == null || ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await _db!.customStatement(
      'UPDATE notification_history SET is_read = 1 WHERE id IN ($placeholders)',
      ids.toList(),
    );
    await _refreshHistory();
  }

  /// Refreshes the in-memory history list and unread count from the database.
  Future<void> _refreshHistory() async {
    if (_db == null) return;
    final rows = await _db!
        .customSelect(
          'SELECT * FROM notification_history ORDER BY created_at DESC',
        )
        .get();
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
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        final payload = details.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          _pendingLaunchPayload = payload;
          AppLogger.info(
            'Captured cold-start notification launch payload: $payload',
          );
        }
      }
    } catch (e) {
      AppLogger.warning('Cold-start notification tap handling failed: $e');
    }
  }

  static void _handleTap(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    if (actionId == 'read_now') {
      if (payload.startsWith('/novel/')) {
        final bookId = payload.replaceFirst('/novel/', '');
        AppRouter.router.push('/reader/$bookId');
        return;
      }
    } else if (actionId == 'mark_read') {
      if (payload.startsWith('/novel/')) {
        final bookId = payload.replaceFirst('/novel/', '');
        unawaited(instance.markNovelAsRead(bookId));
        return;
      }
    }

    AppRouter.router.push(payload);
  }

  /// Disposes the subjects. Call only when the service is no longer needed.
  void dispose() {
    _historyController.close();
    _unreadCountController.close();
  }
}
