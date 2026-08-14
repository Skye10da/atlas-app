import 'dart:async';
import 'dart:convert';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/core/content_engine/transport/webview_fetch_result.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';

/// Implements [WebViewFetcher] against a live [BrowserWebEngine].
///
/// Evaluates a same-origin `fetch()` inside the page context, so the request
/// carries the browser's cookies, User-Agent and TLS fingerprint — the things
/// that let the page itself load — and thereby passes Cloudflare-style bot
/// challenges. The result (body, HTTP status, final URL) is delivered back
/// through a transient JS handler.
///
/// Only same-origin requests are served (a cross-origin `fetch` would be
/// blocked by CORS and is pointless); anything else returns `null` so
/// [WebViewTransport] can fall back to plain HTTP.
class WebViewPageFetcher {
  WebViewPageFetcher({required this.engine, this.timeout = _kDefaultTimeout});

  final BrowserWebEngine engine;

  /// How long to wait for the in-page fetch to call back.
  final Duration timeout;

  static const _kDefaultTimeout = Duration(seconds: 30);

  Future<WebViewFetchResult?> fetchHtml(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final currentUri = Uri.tryParse(engine.currentUrl.value ?? '');
    if (currentUri == null || !_sameOrigin(currentUri, url)) return null;

    final handlerName =
        'atlasPageFetch_${DateTime.now().microsecondsSinceEpoch}';
    final completer = Completer<WebViewFetchResult?>();
    engine.addJsHandler(handlerName, (args) {
      if (completer.isCompleted) return null;
      final raw = args.isEmpty ? null : args.first;
      if (raw is! String) {
        completer.complete(null);
        return null;
      }
      completer.complete(_decodeEnvelope(raw));
      return null;
    });

    try {
      // `void (...)` keeps the evaluated expression from returning a Promise,
      // which some engines cannot serialize; the result arrives via the
      // handler above. Errors (CORS, network) call back with a zero-status
      // envelope so the caller falls through to plain HTTP.
      await engine.evaluate('''
void ((url, headers, handler) => {
  fetch(url, { method: 'GET', credentials: 'include', headers: headers })
    .then(async r => {
      const t = await r.text();
      window.flutter_inappwebview.callHandler(handler, JSON.stringify({ b: t, s: r.status, u: r.url }));
    })
    .catch(() => window.flutter_inappwebview.callHandler(handler, JSON.stringify({ s: 0 })));
})(${jsonEncode(url.toString())}, ${jsonEncode(headers ?? const {})}, ${jsonEncode(handlerName)});
''');
      return await completer.future.timeout(timeout);
    } on Object {
      return null;
    } finally {
      engine.removeJsHandler(handlerName);
    }
  }

  static WebViewFetchResult? _decodeEnvelope(String raw) {
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final status = map['s'] as num? ?? 0;
      final body = map['b'] as String?;
      final url = map['u'] as String?;
      return WebViewFetchResult(
        body: body,
        status: status.toInt(),
        finalUrl: url == null ? null : Uri.tryParse(url),
      );
    } catch (_) {
      return null;
    }
  }

  /// Scheme, host and port must match; the page must be viewing the same
  /// origin for a `fetch` to be same-origin (CORS-free).
  bool _sameOrigin(Uri a, Uri b) =>
      a.scheme == b.scheme &&
      a.host.toLowerCase() == b.host.toLowerCase() &&
      a.port == b.port;
}
