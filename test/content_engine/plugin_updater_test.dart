import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_engine/models/content_hasher.dart';
import 'package:atlas_app/core/content_engine/plugins/github_plugin_source.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_catalog.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_distribution_config.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_repository.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_updater.dart';
import 'package:atlas_app/core/content_engine/plugins/verification.dart';
import 'package:atlas_app/core/content_engine/templates/template_registry.dart';

import 'test_fixtures.dart';

const _config = GithubPluginDistributionConfig();
String _pluginJson(String id, String version, {List<String>? capabilities}) {
  final caps = capabilities ?? ['chapterList', 'chapterContent'];
  return '''
{
  "id": "$id",
  "name": "$id",
  "sourceName": "$id",
  "version": "$version",
  "templateId": "html",
  "baseUrl": "https://example.com",
  "transport": "http",
  "capabilities": ${caps.map((c) => '"$c"').toList()}
}
''';
}

/// Builds a catalog + plugin file fixtures on a [FakeTransport] for a single
/// plugin, returning the checksummed [PluginCatalogEntry].
PluginCatalogEntry _servePlugin(
  FakeTransport transport,
  String id,
  String version, {
  String? pluginJsonOverride,
  String? filtersOverride,
  String? permissionsOverride,
}) {
  const hasher = ContentHasher();
  final files = <String, String>{
    'plugin.json': pluginJsonOverride ?? _pluginJson(id, version),
  };
  if (filtersOverride != null) files['filters.json'] = filtersOverride;
  if (permissionsOverride != null) {
    files['permissions.json'] = permissionsOverride;
  }
  final checksums = <String, String>{};
  for (final file in files.entries) {
    final url = _config.fileUrl(id, file.key);
    transport.addHtml(url.toString(), file.value);
    checksums[file.key] = hasher.sha256Of(file.value);
  }
  final entry = PluginCatalogEntry(
    id: id,
    version: PluginVersion.tryParse(version)!,
    checksums: checksums,
  );
  transport.addJson(_config.catalogUrl().toString(), {
    'plugins': [entry.toJson()],
  });
  return entry;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('updater_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  PluginUpdater buildUpdater(FakeTransport transport) => PluginUpdater(
    source: GithubPluginSource(config: _config, transport: transport),
    targetDirectory: tempDir,
    templateRegistry: TemplateRegistry.defaults,
  );

  test(
    'installs a plugin and makes it discoverable via PluginRepository',
    () async {
      final transport = FakeTransport();
      _servePlugin(transport, 'mvlempyr', '1.0.0');

      final results = await buildUpdater(transport).sync();
      final result = results.single;
      expect(result.pluginId, 'mvlempyr');
      expect(result.status, PluginUpdateStatus.installed);
      expect(result.fromVersion, isNull);

      final repository = PluginRepository(
        baseDirectory: tempDir,
        templateRegistry: TemplateRegistry.defaults,
      );
      final manifest = await repository.load('mvlempyr');
      expect(
        manifest.version,
        const PluginVersion(major: 1, minor: 0, patch: 0),
      );
      expect(await repository.loadAll(), hasLength(1));
    },
  );

  test('upgrades when the catalog version is newer', () async {
    final transport = FakeTransport();
    _servePlugin(transport, 'mvlempyr', '1.0.0');
    await buildUpdater(transport).sync();

    // Second catalog round serves 1.1.0.
    _servePlugin(transport, 'mvlempyr', '1.1.0');
    final results = await buildUpdater(transport).sync();
    final result = results.single;
    expect(result.status, PluginUpdateStatus.upgraded);
    expect(
      result.fromVersion,
      const PluginVersion(major: 1, minor: 0, patch: 0),
    );

    final manifest = await PluginRepository(
      baseDirectory: tempDir,
      templateRegistry: TemplateRegistry.defaults,
    ).load('mvlempyr');
    expect(manifest.version, const PluginVersion(major: 1, minor: 1, patch: 0));
  });

  test('is upToDate when versions match and newerInstalled when installed '
      'exceeds the catalog', () async {
    final transport = FakeTransport();
    _servePlugin(transport, 'mvlempyr', '1.0.0');
    final updater = buildUpdater(transport);
    await updater.sync();

    expect((await updater.sync()).single.status, PluginUpdateStatus.upToDate);

    _servePlugin(transport, 'mvlempyr', '0.9.0');
    expect(
      (await updater.sync()).single.status,
      PluginUpdateStatus.newerInstalled,
    );
  });

  test(
    'a checksum mismatch fails the plugin and leaves nothing installed',
    () async {
      final transport = FakeTransport();
      _servePlugin(transport, 'mvlempyr', '1.0.0');
      // Corrupt the on-the-wire payload after checksums were computed.
      final url = _config.fileUrl('mvlempyr', 'plugin.json').toString();
      transport.htmlByUrl[url] = 'tampered';
      transport.htmlByPath[Uri.parse(url).path] = 'tampered';

      final result = (await buildUpdater(transport).sync()).single;
      expect(result.status, PluginUpdateStatus.failed);
      expect(result.error, contains('Checksum mismatch'));

      final pluginDir = Directory(p.join(tempDir.path, 'mvlempyr'));
      expect(await pluginDir.exists(), isFalse);
    },
  );

  test(
    'a catalog that cannot be fetched throws PluginDistributionException',
    () async {
      final transport = FakeTransport(); // no fixtures
      expect(
        () => buildUpdater(transport).sync(),
        throwsA(isA<PluginDistributionException>()),
      );
    },
  );

  test(
    'a plugin whose manifest version differs from the catalog entry fails',
    () async {
      final transport = FakeTransport();
      // Catalog entry says 1.0.0, but the served (and correctly checksummed)
      // manifest claims 2.0.0. The checksum verifies fine; the version
      // mismatch is caught on reload.
      _servePlugin(
        transport,
        'mvlempyr',
        '1.0.0',
        pluginJsonOverride: _pluginJson('mvlempyr', '2.0.0'),
      );

      final result = (await buildUpdater(transport).sync()).single;
      expect(result.status, PluginUpdateStatus.failed);
      expect(result.error, contains('does not match the catalog'));
      expect(
        await Directory(p.join(tempDir.path, 'mvlempyr')).exists(),
        isFalse,
      );
    },
  );

  test('extra support files are downloaded and written', () async {
    final transport = FakeTransport();
    _servePlugin(
      transport,
      'mvlempyr',
      '1.0.0',
      filtersOverride: '{"foo": 1}',
      permissionsOverride: '{"maxConcurrentRequests": 1}',
    );

    final result = (await buildUpdater(transport).sync()).single;
    expect(result.status, PluginUpdateStatus.installed);

    final filtersFile = File(p.join(tempDir.path, 'mvlempyr', 'filters.json'));
    expect(await filtersFile.readAsString(), '{"foo": 1}');
  });
}
