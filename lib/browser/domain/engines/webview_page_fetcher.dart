import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/core/content_engine/transport/challenge_detector.dart';
import 'package:atlas_app/core/content_engine/transport/webview_fetch_result.dart';
import 'package:atlas_app/core/logging/logger.dart';
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
    Map<String, String>? formBody,
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
        AppLogger.warning(
          'WebViewPageFetcher: handler for $url returned ${raw.runtimeType} '
          'instead of an envelope string',
        );
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
      
      String? body;
      final requestHeaders = <String, String>{...?headers};
      
      if (formBody != null && formBody.isNotEmpty) {
        // Form-encoded POST
        body = formBody.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        if (!requestHeaders.keys.any((k) => k.toLowerCase() == 'content-type')) {
          requestHeaders['Content-Type'] = 'application/x-www-form-urlencoded';
        }
      } else if (jsonBody != null) {
        // JSON POST
        body = jsonEncode(jsonBody);
        if (!requestHeaders.keys.any((k) => k.toLowerCase() == 'content-type')) {
          requestHeaders['Content-Type'] = 'application/json';
        }
      }

      // The result comes back over the `callHandler` round trip, which needs
      // `window.flutter_inappwebview` to exist inside the page. Probe for it in
      // the same evaluate that kicks off the fetch (the IIFE's return value
      // rides back on the evaluateJavascript result, so the probe itself needs
      // no bridge) and fail fast with a clear reason instead of sitting on the
      // full timeout while nothing calls back.
      final probe = await engine.evaluate(
        (binary ? _binaryScript : _textScript)(
          url: url.toString(),
          headers: requestHeaders,
          method: httpMethod,
          body: body,
          handlerName: handlerName,
        ),
      );
      final bridge = _probeResult(probe);
      if (bridge != 'ok') {
        AppLogger.warning(
          'WebViewPageFetcher: JS bridge $bridge for $url — the fetch result '
          'cannot come back, skipping the in-page fetch',
        );
        return null;
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
    } on Object catch (error) {
      // Previously a bare `on Object { return null; }`, which made a missing
      // bridge, a throwing evaluate and an expired timeout indistinguishable
      // from each other — all the caller could see was "fetcher returned null".
      AppLogger.warning(
        'WebViewPageFetcher: in-page fetch failed for $url: $error',
      );
      return null;
    } finally {
      engine.removeJsHandler(handlerName);
    }
  }

  /// Starts the in-page fetch and reports whether the JS bridge it reports
  /// through exists. The IIFE returns `'ok'` or `'no-bridge'`, so a view with no
  /// `window.flutter_inappwebview` is detected instead of silently timing out.
  static String _textScript({
    required String url,
    required Map<String, String> headers,
    required String method,
    required String? body,
    required String handlerName,
  }) => '''
(() => {
  const bridge = window.flutter_inappwebview;
  if (!bridge || typeof bridge.callHandler !== 'function') return 'no-bridge';
  ((url, headers, method, body, handler) => {
    const opts = { method: method, credentials: 'include', headers: headers };
    if (body !== null) opts.body = body;
    fetch(url, opts)
      .then(async r => {
        const t = await r.text();
        bridge.callHandler(handler, JSON.stringify({ b: t, s: r.status, u: r.url }));
      })
      .catch(e => bridge.callHandler(handler, JSON.stringify({ s: 0, e: String(e) })));
  })(${jsonEncode(url)}, ${jsonEncode(headers)}, ${jsonEncode(method)}, ${jsonEncode(body)}, ${jsonEncode(handlerName)});
  return 'ok';
})()
''';

  static String _binaryScript({
    required String url,
    required Map<String, String> headers,
    required String method,
    required String? body,
    required String handlerName,
  }) => '''
(() => {
  const bridge = window.flutter_inappwebview;
  if (!bridge || typeof bridge.callHandler !== 'function') return 'no-bridge';
  ((url, headers, method, body, handler) => {
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
        bridge.callHandler(handler, JSON.stringify({ b: b64, s: r.status, u: r.url, bin: true }));
      })
      .catch(e => bridge.callHandler(handler, JSON.stringify({ s: 0, e: String(e) })));
  })(${jsonEncode(url)}, ${jsonEncode(headers)}, ${jsonEncode(method)}, ${jsonEncode(body)}, ${jsonEncode(handlerName)});
  return 'ok';
})()
''';

  /// Normalizes whatever `evaluateJavascript` handed back for the probe IIFE.
  /// Platforms differ on quoting a returned string, so strip it either way.
  static String _probeResult(Object? raw) {
    final text = raw is String ? raw : raw?.toString() ?? '';
    return text.replaceAll('"', '').replaceAll("'", '').trim();
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
    } on Object catch (error) {
      // A payload that will not parse reaches the caller as a bare `null`,
      // which is indistinguishable from "the handler never fired". Log enough
      // to tell a truncated/corrupted round trip (large page bodies are the
      // suspect) apart from a genuinely absent result.
      AppLogger.warning(
        'WebViewPageFetcher: could not decode the fetch envelope '
        '($error); len=${raw.length}, starts=${_preview(raw)}',
      );
      return null;
    }
  }

  static String _preview(String raw) =>
      raw.length <= 80 ? raw : '${raw.substring(0, 80)}...';

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
