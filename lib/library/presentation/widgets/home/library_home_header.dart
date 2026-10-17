import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';
import 'package:atlas_app/core/account/presentation/providers/local_account_providers.dart';
import 'package:atlas_app/core/account/presentation/widgets/profile_edit_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/notifications/presentation/providers/notification_provider.dart';

/// Greeting header for the Library home.
///
/// Avatar on the left, a time-of-day greeting personalised with the local
/// account in the middle, notification bell on the right. The reading streak
/// lives in the small line above the greeting. The bell shows an unread dot
/// only (no count) so it never competes with the Updated tab count or the
/// per-cover "+N" chapter badges.
///
/// On desktop widths the shell sidebar already shows the account tile, so the
/// avatar is dropped here.
class LibraryHomeHeader extends ConsumerWidget {
  const LibraryHomeHeader({
    super.key,
    required this.streakDays,
    this.onOpenAnalytics,
  });

  final int streakDays;

  /// Tapping the streak line opens analytics. Not tappable when null.
  final VoidCallback? onOpenAnalytics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final account = ref.watch(localAccountSummaryProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final showAvatar =
        MediaQuery.sizeOf(context).width < AppBreakpoints.desktop;

    final now = DateTime.now();
    final timeOfDay = now.hour < 12
        ? 'morning'
        : now.hour < 17
        ? 'afternoon'
        : 'evening';

    final eyebrow = streakDays > 0
        ? '${_weekdayName(now.weekday)} · Day $streakDays of your streak'
        : '${_weekdayName(now.weekday)} $timeOfDay';

    final eyebrowText = Text(
      eyebrow,
      style: theme.textTheme.bodySmall?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showAvatar) ...[
          _ProfileAvatar(account: account),
          const SizedBox(width: AppSpacing.smMd),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (streakDays > 0 && onOpenAnalytics != null)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onOpenAnalytics,
                  child: eyebrowText,
                )
              else
                eyebrowText,
              const SizedBox(height: 2),
              Text(
                'Good $timeOfDay, ${account.greetingName}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _BellButton(
          hasUnread: (unreadCount.valueOrNull ?? 0) > 0,
          onTap: () => context.push('/notifications'),
        ),
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

class _BellButton extends StatelessWidget {
  const _BellButton({required this.hasUnread, required this.onTap});

  final bool hasUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: hasUnread ? 'Notifications, unread' : 'Notifications',
      child: Tooltip(
        message: 'Notifications',
        child: Material(
          color: cs.surfaceContainerLow,
          shape: CircleBorder(side: BorderSide(color: cs.outlineVariant)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 22,
                    color: cs.onSurface,
                  ),
                  if (hasUnread)
                    Positioned(
                      top: 10,
                      right: 11,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: cs.tertiary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.surfaceContainerLow,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.account});

  final LocalAccountEntity account;

  @override
  Widget build(BuildContext context) {
    final color = Color(
      kAvatarColors[account.avatarColorIndex % kAvatarColors.length],
    );
    return Semantics(
      button: true,
      label: 'Your profile',
      child: Tooltip(
        message: 'Your profile',
        child: Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => showProfileEditSheet(context),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Text(
                  account.avatarInitial,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
