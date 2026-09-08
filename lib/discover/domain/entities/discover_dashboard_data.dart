import 'package:flutter/material.dart';
import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/discover/domain/entities/reading_analytics_entity.dart';
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

/// A trending/popular or recommended book from a plugin or OPDS source.
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
    this.matchPercentage,
    bool? isOpds,
  }) : _isOpds = isOpds;

  factory TrendingBook.fromJson(Map<String, dynamic> json) => TrendingBook(
        title: json['title'] as String? ?? 'Untitled',
        sourceId: json['sourceId'] as String? ?? '',
        sourceName: json['sourceName'] as String? ?? '',
        author: json['author'] as String?,
        coverUrl: json['coverUrl'] as String?,
        detailUrl: json['detailUrl'] as String?,
        rating: json['rating'] as String?,
        popularity: json['popularity'] as String?,
        genre: json['genre'] as String?,
        description: json['description'] as String?,
        fetchedAt: json['fetchedAt'] != null
            ? DateTime.tryParse(json['fetchedAt'] as String)
            : null,
        matchPercentage: json['matchPercentage'] as int?,
        isOpds: json['isOpds'] as bool? ?? false,
      );

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
  final int? matchPercentage;
  final bool? _isOpds;

  bool get isOpds => _isOpds ?? false;

  Map<String, dynamic> toJson() => {
        'title': title,
        'sourceId': sourceId,
        'sourceName': sourceName,
        'author': author,
        'coverUrl': coverUrl,
        'detailUrl': detailUrl,
        'rating': rating,
        'popularity': popularity,
        'genre': genre,
        'description': description,
        'fetchedAt': fetchedAt?.toIso8601String(),
        'matchPercentage': matchPercentage,
        'isOpds': isOpds,
      };
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
    ReadingGoalEntity? weeklyGoal,
    Map<String, List<TrendingBook>>? trendingBooks,
    Map<String, List<TrendingBook>>? opdsTrendingBooks,
    Map<String, List<TrendingBook>>? webNovelTrendingBooks,
    List<TrendingBook>? forYouRecommendations,
    Map<String, int>? genreBookCounts,
    int? totalSupportedSourcesCount,
  })  : _weeklyGoal = weeklyGoal,
        _trendingBooks = trendingBooks,
        _opdsTrendingBooks = opdsTrendingBooks,
        _webNovelTrendingBooks = webNovelTrendingBooks,
        _forYouRecommendations = forYouRecommendations,
        _genreBookCounts = genreBookCounts,
        _totalSupportedSourcesCount = totalSupportedSourcesCount;

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

  final ReadingGoalEntity? _weeklyGoal;
  final Map<String, List<TrendingBook>>? _trendingBooks;
  final Map<String, List<TrendingBook>>? _opdsTrendingBooks;
  final Map<String, List<TrendingBook>>? _webNovelTrendingBooks;
  final List<TrendingBook>? _forYouRecommendations;
  final Map<String, int>? _genreBookCounts;
  final int? _totalSupportedSourcesCount;

  /// Weekly reading goal
  ReadingGoalEntity get weeklyGoal =>
      _weeklyGoal ?? ReadingGoalEntity.initial();

  /// Trending books grouped by source ID (all sources combined)
  Map<String, List<TrendingBook>> get trendingBooks {
    if (_trendingBooks != null) return _trendingBooks;
    final merged = <String, List<TrendingBook>>{};
    merged.addAll(opdsTrendingBooks);
    merged.addAll(webNovelTrendingBooks);
    return merged;
  }

  static const _opdsSourceIds = {'gutenberg', 'standard', 'feedbooks', 'openlib'};

  /// OPDS Trending books grouped by catalog (Gutenberg, Standard Ebooks, Feedbooks, Open Library)
  Map<String, List<TrendingBook>> get opdsTrendingBooks {
    if (_opdsTrendingBooks != null) return _opdsTrendingBooks;
    final result = <String, List<TrendingBook>>{};
    for (final entry in (_trendingBooks ?? const <String, List<TrendingBook>>{}).entries) {
      if (_opdsSourceIds.contains(entry.key) || entry.value.any((b) => b.isOpds)) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  /// Web Novel Trending books grouped by plugin (Royal Road, ReadNovelFull, etc.)
  Map<String, List<TrendingBook>> get webNovelTrendingBooks {
    if (_webNovelTrendingBooks != null) return _webNovelTrendingBooks;
    final result = <String, List<TrendingBook>>{};
    for (final entry in (_trendingBooks ?? const <String, List<TrendingBook>>{}).entries) {
      if (!_opdsSourceIds.contains(entry.key) && !entry.value.any((b) => b.isOpds)) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  /// Personalized "For You" recommendations with match percentage
  List<TrendingBook> get forYouRecommendations =>
      _forYouRecommendations ?? const [];

  /// Real book counts mapped by genre tag
  Map<String, int> get genreBookCounts =>
      _genreBookCounts ?? const {};

  /// Total supported sources count across plugins and catalogs
  int get totalSupportedSourcesCount =>
      _totalSupportedSourcesCount ?? sources.length;
}
