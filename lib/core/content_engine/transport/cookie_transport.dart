import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:atlas_app/core/content_engine/transport/browser_header_utils.dart';
import 'package:atlas_app/core/content_engine/transport/cronet_version_provider.dart';
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
  /// constructed per plugin/run. Only available where the plugin implements
  /// `getDefaultUserAgent` (Android/iOS/macOS); on Windows, Linux, and Web it
  /// stays null and requests pass through without a UA fill.
  static const _kWindowsUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';
  static const _kMacUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';
  static const _kLinuxUserAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';
  static const _kAndroidUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Mobile Safari/537.36';
  static const _kIosUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  static String? _cachedUserAgent;
  static Future<String?>? _userAgentLookup;

  Future<String> _userAgent() {
    final cached = _cachedUserAgent;
    if (cached != null) return Future.value(cached);
    return (_userAgentLookup ??= _fetchDefaultUserAgent()).then(
      (ua) => ua ?? _fallbackUserAgent,
    );
  }

  static String get _fallbackUserAgent {
    if (kIsWeb) return _kWindowsUserAgent;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return _kWindowsUserAgent;
      case TargetPlatform.macOS:
        return _kMacUserAgent;
      case TargetPlatform.linux:
        return _kLinuxUserAgent;
      case TargetPlatform.android:
        return _kAndroidUserAgent;
      case TargetPlatform.iOS:
        return _kIosUserAgent;
      default:
        return _kWindowsUserAgent;
    }
  }

  static Future<String?> _fetchDefaultUserAgent() async {
    if (!_supportsDefaultUserAgent) return _fallbackUserAgent;
    try {
      final ua = await InAppWebViewController.getDefaultUserAgent();
      if (ua.isNotEmpty) {
        _cachedUserAgent = ua;
        return ua;
      }
    } on Object {
      // Fallback below
    }
    return _fallbackUserAgent;
  }

  static bool get _supportsDefaultUserAgent {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
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
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final validCookies = cookies.where((c) {
        final expires = c.expiresDate;
        if (expires == null) return true;
        return expires > nowMs;
      }).toList();

      if (validCookies.isNotEmpty) {
        result['Cookie'] = validCookies
            .map((c) => '${c.name}=${c.value}')
            .join('; ');
      }
    } on Object {
      // No cookie store on this platform, or lookup failed — proceed without
      // one; [inner]'s own bot-challenge handling takes over from here.
    }
    final ua = result['User-Agent'] ?? await _userAgent();
    // On Android prefer the real Cronet/Chromium version for `sec-ch-ua`.
    // Falls back to UA parsing when Cronet is unavailable or on other platforms.
    String? cronetVersion;
    try {
      cronetVersion = await CronetVersionProvider.getVersion().timeout(
        const Duration(milliseconds: 300),
      );
    } catch (_) {
      cronetVersion = CronetVersionProvider.cachedVersion;
    }
    return BrowserHeaderUtils.buildBrowserHeaders(
      userAgent: ua,
      existingHeaders: result,
      cronetVersion: cronetVersion,
    );
  }

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    return inner.fetchHtml(url, headers: await _augment(url, headers));
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async {
    return inner.fetchHtmlPost(
      url,
      headers: await _augment(url, headers),
      form: form,
    );
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    return inner.fetchJson(url, headers: await _augment(url, headers));
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    return inner.fetchJsonPost(
      url,
      headers: await _augment(url, headers),
      jsonBody: jsonBody,
    );
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    return inner.fetchBytes(url, headers: await _augment(url, headers));
  }
}
