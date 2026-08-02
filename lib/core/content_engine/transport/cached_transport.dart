import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Read-through cache keyed by URL, used for repeated fetches within a single
/// pipeline run (e.g. paginated chapter lists) to avoid redundant network
/// calls. Instance-scoped: construct per run, discard after.
class CachedTransport implements Transport {
  CachedTransport({required Transport inner}) : _inner = inner;

  final Transport _inner;
  final Map<String, String> _html = {};
  final Map<String, Object?> _json = {};
  final Map<String, List<int>> _bytes = {};

  String _key(Uri url, Map<String, String>? headers) =>
      '$url#${headers ?? const {}}';

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    final key = _key(url, headers);
    final cached = _html[key];
    if (cached != null) return cached;
    final value = await _inner.fetchHtml(url, headers: headers);
    _html[key] = value;
    return value;
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    final key = _key(url, headers);
    final cached = _json[key];
    if (cached != null) return cached;
    final value = await _inner.fetchJson(url, headers: headers);
    _json[key] = value;
    return value;
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    final key = _key(url, headers);
    final cached = _bytes[key];
    if (cached != null) return cached;
    final value = await _inner.fetchBytes(url, headers: headers);
    _bytes[key] = value;
    return value;
  }
}
