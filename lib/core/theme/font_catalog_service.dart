import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/logging/logger.dart';

/// Categories returned by the Google Fonts metadata API.
enum FontCatalogCategory {
  serif('Serif'),
  sansSerif('Sans Serif'),
  display('Display'),
  handwriting('Handwriting'),
  monospace('Monospace');

  const FontCatalogCategory(this.label);
  final String label;

  static FontCatalogCategory? fromLabel(String label) =>
      FontCatalogCategory.values.cast<FontCatalogCategory?>().firstWhere(
            (c) => c!.label == label,
            orElse: () => null,
          );
}

class FontCatalogEntry {
  factory FontCatalogEntry.fromJson(Map<String, dynamic> json) {
    final category =
        FontCatalogCategory.fromLabel(json['category'] as String? ?? '') ??
        FontCatalogCategory.sansSerif;
    final weights = <int>[
      for (final key in (json['weights'] as List?) ?? [])
        if (key is int) key else int.tryParse('$key') ?? 0,
    ]..sort();
    return FontCatalogEntry(
      family: json['family'] as String? ?? '',
      category: category,
      weights: weights.isEmpty ? const [400] : weights,
      popularity: json['popularity'] as int? ?? 9999,
      trending: json['trending'] as int? ?? 9999,
    );
  }

  const FontCatalogEntry({
    required this.family,
    required this.category,
    required this.weights,
    required this.popularity,
    required this.trending,
  });

  final String family;
  final FontCatalogCategory category;
  final List<int> weights;
  final int popularity;
  final int trending;

  Map<String, dynamic> toJson() => {
    'family': family,
    'category': category.label,
    'weights': weights,
    'popularity': popularity,
    'trending': trending,
  };
}

/// Loads font catalog from bundled asset, refreshes from the keyless
/// Google Fonts metadata endpoint periodically, and caches the result.
class FontCatalogService {
  FontCatalogService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _metadataUrl =
      'https://fonts.google.com/metadata/fonts';
  static const _ttl = Duration(days: 7);

  /// Google's CSS API user-agent; old enough to get TTF instead of woff2.
  static const _legacyUserAgent =
      'Mozilla/5.0 (Linux; U; Android 4.1.1; en-us; Nexus S Build/JRO03D) '
      'AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30';

  List<FontCatalogEntry>? _cache;

  /// Returns the full catalog (bundled + refreshed if newer).
  Future<List<FontCatalogEntry>> catalog() async {
    if (_cache != null) return _cache!;

    final diskCached = await _loadDiskCache();
    if (diskCached != null && !_isStale(diskCached.timestamp)) {
      _cache = diskCached.entries;
      return _cache!;
    }

    // Try live refresh; fall back to disk or bundled.
    final refreshed = await _refreshCatalog();
    if (refreshed != null) {
      _cache = refreshed;
      return _cache!;
    }

    if (diskCached != null) {
      _cache = diskCached.entries;
      return _cache!;
    }

    _cache = await _loadBundledCatalog();
    return _cache!;
  }

  /// Filter by category, search by family name, and sort.
  List<FontCatalogEntry> filter(
    List<FontCatalogEntry> entries, {
    String? query,
    FontCatalogCategory? category,
    required FontSort sort,
  }) {
    var result = entries;

    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result.where((e) => e.family.toLowerCase().contains(q)).toList();
    }

    if (category != null) {
      result = result.where((e) => e.category == category).toList();
    }

    switch (sort) {
      case FontSort.popularity:
        result.sort((a, b) => a.popularity.compareTo(b.popularity));
      case FontSort.trending:
        result.sort((a, b) => a.trending.compareTo(b.trending));
      case FontSort.alphabetical:
        result.sort((a, b) => a.family.compareTo(b.family));
    }

    return result;
  }

  // -- Bundled catalog --

  Future<List<FontCatalogEntry>> _loadBundledCatalog() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/data/google_fonts_catalog.json',
      );
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) => FontCatalogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object catch (e, stack) {
      AppLogger.error('Failed to load bundled font catalog', e, stack);
      return [];
    }
  }

  // -- Live refresh from keyless metadata endpoint --

  Future<List<FontCatalogEntry>?> _refreshCatalog() async {
    try {
      final response = await _client
          .get(
            Uri.parse(_metadataUrl),
            headers: {'User-Agent': _legacyUserAgent},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = body['familyMetadataList'] as List? ?? [];
      final entries = list
          .map((e) => FontCatalogEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      // Persist to disk.
      await _saveDiskCache(entries);
      return entries;
    } on Object catch (_) {
      AppLogger.warning('Font catalog refresh failed');
      return null;
    }
  }

  // -- Disk cache (TTL) --

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    final fontsDir = Directory('${dir.path}${Platform.pathSeparator}fonts');
    if (!fontsDir.existsSync()) fontsDir.createSync(recursive: true);
    return File(
      '${fontsDir.path}${Platform.pathSeparator}catalog.json',
    );
  }

  Future<void> _saveDiskCache(List<FontCatalogEntry> entries) async {
    try {
      final file = await _cacheFile();
      final data = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'entries': [for (final e in entries) e.toJson()],
      };
      await file.writeAsString(jsonEncode(data));
    } on Object catch (_) {
      AppLogger.warning('Failed to save font catalog cache');
    }
  }

  Future<_DiskCache?> _loadDiskCache() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        data['timestamp'] as int,
      );
      final list = data['entries'] as List? ?? [];
      final entries = list
          .map((e) => FontCatalogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      return _DiskCache(timestamp: timestamp, entries: entries);
    } on Object catch (_) {
      AppLogger.warning('Failed to load font catalog cache');
      return null;
    }
  }

  bool _isStale(DateTime timestamp) =>
      DateTime.now().difference(timestamp) > _ttl;
}

enum FontSort { popularity, trending, alphabetical }

class _DiskCache {
  const _DiskCache({required this.timestamp, required this.entries});
  final DateTime timestamp;
  final List<FontCatalogEntry> entries;
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Single shared [FontCatalogService] instance for the app.
final fontCatalogServiceProvider = Provider<FontCatalogService>((ref) {
  return FontCatalogService();
});

/// Stable future for the full font catalog — survives rebuilds without
/// resetting to a loading spinner.
final fontCatalogProvider = FutureProvider<List<FontCatalogEntry>>((ref) {
  final service = ref.watch(fontCatalogServiceProvider);
  return service.catalog();
});
