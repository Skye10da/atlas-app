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
      expect(results.single.coverUrl, 'https://example.com/cover-x.jpg');
    });

    test('drives a custom search endpoint via path and queryParam', () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/fictions/search?title=mother', '''
        <html><body>
          <div class="fiction-list-item">
            <h2 class="fiction-title"><a href="/fiction/1/mother">Mother</a></h2>
          </div>
        </body></html>''');
      const selectors = SelectorSet(search: SearchSelectors(
        resultItem: '.fiction-list-item',
        title: 'h2.fiction-title a@text',
        detailUrl: 'h2.fiction-title a@href',
        path: '/fictions/search',
        queryParam: 'title',
      ));
      final context = buildContext(transport: transport, selectors: selectors);

      final results = await const HtmlTemplate().search(context, 'mother');

      expect(results, hasLength(1));
      expect(results.single.title, 'Mother');
      expect(results.single.url, 'https://example.com/fiction/1/mother');
    });

    test('throws PluginCapabilityException without search selectors', () async {
      final context = buildContext(transport: FakeTransport());

      await expectLater(
        const HtmlTemplate().search(context, 'test'),
        throwsA(isA<PluginCapabilityException>()),
      );
    });

    test('appends fixed extra query params (e.g. post_type)', () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/search?q=test&post_type=wp-manga', '''
        <html><body>
          <div class="sr"><a href="/novel/x"><span class="t">Novel X</span></a></div>
        </body></html>''');
      const selectors = SelectorSet(search: SearchSelectors(
        resultItem: '.sr',
        title: '.t',
        detailUrl: 'a@href',
        path: '/search',
        queryParam: 'q',
        extraQueryParams: {'post_type': 'wp-manga'},
      ));
      final context = buildContext(transport: transport, selectors: selectors);

      final results = await const HtmlTemplate().search(context, 'test');

      expect(results, hasLength(1));
      expect(results.single.title, 'Novel X');
    });
  });

  group('HtmlTemplate.chapterList', () {
    test('walks paginated index pages, dedupes and resolves URLs', () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/novel/x', '''
        <html><body><ul class="cl">
          <li><a href="/novel/x/ch/1">Chapter 1</a></li>
          <li><a href="/novel/x/ch/2">Chapter 2</a></li>
        </ul></body></html>''')
        ..addHtml('https://example.com/novel/x?page=2', '''
        <html><body><ul class="cl">
          <li><a href="/novel/x/ch/3">Chapter 3</a></li>
          <li><a href="/novel/x/ch/2">Chapter 2</a></li>
        </ul></body></html>''');
      const selectors = SelectorSet(chapterList: ChapterListSelectors(
        item: '.cl li a',
        title: '@text',
        url: '@href',
        pageParam: 'page',
        maxPages: 5,
      ));
      final context = buildContext(transport: transport, selectors: selectors);

      final refs =
          await const HtmlTemplate().chapterList(context, 'https://example.com/novel/x');

      expect(refs.map((r) => r.title).toList(), ['Chapter 1', 'Chapter 2', 'Chapter 3']);
      expect(refs.first.url, 'https://example.com/novel/x/ch/1');
    });

    test('stops walking when a page adds no new chapters', () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/novel/x', '''
        <html><body><ul class="cl">
          <li><a href="/novel/x/ch/1">Chapter 1</a></li>
        </ul></body></html>''');
      const selectors = SelectorSet(chapterList: ChapterListSelectors(
        item: '.cl li a',
        title: '@text',
        url: '@href',
        maxPages: 50,
      ));
      final context = buildContext(transport: transport, selectors: selectors);

      final refs =
          await const HtmlTemplate().chapterList(context, 'https://example.com/novel/x');

      expect(refs, hasLength(1));
      expect(transport.htmlCalls, 2);
    });

    test('reverses the merged list when configured', () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/novel/x', '''
        <html><body><ul class="cl">
          <li><a href="/novel/x/ch/2">Chapter 2</a></li>
          <li><a href="/novel/x/ch/1">Chapter 1</a></li>
        </ul></body></html>''');
      const selectors = SelectorSet(chapterList: ChapterListSelectors(
        item: '.cl li a',
        title: '@text',
        url: '@href',
        reverse: true,
      ));
      final context = buildContext(transport: transport, selectors: selectors);

      final refs =
          await const HtmlTemplate().chapterList(context, 'https://example.com/novel/x');

      expect(refs.map((r) => r.title).toList(), ['Chapter 1', 'Chapter 2']);
    });

        test('throws PluginCapabilityException without chapterList selectors',
        () async {
      final context = buildContext(transport: FakeTransport());

      await expectLater(
        const HtmlTemplate().chapterList(context, 'https://example.com/novel/x'),
        throwsA(isA<PluginCapabilityException>()),
      );
    });

    test('fetches the archive via ajaxPath keyed by the novel id', () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/novel/x', '''
        <html><body><div id="rating" data-novel-id="42"></div>
        <ul class="cl"><li><a href="/novel/x/ch/2">Chapter 2</a></li></ul>
        </body></html>''')
        ..addHtml('https://example.com/ajax/chapters?novelId=42', '''
        <html><body><select>
          <option value="/novel/x/ch/1">Chapter 1</option>
          <option value="/novel/x/ch/2">Chapter 2</option>
          <option value="/novel/x/ch/3">Chapter 3</option>
        </select></body></html>''');
      const selectors = SelectorSet(chapterList: ChapterListSelectors(
        item: 'ul.cl li',
        title: '@text',
        url: 'a@href',
        ajaxPath: '/ajax/chapters',
        ajaxArchive: AjaxArchiveSelectors(
          item: 'select > option[value]',
          title: '@text',
          url: '@value',
        ),
      ));
      final context = buildContext(transport: transport, selectors: selectors);

      final refs = await const HtmlTemplate().chapterList(
        context,
        'https://example.com/novel/x',
      );

      expect(refs.map((r) => r.title).toList(), [
        'Chapter 1',
        'Chapter 2',
        'Chapter 3',
      ]);
    });

    test('falls back to the paginated walk when the archive is unreachable',
        () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/novel/x', '''
        <html><body><div id="rating" data-novel-id="42"></div>
        <ul class="cl"><li><a href="/novel/x/ch/1">Chapter 1</a></li></ul>
        </body></html>''');
      const selectors = SelectorSet(chapterList: ChapterListSelectors(
        item: 'ul.cl li',
        title: '@text',
        url: 'a@href',
        ajaxPath: '/ajax/chapters',
      ));
      final context = buildContext(transport: transport, selectors: selectors);

      final refs = await const HtmlTemplate().chapterList(
        context,
        'https://example.com/novel/x',
      );

      expect(refs.map((r) => r.title).toList(), ['Chapter 1']);
    });

    test('bounds the walk from the pagination bar and data-total-page',
        () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/novel/x', '''
        <html><body>
        <div id="truyen" data-total-page="2">
          <ul class="cl"><li><a href="/novel/x/ch/1">Chapter 1</a></li></ul>
          <ul class="pagination"><li><a href="/novel/x?page=2">2</a></li></ul>
        </div>
        </body></html>''')
        ..addHtml('https://example.com/novel/x?page=2', '''
        <html><body><ul class="cl">
          <li><a href="/novel/x/ch/2">Chapter 2</a></li>
        </ul></body></html>''');
      const selectors = SelectorSet(chapterList: ChapterListSelectors(
        item: 'ul.cl li',
        title: '@text',
        url: 'a@href',
        paginationSelector: 'ul.pagination',
        totalPagesSelector: '#truyen',
      ));
      final context = buildContext(transport: transport, selectors: selectors);

      final refs = await const HtmlTemplate().chapterList(
        context,
        'https://example.com/novel/x',
      );

      expect(refs.map((r) => r.title).toList(), ['Chapter 1', 'Chapter 2']);
    });

    test('sorts by chapter number when configured', () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/novel/x', '''
        <html><body><ul class="cl">
          <li><a href="/novel/x/chapter-3.html">Chapter 3</a></li>
          <li><a href="/novel/x/chapter-1.html">Chapter 1</a></li>
          <li><a href="/novel/x/chapter-2.html">Chapter 2</a></li>
        </ul></body></html>''');
      const selectors = SelectorSet(chapterList: ChapterListSelectors(
        item: 'ul.cl li',
        title: '@text',
        url: 'a@href',
        sortByChapterNumber: true,
      ));
      final context = buildContext(transport: transport, selectors: selectors);

      final refs = await const HtmlTemplate().chapterList(
        context,
        'https://example.com/novel/x',
      );

      expect(refs.map((r) => r.title).toList(), [
        'Chapter 1',
        'Chapter 2',
        'Chapter 3',
      ]);
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

    test('reads a data-driven metadata section (info rows + css fallbacks)',
        () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/novel/x', '''
        <html><head>
          <meta property="og:title" content="Novel Title">
          <meta property="og:image" content="https://example.com/cover.jpg">
        </head><body>
          <div class="col-info-desc"><div class="info">
            <div><h3>Author:</h3><a href="/author/x">Jane Doe</a></div>
            <div><h3>Genres:</h3><a href="/g/fantasy">Fantasy</a>, <a href="/g/scifi">SciFi</a></div>
            <div><h3>Status:</h3>Ongoing</div>
          </div></div>
          <div class="desc-text"><p>The real synopsis.</p></div>
        </body></html>''');
      const selectors = SelectorSet(metadata: MetadataSelectors(
        author: InfoRowMetadataField(labels: ['Author:']),
        genres: InfoRowMetadataField(labels: ['Genres:', 'Genre:'], links: true),
        status: InfoRowMetadataField(labels: ['Status:']),
        description: CssMetadataField('.desc-text p'),
      ));
      final context = buildContext(transport: transport, selectors: selectors);

      final metadata =
          await const HtmlTemplate().metadata(context, 'https://example.com/novel/x');

      expect(metadata.title, 'Novel Title');
      expect(metadata.author, 'Jane Doe');
      expect(metadata.genres, ['Fantasy', 'SciFi']);
      expect(metadata.status, 'Ongoing');
      expect(metadata.description, 'The real synopsis.');
    });

    test('falls back to og:novel:* tags when no metadata section is present',
        () async {
      final transport = FakeTransport()
        ..addHtml('https://example.com/novel/x', '''
        <html><head>
          <meta property="og:title" content="Novel Title">
          <meta name="og:novel:author" content="Jane Doe">
          <meta property="og:novel:genre" content="Fantasy, SciFi">
          <meta name="og:novel:status" content="Ongoing">
        </head><body></body></html>''');
      final context = buildContext(transport: transport);

      final metadata =
          await const HtmlTemplate().metadata(context, 'https://example.com/novel/x');

      expect(metadata.author, 'Jane Doe');
      expect(metadata.genres, ['Fantasy', 'SciFi']);
      expect(metadata.status, 'Ongoing');
    });
  });
}
