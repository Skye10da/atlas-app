import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/notifications/infrastructure/notification_service.dart';

/// Provider that exposes the list of all notification history entries
/// (newest first).
final notificationHistoryProvider =
    StreamProvider<List<NotificationEntry>>((ref) {
  return UpdateNotificationService.instance.historyStream;
});

/// Provider that exposes the unread notification count.
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  return UpdateNotificationService.instance.unreadCountStream;
});
