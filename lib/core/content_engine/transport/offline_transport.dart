import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Serves only from a local cache, throws on cache miss. Used for offline
/// mode and for tests against recorded fixtures without live network calls.
class OfflineTransport implements Transport {
  OfflineTransport({
    Map<String, String>? html,
    Map<String, Object?>? json,
    Map<String, List<int>>? bytes,
    Map<String, String>? postHtml,
  })  : _html = {...?html},
        _json = {...?json},
        _bytes = {...?bytes},
        _postHtml = {...?postHtml};

  final Map<String, String> _html;
  final Map<String, Object?> _json;
  final Map<String, List<int>> _bytes;
  final Map<String, String> _postHtml;
  final Map<String, Object?> _postJson = {};

  void addHtml(String url, String body) => _html[url] = body;

  void addJson(String url, Object? value) => _json[url] = value;

  void addBytes(String url, List<int> value) => _bytes[url] = value;

  /// Registers a POST response keyed by `url` plus the exact form body, since
  /// two POSTs to the same endpoint (e.g. different `manga` ids on the same
  /// `admin-ajax.php`) can legitimately differ.
  void addPostHtml(
    String url,
    String body, {
    Map<String, String>? form,
  }) =>
      _postHtml['$url#${form ?? const {}}'] = body;

  /// Registers a JSON POST response keyed by `url` only. Unlike form POSTs the
  /// body isn't part of the key: recorded fixtures serve a single canned
  /// response per endpoint, which is all the offline/fixture use cases need.
  void addPostJson(String url, Object? value) => _postJson[url] = value;

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    final body = _html[url.toString()];
    if (body == null) {
      throw TransportException('Offline cache miss: $url');
    }
    return body;
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async {
    final body = _postHtml['${url.toString()}#${form ?? const {}}'];
    if (body == null) {
      throw TransportException('Offline cache miss (POST): $url');
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
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    final value = _postJson[url.toString()];
    if (value == null) {
      throw TransportException('Offline cache miss (JSON POST): $url');
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
