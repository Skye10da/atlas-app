import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Wraps [inner] with cookies and a User-Agent sourced from the platform
/// WebView's persistent cookie store — `WKHTTPCookieStore` on iOS/macOS,
/// `android.webkit.CookieManager` on Android, WebView2's cookie manager on
/// Windows. That store is disk-backed and survives app restarts on its own;
/// nothing about it depends on a [BrowserWebEngine] being mounted.
///
/// [WebViewFetchService] (see `webview_transport.dart`) only has a fetcher
/// installed while a browser tab is alive, so it goes `null` the moment the
/// browser closes — and stays `null` across an app restart until the user
/// opens the browser again. [CookieTransport] fills that gap: it reads
/// whatever cookies a *previous* live-webview visit already left behind (e.g.
/// a Cloudflare `cf_clearance` from the import) and attaches them to the
/// plain HTTP request, so a bot-protected site keeps loading for chapter
/// fetches long after the import session ended.
///
/// This is a *replay* layer, not a challenge solver: it can't pass a fresh
/// Cloudflare JS challenge on its own (no persisted cookie exists yet for
/// that). That case still needs a live or headless WebView. When no cookies
/// are found, requests pass through unchanged and the usual bot-challenge
/// error surfaces from [inner].
class CookieTransport implements Transport {
  CookieTransport({required this.inner});

  final Transport inner;

  /// Platform WebView's default User-Agent. Cloudflare typically binds a
  /// challenge cookie to the UA that solved it, so replaying the cookie
  /// without the matching UA can still get rejected. Fetched once per
  /// process since it's a fixed platform string, not per-page. Cached at the
  /// class level (not per-instance) because a fresh [CookieTransport] is
  /// constructed per plugin/run.
  static String? _cachedUserAgent;
  static Future<String?>? _userAgentLookup;

  Future<String?> _userAgent() {
    final cached = _cachedUserAgent;
    if (cached != null) return Future.value(cached);
    return _userAgentLookup ??= _fetchDefaultUserAgent();
  }

  static Future<String?> _fetchDefaultUserAgent() async {
    try {
      final ua = await InAppWebViewController.getDefaultUserAgent();
      _cachedUserAgent = ua;
      return ua;
    } on Object {
      return null;
    }
  }

  Future<Map<String, String>> _augment(
    Uri url,
    Map<String, String>? headers,
  ) async {
    final result = {...?headers};
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri.uri(url),
      );
      if (cookies.isNotEmpty) {
        result['Cookie'] = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      }
    } on Object {
      // No cookie store on this platform, or lookup failed — proceed without
      // one; [inner]'s own bot-challenge handling takes over from here.
    }
    if (!result.containsKey('User-Agent')) {
      final ua = await _userAgent();
      if (ua != null) result['User-Agent'] = ua;
    }
    return result;
  }

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    return inner.fetchHtml(url, headers: await _augment(url, headers));
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    return inner.fetchJson(url, headers: await _augment(url, headers));
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    return inner.fetchBytes(url, headers: await _augment(url, headers));
  }
}
