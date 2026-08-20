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

const _novelUrl = 'https://freewebnovel.com/novel/defying-the-lycan-king';
const _chapter1Url =
    'https://freewebnovel.com/novel/defying-the-lycan-king/chapter-1';

const _novelPage = '''
<html><head>
<meta name="description" content="She has spent her life believing she's cursed.">
<meta property="og:title" content="Defying the Lycan King">
<meta property="og:image" content="https://freewebnovel.com/files/article/image/13/13246/13246s.jpg">
<meta property="og:description" content="Defying the Lycan King - She has spent her life believing she's cursed.">
</head><body>
<div class="m-desc"><h1 class="tit">Defying the Lycan King</h1></div>
<ul class="ul-list5" id="idData">
  <li><span class="glyphicon glyphicon-book right-5"></span><a href="/novel/defying-the-lycan-king/chapter-1" title="Chapter 1: The Hated One" class="con">Chapter 1: The Hated One</a></li>
  <li><span class="glyphicon glyphicon-book right-5"></span><a href="/novel/defying-the-lycan-king/chapter-2" title="Chapter 2: Daddy Dearest" class="con">Chapter 2: Daddy Dearest</a></li>
</ul>
<div class="page" id="barcon" name="barcon">
  <select id="indexselect">
    <option value="/novel/defying-the-lycan-king">C.1 - C.40</option>
    <option value="/novel/defying-the-lycan-king">C.41 - C.80</option>
  </select>
</div>
</body></html>''';

const _novelPage2 = '''
<html><body>
<ul class="ul-list5" id="idData">
  <li><a href="/novel/defying-the-lycan-king/chapter-3" title="Chapter 3" class="con">Chapter 3</a></li>
  <li><a href="/novel/defying-the-lycan-king/chapter-4" title="Chapter 4" class="con">Chapter 4</a></li>
</ul>
</body></html>''';

const _chapterPage = '''
<html><body>
<div class="m-read">
  <div class="top">
    <h1 class="tit"><a href="/novel/defying-the-lycan-king">Defying the Lycan King</a></h1>
    <span class="chapter">Chapter 1: The Hated One</span>
  </div>
  <div class="ul-list7">
    <ul>
      <li><a href="/novel/defying-the-lycan-king" title="Next Chapter"><span class="glyphicon glyphicon-chevron-right"></span>Next Chapter</a></li>
    </ul>
  </div>
  <div class="txt" style="font-family:Arial;font-size:18px;line-height:160%">
    <p>Derek stayed exactly where he was on the ground.</p>
    <p>She has spent her life believing she's cursed.</p>
    <div class="ads ads-holder"><p>Advertisement</p></div>
  </div>
</div>
</body></html>''';

const _searchPage = '''
<html><body>
<div class="col-content">
  <div class="ul-list1 ul-list1-2 ss-custom rank-list">
    <div class="li-row"><div class="li"><div class="con">
      <div class="pic"><a href="/novel/defying-the-lycan-king"><img src="/files/article/image/13/13246/13246s.jpg" alt="Defying the Lycan King"></a></div>
      <div class="txt"><h3 class="tit"><a href="/novel/defying-the-lycan-king" title="Defying the Lycan King">Defying the Lycan King</a></h3></div>
    </div></div></div>
    <div class="li-row"><div class="li"><div class="con">
      <div class="pic"><a href="/novel/she-used-me"><img src="/files/article/image/10/10859/10859s.jpg" alt="She Used Me"></a></div>
      <div class="txt"><h3 class="tit"><a href="/novel/she-used-me" title="She Used Me">She Used Me</a></h3></div>
    </div></div></div>
  </div>
</div>
</body></html>''';

const _novelPageNoOgTags = '''
<html><head>
<title>Defying the Lycan King Novel | Free Web Novel</title>
<meta name="description" content="She has spent her life believing she's cursed.">
</head><body>
<div class="m-desc"><h1 class="tit">Defying the Lycan King</h1></div>
<div class="pic"><img src="/files/article/image/13/13246/13246s.jpg" alt="Defying the Lycan King"></div>
<ul class="ul-list5" id="idData">
  <li><a href="/novel/defying-the-lycan-king/chapter-1" title="Chapter 1: The Hated One" class="con">Chapter 1: The Hated One</a></li>
</ul>
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
    tempDir = await Directory.systemTemp.createTemp('atlas_freewebnovel_plugin');
    baseDir = Directory(p.join(tempDir.path, 'plugins'));
    final source =
        Directory(p.join(Directory.current.path, 'atlas-plugins', 'freewebnovel'));
    expect(source.existsSync(), isTrue,
        reason: 'flutter test must run from the package root so that '
            'atlas-plugins/freewebnovel resolves');
    await _copyDir(source, Directory(p.join(baseDir.path, 'freewebnovel')));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  PluginRepository repo(Transport transport) => PluginRepository(
        baseDirectory: baseDir,
        templateRegistry: TemplateRegistry.defaults,
        transportRegistry: _FakeTransportRegistry(transport),
      );

  group('atlas-plugins/freewebnovel/plugin.json', () {
    test('loads a valid manifest for the generic html template', () async {
      final manifest = await repo(FakeTransport()).load('freewebnovel');

      expect(manifest.id, 'freewebnovel');
      expect(manifest.name, 'FreeWebNovel');
      expect(manifest.sourceName, 'FreeWebNovel');
      expect(manifest.templateId, 'html');
      expect(manifest.transport, 'http');
      expect(manifest.baseUrl, 'https://freewebnovel.com');
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
      final manifest = await repo(FakeTransport()).load('freewebnovel');
      final template = TemplateRegistry.defaults.resolve(manifest.templateId);
      final unsupported = manifest.capabilities
          .where((c) => !template.supportedCapabilities.contains(c));
      expect(unsupported, isEmpty);
    });

    test('loads filters and permissions from the plugin files', () async {
      final repository = repo(FakeTransport());
      final manifest = await repository.load('freewebnovel');

      final filters = await repository.loadFilters(manifest);
      expect(filters.extraStripSelectors, contains('.m-read .top'));
      expect(filters.extraStripSelectors, contains('.m-read .ul-list7'));
      expect(filters.disableDefaultStrips, isFalse);

      final permissions = await repository.loadPermissions(manifest);
      expect(permissions.maxConcurrentRequests, 2);
      expect(permissions.requestDelayMs, [400, 1200]);
      expect(permissions.allowOfflineCache, isTrue);
    });
  });

  group('freewebnovel PluginSource end-to-end', () {
    test('canHandle matches freewebnovel.com hosts', () async {
      final source = await repo(FakeTransport()).buildSource('freewebnovel');

      expect(source.canHandle(Uri.parse('https://freewebnovel.com/novel/x')),
          isTrue);
      expect(source.canHandle(Uri.parse('https://other.com/novel/x')),
          isFalse);
    });

    test('search drives the /search?keyword= endpoint', () async {
      final transport = FakeTransport()
        ..addHtml(
            'https://freewebnovel.com/search?keyword=defying', _searchPage);
      final source = await repo(transport).buildSource('freewebnovel');

      final response =
          await source.search(const SourceSearchQuery(term: 'defying'));

      expect(response.results, hasLength(2));
      expect(response.results.first.title, 'Defying the Lycan King');
      expect(response.results.first.importUrl, _novelUrl);
      expect(response.results.first.coverUrl,
          'https://freewebnovel.com/files/article/image/13/13246/13246s.jpg');
    });

    test('getMetadata bridges the plugin to a novel-category NovelModel',
        () async {
      final transport = FakeTransport()..addHtml(_novelUrl, _novelPage);
      final source = await repo(transport).buildSource('freewebnovel');

      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      expect(novel.category, ContentCategory.novel);
      expect(novel.source, 'FreeWebNovel');
      expect(novel.title, 'Defying the Lycan King');
      expect(novel.description, contains("she's cursed"));
      expect(novel.coverUrl,
          'https://freewebnovel.com/files/article/image/13/13246/13246s.jpg');
    });

    test('getChapters walks the paginated index and merges in order', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPage)
        ..addHtml('$_novelUrl?page=2', _novelPage2);
      final source = await repo(transport).buildSource('freewebnovel');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      final chapters = await source.getChapters(novel);

      expect(chapters, hasLength(4));
      expect(chapters.map((c) => c.title).toList(), [
        'Chapter 1: The Hated One',
        'Chapter 2: Daddy Dearest',
        'Chapter 3',
        'Chapter 4',
      ]);
      expect(chapters.first.contentUrl, _chapter1Url);
    });

    test('getChapter fetches content through the clean pipeline', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPage)
        ..addHtml(_chapter1Url, _chapterPage);
      final source = await repo(transport).buildSource('freewebnovel');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));
      final chapters = await source.getChapters(novel);

      final chapter = await source.getChapter(chapters.first);

      expect(chapter.title, 'Chapter 1: The Hated One');
      expect(chapter.content, contains('Derek stayed exactly where he was'));
      expect(chapter.content, contains("she's cursed"));
      expect(chapter.content, isNot(contains('Advertisement')));
      expect(chapter.content, isNot(contains('Next Chapter')));
      expect(chapter.content, isNot(contains('Defying the Lycan King')));
      expect(chapter.wordCount, greaterThan(0));
    });

    test('metadata selectors supply title and cover when og: tags are missing',
        () async {
      final transport = FakeTransport()..addHtml(_novelUrl, _novelPageNoOgTags);
      final source = await repo(transport).buildSource('freewebnovel');

      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      expect(novel.title, 'Defying the Lycan King',
          reason: '.m-desc h1.tit must be used instead of <title> tag');
      expect(novel.description, contains("she's cursed"));
      expect(novel.coverUrl,
          'https://freewebnovel.com/files/article/image/13/13246/13246s.jpg',
          reason: '.pic img@src must resolve the relative URL');
      expect(novel.source, 'FreeWebNovel');
    });
  });
}
