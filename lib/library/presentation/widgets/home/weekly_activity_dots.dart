import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';

/// Compact weekly-activity summary: one dot per day, sized by reading minutes,
/// with today highlighted. Tapping opens the analytics dashboard.
class WeeklyActivityDots extends StatelessWidget {
  const WeeklyActivityDots({
    super.key,
    required this.weeklyActivity,
    required this.totalChapters,
    this.onTap,
  });

  final List<ReadingDayActivity> weeklyActivity;
  final int totalChapters;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (weeklyActivity.isEmpty) return const SizedBox.shrink();

    final maxMinutes = weeklyActivity.fold<int>(
      1,
      (max, day) => day.readingMinutes > max ? day.readingMinutes : max,
    );

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 15,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'This week',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$totalChapters ${totalChapters == 1 ? 'chapter' : 'chapters'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final count = weeklyActivity.length;
                  // Reserve a little breathing room between cells so the
                  // largest dot never overflows its own column.
                  final maxDot = ((constraints.maxWidth / count) - 6)
                      .clamp(10.0, 28.0);
                  return Row(
                    children: [
                      for (final day in weeklyActivity)
                        Expanded(
                          child: _DayDot(
                            label: day.dayLabel,
                            intensity: day.readingMinutes / maxMinutes,
                            isToday: day.isToday,
                            maxDot: maxDot,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.intensity,
    required this.isToday,
    required this.maxDot,
  });

  final String label;
  final double intensity;
  final bool isToday;
  final double maxDot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clamped = intensity.clamp(0.0, 1.0);
    // Inactive days shrink but stay visible; active days scale to maxDot.
    final size = maxDot * (0.5 + 0.5 * clamped);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 30,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: clamped <= 0
                    ? cs.surfaceContainerHighest
                    : cs.primary.withValues(alpha: 0.25 + 0.75 * clamped),
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: cs.primary, width: 2)
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
