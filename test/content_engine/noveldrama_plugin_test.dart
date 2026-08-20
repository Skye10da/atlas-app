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

const _novelUrl =
    'https://noveldrama.org/noveldrama/rebirth-super-banking-system';
const _archiveUrl =
    'https://noveldrama.org/ajax/chapter-archive?novelId=rebirth-super-banking-system';
const _chapter1Url =
    'https://noveldrama.org/noveldrama/rebirth-super-banking-system/chapter-1-no-one-cares1';

const _novelPage = '''
<html><head>
<meta property="og:title" content="Rebirth: Super Banking System">
<meta property="og:image" content="https://images.noveldrama.org/novel/rebirth-super-banking-system.jpg">
<meta property="og:description" content="Tang Qing is reborn in 2004, equipped with a banking system.">
<meta property="og:novel:author" content="Mouse No. 6">
<meta property="og:novel:genre" content="DRAMA,ROMANCE">
<meta property="og:novel:status" content="OnGoing">
</head><body>
<div class="col-xs-12 col-info-desc">
<div class="info-holder">
  <div class="desc"><h3 class="title">Rebirth: Super Banking System</h3></div>
</div>
<div class="rate-info">
  <div id="rating" data-novel-id="rebirth-super-banking-system"></div>
</div>
<ul class="info info-meta">
  <li><h3>Author:</h3><a href="/noveldrama-author/Mouse No. 6">Mouse No. 6</a></li>
  <li><h3>Genre:</h3><a href="/noveldrama-genres/drama">Drama</a>, <a href="/noveldrama-genres/romance">Romance</a></li>
  <li><h3>Status:</h3><a href="/sort/noveldrama-ongoing" class="text-primary">Ongoing</a></li>
</ul>
</div>
<div class="desc-text"><p>Tang Qing is reborn in 2004, equipped with a banking system. Thus, he shines.</p></div>
</body></html>''';

const _archivePage = '''
<html><body>
<div class="chapter-archive-grid" data-chapter-archive-grid></div>
<template data-chapter-item-template>
  <li data-chapter-item>
    <span class="glyphicon glyphicon-certificate"></span>&nbsp;
    <a href="/noveldrama/rebirth-super-banking-system/chapter-1-no-one-cares1" title="Chapter 1 No One Cares_1">
      <span class="nchr-text chapter-title">Chapter 1 No One Cares_1</span>
    </a>
  </li>
  <li data-chapter-item>
    <a href="/noveldrama/rebirth-super-banking-system/chapter-2-1-no-one-cares-2" title="Chapter 2 - 1: No One Cares _2">
      <span class="nchr-text chapter-title">Chapter 2 - 1: No One Cares _2</span>
    </a>
  </li>
  <li data-chapter-item>
    <a href="/noveldrama/rebirth-super-banking-system/chapter-3-1-no-one-cares-3" title="Chapter 3 - 1: No One Cares _3">
      <span class="nchr-text chapter-title">Chapter 3 - 1: No One Cares _3</span>
    </a>
  </li>
</template>
</body></html>''';

const _chapterPage = '''
<html><body>
<div id="chapter" class="chapter container">
  <div class="row"><div class="col-xs-12">
  <a class="novel-title" href="/noveldrama/rebirth-super-banking-system" title="Rebirth: Super Banking System">Rebirth: Super Banking System</a>
  <h2><a class="chr-title" href="/noveldrama/rebirth-super-banking-system/chapter-1-no-one-cares1" title="Chapter 1 No One Cares_1"><span class="chr-text">Chapter 1 No One Cares_1</span></a></h2>
  <div class="chr-nav" id="chr-nav-top"><a class="btn js-chapter-nav" href="javascript:void(0)">Prev Chapter</a></div>
  <div id="chr-content" class="chr-c">
    <p>June 1, 2017.</p>
    <p>Zhongzhou City.</p>
    <p>Tang Qing, his back laden with a black backpack, weaves through parked vehicles.</p>
  </div>
  </div></div>
</div>
</body></html>''';

const _searchPage = '''
<html><body>
<div class="container" id="list-page">
  <div class="list list-novel">
    <div class="row">
      <div class="col-xs-7"><div><h3 class="novel-title"><a href="/noveldrama/rebirth-super-banking-system" title="Rebirth: Super Banking System">Rebirth: Super Banking System</a></h3><span class="author">Mouse No. 6</span></div></div>
    </div>
    <div class="row">
      <div class="col-xs-7"><div><h3 class="novel-title"><a href="/noveldrama/after-her-rebirth" title="After her rebirth">After her rebirth</a></h3></div></div>
    </div>
  </div>
</div>
</body></html>''';

const _novelPageNoOgTags = '''
<html><head>
<title>Rebirth: Super Banking System Novel - Read Rebirth: Super Banking System Online For Free - Novel Drama</title>
<meta property="og:novel:novel_name" content="Rebirth: Super Banking System">
<meta property="og:novel:author" content="Mouse No. 6">
</head><body>
<div class="col-xs-12 col-info-desc">
<div class="info-holder">
  <div class="desc"><h3 class="title">Rebirth: Super Banking System</h3></div>
  <div class="book"><img class="lazy" data-src="https://images.noveldrama.org/novel/rebirth-super-banking-system.jpg" alt="Rebirth: Super Banking System"></div>
</div>
<ul class="info info-meta">
  <li><h3>Author:</h3><a href="/noveldrama-author/Mouse No. 6">Mouse No. 6</a></li>
  <li><h3>Genre:</h3><a href="/noveldrama-genres/drama">Drama</a>, <a href="/noveldrama-genres/romance">Romance</a></li>
  <li><h3>Status:</h3><a href="/sort/noveldrama-ongoing" class="text-primary">Ongoing</a></li>
</ul>
</div>
<div class="desc-text"><p>Tang Qing is reborn in 2004, equipped with a banking system.</p></div>
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
    tempDir = await Directory.systemTemp.createTemp('atlas_noveldrama_plugin');
    baseDir = Directory(p.join(tempDir.path, 'plugins'));
    final source = Directory(
      p.join(Directory.current.path, 'atlas-plugins', 'noveldrama'),
    );
    expect(
      source.existsSync(),
      isTrue,
      reason:
          'flutter test must run from the package root so that '
          'atlas-plugins/noveldrama resolves',
    );
    await _copyDir(source, Directory(p.join(baseDir.path, 'noveldrama')));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  PluginRepository repo(Transport transport) => PluginRepository(
    baseDirectory: baseDir,
    templateRegistry: TemplateRegistry.defaults,
    transportRegistry: _FakeTransportRegistry(transport),
  );

  group('atlas-plugins/noveldrama/plugin.json', () {
    test('loads a valid manifest for the generic html template', () async {
      final manifest = await repo(FakeTransport()).load('noveldrama');

      expect(manifest.id, 'noveldrama');
      expect(manifest.name, 'NovelDrama');
      expect(manifest.sourceName, 'NovelDrama');
      expect(manifest.templateId, 'html');
      expect(manifest.transport, 'http');
      expect(manifest.baseUrl, 'https://noveldrama.org');
      expect(manifest.language, 'en');
      expect(manifest.customUserAgent, contains('Chrome/124'));
      expect(manifest.requiresJsRendering, isFalse);
      expect(manifest.capabilities.toSet(), {
        PluginCapability.search,
        PluginCapability.chapterList,
        PluginCapability.chapterContent,
        PluginCapability.cover,
      });
      expect(TemplateRegistry.defaults.resolve('html'), isA<HtmlTemplate>());
    });

    test('declared capabilities are implemented by the template', () async {
      final manifest = await repo(FakeTransport()).load('noveldrama');
      final template = TemplateRegistry.defaults.resolve(manifest.templateId);
      final unsupported = manifest.capabilities.where(
        (c) => !template.supportedCapabilities.contains(c),
      );
      expect(unsupported, isEmpty);
    });

    test('loads filters and permissions from the plugin files', () async {
      final repository = repo(FakeTransport());
      final manifest = await repository.load('noveldrama');

      final filters = await repository.loadFilters(manifest);
      expect(filters.extraStripSelectors, contains('.js-ad-slot'));
      expect(filters.disableDefaultStrips, isFalse);

      final permissions = await repository.loadPermissions(manifest);
      expect(permissions.maxConcurrentRequests, 2);
      expect(permissions.requestDelayMs, [400, 1200]);
      expect(permissions.allowOfflineCache, isTrue);
    });
  });

  group('noveldrama PluginSource end-to-end', () {
    test('canHandle matches noveldrama.org hosts', () async {
      final source = await repo(FakeTransport()).buildSource('noveldrama');

      expect(
        source.canHandle(Uri.parse('https://noveldrama.org/noveldrama/x')),
        isTrue,
      );
      expect(source.canHandle(Uri.parse('https://other.com/novel/x')), isFalse);
    });

    test('search drives the /search?keyword= endpoint', () async {
      final transport = FakeTransport()
        ..addHtml('https://noveldrama.org/search?keyword=rebirth', _searchPage);
      final source = await repo(transport).buildSource('noveldrama');

      final response = await source.search(
        const SourceSearchQuery(term: 'rebirth'),
      );

      expect(response.results, hasLength(2));
      expect(response.results.first.title, 'Rebirth: Super Banking System');
      expect(response.results.first.importUrl, _novelUrl);
    });

    test(
      'getMetadata bridges the plugin to a novel-category NovelModel',
      () async {
        final transport = FakeTransport()..addHtml(_novelUrl, _novelPage);
        final source = await repo(transport).buildSource('noveldrama');

        final novel = await source.getMetadata(Uri.parse(_novelUrl));

        expect(novel.category, ContentCategory.novel);
        expect(novel.source, 'NovelDrama');
        expect(novel.title, 'Rebirth: Super Banking System');
        expect(novel.author, 'Mouse No. 6');
        expect(novel.description, contains('Tang Qing is reborn in 2004'));
        expect(
          novel.coverUrl,
          'https://images.noveldrama.org/novel/rebirth-super-banking-system.jpg',
        );
        expect(novel.genres, ['Drama', 'Romance']);
        expect(novel.status, 'Ongoing');
      },
    );

    test('getChapters fetches the full archive from ajaxPath and returns '
        'ascending order', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPage)
        ..addHtml(_archiveUrl, _archivePage);
      final source = await repo(transport).buildSource('noveldrama');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      final chapters = await source.getChapters(novel);

      expect(chapters, hasLength(3));
      expect(chapters.map((c) => c.title).toList(), [
        'Chapter 1 No One Cares_1',
        'Chapter 2 - 1: No One Cares _2',
        'Chapter 3 - 1: No One Cares _3',
      ]);
      expect(chapters.first.contentUrl, _chapter1Url);
    });

    test('getChapters falls back to the in-page list when the archive '
        'endpoint is unreachable', () async {
      final transport = FakeTransport()..addHtml(_novelUrl, _novelPage);
      final source = await repo(transport).buildSource('noveldrama');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      final chapters = await source.getChapters(novel);

      expect(chapters, isEmpty);
    });

    test('getChapter fetches content through the clean pipeline', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPage)
        ..addHtml(_archiveUrl, _archivePage)
        ..addHtml(_chapter1Url, _chapterPage);
      final source = await repo(transport).buildSource('noveldrama');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));
      final chapters = await source.getChapters(novel);

      final chapter = await source.getChapter(chapters.first);

      expect(chapter.title, 'Chapter 1 No One Cares_1');
      expect(chapter.content, contains('Zhongzhou City'));
      expect(chapter.content, contains('Tang Qing'));
      expect(chapter.content, isNot(contains('Prev Chapter')));
      expect(chapter.wordCount, greaterThan(0));
    });

    test(
      'metadata selectors supply title and cover when og: tags are polluted',
      () async {
        final transport = FakeTransport()
          ..addHtml(_novelUrl, _novelPageNoOgTags);
        final source = await repo(transport).buildSource('noveldrama');

        final novel = await source.getMetadata(Uri.parse(_novelUrl));

        expect(
          novel.title,
          'Rebirth: Super Banking System',
          reason: '.desc h3.title must be used instead of polluted og:title',
        );
        expect(novel.author, 'Mouse No. 6');
        expect(novel.description, contains('Tang Qing is reborn in 2004'));
        expect(
          novel.coverUrl,
          'https://images.noveldrama.org/novel/rebirth-super-banking-system.jpg',
          reason: '.book img@data-src must resolve the lazy-loaded cover',
        );
        expect(novel.genres, ['Drama', 'Romance']);
        expect(novel.source, 'NovelDrama');
      },
    );
  });
}
