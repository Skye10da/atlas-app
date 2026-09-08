import 'package:drift/drift.dart';
import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/domain/repositories/discover_repository_interface.dart';
import 'package:atlas_app/discover/infrastructure/services/reading_analytics_service.dart';
import 'package:atlas_app/discover/infrastructure/services/recommendation_engine.dart';
import 'package:atlas_app/discover/infrastructure/services/trending_service.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';

class DriftDiscoverRepository implements DiscoverRepositoryInterface {
  DriftDiscoverRepository({
    required AppDatabase db,
    required List<SearchableSource> Function() getSources,
    required TrendingService trendingService,
    ReadingAnalyticsService? analyticsService,
    RecommendationEngine? recommendationEngine,
  })  : _db = db,
        _getSources = getSources,
        _trendingService = trendingService,
        _analyticsService = analyticsService ?? ReadingAnalyticsService(db: db),
        _recommendationEngine = recommendationEngine;

  final AppDatabase _db;
  final List<SearchableSource> Function() _getSources;
  final TrendingService _trendingService;
  final ReadingAnalyticsService _analyticsService;
  final RecommendationEngine? _recommendationEngine;

  RecommendationEngine get recommendationEngine =>
      _recommendationEngine ?? const RecommendationEngine();

  @override
  Future<Result<DiscoverDashboardData>> getDashboardData() async {
    try {
      final libraryRepo = DriftLibraryRepository(_db);
      final booksResult = await libraryRepo.getBooks();
      final List<BookEntity> books = switch (booksResult) {
        Success(value: final b) => b,
        Failure() => <BookEntity>[],
      };

      // 1. Determine Now Reading: Most recently read book with progress > 0
      final progressRows = await _db.select(_db.readingProgress).get();
      final progressMap = {for (final p in progressRows) p.bookId: p};

      BookEntity? nowReading;
      if (books.isNotEmpty) {
        final activeBooks = List<BookEntity>.from(books)..sort((a, b) {
            final pA = progressMap[a.id]?.lastReadAt ?? a.updatedAt;
            final pB = progressMap[b.id]?.lastReadAt ?? b.updatedAt;
            return pB.compareTo(pA);
          });
        nowReading = activeBooks.firstWhere(
          (b) => (b.progress ?? 0) > 0,
          orElse: () => activeBooks.first,
        );
      }

      // 2. Fetch latest saved bookmark / quote for nowReading or any book
      String? latestQuote;
      if (nowReading != null) {
        final bookmark = await (_db.select(_db.bookmarks)
              ..where((b) => b.bookId.equals(nowReading!.id))
              ..orderBy([(b) => OrderingTerm.desc(b.createdAt)])
              ..limit(1))
            .getSingleOrNull();
        if (bookmark?.note != null && bookmark!.note!.trim().isNotEmpty) {
          latestQuote = bookmark.note!.trim();
        }
      }
      if (latestQuote == null) {
        final anyBookmark = await (_db.select(_db.bookmarks)
              ..where((b) => b.note.isNotNull())
              ..orderBy([(b) => OrderingTerm.desc(b.createdAt)])
              ..limit(1))
            .getSingleOrNull();
        if (anyBookmark?.note != null && anyBookmark!.note!.trim().isNotEmpty) {
          latestQuote = anyBookmark.note!.trim();
        }
      }

      // 3. Fetch reading insights directly from analytics — single source of truth.
      // Previously this was recomputed here from reading_progress only,
      // duplicating and drifting from ReadingAnalyticsService (which uses
      // reading_sessions + progress). Now we delegate entirely.
      final analyticsReport = await _analyticsService.getAnalyticsReport();
      final streakDays = analyticsReport.currentStreak;
      final weeklyGoal = analyticsReport.weeklyGoal;
      final weeklyActivity = analyticsReport.weeklyActivity;
      final weeklyChapters = analyticsReport.weeklyActivity.fold<int>(
        0,
        (sum, d) => sum + d.chaptersRead,
      );
      final todayEntry = analyticsReport.weeklyActivity.firstWhere(
        (d) => d.isToday,
        orElse: () => analyticsReport.weeklyActivity.last,
      );
      final todayMinutes = todayEntry.readingMinutes;

      // 5. SRS Pending Reviews Count
      final nowUtc = DateTime.now().toUtc();
      final dueWords = await (_db.select(_db.dictionaryWords)
            ..where((w) =>
                w.nextReviewAt.isNull() | w.nextReviewAt.isSmallerOrEqualValue(nowUtc)))
          .get();
      final dueReviewsCount = dueWords.length;

      // 6. Total Bookmarks / Highlights Count — still direct count, not analytics.
      final allBookmarks = await _db.select(_db.bookmarks).get();
      final totalBookmarksCount = allBookmarks.length;

      // 7. Totals — fetch directly from analytics (single source of truth).
      // Previously recomputed from progressRows here, duplicating
      // ReadingAnalyticsService logic. Now delegate.
      final totalBooksCount = analyticsReport.totalBooks;
      final totalChaptersReadCount = analyticsReport.totalChaptersRead;
      final totalReadingHours = analyticsReport.totalHours;

      final sources = _getSources();

      // 8. Fetch trending from plugin sources + OPDS
      Map<String, List<TrendingBook>> trendingBooks;
      try {
        trendingBooks = await _trendingService.fetchAllTrending();
      } catch (_) {
        trendingBooks = const {};
      }

      // 9. Personalized "For You" recommendations
      final forYouRecommendations = recommendationEngine.computeRecommendations(
        libraryBooks: books,
        allTrending: trendingBooks,
      );

      // 10. Real genre book counts backed by library
      final genreBookCounts = <String, int>{
        'wuxia': 0,
        'romance': 0,
        'scifi': 0,
        'fantasy': 0,
        'mystery': 0,
        'classic': 0,
      };

      for (final b in books) {
        final tagsJoined = '${b.tags.join(' ')} ${b.title}'.toLowerCase();
        if (tagsJoined.contains('wuxia') || tagsJoined.contains('cultivation') || tagsJoined.contains('martial') || tagsJoined.contains('xianxia')) {
          genreBookCounts['wuxia'] = (genreBookCounts['wuxia'] ?? 0) + 1;
        }
        if (tagsJoined.contains('romance') || tagsJoined.contains('love') || tagsJoined.contains('drama') || tagsJoined.contains('royal')) {
          genreBookCounts['romance'] = (genreBookCounts['romance'] ?? 0) + 1;
        }
        if (tagsJoined.contains('sci-fi') || tagsJoined.contains('scifi') || tagsJoined.contains('cyberpunk') || tagsJoined.contains('space') || tagsJoined.contains('time')) {
          genreBookCounts['scifi'] = (genreBookCounts['scifi'] ?? 0) + 1;
        }
        if (tagsJoined.contains('fantasy') || tagsJoined.contains('magic') || tagsJoined.contains('dungeon') || tagsJoined.contains('litrpg')) {
          genreBookCounts['fantasy'] = (genreBookCounts['fantasy'] ?? 0) + 1;
        }
        if (tagsJoined.contains('mystery') || tagsJoined.contains('detective') || tagsJoined.contains('sherlock') || tagsJoined.contains('crime')) {
          genreBookCounts['mystery'] = (genreBookCounts['mystery'] ?? 0) + 1;
        }
        if (tagsJoined.contains('classic') || tagsJoined.contains('gutenberg') || tagsJoined.contains('public domain') || !b.isNovel) {
          genreBookCounts['classic'] = (genreBookCounts['classic'] ?? 0) + 1;
        }
      }

      // Supported sources count: registered sources + 4 OPDS catalogs
      final totalSourcesCount = sources.length + 4;

      return Success(
        DiscoverDashboardData(
          books: books,
          nowReading: nowReading,
          nowReadingLatestQuote: latestQuote,
          streakDays: streakDays,
          weeklyActivity: weeklyActivity,
          weeklyTotalChapters: weeklyChapters,
          todayReadingMinutes: todayMinutes,
          dueReviewsCount: dueReviewsCount,
          totalBookmarksCount: totalBookmarksCount,
          totalBooksCount: totalBooksCount,
          totalChaptersReadCount: totalChaptersReadCount > 0
              ? totalChaptersReadCount
              : books.fold<int>(0, (sum, b) => sum + b.totalChapters),
          totalReadingHours: totalReadingHours,
          sources: sources,
          trendingBooks: trendingBooks,
          weeklyGoal: weeklyGoal,
          forYouRecommendations: forYouRecommendations,
          genreBookCounts: genreBookCounts,
          totalSupportedSourcesCount: totalSourcesCount,
        ),
      );
    } catch (e, st) {
      return Failure(
        DatabaseException('Failed to load discover dashboard data', e),
        st,
      );
    }
  }
}
