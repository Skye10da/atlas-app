import 'dart:convert';

import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/content_engine/transport/webview_fetch_result.dart';
import 'package:atlas_app/core/session/session_refresh_service.dart';

/// Fetches through a live web view's same-origin `fetch`, so the request
/// carries the browser's cookies and TLS fingerprint and can pass
/// Cloudflare-style bot challenges that block plain HTTP clients. GETs and
/// JSON POSTs ([jsonBody]) are both served; a POST body is sent with
/// `Content-Type: application/json`.
///
/// When [binary] is true the fetcher uses `arrayBuffer()` + base64 encoding
/// to transfer raw bytes without the UTF-8 corruption that `text()` causes.
///
/// Returning `null` means "cannot serve this request" (the web view is on a
/// different origin, or the in-page fetch failed); [WebViewTransport] then
/// falls back to plain HTTP.
typedef WebViewFetcher =
    Future<WebViewFetchResult?> Function(
      Uri url, {
      Map<String, String>? headers,
      String? method,
      Object? jsonBody,
      bool binary,
    });

/// Process-wide handle the in-app browser fills for the duration of a
/// browser-initiated import, so already-constructed plugin sources route their
/// fetches through the live web view without rebuilding anything. When left
/// empty every transport behaves exactly like plain HTTP.
///
/// Fetchers are layered: [fetcher] (live browser tabs) is tried first, then
/// [fallbackFetcher] (the silent background web view), then plain HTTP. The
/// background view outlives the browser screen, so a bot-protected site keeps
/// loading after the browser closes and across an app restart.
class WebViewFetchService {
  WebViewFetchService._();

  static final WebViewFetchService instance = WebViewFetchService._();

  /// Live-browser fetcher (browser screen installs/clears this on open/close).
  WebViewFetcher? fetcher;

  /// Always-available background fetcher (see `silent_web_view_host.dart`),
  /// used only when the live browser cannot serve the request.
  WebViewFetcher? fallbackFetcher;
}

/// Wraps [inner] and, when fetchers are installed on [service], prefers them
/// for every request so bot-protected sites import from the in-app browser.
/// Unset / unusable fetchers degrade transparently to the inner transport.
class WebViewTransport implements Transport {
  WebViewTransport({required this.inner, WebViewFetchService? service})
    : _service = service ?? WebViewFetchService.instance;

  final Transport inner;
  final WebViewFetchService _service;

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) {
    return _exec(
      () => inner.fetchHtml(url, headers: headers),
      url,
      headers: headers,
      decode: (r) => r.body ?? '',
    );
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) {
    return _exec(
      () => inner.fetchHtmlPost(url, headers: headers, form: form),
      url,
      headers: headers,
      method: 'POST',
      jsonBody: form,
      decode: (r) => r.body ?? '',
    );
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) {
    return _exec(
      () => inner.fetchJson(url, headers: headers),
      url,
      headers: headers,
      decode: (r) => r.body == null ? null : jsonDecode(r.body!),
    );
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) {
    return _exec(
      () => inner.fetchJsonPost(url, headers: headers, jsonBody: jsonBody),
      url,
      headers: headers,
      method: 'POST',
      jsonBody: jsonBody,
      decode: (r) => r.body == null ? null : jsonDecode(r.body!),
    );
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) {
    return _exec(
      () => inner.fetchBytes(url, headers: headers),
      url,
      headers: headers,
      binary: true,
      decode: (r) => r.bytes ?? (r.body != null ? utf8.encode(r.body!) : const <int>[]),
    );
  }

  /// High-performance HTTP-First execution:
  /// Executes [run] against the inner transport (fast HTTP + cookie replay).
  ///
  /// Only on a bot challenge (Cloudflare 403/503) or session wall does it:
  /// 1. Try a live open browser tab on that origin (if available).
  /// 2. If unresolved, escalate to [SessionRefreshService] so the app can
  ///    offer a visible re-verify pass.
  Future<T> _exec<T>(
    Future<T> Function() run,
    Uri url, {
    Map<String, String>? headers,
    String? method,
    Object? jsonBody,
    bool binary = false,
    required T Function(WebViewFetchResult) decode,
  }) async {
    try {
      return await run();
    } on TransportException catch (e) {
      if (e.sessionExpired || e.botChallenge) {
        // Try live open browser tab if present
        final liveResult = await _tryLiveWebView(
          url,
          headers: headers,
          method: method,
          jsonBody: jsonBody,
          binary: binary,
        );
        if (liveResult != null && (liveResult.body != null || liveResult.bytes != null)) {
          return decode(liveResult);
        }

        // Escalate to session refresh
        SessionRefreshService.instance.markInvalid(
          url,
          seedUrl: url,
          verificationProbe: () => _challengeCleared(url),
        );
        throw TransportException(
          e.message,
          cause: e,
          sessionExpired: true,
          botChallenge: e.botChallenge,
        );
      }
      rethrow;
    }
  }

  Future<WebViewFetchResult?> _tryLiveWebView(
    Uri url, {
    Map<String, String>? headers,
    String? method,
    Object? jsonBody,
    bool binary = false,
  }) async {
    final fetcher = _service.fetcher;
    if (fetcher == null) return null;
    try {
      final result = await fetcher(
        url,
        headers: headers,
        method: method,
        jsonBody: jsonBody,
        binary: binary,
      );
      if (result == null) return null;
      if (result.isSessionWall || result.isBotChallenge) return null;
      return result;
    } on Object {
      return null;
    }
  }

  /// Probe the refresh webview polls to decide a bot challenge is really gone:
  /// a plain HTTP fetch through [inner] (which replays cookies captured by the
  /// refresh webview). While Cloudflare still challenges the client the fetch
  /// throws a bot-challenge [TransportException]; once the `cf_clearance`
  /// cookie lands, the same request succeeds.
  Future<bool> _challengeCleared(Uri url) async {
    try {
      await inner.fetchHtml(url);
      return true;
    } on TransportException catch (e) {
      return !e.botChallenge;
    } on Object {
      return false;
    }
  }
}
