import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/presentation/providers/discover_providers.dart';
import 'package:atlas_app/discover/presentation/widgets/curated_sources_section.dart';
import 'package:atlas_app/discover/presentation/widgets/discover_header.dart';
import 'package:atlas_app/discover/presentation/widgets/ecosystem_quick_grid.dart';
import 'package:atlas_app/discover/presentation/widgets/genre_carousel_section.dart';
import 'package:atlas_app/discover/presentation/widgets/now_reading_hero_card.dart';
import 'package:atlas_app/discover/presentation/widgets/stats_summary_footer.dart';
import 'package:atlas_app/discover/presentation/widgets/trending_section.dart';
import 'package:atlas_app/discover/presentation/widgets/weekly_activity_chart.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

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
          loading: () => const AppLoading(),
          error: (err, _) => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Could not load dashboard data.'),
                SizedBox(height: 12),
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
              Success(value: final DiscoverDashboardData data) =>
                RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(discoverDashboardProvider);
                  },
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    children: [
                      // 1. Header Greeting, Streak Pill & Notification Badge
                      DiscoverHeader(streakDays: data.streakDays),
                      const SizedBox(height: AppSpacing.lg),

                      // 2. NOW READING Contextual Hero Card
                      NowReadingHeroCard(
                        book: data.nowReading,
                        latestQuote: data.nowReadingLatestQuote,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // 3. Weekly 7-Day Reading Activity Chart
                      WeeklyActivityChart(
                        weeklyActivity: data.weeklyActivity,
                        totalChapters: data.weeklyTotalChapters,
                        todayMinutes: data.todayReadingMinutes,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // 4. Connected Ecosystem Quick-Action Grid (SRS, Quotes, Explorer, Shelf)
                      EcosystemQuickGrid(
                        dueReviewsCount: data.dueReviewsCount,
                        totalBookmarksCount: data.totalBookmarksCount,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // 5. Explore Genres / Mood Catalogs
                      const GenreCarouselSection(),
                      const SizedBox(height: AppSpacing.xl),

                      // 6. Trending Now from Plugin Sources
                      TrendingSection(
                        trendingBooks: data.trendingBooks,
                        isLoading: false,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // 7. Recently Added Library Shelf Carousel
                      if (data.books.isNotEmpty) ...[
                        _RecentlyAddedCarousel(books: data.books),
                        const SizedBox(height: AppSpacing.xl),
                      ],

                      // 8. Curated Sources & Immersive Catalogs
                      CuratedSourcesSection(sources: data.sources),
                      const SizedBox(height: AppSpacing.xl),

                      // 9. Live Reading Footprint & Stats Summary
                      StatsSummaryFooter(
                        totalBooks: data.totalBooksCount,
                        totalChaptersRead: data.totalChaptersReadCount,
                        totalReadingHours: data.totalReadingHours,
                        totalBookmarks: data.totalBookmarksCount,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
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
    final recent = books.take(6).toList();

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
              onPressed: () => context.go('/library'),
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
                    context.push('/novel/');
                  } else {
                    context.push('/book/');
                  }
                },
                child: SizedBox(
                  width: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BookCover(
                      coverPath: b.coverPath,
                      width: 96,
                      height: 140,
                    ),
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
