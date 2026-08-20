import 'dart:convert';
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

const _base = 'https://live.mangabooth.com/novelreader';
const _novelUrl = '$_base/novel/deceive-me-marry-me/';
const _chapter1Url =
    '$_base/novel/deceive-me-marry-me/chapter-1-deceive-me-marry-me/';
const _ajaxUrl = '$_base/wp-admin/admin-ajax.php';

const _novelPage =
    '''
<html><head>
<meta property="og:title" content="Deceive me, Marry me">
<meta property="og:image" content="$_base/wp-content/uploads/2019/08/deceive-me-marry-me.jpg">
<meta property="og:description" content="She was a young doctor engaged to a man she never loved.">
</head><body class="postid-591 wp-manga">
<div class="profile-manga">
  <div class="summary_image">
    <img src="$_base/wp-content/uploads/2019/08/deceive-me-marry-me.jpg" alt="Deceive me, Marry me">
  </div>
  <div class="summary_content">
    <div class="post-content_item mg_author">
      <div class="summary-heading"><h5>Author(s)</h5></div>
      <div class="summary-content manga-author">
        <a href="$_base/author/tang-jin/">Tang Jin</a>
      </div>
    </div>
    <div class="post-content_item mg_genres">
      <div class="summary-heading"><h5>Genre(s)</h5></div>
      <div class="summary-content genres-content">
        <a href="$_base/genre/romance/">Romance</a>,
        <a href="$_base/genre/drama/">Drama</a>,
        <a href="$_base/genre/mature/">Mature</a>
      </div>
    </div>
    <div class="post-content_item mg_status">
      <div class="summary-heading"><h5>Status</h5></div>
      <div class="summary-content manga-status">Completed</div>
    </div>
  </div>
  <div class="info-block manga-excerpt">
    <div class="excerpt-content">
      <p>She was a young doctor engaged to a man she never loved.</p>
    </div>
  </div>
  <div id="manga-chapters-holder" data-id="591">
    <ul class="main">
      <li class="wp-manga-chapter"><a href="$_chapter1Url">Chapter 1: Deceive me, Marry me</a></li>
      <li class="wp-manga-chapter"><a href="$_base/novel/deceive-me-marry-me/chapter-9/">Chapter 9</a></li>
    </ul>
  </div>
</div>
</body></html>''';

/// What `wp-admin/admin-ajax.php` returns for `manga_get_chapters&manga=591`:
/// JSON wrapping the `<li>` chapter list in `data.content`.
final _archiveJson = jsonEncode({
  'success': true,
  'data': {
    'content':
        '''
<li class="wp-manga-chapter"><a href="$_chapter1Url">Chapter 1: Deceive me, Marry me</a></li>
<li class="wp-manga-chapter"><a href="$_base/novel/deceive-me-marry-me/chapter-2-a-dream-like-wedding/">Chapter 2: A Dream-like Wedding</a></li>
<li class="wp-manga-chapter"><a href="$_base/novel/deceive-me-marry-me/chapter-3-the-signing/">Chapter 3: The Signing</a></li>
<li class="wp-manga-chapter"><a href="$_base/novel/deceive-me-marry-me/chapter-4-a-cold-departure/">Chapter 4: A Cold Departure</a></li>
''',
  },
});

const _chapterPage = '''
<html><head><title>Chapter 1: Deceive me, Marry me</title></head>
<body>
<div class="entry-header">
  <h1 class="entry-title">Chapter 1: Deceive me, Marry me</h1>
</div>
<div class="reading-content">
  <div class="text-left">
    <h2 class="heading font-18">Chapter 1: Deceive me, Marry me</h2>
    <p>The airport chapel smelled of white lilies and cold coffee.</p>
    <p>She kept her veil down until the very last moment, and he never once looked at her face.</p>
    <div class="wp-manga-chapter-title"><strong>Advertisement</strong></div>
  </div>
</div>
</body></html>''';

const _searchPage =
    '''
<html><body>
<div id="loop-content">
  <div class="row c-tabs-item__content">
    <div class="tab-thumb"><a href="$_novelUrl"><img src="$_base/wp-content/uploads/2019/08/deceive-me-marry-me-150x150.jpg"></a></div>
    <div class="tab-summary">
      <div class="post-title"><h3><a href="$_novelUrl">Deceive me, Marry me</a></h3></div>
    </div>
  </div>
  <div class="row c-tabs-item__content">
    <div class="tab-thumb"><a href="$_base/novel/deceive-me-tonight/"><img src="$_base/wp-content/uploads/2019/06/deceive-me-tonight-150x150.jpg"></a></div>
    <div class="tab-summary">
      <div class="post-title"><h3><a href="$_base/novel/deceive-me-tonight/">Deceive me, Tonight</a></h3></div>
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
    tempDir = await Directory.systemTemp.createTemp('atlas_novelhub_plugin');
    baseDir = Directory(p.join(tempDir.path, 'plugins'));
    final source = Directory(
      p.join(Directory.current.path, 'atlas-plugins', 'novel-hub'),
    );
    expect(
      source.existsSync(),
      isTrue,
      reason:
          'flutter test must run from the package root so that '
          'atlas-plugins/novel-hub resolves',
    );
    await _copyDir(source, Directory(p.join(baseDir.path, 'novel-hub')));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  PluginRepository repo(Transport transport) => PluginRepository(
    baseDirectory: baseDir,
    templateRegistry: TemplateRegistry.defaults,
    transportRegistry: _FakeTransportRegistry(transport),
  );

  group('atlas-plugins/novel-hub/plugin.json', () {
    test('loads a valid manifest for the generic html template', () async {
      final manifest = await repo(FakeTransport()).load('novel-hub');

      expect(manifest.id, 'novel-hub');
      expect(manifest.name, 'Novel Hub');
      expect(manifest.sourceName, 'Novel Hub');
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
      expect(TemplateRegistry.defaults.resolve('html'), isA<HtmlTemplate>());
    });

    test('declared capabilities are implemented by the template', () async {
      final manifest = await repo(FakeTransport()).load('novel-hub');
      final template = TemplateRegistry.defaults.resolve(manifest.templateId);
      final unsupported = manifest.capabilities.where(
        (c) => !template.supportedCapabilities.contains(c),
      );
      expect(unsupported, isEmpty);
    });

    test('loads filters and permissions from the plugin files', () async {
      final repository = repo(FakeTransport());
      final manifest = await repository.load('novel-hub');

      final filters = await repository.loadFilters(manifest);
      expect(
        filters.extraStripSelectors,
        contains('.reading-content .wp-manga-chapter-title'),
      );
      expect(filters.disableDefaultStrips, isFalse);

      final permissions = await repository.loadPermissions(manifest);
      expect(permissions.maxConcurrentRequests, 2);
      expect(permissions.requestDelayMs, [400, 1200]);
      expect(permissions.allowOfflineCache, isTrue);
    });
  });

  group('novel-hub PluginSource end-to-end', () {
    test('canHandle matches the live.mangabooth.com host', () async {
      final source = await repo(FakeTransport()).buildSource('novel-hub');

      expect(source.canHandle(Uri.parse('$_base/novel/x')), isTrue);
      expect(source.canHandle(Uri.parse('https://other.com/novel/x')), isFalse);
    });

    test('search drives the ?s= endpoint with post_type=wp-manga', () async {
      final transport = FakeTransport()
        ..addHtml('$_base?s=deceive&post_type=wp-manga', _searchPage);
      final source = await repo(transport).buildSource('novel-hub');

      final response = await source.search(
        const SourceSearchQuery(term: 'deceive'),
      );

      expect(response.results, hasLength(2));
      expect(response.results.first.title, 'Deceive me, Marry me');
      expect(response.results.first.importUrl, _novelUrl);
      expect(
        response.results.first.coverUrl,
        '$_base/wp-content/uploads/2019/08/deceive-me-marry-me-150x150.jpg',
      );
    });

    test('getMetadata reads the child-theme summary blocks', () async {
      final transport = FakeTransport()..addHtml(_novelUrl, _novelPage);
      final source = await repo(transport).buildSource('novel-hub');

      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      expect(novel.category, ContentCategory.novel);
      expect(novel.source, 'Novel Hub');
      expect(novel.title, 'Deceive me, Marry me');
      expect(novel.author, 'Tang Jin');
      expect(novel.genres, ['Romance', 'Drama', 'Mature']);
      expect(novel.status, 'Completed');
      expect(novel.description, contains('engaged to a man she never loved'));
      expect(
        novel.coverUrl,
        '$_base/wp-content/uploads/2019/08/deceive-me-marry-me.jpg',
      );
    });

    test('getChapters POSTs the archive and unwraps data.content', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPage)
        ..addPostHtml(_ajaxUrl, _archiveJson);
      final source = await repo(transport).buildSource('novel-hub');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      final chapters = await source.getChapters(novel);

      expect(chapters, hasLength(4));
      expect(chapters.map((c) => c.title).toList(), [
        'Chapter 1: Deceive me, Marry me',
        'Chapter 2: A Dream-like Wedding',
        'Chapter 3: The Signing',
        'Chapter 4: A Cold Departure',
      ]);
      expect(chapters.first.contentUrl, _chapter1Url);
    });

    test('getChapter fetches content through the clean pipeline', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, _novelPage)
        ..addPostHtml(_ajaxUrl, _archiveJson)
        ..addHtml(_chapter1Url, _chapterPage);
      final source = await repo(transport).buildSource('novel-hub');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));
      final chapters = await source.getChapters(novel);

      final chapter = await source.getChapter(chapters.first);

      expect(chapter.title, 'Chapter 1: Deceive me, Marry me');
      expect(chapter.content, contains('airport chapel smelled'));
      expect(chapter.content, contains('never once looked at her face'));
      expect(chapter.content, isNot(contains('Advertisement')));
      expect(chapter.content, isNot(contains('Back to novel')));
      expect(chapter.wordCount, greaterThan(0));
    });
  });
}
