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