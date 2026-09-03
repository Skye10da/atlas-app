import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:atlas_app/core/content_engine/registry/plugin_source.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/domain/repositories/discover_repository_interface.dart';
import 'package:atlas_app/discover/infrastructure/repositories/drift_discover_repository.dart';
import 'package:atlas_app/discover/infrastructure/services/trending_service.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';

final trendingServiceProvider = Provider<TrendingService>((ref) {
  final sources = ref.watch(searchableSourcesProvider);
  // Filter to PluginSource instances that support trending
  final pluginSources = sources.whereType<PluginSource>().toList();
  return TrendingService(pluginSources: pluginSources);
});

final discoverRepositoryProvider = Provider<DiscoverRepositoryInterface>((ref) {
  final db = ref.watch(databaseProvider);
  final trendingService = ref.watch(trendingServiceProvider);
  return DriftDiscoverRepository(
    db: db,
    getSources: () => ref.watch(searchableSourcesProvider),
    trendingService: trendingService,
  );
});

final discoverDashboardProvider =
    FutureProvider<Result<DiscoverDashboardData>>((ref) async {
  final repo = ref.watch(discoverRepositoryProvider);
  return repo.getDashboardData();
});
