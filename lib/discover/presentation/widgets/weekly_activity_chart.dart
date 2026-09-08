import 'package:flutter/material.dart';
import 'package:atlas_app/core/router/app_router.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';

class WeeklyActivityChart extends StatelessWidget {
  const WeeklyActivityChart({
    super.key,
    required this.weeklyActivity,
    required this.totalChapters,
    required this.todayMinutes,
  });

  final List<ReadingDayActivity> weeklyActivity;
  final int totalChapters;
  final int todayMinutes;

  @override
  Widget build(BuildContext context) {
    final maxChapters = weeklyActivity.fold<int>(
      1,
      (max, day) => day.chaptersRead > max ? day.chaptersRead : max,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => AppRouter.openAnalytics(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3EDF7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "This Week's Activity",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1B1F),
                  ),
                ),
                Text(
                  '$totalChapters chapters',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 84,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: weeklyActivity.map((day) {
                  final ratio = maxChapters > 0
                      ? (day.chaptersRead / maxChapters).clamp(0.08, 1.0)
                      : 0.08;
                  final barHeight = (68.0 * ratio).clamp(8.0, 68.0);
                  final hasActivity = day.chaptersRead > 0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: double.infinity,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  gradient: (day.isToday || hasActivity)
                                      ? const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                                        )
                                      : null,
                                  color: (!day.isToday && !hasActivity)
                                      ? const Color(0xFFD1C4E9)
                                      : null,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: day.isToday
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            day.dayLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: day.isToday ? FontWeight.w700 : FontWeight.w500,
                              color: day.isToday ? const Color(0xFF7C3AED) : const Color(0xFF79747E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
