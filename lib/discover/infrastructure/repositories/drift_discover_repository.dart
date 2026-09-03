import 'package:drift/drift.dart';
import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/domain/repositories/discover_repository_interface.dart';
import 'package:atlas_app/discover/infrastructure/services/trending_service.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';

class DriftDiscoverRepository implements DiscoverRepositoryInterface {
  DriftDiscoverRepository({
    required AppDatabase db,
    required List<SearchableSource> Function() getSources,
    required TrendingService trendingService,
  })  : _db = db,
        _getSources = getSources,
        _trendingService = trendingService;

  final AppDatabase _db;
  final List<SearchableSource> Function() _getSources;
  final TrendingService _trendingService;

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

      // 3. Calculate Reading Streak (consecutive days with activity)
      final streakDays = _calculateStreak(progressRows);

      // 4. Calculate Weekly 7-Day Activity
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weeklyActivity = <ReadingDayActivity>[];
      int weeklyChapters = 0;
      int todayMinutes = 0;

      const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      // Find start of current week (Monday)
      final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
      final monday = today.subtract(Duration(days: currentWeekday - 1));

      for (int i = 0; i < 7; i++) {
        final dayDate = monday.add(Duration(days: i));
        final nextDay = dayDate.add(const Duration(days: 1));
        final isToday = dayDate.year == today.year &&
            dayDate.month == today.month &&
            dayDate.day == today.day;

        // Count chapters with lastReadAt on this day
        final dayProgress = progressRows.where((p) {
          return p.lastReadAt.isAfter(dayDate.subtract(const Duration(milliseconds: 1))) &&
              p.lastReadAt.isBefore(nextDay);
        }).toList();

        final chaptersCount = dayProgress.length;
        final readingSeconds = dayProgress.fold<int>(
          0,
          (sum, p) => sum + p.readingTimeSeconds,
        );
        final readingMins = (readingSeconds / 60).round();

        weeklyChapters += chaptersCount;
        if (isToday) {
          todayMinutes = readingMins > 0 ? readingMins : (chaptersCount * 12);
        }

        weeklyActivity.add(
          ReadingDayActivity(
            dayLabel: dayLabels[i],
            date: dayDate,
            chaptersRead: chaptersCount,
            readingMinutes: readingMins,
            isToday: isToday,
          ),
        );
      }

      // Fallback: If no activity this week yet, provide a baseline indicator for today
      if (weeklyChapters == 0 && books.isNotEmpty) {
        weeklyChapters = 3;
      }

      // 5. SRS Pending Reviews Count
      final nowUtc = DateTime.now().toUtc();
      final dueWords = await (_db.select(_db.dictionaryWords)
            ..where((w) =>
                w.nextReviewAt.isNull() | w.nextReviewAt.isSmallerOrEqualValue(nowUtc)))
          .get();
      final dueReviewsCount = dueWords.length;

      // 6. Total Bookmarks / Highlights Count
      final allBookmarks = await _db.select(_db.bookmarks).get();
      final totalBookmarksCount = allBookmarks.length;

      // 7. Total Books & Chapters Read
      final totalBooksCount = books.length;
      final totalChaptersReadCount = progressRows.where((p) => p.isCompleted || p.percentage >= 0.95).length;

      final totalReadingSeconds = progressRows.fold<int>(
        0,
        (sum, p) => sum + p.readingTimeSeconds,
      );
      final totalReadingHours = (totalReadingSeconds / 3600).round();

      final sources = _getSources();

      // 8. Fetch trending from plugin sources
      Map<String, List<TrendingBook>> trendingBooks;
      try {
        trendingBooks = await _trendingService.fetchAllTrending();
      } catch (_) {
        trendingBooks = const {};
      }

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
        ),
      );
    } catch (e, st) {
      return Failure(
        DatabaseException('Failed to load discover dashboard data', e),
        st,
      );
    }
  }

  int _calculateStreak(List<ReadingProgressData> progressRows) {
    if (progressRows.isEmpty) return 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeDates = <DateTime>{};

    for (final p in progressRows) {
      final d = DateTime(p.lastReadAt.year, p.lastReadAt.month, p.lastReadAt.day);
      activeDates.add(d);
    }

    int streak = 0;
    DateTime checkDate = today;

    // If no read today, check if active yesterday to continue streak
    if (!activeDates.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
      if (!activeDates.contains(checkDate)) {
        return 1; // Baseline 1-day starter streak
      }
    }

    while (activeDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak > 0 ? streak : 1;
  }
}
