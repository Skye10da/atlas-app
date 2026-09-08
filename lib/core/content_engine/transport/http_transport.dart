import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:atlas_app/core/content_engine/transport/challenge_detector.dart';
import 'package:atlas_app/core/content_engine/transport/native_client_factory.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Direct HTTP client, with platform-native TLS where supported (Cronet on Android,
/// Cupertino on iOS/macOS). Default for well-behaved API-based plugins.
class HttpTransport implements Transport {
  HttpTransport({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    this.transientRetryDelay = const Duration(milliseconds: 800),
    Future<void> Function(Duration)? sleep,
  })  : _client = client ?? createNativeClient(),
        _sleep = sleep ?? Future<void>.delayed;

  final http.Client _client;

  /// Per-request timeout for the underlying `http.Client` call. Cloudflare
  /// origins that close a keep-alive socket otherwise hang indefinitely.
  final Duration timeout;

  /// Delay before the single retry for `Connection closed before full header`.
  final Duration transientRetryDelay;

  final Future<void> Function(Duration) _sleep;

  void _ensureSuccess(http.Response response, Uri url) {
    final isChallenge = _isChallengeResponseSafe(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TransportException(
        _describeFailure(response, url, isChallenge: isChallenge),
        sessionExpired: _isSessionExpired(response, isChallenge: isChallenge),
        botChallenge: isChallenge,
        statusCode: response.statusCode,
        retryAfter: _retryAfter(response),
      );
    }
    // freewebnovel.com returns 200 with a full Cloudflare challenge body
    // (`Just a moment...` + `challenge-platform`). Without this, callers would
    // treat the interstitial as real HTML. Detect it even on 200 so the
    // WebView fallback can silently solve it headlessly.
    if (isChallenge) {
      throw TransportException(
        _describeFailure(response, url, isChallenge: true),
        sessionExpired: false,
        botChallenge: true,
        statusCode: response.statusCode,
        retryAfter: _retryAfter(response),
      );
    }
  }

  bool _isChallengeResponseSafe(http.Response response) {
    try {
      return ChallengeDetector.isChallengeResponse(response);
    } on FormatException {
      // Response bytes were not valid UTF-8 (e.g. Brotli without decoder) —
      // treat as not-a-challenge so we surface the decode error instead.
      return false;
    }
  }

  String _decodeBody(http.Response response) {
    // `response.body` eagerly UTF-8 decodes `bodyBytes` and throws
    // `FormatException: Invalid UTF-8 byte (at offset 1)` when the origin
    // returns `br` without us advertising it correctly or when the chapter
    // contains non-UTF8 bytes. Use `allowMalformed` so the chapter still
    // loads (replacement chars) instead of crashing the provider.
    try {
      return response.body;
    } on FormatException {
      try {
        return utf8.decode(response.bodyBytes, allowMalformed: true);
      } catch (_) {
        // Last resort — latin1 never throws.
        return latin1.decode(response.bodyBytes);
      }
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

  String _describeFailure(
    http.Response response,
    Uri url, {
    required bool isChallenge,
  }) {
    if (isChallenge) {
      return '${url.host} blocked this request with a bot-check challenge '
          '(Cloudflare). That site does not allow automated imports, so Atlas '
          'cannot fetch it with a plain HTTP client — try another source.';
    }
    return 'GET $url failed with ${response.statusCode}';
  }

  /// An auth/session wall: HTTP 401/403 that is *not* Cloudflare's bot check
  /// (which [_describeFailure] already names). A site answers 401/403 when the
  /// replayed session cookie is stale or revoked — the signal that drives the
  /// quick re-verify flow.
  bool _isSessionExpired(
    http.Response response, {
    required bool isChallenge,
  }) {
    if (response.statusCode != 401 && response.statusCode != 403) return false;
    return !isChallenge;
  }

  Future<http.Response> _getWithRetry(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    // Force `Connection: close` to avoid reusing a keep-alive socket that
    // Cloudflare/frontends have already closed (the classic
    // "Connection closed before full header" race). Slightly less efficient
    // but far more reliable for freewebnovel and similar CF sites, especially
    // on Windows `IOClient` (BoringSSL) where the race is more frequent.
    final effectiveHeaders = {
      ...?headers,
      if (headers == null || !headers.keys.any((k) => k.toLowerCase() == 'connection'))
        'Connection': 'close',
    };
    return _withTransientRetry(
      () => _client.get(url, headers: effectiveHeaders).timeout(timeout),
    );
  }

  Future<http.Response> _postWithRetry(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final effectiveHeaders = {
      ...?headers,
      if (headers == null || !headers.keys.any((k) => k.toLowerCase() == 'connection'))
        'Connection': 'close',
    };
    return _withTransientRetry(
      () => _client
          .post(url, headers: effectiveHeaders, body: body, encoding: encoding)
          .timeout(timeout),
    );
  }

  Future<http.Response> _withTransientRetry(
    Future<http.Response> Function() run,
  ) async {
    try {
      return await run();
    } on TimeoutException {
      // Cloudflare origins + keep-alive race often manifest as a hang
      // until the 15s timeout. Retry once on a fresh socket before
      // surfacing as transient — matches the connection-closed retry.
      await _sleep(transientRetryDelay);
      try {
        return await run().timeout(timeout);
      } on TimeoutException catch (retryTimeout) {
        throw TransportException(
          'Request timed out: $retryTimeout',
          cause: retryTimeout,
          isTransient: true,
        );
      } on SocketException catch (retrySocket) {
        throw TransportException(
          'Connection failed on timeout retry: $retrySocket',
          cause: retrySocket,
          isTransient: true,
        );
      } on HttpException catch (retryHttp) {
        throw TransportException(
          'HTTP error on timeout retry: $retryHttp',
          cause: retryHttp,
          isTransient: true,
        );
      } on HandshakeException catch (retryHs) {
        throw TransportException(
          'TLS handshake failed on timeout retry: $retryHs',
          cause: retryHs,
          isTransient: true,
        );
      } on http.ClientException catch (retryClient) {
        throw TransportException(
          'Connection failed on timeout retry: ${retryClient.message}',
          cause: retryClient,
          isTransient: true,
        );
      }
    } on http.ClientException catch (e) {
      if (_isConnectionClosedException(e)) {
        await _sleep(transientRetryDelay);
        try {
          return await run().timeout(timeout);
        } on TimeoutException catch (retryTimeout) {
          throw TransportException(
            'Request timed out on retry: $retryTimeout',
            cause: retryTimeout,
            isTransient: true,
          );
        } on http.ClientException catch (retryClient) {
          throw TransportException(
            'Connection closed before full header was received: $retryClient',
            cause: retryClient,
            isTransient: true,
          );
        } on SocketException catch (retrySocket) {
          throw TransportException(
            'Connection closed before full header was received: $retrySocket',
            cause: retrySocket,
            isTransient: true,
          );
        } on HttpException catch (retryHttp) {
          throw TransportException(
            'Connection closed before full header was received: $retryHttp',
            cause: retryHttp,
            isTransient: true,
          );
        }
      }
      throw TransportException(
        'Connection failed: ${e.message}',
        cause: e,
        isTransient: true,
      );
    } on SocketException {
      await _sleep(transientRetryDelay);
      try {
        return await run().timeout(timeout);
      } on SocketException catch (retry) {
        throw TransportException(
          'Connection failed: $retry',
          cause: retry,
          isTransient: true,
        );
      } on HttpException catch (retryHttp) {
        throw TransportException(
          'HTTP error on socket retry: $retryHttp',
          cause: retryHttp,
          isTransient: true,
        );
      } on HandshakeException catch (retryHs) {
        throw TransportException(
          'TLS handshake failed on socket retry: $retryHs',
          cause: retryHs,
          isTransient: true,
        );
      } on TimeoutException catch (retryTimeout) {
        throw TransportException(
          'Request timed out on socket retry: $retryTimeout',
          cause: retryTimeout,
          isTransient: true,
        );
      } on http.ClientException catch (retryClient) {
        throw TransportException(
          'Connection failed on socket retry: ${retryClient.message}',
          cause: retryClient,
          isTransient: true,
        );
      }
    } on HttpException {
      await _sleep(transientRetryDelay);
      try {
        return await run().timeout(timeout);
      } on HttpException catch (retryHttp) {
        throw TransportException(
          'HTTP error: $retryHttp',
          cause: retryHttp,
          isTransient: true,
        );
      } on SocketException catch (retrySocket) {
        throw TransportException(
          'Connection failed on http retry: $retrySocket',
          cause: retrySocket,
          isTransient: true,
        );
      } on HandshakeException catch (retryHs) {
        throw TransportException(
          'TLS handshake failed on http retry: $retryHs',
          cause: retryHs,
          isTransient: true,
        );
      } on TimeoutException catch (retryTimeout) {
        throw TransportException(
          'Request timed out on http retry: $retryTimeout',
          cause: retryTimeout,
          isTransient: true,
        );
      } on http.ClientException catch (retryClient) {
        throw TransportException(
          'Connection failed on http retry: ${retryClient.message}',
          cause: retryClient,
          isTransient: true,
        );
      }
    } on HandshakeException catch (_) {
      // Windows BoringSSL + Cloudflare often terminates the first handshake
      // (TLS fingerprint / keep-alive race). Retry once on a fresh socket
      // before surfacing as transient — mirrors timeout/connection-closed.
      await _sleep(transientRetryDelay);
      try {
        return await run().timeout(timeout);
      } on HandshakeException catch (retryHs) {
        throw TransportException(
          'TLS handshake failed: $retryHs',
          cause: retryHs,
          isTransient: true,
        );
      } on TimeoutException catch (retryTimeout) {
        throw TransportException(
          'Request timed out on handshake retry: $retryTimeout',
          cause: retryTimeout,
          isTransient: true,
        );
      } on SocketException catch (retrySocket) {
        throw TransportException(
          'Connection failed on handshake retry: $retrySocket',
          cause: retrySocket,
          isTransient: true,
        );
      } on HttpException catch (retryHttp) {
        throw TransportException(
          'HTTP error on handshake retry: $retryHttp',
          cause: retryHttp,
          isTransient: true,
        );
      } on http.ClientException catch (retryClient) {
        throw TransportException(
          'Connection failed on handshake retry: ${retryClient.message}',
          cause: retryClient,
          isTransient: true,
        );
      }
    }
  }

  static bool _isConnectionClosedException(http.ClientException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('connection closed before full header') ||
        msg.contains('connection closed') ||
        msg.contains('connection reset by peer');
  }

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    final response = await _getWithRetry(url, headers: headers);
    _ensureSuccess(response, url);
    return _decodeBody(response);
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async {
    final response = await _postWithRetry(url, headers: headers, body: form);
    _ensureSuccess(response, url);
    return _decodeBody(response);
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    final response = await _getWithRetry(url, headers: headers);
    _ensureSuccess(response, url);
    return jsonDecode(_decodeBody(response));
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    final response = await _postWithRetry(
      url,
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonBody == null ? null : jsonEncode(jsonBody),
    );
    _ensureSuccess(response, url);
    return jsonDecode(_decodeBody(response));
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    final response = await _getWithRetry(url, headers: headers);
    _ensureSuccess(response, url);
    return response.bodyBytes;
  }
}
