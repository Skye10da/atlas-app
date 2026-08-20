import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_permissions.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_repository.dart';
import 'package:atlas_app/core/content_engine/templates/royalroad_template.dart';
import 'package:atlas_app/core/content_engine/templates/template_registry.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/content_engine/transport/transport_registry.dart';

import 'test_fixtures.dart';

const _novelUrl = 'https://www.royalroad.com/fiction/21220/mother-of-learning';
const _chapter1Url =
    'https://www.royalroad.com/fiction/21220/mother-of-learning/chapter/301778/1-good-morning-brother';

const _ldJson =
    '''{"@context":"https://schema.org","@type":"Book","name":"Mother of Learning","description":"\\u003Cp\\u003EZorian is a teenage mage of humble birth and slightly above-average skill, attending his third year of education at Cyoria\\u0027s magical academy.\\u003C/p\\u003E","dateModified":"2018-10-28T21:45:44Z","author":{"@type":"Person","@id":"/profile/100374","name":"nobody103"},"aggregateRating":{"@type":"AggregateRating","bestRating":5,"ratingValue":4.83,"ratingCount":17241}}''';

const _chaptersScript =
    '''window.chapters = [{"id":301778,"volumeId":null,"title":"1. Good Morning Brother","slug":"1-good-morning-brother","date":"2018-10-28T21:34:43Z","order":0,"visible":1,"subscriptionTiers":null,"doesNotRollOver":false,"isUnlocked":true,"url":"/fiction/21220/mother-of-learning/chapter/301778/1-good-morning-brother"},{"id":301781,"volumeId":null,"title":"2. Life's Little Problems","slug":"2-lifes-little-problems","date":"2018-10-28T21:45:44Z","order":1,"visible":1,"subscriptionTiers":null,"doesNotRollOver":false,"isUnlocked":true,"url":"/fiction/21220/mother-of-learning/chapter/301781/2-lifes-little-problems"}]; window.volumes = []; window.readingProgress = null;''';

const _novelPage =
    '''
<html><head>
<title>Mother of Learning | Royal Road</title>
<meta name="description" content="Zorian is a teenage mage of humble birth and slightly above-average skill.">
<script type="application/ld+json">$_ldJson</script>
<script type="text/javascript">
var mvl = {}; window.fictionId = 21220;
$_chaptersScript
</script>
</head><body>
<div class="page-content-inner">
  <div class="row fic-header">
    <div class="col-md-3 text-center cover-col">
      <div class="cover-art-container">
        <img class="thumbnail inline-block" data-type="cover" alt="Mother of Learning" src="https://www.royalroadcdn.com/public/covers-full/21220-mother-of-learning.jpg?time=1637247458">
      </div>
    </div>
    <div class="col-md-5 col-lg-6 text-center md-text-left fic-title">
      <div class="col">
        <h1 class="font-white">Mother of Learning</h1>
        <h4 class="font-white">
          <span class="small font-white">by </span>
          <span><a href="/profile/100374" class="font-white">nobody103</a></span>
        </h4>
      </div>
    </div>
    <div class="col-md-4 col-lg-3 text-center">
      <div class="margin-bottom-10" style="min-height: 10px">
        <span class="label label-default label-sm bg-blue-hoki">Original</span>
        <span class="label label-default label-sm bg-blue-hoki"> COMPLETED </span>
        <span class="tags">
          <a class="label label-default label-sm bg-blue-dark fiction-tag" href="/fictions/search?tagsAdd=loop">Time Loop</a>
          <a class="label label-default label-sm bg-blue-dark fiction-tag" href="/fictions/search?tagsAdd=adventure">Adventure</a>
          <a class="label label-default label-sm bg-blue-dark fiction-tag" href="/fictions/search?tagsAdd=fantasy">Fantasy</a>
        </span>
      </div>
    </div>
  </div>
  <div class="col-lg-12">
    <table class="table no-border" id="chapters" data-chapters="109">
      <tbody>
        <tr style="cursor: pointer" data-url="/fiction/21220/mother-of-learning/chapter/301778/1-good-morning-brother" data-volume-id="null" class="chapter-row">
          <td><a href="/fiction/21220/mother-of-learning/chapter/301778/1-good-morning-brother"> 1. Good Morning Brother </a></td>
        </tr>
        <tr style="cursor: pointer" data-url="/fiction/21220/mother-of-learning/chapter/301781/2-lifes-little-problems" data-volume-id="null" class="chapter-row">
          <td><a href="/fiction/21220/mother-of-learning/chapter/301781/2-lifes-little-problems"> 2. Life's Little Problems </a></td>
        </tr>
      </tbody>
    </table>
  </div>
</div>
</body></html>''';

/// A fiction page rendered without the `window.chapters` script, so the
/// chapterList falls back to the server-rendered `table#chapters` rows.
const _novelPageNoScript = '''
<html><body>
<div class="page-content-inner">
  <div class="row fic-header">
    <div class="col-md-5 col-lg-6 text-center md-text-left fic-title">
      <div class="col"><h1 class="font-white">Mother of Learning</h1></div>
    </div>
  </div>
  <div class="col-lg-12">
    <table class="table no-border" id="chapters" data-chapters="109">
      <tbody>
        <tr data-url="/fiction/21220/mother-of-learning/chapter/301778/1-good-morning-brother" class="chapter-row">
          <td><a href="/fiction/21220/mother-of-learning/chapter/301778/1-good-morning-brother"> 1. Good Morning Brother </a></td>
        </tr>
        <tr data-url="/fiction/21220/mother-of-learning/chapter/301781/2-lifes-little-problems" class="chapter-row">
          <td><a href="/fiction/21220/mother-of-learning/chapter/301781/2-lifes-little-problems"> 2. Life's Little Problems </a></td>
        </tr>
      </tbody>
    </table>
  </div>
</div>
</body></html>''';

const _chapterPage = '''
<html><head>
<title>Chapter 1: Good Morning Brother | Royal Road</title>
<style>
    .cjA5ZjgxNWViMDY5NTRhMjliNzYyYmI3YzJkODFhYzBh{ display: none; speak: never; }
</style>
</head><body>
<div class="fic-header">
  <a href="/fiction/21220/mother-of-learning"><h2 class="font-white inline-block">Mother of Learning</h2></a>
  <h1 style="margin-top: 10px" class="font-white break-word">1. Good Morning Brother</h1>
</div>
<div class="chapter-inner chapter-content">
  <p class="cnNiYjExODQyMmE3YTQ5MDc5ZmU0NDUzN2IzZTBmMDQw" style="text-align: center"><strong>Chapter 001</strong></p>
  <p class="cnNhNDIzODA5ZjliZDQwOTI4MzBkNDdkMTM1NTExNWVk">Zorian's eyes abruptly shot open as a sharp pain went through his head.</p>
  <p class="cnNzBmMzI1NTcyYzJkYTJiNDVlMmM1NGUxZjE2N2E2MW">The room was cold and dark, the familiar ceiling of his family's house greeting him once again.</p>
  <p class="cjA5ZjgxNWViMDY5NTRhMjliNzYyYmI3YzJkODFhYzBh">This hidden paragraph is an anti-copy decoy and must never appear in the reader.</p>
</div>
</body></html>''';

const _searchPage = '''
<html><body>
<div class="search-container">
  <div class="fiction-list">
    <div class="row fiction-list-item">
      <figure class="col-sm-2 col-md-3 col-lg-2 text-center">
        <a href="/fiction/21220/mother-of-learning"><img data-type="cover" alt="Mother of Learning" src="/dist/img/nocover-new-min.png"></a>
      </figure>
      <div class="col-sm-10 col-md-8 col-lg-9 col-xs-12 search-content">
        <h2 class="fiction-title"><a href="/fiction/21220/mother-of-learning" class="font-red-sunglo bold">Mother of Learning</a></h2>
        <div class="margin-bottom-10">
          <span class="label label-default label-sm bg-blue-hoki">Original</span>
          <span class="label label-default label-sm bg-blue-hoki"> COMPLETED </span>
        </div>
      </div>
    </div>
    <div class="row fiction-list-item">
      <figure class="col-sm-2 col-md-3 col-lg-2 text-center">
        <a href="/fiction/14326/mother"><img data-type="cover" alt="Mother" src="/dist/img/nocover-new-min.png"></a>
      </figure>
      <div class="col-sm-10 col-md-8 col-lg-9 col-xs-12 search-content">
        <h2 class="fiction-title"><a href="/fiction/14326/mother" class="font-red-sunglo bold">Mother</a></h2>
      </div>
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
    tempDir = await Directory.systemTemp.createTemp('atlas_royalroad_plugin');
    baseDir = Directory(p.join(tempDir.path, 'plugins'));
    final source = Directory(
      p.join(Directory.current.path, 'atlas-plugins', 'royalroad'),
    );
    expect(
      source.existsSync(),
      isTrue,
      reason:
          'flutter test must run from the package root so that '
          'atlas-plugins/royalroad resolves',
    );
    await _copyDir(source, Directory(p.join(baseDir.path, 'royalroad')));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  PluginRepository repo(Transport transport) => PluginRepository(
    baseDirectory: baseDir,
    templateRegistry: TemplateRegistry.defaults,
    transportRegistry: _FakeTransportRegistry(transport),
  );

  group('atlas-plugins/royalroad/plugin.json', () {
    test('loads a valid manifest for the royalroad template', () async {
      final manifest = await repo(FakeTransport()).load('royalroad');

      expect(manifest.id, 'royalroad');
      expect(manifest.name, 'Royal Road');
      expect(manifest.sourceName, 'Royal Road');
      expect(manifest.templateId, 'royalroad');
      expect(manifest.transport, 'http');
      expect(manifest.baseUrl, 'https://www.royalroad.com');
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
        TemplateRegistry.defaults.resolve('royalroad'),
        isA<RoyalRoadTemplate>(),
      );
    });

    test('declared capabilities are implemented by the template', () async {
      final manifest = await repo(FakeTransport()).load('royalroad');
      final template = TemplateRegistry.defaults.resolve(manifest.templateId);
      final unsupported = manifest.capabilities.where(
        (c) => !template.supportedCapabilities.contains(c),
      );
      expect(unsupported, isEmpty);
    });

    test('loads filters and permissions from the plugin files', () async {
      final repository = repo(FakeTransport());
      final manifest = await repository.load('royalroad');

      final filters = await repository.loadFilters(manifest);
      expect(filters.disableDefaultStrips, isFalse);

      final permissions = await repository.loadPermissions(manifest);
      expect(permissions.maxConcurrentRequests, 2);
      expect(permissions.requestDelayMs, [400, 1200]);
      expect(permissions.allowOfflineCache, isTrue);
    });
  });

  group('royalroad PluginSource end-to-end', () {
    test('canHandle matches royalroad.com hosts', () async {
      final source = await repo(FakeTransport()).buildSource('royalroad');

      expect(
        source.canHandle(Uri.parse('https://www.royalroad.com/fiction/x')),
        isTrue,
      );
      expect(
        source.canHandle(Uri.parse('https://other.com/fiction/x')),
        isFalse,
      );
    });

    test('search drives the /fictions/search?title= endpoint', () async {
      final transport = FakeTransport()
        ..addHtml(
          'https://www.royalroad.com/fictions/search?title=mother',
          _searchPage,
        );
      final source = await repo(transport).buildSource('royalroad');

      final response = await source.search(
        const SourceSearchQuery(term: 'mother'),
      );

      expect(response.results, hasLength(2));
      expect(response.results.first.title, 'Mother of Learning');
      expect(response.results.first.importUrl, _novelUrl);
    });

    test('getMetadata reads the Book schema plus DOM-only fields', () async {
      final transport = FakeTransport()..addHtml(_novelUrl, _novelPage);
      final source = await repo(transport).buildSource('royalroad');

      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      expect(novel.category, ContentCategory.novel);
      expect(novel.source, 'Royal Road');
      expect(novel.title, 'Mother of Learning');
      expect(novel.author, 'nobody103');
      expect(novel.description, contains('teenage mage of humble birth'));
      expect(
        novel.coverUrl,
        'https://www.royalroadcdn.com/public/covers-full/21220-mother-of-learning.jpg?time=1637247458',
      );
      expect(novel.genres, ['Time Loop', 'Adventure', 'Fantasy']);
      expect(novel.status, 'COMPLETED');
      expect(novel.rating, 4.83);
      expect(novel.chapterCount, 109);
      expect(novel.lastUpdated, DateTime.parse('2018-10-28T21:45:44Z'));
    });

    test(
      'getChapters parses window.chapters in order with publish dates',
      () async {
        final transport = FakeTransport()..addHtml(_novelUrl, _novelPage);
        final source = await repo(transport).buildSource('royalroad');
        final novel = await source.getMetadata(Uri.parse(_novelUrl));

        final chapters = await source.getChapters(novel);

        expect(chapters, hasLength(2));
        expect(chapters.map((c) => c.title).toList(), [
          '1. Good Morning Brother',
          "2. Life's Little Problems",
        ]);
        expect(chapters.first.contentUrl, _chapter1Url);
        expect(
          chapters.first.publishedAt,
          DateTime.parse('2018-10-28T21:34:43Z'),
        );
      },
    );

    test(
      'getChapters falls back to table rows when window.chapters is absent',
      () async {
        final transport = FakeTransport()
          ..addHtml(_novelUrl, _novelPageNoScript);
        final source = await repo(transport).buildSource('royalroad');
        final novel = await source.getMetadata(Uri.parse(_novelUrl));

        final chapters = await source.getChapters(novel);

        expect(chapters, hasLength(2));
        expect(chapters.first.contentUrl, _chapter1Url);
      },
    );

    test(
      'getChapter strips CSS-hidden paragraphs and reads the chapter title',
      () async {
        final transport = FakeTransport()
          ..addHtml(_novelUrl, _novelPage)
          ..addHtml(_chapter1Url, _chapterPage);
        final source = await repo(transport).buildSource('royalroad');
        final novel = await source.getMetadata(Uri.parse(_novelUrl));
        final chapters = await source.getChapters(novel);

        final chapter = await source.getChapter(chapters.first);

        expect(chapter.title, '1. Good Morning Brother');
        expect(chapter.content, contains("Zorian's eyes abruptly shot open"));
        expect(chapter.content, contains('sharp pain went through his head'));
        expect(chapter.content, isNot(contains('anti-copy decoy')));
        expect(chapter.wordCount, greaterThan(0));
      },
    );
  });
}
