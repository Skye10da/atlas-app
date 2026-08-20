import 'dart:collection';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/entities/web_selection.dart';
import 'package:atlas_app/browser/domain/utils/browser_url.dart';

/// flutter_inappwebview-backed [BrowserWebEngine].
///
/// All plugin callbacks cross into state notifiers here so the widget layer
/// only ever speaks the abstract contract.
class InappWebviewEngine implements BrowserWebEngine {
  InappWebviewEngine({this.initialUrl}) {
    _disableDebugLogging();
  }

  /// The plugin's channel-event debug logging is a static, process-wide
  /// switch (`PlatformInAppWebViewController.debugLoggingSettings`), not a
  /// per-widget setting — there is no `debugLoggingSettings` parameter on
  /// [InAppWebViewSettings] or [InAppWebView]. Left enabled (its default is
  /// `kDebugMode`), every plugin channel event — including each page
  /// `console.*` call — gets formatted and pushed through `developer.log`,
  /// adding measurable per-event overhead on busy pages. Disabled here for
  /// both the overhead and to keep release/dev behavior identical. Guarded so
  /// it only runs once regardless of how many tabs/engines get created.
  static bool _debugLoggingDisabled = false;
  static void _disableDebugLogging() {
    if (_debugLoggingDisabled) return;
    _debugLoggingDisabled = true;
    PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
  }

  /// URL loaded the moment the web view is created.
  final String? initialUrl;

  /// URL requested via [load] before the web view was attached. Consumed as
  /// the initial request when [buildView] first mounts the view.
  String? _pendingUrl;

  InAppWebViewController? _controller;

  bool _disposed = false;

  final _currentUrl = ValueNotifier<String?>(null);
  final _currentTitle = ValueNotifier<String?>(null);
  final _lastError = ValueNotifier<String?>(null);
  final _progress = ValueNotifier<double>(0);
  final _canGoBack = ValueNotifier<bool>(false);
  final _canGoForward = ValueNotifier<bool>(false);
  final _isLoading = ValueNotifier<bool>(false);

  /// URL of the last document that finished loading. Drives the error banner's
  /// frame/URL awareness: when a navigation to a *different* URL fails while a
  /// page is committed, the old document is still on screen (WebView2/Android
  /// keep it after a failed main-frame load), so that failure is a background
  /// probe — not the page the user is looking at.
  String? _lastLoadedUrl;

  final Map<String, JsHandlerCallback> _jsHandlers = {};

  /// Most recent main-frame load attempts keyed by URL (epoch ms). Some
  /// sites (e.g. mvlempyr) run anti-devtools / anti-bot scripts that detect
  /// the embedded WebView2 and answer with an endless `location.reload()`
  /// loop, which pegs the renderer and freezes the whole window. This backs a
  /// `shouldOverrideUrlLoading` burst guard that cancels those reloads.
  final Map<String, List<int>> _recentLoadAttempts = {};

  @override
  ValueNotifier<String?> get currentUrl => _currentUrl;

  @override
  ValueNotifier<String?> get currentTitle => _currentTitle;

  @override
  ValueNotifier<String?> get lastError => _lastError;

  @override
  ValueNotifier<double> get progress => _progress;

  @override
  ValueNotifier<bool> get canGoBack => _canGoBack;

  @override
  ValueNotifier<bool> get canGoForward => _canGoForward;

  @override
  ValueNotifier<bool> get isLoading => _isLoading;

  /// Builds a [WebUri] only when [url] is parseable and, for non-`about:`
  /// schemes, carries a real host. Returns null for malformed input so callers
  /// can fall back without a `FormatException`.
  static WebUri? _tryWebUri(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null) return null;
    if (parsed.scheme == 'about') return WebUri(url);
    if (parsed.host.isEmpty) return null;
    return WebUri(url);
  }

  @override
  void dispose() {
    // The InAppWebView widget owns the native platform lifecycle, so we only
    // release our own state notifiers here. Null the controller and pending
    // URL so late plugin callbacks and pre-attach loads cannot touch disposed
    // state; the _disposed flag stops in-flight platform callbacks from
    // writing to released notifiers.
    _disposed = true;
    _controller = null;
    _pendingUrl = null;
    for (final notifier in <ValueNotifier<Object?>>[
      _currentUrl,
      _currentTitle,
      _lastError,
      _progress,
      _canGoBack,
      _canGoForward,
      _isLoading,
    ]) {
      notifier.dispose();
    }
  }

  @override
  Future<void> load(String url) async {
    if (_disposed) return;
    final normalized = normalizeBrowserUrl(url);
    if (normalized.isEmpty) return;
    final uri = _tryWebUri(normalized);
    if (uri == null) return;
    // Explicit user navigation, so any residual anti-bot reload burst for the
    // same URL must not be counted against this fresh load.
    _recentLoadAttempts.remove(normalized);
    // This navigation is the page the user asked for: forget the last
    // committed document so a failure here surfaces as a real error instead of
    // being mistaken for a background probe.
    _lastLoadedUrl = null;
    final controller = _controller;
    if (controller == null) {
      _pendingUrl = normalized;
      return;
    }
    await controller.loadUrl(urlRequest: URLRequest(url: uri));
  }

  @override
  Future<void> goHome() async {
    if (_disposed) return;
    // Enter new-tab state synchronously: an `about:blank` load callback is not
    // guaranteed on every engine, and the start-page overlay only shows while
    // currentUrl is the sentinel. Then reconcile the view to a fresh blank
    // document so the previous page can't squat underneath the start page.
    _currentUrl.value = kBrowserStartPageUrl;
    _isLoading.value = false;
    _lastError.value = null;
    _lastLoadedUrl = null;
    _progress.value = 0;
    final controller = _controller;
    if (controller == null) return;
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri('about:blank')),
    );
  }

  @override
  Future<void> goBack() async => await _controller?.goBack();

  @override
  Future<void> goForward() async => await _controller?.goForward();

  @override
  Future<void> reload() async {
    // A reload is the user telling the engine "show me this page again"; if it
    // fails, that is a real failure of the page under the cursor.
    _lastLoadedUrl = null;
    await _controller?.reload();
  }

  @override
  Future<void> stop() async => await _controller?.stopLoading();

  @override
  Future<dynamic> evaluate(String script) async {
    final controller = _controller;
    if (controller == null) return null;
    return controller.evaluateJavascript(source: script);
  }

  String? _findQuery;

  @override
  Future<int> search(String query) async {
    _findQuery = query;
    final escaped = jsonEncode(query);
    final script =
        '''
(() => {
  const q = $escaped;
  if (!q) return 0;
  const text = document.body ? document.body.innerText : '';
  const lower = text.toLowerCase();
  const needle = q.toLowerCase();
  let count = 0, idx = 0;
  while (lower.indexOf(needle, idx) !== -1) { count++; idx = lower.indexOf(needle, idx) + needle.length; }
  window.find(q, false, false, false, false);
  window.scrollBy(0, -120);
  return count;
})()
''';
    final result = await _controller?.evaluateJavascript(source: script);
    if (result is num) return result.toInt();
    return 0;
  }

  @override
  Future<bool> findNext() => _findDirection(backward: false);

  @override
  Future<bool> findPrevious() => _findDirection(backward: true);

  Future<bool> _findDirection({required bool backward}) async {
    final query = _findQuery;
    if (query == null || query.isEmpty) return false;
    final escaped = jsonEncode(query);
    final script =
        '''
(() => { return window.find($escaped, false, ${backward ? 'true' : 'false'}, false, false); })()
''';
    final result = await _controller?.evaluateJavascript(source: script);
    return result == true;
  }

  @override
  Future<void> clearFind() async {
    _findQuery = null;
    await _controller?.evaluateJavascript(
      source:
          '(() => { window.getSelection().removeAllRanges(); return true; })()',
    );
  }

  static const _kSelectionHandlerName = 'atlasSelection';
  void Function(WebSelection)? _selectionListener;

  @override
  Future<void> setSelectionListener(
    void Function(WebSelection)? listener,
  ) async {
    _selectionListener = listener;
    if (listener == null) {
      _controller?.removeJavaScriptHandler(handlerName: _kSelectionHandlerName);
    } else if (_controller != null) {
      _registerSelectionHandler(_controller!);
    }
  }

  void _registerSelectionHandler(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: _kSelectionHandlerName,
      callback: (arguments) {
        final raw = arguments.isNotEmpty ? arguments.first : null;
        final selection = _selectionFromPayload(raw);
        if (selection != null && !selection.isEmpty) {
          _selectionListener?.call(selection);
        }
        return null;
      },
    );
  }

  static WebSelection? _selectionFromPayload(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return WebSelection(
        text: (map['text'] as String? ?? ''),
        x1: (map['x1'] as num? ?? 0).toDouble(),
        y1: (map['y1'] as num? ?? 0).toDouble(),
        x2: (map['x2'] as num? ?? 0).toDouble(),
        y2: (map['y2'] as num? ?? 0).toDouble(),
        language: map['lang'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearSelection() async {
    await _controller?.evaluateJavascript(
      source:
          '(() => { window.getSelection().removeAllRanges(); return true; })()',
    );
  }

  @override
  Future<void> selectAllInPage() async {
    await _controller?.evaluateJavascript(
      source: '(() => { document.execCommand("selectAll"); return true; })()',
    );
  }

  Future<void> _injectSelectionBridge() async {
    final controller = _controller;
    if (_disposed || controller == null) return;
    if (_selectionListener != null) {
      _registerSelectionHandler(controller);
    }
    await controller.evaluateJavascript(source: _kSelectionBridgeScript);
  }

  void Function(String url, String? mimeType)? _downloadListener;

  @override
  Future<void> setDownloadListener(
    void Function(String url, String? mimeType)? listener,
  ) async {
    _downloadListener = listener;
  }

  static const _kSelectionBridgeScript = '''
(() => {
  if (window.__atlasSelectionInjected) return;
  window.__atlasSelectionInjected = true;
  let lastText = '';
  document.addEventListener('selectionchange', () => {
    // Stamp on every event, select AND deselect — closing the context menu
    // collapses the selection and can trigger the same hound reaction as
    // opening it, so the reload guard needs to cover both.
    window.__atlasSelectionSentAt = Date.now();

    const sel = window.getSelection();
    if (!sel || !sel.rangeCount || sel.isCollapsed) { lastText = ''; return; }
    const text = sel.toString();
    if (!text || text.length === 0 || text.length > 5000) { lastText = ''; return; }
    if (text === lastText) return;
    lastText = text;
    const r = sel.getRangeAt(0).getBoundingClientRect();
    flutter_inappwebview.callHandler('atlasSelection', JSON.stringify({
      text: text,
      x1: r.left, y1: r.top, x2: r.right, y2: r.bottom,
      lang: document.documentElement.lang || ''
    }));
  });
})()
''';

  /// Injected at document start to pacify anti-devtools / anti-bot hounds
  /// (e.g. mvlempyr) that detect the embedded WebView2 and answer with an
  /// endless `location.reload()` loop, which pegs the renderer and freezes
  /// the whole window. Only *script-initiated* reloads of the current URL are
  /// suppressed — the toolbar/engine reload goes through the native WebView2
  /// API and the Dart burst guard takes over if a page still finds a way
  /// around this. Suppression kicks in for (a) reload bursts (2+ in 2s, then
  /// locked for 3s) and (b) any scripted reload shortly after our selection
  /// bridge posts a message — the hound reloads in reaction to that message,
  /// and without this the page refreshes every time the context menu opens.
  static const _kReloadGuardScript = '''
(() => {
  if (window.__atlasReloadGuard) return;
  window.__atlasReloadGuard = true;
  try {
    if (window.console) {
      const noop = function () {};
      for (const k of ['clear', 'log', 'debug', 'info']) {
        if (typeof window.console[k] === 'function') window.console[k] = noop;
      }
    }
  } catch (_) {}
  let prev = 0;
  let hits = 0;
  let lockedUntil = 0;
  const burst = () => {
    const now = Date.now();
    if (now - prev > 2000) hits = 0;
    prev = now;
    hits++;
    if (hits > 1) lockedUntil = now + 3000;
    return now < lockedUntil || hits > 1;
  };
  const bridgeActive = () => {
    const at = window.__atlasSelectionSentAt || 0;
    return Date.now() - at < 2000;
  };
  const blocked = () => bridgeActive() || burst();
  try {
    const proto = Location.prototype;
    const origReload = proto.reload;
    Object.defineProperty(proto, 'reload', {
      configurable: true,
      writable: true,
      value: function () {
        if (blocked()) return;
        return origReload.call(this);
      },
    });
    const origAssign = proto.assign;
    Object.defineProperty(proto, 'assign', {
      configurable: true,
      writable: true,
      value: function (url) {
        if (typeof url === 'string' && url === String(window.location.href)) {
          if (blocked()) return;
        }
        return origAssign.call(this, url);
      },
    });
    const hrefDesc = Object.getOwnPropertyDescriptor(proto, 'href');
    if (hrefDesc && hrefDesc.set) {
      const origSet = hrefDesc.set;
      Object.defineProperty(proto, 'href', {
        configurable: true,
        enumerable: hrefDesc.enumerable,
        get: hrefDesc.get,
        set: function (url) {
          if (String(url) === String(window.location.href) && blocked()) return;
          return origSet.call(this, url);
        },
      });
    }
  } catch (_) {}
})()
''';

  @override
  void addJsHandler(String name, JsHandlerCallback handler) {
    _jsHandlers[name] = handler;
    _controller?.addJavaScriptHandler(handlerName: name, callback: handler);
  }

  @override
  void removeJsHandler(String name) {
    _jsHandlers.remove(name);
    _controller?.removeJavaScriptHandler(handlerName: name);
  }

  @override
  Widget buildView() {
    final pending = _pendingUrl ?? initialUrl;
    final safeInitial = pending == null
        ? 'about:blank'
        : (_tryWebUri(pending)?.toString() ?? 'about:blank');
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(safeInitial)),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: _kReloadGuardScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        useShouldOverrideUrlLoading: true,
        useOnDownloadStart: true,
        disableContextMenu: true,
        disabledActionModeMenuItems: ActionModeMenuItem
            .MENU_ITEM_SHARE, // suppresses the Action Mode bar itself
      ),
      onReceivedError: (controller, request, error) {
        if (_disposed) return;
        // Aborted/canceled main-frame navigations — a user stop, a burst-guard
        // cancel, or the anti-bot reload hound reloading the page — abort the
        // in-flight load by design. Not a page failure.
        final type = error.type;
        if (type == WebResourceErrorType.CONNECTION_ABORTED ||
            type == WebResourceErrorType.CANCELLED) {
          return;
        }
        final failedUrl = request.url.toString();
        if (failedUrl.isEmpty) return;
        // The engines keep the last committed document on screen when a
        // *different* URL fails, so a failed navigation here is a background
        // probe (anti-bot redirect/DNS hound) while the page the user is
        // looking at is fine. Restore the committed URL and stay silent rather
        // than banner a fully-loaded page.
        final committed = _lastLoadedUrl;
        final isBackgroundFailure =
            committed != null &&
            committed != kBrowserStartPageUrl &&
            failedUrl != committed;
        if (isBackgroundFailure) {
          _currentUrl.value = committed;
          return;
        }
        final detail = error.description.trim();
        _lastError.value =
            'Could not load this page'
            '${detail.isEmpty ? '' : ': $detail'}';
      },
      onWebViewCreated: _onWebViewCreated,
      onLoadStart: (controller, url) {
        if (_disposed) return;
        _isLoading.value = true;
        _lastError.value = null;
        if (url != null) _currentUrl.value = url.toString();
        _refreshNavState();
      },
      onLoadStop: (controller, url) {
        if (_disposed) return;
        _isLoading.value = false;
        _progress.value = 1;
        // A document committed successfully, so whatever the last failed
        // navigation was, a real page is now showing.
        _lastLoadedUrl = url?.toString();
        _lastError.value = null;
        _refreshNavState();
        _injectSelectionBridge();
      },
      onProgressChanged: (controller, progress) {
        if (_disposed) return;
        _progress.value = progress / 100.0;
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        if (_disposed) return;
        if (url != null) _currentUrl.value = url.toString();
        _refreshNavState();
      },
      onTitleChanged: (controller, title) {
        if (_disposed) return;
        if (title != null && title.isNotEmpty) _currentTitle.value = title;
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final url = action.request.url?.toString();
        if (url != null &&
            action.isForMainFrame &&
            (looksLikeEpubUrl(url) || looksLikePdfUrl(url))) {
          final isPdf = looksLikePdfUrl(url);
          _downloadListener?.call(url, isPdf ? 'application/pdf' : null);
          return NavigationActionPolicy.CANCEL;
        }
        if (url != null && action.isForMainFrame) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final attempts = _recentLoadAttempts.putIfAbsent(url, () => [])
            ..add(now);
          attempts.removeWhere((t) => now - t > 2000);
          if (attempts.isEmpty) {
            _recentLoadAttempts.remove(url);
          }
          if (attempts.length >= 3) {
            // Same main-frame URL requested 3+ times inside 2s: the anti-bot
            // reload hound struck. Cancel so the renderer settles instead of
            // spinning the page in a freeze loop. Fresh user navigations clear
            // this window in [load].
            return NavigationActionPolicy.CANCEL;
          }
        }
        return NavigationActionPolicy.ALLOW;
      },
    );
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    if (_disposed) return;
    _controller = controller;
    _pendingUrl = null;
    for (final entry in _jsHandlers.entries) {
      controller.addJavaScriptHandler(
        handlerName: entry.key,
        callback: entry.value,
      );
    }
    _injectSelectionBridge();
    _refreshNavState();
  }

  Future<void> _refreshNavState() async {
    final controller = _controller;
    if (_disposed || controller == null) return;
    _canGoBack.value = await controller.canGoBack();
    _canGoForward.value = await controller.canGoForward();
  }
}
