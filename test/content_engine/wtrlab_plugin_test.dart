import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_permissions.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_repository.dart';
import 'package:atlas_app/core/content_engine/templates/template_registry.dart';
import 'package:atlas_app/core/content_engine/templates/wtrlab_template.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/content_engine/transport/transport_registry.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_session_repository.dart';
import 'package:atlas_app/wtr/domain/services/wtr_authentication_manager.dart';
import 'package:atlas_app/wtr/domain/services/wtr_chapter_provider.dart';
import 'package:atlas_app/wtr/domain/services/wtr_session_auxiliary.dart';

import 'test_fixtures.dart';

const _base = 'https://wtr-lab.com';
const _novelUrl = '$_base/en/novel/29058/'
    'charm-is-full-i-have-become-a-male-god-since-high-school';
const _chapterUrl = '$_novelUrl/chapter-639';
const _searchUrl = '$_base/api/search';
const _chaptersUrl = '$_base/api/chapters/29058';
const _readerUrl = '$_base/api/reader/get';

const _searchResponse = {
  'success': true,
  'data': [
    {
      'raw_id': 29058,
      'slug': 'charm-is-full-i-have-become-a-male-god-since-high-school',
      'status': 0,
      'chapter_count': 960,
      'data': {
        'title': 'Charm is Full: I Have Become a Male God Since High School',
        'author': 'Dong Bei Da Ju Mao',
        'description': 'Reborn in high school, Lu Yan activates his charm system.',
        'image': 'https://img.wtr-lab.com/cdn/series/thumb.jpg',
      },
    }
  ],
};

const _chaptersResponse = {
  'chapters': [
    {
      'serie_id': 28086,
      'id': 21337972,
      'order': 639,
      'title': 'Chapter 638: He wrote both of them!?',
      'name': '第638章 两个都是他写的! ?',
      'updated_at': '2026-03-23 19:00:12.04+00',
    },
  ],
};

class _FakeTransportRegistry extends TransportRegistry {
  const _FakeTransportRegistry(this.transport);

  final Transport transport;

  @override
  Transport create(PluginManifest plugin, {PluginPermissions? permissions}) =>
      transport;
}

/// A WTR session auxiliary that always reports session cookies present, so the
/// auth manager can be driven to the authenticated state in tests.
class _AuthenticatedWtrAuxiliary implements WtrSessionAuxiliary {
  @override
  String get origin => 'https://wtr-lab.com';

  @override
  Future<void> captureCookies() async {}

  @override
  Future<bool> hasSessionCookies() async => true;

  @override
  Future<void> clearCookies() async {}
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
    tempDir = await Directory.systemTemp.createTemp('atlas_wtrlab_plugin');
    baseDir = Directory(p.join(tempDir.path, 'plugins'));
    final source =
        Directory(p.join(Directory.current.path, 'atlas-plugins', 'wtrlab'));
    expect(source.existsSync(), isTrue,
        reason: 'flutter test must run from the package root so that '
            'atlas-plugins/wtrlab resolves');
    await _copyDir(source, Directory(p.join(baseDir.path, 'wtrlab')));

    // The default translation service is now AI (English), which requires an
    // authenticated WTR-Lab session — provide one so the getChapter path
    // passes through the sign-in gate.
    final auth = WtrAuthenticationManager(
      sessionRepository: InMemoryWtrSessionRepository(),
      auxiliary: _AuthenticatedWtrAuxiliary(),
    );
    await auth.completeLogin();
    WtrChapterProvider.overrideForTest(WtrChapterProvider(authManager: auth));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
    WtrChapterProvider.reset();
  });

  PluginRepository repo(Transport transport) => PluginRepository(
        baseDirectory: baseDir,
        templateRegistry: TemplateRegistry.defaults,
        transportRegistry: _FakeTransportRegistry(transport),
      );

  group('atlas-plugins/wtrlab/plugin.json', () {
    test('loads a valid manifest for the wtrlab template', () async {
      final manifest = await repo(FakeTransport()).load('wtrlab');

      expect(manifest.id, 'wtrlab');
      expect(manifest.name, 'WTR-LAB');
      expect(manifest.sourceName, 'WTR-LAB');
      expect(manifest.templateId, 'wtrlab');
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
        TemplateRegistry.defaults.resolve('wtrlab'),
        isA<WtrLabTemplate>(),
      );
    });

    test('declared capabilities are implemented by the template', () async {
      final manifest = await repo(FakeTransport()).load('wtrlab');
      final template = TemplateRegistry.defaults.resolve(manifest.templateId);
      final unsupported = manifest.capabilities
          .where((c) => !template.supportedCapabilities.contains(c));
      expect(unsupported, isEmpty);
    });

    test('loads filters and permissions from the plugin files', () async {
      final repository = repo(FakeTransport());
      final manifest = await repository.load('wtrlab');

      final filters = await repository.loadFilters(manifest);
      expect(filters.disableDefaultStrips, isFalse);

      final permissions = await repository.loadPermissions(manifest);
      expect(permissions.maxConcurrentRequests, 1);
      expect(permissions.requestDelayMs, [1000, 2000]);
      expect(permissions.allowOfflineCache, isTrue);
    });
  });

  group('wtrlab PluginSource end-to-end', () {
    test('canHandle matches the wtr-lab.com host', () async {
      final source = await repo(FakeTransport()).buildSource('wtrlab');

      expect(source.canHandle(Uri.parse('$_base/en/novel/29058/slug')), isTrue);
      expect(source.canHandle(Uri.parse('https://other.com/novel/x')), isFalse);
    });

    test('search POSTs /api/search and maps results to import URLs', () async {
      final transport = FakeTransport()..addPostJson(_searchUrl, _searchResponse);
      final source = await repo(transport).buildSource('wtrlab');

      final response =
          await source.search(const SourceSearchQuery(term: 'male god'));

      expect(response.results, hasLength(1));
      expect(response.results.first.title,
          'Charm is Full: I Have Become a Male God Since High School');
      expect(response.results.first.importUrl, _novelUrl);
    });

    test('getMetadata reads the __NEXT_DATA__ metadata', () async {
      final novelHtml = await File(
        p.join(baseDir.path, 'wtrlab', 'tests', 'fixtures', 'novel.html'),
      ).readAsString();
      final transport = FakeTransport()..addHtml(_novelUrl, novelHtml);
      final source = await repo(transport).buildSource('wtrlab');

      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      expect(novel.category, ContentCategory.novel);
      expect(novel.source, 'WTR-LAB');
      expect(novel.title, 'Charm is Full: I Have Become a Male God Since High School');
      expect(novel.author, 'Dong Bei Da Ju Mao');
      expect(novel.status, 'Ongoing');
      expect(novel.description, contains('Reborn in high school, Lu Yan'));
      expect(novel.coverUrl,
          'https://img.wtr-lab.com/cdn/series/0viGWduh906iO1MGqXzOa6A9rVjTOkPMeCm9_Q41iuo.jpg');
      expect(novel.chapterCount, 960);
    });

    test('getChapters maps the chapters API to content URLs', () async {
      final novelHtml = await File(
        p.join(baseDir.path, 'wtrlab', 'tests', 'fixtures', 'novel.html'),
      ).readAsString();
      final transport = FakeTransport()
        ..addHtml(_novelUrl, novelHtml)
        ..addJson(_chaptersUrl, _chaptersResponse);
      final source = await repo(transport).buildSource('wtrlab');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));

      final chapters = await source.getChapters(novel);

      expect(chapters, hasLength(1));
      expect(chapters.first.title, 'Chapter 638: He wrote both of them!?');
      expect(chapters.first.contentUrl, _chapterUrl);
    });

    test('getChapter POSTs reader/get and renders the decrypted body',
        () async {
      final novelHtml = await File(
        p.join(baseDir.path, 'wtrlab', 'tests', 'fixtures', 'novel.html'),
      ).readAsString();
      final fixture = jsonDecode(await File(
        p.join(baseDir.path, 'wtrlab', 'tests', 'fixtures', 'chapter.json'),
      ).readAsString());
      final transport = FakeTransport()
        ..addHtml(_novelUrl, novelHtml)
        ..addJson(_chaptersUrl, _chaptersResponse)
        ..addPostJson(_readerUrl, fixture);
      final source = await repo(transport).buildSource('wtrlab');
      final novel = await source.getMetadata(Uri.parse(_novelUrl));
      final chapters = await source.getChapters(novel);

      final chapter = await source.getChapter(chapters.first);

      expect(chapter.title, 'Chapter 638: He wrote both of them!?');
      expect(chapter.content, contains('鬼吹灯之龙中岳'));
      expect(chapter.wordCount, greaterThan(0));
    });
  });
}