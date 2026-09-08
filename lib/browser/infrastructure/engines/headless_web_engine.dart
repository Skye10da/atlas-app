// ignore_for_file: unawaited_futures
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/entities/web_selection.dart';

/// A [BrowserWebEngine] implementation backed by [HeadlessInAppWebView].
///
/// Operates completely headlessly without requiring any widget in the Flutter
/// widget tree, eliminating off-screen 1x1 pixel layout hacks.
class HeadlessWebEngine implements BrowserWebEngine {
  HeadlessWebEngine({this.initialUrl});

  final String? initialUrl;
  HeadlessInAppWebView? _headless;
  InAppWebViewController? _controller;
  Completer<void>? _initCompleter;
  bool _disposed = false;

  final _currentUrl = ValueNotifier<String?>(null);
  final _currentTitle = ValueNotifier<String?>(null);
  final _lastError = ValueNotifier<String?>(null);
  final _progress = ValueNotifier<double>(0);
  final _canGoBack = ValueNotifier<bool>(false);
  final _canGoForward = ValueNotifier<bool>(false);
  final _isLoading = ValueNotifier<bool>(false);

  final Map<String, JsHandlerCallback> _jsHandlers = {};

  Future<void> _ensureInitialized() async {
    if (_disposed) return;
    if (_initCompleter != null) return _initCompleter!.future;

    // On Windows, WebView2 requires COM to be initialized and the Flutter
    // engine's platform views to be ready. Creating HeadlessInAppWebView
    // too early (e.g. during provider init or hot reload) throws
    // `CoInitialize has not been called` / `CustomPlatformView` errors.
    // Defer creation to the next frame and retry once instead of failing
    // fast — this lets the visible WebView2 host initialize and then
    // allows Cloudflare challenges to be solved headlessly on Windows as well.
    if (!kIsWeb && Platform.isWindows) {
      // Wait for the next frame so the engine's platform view registry
      // has called CoInitialize on the UI thread. Use a completer + timeout
      // so tests (no frames) don't hang.
      try {
        final frameCompleter = Completer<void>();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => frameCompleter.complete(),
        );
        await Future.any<void>([
          frameCompleter.future,
          Future<void>.delayed(const Duration(milliseconds: 150)),
        ]);
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    final completer = Completer<void>();
    _initCompleter = completer;
    // Retry once on Windows CoInitialize race — first `run()` often throws
    // `PlatformException(CoInitialize)` even after the frame delay.
    var attempts = (!kIsWeb && Platform.isWindows) ? 2 : 1;
    Object? lastError;
    while (attempts-- > 0) {
      try {
        _headless = HeadlessInAppWebView(
          initialUrlRequest: initialUrl != null
              ? URLRequest(url: WebUri(initialUrl!))
              : null,
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            isInspectable: false,
            cacheEnabled: true,
          ),
          onLoadStart: (controller, url) {
            _isLoading.value = true;
            _currentUrl.value = url?.toString();
          },
          onLoadStop: (controller, url) {
            _isLoading.value = false;
            _currentUrl.value = url?.toString();
          },
          onReceivedError: (controller, request, error) {
            _isLoading.value = false;
            _lastError.value = error.description;
          },
          onProgressChanged: (controller, progress) {
            _progress.value = progress / 100.0;
          },
          onTitleChanged: (controller, title) {
            _currentTitle.value = title;
          },
        );

        await _headless!.run();
        _controller = _headless!.webViewController;

        for (final entry in _jsHandlers.entries) {
          _controller?.addJavaScriptHandler(
            handlerName: entry.key,
            callback: entry.value,
          );
        }
        completer.complete();
        return completer.future;
      } catch (e) {
        lastError = e;
        try {
          _headless?.dispose();
        } catch (_) {}
        _headless = null;
        _controller = null;
        if (_isWindowsException(e) && attempts > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          continue;
        }
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
        break;
      }
    }
    if (lastError != null && !completer.isCompleted) {
      completer.completeError(lastError);
    }
    return completer.future;
  }

  bool _isWindowsException(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('coinit') ||
        msg.contains('coinitialize') ||
        msg.contains('customplatformview') ||
        msg.contains('inappwebview');
  }

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

  @override
  Future<void> load(String url) async {
    await _ensureInitialized();
    final target = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : 'https://$url';
    _isLoading.value = true;
    await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
  }

  @override
  Future<dynamic> evaluate(String script) async {
    await _ensureInitialized();
    return _controller?.evaluateJavascript(source: script);
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
  Future<void> goHome() async {}
  @override
  Future<void> goBack() async => _controller?.goBack();
  @override
  Future<void> goForward() async => _controller?.goForward();
  @override
  Future<void> reload() async => _controller?.reload();
  @override
  Future<void> stop() async => _controller?.stopLoading();
  @override
  Future<int> search(String query) async => 0;
  @override
  Future<bool> findNext() async => false;
  @override
  Future<bool> findPrevious() async => false;
  @override
  Future<void> clearFind() async {}
  @override
  Future<void> setSelectionListener(
    void Function(WebSelection selection)? listener,
  ) async {}
  @override
  Future<void> clearSelection() async {}
  @override
  Future<void> selectAllInPage() async {}
  @override
  Future<void> setDownloadListener(
    void Function(String url, String? mimeType)? listener,
  ) async {}

  @override
  Widget buildView() => const SizedBox.shrink();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _headless?.dispose();
    _headless = null;
    _controller = null;
    _currentUrl.dispose();
    _currentTitle.dispose();
    _lastError.dispose();
    _progress.dispose();
    _canGoBack.dispose();
    _canGoForward.dispose();
    _isLoading.dispose();
  }
}

