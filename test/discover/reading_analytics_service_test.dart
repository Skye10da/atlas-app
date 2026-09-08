import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/discover/infrastructure/services/reading_analytics_service.dart';

void main() {
  late AppDatabase db;
  late ReadingAnalyticsService service;

  setUp(() {
    db = AppDatabase.memory();
    service = ReadingAnalyticsService(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('ReadingAnalyticsService records reading session and updates reading progress', () async {
    // 1. Record a reading session
    await service.recordReadingSession(
      bookId: 'test_book_1',
      durationSeconds: 1200,
      chaptersRead: 2,
    );

    // 2. Query reading sessions directly via custom query
    final sessionRows = await db.customSelect('SELECT * FROM reading_sessions').get();
    expect(sessionRows.length, 1);
    expect(sessionRows.first.data['book_id'], 'test_book_1');
    expect(sessionRows.first.data['duration_seconds'], 1200);
    expect(sessionRows.first.data['chapters_read'], 2);

    // 3. Verify analytics report aggregates the session
    final report = await service.getAnalyticsReport();
    expect(report.totalHours, 0); // 1200s is 0.33h -> rounds to 0
    expect(report.totalChaptersRead, 2);
    expect(report.weeklyActivity.isNotEmpty, isTrue);
  });

  test('ReadingAnalyticsService updates and persists reading goals', () async {
    // Initial goal
    final initialGoal = await service.getGoal();
    expect(initialGoal.weeklyChapterTarget, 20);
    expect(initialGoal.dailyMinuteTarget, 30);

    // Update goal
    await service.updateGoal(
      weeklyChapterTarget: 35,
      dailyMinuteTarget: 45,
    );

    final updatedGoal = await service.getGoal();
    expect(updatedGoal.weeklyChapterTarget, 35);
    expect(updatedGoal.dailyMinuteTarget, 45);
  });
}
