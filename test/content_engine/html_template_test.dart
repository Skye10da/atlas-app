import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/plugins/plugin_filters.dart';
import 'package:atlas_app/core/content_engine/selectors/selector_set.dart';
import 'package:atlas_app/core/content_engine/templates/html_template.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/template_models.dart';

import 'test_fixtures.dart';

void main() {
  group('HtmlTemplate.chapterContent', () {
    test('applies chapterContent selectors and strips ad nodes', () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/ch/1', '''
        <html><head><title>Page title</title></head><body>
          <div id="content">
            <h1 class="chapter-title">Chapter One</h1>
            <p>First <strong>paragraph</strong>.</p>
            <div class="ad"><a href="https://ads.example/x">Buy now</a></div>
          </div>
        </body></html>''');
      const selectors = SelectorSet(chapterContent:
          ChapterContentSelectors(container: '#content', title: '.chapter-title'));
      const filters = PluginFilters(extraStripSelectors: ['.ad']);
      final context = buildContext(
        transport: transport,
        selectors: selectors,
        filters: filters,
      );

      final doc =
          await const HtmlTemplate().chapterContent(context, 'https://example.com/ch/1');

      expect(doc.title, 'Chapter One');
      final text = doc.renderToText();
      expect(text, contains('First paragraph'));
      expect(text, isNot(contains('Buy now')));
    });

    test('falls back to the whole body when no selectors are configured',
        () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/ch/2',
            '<html><body><p>Just a body.</p></body></html>');
      final context = buildContext(transport: transport);

      final doc =
          await const HtmlTemplate().chapterContent(context, 'https://example.com/ch/2');

      expect(doc.renderToText(), contains('Just a body.'));
    });
  });

  group('HtmlTemplate.search', () {
    test('queries the WordPress ?s= endpoint and resolves relative URLs',
        () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com?s=test', '''
        <html><body>
          <div class="search-result">
            <a href="/novel/x"><span class="title">Novel X</span></a>
            <img src="/cover-x.jpg" alt="">
          </div>
        </body></html>''');
      const selectors = SelectorSet(search: SearchSelectors(
        resultItem: '.search-result',
        title: '.title',
        coverUrl: 'img@src',
        detailUrl: 'a@href',
      ));
      final context = buildContext(transport: transport, selectors: selectors);

      final results =
          await const HtmlTemplate().search(context, 'test');

      expect(results, hasLength(1));
      expect(results.single.title, 'Novel X');
      expect(results.single.url, 'https://example.com/novel/x');
      expect(results.single.coverUrl, '/cover-x.jpg');
    });

    test('throws PluginCapabilityException without search selectors', () async {
      final context = buildContext(transport: FakeTransport());

      await expectLater(
        const HtmlTemplate().search(context, 'test'),
        throwsA(isA<PluginCapabilityException>()),
      );
    });
  });

  group('HtmlTemplate.metadata', () {
    test('reads og: tags and falls back to the title tag', () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/novel/x', '''
        <html><head>
          <title>Title Tag</title>
          <meta property="og:title" content="Novel Title">
          <meta property="og:image" content="https://example.com/cover.jpg">
          <meta name="description" content="A great novel.">
        </head><body></body></html>''');
      final context = buildContext(transport: transport);

      final metadata =
          await const HtmlTemplate().metadata(context, 'https://example.com/novel/x');

      expect(metadata, isA<NovelMetadata>());
      expect(metadata.title, 'Novel Title');
      expect(metadata.coverUrl, 'https://example.com/cover.jpg');
      expect(metadata.description, 'A great novel.');
      expect(metadata.language, 'en');
    });
  });
}
