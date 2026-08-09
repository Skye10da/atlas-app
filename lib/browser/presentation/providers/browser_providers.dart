import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/entities/web_bookmark.dart';
import 'package:atlas_app/browser/domain/entities/web_history_entry.dart';
import 'package:atlas_app/browser/domain/repository_interfaces/browser_repository_interface.dart';
import 'package:atlas_app/browser/infrastructure/engines/inapp_webview_engine.dart';
import 'package:atlas_app/browser/infrastructure/repositories/drift_browser_repository.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';

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

/// Drift-backed persistence for history, favorites and tabs.
final browserRepositoryProvider =
    Provider<BrowserRepositoryInterface>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftBrowserRepository(db);
});

final webHistoryProvider = StreamProvider<List<WebHistoryEntry>>((ref) {
  return ref
      .watch(browserRepositoryProvider)
      .watchHistory()
      .map((result) => switch (result) {
            Success(value: final history) => history,
            Failure() => <WebHistoryEntry>[],
          });
});

final webBookmarksProvider = StreamProvider<List<BrowserBookmark>>((ref) {
  return ref
      .watch(browserRepositoryProvider)
      .watchBookmarks()
      .map((result) => switch (result) {
            Success(value: final bookmarks) => bookmarks,
            Failure() => <BrowserBookmark>[],
          });
});