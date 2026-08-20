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

const _base = 'https://novgo.net';
const _novelUrl = '$_base/overlord-ln.html';
const _chapter1Url = '$_base/overlord-ln/chapter-1.html';
const _ajaxUrl = '$_base/ajax-chapter-option?novelId=377';

const _novelPage = '''
<html><head>
<meta property="og:title" content="Read Overlord (LN) novel online free - NOVGO.NET">
<meta property="og:image" content="$_base/uploads/thumbs/overlord-ln-b4ea0524cf.jpg">
<meta property="og:description" content="Experience the official release of Overlord (LN) online.">
</head><body>
<div class="col-xs-12 col-info-desc">
  <div class="col-xs-12 col-sm-4 col-md-4 info-holder">
    <div class="books">
      <div class="desc"><h3 class="title">Overlord (LN)</h3></div>
      <div class="book"><img src="/uploads/thumbs/overlord-ln-b4ea0524cf.jpg" alt="Read Overlord (LN) Online"></div>
    </div>
    <div class="info">
      <div><h3>Author:</h3><a href="/author/MARUYAMA+Kugane">MARUYAMA Kugane</a></div>
      <div><h3>Genre:</h3><a href="/genre/Action">Action</a>, <a href="/genre/Fantasy">Fantasy</a>, <a href="/genre/Harem">Harem</a></div>
      <div><h3>Status:</h3><a href="/status/Completed">Completed</a></div>
    </div>
  </div>
  <div class="col-xs-12 col-sm-8 col-md-8 desc">
    <div id="rating" data-novel-id="377"></div>
    <div class="desc-text">
      <p>Experience the official release of Overlord (LN) online. After announcing it will be discontinuing all service, the internet game Yggdrasil shut down&hellip;</p>
    </div>
    <div id="list-chapter">
      <ul class="list-chapter">
        <li><a href="/overlord-ln/chapter-1.html" title="Chapter 1"><span class="chapter-text">Chapter 1</span></a></li>
        <li><a href="/overlord-ln/chapter-2.html" title="Chapter 2"><span class="chapter-text">Chapter 2</span></a></li>
      </ul>
    </div>
  </div>
</div>
</body></html>''';

/// What `/ajax-chapter-option?novelId=377` returns: a `<select>` of options.
const _archivePage = '''
<select class="btn btn-success form-control chapter_jump">
<option value="/overlord-ln/chapter-1.html">Chapter 1</option>
<option value="/overlord-ln/chapter-2.html">Chapter 2</option>
<option value="/overlord-ln/chapter-3.html">Chapter 3</option>
<option value="/overlord-ln/chapter-4.html">Chapter 4</option>
</select>''';

const _chapterPage = '''
<html><head><title>Chapter 1 - Overlord (LN)</title></head>
<body>
<div id="chapter" class="chapter container">
  <div class="col-xs-12">
    <a class="truyen-title" href="/overlord-ln.html" title="Overlord (LN)">Overlord (LN)</a>
    <h2><a class="chapter-title" href="/overlord-ln/chapter-1.html" title="Chapter 1">Chapter 1</a></h2>
  </div>
  <div id="chapter-content" class="chapter-c">
    <p>Momonga stood in the throne room of the Great Tomb of Nazarick.</p>
    <div class="box-notice">Advertisement placeholder</div>
    <p>The guild NPCs had started to act of their own accord, and the tomb had come alive.</p>
  </div>
</div>
</body></html>''';

const _searchPage = '''
<html><body>
<div class="row top-item">
  <div class="s-title"><h3><a href="$_novelUrl">Overlord (LN)</a></h3></div>
</div>
<div class="row top-item">
  <div class="s-title"><h3><a href="$_base/another-ln.html">Another (LN)</a></h3></div>
</div>
</body></html>''';

const _novelPageNoOgTags = '''
<html><head><title>Read Overlord (LN) novel online free - NOVGO.NET</title></head><body>
<div class="col-xs-12 col-info-desc">
  <div class="col-xs-12 col-sm-4 col-md-4 info-holder">
    <div class="books">
      <div class="desc"><h3 class="title">Overlord (LN)</h3></div>
      <div class="book"><img src="/uploads/thumbs/overlord-ln-b4ea0524cf.jpg" alt="Overlord (LN)"></div>
    </div>
    <div class="info">
      <div><h3>Author:</h3><a href="/author/MARUYAMA+Kugane">MARUYAMA Kugane</a></div>
      <div><h3>Genre:</h3><a href="/genre/Action">Action</a>, <a href="/genre/Fantasy">Fantasy</a></div>
      <div><h3>Status:</h3><a href="/status/Completed">Completed</a></div>
    </div>
  </div>
  <div class="col-xs-12 col-sm-8 col-md-8 desc">
    <div class="desc-text">
      <p>Experience the official release of Overlord (LN) online.</p>
    </div>
    <div id="list-chapter">
      <ul class="list-chapter">
        <li><a href="/overlord-ln/chapter-1.html" title="Chapter 1"><span class="chapter-text">Chapter 1</span></a></li>
      </ul>
    </div>
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
    tempDir = await Directory.systemTemp.createTemp('atlas_allnovelfull_plugin');
    baseDir = Directory(p.join(tempDir.path, 'plugins'));
    final source = Directory(
        p.join(Directory.current.path, 'atlas-plugins', 'allnovelfull'));
    expect(source.existsSync(), isTrue,
        reason: 'flutter test must run from the package root so that '
            'atlas-plugins/allnovelfull resolves');
    await _copyDir(source, Directory(p.join(baseDir.path, 'allnovelfull')));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  PluginRepository repo(Transport transport) => PluginRepository(
        baseDirectory: baseDir,
        templateRegistry: TemplateRegistry.defaults,
        transportRegistry: _FakeTransportRegistry(transport),
      );

  group('atlas-plugins/allnovelfull/plugin.json', () {
    test('loads a valid manifest for the generic html template', () async {
      final manifest = await repo(FakeTransport()).load('allnovelfull');

      expect(manifest.id, 'allnovelfull');
      expect(manifest.name, 'AllNovelFull');
      expect(manifest.sourceName, 'AllNovelFull');
      expect(manifest.templateId, 'html');
      expect(manifest.transport, 'http');
      expect(manifest.baseUrl, _base);
      expect(manifest.language, 'en');
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
      final manifest = await repo(FakeTransport()).load('allnovelfull');
      final template = TemplateRegistry.defaults.resolve(manifest.templateId);
      final unsupported = manifest.capabilities
          .where((c) => !template.supportedCapabilities.contains(c));
      expect(unsupported, isEmpty);
    });

    test('loads filters and permissions from the plugin files', () async {
      final repository = repo(FakeTransport());
      final manifest = await repository.load('allnovelfull');

      final filters = await repository.loadFilters(manifest);
      expect(filters.extraStripSelectors, contains('.box-notice'));
      expect(filters.disableDefaultStrips, isFalse);

      final permissions = await repository.loadPermissions(manifest);
      expect(permissions.maxConcurrentRequests, 2);
      expect(permissions.requestDelayMs, [400, 1200]);
      expect(permissions.allowOfflineCache, isTrue);
    });
  });

  group('allnovelfull PluginSource end-to-end', () {
    test('canHandle matches the novgo.net host (formerly allnovelfull.net)',
        () async {
      final source = await repo(FakeTransport()).buildSource('allnovelfull');

      expect(source.canHandle(Uri.parse('$_base/overlord-ln.html')), isTrue);
      expect(source.canHandle(Uri.parse('https://other.com/novel/x')),
          isFalse);
    });

    test('search drives the /search?keyword= endpoint', () async {
      final transport = FakeTransport()
        ..addHtml('$_base/search?keyword=overlord', _searchPage);
      final source = await repo(transport).buildSource('allnovelfull');

      final response =
          await source.search(const SourceSearchQuery(term: 'overlord'));

      expect(response.results, hasLength(2));
      expect(response.results.first.title, 'Overlord (LN)');
      expect(response.results.first.importUrl, _novelUrl);
    });

    test('getMetadata reads the .col-info-desc info rows', () async {
      final transport = FakeTransport()..addHtml(_novelUrl, _novelPage);
      final source = await repo(transport).buildSource('allnovelfull');

      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      expect(novel.category, ContentCategory.novel);
      expect(novel.source, 'AllNovelFull');
      expect(novel.title, 'Overlord (LN)');
      expect(novel.author, 'MARUYAMA Kugane');
      expect(novel.genres, ['Action', 'Fantasy', 'Harem']);
      expect(novel.status, 'Completed');
      expect(novel.description, contains('official release of Overlord'));
      expect(novel.coverUrl,
          '$_base/uploads/thumbs/overlord-ln-b4ea0524cf.jpg');
    });

    test('getChapters GETs the ajax-chapter-option archive', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPage)
        ..addHtml(_ajaxUrl, _archivePage);
      final source = await repo(transport).buildSource('allnovelfull');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      final chapters = await source.getChapters(novel);

      expect(chapters, hasLength(4));
      expect(chapters.map((c) => c.title).toList(), [
        'Chapter 1',
        'Chapter 2',
        'Chapter 3',
        'Chapter 4',
      ]);
      expect(chapters.first.contentUrl, _chapter1Url);
    });

    test('getChapter fetches content through the clean pipeline', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPage)
        ..addHtml(_ajaxUrl, _archivePage)
        ..addHtml(_chapter1Url, _chapterPage);
      final source = await repo(transport).buildSource('allnovelfull');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));
      final chapters = await source.getChapters(novel);

      final chapter = await source.getChapter(chapters.first);

      expect(chapter.title, 'Chapter 1');
      expect(chapter.content, contains('throne room of the Great Tomb'));
      expect(chapter.content, contains('tomb had come alive'));
      expect(chapter.content, isNot(contains('Advertisement')));
      expect(chapter.content, isNot(contains('Back to novel')));
      expect(chapter.wordCount, greaterThan(0));
    });

    test('metadata selectors supply title and cover when og: tags are polluted',
        () async {
      final transport = FakeTransport()..addHtml(_novelUrl, _novelPageNoOgTags);
      final source = await repo(transport).buildSource('allnovelfull');

      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      expect(novel.title, 'Overlord (LN)',
          reason: '.desc h3.title must be used instead of polluted og:title');
      expect(novel.author, 'MARUYAMA Kugane');
      expect(novel.description, contains('official release of Overlord'));
      expect(novel.coverUrl,
          '$_base/uploads/thumbs/overlord-ln-b4ea0524cf.jpg',
          reason: '.book img@src must resolve the relative URL');
      expect(novel.source, 'AllNovelFull');
    });
  });
}
