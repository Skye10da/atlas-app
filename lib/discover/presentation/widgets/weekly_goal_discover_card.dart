import 'package:flutter/material.dart';
import 'package:atlas_app/core/router/app_router.dart';
import 'package:atlas_app/discover/domain/entities/reading_analytics_entity.dart';

class WeeklyGoalDiscoverCard extends StatelessWidget {
  const WeeklyGoalDiscoverCard({
    super.key,
    this.goal,
  });

  final ReadingGoalEntity? goal;

  @override
  Widget build(BuildContext context) {
    final activeGoal = goal ?? ReadingGoalEntity.initial();
    final pctInt = (activeGoal.weeklyCompletionPercentage * 100).round();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => AppRouter.openAnalytics(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Progress Ring
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: activeGoal.weeklyCompletionPercentage,
                    strokeWidth: 4,
                    backgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)),
                  ),
                  Text(
                    '$pctInt%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Middle Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Reading Goal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${activeGoal.weeklyChaptersCompleted} of ${activeGoal.weeklyChapterTarget} chapters completed',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF388E3C),
                    ),
                  ),
                ],
              ),
            ),

            // Streak Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '🔥 ${activeGoal.currentStreak} days',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

