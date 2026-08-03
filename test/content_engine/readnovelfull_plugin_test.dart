import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_permissions.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_repository.dart';
import 'package:atlas_app/core/content_engine/templates/novelfull_template.dart';
import 'package:atlas_app/core/content_engine/templates/template_registry.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/content_engine/transport/transport_registry.dart';

import 'test_fixtures.dart';

const _novelUrl = 'https://readnovelfull.com/lord-of-the-realm.html';
const _archiveUrl =
    'https://readnovelfull.com/ajax/chapter-archive?novelId=2667';
const _chapter1Url =
    'https://readnovelfull.com/lord-of-the-realm/chapter-1-forbidden-love.html';

const _novelPage = '''
<html><head>
<meta name="description" content="Read Lord of the Realm novel online free.">
<meta name="og:title" content="Lord of the Realm">
<meta name="og:image" content="https://img.readnovelfull.com/thumb/t-300x439/lord-of-the-realm.jpg">
<meta name="og:description" content="Steampunk, magic and secret arts, the righteous moon gods.">
</head><body>
<div class="col-info-desc">
<div class="info-holder">
  <div class="desc"><h3 class="title">Lord of the Realm</h3></div>
</div>
<div class="rate-info">
  <input type="hidden" id="rateVal" value="8.9">
  <div id="rating" data-novel-id="2667"></div>
</div>
<ul class="info info-meta">
  <li><h3>Alternative names: </h3>LOTR</li>
  <li><h3>Author:</h3><a href="/authors/guijingzhuzai">Guijingzhuzai</a></li>
  <li><h3>Genre:</h3><a href="/genres/action">Action</a>, <a href="/genres/fantasy">Fantasy</a></li>
  <li><h3>Status:</h3><a href="/novel-list/completed-novel" class="text-primary">Completed</a></li>
</ul>
</div>
<div class="desc-text"><p>Steampunk, magic and secret arts, the righteous moon gods and the mysterious realm.</p></div>
<div class="col-xs-12" id="list-chapter">
  <ul class="list-chapter">
    <li><a href="/lord-of-the-realm/chapter-1-forbidden-love.html" title="Chapter 1"><span class="nchr-text">Chapter 1: Forbidden love</span></a></li>
  </ul>
</div>
</body></html>''';

const _archivePage = '''
<html><body>
<div class="panel-body">
  <ul class="list-chapter">
    <li><a href="/lord-of-the-realm/chapter-1-forbidden-love.html" title="Chapter 1: Forbidden love"><span class="nchr-text">Chapter 1: Forbidden love</span></a></li>
    <li><a href="/lord-of-the-realm/chapter-2-the-awakening.html" title="Chapter 2: The Awakening"><span class="nchr-text">Chapter 2: The Awakening</span></a></li>
    <li><a href="/lord-of-the-realm/chapter-3-a-paradise.html" title="Chapter 3: A Paradise"><span class="nchr-text">Chapter 3: A Paradise</span></a></li>
    <li><a href="/lord-of-the-realm/chapter-4-daughter-rejects-mother-steps-in.html" title="Chapter 4"><span class="nchr-text">Chapter 4: Daughter rejects, mother steps in</span></a></li>
    <li><a href="/lord-of-the-realm/chapter-5-my-girlfriends-mother.html" title="Chapter 5"><span class="nchr-text">Chapter 5: My girlfriend's mother</span></a></li>
  </ul>
</div>
</body></html>''';

const _chapterPage = '''
<html><body>
<h2><a class="chr-title" href="/lord-of-the-realm/chapter-1-forbidden-love.html" title="Chapter 1: Forbidden love"><span class="chr-text">Chapter 1: Forbidden love</span></a></h2>
<div id="chr-content" class="chr-c">
  <h3>Chapter 1: Forbidden love</h3>
  <br><br>
  <p>The first light of dawn crept over the jagged peaks of Frostvale.</p>
  <br>
  <p>Winter had tightened its grip on the valley below.</p>
</div>
</body></html>''';

const _searchPage = '''
<html><body>
<div class="list list-novel">
  <div class="row">
    <div class="col-xs-3"><div><img src="https://img.readnovelfull.com/thumb/t-200x89/lord-of-the-realm.jpg" class="cover" alt="Lord of the Realm"></div></div>
    <div class="col-xs-7"><div><h3 class="novel-title"><a href="/lord-of-the-realm.html" title="Lord of the Realm">Lord of the Realm</a></h3><span class="author">Guijingzhuzai</span></div></div>
    <div class="col-xs-2 text-info"><div><a href="/lord-of-the-realm/chapter-274-is-he-your-boytoy.html" title="Chapter 274"><span class="chr-text">Chapter 274</span></a></div></div>
  </div>
  <div class="row">
    <div class="col-xs-7"><div><h3 class="novel-title"><a href="/lord-of-winter.html" title="Lord of Winter">Lord of Winter</a></h3><span class="author">Soy Milk</span></div></div>
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
    tempDir = await Directory.systemTemp.createTemp('atlas_readnovelfull_plugin');
    baseDir = Directory(p.join(tempDir.path, 'plugins'));
    final source =
        Directory(p.join(Directory.current.path, 'atlas-plugins', 'readnovelfull'));
    expect(source.existsSync(), isTrue,
        reason: 'flutter test must run from the package root so that '
            'atlas-plugins/readnovelfull resolves');
    await _copyDir(source, Directory(p.join(baseDir.path, 'readnovelfull')));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  PluginRepository repo(Transport transport) => PluginRepository(
        baseDirectory: baseDir,
        templateRegistry: TemplateRegistry.defaults,
        transportRegistry: _FakeTransportRegistry(transport),
      );

  group('atlas-plugins/readnovelfull/plugin.json', () {
    test('loads a valid manifest for the novelfull template', () async {
      final manifest = await repo(FakeTransport()).load('readnovelfull');

      expect(manifest.id, 'readnovelfull');
      expect(manifest.name, 'ReadNovelFull');
      expect(manifest.sourceName, 'ReadNovelFull');
      expect(manifest.templateId, 'novelfull');
      expect(manifest.transport, 'http');
      expect(manifest.baseUrl, 'https://readnovelfull.com');
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
        TemplateRegistry.defaults.resolve('novelfull'),
        isA<NovelfullTemplate>(),
      );
    });

    test('declared capabilities are implemented by the template', () async {
      final manifest = await repo(FakeTransport()).load('readnovelfull');
      final template = TemplateRegistry.defaults.resolve(manifest.templateId);
      final unsupported = manifest.capabilities
          .where((c) => !template.supportedCapabilities.contains(c));
      expect(unsupported, isEmpty);
    });

    test('loads filters and permissions from the plugin files', () async {
      final repository = repo(FakeTransport());
      final manifest = await repository.load('readnovelfull');

      final filters = await repository.loadFilters(manifest);
      expect(filters.extraStripSelectors, contains('.ads-holder'));
      expect(filters.disableDefaultStrips, isFalse);

      final permissions = await repository.loadPermissions(manifest);
      expect(permissions.maxConcurrentRequests, 2);
      expect(permissions.requestDelayMs, [400, 1200]);
      expect(permissions.allowOfflineCache, isTrue);
    });
  });

  group('readnovelfull PluginSource end-to-end', () {
    test('canHandle matches readnovelfull.com hosts', () async {
      final source = await repo(FakeTransport()).buildSource('readnovelfull');

      expect(
          source.canHandle(Uri.parse('https://readnovelfull.com/novel/x')),
          isTrue);
      expect(source.canHandle(Uri.parse('https://other.com/novel/x')),
          isFalse);
    });

    test('search drives the /novel-list/search?keyword= endpoint', () async {
      final transport = FakeTransport()
        ..addHtml(
            'https://readnovelfull.com/novel-list/search?keyword=lord',
            _searchPage);
      final source = await repo(transport).buildSource('readnovelfull');

      final response =
          await source.search(const SourceSearchQuery(term: 'lord'));

      expect(response.results, hasLength(2));
      expect(response.results.first.title, 'Lord of the Realm');
      expect(response.results.first.importUrl, _novelUrl);
    });

    test('getMetadata bridges the plugin to a novel-category NovelModel',
        () async {
      final transport = FakeTransport()..addHtml(_novelUrl, _novelPage);
      final source = await repo(transport).buildSource('readnovelfull');

      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      expect(novel.category, ContentCategory.novel);
      expect(novel.source, 'ReadNovelFull');
      expect(novel.title, 'Lord of the Realm');
      expect(novel.author, 'Guijingzhuzai');
      expect(novel.description, contains('Steampunk, magic and secret arts'));
      expect(novel.coverUrl,
          'https://img.readnovelfull.com/thumb/t-300x439/lord-of-the-realm.jpg');
      expect(novel.genres, ['Action', 'Fantasy']);
      expect(novel.status, 'Completed');
    });

    test('getChapters fetches the full archive from ajaxPath and returns '
        'ascending order', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPage)
        ..addHtml(_archiveUrl, _archivePage);
      final source = await repo(transport).buildSource('readnovelfull');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      final chapters = await source.getChapters(novel);

      expect(chapters, hasLength(5));
      expect(chapters.map((c) => c.title).toList(), [
        'Chapter 1: Forbidden love',
        'Chapter 2: The Awakening',
        'Chapter 3: A Paradise',
        'Chapter 4: Daughter rejects, mother steps in',
        "Chapter 5: My girlfriend's mother",
      ]);
      expect(chapters.first.contentUrl, _chapter1Url);
    });

    test('getChapters falls back to the in-page list when the archive '
        'endpoint is unreachable', () async {
      final transport = FakeTransport()..addHtml(_novelUrl, _novelPage);
      final source = await repo(transport).buildSource('readnovelfull');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      final chapters = await source.getChapters(novel);

      expect(chapters, hasLength(1));
      expect(chapters.first.title, 'Chapter 1: Forbidden love');
      expect(chapters.first.contentUrl, _chapter1Url);
    });

    test('getChapter fetches content through the clean pipeline', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPage)
        ..addHtml(_archiveUrl, _archivePage)
        ..addHtml(_chapter1Url, _chapterPage);
      final source = await repo(transport).buildSource('readnovelfull');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));
      final chapters = await source.getChapters(novel);

      final chapter = await source.getChapter(chapters.first);

      expect(chapter.title, 'Chapter 1: Forbidden love');
      expect(chapter.content, contains('Frostvale'));
      expect(chapter.content, contains('grip on the valley below'));
      expect(chapter.content, isNot(contains('Prev Chapter')));
      expect(chapter.wordCount, greaterThan(0));
    });
  });
}
