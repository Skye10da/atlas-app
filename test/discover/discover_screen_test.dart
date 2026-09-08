import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/domain/entities/reading_analytics_entity.dart';
import 'package:atlas_app/discover/presentation/providers/discover_providers.dart';
import 'package:atlas_app/discover/presentation/providers/reading_analytics_providers.dart';
import 'package:atlas_app/discover/infrastructure/services/trending_service.dart';
import 'package:atlas_app/discover/presentation/screens/discover_screen.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/notifications/presentation/providers/notification_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleBook = BookEntity(
    id: 'sample_book_1',
    title: 'Whispers of Void',
    author: 'Elara Vance',
    coverPath: null,
    format: 'epub',
    totalChapters: 50,
    description: 'An epic tale of void exploration.',
    progress: 0.74,
    itemType: ContentCategory.book,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final mockDashboardData = DiscoverDashboardData(
    books: [sampleBook],
    nowReading: sampleBook,
    nowReadingLatestQuote: 'The darkness is not an ending.',
    streakDays: 12,
    weeklyActivity: [
      ReadingDayActivity(
        dayLabel: 'M',
        date: DateTime.now(),
        chaptersRead: 5,
        readingMinutes: 30,
        isToday: false,
      ),
      ReadingDayActivity(
        dayLabel: 'T',
        date: DateTime.now(),
        chaptersRead: 8,
        readingMinutes: 45,
        isToday: true,
      ),
    ],
    weeklyTotalChapters: 13,
    todayReadingMinutes: 45,
    dueReviewsCount: 5,
    totalBookmarksCount: 18,
    totalBooksCount: 1,
    totalChaptersReadCount: 37,
    totalReadingHours: 12,
    sources: [],
    weeklyGoal: const ReadingGoalEntity(
      weeklyChapterTarget: 20,
      dailyMinuteTarget: 30,
      weeklyChaptersCompleted: 13,
      todayMinutesRead: 45,
      weeklyCompletionPercentage: 0.65,
      currentStreak: 12,
    ),
    genreBookCounts: const {
      'fantasy': 1,
    },
    opdsTrendingBooks: const {
      'gutenberg': [
        TrendingBook(
          title: 'Pride and Prejudice',
          sourceId: 'gutenberg',
          sourceName: 'Gutenberg',
          author: 'Jane Austen',
          isOpds: true,
        ),
      ],
    },
    webNovelTrendingBooks: const {
      'royalroad': [
        TrendingBook(
          title: 'The Gift of Loot',
          sourceId: 'royalroad',
          sourceName: 'Royal Road',
          author: 'ActiveThreads',
          isOpds: false,
        ),
      ],
    },
  );

  testWidgets('DiscoverScreen renders ecosystem widgets cleanly', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockAnalyticsReport = ReadingAnalyticsReport(
      totalBooks: 1,
      totalChaptersRead: 37,
      totalReadingSeconds: 43200,
      currentStreak: 12,
      longestStreak: 16,
      weeklyActivity: mockDashboardData.weeklyActivity,
      monthlyDailyActivity: mockDashboardData.weeklyActivity,
      weeklyGoal: mockDashboardData.weeklyGoal,
      timeOfDay: const ReadingTimeOfDayBreakdown(
        morningMinutes: 25,
        afternoonMinutes: 40,
        eveningMinutes: 85,
        nightMinutes: 30,
      ),
      genreStats: const [],
      formatRatio: const FormatReadRatio(
        novelMinutes: 120,
        bookMinutes: 60,
        novelChapters: 30,
        bookChapters: 7,
      ),
      recentSessions: const [],
      averagePaceMinutesPerChapter: 8.5,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoverDashboardProvider.overrideWith(
            (ref) => Future.value(Success(mockDashboardData)),
          ),
          readingAnalyticsReportProvider.overrideWith(
            (ref) => Future.value(mockAnalyticsReport),
          ),
          unreadNotificationCountProvider.overrideWith(
            (ref) => Stream.value(3),
          ),
        ],
        child: const MaterialApp(
          home: DiscoverScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Header and Streak
    expect(find.text('Welcome back, Reader'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);

    // 2. Now Reading Card
    expect(find.text('NOW READING'), findsOneWidget);
    expect(find.text('Whispers of Void'), findsWidgets);
    expect(find.text('Elara Vance'), findsWidgets);
    expect(find.text('74%'), findsOneWidget);
    expect(find.text('Continue Reading'), findsOneWidget);
    expect(find.text('"The darkness is not an ending."'), findsOneWidget);

    // 3. Quick Stats Row
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('Chapters'), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);

    // 4. Weekly Goal & Activity
    expect(find.text('Weekly Reading Goal'), findsOneWidget);
    expect(find.text("This Week's Activity"), findsOneWidget);
    expect(find.text('13 chapters'), findsOneWidget);

    // 5. OPDS and Web Novel Trending Sections
    expect(find.text('🔥 OPDS Trending Now'), findsOneWidget);
    expect(find.text('🔥 Web Novel Trending Now'), findsOneWidget);

    // 6. Curated Collections, Content Sources & Footprint (scroll down)
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Curated Collections'), findsOneWidget);
    expect(find.text('Content Sources'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Reading Footprint'), findsOneWidget);
    expect(find.text('Saved Quotes'), findsOneWidget);
  });

  test('TrendingService handles fetchAllTrending with forceRefresh and fallback defaults', () async {
    final trendingService = TrendingService(
      pluginSources: const [],
    );
    // Verify getter safe default
    expect(trendingService.opdsService, isNotNull);

    final results = await trendingService.fetchAllTrending(forceRefresh: true);
    expect(results, isNotEmpty);
    expect(results.containsKey('gutenberg'), isTrue);
    expect(results.containsKey('standard'), isTrue);
    expect(results.containsKey('feedbooks'), isTrue);
    expect(results.containsKey('openlib'), isTrue);
    expect(results['gutenberg']!.first.isOpds, isTrue);
  });
}
