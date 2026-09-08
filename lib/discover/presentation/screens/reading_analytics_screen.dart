import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/domain/entities/reading_analytics_entity.dart';
import 'package:atlas_app/discover/presentation/providers/reading_analytics_providers.dart';
import 'package:atlas_app/discover/presentation/providers/discover_providers.dart';

class ReadingAnalyticsScreen extends ConsumerStatefulWidget {
  const ReadingAnalyticsScreen({super.key});

  @override
  ConsumerState<ReadingAnalyticsScreen> createState() =>
      _ReadingAnalyticsScreenState();
}

class _ReadingAnalyticsScreenState
    extends ConsumerState<ReadingAnalyticsScreen> {
  int _selectedViewTab = 0; // 0: Week, 1: Month

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(readingAnalyticsReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reading Analytics',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh analytics',
            onPressed: () {
              ref.invalidate(readingAnalyticsReportProvider);
              ref.invalidate(discoverDashboardProvider);
            },
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: AppLoading()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Could not load reading analytics.'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(readingAnalyticsReportProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (report) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.formContentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              children: [
                // 1. Streak & Reader Level Header Banner
                _StreakBanner(report: report),
                const SizedBox(height: AppSpacing.lg),

                // 2. KPI Summary Grid
                _KpiSummaryGrid(report: report),
                const SizedBox(height: AppSpacing.lg),

                // 3. Weekly Reading Goal Card
                _WeeklyGoalCard(
                  goal: report.weeklyGoal,
                  onEditGoal: () => _showEditGoalSheet(context, report.weeklyGoal),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 4. Interactive Activity Chart (Week vs Month)
                _ActivityChartSection(
                  weeklyActivity: report.weeklyActivity,
                  monthlyActivity: report.monthlyDailyActivity,
                  selectedTab: _selectedViewTab,
                  onTabChanged: (tab) => setState(() => _selectedViewTab = tab),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 5. Reading Time of Day Distribution
                _TimeOfDaySection(timeOfDay: report.timeOfDay),
                const SizedBox(height: AppSpacing.lg),

                // 6. Format Ratio (Web Novels vs Books)
                _FormatRatioSection(formatRatio: report.formatRatio),
                const SizedBox(height: AppSpacing.lg),

                // 7. Genre Affinity Breakdown
                if (report.genreStats.isNotEmpty) ...[
                  _GenreBreakdownSection(genreStats: report.genreStats),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // 8. Recent Sessions Log
                if (report.recentSessions.isNotEmpty) ...[
                  _RecentSessionsSection(sessions: report.recentSessions),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditGoalSheet(BuildContext context, ReadingGoalEntity currentGoal) {
    int selectedChapters = currentGoal.weeklyChapterTarget;
    int selectedMinutes = currentGoal.dailyMinuteTarget;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colors = theme.colorScheme;

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Set Reading Goals',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'Playfair Display',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customize your weekly target chapters and daily habit.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Weekly Chapters Selector
                  Text(
                    'Weekly Target: $selectedChapters chapters',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: selectedChapters.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    label: '$selectedChapters chapters',
                    onChanged: (val) {
                      setSheetState(() => selectedChapters = val.round());
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Daily Minutes Selector
                  Text(
                    'Daily Reading Habit: $selectedMinutes minutes',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: selectedMinutes.toDouble(),
                    min: 10,
                    max: 120,
                    divisions: 11,
                    label: '$selectedMinutes mins',
                    onChanged: (val) {
                      setSheetState(() => selectedMinutes = val.round());
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final service = ref.read(readingAnalyticsServiceProvider);
                        await service.updateGoal(
                          weeklyChapterTarget: selectedChapters,
                          dailyMinuteTarget: selectedMinutes,
                        );
                        ref.invalidate(readingAnalyticsReportProvider);
                        ref.invalidate(discoverDashboardProvider);
                      },
                      child: const Text('Save Goals'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.report});

  final ReadingAnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF3E0),
            Color(0xFFFFE0B2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE65100).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFCC80),
            ),
            child: const Center(
              child: Text(
                '🔥',
                style: TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.currentStreak} Day Reading Streak!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFBF360C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Best streak: ${report.longestStreak} days • Reading momentum is strong',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFD84315),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiSummaryGrid extends StatelessWidget {
  const _KpiSummaryGrid({required this.report});

  final ReadingAnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    String formatChapters(int ch) {
      if (ch >= 1000) {
        return '${(ch / 1000).toStringAsFixed(1)}K';
      }
      return ch.toString();
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _KpiCard(
          icon: '⏱️',
          value: '${report.totalHours}h',
          label: 'Total Time',
          color: colors.primaryContainer,
          textColor: colors.onPrimaryContainer,
        ),
        _KpiCard(
          icon: '📖',
          value: formatChapters(report.totalChaptersRead),
          label: 'Chapters Read',
          color: colors.secondaryContainer,
          textColor: colors.onSecondaryContainer,
        ),
        _KpiCard(
          icon: '📚',
          value: '${report.totalBooks}',
          label: 'Books in Shelf',
          color: colors.tertiaryContainer,
          textColor: colors.onTertiaryContainer,
        ),
        _KpiCard(
          icon: '⚡',
          value: '${report.averagePaceMinutesPerChapter}m',
          label: 'Avg Pace / Ch',
          color: colors.surfaceContainerHighest,
          textColor: colors.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String icon;
  final String value;
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard({required this.goal, required this.onEditGoal});

  final ReadingGoalEntity goal;
  final VoidCallback onEditGoal;

  @override
  Widget build(BuildContext context) {
    final pctInt = (goal.weeklyCompletionPercentage * 100).round();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Circular Progress
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: goal.weeklyCompletionPercentage,
                  strokeWidth: 5,
                  backgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)),
                ),
                Text(
                  '$pctInt%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly Reading Goal',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${goal.weeklyChaptersCompleted} of ${goal.weeklyChapterTarget} chapters completed',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF388E3C),
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: onEditGoal,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1B5E20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityChartSection extends StatelessWidget {
  const _ActivityChartSection({
    required this.weeklyActivity,
    required this.monthlyActivity,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final List<ReadingDayActivity> weeklyActivity;
  final List<ReadingDayActivity> monthlyActivity;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final activities = selectedTab == 0 ? weeklyActivity : monthlyActivity;

    final maxChapters = activities.fold<int>(
      1,
      (max, a) => a.chaptersRead > max ? a.chaptersRead : max,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reading Activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Week')),
                  ButtonSegment(value: 1, label: Text('Month')),
                ],
                selected: {selectedTab},
                onSelectionChanged: (set) => onTabChanged(set.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final act in activities) ...[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (act.chaptersRead > 0)
                          Text(
                            '${act.chaptersRead}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: act.isToday
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Container(
                          width: selectedTab == 0 ? 18 : 6,
                          height: (act.chaptersRead / maxChapters * 70).clamp(6.0, 70.0),
                          decoration: BoxDecoration(
                            color: act.isToday
                                ? colors.primary
                                : (act.chaptersRead > 0
                                    ? colors.primary.withValues(alpha: 0.6)
                                    : colors.outlineVariant.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          act.dayLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: act.isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: act.isToday
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeOfDaySection extends StatelessWidget {
  const _TimeOfDaySection({required this.timeOfDay});

  final ReadingTimeOfDayBreakdown timeOfDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = timeOfDay.totalMinutes > 0 ? timeOfDay.totalMinutes : 1;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reading Rhythm by Time of Day',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _TimeCard(
                label: 'Morning',
                icon: '🌅',
                minutes: timeOfDay.morningMinutes,
                pct: (timeOfDay.morningMinutes / total * 100).round(),
              ),
              const SizedBox(width: 8),
              _TimeCard(
                label: 'Afternoon',
                icon: '☀️',
                minutes: timeOfDay.afternoonMinutes,
                pct: (timeOfDay.afternoonMinutes / total * 100).round(),
              ),
              const SizedBox(width: 8),
              _TimeCard(
                label: 'Evening',
                icon: '🌆',
                minutes: timeOfDay.eveningMinutes,
                pct: (timeOfDay.eveningMinutes / total * 100).round(),
              ),
              const SizedBox(width: 8),
              _TimeCard(
                label: 'Night',
                icon: '🌙',
                minutes: timeOfDay.nightMinutes,
                pct: (timeOfDay.nightMinutes / total * 100).round(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.icon,
    required this.minutes,
    required this.pct,
  });

  final String label;
  final String icon;
  final int minutes;
  final int pct;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              '$pct%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatRatioSection extends StatelessWidget {
  const _FormatRatioSection({required this.formatRatio});

  final FormatReadRatio formatRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final novelPct = (formatRatio.novelPercentage * 100).round();
    final bookPct = (formatRatio.bookPercentage * 100).round();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reading Format Ratio',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.smMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: novelPct,
                    child: Container(color: colors.primary),
                  ),
                  Expanded(
                    flex: bookPct,
                    child: Container(color: colors.secondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Web Novels ($novelPct%)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Books / EPUB ($bookPct%)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenreBreakdownSection extends StatelessWidget {
  const _GenreBreakdownSection({required this.genreStats});

  final List<GenreReadStat> genreStats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Favorite Genres',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final g in genreStats) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        g.genre,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${g.bookCount} books (${(g.percentage * 100).round()}%)',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: g.percentage,
                      minHeight: 6,
                      backgroundColor: colors.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(colors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentSessionsSection extends StatelessWidget {
  const _RecentSessionsSection({required this.sessions});

  final List<ReadingSessionEntity> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Reading Sessions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.smMd),
        for (final s in sessions) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(Icons.auto_stories_rounded,
                      size: 18, color: colors.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.bookTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${(s.durationSeconds / 60).round()} mins • ${s.chaptersRead} chapter(s)',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(s.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (now.year == dt.year && now.month == dt.month && now.day == dt.day) {
      return 'Today';
    }
    return '${dt.month}/${dt.day}';
  }
}

