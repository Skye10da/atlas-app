import 'dart:convert';

import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/content_engine/transport/webview_fetch_result.dart';
import 'package:atlas_app/core/session/session_refresh_service.dart';

/// Fetches a page's text through a live web view's same-origin `fetch`, so the
/// request carries the browser's cookies and TLS fingerprint and can pass
/// Cloudflare-style bot challenges that block plain HTTP clients.
///
/// Returning `null` means "cannot serve this request" (the web view is on a
/// different origin, or the in-page fetch failed); [WebViewTransport] then
/// falls back to plain HTTP.
typedef WebViewFetcher = Future<WebViewFetchResult?> Function(
  Uri url, {
  Map<String, String>? headers,
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
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    final webView = await _tryWebView(url, headers: headers);
    if (webView?.body != null) return webView!.body!;
    return _inner(() => inner.fetchHtml(url, headers: headers), url);
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async {
    // The web-view fetcher only issues same-origin GETs, so a form POST goes
    // straight to the inner transport. Most Madara-style archives are plain
    // `admin-ajax.php` endpoints, which HTTP handles fine.
    return _inner(
      () => inner.fetchHtmlPost(url, headers: headers, form: form),
      url,
    );
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    final webView = await _tryWebView(url, headers: headers);
    if (webView?.body != null) return jsonDecode(webView!.body!);
    return _inner(() => inner.fetchJson(url, headers: headers), url);
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    // The web-view fetcher only issues same-origin GETs, so a JSON POST goes
    // straight to the inner transport, like [fetchHtmlPost].
    return _inner(
      () => inner.fetchJsonPost(url, headers: headers, jsonBody: jsonBody),
      url,
    );
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    final webView = await _tryWebView(url, headers: headers);
    if (webView?.body != null) return utf8.encode(webView!.body!);
    return _inner(() => inner.fetchBytes(url, headers: headers), url);
  }

  /// Runs [run] against the inner transport, forwarding the result and, when
  /// the inner layer reports a session wall, notifying [SessionRefreshService]
  /// so the app can offer a re-verify pass.
  Future<T> _inner<T>(Future<T> Function() run, Uri url) async {
    try {
      return await run();
    } on TransportException catch (e) {
      if (e.sessionExpired) {
        SessionRefreshService.instance.markInvalid(url);
      }
      rethrow;
    }
  }

  Future<WebViewFetchResult?> _tryWebView(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    for (final fetcher in [
      _service.fetcher,
      _service.fallbackFetcher,
    ]) {
      if (fetcher == null) continue;
      try {
        final result = await fetcher(url, headers: headers);
        if (result?.body == null) continue;
        if (result!.isSessionWall) {
          // An auth wall from the browser context: the saved session is stale.
          // Don't serve it — fall through so the inner transport produces the
          // (tagged) error and the app can offer a re-verify pass.
          SessionRefreshService.instance.markInvalid(url);
          continue;
        }
        return result;
      } on Object {
        // A broken fetcher must not kill the request; try the next layer.
      }
    }
    return null;
  }
}
