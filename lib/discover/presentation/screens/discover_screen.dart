import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/router/app_router.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/domain/entities/reading_analytics_entity.dart';
import 'package:atlas_app/discover/presentation/providers/discover_providers.dart';
import 'package:atlas_app/discover/presentation/providers/reading_analytics_providers.dart';
import 'package:atlas_app/discover/presentation/widgets/curated_sources_section.dart';
import 'package:atlas_app/discover/presentation/widgets/discover_header.dart';
import 'package:atlas_app/discover/presentation/widgets/for_you_section.dart';
import 'package:atlas_app/discover/presentation/widgets/genre_carousel_section.dart';
import 'package:atlas_app/discover/presentation/widgets/now_reading_hero_card.dart';
import 'package:atlas_app/discover/presentation/widgets/quick_stats_row.dart';
import 'package:atlas_app/discover/presentation/widgets/stats_summary_footer.dart';
import 'package:atlas_app/discover/presentation/widgets/trending_section.dart';
import 'package:atlas_app/discover/presentation/widgets/weekly_activity_chart.dart';
import 'package:atlas_app/discover/presentation/widgets/weekly_goal_discover_card.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// The Discover Screen upgraded into the Central Ecosystem Command Hub.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(discoverDashboardProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: dashboardAsync.when(
          loading: () => const _DiscoverSkeleton(),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Could not load dashboard data.'),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(discoverDashboardProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (result) {
            return switch (result) {
              Failure(error: final err) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(err.userMessage),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () =>
                          ref.invalidate(discoverDashboardProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              Success(value: final DiscoverDashboardData data) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(discoverDashboardProvider);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      sliver: SliverList.list(
                        children: [
                          // 1. Header Greeting, Streak Pill & Notification Badge
                          DiscoverHeader(streakDays: data.streakDays),
                          const SizedBox(height: AppSpacing.lg),

                          // 2. NOW READING Contextual Hero Card
                          NowReadingHeroCard(
                            book: data.nowReading,
                            latestQuote: data.nowReadingLatestQuote,
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // 3-5. Reading Insights — fetch directly from analytics
                          _DiscoverReadingInsights(
                            fallbackWeeklyGoal: data.weeklyGoal,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),

                    // 6. OPDS Trending Now
                    if (data.opdsTrendingBooks.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: TrendingSection(
                            title: '🔥 OPDS Trending Now',
                            trendingBooks: data.opdsTrendingBooks,
                            isLoading: false,
                            onRefresh: () =>
                                ref.invalidate(discoverDashboardProvider),
                            onViewAll: () =>
                                AppRouter.openTrending(context, type: 'opds'),
                          ),
                        ),
                      )
                    else
                      const SliverToBoxAdapter(child: _TrendingSkeleton()),
                    if (data.opdsTrendingBooks.isNotEmpty)
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xl),
                      ),

                    // 7. Web Novel Trending Now
                    if (data.webNovelTrendingBooks.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: TrendingSection(
                            title: '🔥 Web Novel Trending Now',
                            trendingBooks: data.webNovelTrendingBooks,
                            isLoading: false,
                            onRefresh: () =>
                                ref.invalidate(discoverDashboardProvider),
                            onViewAll: () => AppRouter.openTrending(
                              context,
                              type: 'webnovel',
                            ),
                          ),
                        ),
                      )
                    else if (data.webNovelTrendingBooks.isEmpty &&
                        data.opdsTrendingBooks.isNotEmpty)
                      const SliverToBoxAdapter(child: _TrendingSkeleton()),
                    if (data.webNovelTrendingBooks.isNotEmpty)
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xl),
                      ),

                    // 8. Personalized "For You" Recommendations
                    if (data.forYouRecommendations.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: ForYouSection(
                            recommendations: data.forYouRecommendations,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xl),
                      ),
                    ],

                    // 9. Explore Genres
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: GenreCarouselSection(
                          genreBookCounts: data.genreBookCounts,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xl),
                    ),

                    // 10. Curated Sources
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: CuratedSourcesSection(
                          sources: data.sources,
                          totalSupportedSourcesCount:
                              data.totalSupportedSourcesCount,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xl),
                    ),

                    // 11. Recently Added
                    if (data.books.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _RecentlyAddedCarousel(books: data.books),
                        ),
                      ),
                    if (data.books.isNotEmpty)
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xl),
                      ),

                    // 12. Footer
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: StatsSummaryFooter(
                          totalBooks: data.totalBooksCount,
                          totalChaptersRead: data.totalChaptersReadCount,
                          totalReadingHours: data.totalReadingHours,
                          totalBookmarks: data.totalBookmarksCount,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xxl),
                    ),
                  ],
                ),
              ),
            };
          },
        ),
      ),
    );
  }
}

class _RecentlyAddedCarousel extends StatelessWidget {
  const _RecentlyAddedCarousel({required this.books});

  final List<BookEntity> books;

  @override
  Widget build(BuildContext context) {
    final recent = books.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recently Added',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/library?sort=recentlyAdded'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.smMd),
            itemBuilder: (context, index) {
              final b = recent[index];
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  if (b.isNovel) {
                    context.push('/novel/${b.id}');
                  } else {
                    context.push('/book/${b.id}');
                  }
                },
                child: SizedBox(
                  width: 96,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: BookCover(
                          coverPath: b.coverPath,
                          width: 96,
                          height: 140,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Reading Insights — now fetches directly from analytics (single source of
/// truth). Previously this data came via `DiscoverDashboardData` which
/// recomputed it from `reading_progress` only, duplicating
/// `ReadingAnalyticsService` logic that correctly uses `reading_sessions`.
class _DiscoverReadingInsights extends ConsumerWidget {
  const _DiscoverReadingInsights({this.fallbackWeeklyGoal});

  final ReadingGoalEntity? fallbackWeeklyGoal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(readingAnalyticsReportProvider);
    return analyticsAsync.when(
      loading: () => Skeletonizer(
        enabled: true,
        child: Column(
          children: [
            Row(
              children: List.generate(
                3,
                (_) => Expanded(
                  child: Container(
                    height: 72,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
      error: (err, _) => Column(
        children: [
          const QuickStatsRow(totalBooks: 0, totalChapters: 0, totalHours: 0),
          const SizedBox(height: AppSpacing.lg),
          WeeklyGoalDiscoverCard(goal: fallbackWeeklyGoal),
          const SizedBox(height: AppSpacing.xl),
          const WeeklyActivityChart(
            weeklyActivity: [],
            totalChapters: 0,
            todayMinutes: 0,
          ),
        ],
      ),
      data: (report) {
        final weeklyTotal = report.weeklyActivity.fold<int>(
          0,
          (sum, d) => sum + d.chaptersRead,
        );
        final todayMinutes = report.weeklyActivity
            .firstWhere(
              (d) => d.isToday,
              orElse: () => report.weeklyActivity.last,
            )
            .readingMinutes;
        return Column(
          children: [
            QuickStatsRow(
              totalBooks: report.totalBooks,
              totalChapters: report.totalChaptersRead,
              totalHours: report.totalHours,
            ),
            const SizedBox(height: AppSpacing.lg),
            WeeklyGoalDiscoverCard(goal: report.weeklyGoal),
            const SizedBox(height: AppSpacing.xl),
            WeeklyActivityChart(
              weeklyActivity: report.weeklyActivity,
              totalChapters: weeklyTotal,
              todayMinutes: todayMinutes,
            ),
          ],
        );
      },
    );
  }
}

class _TrendingSkeleton extends StatelessWidget {
  const _TrendingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 18,
            width: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 265,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 190,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(width: 100, height: 12, color: Colors.white),
                  const SizedBox(height: 4),
                  Container(width: 80, height: 10, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForYouSkeleton extends StatelessWidget {
  const _ForYouSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 18,
            width: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 275,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(width: 110, height: 12, color: Colors.white),
                  const SizedBox(height: 4),
                  Container(width: 80, height: 10, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverSkeleton extends StatelessWidget {
  const _DiscoverSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          sliver: SliverList.list(
            children: [
              Skeletonizer(
                enabled: true,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 120,
                              height: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 80,
                              height: 12,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _TrendingSkeleton(),
              const SizedBox(height: AppSpacing.xl),
              const _ForYouSkeleton(),
            ],
          ),
        ),
      ],
    );
  }
}
