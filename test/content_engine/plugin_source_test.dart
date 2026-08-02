import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/verification.dart';
import 'package:atlas_app/core/content_engine/registry/plugin_source.dart';
import 'package:atlas_app/core/content_engine/selectors/selector_set.dart';
import 'package:atlas_app/core/content_engine/templates/html_template.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';

import 'test_fixtures.dart';

void main() {
  const novel = NovelModel(
    sourceId: 'x',
    title: 'X',
    source: 'Test Plugin',
    sourceUrl: 'https://example.com/novel/x',
  );

  group('PluginSource.canHandle', () {
    test('matches the manifest host ignoring www. prefix', () {
      final source = PluginSource(
        manifest: buildManifest(baseUrl: 'https://www.example.com'),
        template: const HtmlTemplate(),
        transport: FakeTransport(),
      );

      expect(source.canHandle(Uri.parse('https://example.com/novel/x')), isTrue);
      expect(source.canHandle(Uri.parse('https://www.example.com/novel/x')),
          isTrue);
      expect(source.canHandle(Uri.parse('https://other.com/novel/x')), isFalse);
    });
  });

  group('PluginSource.getMetadata', () {
    test('bridges template metadata to a NovelModel', () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/novel/x', '''
        <html><head>
          <meta property="og:title" content="Great Novel">
          <meta name="description" content="A description.">
        </head><body></body></html>''');
      final source = PluginSource(
        manifest: buildManifest(),
        template: const HtmlTemplate(),
        transport: transport,
      );

      final result = await source.getMetadata(Uri.parse('https://example.com/novel/x'));

      expect(result.title, 'Great Novel');
      expect(result.description, 'A description.');
      expect(result.source, 'Test Plugin');
      expect(result.sourceUrl, 'https://example.com/novel/x');
      expect(result.category, ContentCategory.novel);
    });
  });

  group('PluginSource.getChapters', () {
    test('maps chapter-list refs to ChapterModels', () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/novel/x', '''
        <html><body>
          <ul class="chapter-list">
            <li><a href="/chapter/1">Ch 1</a></li>
            <li><a href="/chapter/2">Ch 2</a></li>
          </ul>
        </body></html>''');
      const selectors = SelectorSet(chapterList: ChapterListSelectors(
        item: '.chapter-list li a',
        title: '@text',
        url: '@href',
      ));
      final source = PluginSource(
        manifest: buildManifest(),
        template: const HtmlTemplate(),
        transport: transport,
        selectors: selectors,
      );

      final chapters = await source.getChapters(novel);

      expect(chapters, hasLength(2));
      expect(chapters[0].title, 'Ch 1');
      expect(chapters[0].contentUrl, '/chapter/1');
      expect(chapters[0].id, '/chapter/1#ch0');
      expect(chapters[1].id, '/chapter/2#ch1');
    });
  });

  group('PluginSource.getChapter', () {
    test('runs the pipeline and exposes rendered text', () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/chapter/1', '''
        <html><body>
          <div id="content">
            <h1 class="chapter-title">Chapter One</h1>
            <p>Hello world.</p>
          </div>
        </body></html>''');
      const selectors = SelectorSet(chapterContent:
          ChapterContentSelectors(container: '#content', title: '.chapter-title'));
      final source = PluginSource(
        manifest: buildManifest(),
        template: const HtmlTemplate(),
        transport: transport,
        selectors: selectors,
      );
      const chapter = ChapterModel(
        id: '/chapter/1#ch0',
        title: 'Ch 1',
        index: 0,
        contentUrl: 'https://example.com/chapter/1',
      );

      final result = await source.getChapter(chapter);

      expect(result.content, contains('Hello world.'));
      expect(result.wordCount, greaterThan(0));
      expect(result.title, 'Chapter One');
    });
  });

  group('PluginSource.search', () {
    test('bridges template search results to the SearchableSource contract',
        () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com?s=novel', '''
        <html><body>
          <div class="search-result">
            <a href="/novel/x"><span class="title">Novel X</span></a>
          </div>
        </body></html>''');
      const selectors = SelectorSet(search: SearchSelectors(
        resultItem: '.search-result',
        title: '.title',
        detailUrl: 'a@href',
      ));
      final source = PluginSource(
        manifest: buildManifest(),
        template: const HtmlTemplate(),
        transport: transport,
        selectors: selectors,
      );

      final response =
          await source.search(const SourceSearchQuery(term: 'novel'));

      expect(response.results, hasLength(1));
      expect(response.results.single.title, 'Novel X');
      expect(response.results.single.importUrl, 'https://example.com/novel/x');
    });
  });

  group('PluginSource capability guards', () {
    test('throws PluginCapabilityException when search is not declared',
        () async {
      final source = PluginSource(
        manifest: buildManifest(capabilities: [PluginCapability.chapterContent]),
        template: const HtmlTemplate(),
        transport: FakeTransport(),
      );

      await expectLater(
        source.search(const SourceSearchQuery(term: 'x')),
        throwsA(isA<PluginCapabilityException>()),
      );
    });

    test('fails construction when requiresJsRendering is set', () {
      const manifest = PluginManifest(
        id: 'js',
        name: 'JS',
        sourceName: 'JS',
        version: PluginVersion(major: 1, minor: 0, patch: 0),
        templateId: 'html',
        baseUrl: 'https://example.com',
        requiresJsRendering: true,
      );

      expect(
        () => PluginSource(
          manifest: manifest,
          template: const HtmlTemplate(),
          transport: FakeTransport(),
        ),
        throwsA(isA<PluginManifestException>()),
      );
    });
  });
}
