import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/discover/domain/entities/reading_analytics_entity.dart';
import 'package:atlas_app/discover/infrastructure/services/reading_analytics_service.dart';

final readingAnalyticsServiceProvider = Provider<ReadingAnalyticsService>((ref) {
  final db = ref.watch(databaseProvider);
  return ReadingAnalyticsService(db: db);
});

final readingAnalyticsReportProvider =
    FutureProvider<ReadingAnalyticsReport>((ref) async {
  final service = ref.watch(readingAnalyticsServiceProvider);
  return service.getAnalyticsReport();
});

final readingGoalProvider = FutureProvider<ReadingGoalEntity>((ref) async {
  final service = ref.watch(readingAnalyticsServiceProvider);
  return service.getGoal();
});

