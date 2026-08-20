import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_permissions.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_repository.dart';
import 'package:atlas_app/core/content_engine/templates/html_template.dart';
import 'package:atlas_app/core/content_engine/templates/template_registry.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/content_engine/transport/transport_registry.dart';

import 'test_fixtures.dart';

const _novelUrl = 'https://novelfull.net/novel.html';
const _chapter1Url =
    'https://novelfull.net/novel/chapter-1-first-chapter.html';

const _novelPage = '''
<html><head>
<meta property="og:title" content="Test Novel">
<meta property="og:image" content="https://novelfull.net/uploads/thumbs/cover.jpg">
<meta property="og:novel:author" content="Jane Doe">
</head><body>
<div id="rating" data-novel-id="1"></div>
<div class="col-xs-12 col-info-desc">
<div class="col-xs-12 col-sm-4 col-md-4 info-holder">
  <div class="desc"><h3 class="title">Test Novel</h3></div>
</div>
<div class="info">
  <div><h3>Author:</h3><a href="/author/Jane-Doe">Jane Doe</a></div>
  <div><h3>Genres:</h3><a href="/genre/Fantasy">Fantasy</a>, <a href="/genre/Adventure">Adventure</a></div>
  <div><h3>Status:</h3><a href="/status/Ongoing">Ongoing</a></div>
</div>
</div>
<div class="desc-text"><p>A great story about dragons and dungeons.</p><div class="showmore"><a>See more</a></div></div>
<div class="col-xs-12" id="list-chapter">
  <ul class="list-chapter">
    <li><a href="/novel/chapter-3-third.html" title="Chapter 3"><span class="chapter-text">Chapter 3</span></a></li>
    <li><a href="/novel/chapter-2-second.html" title="Chapter 2"><span class="chapter-text">Chapter 2</span></a></li>
    <li><a href="/novel/chapter-1-first-chapter.html" title="Chapter 1"><span class="chapter-text">Chapter 1</span></a></li>
  </ul>
  <ul class="pagination pagination-sm">
    <li class="active"><a href="/novel.html" data-page="0">1</a></li>
    <li><a href="/novel.html?page=2" data-page="1">2</a></li>
    <li class="next"><a href="/novel.html?page=2">&gt;</a></li>
  </ul>
</div>
</body></html>''';

const _novelPage2 = '''
<html><body>
<div class="col-xs-12" id="list-chapter">
  <ul class="list-chapter">
    <li><a href="/novel/chapter-5-fifth.html" title="Chapter 5"><span class="chapter-text">Chapter 5</span></a></li>
    <li><a href="/novel/chapter-4-fourth.html" title="Chapter 4"><span class="chapter-text">Chapter 4</span></a></li>
  </ul>
  <ul class="pagination pagination-sm">
    <li><a href="/novel.html" data-page="0">1</a></li>
    <li class="active"><a href="/novel.html?page=2" data-page="1">2</a></li>
  </ul>
</div>
</body></html>''';

const _chapterPage = '''
<html><body>
<h2><a class="chapter-title" href="/novel/chapter-1-first-chapter.html" title="Chapter 1"><span class="chapter-text">Chapter 1<span></a></h2>
<div id="chapter-content">
  <div id="frame"><iframe src="//ad.example.com"></iframe></div>
  <p></p><p>First paragraph of the chapter body.</p><p>Second paragraph.</p>
  <div class="ads ads-holder ads-middle"><p>Advertisement</p></div>
</div>
</body></html>''';

const _ajaxChapterPage = '''
<html><body><select>
<option value="/novel/chapter-1-first-chapter.html">Chapter 1</option>
<option value="/novel/chapter-2-second.html">Chapter 2</option>
<option value="/novel/chapter-3-third.html">Chapter 3</option>
<option value="/novel/chapter-4-fourth.html">Chapter 4</option>
<option value="/novel/chapter-5-fifth.html">Chapter 5</option>
</select></body></html>''';

/// The current novelfull.net markup: the novel id moved off `#rating` onto the
/// score box and the chapter-list container, and the pagination bar is a
/// `<select id="indexselect">` whose options carry `?page=N` in `data-url`.
const _novelPageNewMarkup = '''
<html><head>
<meta property="og:title" content="Test Novel">
<meta property="og:image" content="https://novelfull.net/uploads/thumbs/cover.jpg">
<meta property="og:novel:author" content="Jane Doe">
</head><body>
<div class="container" id="truyen" data-page-size="40" data-total-page="2" data-total-chapters="5">
<div class="col-xs-12 col-sm-4 col-md-4 info-holder">
  <div class="desc"><h3 class="title">Test Novel</h3></div>
</div>
<div class="score" id="novel-score" data-novel-id="1" data-avg="4.3"></div>
<div class="col-info-desc">
  <div class="info">
    <div><h3>Author:</h3><a href="/author/Jane-Doe">Jane Doe</a></div>
    <div><h3>Genres:</h3><a href="/genre/Fantasy">Fantasy</a></div>
    <div><h3>Status:</h3><a href="/status/Ongoing">Ongoing</a></div>
  </div>
</div>
<div class="desc-text"><p>A great story about dragons and dungeons.</p></div>
<div class="m-newest2" id="list-chapter" data-novel-id="1" data-current-page="1" data-total-page="2">
  <ul class="ul-list5" id="idData">
    <li><a href="/novel/chapter-1.html" title="Chapter 1"><span class="chapter-text">Chapter 1</span></a></li>
  </ul>
  <div class="page" id="barcon">
    <select id="indexselect" aria-label="Chapter range">
      <option value="1" data-url="/novel.html">C.1 - C.40</option>
      <option value="2" data-url="/novel.html?page=2">C.41 - C.80</option>
    </select>
  </div>
</div>
</div>
</body></html>''';

/// New-markup page without any `data-novel-id`, forcing the pagination
/// fallback to read the `<select>` bar and the embedded page count.
const _novelPageNewMarkupNoId = '''
<html><body>
<div class="container" id="truyen" data-page-size="40" data-total-page="2">
<div class="m-newest2" id="list-chapter">
  <ul class="ul-list5" id="idData">
    <li><a href="/novel/chapter-1.html" title="Chapter 1"><span class="chapter-text">Chapter 1</span></a></li>
    <li><a href="/novel/chapter-2.html" title="Chapter 2"><span class="chapter-text">Chapter 2</span></a></li>
  </ul>
  <div class="page" id="barcon">
    <select id="indexselect">
      <option value="1" data-url="/novel.html">C.1 - C.40</option>
      <option value="2" data-url="/novel.html?page=2">C.41 - C.80</option>
    </select>
  </div>
</div>
</div>
</body></html>''';

const _novelPageNewMarkupNoIdPage2 = '''
<html><body>
<div class="m-newest2" id="list-chapter">
  <ul class="ul-list5" id="idData">
    <li><a href="/novel/chapter-3.html" title="Chapter 3"><span class="chapter-text">Chapter 3</span></a></li>
  </ul>
  <div class="page" id="barcon">
    <select id="indexselect">
      <option value="1" data-url="/novel.html">C.1 - C.40</option>
      <option value="2" data-url="/novel.html?page=2">C.41 - C.80</option>
    </select>
  </div>
</div>
</div>
</body></html>''';

/// Ajax list mixing bare `chapter-N.html` URLs with the `_End` slug style so
/// number-from-URL ordering still lands the finale last.
const _ajaxChapterPageMixedUrls = '''
<html><body><select>
<option value="/novel/chapter-1.html">Chapter 1</option>
<option value="/novel/chapter-2.html">Chapter 2</option>
<option value="/novel/chapter-6492end-chapter-6492-finale.html">Chapter 6492_End - Chapter 6492: Finale</option>
</select></body></html>''';

/// Novel page where og:title and og:image are missing, so the CSS selectors
/// `.m-desc h1.tit` and `.pic img@src` must supply the title and cover.
const _novelPageNoOgTags = '''
<html><head><title>Read Invincible novel online free - NovelFull</title></head><body>
<div class="container" id="truyen" data-page-size="40" data-current-page="1" data-total-page="1" data-total-chapters="1">
  <div class="col-content">
    <div class="m-info">
      <div class="g-tit"><h3 class="tit">Invincible</h3></div>
      <div class="m-book1">
        <div class="m-imgtxt">
          <div class="pic"><img src="/uploads/thumbs/invincible-cover.jpg" alt="Invincible"></div>
        </div>
      </div>
    </div>
    <div class="m-desc hasmore">
      <h1 class="tit">Invincible</h1>
      <div class="score" id="novel-score" data-novel-id="456"></div>
      <div class="m-desc-content" id="novel-summary-inner">
        <p>Weakness is a sin. A story of the strong.</p>
      </div>
    </div>
    <div class="col-info-desc">
      <div class="info">
        <div><h3>Author:</h3><a href="/author/Qi-peasant">Qi Peasant</a></div>
        <div><h3>Genres:</h3><a href="/genre/Action">Action</a>, <a href="/genre/Fantasy">Fantasy</a></div>
        <div><h3>Status:</h3><a href="/status/Ongoing">Ongoing</a></div>
      </div>
    </div>
    <div class="m-newest2" id="list-chapter" data-novel-id="456" data-current-page="1" data-page-size="40" data-total-page="1" data-total-chapters="1">
      <ul class="ul-list5" id="idData">
        <li><a href="/invincible/chapter-1.html" class="con" title="Chapter 1"><span class="chapter-text">Chapter 1</span></a></li>
      </ul>
      <div class="page" id="barcon">
        <select id="indexselect"><option value="1" data-url="/invincible.html" selected>C.1</option></select>
      </div>
    </div>
  </div>
</div>
</body></html>''';

const _searchPage = '''
<html><body>
<div class="row top-item">
  <div class="col-xs-12">
    <div class="top-num top-1">1</div>
    <div class="s-title"><h3><a href="/novel.html" title="Test Novel">Test Novel</a></h3></div>
  </div>
</div>
<div class="row top-item">
  <div class="col-xs-12">
    <div class="top-num top-2">2</div>
    <div class="s-title"><h3><a href="/other-novel.html" title="Other Novel">Other Novel</a></h3></div>
  </div>
</div>
</body></html>''';

class _FakeTransportRegistry extends TransportRegistry {
  const _FakeTransportRegistry(this.transport);

  final Transport transport;

  @override
  Transport create(PluginManifest plugin, {PluginPermissions? permissions}) =>
      transport;
}

Future<void> _copyDir(Directory from, Directory to) async {
  await to.create(recursive: true);
  await for (final entry in from.list()) {
    final dest = p.join(to.path, p.basename(entry.path));
    if (entry is Directory) {
      await _copyDir(entry, Directory(dest));
    } else if (entry is File) {
      await entry.copy(dest);
    }
  }
}

void main() {
  late Directory tempDir;
  late Directory baseDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('atlas_novelfull_plugin');
    baseDir = Directory(p.join(tempDir.path, 'plugins'));
    final source =
        Directory(p.join(Directory.current.path, 'atlas-plugins', 'novelfull'));
    expect(source.existsSync(), isTrue,
        reason: 'flutter test must run from the package root so that '
            'atlas-plugins/novelfull resolves');
    await _copyDir(source, Directory(p.join(baseDir.path, 'novelfull')));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  PluginRepository repo(Transport transport) => PluginRepository(
        baseDirectory: baseDir,
        templateRegistry: TemplateRegistry.defaults,
        transportRegistry: _FakeTransportRegistry(transport),
      );

  group('atlas-plugins/novelfull/plugin.json', () {
    test('loads a valid manifest for the generic html template', () async {
      final manifest = await repo(FakeTransport()).load('novelfull');

      expect(manifest.id, 'novelfull');
      expect(manifest.name, 'NovelFull');
      expect(manifest.sourceName, 'NovelFull');
      expect(manifest.templateId, 'html');
      expect(manifest.transport, 'http');
      expect(manifest.baseUrl, 'https://novelfull.net');
      expect(manifest.language, 'en');
      expect(manifest.customUserAgent, contains('Chrome/124'));
      expect(manifest.requiresJsRendering, isFalse);
      expect(manifest.capabilities.toSet(), {
        PluginCapability.search,
        PluginCapability.chapterList,
        PluginCapability.chapterContent,
        PluginCapability.cover,
      });
      expect(
        TemplateRegistry.defaults.resolve('html'),
        isA<HtmlTemplate>(),
      );
    });

    test('declared capabilities are implemented by the template', () async {
      final manifest = await repo(FakeTransport()).load('novelfull');
      final template = TemplateRegistry.defaults.resolve(manifest.templateId);
      final unsupported = manifest.capabilities
          .where((c) => !template.supportedCapabilities.contains(c));
      expect(unsupported, isEmpty);
    });

    test('loads filters and permissions from the plugin files', () async {
      final repository = repo(FakeTransport());
      final manifest = await repository.load('novelfull');

      final filters = await repository.loadFilters(manifest);
      expect(filters.extraStripSelectors, contains('#frame'));
      expect(filters.disableDefaultStrips, isFalse);

      final permissions = await repository.loadPermissions(manifest);
      expect(permissions.maxConcurrentRequests, 2);
      expect(permissions.requestDelayMs, [400, 1200]);
      expect(permissions.allowOfflineCache, isTrue);
    });
  });

  group('novelfull PluginSource end-to-end', () {
    test('canHandle matches novelfull.net hosts', () async {
      final source = await repo(FakeTransport()).buildSource('novelfull');

      expect(source.canHandle(Uri.parse('https://novelfull.net/novel/x')),
          isTrue);
      expect(source.canHandle(Uri.parse('https://other.com/novel/x')),
          isFalse);
    });

    test('search drives the /search?keyword= endpoint', () async {
      final transport = FakeTransport()
        ..addHtml(
            'https://novelfull.net/search?keyword=test', _searchPage);
      final source = await repo(transport).buildSource('novelfull');

      final response = await source.search(const SourceSearchQuery(term: 'test'));

      expect(response.results, hasLength(2));
      expect(response.results.first.title, 'Test Novel');
      expect(response.results.first.importUrl,
          'https://novelfull.net/novel.html');
    });

    test('getMetadata bridges the plugin to a novel-category NovelModel',
        () async {
      final transport = FakeTransport()..addHtml(_novelUrl, _novelPage);
      final source = await repo(transport).buildSource('novelfull');

      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      expect(novel.category, ContentCategory.novel);
      expect(novel.source, 'NovelFull');
      expect(novel.title, 'Test Novel');
      expect(novel.author, 'Jane Doe');
      expect(novel.description, contains('dragons and dungeons'));
      expect(novel.coverUrl,
          'https://novelfull.net/uploads/thumbs/cover.jpg');
      expect(novel.genres, ['Fantasy', 'Adventure']);
      expect(novel.status, 'Ongoing');
    });

    test('getChapters fetches the full list from the ajax-chapter-option '
        'endpoint and returns ascending order', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPage)
        ..addHtml(
            'https://novelfull.net/ajax-chapter-option?novelId=1',
            _ajaxChapterPage);
      final source = await repo(transport).buildSource('novelfull');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      final chapters = await source.getChapters(novel);

      expect(chapters, hasLength(5));
      expect(chapters.map((c) => c.title).toList(),
          ['Chapter 1', 'Chapter 2', 'Chapter 3', 'Chapter 4', 'Chapter 5']);
      expect(chapters.first.contentUrl, _chapter1Url);
    });

    test('getChapters falls back to the paginated list when no novel id '
        'is present', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl,
            _novelPage.replaceFirst('<div id="rating" data-novel-id="1"></div>',
                '<div id="rating"></div>'))
        ..addHtml('$_novelUrl?page=2', _novelPage2);
      final source = await repo(transport).buildSource('novelfull');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      final chapters = await source.getChapters(novel);

      expect(chapters, hasLength(5));
      expect(chapters.map((c) => c.title).toList(),
          ['Chapter 1', 'Chapter 2', 'Chapter 3', 'Chapter 4', 'Chapter 5']);
      expect(chapters.first.contentUrl, _chapter1Url);
    });

    test('getChapters reads the novel id off the current novelfull.net markup '
        'and fetches the full ajax list', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPageNewMarkup)
        ..addHtml(
            'https://novelfull.net/ajax-chapter-option?novelId=1',
            _ajaxChapterPageMixedUrls);
      final source = await repo(transport).buildSource('novelfull');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      final chapters = await source.getChapters(novel);

      expect(chapters.map((c) => c.title).toList(), [
        'Chapter 1',
        'Chapter 2',
        'Chapter 6492_End - Chapter 6492: Finale',
      ]);
      expect(chapters.last.contentUrl,
          'https://novelfull.net/novel/chapter-6492end-chapter-6492-finale.html');
    });

    test('getChapters walks the new select-bar pagination when no novel id '
        'is present', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPageNewMarkupNoId)
        ..addHtml('$_novelUrl?page=2', _novelPageNewMarkupNoIdPage2);
      final source = await repo(transport).buildSource('novelfull');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      final chapters = await source.getChapters(novel);

      expect(chapters.map((c) => c.title).toList(),
          ['Chapter 1', 'Chapter 2', 'Chapter 3']);
      expect(chapters.first.contentUrl,
          'https://novelfull.net/novel/chapter-1.html');
    });

    test('getChapter fetches content through the clean pipeline', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPage)
        ..addHtml(_chapter1Url, _chapterPage);
      final source = await repo(transport).buildSource('novelfull');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));
      final chapters = await source.getChapters(novel);

      final chapter = await source.getChapter(chapters.first);

      expect(chapter.title, 'Chapter 1');
      expect(chapter.content, contains('First paragraph of the chapter body.'));
      expect(chapter.content, contains('Second paragraph.'));
      expect(chapter.content, isNot(contains('Advertisement')));
      expect(chapter.wordCount, greaterThan(0));
    });

    test('metadata selectors supply title and cover when og: tags are missing',
        () async {
      final transport = FakeTransport()..addHtml(_novelUrl, _novelPageNoOgTags);
      final source = await repo(transport).buildSource('novelfull');

      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      expect(novel.title, 'Invincible',
          reason: '.m-desc h1.tit must be used instead of <title> tag');
      expect(novel.author, 'Qi Peasant');
      expect(novel.description, contains('Weakness is a sin'));
      expect(novel.coverUrl,
          'https://novelfull.net/uploads/thumbs/invincible-cover.jpg',
          reason: '.pic img@src must resolve the relative URL');
      expect(novel.genres, ['Action', 'Fantasy']);
      expect(novel.source, 'NovelFull');
    });
  });
}
