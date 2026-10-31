import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/find_new/presentation/screens/find_new_screen.dart';
import 'package:atlas_app/library/presentation/widgets/source_directory_section.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';
import 'package:atlas_app/reader/presentation/screens/bookmarks_screen.dart';
import 'package:atlas_app/search/presentation/screens/search_screen.dart';

class _FakeSource implements SearchableSource {
  const _FakeSource(this.name);

  final String name;

  @override
  String get sourceName => name;

  @override
  ContentCategory get contentCategory => ContentCategory.novel;

  @override
  Future<SourceSearchResponse> search(SourceSearchQuery query) async =>
      const SourceSearchResponse(results: []);

  @override
  bool canHandle(Uri uri) => false;
  @override
  Future<NovelModel> getMetadata(Uri uri) => throw UnimplementedError();
  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) =>
      throw UnimplementedError();
  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) =>
      throw UnimplementedError();
}

void main() {
  // The hub reads the live source registry in tests; keep it stubbed so no
  // plugin machinery (path_provider, db) spins up.
  final List<Override> hubOverrides = [
    searchableSourcesProvider.overrideWith(
      (ref) => const [_FakeSource('Example Site')],
    ),
    pluginSourcesProvider.overrideWith((ref) async => const []),
  ];

  group('FindNewScreen (minimal dashboard)', () {
    testWidgets('renders the hero field and the saved-sites directory',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await tester.pumpWidget(
        ProviderScope(
          overrides: hubOverrides,
          child: const MaterialApp(home: Scaffold(body: FindNewScreen())),
        ),
      );
      await tester.pumpAndSettle();

      // One field for everything.
      expect(
        find.text('Search novels or paste a link'),
        findsOneWidget,
      );
      // The bookmark-style source directory lives here again.
      expect(find.byType(SourceListSection), findsOneWidget);
      expect(find.text('Example Site'), findsOneWidget);
    });
  });

  group('BookmarksScreen', () {
    testWidgets('renders the bookmarks and words tabs without the site directory',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...hubOverrides,
            enrichedBookmarksProvider.overrideWith((ref) async => <EnrichedBookmark>[]),
          ],
          child: const MaterialApp(home: Scaffold(body: BookmarksScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.text('Words'), findsOneWidget);
      // The supported-sites directory was wrongly moved here during the
      // Find new redesign; it lives on FindNewScreen again.
      expect(find.text('SUPPORTED SITE'), findsNothing);
      expect(find.text('Example Site'), findsNothing);
    });
  });

  group('SearchScreen ("Find new")', () {
    testWidgets('leads with the discovery surface and exposes all tabs',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = AppDatabase.memory();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            ...hubOverrides,
          ],
          child: const MaterialApp(home: SearchScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Find new'), findsOneWidget);
      for (final label in ['Browse', 'Library', 'Lookup']) {
        expect(find.text(label), findsOneWidget);
      }
      // The former Saved tab now lives in the Saved bottom-nav branch.
      expect(find.text('Saved'), findsNothing);

      // The Browse tab is selected by default, so discovery is the first body.
      expect(find.byType(FindNewScreen), findsOneWidget);
    });
  });
}

