import 'package:atlas_app/browser/domain/entities/web_bookmark.dart';
import 'package:atlas_app/browser/domain/entities/web_history_entry.dart';
import 'package:atlas_app/browser/domain/entities/web_tab_state.dart';
import 'package:atlas_app/core/error_handling/result.dart';

abstract interface class BrowserRepositoryInterface {
  Future<Result<List<WebHistoryEntry>>> getAllHistory({int limit = 50});
  Stream<Result<List<WebHistoryEntry>>> watchHistory({int limit = 50});
  Future<Result<void>> recordVisit({
    required String url,
    String? title,
    DateTime? visitedAt,
  });
  Future<Result<void>> clearHistory();

  Future<Result<List<BrowserBookmark>>> getAllBookmarks();
  Stream<Result<List<BrowserBookmark>>> watchBookmarks();
  Future<Result<void>> addBookmark(BrowserBookmark bookmark);
  Future<Result<void>> removeBookmark(String bookmarkId);

  Future<Result<List<WebTabState>>> getTabs();
  Future<Result<void>> upsertTab(WebTabState tab);
  Future<Result<void>> removeTab(String tabId);
  Future<Result<void>> clearTabs();
}
