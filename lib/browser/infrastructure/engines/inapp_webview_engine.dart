import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/utils/browser_url.dart';

/// flutter_inappwebview-backed [BrowserWebEngine].
///
/// All plugin callbacks cross into state notifiers here so the widget layer
/// only ever speaks the abstract contract.
class InappWebviewEngine implements BrowserWebEngine {
  InappWebviewEngine({this.initialUrl});

  /// URL loaded the moment the web view is created.
  final String? initialUrl;

  InAppWebViewController? _controller;

  final _currentUrl = ValueNotifier<String?>(null);
  final _currentTitle = ValueNotifier<String?>(null);
  final _progress = ValueNotifier<double>(0);
  final _canGoBack = ValueNotifier<bool>(false);
  final _canGoForward = ValueNotifier<bool>(false);
  final _isLoading = ValueNotifier<bool>(false);

  final Map<String, JsHandlerCallback> _jsHandlers = {};

  @override
  ValueNotifier<String?> get currentUrl => _currentUrl;

  @override
  ValueNotifier<String?> get currentTitle => _currentTitle;

  @override
  ValueNotifier<double> get progress => _progress;

  @override
  ValueNotifier<bool> get canGoBack => _canGoBack;

  @override
  ValueNotifier<bool> get canGoForward => _canGoForward;

  @override
  ValueNotifier<bool> get isLoading => _isLoading;

  @override
  void dispose() {
    // The InAppWebView widget owns the native platform lifecycle, so we only
    // release our own state notifiers here.
    for (final notifier in <ValueNotifier<Object?>>[
      _currentUrl,
      _currentTitle,
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
    final controller = _controller;
    if (controller == null) return;
    final normalized = normalizeBrowserUrl(url);
    if (normalized.isEmpty) return;
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(normalized)),
    );
  }

  @override
  Future<void> goBack() async => await _controller?.goBack();

  @override
  Future<void> goForward() async => await _controller?.goForward();

  @override
  Future<void> reload() async => await _controller?.reload();

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
    final script = '''
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
    final script = '''
(() => { return window.find($escaped, false, false, ${backward ? 'true' : 'false'}, false); })()
''';
    final result = await _controller?.evaluateJavascript(source: script);
    return result == true;
  }

  @override
  Future<void> clearFind() async {
    _findQuery = null;
    await _controller?.evaluateJavascript(
      source: '(() => { window.getSelection().removeAllRanges(); return true; })()',
    );
  }

  bool _darkModeEnabled = false;

  @override
  Future<void> setDarkMode(bool enabled) async {
    if (_darkModeEnabled == enabled) return;
    _darkModeEnabled = enabled;
    await _applyDarkMode();
  }

  Future<void> _applyDarkMode() async {
    final controller = _controller;
    if (controller == null) return;
    final script = _darkModeEnabled
        ? _kDarkModeInjectScript
        : _kDarkModeRemoveScript;
    await controller.evaluateJavascript(source: script);
  }

  static const _kDarkModeInjectScript = '''
(() => {
  document.getElementById('atlas-dark-css')?.remove();
  const meta = document.createElement('meta');
  meta.name = 'color-scheme';
  meta.content = 'dark';
  document.head.appendChild(meta);
  const style = document.createElement('style');
  style.id = 'atlas-dark-css';
  style.textContent = [
    'html { filter: invert(0.92) hue-rotate(180deg) !important; background: #0f1115 !important; }',
    'img, video, picture, canvas, iframe, svg image, [style*="background-image"], [class*="logo"], [class*="avatar"], [class*="thumb"] { filter: invert(0.92) hue-rotate(180deg) !important; }',
  ].join('\\n');
  document.head.appendChild(style);
  document.documentElement.style.colorScheme = 'dark';
})()
''';

  static const _kDarkModeRemoveScript = '''
(() => {
  document.getElementById('atlas-dark-css')?.remove();
  document.documentElement.style.colorScheme = '';
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
return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(initialUrl ?? 'about:blank')),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        useShouldOverrideUrlLoading: true,
        useOnDownloadStart: true,
      ),
      onWebViewCreated: _onWebViewCreated,
      onLoadStart: (controller, url) {
        _isLoading.value = true;
        if (url != null) _currentUrl.value = url.toString();
        _refreshNavState();
      },
      onLoadStop: (controller, url) {
        _isLoading.value = false;
        _progress.value = 1;
        _refreshNavState();
        if (_darkModeEnabled) _applyDarkMode();
      },
      onProgressChanged: (controller, progress) {
        _progress.value = progress / 100.0;
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        if (url != null) _currentUrl.value = url.toString();
        _refreshNavState();
      },
      onTitleChanged: (controller, title) {
        if (title != null && title.isNotEmpty) _currentTitle.value = title;
      },
      shouldOverrideUrlLoading: (controller, action) async {
        return NavigationActionPolicy.ALLOW;
      },
    );
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    for (final entry in _jsHandlers.entries) {
      controller.addJavaScriptHandler(
        handlerName: entry.key,
        callback: entry.value,
      );
    }
    _refreshNavState();
  }

  Future<void> _refreshNavState() async {
    final controller = _controller;
    if (controller == null) return;
    _canGoBack.value = await controller.canGoBack();
    _canGoForward.value = await controller.canGoForward();
  }
}