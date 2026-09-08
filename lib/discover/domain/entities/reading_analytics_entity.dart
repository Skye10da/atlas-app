import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';

class ReadingGoalEntity {
  const ReadingGoalEntity({
    required this.weeklyChapterTarget,
    required this.dailyMinuteTarget,
    required this.weeklyChaptersCompleted,
    required this.todayMinutesRead,
    required this.weeklyCompletionPercentage,
    required this.currentStreak,
  });

  factory ReadingGoalEntity.initial() => const ReadingGoalEntity(
        weeklyChapterTarget: 20,
        dailyMinuteTarget: 30,
        weeklyChaptersCompleted: 0,
        todayMinutesRead: 0,
        weeklyCompletionPercentage: 0.0,
        currentStreak: 1,
      );

  final int weeklyChapterTarget;
  final int dailyMinuteTarget;
  final int weeklyChaptersCompleted;
  final int todayMinutesRead;
  final double weeklyCompletionPercentage;
  final int currentStreak;

  ReadingGoalEntity copyWith({
    int? weeklyChapterTarget,
    int? dailyMinuteTarget,
    int? weeklyChaptersCompleted,
    int? todayMinutesRead,
    double? weeklyCompletionPercentage,
    int? currentStreak,
  }) {
    return ReadingGoalEntity(
      weeklyChapterTarget: weeklyChapterTarget ?? this.weeklyChapterTarget,
      dailyMinuteTarget: dailyMinuteTarget ?? this.dailyMinuteTarget,
      weeklyChaptersCompleted:
          weeklyChaptersCompleted ?? this.weeklyChaptersCompleted,
      todayMinutesRead: todayMinutesRead ?? this.todayMinutesRead,
      weeklyCompletionPercentage:
          weeklyCompletionPercentage ?? this.weeklyCompletionPercentage,
      currentStreak: currentStreak ?? this.currentStreak,
    );
  }
}

class ReadingTimeOfDayBreakdown {
  const ReadingTimeOfDayBreakdown({
    required this.morningMinutes,
    required this.afternoonMinutes,
    required this.eveningMinutes,
    required this.nightMinutes,
  });

  final int morningMinutes; // 6:00 - 11:59
  final int afternoonMinutes; // 12:00 - 17:59
  final int eveningMinutes; // 18:00 - 21:59
  final int nightMinutes; // 22:00 - 5:59

  int get totalMinutes =>
      morningMinutes + afternoonMinutes + eveningMinutes + nightMinutes;
}

class GenreReadStat {
  const GenreReadStat({
    required this.genre,
    required this.bookCount,
    required this.chaptersRead,
    required this.readingMinutes,
    required this.percentage,
  });

  final String genre;
  final int bookCount;
  final int chaptersRead;
  final int readingMinutes;
  final double percentage;
}

class FormatReadRatio {
  const FormatReadRatio({
    required this.novelMinutes,
    required this.bookMinutes,
    required this.novelChapters,
    required this.bookChapters,
  });

  final int novelMinutes;
  final int bookMinutes;
  final int novelChapters;
  final int bookChapters;

  int get totalMinutes => novelMinutes + bookMinutes;
  double get novelPercentage =>
      totalMinutes == 0 ? 0.5 : (novelMinutes / totalMinutes).clamp(0.0, 1.0);
  double get bookPercentage =>
      totalMinutes == 0 ? 0.5 : (bookMinutes / totalMinutes).clamp(0.0, 1.0);
}

class ReadingSessionEntity {
  const ReadingSessionEntity({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.durationSeconds,
    required this.chaptersRead,
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final int durationSeconds;
  final int chaptersRead;
  final DateTime createdAt;
}

class ReadingAnalyticsReport {
  const ReadingAnalyticsReport({
    required this.totalBooks,
    required this.totalChaptersRead,
    required this.totalReadingSeconds,
    required this.currentStreak,
    required this.longestStreak,
    required this.weeklyActivity,
    required this.monthlyDailyActivity,
    required this.weeklyGoal,
    required this.timeOfDay,
    required this.genreStats,
    required this.formatRatio,
    required this.recentSessions,
    required this.averagePaceMinutesPerChapter,
  });

  final int totalBooks;
  final int totalChaptersRead;
  final int totalReadingSeconds;
  final int currentStreak;
  final int longestStreak;
  final List<ReadingDayActivity> weeklyActivity;
  final List<ReadingDayActivity> monthlyDailyActivity;
  final ReadingGoalEntity weeklyGoal;
  final ReadingTimeOfDayBreakdown timeOfDay;
  final List<GenreReadStat> genreStats;
  final FormatReadRatio formatRatio;
  final List<ReadingSessionEntity> recentSessions;
  final double averagePaceMinutesPerChapter;

  int get totalHours => (totalReadingSeconds / 3600).round();
}

