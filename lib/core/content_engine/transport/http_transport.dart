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
        botChallenge: _isBotChallenge(response),
        statusCode: response.statusCode,
        retryAfter: _retryAfter(response),
      );
    }
  }

  /// `Retry-After` in its integer-seconds form (the form every AI API uses).
  /// HTTP-date form and missing/unparseable values yield null — callers fall
  /// back to their own backoff schedule.
  static Duration? _retryAfter(http.Response response) {
    final raw = response.headers['retry-after'];
    if (raw == null) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
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
  /// with a 403 or 503 "Just a moment..." JS challenge, Turnstile, or block page.
  bool _isBotChallenge(http.Response response) {
    final status = response.statusCode;
    if (status != 403 && status != 503 && status != 429) return false;

    final cfMitigated = response.headers['cf-mitigated'] ?? '';
    if (cfMitigated.isNotEmpty && cfMitigated.toLowerCase().contains('challenge')) {
      return true;
    }

    final lowerBody = response.body.toLowerCase();
    if (lowerBody.contains('just a moment') ||
        lowerBody.contains('attention required') ||
        lowerBody.contains('challenge-platform') ||
        lowerBody.contains('cf_chl_opt') ||
        lowerBody.contains('cf-turnstile') ||
        lowerBody.contains('ddos-guard') ||
        lowerBody.contains('cf-chl-widget')) {
      return true;
    }

    final title = RegExp(
      r'<title>\s*([^<]*)',
      caseSensitive: false,
    ).firstMatch(response.body)?.group(1)?.trim();
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
      headers: {'Content-Type': 'application/json', ...?headers},
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
