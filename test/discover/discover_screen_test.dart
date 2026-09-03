import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/presentation/providers/discover_providers.dart';
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
  );

  testWidgets('DiscoverScreen renders ecosystem widgets cleanly', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoverDashboardProvider.overrideWith(
            (ref) => Future.value(Success(mockDashboardData)),
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
    expect(find.text('12 DAY'), findsOneWidget);

    // 2. Now Reading Card
    expect(find.text('NOW READING'), findsOneWidget);
    expect(find.text('Whispers of Void'), findsOneWidget);
    expect(find.text('Elara Vance'), findsOneWidget);
    expect(find.text('74%'), findsOneWidget);
    expect(find.text('Resume Reading'), findsOneWidget);
    expect(find.text('The darkness is not an ending.'), findsOneWidget);

    // 3. Weekly Activity & Ecosystem Grid
    expect(find.text('Weekly Activity'), findsOneWidget);
    expect(find.text('13 chapters'), findsOneWidget);
    expect(find.text('Ecosystem Grid'), findsOneWidget);
    expect(find.text('Novel Explorer'), findsOneWidget);
    expect(find.text('Vocabulary & SRS'), findsOneWidget);
    expect(find.text('5 due'), findsOneWidget);
    expect(find.text('Quotes & Bookmarks'), findsOneWidget);

    // 4. Explore Genres & Reading Footprint
    expect(find.text('Explore Genres'), findsOneWidget);
    expect(find.text('Reading Footprint'), findsOneWidget);
    expect(find.text('Saved Quotes'), findsOneWidget);
  });
}
