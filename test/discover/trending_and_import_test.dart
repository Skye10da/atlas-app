import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/infrastructure/services/recommendation_engine.dart';
import 'package:atlas_app/discover/presentation/providers/discover_providers.dart';
import 'package:atlas_app/discover/presentation/screens/trending_list_screen.dart';
import 'package:atlas_app/discover/presentation/widgets/trending_book_action_sheet.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const opdsBook = TrendingBook(
    title: 'Pride and Prejudice',
    sourceId: 'gutenberg',
    sourceName: 'Gutenberg',
    author: 'Jane Austen',
    genre: 'Classic',
    detailUrl: 'https://www.gutenberg.org/ebooks/1342',
    isOpds: true,
  );

  const webNovelBook = TrendingBook(
    title: 'The Gift of Loot',
    sourceId: 'royalroad',
    sourceName: 'Royal Road',
    author: 'ActiveThreads',
    genre: 'LitRPG',
    detailUrl: 'https://www.royalroad.com/fiction/trending',
    isOpds: false,
  );

  test('DiscoverDashboardData correctly separates OPDS and Web Novel feeds', () {
    const data = DiscoverDashboardData(
      books: [],
      nowReading: null,
      nowReadingLatestQuote: null,
      streakDays: 0,
      weeklyActivity: [],
      weeklyTotalChapters: 0,
      todayReadingMinutes: 0,
      dueReviewsCount: 0,
      totalBookmarksCount: 0,
      totalBooksCount: 0,
      totalChaptersReadCount: 0,
      totalReadingHours: 0,
      sources: [],
      trendingBooks: {
        'gutenberg': [opdsBook],
        'royalroad': [webNovelBook],
      },
    );

    expect(data.opdsTrendingBooks.containsKey('gutenberg'), isTrue);
    expect(data.opdsTrendingBooks.containsKey('royalroad'), isFalse);

    expect(data.webNovelTrendingBooks.containsKey('royalroad'), isTrue);
    expect(data.webNovelTrendingBooks.containsKey('gutenberg'), isFalse);
  });

  test('RecommendationEngine matches user library genre affinity', () {
    const engine = RecommendationEngine();
    final libraryBooks = [
      BookEntity(
        id: '1',
        title: 'Martial World',
        author: 'Cocooned Cow',
        coverPath: null,
        format: 'novel',
        totalChapters: 100,
        tags: const ['wuxia', 'cultivation'],
        itemType: ContentCategory.novel,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    final candidateTrending = {
      'royalroad': [
        const TrendingBook(
          title: 'Cultivation Online',
          sourceId: 'royalroad',
          sourceName: 'Royal Road',
          genre: 'Cultivation',
        ),
        const TrendingBook(
          title: 'Baking 101',
          sourceId: 'royalroad',
          sourceName: 'Royal Road',
          genre: 'Cooking',
        ),
      ],
    };

    final recommendations = engine.computeRecommendations(
      libraryBooks: libraryBooks,
      allTrending: candidateTrending,
    );

    expect(recommendations.isNotEmpty, isTrue);
    expect(recommendations.first.genre, 'Cultivation');
    expect(recommendations.first.matchPercentage, greaterThan(80));
  });

  testWidgets('TrendingBookActionSheet displays book details and action buttons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrendingBookActionSheet(book: opdsBook),
        ),
      ),
    );

    expect(find.text('Pride and Prejudice'), findsOneWidget);
    expect(find.text('by Jane Austen'), findsOneWidget);
    expect(find.text('Gutenberg'), findsOneWidget);
    expect(find.text('Add to Library (Direct Import)'), findsOneWidget);
    expect(find.text('Open in Web Reader'), findsOneWidget);
  });

  testWidgets('TrendingListScreen switches between OPDS and Web Novels and limits', (tester) async {
    const mockData = DiscoverDashboardData(
      books: [],
      nowReading: null,
      nowReadingLatestQuote: null,
      streakDays: 5,
      weeklyActivity: [],
      weeklyTotalChapters: 0,
      todayReadingMinutes: 0,
      dueReviewsCount: 0,
      totalBookmarksCount: 0,
      totalBooksCount: 0,
      totalChaptersReadCount: 0,
      totalReadingHours: 0,
      sources: [],
      opdsTrendingBooks: {
        'gutenberg': [opdsBook],
      },
      webNovelTrendingBooks: {
        'royalroad': [webNovelBook],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoverDashboardProvider.overrideWith(
            (ref) => Future.value(const Success(mockData)),
          ),
        ],
        child: const MaterialApp(
          home: TrendingListScreen(initialType: 'opds'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('OPDS Trending Catalog'), findsOneWidget);
    expect(find.text('Pride and Prejudice'), findsOneWidget);

    // Switch to Web Novels
    await tester.tap(find.text('Web Novels'));
    await tester.pumpAndSettle();

    expect(find.text('The Gift of Loot'), findsOneWidget);
  });
}
