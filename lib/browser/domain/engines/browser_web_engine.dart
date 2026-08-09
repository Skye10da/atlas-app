import 'package:flutter/widgets.dart';

/// A message coming back from JavaScript inside the web page.
///
/// Keep this signature free of any engine-specific types so the presentation
/// layer (and tests) never leak plugin details.
typedef JsHandlerCallback = dynamic Function(List<dynamic> arguments);

/// Contract between the browser UI and the underlying web engine.
///
/// Mirrors the `PlatformService` seam: the UI drives navigation and reads state
/// through this interface while the concrete engine (flutter_inappwebview) is
/// confined to `infrastructure/`.
abstract interface class BrowserWebEngine {
  /// Most recently committed URL.
  ValueNotifier<String?> get currentUrl;

  /// Best-effort document title.
  ValueNotifier<String?> get currentTitle;

  /// Page load progress in the range 0..1.
  ValueNotifier<double> get progress;

  ValueNotifier<bool> get canGoBack;
  ValueNotifier<bool> get canGoForward;
  ValueNotifier<bool> get isLoading;

  /// Navigates [url], prepending `https://` when no scheme is present.
  Future<void> load(String url);

  Future<void> goBack();
  Future<void> goForward();
  Future<void> reload();
  Future<void> stop();

  /// Evaluates an arbitrary JS expression and returns its JSON-serializable
  /// result (or `null` when the engine cannot produce a value).
  Future<dynamic> evaluate(String script);

  /// Registers a handler that becomes callable from page JS as
  /// `window.flutter_inappwebview.callHandler(name, ...args)`.
  void addJsHandler(String name, JsHandlerCallback handler);

  void removeJsHandler(String name);

  /// Builds the actual web view widget. The engine wires every plugin callback
  /// back into its own state notifiers.
  Widget buildView();

  /// Releases engine-owned resources (listeners, native web view state).
  void dispose();
}