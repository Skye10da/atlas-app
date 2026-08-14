import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Direct HTTP client, no evasion behavior. Default for well-behaved
/// API-based plugins.
class HttpTransport implements Transport {
  HttpTransport({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  void _ensureSuccess(http.Response response, Uri url) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TransportException(
        _describeFailure(response, url),
        sessionExpired: _isSessionExpired(response),
      );
    }
  }

  String _describeFailure(http.Response response, Uri url) {
    if (_isBotChallenge(response)) {
      return '${url.host} blocked this request with a bot-check challenge '
          '(Cloudflare). That site does not allow automated imports, so Atlas '
          'cannot fetch it with a plain HTTP client — try another source.';
    }
    return 'GET $url failed with ${response.statusCode}';
  }

  /// Cloudflare bot protection answers clients it fingerprints as non-browser
  /// (Dart's own HTTP stack is one) with a 403 "Just a moment..." JS challenge
  /// or an "Attention Required!" block page. Prefer the response headers, which
  /// are more reliable than sniffing the body, and fall back to the title only
  /// for otherwise-ambiguous 403s.
  bool _isBotChallenge(http.Response response) {
    final server = response.headers['server'] ?? '';
    if (server.toLowerCase().contains('cloudflare')) return true;
    if ((response.headers['cf-mitigated'] ?? '').isNotEmpty) return true;
    if (response.statusCode != 403) return false;
    final title = RegExp(r'<title>\s*([^<]*)', caseSensitive: false)
        .firstMatch(response.body)
        ?.group(1)
        ?.trim();
    return title == 'Just a moment...' ||
        title == 'Attention Required! | Cloudflare';
  }

  /// An auth/session wall: HTTP 401/403 that is *not* Cloudflare's bot check
  /// (which [_describeFailure] already names). A site answers 401/403 when the
  /// replayed session cookie is stale or revoked — the signal that drives the
  /// quick re-verify flow.
  bool _isSessionExpired(http.Response response) {
    if (response.statusCode != 401 && response.statusCode != 403) return false;
    return !_isBotChallenge(response);
  }

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    final response = await _client.get(url, headers: headers);
    _ensureSuccess(response, url);
    return response.body;
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async {
    final response = await _client.post(url, headers: headers, body: form);
    _ensureSuccess(response, url);
    return response.body;
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    final response = await _client.get(url, headers: headers);
    _ensureSuccess(response, url);
    return jsonDecode(response.body);
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: jsonBody == null ? null : jsonEncode(jsonBody),
    );
    _ensureSuccess(response, url);
    return jsonDecode(response.body);
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    final response = await _client.get(url, headers: headers);
    _ensureSuccess(response, url);
    return response.bodyBytes;
  }
}
