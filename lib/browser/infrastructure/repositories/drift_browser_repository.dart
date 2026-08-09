import 'package:drift/drift.dart';

import 'package:atlas_app/browser/domain/entities/web_bookmark.dart';
import 'package:atlas_app/browser/domain/entities/web_history_entry.dart';
import 'package:atlas_app/browser/domain/entities/web_tab_state.dart';
import 'package:atlas_app/browser/domain/repository_interfaces/browser_repository_interface.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';

class DriftBrowserRepository implements BrowserRepositoryInterface {
  const DriftBrowserRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<List<WebHistoryEntry>>> getAllHistory({int limit = 50}) async {
    try {
      final rows = await (_db.select(_db.webHistory)
            ..orderBy([(h) => OrderingTerm.desc(h.visitedAt)])
            ..limit(limit))
          .get();
      return Success(rows.map(_historyFrom).toList());
    } catch (e, st) {
      return Failure(DatabaseException('Failed to load web history', e), st);
    }
  }

  @override
  Stream<Result<List<WebHistoryEntry>>> watchHistory({int limit = 50}) {
    return (_db.select(_db.webHistory)
          ..orderBy([(h) => OrderingTerm.desc(h.visitedAt)])
          ..limit(limit))
        .watch()
        .map((rows) => Success(rows.map(_historyFrom).toList()));
  }

  @override
  Future<Result<void>> recordVisit({
    required String url,
    String? title,
    DateTime? visitedAt,
  }) async {
    try {
      final trimmedUrl = url.trim();
      if (trimmedUrl.isEmpty || trimmedUrl == 'about:blank') {
        return const Success(null);
      }
      final now = visitedAt ?? DateTime.now();
      final latest = await (_db.select(_db.webHistory)
            ..orderBy([(h) => OrderingTerm.desc(h.visitedAt)])
            ..limit(1))
          .getSingleOrNull();

      if (latest != null && latest.url == trimmedUrl) {
        await (_db.update(_db.webHistory)..where((h) => h.id.equals(latest.id))).write(
          WebHistoryCompanion(
            title: title != null ? Value(title) : const Value.absent(),
            visitedAt: Value(now),
          ),
        );
        return const Success(null);
      }

      final id = '$trimmedUrl#${now.microsecondsSinceEpoch}';
      await _db.into(_db.webHistory).insert(
            WebHistoryCompanion.insert(
              id: id,
              url: trimmedUrl,
              title: Value(title),
              visitedAt: now,
            ),
          );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to record web visit', e), st);
    }
  }

  @override
  Future<Result<void>> clearHistory() async {
    try {
      await _db.delete(_db.webHistory).go();
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to clear web history', e), st);
    }
  }

  @override
  Future<Result<List<BrowserBookmark>>> getAllBookmarks() async {
    try {
      final rows = await (_db.select(_db.webBookmarks)
            ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
          .get();
      return Success(rows.map(_bookmarkFrom).toList());
    } catch (e, st) {
      return Failure(DatabaseException('Failed to load web bookmarks', e), st);
    }
  }

  @override
  Stream<Result<List<BrowserBookmark>>> watchBookmarks() {
    return (_db.select(_db.webBookmarks)
          ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
        .watch()
        .map((rows) => Success(rows.map(_bookmarkFrom).toList()));
  }

  @override
  Future<Result<void>> addBookmark(BrowserBookmark bookmark) async {
    try {
      await _db.into(_db.webBookmarks).insertOnConflictUpdate(
            WebBookmarksCompanion(
              id: Value(bookmark.id),
              url: Value(bookmark.url),
              title: bookmark.title != null
                  ? Value(bookmark.title)
                  : const Value.absent(),
              createdAt: Value(bookmark.createdAt),
              updatedAt: Value(bookmark.updatedAt),
            ),
          );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to add web bookmark', e), st);
    }
  }

  @override
  Future<Result<void>> removeBookmark(String bookmarkId) async {
    try {
      await (_db.delete(_db.webBookmarks)..where((b) => b.id.equals(bookmarkId))).go();
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to remove web bookmark', e), st);
    }
  }

  @override
  Future<Result<List<WebTabState>>> getTabs() async {
    try {
      final rows = await (_db.select(_db.webTabs)
            ..orderBy([(t) => OrderingTerm.asc(t.order)]))
          .get();
      return Success(rows.map(_tabFrom).toList());
    } catch (e, st) {
      return Failure(DatabaseException('Failed to load web tabs', e), st);
    }
  }

  @override
  Future<Result<void>> upsertTab(WebTabState tab) async {
    try {
      await _db.into(_db.webTabs).insertOnConflictUpdate(
            WebTabsCompanion(
              id: Value(tab.id),
              url: tab.url != null ? Value(tab.url) : const Value.absent(),
              title: tab.title != null ? Value(tab.title) : const Value.absent(),
              order: Value(tab.order),
              lastActiveAt: Value(tab.lastActiveAt),
            ),
          );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to save web tab', e), st);
    }
  }

  @override
  Future<Result<void>> removeTab(String tabId) async {
    try {
      await (_db.delete(_db.webTabs)..where((t) => t.id.equals(tabId))).go();
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to remove web tab', e), st);
    }
  }

  @override
  Future<Result<void>> clearTabs() async {
    try {
      await _db.delete(_db.webTabs).go();
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to clear web tabs', e), st);
    }
  }

  WebHistoryEntry _historyFrom(WebHistoryData row) => WebHistoryEntry(
        id: row.id,
        url: row.url,
        title: row.title,
        visitedAt: row.visitedAt,
      );

  BrowserBookmark _bookmarkFrom(WebBookmark row) => BrowserBookmark(
        id: row.id,
        url: row.url,
        title: row.title,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  WebTabState _tabFrom(WebTab row) => WebTabState(
        id: row.id,
        url: row.url,
        title: row.title,
        order: row.order,
        lastActiveAt: row.lastActiveAt,
      );
}