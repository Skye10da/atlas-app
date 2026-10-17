import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/router/app_router.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/presentation/providers/discover_providers.dart';
import 'package:atlas_app/find_new/presentation/widgets/curated_sources_section.dart';
import 'package:atlas_app/find_new/presentation/widgets/for_you_section.dart';
import 'package:atlas_app/find_new/presentation/widgets/genre_carousel_section.dart';
import 'package:atlas_app/find_new/presentation/widgets/stats_summary_footer.dart';
import 'package:atlas_app/find_new/presentation/widgets/trending_section.dart';

/// "Find new" — the discovery surface that used to live on the standalone
/// Discover page. Hosted as the default tab of the Search branch.
class FindNewScreen extends ConsumerWidget {
  const FindNewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(discoverDashboardProvider);
    final result = dashboardAsync.valueOrNull;
    final DiscoverDashboardData? data = result is Success<DiscoverDashboardData>
        ? result.value
        : null;

    if (data == null) {
      if (dashboardAsync.hasError || result is Failure) {
        final message = result is Failure
            ? (result as Failure).error.userMessage
            : 'Could not load discovery data.';
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.explore_off_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(discoverDashboardProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: AppLoading());
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(discoverDashboardProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: AppSpacing.xxl,
        ),
        children: [
          if (data.opdsTrendingBooks.isNotEmpty)
            _Section(
              child: TrendingSection(
                title: '🔥 Trending now',
                trendingBooks: data.opdsTrendingBooks,
                isLoading: false,
                onRefresh: () => ref.invalidate(discoverDashboardProvider),
                onViewAll: () => AppRouter.openTrending(context, type: 'opds'),
              ),
            ),
          if (data.webNovelTrendingBooks.isNotEmpty)
            _Section(
              child: TrendingSection(
                title: '🔥 Trending web novels',
                trendingBooks: data.webNovelTrendingBooks,
                isLoading: false,
                onRefresh: () => ref.invalidate(discoverDashboardProvider),
                onViewAll: () =>
                    AppRouter.openTrending(context, type: 'webnovel'),
              ),
            ),
          if (data.forYouRecommendations.isNotEmpty)
            _Section(
              child: ForYouSection(
                recommendations: data.forYouRecommendations,
              ),
            ),
          if (data.genreBookCounts.isNotEmpty)
            _Section(
              child: GenreCarouselSection(
                genreBookCounts: data.genreBookCounts,
              ),
            ),
          if (data.sources.isNotEmpty)
            _Section(
              child: CuratedSourcesSection(
                sources: data.sources,
                totalSupportedSourcesCount: data.totalSupportedSourcesCount,
              ),
            ),
          _Section(
            child: StatsSummaryFooter(
              totalBooks: data.totalBooksCount,
              totalChaptersRead: data.totalChaptersReadCount,
              totalReadingHours: data.totalReadingHours,
              totalBookmarks: data.totalBookmarksCount,
            ),
          ),
        ],
      ),
    );
  }
}

/// Applies the shared horizontal gutter used by every discovery section.
class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: child,
    );
  }
}
