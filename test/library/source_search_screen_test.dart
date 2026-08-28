import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';
import 'package:atlas_app/library/presentation/screens/source_search_screen.dart';

class _FakeSearchableSource implements SearchableSource {
  _FakeSearchableSource(this.searchCompleter);

  final Completer<SourceSearchResponse> searchCompleter;

  @override
  String get sourceName => 'FakeSource';

  @override
  ContentCategory get contentCategory => ContentCategory.novel;

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

  @override
  Future<SourceSearchResponse> search(SourceSearchQuery query) =>
      searchCompleter.future;
}

void main() {
  testWidgets('SourceSearchScreen does not call setState after dispose if search completes late', (
    tester,
  ) async {
    final completer = Completer<SourceSearchResponse>();
    final fakeSource = _FakeSearchableSource(completer);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchableSourcesProvider.overrideWithValue([fakeSource]),
        ],
        child: const MaterialApp(
          home: SourceSearchScreen(sourceName: 'FakeSource'),
        ),
      ),
    );

    // Enter search text and submit
    await tester.enterText(find.byType(TextField), 'Test query');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    // Verify search indicator is shown
    expect(find.text('Searching...'), findsOneWidget);

    // Dispose the widget by replacing the root with an empty container
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Done')),
      ),
    );

    // Complete the search response now that SourceSearchScreen is unmounted
    completer.complete(
      const SourceSearchResponse(
        results: [
          SourceSearchResult(
            id: '1',
            title: 'Test Book',
            importUrl: 'https://example.com/test',
          ),
        ],
      ),
    );

    // Pump to process future completion - must not throw FlutterError
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
  });
}
