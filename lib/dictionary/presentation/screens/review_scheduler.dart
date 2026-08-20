import 'package:atlas_app/dictionary/domain/entities/dictionary_word_entity.dart';

class ReviewScheduler {
  ReviewScheduler._();

  static const List<Duration> intervals = [
    Duration(hours: 4),
    Duration(days: 1),
    Duration(days: 3),
    Duration(days: 7),
    Duration(days: 14),
    Duration(days: 30),
  ];

  static const int maxLevel = 5;

  static int nextLevel(int currentLevel, {required bool correct}) {
    if (correct) return (currentLevel + 1).clamp(0, maxLevel);
    return (currentLevel - 2).clamp(0, maxLevel);
  }

  static DateTime nextReviewDate(int level, {DateTime? from}) {
    final base = from ?? DateTime.now();
    return base.add(intervals[level.clamp(0, maxLevel)]);
  }

  static bool isMastered(int level) => level >= maxLevel;

  static String levelLabel(int level) {
    const labels = [
      'New',
      'Learning',
      'Familiar',
      'Good',
      'Strong',
      'Mastered',
    ];
    return labels[level.clamp(0, labels.length - 1)];
  }

  static bool isDue(DictionaryWordEntity word) {
    final next = word.nextReviewAt;
    return next == null || !next.isAfter(DateTime.now());
  }

  static List<DictionaryWordEntity> dueWords(List<DictionaryWordEntity> words) {
    return words.where(isDue).toList();
  }

  static int masteredCount(List<DictionaryWordEntity> words) {
    return words.where((w) => isMastered(w.reviewLevel)).length;
  }

  static int currentStreak(List<DictionaryWordEntity> words) {
    final days = words
        .map((w) => w.lastReviewedAt)
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    if (days.isEmpty) return 0;

    var today = DateTime.now();
    today = DateTime(today.year, today.month, today.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (!days.contains(today) && !days.contains(yesterday)) return 0;

    var cursor = days.contains(today) ? today : yesterday;
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
