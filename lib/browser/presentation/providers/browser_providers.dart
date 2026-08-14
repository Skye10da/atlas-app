import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/entities/web_bookmark.dart';
import 'package:atlas_app/browser/domain/entities/web_history_entry.dart';
import 'package:atlas_app/browser/domain/repository_interfaces/browser_repository_interface.dart';
import 'package:atlas_app/browser/domain/repository_interfaces/browser_session_repository_interface.dart';
import 'package:atlas_app/browser/infrastructure/engines/inapp_webview_engine.dart';
import 'package:atlas_app/browser/infrastructure/repositories/drift_browser_repository.dart';
import 'package:atlas_app/browser/infrastructure/repositories/json_browser_session_repository.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';

/// Creates a fresh [BrowserWebEngine] per browser session. Overridable in tests
/// to inject a fake engine. Callers always pass `initialUrl` (explicitly,
/// including `null` for start-page tabs).
final browserEngineFactoryProvider = Provider<BrowserEngineFactory>((ref) {
  return ({String? initialUrl}) => InappWebviewEngine(initialUrl: initialUrl);
});

/// Drift-backed persistence for history, favorites and tabs.
final browserRepositoryProvider =
    Provider<BrowserRepositoryInterface>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftBrowserRepository(db);
});

/// JSON-backed persistence for per-origin WebView cookies, seeded back into
/// the platform store by the silent background web view before it navigates a
/// protected origin after a restart.
final browserSessionRepositoryProvider =
    Provider<BrowserSessionRepositoryInterface>((ref) {
  return JsonBrowserSessionRepository();
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