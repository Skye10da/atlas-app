import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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
    this.onAnnotationsTap,
  });

  final Color textColor;
  final VoidCallback onSettingsTap;
  final VoidCallback onChapterIndexTap;
  final VoidCallback onBookmarkTap;
  final VoidCallback? onAnnotationsTap;
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;
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
                    icon: Icons.tune_rounded,
                    label: 'Tune',
                    textColor: textColor,
                    onTap: onSettingsTap,
                  ),
                  _NavIconButton(
                    icon: Icons.format_list_numbered_rounded,
                    label: currentChapterNumber != null
                        ? 'Ch. ${currentChapterNumber! + 1}'
                        : 'Chapters',
                    textColor: textColor,
                    onTap: onChapterIndexTap,
                  ),
                  _NavIconButton(
                    icon: isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    label: isBookmarked ? 'Saved' : 'Save',
                    textColor: textColor,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onBookmarkTap();
                    },
                  ),
                  if (onAutoScrollToggle != null)
                    _NavIconButton(
                      icon: autoScrollActive
                          ? Icons.bolt_rounded
                          : Icons.bolt_outlined,
                      label: autoScrollActive ? 'Flowing' : 'Flow',
                      textColor: textColor,
                      onTap: onAutoScrollToggle!,
                    ),
                  if (onAnnotationsTap != null)
                    _NavIconButton(
                      icon: Icons.bookmarks_outlined,
                      label: 'Notes',
                      textColor: textColor,
                      onTap: onAnnotationsTap!,
                    ),
                  _NavIconButton(
                    icon: Icons.headphones_rounded,
                    label: 'Listen',
                    textColor: textColor,
                    onTap: () => _openNowPlaying(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: 4,
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
                  const SizedBox(width: AppSpacing.smMd),
                  _ClockIndicator(textColor: textColor),
                  const SizedBox(width: AppSpacing.xs),
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

class _ClockIndicator extends HookWidget {
  const _ClockIndicator({required this.textColor});

  final Color textColor;

  static String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour == 0
        ? 12
        : (now.hour > 12 ? now.hour - 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final timeString = useState(_formatCurrentTime());

    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 30), (_) {
        timeString.value = _formatCurrentTime();
      });
      return timer.cancel;
    }, const []);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      ),
      child: Text(
        timeString.value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor.withValues(alpha: 0.9),
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
      builder: (context, value, _) =>
          ReaderProgressBar(progress: value, color: color),
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: AppSpacing.touchTarget,
          minHeight: AppSpacing.touchTarget,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: textColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textColor.withValues(alpha: 0.85),
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
      icon = Icons.battery_charging_full_rounded;
    } else {
      icon = switch (pct) {
        null => Icons.battery_unknown_rounded,
        >= 80 => Icons.battery_full_rounded,
        >= 50 => Icons.battery_5_bar_rounded,
        >= 20 => Icons.battery_3_bar_rounded,
        _ => Icons.battery_alert_rounded,
      };
    }

    final label = pct != null ? '$pct%' : '100%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor.withValues(alpha: 0.9)),
          const SizedBox(width: 3),
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
