/// Fetches and caches the CDN voice-pack catalog (NTD §3.5).
///
/// Offline-tolerant by design: the last successful catalog body is cached
/// in shared_preferences and served when the network is unreachable or the
/// response is unusable. A newer-than-understood schema keeps the cache too
/// (forward compatibility), never an empty gallery dead end.
library;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/reader/speech/packs/voice_pack_manifest.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_downloader.dart';

class VoicePackCatalogEndpoints {
  const VoicePackCatalogEndpoints({
    required this.baseUrl,
    required this.catalogPath,
  });

  /// CDN root, e.g. `https://cdn.atlasapp.sk/atlas_tts`.
  final String baseUrl;

  /// Relative path of the catalog document under [baseUrl].
  final String catalogPath;

  Uri get catalogUri => Uri.parse('$baseUrl/$catalogPath');
  VoicePackLocation toLocation() =>
      VoicePackLocation(baseUrl: '$baseUrl/voices');
}

class VoicePackCatalogService {
  VoicePackCatalogService({
    required this.endpoints,
    http.Client? client,
    SharedPreferences? prefs,
  }) : _client = client ?? http.Client(),
       _prefs = prefs;

  static const _cacheKey = 'voice_pack_catalog_cache';

  final VoicePackCatalogEndpoints endpoints;
  final http.Client _client;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Cache-first read for instant UI, falling back to the network on a
  /// cold start. Returns null when neither is available (first run,
  /// offline).
  Future<VoicePackCatalog?> load() async {
    final prefs = await _ensurePrefs();
    final cached = _decode(prefs.getString(_cacheKey));
    if (cached != null) return cached;
    return refreshNow();
  }

  /// Live fetch (used by the gallery's refresh affordance and the cold
  /// start above); on success it also updates the offline cache.
  Future<VoicePackCatalog?> refreshNow() async {
    final prefs = await _ensurePrefs();
    try {
      final response = await _client
          .get(endpoints.catalogUri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final catalog = VoicePackCatalog.tryDecode(response.body);
        if (catalog != null) {
          await prefs.setString(_cacheKey, response.body);
          return catalog;
        }
      }
    } catch (_) {}
    return _decode(prefs.getString(_cacheKey));
  }

  VoicePackCatalog? _decode(String? raw) {
    if (raw == null) return null;
    return VoicePackCatalog.tryDecode(raw);
  }
}
