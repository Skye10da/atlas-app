import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/router/app_router.dart';
import 'package:atlas_app/notifications/presentation/providers/notification_provider.dart';

class DiscoverHeader extends ConsumerWidget {
  const DiscoverHeader({
    super.key,
    required this.streakDays,
  });

  final int streakDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    final now = DateTime.now();
    final dayName = _weekdayName(now.weekday);
    final timeOfDay = now.hour < 12
        ? 'morning'
        : now.hour < 17
            ? 'afternoon'
            : 'evening';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$dayName $timeOfDay',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Welcome back, Reader',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Streak Pill - Tapping opens full Analytics dashboard
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => AppRouter.openAnalytics(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE65100).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🔥',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 5),
                Text(
                  '$streakDays',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFFE65100),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Notification Bell with Badge Dot
        _NotificationBellBadge(unreadCount: unreadCount),
      ],
    );
  }

  static String _weekdayName(int day) {
    return switch (day) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => 'Today',
    };
  }
}

class _NotificationBellBadge extends StatelessWidget {
  const _NotificationBellBadge({required this.unreadCount});

  final AsyncValue<int> unreadCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = unreadCount.valueOrNull ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/notifications'),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            if (count > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
