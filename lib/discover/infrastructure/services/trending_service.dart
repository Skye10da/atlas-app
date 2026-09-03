import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/registry/plugin_source.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';

/// Service that fetches trending/popular books from accessible plugin sources.
class TrendingService {
  TrendingService({required this.pluginSources});

  final List<PluginSource> pluginSources;

  /// Plugins without Cloudflare that have trending pages.
  static const _trendingPlugins = {
    'royalroad',
    'readnovelfull',
    'noveldrama',
    'novel-hub',
    'mvlempyr',
    'wtrlab',
  };

  /// Fetches trending books from all accessible plugins.
  /// Returns a map of sourceId -> list of trending books.
  Future<Map<String, List<TrendingBook>>> fetchAllTrending() async {
    final results = <String, List<TrendingBook>>{};

    final futures = <Future<void>>[];

    for (final source in pluginSources) {
      final sourceId = source.manifest.id;
      if (!_trendingPlugins.contains(sourceId)) continue;
      if (!source.manifest.capabilities.contains(PluginCapability.trending)) {
        continue;
      }

      futures.add(
        _fetchTrendingForSource(source).then((books) {
          if (books.isNotEmpty) {
            results[sourceId] = books;
          }
        }).catchError((e) {
          AppLogger.warning('Failed to fetch trending from $sourceId: $e');
        }),
      );
    }

    await Future.wait(futures);
    return results;
  }

  /// Fetches trending books from a single plugin source.
  Future<List<TrendingBook>> _fetchTrendingForSource(
    PluginSource source,
  ) async {
    try {
      final trendingResults = await source.getTrending();
      return trendingResults.map((r) {
        return TrendingBook(
          title: r.title,
          sourceId: source.manifest.id,
          sourceName: source.manifest.sourceName,
          author: r.author,
          coverUrl: r.coverUrl,
          detailUrl: r.url,
          rating: r.rating,
          popularity: r.popularity,
          genre: r.genre,
          description: r.description,
          fetchedAt: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      AppLogger.warning(
        'Error fetching trending from ${source.manifest.id}: $e',
      );
      return const [];
    }
  }
}
