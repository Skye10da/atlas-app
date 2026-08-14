import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_engine/models/content_hasher.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_filters.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_permissions.dart';
import 'package:atlas_app/core/content_engine/selectors/selector_set.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/template_registry.dart';
import 'package:atlas_app/core/content_engine/transport/offline_transport.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

class PluginValidationIssue {
  const PluginValidationIssue({
    required this.pluginId,
    required this.category,
    required this.message,
  });

  final String pluginId;

  /// "schema" | "template" | "checksum" | "fixture"
  final String category;
  final String message;

  @override
  String toString() => '[$category] $pluginId: $message';
}

/// Validates a plugin package the way CI would: schema + semver, template
/// wiring, checksums against the catalog, and fixture smoke tests that run
/// the template over recorded HTML with no live network.
class PluginValidator {
  PluginValidator({
    TemplateRegistry? registry,
    ContentHasher hasher = const ContentHasher(),
  })  : _registry = registry ?? TemplateRegistry.defaults,
        _hasher = hasher;

  final TemplateRegistry _registry;
  final ContentHasher _hasher;

  Future<List<PluginValidationIssue>> validateAll(Directory pluginsRoot) async {
    if (!await pluginsRoot.exists()) {
      return [
        PluginValidationIssue(
          pluginId: '<root>',
          category: 'schema',
          message: 'plugins directory not found: ${pluginsRoot.path}',
        ),
      ];
    }
    final issues = <PluginValidationIssue>[];
    await for (final entry in pluginsRoot.list()) {
      if (entry is! Directory) continue;
      final pluginDir = entry;
      final id = p.basename(pluginDir.path);
      final manifestFile = File(p.join(pluginDir.path, 'plugin.json'));
      if (!await manifestFile.exists()) {
        issues.add(PluginValidationIssue(
          pluginId: id,
          category: 'schema',
          message: 'missing plugin.json',
        ));
        continue;
      }
      issues.addAll(await validatePlugin(pluginDir));
    }
    return issues;
  }

  Future<List<PluginValidationIssue>> validatePlugin(Directory pluginDir) async {
    final id = p.basename(pluginDir.path);
    final issues = <PluginValidationIssue>[];

    final PluginManifest manifest;
    try {
      manifest = PluginManifest.fromJson(await _readJsonMap(pluginDir, 'plugin.json'));
    } catch (e) {
      return [
        PluginValidationIssue(
          pluginId: id,
          category: 'schema',
          message: 'plugin.json does not parse: $e',
        ),
      ];
    }
    issues.addAll(_schemaIssues(id, manifest));

    final template = _registry.resolve(manifest.templateId);
    issues.addAll(_templateIssues(id, manifest, template));

    issues.addAll(await _configIssues(pluginDir, id, manifest));
    issues.addAll(await _checksumIssues(pluginDir, id));
    issues.addAll(await _fixtureIssues(pluginDir, id, manifest, template));
    return issues;
  }

  List<PluginValidationIssue> _schemaIssues(String id, PluginManifest manifest) {
    final issues = <PluginValidationIssue>[];
    if (manifest.id != id) {
      issues.add(PluginValidationIssue(
        pluginId: id,
        category: 'schema',
        message: 'plugin.json "id" (${manifest.id}) does not match directory '
            'name "$id"',
      ));
    }
    return issues;
  }

  List<PluginValidationIssue> _templateIssues(
    String id,
    PluginManifest manifest,
    Template template,
  ) {
    final issues = <PluginValidationIssue>[];
    if (manifest.requiresJsRendering) {
      issues.add(PluginValidationIssue(
        pluginId: id,
        category: 'template',
        message: 'requiresJsRendering is not supported',
      ));
      return issues;
    }
    final unsupported = manifest.capabilities
        .where((c) => !template.supportedCapabilities.contains(c))
        .toList();
    if (unsupported.isNotEmpty) {
      issues.add(PluginValidationIssue(
        pluginId: id,
        category: 'template',
        message: 'capabilities not implemented by template '
            '"${manifest.templateId}": '
            '${unsupported.map((c) => c.name).join(', ')}',
      ));
    }
    return issues;
  }

  Future<List<PluginValidationIssue>> _configIssues(
    Directory pluginDir,
    String id,
    PluginManifest manifest,
  ) async {
    final issues = <PluginValidationIssue>[];
    for (final filename in [
      manifest.selectorsFile,
      manifest.filtersFile,
      manifest.permissionsFile,
    ]) {
      final file = File(p.join(pluginDir.path, filename));
      if (!await file.exists()) continue;
      try {
        final map = await _readJsonMap(pluginDir, filename);
        switch (filename) {
          case 'selectors.json':
            SelectorSet.fromJson(map);
          case 'filters.json':
            PluginFilters.fromJson(map);
          case 'permissions.json':
            PluginPermissions.fromJson(map);
          default:
            break;
        }
      } catch (e) {
        issues.add(PluginValidationIssue(
          pluginId: id,
          category: 'schema',
          message: '$filename does not parse: $e',
        ));
      }
    }
    return issues;
  }

  /// Every shipped file must be listed in `index.json` with a matching sha256.
  Future<List<PluginValidationIssue>> _checksumIssues(
    Directory pluginDir,
    String id,
  ) async {
    final indexFile = File(p.join(pluginDir.parent.path, 'index.json'));
    if (!await indexFile.exists()) return const [];
    final index = jsonDecode(await indexFile.readAsString());
    final rawPlugins = index is Map ? index['plugins'] : null;
    if (rawPlugins is! List) return const [];
    Map<String, Object?>? entry;
    for (final raw in rawPlugins.whereType<Map>()) {
      if (raw['id'] == id) {
        entry = Map<String, Object?>.from(raw);
        break;
      }
    }
    if (entry == null) {
      return [
        PluginValidationIssue(
          pluginId: id,
          category: 'checksum',
          message: 'missing from index.json; run '
              '`dart run tool/generate_plugin_catalog.dart`',
        ),
      ];
    }
    final checksums = entry['checksums'];
    if (checksums is! Map) return const [];

    final issues = <PluginValidationIssue>[];
    await for (final file in pluginDir.list()) {
      if (file is! File) continue;
      final name = p.basename(file.path);
      final expected = checksums[name];
      if (expected is! String) {
        issues.add(PluginValidationIssue(
          pluginId: id,
          category: 'checksum',
          message: 'index.json has no checksum for "$name"',
        ));
        continue;
      }
      final actual = _hasher.sha256OfBytes(await file.readAsBytes());
      if (actual != expected) {
        issues.add(PluginValidationIssue(
          pluginId: id,
          category: 'checksum',
          message: 'checksum mismatch for "$name"; re-run the catalog tool',
        ));
      }
    }
    return issues;
  }

  /// Runs the template over `tests/fixtures/*.html` with an [OfflineTransport],
  /// asserting the expectations in `tests/expected.json`.
  Future<List<PluginValidationIssue>> _fixtureIssues(
    Directory pluginDir,
    String id,
    PluginManifest manifest,
    Template template,
  ) async {
    final expectedFile = File(p.join(pluginDir.path, 'tests', 'expected.json'));
    if (!await expectedFile.exists()) return const [];

    final Map<String, Object?> expected;
    try {
      expected = await _readJsonMap(
        Directory(p.join(pluginDir.path, 'tests')),
        'expected.json',
      );
    } catch (e) {
      return [
        PluginValidationIssue(
          pluginId: id,
          category: 'fixture',
          message: 'tests/expected.json does not parse: $e',
        ),
      ];
    }

    final issues = <PluginValidationIssue>[];
    for (final entry in expected.entries) {
      final fixtureName = entry.key;
      final spec = entry.value;
      if (spec is! Map) {
        issues.add(PluginValidationIssue(
          pluginId: id,
          category: 'fixture',
          message: 'expected.json entry "$fixtureName" is not an object',
        ));
        continue;
      }
      final specMap = Map<String, Object?>.from(spec);
      final url = specMap['url'];
      if (url is! String) {
        issues.add(PluginValidationIssue(
          pluginId: id,
          category: 'fixture',
          message: 'expected.json entry "$fixtureName" has no "url"',
        ));
        continue;
      }
      final htmlFile =
          File(p.join(pluginDir.path, 'tests', 'fixtures', '$fixtureName.html'));
      final jsonFile =
          File(p.join(pluginDir.path, 'tests', 'fixtures', '$fixtureName.json'));
      if (!await htmlFile.exists() && !await jsonFile.exists()) {
        issues.add(PluginValidationIssue(
          pluginId: id,
          category: 'fixture',
          message: 'missing tests/fixtures/$fixtureName.html '
              '(or .json for API-driven chapter fixtures)',
        ));
        continue;
      }
issues.addAll(await _runFixture(
        pluginDir,
        id,
        manifest,
        template,
        fixtureName,
        url,
        specMap,
        htmlFile,
      ));
    }
    return issues;
  }

  Future<List<PluginValidationIssue>> _runFixture(
    Directory pluginDir,
    String id,
    PluginManifest manifest,
    Template template,
    String fixtureName,
    String url,
    Map<String, Object?> spec,
    File htmlFile,
  ) async {
    final jsonFile =
        File(p.join(pluginDir.path, 'tests', 'fixtures', '$fixtureName.json'));
    final transport = OfflineTransport();
    if (await htmlFile.exists()) {
      transport.addHtml(url, await htmlFile.readAsString());
    }
    if (await jsonFile.exists()) {
      final postUrl = spec['postUrl'];
      if (postUrl is! String || postUrl.isEmpty) {
        return [
          PluginValidationIssue(
            pluginId: id,
            category: 'fixture',
            message: 'fixture "$fixtureName": tests/fixtures/$fixtureName.json '
                'is present, so expected.json must declare a "postUrl" '
                '(the API endpoint the template POSTs to)',
          ),
        ];
      }
      Object? decoded;
      try {
        decoded = jsonDecode(await jsonFile.readAsString());
      } on Object catch (e) {
        return [
          PluginValidationIssue(
            pluginId: id,
            category: 'fixture',
            message: 'fixture "$fixtureName": '
                'tests/fixtures/$fixtureName.json does not parse: $e',
          ),
        ];
      }
      transport.addPostJson(postUrl, decoded);
    }
    final context = PluginContext(
      plugin: manifest,
      transport: transport,
      filters: await _optionalConfig<PluginFilters>(
          pluginDir, manifest.filtersFile, PluginFilters.fromJson),
      permissions: await _optionalConfig<PluginPermissions>(
          pluginDir, manifest.permissionsFile, PluginPermissions.fromJson),
      selectors: await _optionalConfig<SelectorSet>(
          pluginDir, manifest.selectorsFile, SelectorSet.fromJson),
    );

    final issues = <PluginValidationIssue>[];
    String? actualText;
    String? actualTitle;
    try {
      switch (spec['method']) {
        case 'metadata':
          final meta = await template.metadata(context, url);
          actualTitle = meta.title;
          actualText = meta.description;
        default:
          final doc = await template.chapterContent(context, url);
          actualTitle = doc.title;
          actualText = doc.renderToText();
      }
    } on TransportException catch (e) {
      return [
        PluginValidationIssue(
          pluginId: id,
          category: 'fixture',
          message: 'fixture "$fixtureName" threw: $e',
        ),
      ];
    } on Exception catch (e) {
      return [
        PluginValidationIssue(
          pluginId: id,
          category: 'fixture',
          message: 'fixture "$fixtureName" threw: $e',
        ),
      ];
    }

    final wantTitle = spec['title'];
    if (wantTitle is String && actualTitle != wantTitle) {
      issues.add(PluginValidationIssue(
        pluginId: id,
        category: 'fixture',
        message: 'fixture "$fixtureName": expected title "$wantTitle", '
            'got "$actualTitle"',
      ));
    }
    final wantContains = spec['textContains'];
    if (wantContains is List) {
      for (final fragment in wantContains.whereType<String>()) {
        if (actualText == null || !actualText.contains(fragment)) {
          issues.add(PluginValidationIssue(
            pluginId: id,
            category: 'fixture',
            message: 'fixture "$fixtureName": rendered text missing '
                '"$fragment"',
          ));
        }
      }
    }
    return issues;
  }

  Future<T?> _optionalConfig<T>(
    Directory pluginDir,
    String filename,
    T Function(Map<String, Object?>) fromJson,
  ) async {
    final file = File(p.join(pluginDir.path, filename));
    if (!await file.exists()) return null;
    return fromJson(await _readJsonMap(pluginDir, filename));
  }

  Future<Map<String, Object?>> _readJsonMap(
    Directory dir,
    String filename,
  ) async {
    final file = File(p.join(dir.path, filename));
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw FormatException('$filename must be a JSON object');
    }
    return Map<String, Object?>.from(decoded);
  }
}
