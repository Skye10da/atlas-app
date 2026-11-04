import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/find_new/presentation/screens/find_new_screen.dart';
import 'package:atlas_app/find_new/presentation/widgets/search_summary_line.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';
import 'package:atlas_app/search/domain/federated_search.dart';
import 'package:atlas_app/search/presentation/providers/federated_search_provider.dart';

/// Canned federated search state for UI-level assertions.
FederatedSearchState stubState = FederatedSearchState.idle(const []);

class StubFederatedNotifier extends FederatedSearchNotifier {
  @override
  FederatedSearchState build() => stubState;

  // Screen-driven stubs: the widget's own useState decides which mode is
  // showing; these overrides just avoid dangling timers in tests.
  @override
  void query(String term) {}
  @override
  void run(String term) {}
  @override
  void clear() {}
  @override
  void retryUnreachable() {}
}

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

List<SiteSearchStatus> stubSites = [
  const SiteSearchStatus(
    sourceName: 'Site A',
    state: SiteSearchState.done,
    resultCount: 1,
  ),
  const SiteSearchStatus(
    sourceName: 'Site B',
    state: SiteSearchState.done,
    resultCount: 1,
  ),
  const SiteSearchStatus(
    sourceName: 'Site C',
    state: SiteSearchState.error,
    error: 'site down',
  ),
];

FederatedSearchState get stubResultsState => FederatedSearchState(
      term: 'cultivation',
      sites: stubSites,
      results: [
        FederatedBook(
          title: 'Transcend the Nine Heavens',
          author: 'Tan Sheng',
          matchKey:
              federatedMatchKey('Transcend the Nine Heavens', 'Tan Sheng'),
          offerings: const [
            SiteOffering(
              sourceName: 'Site A',
              importUrl: 'https://a.example/novel/1',
            ),
            SiteOffering(
              sourceName: 'Site B',
              importUrl: 'https://b.example/novel/1',
            ),
          ],
        ),
      ],
    );

Future<void> pumpHub(
  WidgetTester tester, {
  required bool withLibraryBook,
}) async {
  stubState = stubResultsState;
  final overrides = <Override>[
    searchableSourcesProvider.overrideWith((ref) => const [
          _FakeSource('Site A'),
          _FakeSource('Site B'),
          _FakeSource('Site C'),
        ]),
    pluginSourcesProvider.overrideWith((ref) async => const []),
    federatedSearchProvider.overrideWith(StubFederatedNotifier.new),
  ];
  if (withLibraryBook) {
    overrides.add(
      libraryBooksProvider.overrideWith(
        (ref) => Stream.value(
          Success<List<BookEntity>>([
            BookEntity(
              id: 'lib-1',
              title: 'Transcend the Nine Heavens',
              author: 'Tan Sheng',
              format: 'epub',
              totalChapters: 100,
              itemType: ContentCategory.novel,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ]),
        ),
      ),
    );
  }
  // Minimal router so title-tap navigation can be asserted.
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: FindNewScreen()),
      ),
      GoRoute(
        path: '/web',
        builder: (context, state) =>
            ScreenStub('web:${state.uri.queryParameters['url']}'),
      ),
      GoRoute(
        path: '/novel/:id',
        builder: (context, state) =>
            ScreenStub('novel:${state.pathParameters['id']}'),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class ScreenStub extends StatelessWidget {
  const ScreenStub(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(label));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('FindNewScreen results mode', () {
    testWidgets('typing in the hero search switches to federated results',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpHub(tester, withLibraryBook: false);

      // The dashboard is minimal: the supported-sites list, no feed.
      expect(find.text('Transcend the Nine Heavens'), findsNothing);

      // Type into the hero bar → results mode.
      await tester.enterText(find.byType(TextField), 'cultivation');
      await tester.pumpAndSettle();

      expect(find.byType(FindNewScreen), findsOneWidget);
      // One quiet summary line instead of the chip strip: 2 of 3 sites
      // searched (Site C failed), 2 matches.
      expect(find.byType(SearchSummaryLine), findsOneWidget);
      expect(find.textContaining('2 of 3 sites searched'), findsOneWidget);
      // One deduped card across two sites.
      expect(find.textContaining('1 match'), findsOneWidget);
      // Quiet failures: no technical error text anywhere.
      expect(find.textContaining('site down'), findsNothing);
      // Deduped card with the multi-source badge and Add action.
      expect(find.text('Transcend the Nine Heavens'), findsOneWidget);
      expect(find.text('by Tan Sheng'), findsOneWidget);
      expect(find.text('on 2 sites'), findsOneWidget);
      expect(find.text('Add to Library'), findsOneWidget);
      // The unreachable one is covered by the summary (quietly).
      expect(find.textContaining('1 of 3'), findsNothing);
    });

    testWidgets('a book already in the library opens instead of re-importing',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpHub(tester, withLibraryBook: true);

      await tester.enterText(find.byType(TextField), 'cultivation');
      await tester.pumpAndSettle();

      expect(find.text('In library'), findsOneWidget);
      expect(find.text('Add to Library'), findsNothing);
    });

    testWidgets('tapping the title opens the novel page in the browser',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpHub(tester, withLibraryBook: false);

      await tester.enterText(find.byType(TextField), 'cultivation');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Transcend the Nine Heavens'));
      await tester.pumpAndSettle();

      // The novel's page on its source site opens in the immersive source
      // browser (the primary offering's URL).
      expect(find.text('web:https://a.example/novel/1'), findsOneWidget);
    });

    testWidgets('tapping the title of an in-library book opens its details',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpHub(tester, withLibraryBook: true);

      await tester.enterText(find.byType(TextField), 'cultivation');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Transcend the Nine Heavens'));
      await tester.pumpAndSettle();

      expect(find.text('novel:lib-1'), findsOneWidget);
    });

    testWidgets('"More from site" opens the site itself in the browser, '
        'not a search page', (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpHub(tester, withLibraryBook: false);

      await tester.enterText(find.byType(TextField), 'cultivation');
      await tester.pumpAndSettle();

      // The button carries the offering's site origin (its scheme+host),
      // never a per-site search route.
      expect(find.text('More from site'), findsOneWidget);
      expect(find.textContaining('/sources/'), findsNothing);
      await tester.tap(find.text('More from site'));
      await tester.pumpAndSettle();

      expect(find.text('web:https://a.example'), findsOneWidget);
    });

    testWidgets('clearing the query returns to the dashboard',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      stubState = FederatedSearchState.idle(const []);
      await pumpHub(tester, withLibraryBook: false);

      await tester.enterText(find.byType(TextField), 'x');
      await tester.pumpAndSettle();

      // Enter the clear icon (suffix) and clear the query.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(SearchSummaryLine), findsNothing);
    });
  });
}
