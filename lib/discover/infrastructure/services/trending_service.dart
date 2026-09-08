import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/registry/plugin_source.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/infrastructure/services/discover_settings_store.dart';
import 'package:atlas_app/discover/infrastructure/services/opds_trending_service.dart';

/// Service that fetches trending/popular books from accessible plugin sources and OPDS feeds.
class TrendingService {
  TrendingService({
    required this.pluginSources,
    this.cacheService,
    OpdsTrendingService? opdsService,
  }) : _opdsService = opdsService;

  final List<PluginSource> pluginSources;
  final DiscoverCacheService? cacheService;
  final OpdsTrendingService? _opdsService;

  OpdsTrendingService get opdsService =>
      _opdsService ?? const OpdsTrendingService();

  /// Curated fallback titles for web novel plugins in case of offline/network issues.
  static const _webNovelCuratedDefaults = <String, List<TrendingBook>>{
    'royalroad': [
      TrendingBook(
        title: 'The Gift of Loot',
        sourceId: 'royalroad',
        sourceName: 'Royal Road',
        author: 'ActiveThreads',
        genre: 'LitRPG',
        popularity: '🔥 Hot',
        rating: '4.8',
        detailUrl: 'https://www.royalroad.com/fiction/trending',
        isOpds: false,
      ),
      TrendingBook(
        title: 'No One Truly Dies in My Dungeon',
        sourceId: 'royalroad',
        sourceName: 'Royal Road',
        author: 'LitRPG_Fan',
        genre: 'Dungeon',
        popularity: '🔥 Hot',
        rating: '4.9',
        detailUrl: 'https://www.royalroad.com/fiction/trending',
        isOpds: false,
      ),
      TrendingBook(
        title: 'Mother of Learning',
        sourceId: 'royalroad',
        sourceName: 'Royal Road',
        author: 'nobody103',
        genre: 'Progression',
        popularity: '🔥 Top Rated',
        rating: '4.9',
        detailUrl: 'https://www.royalroad.com/fiction/21220/mother-of-learning',
        isOpds: false,
      ),
      TrendingBook(
        title: 'The Primal Hunter',
        sourceId: 'royalroad',
        sourceName: 'Royal Road',
        author: 'Zogarth',
        genre: 'LitRPG',
        popularity: '🔥 Trending',
        rating: '4.7',
        detailUrl: 'https://www.royalroad.com/fiction/36049/the-primal-hunter',
        isOpds: false,
      ),
      TrendingBook(
        title: 'Defiance of the Fall',
        sourceId: 'royalroad',
        sourceName: 'Royal Road',
        author: 'TheFirstDefier',
        genre: 'Cultivation',
        popularity: '🔥 Popular',
        rating: '4.8',
        detailUrl: 'https://www.royalroad.com/fiction/24709/defiance-of-the-fall',
        isOpds: false,
      ),
    ],
    'readnovelfull': [
      TrendingBook(
        title: 'Archean Eon Art',
        sourceId: 'readnovelfull',
        sourceName: 'ReadNovelFull',
        author: 'I Eat Tomatoes',
        genre: 'Xianxia',
        popularity: '🔥 Hot',
        rating: '4.7',
        detailUrl: 'https://readnovelfull.com/novel-list/hot-novel',
        isOpds: false,
      ),
      TrendingBook(
        title: 'Dark Magus Returns',
        sourceId: 'readnovelfull',
        sourceName: 'ReadNovelFull',
        author: 'Shadow Knight',
        genre: 'Fantasy',
        popularity: '🔥 Popular',
        rating: '4.6',
        detailUrl: 'https://readnovelfull.com/novel-list/hot-novel',
        isOpds: false,
      ),
      TrendingBook(
        title: 'Lord of the Mysteries',
        sourceId: 'readnovelfull',
        sourceName: 'ReadNovelFull',
        author: 'Cuttlefish That Loves Diving',
        genre: 'Mystery',
        popularity: '🔥 #1 All Time',
        rating: '4.9',
        detailUrl: 'https://readnovelfull.com/novel-list/hot-novel',
        isOpds: false,
      ),
      TrendingBook(
        title: 'Shadow Slave',
        sourceId: 'readnovelfull',
        sourceName: 'ReadNovelFull',
        author: 'Guiltythree',
        genre: 'Fantasy',
        popularity: '🔥 Hot',
        rating: '4.9',
        detailUrl: 'https://readnovelfull.com/novel-list/hot-novel',
        isOpds: false,
      ),
    ],
    'noveldrama': [
      TrendingBook(
        title: 'The Luna Choosing Game',
        sourceId: 'noveldrama',
        sourceName: 'NovelDrama',
        author: 'Rina Young',
        genre: 'Werewolf',
        popularity: '🔥 Hot',
        rating: '4.5',
        detailUrl: 'https://noveldrama.com/sort/noveldrama-hot',
        isOpds: false,
      ),
      TrendingBook(
        title: 'Alpha King\'s Unclaimed Mate',
        sourceId: 'noveldrama',
        sourceName: 'NovelDrama',
        author: 'Elena Rose',
        genre: 'Romance',
        popularity: '🔥 Trending',
        rating: '4.6',
        detailUrl: 'https://noveldrama.com/sort/noveldrama-hot',
        isOpds: false,
      ),
      TrendingBook(
        title: 'Billionaire\'s Secret Heir',
        sourceId: 'noveldrama',
        sourceName: 'NovelDrama',
        author: 'Claire Vance',
        genre: 'Drama',
        popularity: '🔥 Top Rank',
        rating: '4.4',
        detailUrl: 'https://noveldrama.com/sort/noveldrama-hot',
        isOpds: false,
      ),
    ],
    'novel-hub': [
      TrendingBook(
        title: 'Invincible Connoisseur',
        sourceId: 'novel-hub',
        sourceName: 'Novel Hub',
        author: 'Martial King',
        genre: 'Action',
        popularity: '🔥 Trending',
        rating: '4.7',
        detailUrl: 'https://novelhub.com/ranking',
        isOpds: false,
      ),
      TrendingBook(
        title: 'Peerless Battle Spirit',
        sourceId: 'novel-hub',
        sourceName: 'Novel Hub',
        author: 'Supreme Spirit',
        genre: 'Xuanhuan',
        popularity: '🔥 Popular',
        rating: '4.6',
        detailUrl: 'https://novelhub.com/ranking',
        isOpds: false,
      ),
    ],
    'mvlempyr': [
      TrendingBook(
        title: 'Reborn as the Genius Son of the Richest Family',
        sourceId: 'mvlempyr',
        sourceName: 'MVLEMPYR',
        author: 'Broccoli',
        genre: 'Rebirth',
        popularity: '🔥 Top 1',
        rating: '4.8',
        detailUrl: 'https://mvlempyr.com/rankings',
        isOpds: false,
      ),
      TrendingBook(
        title: 'Global Reincarnation: I Can See Hints',
        sourceId: 'mvlempyr',
        sourceName: 'MVLEMPYR',
        author: 'Sky River',
        genre: 'Sci-fi',
        popularity: '🔥 Top 2',
        rating: '4.7',
        detailUrl: 'https://mvlempyr.com/rankings',
        isOpds: false,
      ),
    ],
    'wtrlab': [
      TrendingBook(
        title: 'Naruto: From Leaving Konoha',
        sourceId: 'wtrlab',
        sourceName: 'WTR-LAB',
        author: 'AI Translated',
        genre: 'Fanfic',
        popularity: '🔥 Daily Top',
        rating: '4.6',
        detailUrl: 'https://wtr-lab.com/en/ranking/daily',
        isOpds: false,
      ),
      TrendingBook(
        title: 'One Piece: Admiral of the Black Flag',
        sourceId: 'wtrlab',
        sourceName: 'WTR-LAB',
        author: 'Sea Pirate',
        genre: 'Fanfic',
        popularity: '🔥 Hot',
        rating: '4.7',
        detailUrl: 'https://wtr-lab.com/en/ranking/daily',
        isOpds: false,
      ),
    ],
  };

  /// Fetches trending books from all accessible plugins + OPDS feeds, utilizing local cache.
  Future<Map<String, List<TrendingBook>>> fetchAllTrending({
    bool forceRefresh = false,
  }) async {
    // 1. Try local cache unless force refresh
    if (!forceRefresh && cacheService != null) {
      final cached = await cacheService!.getCachedTrending();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    }

    final results = <String, List<TrendingBook>>{};

    // 2. Fetch OPDS feeds in parallel
    final opdsFuture = opdsService.fetchOpdsTrending().then((opdsMap) {
      results.addAll(opdsMap);
    }).catchError((e) {
      AppLogger.warning('OPDS trending fetch error: $e');
    });

    // 3. Fetch web novel plugin sources in parallel
    final pluginFutures = <Future<void>>[];
    for (final source in pluginSources) {
      final sourceId = source.manifest.id;
      if (!source.manifest.capabilities.contains(PluginCapability.trending)) {
        continue;
      }

      pluginFutures.add(
        _fetchTrendingForSource(source).then((books) {
          if (books.isNotEmpty) {
            results[sourceId] = books;
          }
        }).catchError((e) {
          AppLogger.warning('Failed to fetch trending from $sourceId: $e');
        }),
      );
    }

    await Future.wait([opdsFuture, ...pluginFutures]);

    // 4. Fill in curated defaults if any supported web novel plugin returned empty
    for (final entry in _webNovelCuratedDefaults.entries) {
      if (!results.containsKey(entry.key) || results[entry.key]!.isEmpty) {
        results[entry.key] = entry.value;
      }
    }

    // 5. Persist to storage cache with user's configured TTL
    if (cacheService != null) {
      final ttlHours = await DiscoverSettingsStore.getIntervalHours();
      await cacheService!.saveCachedTrending(results, ttlHours);
    }

    return results;
  }

  Future<List<TrendingBook>> _fetchTrendingForSource(
    PluginSource source,
  ) async {
    try {
      final trendingResults = await source.getTrending();
      if (trendingResults.isEmpty) {
        return _webNovelCuratedDefaults[source.manifest.id] ?? const [];
      }
      return trendingResults.map((r) {
        return TrendingBook(
          title: r.title,
          sourceId: source.manifest.id,
          sourceName: source.manifest.sourceName,
          author: r.author,
          coverUrl: r.coverUrl,
          detailUrl: r.url,
          rating: r.rating,
          popularity: r.popularity ?? '🔥 Trending',
          genre: r.genre,
          description: r.description,
          fetchedAt: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      AppLogger.warning(
        'Error fetching trending from ${source.manifest.id}: $e',
      );
      return _webNovelCuratedDefaults[source.manifest.id] ?? const [];
    }
  }
}
