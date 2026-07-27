import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';

class ReaderBottomNav extends ConsumerWidget {
  const ReaderBottomNav({
    super.key,
    required this.onSettingsTap,
    required this.onChapterIndexTap,
    required this.onBookmarkTap,
    this.isBookmarked = false,
    this.currentChapterTitle,
    this.currentChapterNumber,
    this.totalChapters,
  });

  final VoidCallback onSettingsTap;
  final VoidCallback onChapterIndexTap;
  final VoidCallback onBookmarkTap;
  final bool isBookmarked;
  final String? currentChapterTitle;
  final int? currentChapterNumber;
  final int? totalChapters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final batteryAsync = ref.watch(liveBatteryLevelProvider);
    final batteryLevel = batteryAsync.valueOrNull;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      color: colorScheme.surface,
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
                onTap: onSettingsTap,
              ),
              _NavIconButton(
                icon: Icons.list,
                label: currentChapterNumber != null
                    ? '${currentChapterNumber! + 1}/${totalChapters ?? 0}'
                    : 'Chapters',
                onTap: onChapterIndexTap,
              ),
              _NavIconButton(
                icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                label: isBookmarked ? 'Bookmarked' : 'Bookmark',
                onTap: () {
                  HapticFeedback.selectionClick();
                  onBookmarkTap();
                },
              ),
              _BatteryIndicator(level: batteryLevel),
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: colorScheme.onSurface),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  const _BatteryIndicator({required this.level});

  final double? level;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pct = level != null ? (level! * 100).round() : null;

    final icon = switch (pct) {
      null => Icons.battery_unknown,
      >= 80 => Icons.battery_full,
      >= 50 => Icons.battery_5_bar,
      >= 20 => Icons.battery_3_bar,
      _ => Icons.battery_alert,
    };

    final label = pct != null ? '$pct%' : 'Battery';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurface),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface.withValues(alpha: 0.8),
              )),
        ],
      ),
    );
  }
}
