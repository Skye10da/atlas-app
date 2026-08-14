import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/engines/webview_page_fetcher.dart';
import 'package:atlas_app/browser/domain/entities/browser_session_cookie.dart';
import 'package:atlas_app/browser/domain/repository_interfaces/browser_session_repository_interface.dart';
import 'package:atlas_app/core/logging/logger.dart';

/// Serves plugin fetches through a dedicated background web view that stays
/// mounted for the whole app lifetime (see `silent_web_view_host.dart`), so
/// bot-protected sites keep loading after a restart even when the user never
/// opened the browser.
///
/// On an origin miss it silently navigates the background view to that origin —
/// passing any Cloudflare-style JS challenge in a real browser context — then
/// serves the same-origin fetch through [WebViewPageFetcher]. Cookies saved by
/// [BrowserSessionRepositoryInterface] are re-seeded into the platform store
/// first, so a fresh challenge is often skipped when the clearance cookie is
/// still valid.
///
/// Degrades gracefully: an unusable engine, an unresolved challenge, or a
/// cross-origin target all return `null` so [WebViewTransport] falls through to
/// plain HTTP (and the usual Cloudflare error surfaces there if it must).
class SilentWebViewService {
  SilentWebViewService({
    required this.engine,
    this.sessionStore,
    this.navigationTimeout = const Duration(seconds: 45),
    this.challengeRetryDelay = const Duration(milliseconds: 1500),
    this.maxChallengeRetries = 5,
    Future<void> Function(Duration duration)? sleep,
    Future<void> Function(
      Uri origin,
      List<BrowserSessionCookie> cookies,
    )?
        seeder,
  })  : _pageFetcher = WebViewPageFetcher(engine: engine),
        _sleep = sleep ?? _defaultSleep,
        _seeder = seeder;

  final BrowserWebEngine engine;
  final BrowserSessionRepositoryInterface? sessionStore;
  final Duration navigationTimeout;
  final Duration challengeRetryDelay;
  final int maxChallengeRetries;
  final WebViewPageFetcher _pageFetcher;
  final Future<void> Function(Duration duration) _sleep;
  final Future<void> Function(Uri origin, List<BrowserSessionCookie> cookies)?
      _seeder;

  static Future<void> _defaultSleep(Duration duration) =>
      Future<void>.delayed(duration);

  /// Serializes navigation + fetch so concurrent plugin downloads can't race
  /// the single background view over each other.
  Future<void> _queue = Future.value();

  Future<String?> fetchHtml(Uri url, {Map<String, String>? headers}) async {
    if (!_servable(url)) return null;
    final origin = _originKey(url.toString());
    final run = _queue.then((_) async {
      if (_currentOrigin != origin) {
        await _seedSession(Uri.parse(origin));
        final loaded = await _navigateTo(Uri.parse(origin));
        if (!loaded) return null;
      }
      return _fetchThroughPage(url, headers: headers);
    });
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  String? get _currentOrigin {
    final current = engine.currentUrl.value;
    final uri = Uri.tryParse(current ?? '');
    if (uri == null || uri.host.isEmpty) return null;
    return uri.replace(path: '/', query: null, fragment: null).toString();
  }

  /// Only pages on a real origin are worth navigating a web view to; an
  /// `about:`/scheme-less URL cannot pass a challenge.
  bool _servable(Uri url) => url.hasScheme && url.host.isNotEmpty;

  /// Navigates the background view to [origin]'s root and waits for the load
  /// to settle (a Cloudflare challenge interstitial is itself a full load, so
  /// "idle" is just the first page that commits; later fetch retries give the
  /// clearance JS time to finish).
  Future<bool> _navigateTo(Uri origin) async {
    await _waitForIdle();
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
      return await completer.future
          .timeout(navigationTimeout, onTimeout: () => false);
    } on Object {
      return false;
    } finally {
      engine.isLoading.removeListener(listener);
    }
  }

  /// Waits for an in-flight navigation to finish so a new one doesn't abort it
  /// mid-way (the [BrowserWebEngine] contract is one load at a time).
  Future<void> _waitForIdle() async {
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

  Future<String?> _fetchThroughPage(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    for (var attempt = 0; attempt <= maxChallengeRetries; attempt++) {
      final html = await _pageFetcher.fetchHtml(url, headers: headers);
      if (html == null) return null;
      if (!_looksLikeChallenge(html)) return html;
      await _sleep(challengeRetryDelay);
    }
    // The challenge never cleared; hand back to plain HTTP so its own (clear)
    // bot-check error surfaces rather than a silent empty page.
    return null;
  }

  /// Cloudflare challenge pages are recognizable by their interstitial copy /
  /// challenge script markers; a same-origin `fetch` issued before clearance
  /// lands returns one of these, so we retry rather than serve garbage.
  bool _looksLikeChallenge(String html) {
    final lower = html.toLowerCase();
    return lower.contains('just a moment') ||
        lower.contains('attention required') ||
        lower.contains('challenge-platform') ||
        lower.contains('cf_chl');
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
