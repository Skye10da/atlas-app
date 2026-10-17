import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:atlas_app/core/design_system/molecules/milestone_celebration_dialog.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

class StatsSummaryFooter extends StatelessWidget {
  const StatsSummaryFooter({
    super.key,
    required this.totalBooks,
    required this.totalChaptersRead,
    required this.totalReadingHours,
    required this.totalBookmarks,
  });

  final int totalBooks;
  final int totalChaptersRead;
  final int totalReadingHours;
  final int totalBookmarks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reading Footprint',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Live Stats',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                count: '$totalBooks',
                label: 'Books',
                icon: Icons.book_rounded,
                onTap: () => MilestoneCelebrationDialog.show(
                  context,
                  milestone: totalBooks >= 10
                      ? MilestoneType.tenBooksFinished
                      : (totalBooks >= 5
                          ? MilestoneType.fiveBooksFinished
                          : MilestoneType.firstBookFinished),
                ),
              ),
              _StatItem(
                count: '$totalChaptersRead',
                label: 'Chapters',
                icon: Icons.auto_stories_rounded,
                onTap: () => MilestoneCelebrationDialog.show(
                  context,
                  milestone: totalChaptersRead >= 1000
                      ? MilestoneType.thousandChapters
                      : MilestoneType.hundredChapters,
                ),
              ),
              _StatItem(
                count: '${totalReadingHours > 0 ? totalReadingHours : (totalChaptersRead * 3 / 60).round()}h',
                label: 'Hours Read',
                icon: Icons.timelapse_rounded,
                onTap: () => MilestoneCelebrationDialog.show(
                  context,
                  milestone: MilestoneType.streakThirtyDays,
                  customMessage: 'Immersion into extraordinary worlds.',
                ),
              ),
              _StatItem(
                count: '$totalBookmarks',
                label: 'Saved Quotes',
                icon: Icons.format_quote_rounded,
                onTap: () => context.go('/bookmarks'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.count,
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String count;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              count,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
