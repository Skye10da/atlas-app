import 'package:flutter/material.dart';
import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

/// Snapshot of reading activity for a single day of the week.
class ReadingDayActivity {
  const ReadingDayActivity({
    required this.dayLabel,
    required this.date,
    required this.chaptersRead,
    required this.readingMinutes,
    required this.isToday,
  });

  final String dayLabel;
  final DateTime date;
  final int chaptersRead;
  final int readingMinutes;
  final bool isToday;
}

/// A mood / genre category for exploration.
class GenreMoodCategory {
  const GenreMoodCategory({
    required this.title,
    required this.countLabel,
    required this.bgColor,
    required this.accentColor,
    required this.icon,
    this.tagQuery,
  });

  final String title;
  final String countLabel;
  final Color bgColor;
  final Color accentColor;
  final IconData icon;
  final String? tagQuery;
}

/// A trending/popular book from a plugin source.
class TrendingBook {
  const TrendingBook({
    required this.title,
    required this.sourceId,
    required this.sourceName,
    this.author,
    this.coverUrl,
    this.detailUrl,
    this.rating,
    this.popularity,
    this.genre,
    this.description,
    this.fetchedAt,
  });

  final String title;
  final String sourceId;
  final String sourceName;
  final String? author;
  final String? coverUrl;
  final String? detailUrl;
  final String? rating;
  final String? popularity;
  final String? genre;
  final String? description;
  final DateTime? fetchedAt;
}

/// Comprehensive aggregated domain model powering the Discover Hub.
class DiscoverDashboardData {
  const DiscoverDashboardData({
    required this.books,
    required this.nowReading,
    required this.nowReadingLatestQuote,
    required this.streakDays,
    required this.weeklyActivity,
    required this.weeklyTotalChapters,
    required this.todayReadingMinutes,
    required this.dueReviewsCount,
    required this.totalBookmarksCount,
    required this.totalBooksCount,
    required this.totalChaptersReadCount,
    required this.totalReadingHours,
    required this.sources,
    this.trendingBooks = const {},
  });

  final List<BookEntity> books;
  final BookEntity? nowReading;
  final String? nowReadingLatestQuote;
  final int streakDays;
  final List<ReadingDayActivity> weeklyActivity;
  final int weeklyTotalChapters;
  final int todayReadingMinutes;
  final int dueReviewsCount;
  final int totalBookmarksCount;
  final int totalBooksCount;
  final int totalChaptersReadCount;
  final int totalReadingHours;
  final List<SearchableSource> sources;

  /// Trending books grouped by source ID.
  final Map<String, List<TrendingBook>> trendingBooks;
}
