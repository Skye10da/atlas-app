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
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    final webView = await _tryWebView(url, headers: headers);
    if (webView?.body != null) return webView!.body!;
    return _inner(
      () => inner.fetchHtml(url, headers: headers),
      url,
      (r) => r.body!,
    );
  }

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async {
    final webView = await _tryWebView(
      url,
      headers: headers,
      method: 'POST',
      jsonBody: form,
    );
    if (webView?.body != null) return webView!.body!;
    return _inner(
      () => inner.fetchHtmlPost(url, headers: headers, form: form),
      url,
      (r) => r.body!,
    );
  }

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    final webView = await _tryWebView(url, headers: headers);
    if (webView?.body != null) return jsonDecode(webView!.body!);
    return _inner(
      () => inner.fetchJson(url, headers: headers),
      url,
      (r) => jsonDecode(r.body!),
    );
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    final webView = await _tryWebView(
      url,
      headers: headers,
      method: 'POST',
      jsonBody: jsonBody,
    );
    if (webView?.body != null) return jsonDecode(webView!.body!);
    return _inner(
      () => inner.fetchJsonPost(url, headers: headers, jsonBody: jsonBody),
      url,
      (r) => jsonDecode(r.body!),
    );
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    // Try the webview first with binary mode: the in-page fetcher uses
    // arrayBuffer() + base64 to transfer raw bytes without UTF-8 corruption.
    // The webview carries the browser's cookies and TLS fingerprint, so it
    // can pass Cloudflare bot challenges that block plain HTTP.
    final webView = await _tryWebView(url, headers: headers, binary: true);
    if (webView?.bytes != null) return webView!.bytes!;
    if (webView?.body != null) return utf8.encode(webView!.body!);
    return _inner(
      () => inner.fetchBytes(url, headers: headers),
      url,
      (r) => r.bytes ?? utf8.encode(r.body!),
    );
  }

  /// Runs [run] against the inner transport. On a session wall (401/403 that
  /// is *not* Cloudflare), notifies [SessionRefreshService] so the app can
  /// offer a re-verify pass. On a Cloudflare bot-challenge error, retries
  /// through the webview — the background view may have navigated to the site
  /// and solved the challenge by the time the HTTP fallback fails. When the
  /// webview cannot serve it either, the challenge escalates to the
  /// session-refresh flow (same as a session wall): the refresh webview loads
  /// the challenged URL, the user passes the bot check, and fresh cookies are
  /// captured for the retry.
  Future<T> _inner<T>(
    Future<T> Function() run,
    Uri url,
    T Function(WebViewFetchResult) decode,
  ) async {
    try {
      return await run();
    } on TransportException catch (e) {
      if (e.sessionExpired) {
        SessionRefreshService.instance.markInvalid(url, seedUrl: url);
        rethrow;
      }
      // Cloudflare bot check — retry through webview as a last resort.
      // The first _tryWebView() may have returned null because the
      // background view hadn't loaded the site yet; by now it has had time
      // to navigate and solve the challenge.
      final retry = await _tryWebView(url);
      if (retry?.body != null || retry?.bytes != null) return decode(retry!);
      if (e.botChallenge) {
        // The webview could not solve it either. Escalate to the quick
        // re-verify flow and surface as session-expired so the reader's
        // auto-recovery (see reader_providers.dart) runs a visible webview
        // that passes the challenge and captures cookies for the retry.
        SessionRefreshService.instance.markInvalid(
          url,
          seedUrl: url,
          verificationProbe: () => _challengeCleared(url),
        );
        throw TransportException(e.message, cause: e, sessionExpired: true);
      }
      rethrow;
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

  Future<WebViewFetchResult?> _tryWebView(
    Uri url, {
    Map<String, String>? headers,
    String? method,
    Object? jsonBody,
    bool binary = false,
  }) async {
    for (final fetcher in [_service.fetcher, _service.fallbackFetcher]) {
      if (fetcher == null) continue;
      try {
        final result = await fetcher(
          url,
          headers: headers,
          method: method,
          jsonBody: jsonBody,
          binary: binary,
        );
        if (result == null) continue;
        if (result.body == null && result.bytes == null) continue;
        if (result.isSessionWall) {
          SessionRefreshService.instance.markInvalid(url, seedUrl: url);
          continue;
        }
        // A Cloudflare interstitial is *not* a session wall — the webview may
        // still be waiting out the JS challenge, so serving its HTML as
        // chapter content would hide the bot check behind an "empty content"
        // failure and skip the re-verify flow entirely. Skip it; the caller
        // (WebViewTransport._inner) escalates the bot challenge to the session
        // refresh flow instead.
        if (result.isBotChallenge) {
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
