import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';

class ReaderBottomNav extends ConsumerWidget {
  const ReaderBottomNav({
    super.key,
    required this.textColor,
    required this.onSettingsTap,
    required this.onChapterIndexTap,
    required this.onBookmarkTap,
    this.isBookmarked = false,
    this.currentChapterTitle,
    this.currentChapterNumber,
    this.totalChapters,
    this.autoScrollActive = false,
    this.onAutoScrollToggle,
  });

  final Color textColor;
  final VoidCallback onSettingsTap;
  final VoidCallback onChapterIndexTap;
  final VoidCallback onBookmarkTap;
  final bool isBookmarked;
  final String? currentChapterTitle;
  final int? currentChapterNumber;
  final int? totalChapters;
  final bool autoScrollActive;
  final VoidCallback? onAutoScrollToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final batteryAsync = ref.watch(liveBatteryLevelProvider);
    final batteryLevel = batteryAsync.valueOrNull;
    final chargingAsync = ref.watch(liveChargingProvider);
    final charging = chargingAsync.valueOrNull ?? false;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavIconButton(
                icon: Icons.settings,
                label: 'Settings',
                textColor: textColor,
                onTap: onSettingsTap,
              ),
              _NavIconButton(
                icon: Icons.list,
                label: currentChapterNumber != null
                    ? '${currentChapterNumber! + 1}/${totalChapters ?? 0}'
                    : 'Chapters',
                textColor: textColor,
                onTap: onChapterIndexTap,
              ),
              _NavIconButton(
                icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                label: isBookmarked ? 'Bookmarked' : 'Bookmark',
                textColor: textColor,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onBookmarkTap();
                },
              ),
              if (onAutoScrollToggle != null)
                _NavIconButton(
                  icon: autoScrollActive
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_outline,
                  label: autoScrollActive ? 'Pause' : 'Auto-scroll',
                  textColor: textColor,
                  onTap: onAutoScrollToggle!,
                ),
              _BatteryIndicator(level: batteryLevel, charging: charging, textColor: textColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: textColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  const _BatteryIndicator({
    required this.level,
    required this.textColor,
    this.charging = false,
  });

  final double? level;
  final Color textColor;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    final pct = level != null ? (level! * 100).round() : null;

    final IconData icon;
    if (charging) {
      icon = Icons.battery_charging_full;
    } else {
      icon = switch (pct) {
        null => Icons.battery_unknown,
        >= 80 => Icons.battery_full,
        >= 50 => Icons.battery_5_bar,
        >= 20 => Icons.battery_3_bar,
        _ => Icons.battery_alert,
      };
    }

    final label = pct != null ? '$pct%' : 'Battery';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: textColor),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
