import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Direct HTTP client, no evasion behavior. Default for well-behaved
/// API-based plugins.
class HttpTransport implements Transport {
  HttpTransport({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> _ensureSuccess(http.Response response, Uri url) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TransportException(
        'GET $url failed with ${response.statusCode}',
      );
    }
    return Future.value();
  }

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    final response = await _client.get(url, headers: headers);
    await _ensureSuccess(response, url);
    return response.body;
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    final response = await _client.get(url, headers: headers);
    await _ensureSuccess(response, url);
    return jsonDecode(response.body);
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    final response = await _client.get(url, headers: headers);
    await _ensureSuccess(response, url);
    return response.bodyBytes;
  }
}
