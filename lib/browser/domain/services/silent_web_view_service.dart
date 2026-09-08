import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/engines/webview_page_fetcher.dart';
import 'package:atlas_app/browser/domain/entities/browser_session_cookie.dart';
import 'package:atlas_app/browser/domain/repository_interfaces/browser_session_repository_interface.dart';
import 'package:atlas_app/browser/domain/services/headless_webview_pool.dart';
import 'package:atlas_app/core/content_engine/transport/challenge_detector.dart';
import 'package:atlas_app/core/content_engine/transport/webview_fetch_result.dart';
import 'package:atlas_app/core/logging/logger.dart';

/// Serves plugin fetches through background headless web views, so bot-protected
/// sites keep loading after a restart even when the user never opened the browser.
///
/// On an origin miss it silently navigates a pooled background view to that origin —
/// passing any Cloudflare-style JS challenge in a real browser context — then
/// serves the same-origin fetch through [WebViewPageFetcher]. Cookies saved by
/// [BrowserSessionRepositoryInterface] are re-seeded into the platform store
/// first, so a fresh challenge is often skipped when the clearance cookie is
/// still valid.
///
/// Degrades gracefully: an unusable engine, an unresolved challenge, or a
/// cross-origin target all return `null` so [WebViewTransport] falls through to
/// plain HTTP (and the usual Cloudflare error surfaces there if it must).
/// Backed by [HeadlessWebViewPool], allowing concurrent challenge solving across
/// different origins without serializing all requests into a single bottleneck.
class SilentWebViewService {
  SilentWebViewService({
    BrowserWebEngine? engine,
    HeadlessWebViewPool? pool,
    this.sessionStore,
    this.navigationTimeout = const Duration(seconds: 45),
    this.challengeRetryDelay = const Duration(milliseconds: 1500),
    this.maxChallengeRetries = 5,
    Future<void> Function(Duration duration)? sleep,
    Future<void> Function(Uri origin, List<BrowserSessionCookie> cookies)?
        seeder,
  })  : pool = pool ??
            (engine != null
                ? HeadlessWebViewPool.single(engine)
                : HeadlessWebViewPool()),
        _sleep = sleep ?? _defaultSleep,
        _seeder = seeder;

  final HeadlessWebViewPool pool;
  final BrowserSessionRepositoryInterface? sessionStore;
  final Duration navigationTimeout;
  final Duration challengeRetryDelay;
  final int maxChallengeRetries;
  final Future<void> Function(Duration duration) _sleep;
  final Future<void> Function(Uri origin, List<BrowserSessionCookie> cookies)?
      _seeder;

  final Map<String, Future<void>> _originQueues = {};

  static Future<void> _defaultSleep(Duration duration) =>
      Future<void>.delayed(duration);

  Future<WebViewFetchResult?> fetchHtml(
    Uri url, {
    Map<String, String>? headers,
    String? method,
    Object? jsonBody,
    bool binary = false,
  }) async {
    if (!_servable(url)) return null;
    // On Windows the headless pool is disabled (effectiveMaxViews == 0)
    // — fail fast to HTTP fallback instead of trying to acquire a
    // HeadlessInAppWebView that will throw CoInitialize.
    if (pool.effectiveMaxViews == 0) return null;
    final originStr = _originKey(url.toString());
    if (originStr.isEmpty) return null;
    final originUri = Uri.parse(originStr);

    final queue = _originQueues[originStr] ?? Future.value();
    final run = queue.then((_) async {
      late final BrowserWebEngine engine;
      try {
        engine = await pool.acquire(originUri);
      } catch (e) {
        AppLogger.warning('Headless pool acquire failed for $originStr: $e');
        return null;
      }
      try {
        final currentOrigin = _originKey(engine.currentUrl.value ?? '');
        final shouldNavigateForHtml =
            (method == null || method.toUpperCase() == 'GET') &&
            !binary &&
            (url.path.contains('/novel/') || url.queryParameters.containsKey('page'));
        // For document fetches (chapter list, novel page), navigate the
        // WebView to the target URL and capture DOM directly — more reliable
        // than `fetch()` from a different page (e.g. /home) which can be
        // blocked by CF or return null due to sameOrigin timing.
        if (shouldNavigateForHtml &&
            engine.currentUrl.value != url.toString()) {
          await _seedSession(originUri);
          final loaded = await _navigateTo(engine, url);
          if (loaded) {
            // Give the page a moment to settle (CF challenge JS may still
            // be running) before capturing.
            await _sleep(const Duration(milliseconds: 800));
            final dom = await engine.evaluate(
              'document.documentElement.outerHTML',
            );
            if (dom is String &&
                dom.isNotEmpty &&
                !_looksLikeChallenge(dom)) {
              await _refreshSavedSession(Uri.parse(_originKey(url.toString())));
              return WebViewFetchResult(
                body: dom,
                status: 200,
                finalUrl: url,
              );
            }
            // If DOM is still a challenge, fall through to fetch.
          }
        } else if (currentOrigin != originStr) {
          await _seedSession(originUri);
          final loaded = await _navigateTo(engine, originUri);
          if (!loaded) return null;
        }
        return await _fetchThroughPage(
          engine,
          url,
          headers: headers,
          method: method,
          jsonBody: jsonBody,
          binary: binary,
        );
      } catch (e) {
        AppLogger.warning('Headless fetch failed for $url: $e');
        return null;
      } finally {
        try {
          pool.release(originUri);
        } catch (_) {}
      }
    });

    _originQueues[originStr] = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// Only pages on a real origin are worth navigating a web view to; an
  /// `about:`/scheme-less URL cannot pass a challenge.
  bool _servable(Uri url) => url.hasScheme && url.host.isNotEmpty;

  /// Navigates [engine] to [origin]'s root and waits for the load to settle.
  Future<bool> _navigateTo(BrowserWebEngine engine, Uri origin) async {
    await _waitForIdle(engine);
    final completer = Completer<bool>();
    void listener() {
      if (!engine.isLoading.value && !completer.isCompleted) {
        completer.complete(true);
      }
    }

    engine.isLoading.addListener(listener);
    try {
      await engine.load(origin.toString());
      listener(); // a load that already finished before we could observe it
      if (completer.isCompleted) return true;
      return await completer.future.timeout(
        navigationTimeout,
        onTimeout: () => false,
      );
    } on Object {
      return false;
    } finally {
      engine.isLoading.removeListener(listener);
    }
  }

  /// Waits for an in-flight navigation to finish so a new one doesn't abort it mid-way.
  Future<void> _waitForIdle(BrowserWebEngine engine) async {
    if (!engine.isLoading.value) return;
    final completer = Completer<bool>();
    void listener() {
      if (!engine.isLoading.value && !completer.isCompleted) {
        completer.complete(true);
      }
    }

    engine.isLoading.addListener(listener);
    try {
      await completer.future.timeout(navigationTimeout, onTimeout: () => false);
    } finally {
      engine.isLoading.removeListener(listener);
    }
  }

  Future<WebViewFetchResult?> _fetchThroughPage(
    BrowserWebEngine engine,
    Uri url, {
    Map<String, String>? headers,
    String? method,
    Object? jsonBody,
    bool binary = false,
  }) async {
    // Ensure the WebView's current page has finished loading before
    // issuing a same-origin `fetch` — otherwise the fetch's JS context
    // may not be ready and the `pageFetcher` will timeout after 45s and
    // return null, causing the `pageFetcher returned null` log and an
    // unnecessary HTTP fallback that then hits the bot challenge.
    await _waitForIdle(engine);
    final pageFetcher = WebViewPageFetcher(engine: engine);
    for (var attempt = 0; attempt <= maxChallengeRetries; attempt++) {
      final result = await pageFetcher.fetchHtml(
        url,
        headers: headers,
        method: method,
        jsonBody: jsonBody,
        binary: binary,
      );
      if (result == null) {
        AppLogger.warning('_fetchThroughPage: pageFetcher returned null for $url attempt $attempt');
        if (attempt < maxChallengeRetries) {
          await _sleep(challengeRetryDelay);
          continue;
        }
        return null;
      }
      // Binary responses have no text body to inspect; accept status 200.
      if (result.bytes != null) {
        if (result.isSessionWall) {
          AppLogger.warning('_fetchThroughPage: isSessionWall=true for bytes $url status=${result.status} finalUrl=${result.finalUrl}');
          return null;
        }
        await _refreshSavedSession(Uri.parse(_originKey(url.toString())));
        return result;
      }
      final body = result.body;
      if (body == null) {
        AppLogger.warning('_fetchThroughPage: body==null for $url attempt $attempt status=${result.status}');
        return null;
      }
      // A Cloudflare interstitial is retried; an auth wall (401/403 that is
      // not a challenge, or a login redirect) is a stale session, not a
      // passable challenge — give up so the caller falls through to HTTP and
      // the app can offer a re-verify pass.
      if (_looksLikeChallenge(body)) {
        AppLogger.warning('_fetchThroughPage: _looksLikeChallenge=true for $url attempt $attempt status=${result.status} finalUrl=${result.finalUrl} bodyLen=${body.length}');
        await _sleep(challengeRetryDelay);
        continue;
      }
      if (result.isSessionWall) {
        AppLogger.warning('_fetchThroughPage: isSessionWall=true for $url attempt $attempt status=${result.status} finalUrl=${result.finalUrl}');
        return null;
      }
      // A fresh solve landed (challenge retries succeeded, or the seeded
      // clearance cookie was still valid): persist the store's current
      // cookies so a restart can re-seed this exact set.
      await _refreshSavedSession(Uri.parse(_originKey(url.toString())));
      return result;
    }
    // The challenge never cleared; hand back to plain HTTP so its own (clear)
    // bot-check error surfaces rather than a silent empty page.
    return null;
  }

  /// Snapshot the platform cookie store for [origin] so the persisted session
  /// file matches what the background view is actually using now.
  Future<void> _refreshSavedSession(Uri origin) async {
    final store = sessionStore;
    if (store == null) return;
    try {
      await store.captureForOrigin(origin);
    } on Object catch (e) {
      AppLogger.warning('Failed to refresh saved session for $origin: $e');
    }
  }

  /// Synced with `ChallengeDetector.challengeMarkers`.
  bool _looksLikeChallenge(String html) {
    final isChallenge = ChallengeDetector.isChallengeBody(html);
    if (isChallenge) {
      // Debug: log first 200 chars of the body that was flagged. This
      // helps diagnose false positives where novel text contains
      // `just a moment` or Cloudflare script fragments.
      final snippet = html.length > 200
          ? '${html.substring(0, 200)}…'
          : html;
      AppLogger.warning(
        '_looksLikeChallenge=true for ${snippet.replaceAll('\n', ' ')}',
      );
    }
    return isChallenge;
  }

  Future<void> _seedSession(Uri origin) async {
    final store = sessionStore;
    final cookies = store == null
        ? const <BrowserSessionCookie>[]
        : await store.loadForOrigin(origin);
    if (cookies.isEmpty) return;
    if (_seeder != null) {
      await _seeder(origin, cookies);
      return;
    }
    for (final cookie in cookies) {
      try {
        await CookieManager.instance().setCookie(
          url: WebUri.uri(origin),
          name: cookie.name,
          value: cookie.value,
          path: cookie.path ?? '/',
          domain: cookie.domain,
          expiresDate: cookie.expiresDate,
          isSecure: cookie.isSecure,
        );
      } on Object catch (e) {
        AppLogger.warning('Failed to re-seed cookie ${cookie.name}: $e');
      }
    }
  }

  String _originKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return '';
    return uri.replace(path: '/', query: null, fragment: null).toString();
  }
}
