import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
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
  // Also watch the async plugin discovery — when it warms up from `loading`
  // to `data`, this provider rebuilds so web-novel trending stops returning
  // the empty stale snapshot. Without this the dashboard is stuck on the
  // `_TrendingSkeleton` for web novels forever (stale-then-refresh with
  // snapshot taken before plugins existed).
  final pluginFuture = ref.watch(pluginSourcesProvider);
  final pluginFromFuture = pluginFuture.valueOrNull ?? const <PluginSource>[];
  final merged = <PluginSource>[];
  final seenIds = <String>{};
  for (final s in [...sources.whereType<PluginSource>(), ...pluginFromFuture]) {
    if (seenIds.add(s.manifest.id)) merged.add(s);
  }
  final cacheService = ref.watch(discoverCacheServiceProvider);
  return TrendingService(pluginSources: merged, cacheService: cacheService);
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

final discoverDashboardProvider = FutureProvider<Result<DiscoverDashboardData>>((ref) async {
  // Keep splash prewarm alive across navigation — go + per-section shell.
  ref.keepAlive();
  final repo = ref.watch(discoverRepositoryProvider);
  // Wire SWR push: background trending revalidation invalidates dashboard.
  // Debounce and diff-guard to avoid the stale-expired → background →
  // invalidate → stale-expired loop seen in section-level shimmer.
  if (repo is DriftDiscoverRepository) {
    DateTime? lastInvalidateAt;
    Map<String, int>? lastFreshKeys;
    repo.onTrendingBackgroundUpdate = (fresh) {
      final now = DateTime.now();
      if (lastInvalidateAt != null &&
          now.difference(lastInvalidateAt!) < const Duration(seconds: 5)) {
        return;
      }
      final keys = fresh.map((k, v) => MapEntry(k, v.length));
      if (lastFreshKeys != null &&
          lastFreshKeys!.length == keys.length &&
          lastFreshKeys!.entries.every((e) => keys[e.key] == e.value)) {
        return;
      }
      lastFreshKeys = keys;
      lastInvalidateAt = now;
      // ignore: unawaited_futures
      Future.microtask(() => ref.invalidateSelf());
    };
  }
  return repo.getDashboardData();
}, dependencies: [discoverRepositoryProvider, trendingServiceProvider]);
