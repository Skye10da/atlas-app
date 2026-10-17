import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/presentation/providers/discover_providers.dart';
import 'package:atlas_app/find_new/presentation/screens/find_new_screen.dart';
import 'package:atlas_app/find_new/presentation/widgets/for_you_section.dart';
import 'package:atlas_app/find_new/presentation/widgets/genre_carousel_section.dart';
import 'package:atlas_app/find_new/presentation/widgets/stats_summary_footer.dart';
import 'package:atlas_app/find_new/presentation/widgets/trending_section.dart';
import 'package:atlas_app/search/presentation/screens/search_screen.dart';

DiscoverDashboardData _sampleData() => const DiscoverDashboardData(
      books: [],
      nowReading: null,
      nowReadingLatestQuote: null,
      streakDays: 3,
      weeklyActivity: [],
      weeklyTotalChapters: 5,
      todayReadingMinutes: 20,
      dueReviewsCount: 0,
      totalBookmarksCount: 4,
      totalBooksCount: 8,
      totalChaptersReadCount: 120,
      totalReadingHours: 12,
      sources: [],
      opdsTrendingBooks: {
        'gutenberg': [
          TrendingBook(
            title: 'Moby Dick',
            sourceId: 'gutenberg',
            sourceName: 'Gutenberg',
            isOpds: true,
          ),
        ],
      },
      forYouRecommendations: [
        TrendingBook(
          title: 'Dune',
          sourceId: 'gutenberg',
          sourceName: 'Gutenberg',
          matchPercentage: 92,
        ),
      ],
      genreBookCounts: {'wuxia': 12},
      totalSupportedSourcesCount: 4,
    );

void main() {
  group('FindNewScreen', () {
    testWidgets('renders every discovery section when data is loaded', (
      tester,
    ) async {
      // Tall viewport so every lazily-built list section is realised.
      tester.view.physicalSize = const Size(1000, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoverDashboardProvider.overrideWith((ref) => Success(_sampleData())),
          ],
          child: const MaterialApp(home: Scaffold(body: FindNewScreen())),
        ),
      );
      await tester.pump();

      expect(find.byType(TrendingSection), findsOneWidget);
      expect(find.byType(ForYouSection), findsOneWidget);
      expect(find.byType(GenreCarouselSection), findsOneWidget);
      expect(find.byType(StatsSummaryFooter), findsOneWidget);
      expect(find.text('Reading Footprint'), findsOneWidget);
      expect(find.text('For You'), findsOneWidget);
    });

    testWidgets('shows a loading indicator while the dashboard resolves', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoverDashboardProvider.overrideWith(
              (ref) => Completer<Result<DiscoverDashboardData>>().future,
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: FindNewScreen())),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.byType(TrendingSection), findsNothing);
    });

    testWidgets('surfaces an error state with a retry action', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoverDashboardProvider.overrideWith(
              (ref) => Future<Result<DiscoverDashboardData>>.error(
                Exception('boom'),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: FindNewScreen())),
        ),
      );
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('SearchScreen ("Find new")', () {
    testWidgets('leads with the discovery surface and exposes all tabs', (
      tester,
    ) async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            discoverDashboardProvider.overrideWith((ref) => Success(_sampleData())),
          ],
          child: const MaterialApp(home: SearchScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Find new'), findsOneWidget);
      for (final label in ['Browse', 'Library', 'Lookup', 'Saved']) {
        expect(find.text(label), findsOneWidget);
      }

      // The Browse tab is selected by default, so discovery is the first body.
      expect(find.byType(FindNewScreen), findsOneWidget);
    });
  });
}
