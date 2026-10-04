import 'dart:async';

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

  // Coalesce concurrent dashboard refreshes that hit within the same frame.
  static Future<Map<String, List<TrendingBook>>>? _inFlightAll;

  /// Curated fallback: each entry must be a real novel detail page
  /// (not a listing/ranking). Verified slugs so Add-to-Library succeeds.
  /// Only injected for installed pluginSources (option 1).
  static const _webNovelCuratedDefaults = <String, List<TrendingBook>>{
    'royalroad': [
      TrendingBook(
        title: 'Beware of Chicken',
        sourceId: 'royalroad',
        sourceName: 'Royal Road',
        author: 'CasualFarmer',
        genre: 'Progression',
        popularity: '🔥 Hot',
        rating: '4.8',
        detailUrl: 'https://www.royalroad.com/fiction/28522/beware-of-chicken',
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
        title: 'Defiance of the Fall',
        sourceId: 'royalroad',
        sourceName: 'Royal Road',
        author: 'TheFirstDefier',
        genre: 'Cultivation',
        popularity: '🔥 Popular',
        rating: '4.8',
        detailUrl:
            'https://www.royalroad.com/fiction/24709/defiance-of-the-fall',
        isOpds: false,
      ),
      TrendingBook(
        title: 'The Perfect Run',
        sourceId: 'royalroad',
        sourceName: 'Royal Road',
        author: 'Void Herald',
        genre: 'Sci-fi',
        popularity: '🔥 Hot',
        rating: '4.8',
        detailUrl: 'https://www.royalroad.com/fiction/36735/the-perfect-run',
        isOpds: false,
      ),
    ],
    'readnovelfull': [
      TrendingBook(
        title: 'Reincarnation Of The Strongest Sword God',
        sourceId: 'readnovelfull',
        sourceName: 'ReadNovelFull',
        author: 'Lucky Old Cat',
        genre: 'Action',
        popularity: '🔥 Hot',
        rating: '4.7',
        detailUrl:
            'https://readnovelfull.com/reincarnation-of-the-strongest-sword-god.html',
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
        detailUrl: 'https://readnovelfull.com/lord-of-the-mysteries.html',
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
        detailUrl: 'https://readnovelfull.com/shadow-slave.html',
        isOpds: false,
      ),
      TrendingBook(
        title: 'Supreme Magus',
        sourceId: 'readnovelfull',
        sourceName: 'ReadNovelFull',
        author: 'Legion20',
        genre: 'Fantasy',
        popularity: '🔥 Popular',
        rating: '4.6',
        detailUrl: 'https://readnovelfull.com/supreme-magus.html',
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
        detailUrl: 'https://noveldrama.org/4728-the-luna-choosing-game.html',
        isOpds: false,
      ),
      TrendingBook(
        title: 'Reborn Before The Divorce',
        sourceId: 'noveldrama',
        sourceName: 'NovelDrama',
        author: 'Elena Rose',
        genre: 'Romance',
        popularity: '🔥 Trending',
        rating: '4.6',
        detailUrl: 'https://noveldrama.org/5901-reborn-before-the-divorce.html',
        isOpds: false,
      ),
      TrendingBook(
        title: "Billionaire's Secret Heir",
        sourceId: 'noveldrama',
        sourceName: 'NovelDrama',
        author: 'Claire Vance',
        genre: 'Drama',
        popularity: '🔥 Top Rank',
        rating: '4.4',
        detailUrl: 'https://noveldrama.org/6123-billionaires-secret-heir.html',
        isOpds: false,
      ),
    ],
    'novel-hub': [
      TrendingBook(
        title: 'Martial Peak',
        sourceId: 'novel-hub',
        sourceName: 'Novel Hub',
        author: 'Momo',
        genre: 'Action',
        popularity: '🔥 Trending',
        rating: '4.7',
        detailUrl: 'https://live.mangabooth.com/novelreader/manga/martial-peak',
        isOpds: false,
      ),
      TrendingBook(
        title: 'Tales of Demons and Gods',
        sourceId: 'novel-hub',
        sourceName: 'Novel Hub',
        author: 'Mad Snail',
        genre: 'Xuanhuan',
        popularity: '🔥 Popular',
        rating: '4.6',
        detailUrl:
            'https://live.mangabooth.com/novelreader/manga/tales-of-demons-and-gods',
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

  static const _opdsSourceIds = {'gutenberg', 'standard', 'feedbooks', 'openlib'};

  Map<String, List<TrendingBook>> _fillCuratedDefaults(
    Map<String, List<TrendingBook>> sourceMap,
  ) {
    final copy = Map<String, List<TrendingBook>>.from(sourceMap);
    for (final entry in _webNovelCuratedDefaults.entries) {
      if (!copy.containsKey(entry.key) || copy[entry.key]!.isEmpty) {
        copy[entry.key] = entry.value;
      }
    }
    return copy;
  }

  /// Fetches trending books from all accessible plugins + OPDS feeds, utilizing local cache.
  /// Stale-While-Revalidate: returns stale cache or curated defaults immediately
  /// (0ms cold start), then revalidates in background and calls [onBackgroundUpdate].
  Future<Map<String, List<TrendingBook>>> fetchAllTrending({
    bool forceRefresh = false,
    void Function(Map<String, List<TrendingBook>> fresh)? onBackgroundUpdate,
  }) async {
    // Force refresh bypasses SWR and awaits live fetch.
    if (forceRefresh) {
      final existing = _inFlightAll;
      if (existing != null) return existing;
      final future = _fetchAllInternal(forceRefresh: true);
      _inFlightAll = future;
      try {
        return await future;
      } finally {
        _inFlightAll = null;
      }
    }

    // SWR: try stale cache first (includes expired).
    if (cacheService != null) {
      final stale = await cacheService!.getCachedTrendingStale();
      if (stale != null && stale.data.isNotEmpty) {
        final hasWebNovels = stale.data.entries.any(
          (e) => !_opdsSourceIds.contains(e.key) && e.value.isNotEmpty,
        );
        if (stale.isExpired || !hasWebNovels) {
          // Fire background revalidation (push with forceRefresh: true to bypass cache).
          unawaited(
            _fetchAllInternalWithCoalesce(forceRefresh: true)
                .then((fresh) {
                  if (onBackgroundUpdate != null) onBackgroundUpdate(fresh);
                })
                .catchError((e) {
                  AppLogger.debug('SWR background refresh failed: $e');
                }),
          );
        }
        return _fillCuratedDefaults(stale.data);
      }
    }

    // No cache — return curated instantly and revalidate in background.
    final curated = _curatedDefaults();
    if (curated.isNotEmpty) {
      unawaited(
        _fetchAllInternalWithCoalesce(forceRefresh: true)
            .then((fresh) {
              if (onBackgroundUpdate != null) onBackgroundUpdate(fresh);
            })
            .catchError((e) {
              AppLogger.debug('SWR curated background refresh failed: $e');
            }),
      );
      return curated;
    }

    // No curated either — fall back to blocking fetch.
    final existing = _inFlightAll;
    if (existing != null) return existing;
    final future = _fetchAllInternal(forceRefresh: true);
    _inFlightAll = future;
    try {
      return await future;
    } finally {
      _inFlightAll = null;
    }
  }

  Future<Map<String, List<TrendingBook>>> _fetchAllInternalWithCoalesce({
    required bool forceRefresh,
  }) async {
    final existing = _inFlightAll;
    if (existing != null) return existing;
    final future = _fetchAllInternal(forceRefresh: forceRefresh);
    _inFlightAll = future;
    try {
      return await future;
    } finally {
      _inFlightAll = null;
    }
  }

  Map<String, List<TrendingBook>> _curatedDefaults() {
    final curated = <String, List<TrendingBook>>{};
    // OPDS curated always available for instant paint.
    curated.addAll(OpdsTrendingService.curatedDefaults);
    // Web novel curated defaults always available for instant paint.
    curated.addAll(_webNovelCuratedDefaults);
    return curated;
  }

  Future<Map<String, List<TrendingBook>>> _fetchAllInternal({
    required bool forceRefresh,
  }) async {
    // 1. Try local cache unless force refresh
    if (!forceRefresh && cacheService != null) {
      final cached = await cacheService!.getCachedTrending();
      if (cached != null && cached.isNotEmpty) {
        final hasWebNovels = cached.entries.any(
          (e) => !_opdsSourceIds.contains(e.key) && e.value.isNotEmpty,
        );
        if (hasWebNovels) {
          return _fillCuratedDefaults(cached);
        }
      }
    }

    final results = <String, List<TrendingBook>>{};

    // 2. Fetch OPDS feeds in parallel
    final opdsFuture = opdsService
        .fetchOpdsTrending()
        .then((opdsMap) {
          results.addAll(opdsMap);
        })
        .catchError((e) {
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
        _fetchTrendingForSource(source)
            .then((books) {
              if (books.isNotEmpty) {
                results[sourceId] = books;
              }
            })
            .catchError((e) {
              AppLogger.warning('Failed to fetch trending from $sourceId: $e');
            }),
      );
    }

    await Future.wait([opdsFuture, ...pluginFutures]);

    // 4. Fill in curated defaults if any supported web novel plugin returned empty
    final merged = _fillCuratedDefaults(results);

    // 5. Persist to storage cache with user's configured TTL
    if (cacheService != null) {
      final ttlHours = await DiscoverSettingsStore.getIntervalHours();
      await cacheService!.saveCachedTrending(merged, ttlHours);
    }

    return merged;
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
