import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_repository.dart';
import 'package:atlas_app/core/content_engine/registry/plugin_source.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/template_models.dart';
import 'package:atlas_app/core/content_engine/templates/template_registry.dart';

class _LimitedTemplate implements Template {
  const _LimitedTemplate();

  @override
  String get templateId => 'limited';

  @override
  Set<PluginCapability> get supportedCapabilities => const {
    PluginCapability.chapterContent,
  };

  @override
  Future<List<SearchResult>> search(PluginContext context, String query) =>
      throw UnimplementedError();

  @override
  Future<List<ChapterRef>> chapterList(
    PluginContext context,
    String novelUrl,
  ) => throw UnimplementedError();

  @override
  Future<AtlasDocument> chapterContent(
    PluginContext context,
    String chapterUrl,
  ) => throw UnimplementedError();

  @override
  Future<NovelMetadata> metadata(PluginContext context, String novelUrl) =>
      throw UnimplementedError();
}

void main() {
  late Directory tempDir;
  late Directory baseDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('atlas_plugins');
    baseDir = Directory(p.join(tempDir.path, 'plugins'));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<void> writePlugin(
    String id,
    Map<String, Object?> json, {
    Map<String, Object?>? selectors,
    Map<String, Object?>? filters,
    Map<String, Object?>? permissions,
  }) async {
    final dir = Directory(p.join(baseDir.path, id));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'plugin.json')).writeAsString(jsonEncode(json));
    if (selectors != null) {
      await File(
        p.join(dir.path, 'selectors.json'),
      ).writeAsString(jsonEncode(selectors));
    }
    if (filters != null) {
      await File(
        p.join(dir.path, 'filters.json'),
      ).writeAsString(jsonEncode(filters));
    }
    if (permissions != null) {
      await File(
        p.join(dir.path, 'permissions.json'),
      ).writeAsString(jsonEncode(permissions));
    }
  }

  Map<String, Object?> manifestJson(String id, {String templateId = 'html'}) =>
      {
        'id': id,
        'name': 'Test $id',
        'version': '1.0.0',
        'templateId': templateId,
        'baseUrl': 'https://$id.example.com',
      };

  PluginRepository repo({TemplateRegistry? registry}) => PluginRepository(
    baseDirectory: baseDir,
    templateRegistry: registry ?? TemplateRegistry.defaults,
  );

  group('PluginRepository.load', () {
    test('reads a manifest from disk', () async {
      await writePlugin('alpha', manifestJson('alpha'));
      final manifest = await repo().load('alpha');

      expect(manifest.id, 'alpha');
      expect(manifest.name, 'Test alpha');
      expect(manifest.baseUrl, 'https://alpha.example.com');
    });

    test('throws when plugin.json is missing', () async {
      await writePlugin('alpha', manifestJson('alpha'));
      await expectLater(
        repo().load('missing'),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('throws when directory id does not match manifest id', () async {
      await writePlugin('alpha', manifestJson('beta'));
      await expectLater(
        repo().load('alpha'),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('throws UnknownTemplateException for unregistered template', () async {
      await writePlugin('alpha', manifestJson('alpha', templateId: 'nope'));
      await expectLater(
        repo().load('alpha'),
        throwsA(isA<UnknownTemplateException>()),
      );
    });

    test('throws when a declared capability is not implemented', () async {
      await writePlugin('alpha', {
        ...manifestJson('alpha', templateId: 'limited'),
        'capabilities': ['search', 'chapterContent'],
      });
      final registry = TemplateRegistry(const [_LimitedTemplate()]);
      await expectLater(
        repo(registry: registry).load('alpha'),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('throws when requiresJsRendering is set', () async {
      await writePlugin('alpha', {
        ...manifestJson('alpha'),
        'requiresJsRendering': true,
      });
      await expectLater(
        repo().load('alpha'),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('loadAll returns manifests from every plugin directory', () async {
      await writePlugin('alpha', manifestJson('alpha'));
      await writePlugin('beta', manifestJson('beta'));
      final manifests = await repo().loadAll();

      expect(manifests.map((m) => m.id).toSet(), {'alpha', 'beta'});
    });

    test('loadAll is a no-op when the base directory does not exist', () async {
      expect(await repo().loadAll(), isEmpty);
    });
  });

  group('PluginRepository config loading', () {
    test('loadFilters reads extraStripSelectors', () async {
      await writePlugin(
        'alpha',
        manifestJson('alpha'),
        filters: {
          'extraStripSelectors': ['.site-ad'],
          'disableDefaultStrips': false,
        },
      );
      final manifest = await repo().load('alpha');
      final filters = await repo().loadFilters(manifest);

      expect(filters.extraStripSelectors, ['.site-ad']);
      expect(filters.disableDefaultStrips, isFalse);
    });

    test('loadPermissions reads requestDelayMs', () async {
      await writePlugin(
        'alpha',
        manifestJson('alpha'),
        permissions: {
          'maxConcurrentRequests': 1,
          'requestDelayMs': [500, 1200],
        },
      );
      final manifest = await repo().load('alpha');
      final permissions = await repo().loadPermissions(manifest);

      expect(permissions.maxConcurrentRequests, 1);
      expect(permissions.requestDelayMs, [500, 1200]);
    });

    test('loadSelectors reads chapterContent selectors', () async {
      await writePlugin(
        'alpha',
        manifestJson('alpha'),
        selectors: {
          'chapterContent': {
            'container': '#chapter-content',
            'title': '.chapter-title',
          },
        },
      );
      final manifest = await repo().load('alpha');
      final selectors = await repo().loadSelectors(manifest);

      expect(selectors.chapterContent?.container, '#chapter-content');
      expect(selectors.chapterContent?.title, '.chapter-title');
    });

    test('missing config files default to empty models', () async {
      await writePlugin('alpha', manifestJson('alpha'));
      final manifest = await repo().load('alpha');

      expect((await repo().loadFilters(manifest)).extraStripSelectors, isEmpty);
      expect((await repo().loadPermissions(manifest)).requestDelayMs, [
        800,
        2000,
      ]);
      expect((await repo().loadSelectors(manifest)).chapterContent, isNull);
    });
  });

  group('PluginRepository.buildSource', () {
    test(
      'builds a PluginSource wired to the manifest template and transport',
      () async {
        await writePlugin('alpha', {
          ...manifestJson('alpha', templateId: 'html'),
          'transport': 'cached',
        });
        final source = await repo().buildSource('alpha');

        expect(source, isA<PluginSource>());
        expect(source.manifest.id, 'alpha');
        expect(
          source.template,
          same(TemplateRegistry.defaults.resolve('html')),
        );
        expect(source.sourceName, 'Test alpha');
      },
    );
  });
}
