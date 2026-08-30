import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_viewer_models.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_progress_bar.dart';

/// Bottom navigation bar for the PDF reader matching the design tokens,
/// typography, layout, and styling of [ReaderBottomNav].
class PdfBottomNav extends ConsumerWidget {
  const PdfBottomNav({
    super.key,
    required this.textColor,
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
    required this.onSettingsTap,
    required this.onOutlineTap,
    required this.onBookmarkTap,
    this.isBookmarked = false,
    required this.layoutMode,
    required this.onToggleLayoutMode,
    required this.onListenTap,
    this.onAnnotationsTap,
    this.progressColor,
  });

  final Color textColor;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onSettingsTap;
  final VoidCallback onOutlineTap;
  final VoidCallback onBookmarkTap;
  final VoidCallback? onAnnotationsTap;
  final bool isBookmarked;
  final PdfReaderLayoutMode layoutMode;
  final VoidCallback onToggleLayoutMode;
  final VoidCallback onListenTap;
  final Color? progressColor;

  IconData get _layoutModeIcon => switch (layoutMode) {
    PdfReaderLayoutMode.single => Icons.crop_portrait_rounded,
    PdfReaderLayoutMode.facing => Icons.menu_book_rounded,
    PdfReaderLayoutMode.continuous => Icons.view_day_rounded,
  };

  String get _layoutModeLabel => switch (layoutMode) {
    PdfReaderLayoutMode.single => 'Single',
    PdfReaderLayoutMode.facing => 'Facing',
    PdfReaderLayoutMode.continuous => 'Scroll',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final batteryAsync = ref.watch(liveBatteryLevelProvider);
    final batteryLevel = batteryAsync.valueOrNull;
    final chargingAsync = ref.watch(liveChargingProvider);
    final charging = chargingAsync.valueOrNull ?? false;

    final progressFraction = totalPages > 0
        ? (currentPage / totalPages).clamp(0.0, 1.0)
        : 0.0;

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
                    label: totalPages > 0 ? '$currentPage / $totalPages' : 'Pages',
                    textColor: textColor,
                    onTap: onOutlineTap,
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
                  if (onAnnotationsTap != null)
                    _NavIconButton(
                      icon: Icons.note_alt_outlined,
                      label: 'Notes',
                      textColor: textColor,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onAnnotationsTap!();
                      },
                    ),
                  _NavIconButton(
                    icon: _layoutModeIcon,
                    label: _layoutModeLabel,
                    textColor: textColor,
                    onTap: onToggleLayoutMode,
                  ),
                  _NavIconButton(
                    icon: Icons.headphones_rounded,
                    label: 'Listen',
                    textColor: textColor,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onListenTap();
                    },
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
                    child: _PageSliderTrack(
                      currentPage: currentPage,
                      totalPages: totalPages,
                      progressFraction: progressFraction,
                      color: progressColor ?? textColor,
                      onPageSelected: onPageSelected,
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

class _PageSliderTrack extends StatelessWidget {
  const _PageSliderTrack({
    required this.currentPage,
    required this.totalPages,
    required this.progressFraction,
    required this.color,
    required this.onPageSelected,
  });

  final int currentPage;
  final int totalPages;
  final double progressFraction;
  final Color color;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return ReaderProgressBar(progress: progressFraction, color: color);
    }

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        activeTrackColor: color,
        inactiveTrackColor: color.withValues(alpha: 0.15),
        thumbColor: color,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        overlayColor: color.withValues(alpha: 0.12),
      ),
      child: Slider(
        value: currentPage.clamp(1, totalPages).toDouble(),
        min: 1,
        max: totalPages.toDouble(),
        onChanged: (val) => onPageSelected(val.round()),
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

class _ClockIndicator extends StatefulWidget {
  const _ClockIndicator({required this.textColor});

  final Color textColor;

  @override
  State<_ClockIndicator> createState() => _ClockIndicatorState();
}

class _ClockIndicatorState extends State<_ClockIndicator> {
  late Timer _timer;
  late String _timeString;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour == 0
        ? 12
        : (now.hour > 12 ? now.hour - 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final formatted = '$hour:$minute $period';
    if (mounted) {
      setState(() => _timeString = formatted);
    } else {
      _timeString = formatted;
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: widget.textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      ),
      child: Text(
        _timeString,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: widget.textColor.withValues(alpha: 0.9),
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

