import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/browser/domain/entities/web_bookmark.dart';
import 'package:atlas_app/browser/domain/entities/web_tab_state.dart';
import 'package:atlas_app/browser/infrastructure/repositories/drift_browser_repository.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';

void main() {
  late AppDatabase db;
  late DriftBrowserRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = DriftBrowserRepository(db);
  });

  tearDown(() => db.close());

  group('web history', () {
    test('records a visit and returns most recent first', () async {
      final first = await repo.recordVisit(
        url: 'https://a.example',
        title: 'A',
        visitedAt: DateTime(2025, 1, 1, 10, 0, 0),
      );
      expect(first, isA<Success<void>>());

      final second = await repo.recordVisit(
        url: 'https://b.example',
        title: 'B',
        visitedAt: DateTime(2025, 1, 1, 10, 0, 1),
      );

      expect(second, isA<Success<void>>());
      final history = (await repo.getAllHistory()).valueOrThrow;
      expect(history.map((h) => h.url).toList(),
          ['https://b.example', 'https://a.example']);
      expect(history.first.title, 'B');
    });

    test('collapses consecutive visits to the same url', () async {
      await repo.recordVisit(url: 'https://a.example', title: 'First');
      await repo.recordVisit(url: 'https://a.example', title: 'Second');
      final history = (await repo.getAllHistory()).valueOrThrow;
      expect(history, hasLength(1));
      expect(history.single.title, 'Second');
    });

    test('ignores about:blank visits', () async {
      await repo.recordVisit(url: 'about:blank');
      final history = (await repo.getAllHistory()).valueOrThrow;
      expect(history, isEmpty);
    });

    test('clearHistory empties the table', () async {
      await repo.recordVisit(url: 'https://a.example', title: 'A');
      final clear = await repo.clearHistory();
      expect(clear, isA<Success<void>>());
      expect((await repo.getAllHistory()).valueOrThrow, isEmpty);
    });
  });

  group('web bookmarks', () {
    test('add/remove round-trips', () async {
      final bookmark = BrowserBookmark(
        id: 'https://a.example',
        url: 'https://a.example',
        title: 'Page A',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      final add = await repo.addBookmark(bookmark);
      expect(add, isA<Success<void>>());

      final bookmarks = (await repo.getAllBookmarks()).valueOrThrow;
      expect(bookmarks, hasLength(1));
      expect(bookmarks.single.displayTitle, 'Page A');
      expect(bookmarks.single.url, 'https://a.example');

      final remove = await repo.removeBookmark(bookmark.id);
      expect(remove, isA<Success<void>>());
      expect((await repo.getAllBookmarks()).valueOrThrow, isEmpty);
    });
  });

  group('web tabs', () {
    test('upsert + get preserves order', () async {
      final a = WebTabState(
        id: 'tab-1',
        url: 'https://a.example',
        title: 'A',
        order: 0,
        lastActiveAt: DateTime(2025, 1, 1),
      );
      final b = WebTabState(
        id: 'tab-2',
        url: 'https://b.example',
        title: 'B',
        order: 1,
        lastActiveAt: DateTime(2025, 1, 2),
      );
      await repo.upsertTab(a);
      await repo.upsertTab(b);

      final tabs = (await repo.getTabs()).valueOrThrow;
      expect(tabs.map((t) => t.id).toList(), ['tab-1', 'tab-2']);

      await repo.removeTab('tab-1');
      final after = (await repo.getTabs()).valueOrThrow;
      expect(after.map((t) => t.id).toList(), ['tab-2']);
    });

    test('upsert with the same id updates in place', () async {
      final original = WebTabState(
        id: 'tab-1',
        url: 'https://a.example',
        title: 'A',
        order: 0,
        lastActiveAt: DateTime(2025, 1, 1),
      );
      final updated = WebTabState(
        id: 'tab-1',
        url: 'https://b.example',
        title: 'B',
        order: 0,
        lastActiveAt: DateTime(2025, 1, 3),
      );
      await repo.upsertTab(original);
      await repo.upsertTab(updated);
      final tabs = (await repo.getTabs()).valueOrThrow;
      expect(tabs, hasLength(1));
      expect(tabs.single.url, 'https://b.example');
    });

    test('upsert with null url/title clears persisted values', () async {
      final original = WebTabState(
        id: 'tab-1',
        url: 'https://a.example',
        title: 'A',
        order: 0,
        lastActiveAt: DateTime(2025, 1, 1),
      );
      final reset = WebTabState(
        id: 'tab-1',
        url: null,
        title: 'New tab',
        order: 0,
        lastActiveAt: DateTime(2025, 1, 4),
      );
      await repo.upsertTab(original);
      await repo.upsertTab(reset);
      final tabs = (await repo.getTabs()).valueOrThrow;
      expect(tabs.single.url, isNull);
      expect(tabs.single.title, 'New tab');
    });
  });
}

extension<T> on Result<T> {
  T get valueOrThrow => switch (this) {
        Success(value: final value) => value,
        Failure() => throw StateError('Unexpected failure'),
      };
}