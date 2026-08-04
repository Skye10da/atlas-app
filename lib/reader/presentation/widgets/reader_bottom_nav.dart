import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_progress_bar.dart';

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
    this.bookTitle,
    this.coverPath,
    this.progress,
    this.progressColor,
    this.onListenTap,
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
  final String? bookTitle;
  final String? coverPath;

  /// Normalized reading progress (0..1). Passed as a listenable so the bar
  /// tracks scrolling without rebuilding the whole nav.
  final ValueListenable<double>? progress;
  final Color? progressColor;

  /// Overrides the Listen button action (e.g. desktop opens the narration
  /// panel instead of the bottom sheet). Falls back to [NowPlayingSheet.show].
  final VoidCallback? onListenTap;

  void _openNowPlaying(BuildContext context) {
    HapticFeedback.selectionClick();
    final custom = onListenTap;
    if (custom != null) {
      custom();
      return;
    }
    NowPlayingSheet.show(
      context,
      chapterTitle: currentChapterTitle,
      bookTitle: bookTitle,
      coverPath: coverPath,
    );
  }

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
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
                  _NavIconButton(
                    icon: Icons.headphones,
                    label: 'Listen',
                    textColor: textColor,
                    onTap: () => _openNowPlaying(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: 2,
                top: 4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ProgressTrack(
                      progress: progress,
                      color: progressColor ?? textColor,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _BatteryIndicator(
                    level: batteryLevel,
                    charging: charging,
                    textColor: textColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.progress, required this.color});

  final ValueListenable<double>? progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final listenable = progress;
    if (listenable == null) return const SizedBox.shrink();
    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      builder: (context, value, _) => ReaderProgressBar(
        progress: value,
        color: color,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
