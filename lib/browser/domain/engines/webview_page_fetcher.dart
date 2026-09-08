import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/core/content_engine/transport/challenge_detector.dart';
import 'package:atlas_app/core/content_engine/transport/webview_fetch_result.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';

/// Implements [WebViewFetcher] against a live [BrowserWebEngine].
///
/// Evaluates a same-origin `fetch()` inside the page context, so the request
/// carries the browser's cookies, User-Agent and TLS fingerprint — the things
/// that let the page itself load — and thereby passes Cloudflare-style bot
/// challenges. The result (body, HTTP status, final URL) is delivered back
/// through a transient JS handler. GETs and JSON POSTs (via [method] and
/// [jsonBody]) are both supported.
///
/// When [binary] is true the fetcher uses `arrayBuffer()` + base64 encoding
/// to transfer raw bytes without the UTF-8 corruption that `text()` causes.
///
/// Only same-origin requests are served (a cross-origin `fetch` would be
/// blocked by CORS and is pointless); anything else returns `null` so
/// [WebViewTransport] can fall back to plain HTTP.
class WebViewPageFetcher {
  WebViewPageFetcher({required this.engine, this.timeout = _kDefaultTimeout});

  final BrowserWebEngine engine;

  /// How long to wait for the in-page fetch to call back.
  final Duration timeout;

  static const _kDefaultTimeout = Duration(seconds: 45);

  Future<WebViewFetchResult?> fetchHtml(
    Uri url, {
    Map<String, String>? headers,
    String? method,
    Object? jsonBody,
    bool binary = false,
  }) async {
    final currentRaw = engine.currentUrl.value ?? '';
    Uri? currentUri;
    if (currentRaw.isEmpty || currentRaw == 'about:blank') {
      currentUri = null;
    } else {
      currentUri = Uri.tryParse(currentRaw);
      if (currentUri != null && !_sameOrigin(currentUri, url)) {
        // Log same-origin failure for diagnostics — helps distinguish
        // `pageFetcher returned null` due to CORS vs timeout.
        // ignore: avoid_print
        print('[WebViewPageFetcher] sameOrigin=false current=$currentRaw target=$url');
        return null;
      }
    }
    if (currentUri == null) {
      // Still allow fetch from about:blank — the JS will handle CORS.
      // But log for diagnostics.
      // ignore: avoid_print
      print('[WebViewPageFetcher] currentUri null/blank, allowing fetch for $url from $currentRaw');
    }

    // If the WebView is already viewing the exact URL the caller wants,
    // capture the rendered DOM directly — avoids a same-origin `fetch` that
    // would re-hit Cloudflare's interstitial when the page itself has already
    // solved the challenge (freewebnovel 200 `Just a moment` case).
    final isViewingTarget =
        currentUri != null && _isViewingTarget(currentUri, url);

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
      final httpMethod = (method == null || method.isEmpty)
          ? 'GET'
          : method.toUpperCase();
      final body = jsonBody == null ? null : jsonEncode(jsonBody);
      final requestHeaders = <String, String>{...?headers};
      if (body != null &&
          !requestHeaders.keys.any((k) => k.toLowerCase() == 'content-type')) {
        requestHeaders['Content-Type'] = 'application/json';
      }

      if (binary) {
        await engine.evaluate('''
void ((url, headers, method, body, handler) => {
  const opts = { method: method, credentials: 'include', headers: headers };
  if (body !== null) opts.body = body;
  fetch(url, opts)
    .then(async r => {
      const buf = await r.arrayBuffer();
      const bytes = new Uint8Array(buf);
      let bin = '';
      const chunk = 8192;
      for (let i = 0; i < bytes.byteLength; i += chunk) {
        bin += String.fromCharCode.apply(null, bytes.subarray(i, Math.min(i + chunk, bytes.byteLength)));
      }
      const b64 = btoa(bin);
      window.flutter_inappwebview.callHandler(handler, JSON.stringify({ b: b64, s: r.status, u: r.url, bin: true }));
    })
    .catch(() => window.flutter_inappwebview.callHandler(handler, JSON.stringify({ s: 0 })));
})(${jsonEncode(url.toString())}, ${jsonEncode(requestHeaders)}, ${jsonEncode(httpMethod)}, ${jsonEncode(body)}, ${jsonEncode(handlerName)});
''');
      } else {
        await engine.evaluate('''
void ((url, headers, method, body, handler) => {
  const opts = { method: method, credentials: 'include', headers: headers };
  if (body !== null) opts.body = body;
  fetch(url, opts)
    .then(async r => {
      const t = await r.text();
      window.flutter_inappwebview.callHandler(handler, JSON.stringify({ b: t, s: r.status, u: r.url }));
    })
    .catch(() => window.flutter_inappwebview.callHandler(handler, JSON.stringify({ s: 0 })));
})(${jsonEncode(url.toString())}, ${jsonEncode(requestHeaders)}, ${jsonEncode(httpMethod)}, ${jsonEncode(body)}, ${jsonEncode(handlerName)});
''');
      }

      final fetched = await completer.future.timeout(timeout);

      // If the fetch returned a Cloudflare interstitial but we're already
      // viewing that URL, the DOM itself is the solved page — return it
      // instead of the interstitial.
      if (fetched != null && fetched.isBotChallenge && isViewingTarget) {
        try {
          final dom =
              await engine.evaluate('document.documentElement.outerHTML');
          if (dom is String &&
              dom.isNotEmpty &&
              !_isChallengeHtml(dom)) {
            return WebViewFetchResult(
              body: dom,
              status: 200,
              finalUrl: url,
            );
          }
        } on Object {
          // Fall through to return the interstitial (will be discarded upstream
          // and retried via silent fallback / re-verify).
        }
      }

      return fetched;
    } on Object {
      return null;
    } finally {
      engine.removeJsHandler(handlerName);
    }
  }

  static bool _isViewingTarget(Uri current, Uri target) {
    if (current.toString() == target.toString()) return true;
    return current.path == target.path && current.query == target.query;
  }

  static bool _isChallengeHtml(String html) =>
      ChallengeDetector.isChallengeBody(html);

  static WebViewFetchResult? _decodeEnvelope(String raw) {
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final status = map['s'] as num? ?? 0;
      final body = map['b'] as String?;
      final url = map['u'] as String?;
      final isBinary = map['bin'] as bool? ?? false;
      Uint8List? bytes;
      if (isBinary && body != null) {
        try {
          bytes = base64.decode(body);
        } on Object {
          return null;
        }
      }
      return WebViewFetchResult(
        body: isBinary ? null : body,
        bytes: bytes,
        status: status.toInt(),
        finalUrl: url == null ? null : Uri.tryParse(url),
      );
    } catch (_) {
      return null;
    }
  }

  /// Scheme, host and port must match; the page must be viewing the same
  /// origin for a `fetch` to be same-origin (CORS-free). Port check is
  /// lenient — `Uri.port` returns 0 when not explicitly set, but
  /// `https://freewebnovel.com` and `https://freewebnovel.com:443` are the
  /// same origin.
  bool _sameOrigin(Uri a, Uri b) {
    if (a.scheme != b.scheme) return false;
    if (a.host.toLowerCase() != b.host.toLowerCase()) return false;
    final aPort = a.hasPort ? a.port : (a.scheme == 'https' ? 443 : 80);
    final bPort = b.hasPort ? b.port : (b.scheme == 'https' ? 443 : 80);
    return aPort == bPort;
  }
}
