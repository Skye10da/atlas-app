import 'dart:convert';

import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Fetches a page's text through a live web view's same-origin `fetch`, so the
/// request carries the browser's cookies and TLS fingerprint and can pass
/// Cloudflare-style bot challenges that block plain HTTP clients.
///
/// Returning `null` means "cannot serve this request" (the web view is on a
/// different origin, or the in-page fetch failed); [WebViewTransport] then
/// falls back to plain HTTP.
typedef WebViewFetcher = Future<String?> Function(
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
    if (webView != null) return webView;
    return inner.fetchHtml(url, headers: headers);
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    final webView = await _tryWebView(url, headers: headers);
    if (webView != null) return jsonDecode(webView);
    return inner.fetchJson(url, headers: headers);
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    final webView = await _tryWebView(url, headers: headers);
    if (webView != null) return utf8.encode(webView);
    return inner.fetchBytes(url, headers: headers);
  }

  Future<String?> _tryWebView(Uri url, {Map<String, String>? headers}) async {
    for (final fetcher in [
      _service.fetcher,
      _service.fallbackFetcher,
    ]) {
      if (fetcher == null) continue;
      try {
        final html = await fetcher(url, headers: headers);
        if (html != null) return html;
      } on Object {
        // A broken fetcher must not kill the request; try the next layer.
      }
    }
    return null;
  }
}
