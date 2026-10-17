import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';

int _todayChapters(List<ReadingDayActivity> week) {
  var total = 0;
  for (final day in week) {
    if (day.isToday) total += day.chaptersRead;
  }
  return total;
}

int _maxMinutes(List<ReadingDayActivity> week) => week.fold<int>(
  1,
  (max, day) => day.readingMinutes > max ? day.readingMinutes : max,
);

/// Stats card: one dot per day (sized by reading minutes, today highlighted)
/// with today's and this week's chapter counts. Tapping opens analytics.
/// Used beside the hero on medium widths and in the insights panel on wide.
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

    final maxMinutes = _maxMinutes(weeklyActivity);
    final today = _todayChapters(weeklyActivity);

    return Semantics(
      button: true,
      label: 'Open reading stats',
      child: Material(
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
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
                    Expanded(
                      child: Text(
                        'This week',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.smMd),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final count = weeklyActivity.length;
                    final maxDot = ((constraints.maxWidth / count) - 6).clamp(
                      10.0,
                      28.0,
                    );
                    return Row(
                      children: [
                        for (final day in weeklyActivity)
                          Expanded(
                            child: _DayDot(
                              label: day.dayLabel,
                              intensity: day.readingMinutes / maxMinutes,
                              isToday: day.isToday,
                              maxDot: maxDot,
                              slotHeight: 30,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.smMd),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _StatNumber(
                          value: '$today',
                          label: today == 1
                              ? 'chapter today'
                              : 'chapters today',
                          accent: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: _StatNumber(
                          value: '$totalChapters',
                          label: 'this week',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single-line weekly summary for compact (phone) layouts: the seven dots on
/// the left, today's chapter count on the right. Tapping opens analytics.
class WeeklyActivityStrip extends StatelessWidget {
  const WeeklyActivityStrip({
    super.key,
    required this.weeklyActivity,
    this.onTap,
  });

  final List<ReadingDayActivity> weeklyActivity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (weeklyActivity.isEmpty) return const SizedBox.shrink();

    final maxMinutes = _maxMinutes(weeklyActivity);
    final today = _todayChapters(weeklyActivity);

    return Semantics(
      button: true,
      label: 'Open reading stats. $today chapters read today.',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in weeklyActivity)
                      Expanded(
                        child: _DayDot(
                          label: day.dayLabel,
                          intensity: day.readingMinutes / maxMinutes,
                          isToday: day.isToday,
                          maxDot: 18,
                          slotHeight: 24,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: _StatNumber(
                    value: '$today',
                    label: today == 1 ? 'chapter today' : 'chapters today',
                    accent: true,
                    alignEnd: true,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatNumber extends StatelessWidget {
  const _StatNumber({
    required this.value,
    required this.label,
    this.accent = false,
    this.alignEnd = false,
  });

  final String value;
  final String label;
  final bool accent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFamily: 'Fraunces',
            fontWeight: FontWeight.w600,
            height: 1,
            color: accent ? cs.primary : cs.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        _StatLabel(label: label, cs: cs),
      ],
    );
  }
}

class _StatLabel extends StatelessWidget {
  const _StatLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.intensity,
    required this.isToday,
    required this.maxDot,
    required this.slotHeight,
  });

  final String label;
  final double intensity;
  final bool isToday;
  final double maxDot;
  final double slotHeight;

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
          height: slotHeight,
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
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
