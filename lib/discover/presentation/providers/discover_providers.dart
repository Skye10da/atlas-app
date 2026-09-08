import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:atlas_app/core/content_engine/registry/plugin_source.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/domain/repositories/discover_repository_interface.dart';
import 'package:atlas_app/discover/infrastructure/repositories/drift_discover_repository.dart';
import 'package:atlas_app/discover/infrastructure/services/discover_settings_store.dart';
import 'package:atlas_app/discover/infrastructure/services/reading_analytics_service.dart';
import 'package:atlas_app/discover/infrastructure/services/trending_service.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';

final discoverCacheServiceProvider = Provider<DiscoverCacheService>((ref) {
  final db = ref.watch(databaseProvider);
  return DiscoverCacheService(db: db);
});

final trendingServiceProvider = Provider<TrendingService>((ref) {
  final sources = ref.watch(searchableSourcesProvider);
  final pluginSources = sources.whereType<PluginSource>().toList();
  final cacheService = ref.watch(discoverCacheServiceProvider);
  return TrendingService(
    pluginSources: pluginSources,
    cacheService: cacheService,
  );
});

final discoverRepositoryProvider = Provider<DiscoverRepositoryInterface>((ref) {
  final db = ref.watch(databaseProvider);
  final trendingService = ref.watch(trendingServiceProvider);
  final analyticsService = ReadingAnalyticsService(db: db);
  return DriftDiscoverRepository(
    db: db,
    getSources: () => ref.watch(searchableSourcesProvider),
    trendingService: trendingService,
    analyticsService: analyticsService,
  );
});

final discoverDashboardProvider =
    FutureProvider<Result<DiscoverDashboardData>>((ref) async {
  final repo = ref.watch(discoverRepositoryProvider);
  return repo.getDashboardData();
});
