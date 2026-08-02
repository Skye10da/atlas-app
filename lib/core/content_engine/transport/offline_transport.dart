import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Serves only from a local cache, throws on cache miss. Used for offline
/// mode and for tests against recorded fixtures without live network calls.
class OfflineTransport implements Transport {
  OfflineTransport({
    Map<String, String>? html,
    Map<String, Object?>? json,
    Map<String, List<int>>? bytes,
  })  : _html = {...?html},
        _json = {...?json},
        _bytes = {...?bytes};

  final Map<String, String> _html;
  final Map<String, Object?> _json;
  final Map<String, List<int>> _bytes;

  void addHtml(String url, String body) => _html[url] = body;

  void addJson(String url, Object? value) => _json[url] = value;

  void addBytes(String url, List<int> value) => _bytes[url] = value;

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    final body = _html[url.toString()];
    if (body == null) {
      throw TransportException('Offline cache miss: $url');
    }
    return body;
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    final value = _json[url.toString()];
    if (value == null) {
      throw TransportException('Offline cache miss: $url');
    }
    return value;
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    final value = _bytes[url.toString()];
    if (value == null) {
      throw TransportException('Offline cache miss: $url');
    }
    return value;
  }
}
