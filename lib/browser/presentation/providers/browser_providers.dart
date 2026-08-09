import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/infrastructure/engines/inapp_webview_engine.dart';

/// Landing URL shown before the browser's own start page exists. Phase 1 swaps
/// this for the native catalog/start screen.
const String kBrowserDefaultHomeUrl = 'https://www.gutenberg.org';

typedef BrowserEngineFactory = BrowserWebEngine Function({String? initialUrl});

/// Creates a fresh [BrowserWebEngine] per browser session. Overridable in tests
/// to inject a fake engine.
final browserEngineFactoryProvider = Provider<BrowserEngineFactory>((ref) {
  return ({String? initialUrl = kBrowserDefaultHomeUrl}) =>
      InappWebviewEngine(initialUrl: initialUrl);
});