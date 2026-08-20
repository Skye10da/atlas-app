import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_permissions.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_repository.dart';
import 'package:atlas_app/core/content_engine/templates/mvlempyr_template.dart';
import 'package:atlas_app/core/content_engine/templates/template_registry.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/content_engine/transport/transport_registry.dart';

import 'test_fixtures.dart';

const _novelPage = '''
<html><head><title>Some Title</title>
<meta name="description" content="Meta desc">
</head><body>
<h1 class="novel-title">The Novel</h1>
<div id="novel-code">12345</div>
<div class="fieldtext">Author:</div><div>Jane Doe</div>
<div class="synopsis w-richtext"><p>A <strong>great</strong> story.</p></div>
<div class="novelstatustextlarge">Ongoing</div>
<img src="https://example.com/cover.jpg" class="novel-image">
</body></html>''';

const _chapterPage = '''
<html><body>
<h2 id="chapter-name"><span>Chapter One</span></h2>
<span class="oxy-stock-content-styles"><p>Body text.</p></span>
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
    tempDir = await Directory.systemTemp.createTemp('atlas_mvlempyr_plugin');
    baseDir = Directory(p.join(tempDir.path, 'plugins'));
    final source = Directory(
      p.join(Directory.current.path, 'atlas-plugins', 'mvlempyr'),
    );
    expect(
      source.existsSync(),
      isTrue,
      reason:
          'flutter test must run from the package root so that '
          'atlas-plugins/mvlempyr resolves',
    );
    await _copyDir(source, Directory(p.join(baseDir.path, 'mvlempyr')));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  PluginRepository repo(Transport transport) => PluginRepository(
    baseDirectory: baseDir,
    templateRegistry: TemplateRegistry.defaults,
    transportRegistry: _FakeTransportRegistry(transport),
  );

  group('atlas-plugins/mvlempyr/plugin.json', () {
    test('loads a valid manifest for the mvlempyr template', () async {
      final manifest = await repo(FakeTransport()).load('mvlempyr');

      expect(manifest.id, 'mvlempyr');
      expect(manifest.name, 'MVLEMPYR');
      expect(manifest.sourceName, 'MVLEMPYR');
      expect(manifest.templateId, 'mvlempyr');
      expect(manifest.transport, 'http');
      expect(manifest.baseUrl, 'https://www.mvlempyr.io');
      expect(manifest.language, 'en');
      expect(manifest.customUserAgent, contains('Chrome/124'));
      expect(manifest.requiresJsRendering, isFalse);
      expect(manifest.capabilities.toSet(), {
        PluginCapability.chapterList,
        PluginCapability.chapterContent,
        PluginCapability.cover,
      });
      expect(
        TemplateRegistry.defaults.resolve('mvlempyr'),
        isA<MvlempyrTemplate>(),
      );
    });

    test('declared capabilities are implemented by the template', () async {
      final manifest = await repo(FakeTransport()).load('mvlempyr');
      final template = TemplateRegistry.defaults.resolve(manifest.templateId);
      final unsupported = manifest.capabilities.where(
        (c) => !template.supportedCapabilities.contains(c),
      );
      expect(unsupported, isEmpty);
    });

    test('loads filters and permissions from the plugin files', () async {
      final repository = repo(FakeTransport());
      final manifest = await repository.load('mvlempyr');

      final filters = await repository.loadFilters(manifest);
      expect(filters.extraStripSelectors, isEmpty);
      expect(filters.disableDefaultStrips, isFalse);

      final permissions = await repository.loadPermissions(manifest);
      expect(permissions.maxConcurrentRequests, 1);
      expect(permissions.requestDelayMs, [800, 2000]);
      expect(permissions.allowOfflineCache, isFalse);
    });
  });

  group('mvlempyr PluginSource end-to-end', () {
    test(
      'canHandle matches mvlempyr.io hosts ignoring the www. prefix',
      () async {
        final source = await repo(FakeTransport()).buildSource('mvlempyr');

        expect(
          source.canHandle(Uri.parse('https://www.mvlempyr.io/novel/x')),
          isTrue,
        );
        expect(
          source.canHandle(Uri.parse('https://mvlempyr.io/novel/x')),
          isTrue,
        );
        expect(
          source.canHandle(Uri.parse('https://other.com/novel/x')),
          isFalse,
        );
      },
    );

    test(
      'getMetadata bridges the plugin to a novel-category NovelModel',
      () async {
        final transport = FakeTransport()
          ..addHtml('https://www.mvlempyr.io/novel/some-slug', _novelPage)
          ..addJson(
            'https://chap.heliosarchive.online/wp-json/wp/v2/mvl-novels',
            <Object?>[
              {
                'average-review': 4.5,
                'total-chapters': 120,
                'createdOn': '2024-01-15T00:00:00',
                'genre': ['Fantasy', 'Adventure'],
              },
            ],
          );
        final source = await repo(transport).buildSource('mvlempyr');

        final novel = await source.getMetadata(
          Uri.parse('https://www.mvlempyr.io/novel/some-slug'),
        );

        expect(novel.category, ContentCategory.novel);
        expect(novel.source, 'MVLEMPYR');
        expect(novel.title, 'The Novel');
        expect(novel.sourceId, '12345');
        expect(novel.rating, 4.5);
        expect(novel.chapterCount, 120);
        expect(novel.genres, ['Fantasy', 'Adventure']);
      },
    );

    test(
      'getChapters and getChapter fetch content through the pipeline',
      () async {
        final transport = FakeTransport()
          ..addHtml('https://www.mvlempyr.io/novel/some-slug', _novelPage)
          ..addJson(
            'https://chap.heliosarchive.online/wp-json/wp/v2/posts',
            <Object?>[
              {
                'acf': {
                  'chapter_number': 1,
                  'novel_code': '12345',
                  'ch_name': 'Chapter One',
                },
                'date': '2024-01-01T00:00:00',
              },
            ],
          )
          ..addHtml('https://www.mvlempyr.io/chapter/12345-1', _chapterPage);
        final source = await repo(transport).buildSource('mvlempyr');
        final novel = await source.getMetadata(
          Uri.parse('https://www.mvlempyr.io/novel/some-slug'),
        );

        final chapters = await source.getChapters(novel);
        expect(chapters, hasLength(1));
        expect(chapters.single.title, 'Chapter One');
        expect(
          chapters.single.contentUrl,
          'https://www.mvlempyr.io/chapter/12345-1',
        );

        final chapter = await source.getChapter(chapters.single);
        expect(chapter.content, contains('Body text.'));
        expect(chapter.wordCount, greaterThan(0));
      },
    );
  });
}
