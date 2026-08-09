import 'package:flutter/widgets.dart';

import 'package:atlas_app/browser/domain/entities/web_selection.dart';

/// A message coming back from JavaScript inside the web page.
///
/// Keep this signature free of any engine-specific types so the presentation
/// layer (and tests) never leak plugin details.
typedef JsHandlerCallback = dynamic Function(List<dynamic> arguments);

/// Builds a fresh [BrowserWebEngine]. Shared by providers and controllers so
/// the browser never couples to a specific engine implementation.
typedef BrowserEngineFactory = BrowserWebEngine Function({String? initialUrl});

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

  /// Runs an in-page text search, highlighting the current match and returning
  /// the total number of matches.
  Future<int> search(String query);

  /// Jumps to the next / previous match of the last [search] query.
  Future<bool> findNext();
  Future<bool> findPrevious();

  /// Clears the current find highlight.
  Future<void> clearFind();

  /// Injects (or removes) a dark-mode stylesheet so browsing matches the
  /// reader theme. Stays applied across page loads until disabled.
  Future<void> setDarkMode(bool enabled);

  /// Registers the callback fired whenever the page reports a text selection.
  /// Pass `null` to stop listening. Only the most recent listener is kept.
  Future<void> setSelectionListener(void Function(WebSelection selection)? listener);

  /// Clears the current page selection (also hides any open menu).
  Future<void> clearSelection();

  /// Selects the entire visible page body (drives the "Select all" action).
  Future<void> selectAllInPage();

  /// Registers the callback fired when a downloadable resource is requested
  /// (intercepted epub links today). Pass `null` to stop reporting.
  Future<void> setDownloadListener(
      void Function(String url, String? mimeType)? listener);

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