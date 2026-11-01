import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_engine/plugins/plugin_artifact_store.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_artifact_store_io.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_filters.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_permissions.dart';
import 'package:atlas_app/core/content_engine/registry/plugin_source.dart';
import 'package:atlas_app/core/content_engine/selectors/selector_set.dart';
import 'package:atlas_app/core/content_engine/templates/template_registry.dart';
import 'package:atlas_app/core/content_engine/transport/transport_registry.dart';
import 'package:atlas_app/core/database/database.dart';

/// Resolves plugins from an artifact backend (installed files on disk by
/// default, fetched-in-memory from the distribution repo on the web) into
/// runnable [PluginSource]s.
///
/// Validation failures — missing/unknown `templateId`, capabilities the
/// resolved template doesn't implement, `requiresJsRendering` — throw at load
/// time (named exceptions, not null-check failures), never deep inside a
/// template call.
class PluginRepository {
  PluginRepository({
    required this.baseDirectory,
    required this.templateRegistry,
    required this.database,
    TransportRegistry? transportRegistry,
    PluginArtifactStore? store,
  }) : _store = store ?? DirectoryPluginArtifactStore(baseDirectory),
       transportRegistry = transportRegistry ?? const TransportRegistry();

  final Directory baseDirectory;
  final TemplateRegistry templateRegistry;
  final TransportRegistry transportRegistry;
  final AppDatabase database;

  /// Where plugin files are read from. [baseDirectory] is only meaningful
  /// for the default disk store (and for [pluginDir], used by installers).
  final PluginArtifactStore _store;

  Directory pluginDir(String pluginId) =>
      Directory(p.join(baseDirectory.path, pluginId));

  Future<PluginManifest> load(String pluginId) async {
    final content = await _store.readText(pluginId, 'plugin.json');
    if (content == null) {
      throw PluginManifestException(
        'No plugin.json found for "$pluginId"',
      );
    }
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw PluginManifestException(
        'plugin.json for "$pluginId" must be a JSON object',
      );
    }
    final manifest = PluginManifest.fromJson(
      Map<String, Object?>.from(decoded),
    );
    if (manifest.id != pluginId) {
      throw PluginManifestException(
        'plugin.json "id" (${manifest.id}) does not match directory '
        '"$pluginId"',
      );
    }
    _validateAgainstTemplates(manifest);
    return manifest;
  }

  /// Loads every available plugin. Fails loudly: a malformed manifest throws
  /// rather than being silently skipped.
  Future<List<PluginManifest>> loadAll() async {
    final ids = await _store.listPluginIds();
    final results = <PluginManifest>[];
    for (final id in ids) {
      results.add(await load(id));
    }
    return results;
  }

  Future<PluginFilters> loadFilters(PluginManifest plugin) async =>
      PluginFilters.fromJson(await _loadJsonMap(plugin, plugin.filtersFile));

  Future<PluginPermissions> loadPermissions(PluginManifest plugin) async =>
      PluginPermissions.fromJson(
        await _loadJsonMap(plugin, plugin.permissionsFile),
      );

  Future<SelectorSet> loadSelectors(PluginManifest plugin) async =>
      SelectorSet.fromJson(await _loadJsonMap(plugin, plugin.selectorsFile));

  Future<PluginSource> buildSource(String pluginId) async {
    final manifest = await load(pluginId);
    final filters = await loadFilters(manifest);
    final permissions = await loadPermissions(manifest);
    final selectors = await loadSelectors(manifest);
    final template = templateRegistry.resolve(manifest.templateId);
    final transport = transportRegistry.create(
      manifest,
      permissions: permissions,
    );
    return PluginSource(
      manifest: manifest,
      template: template,
      transport: transport,
      database: database,
      selectors: selectors,
      filters: filters,
      permissions: permissions,
    );
  }

  Future<List<PluginSource>> buildAllSources() async {
    final manifests = await loadAll();
    final sources = <PluginSource>[];
    for (final manifest in manifests) {
      sources.add(await buildSource(manifest.id));
    }
    return sources;
  }

  Future<Map<String, Object?>> _loadJsonMap(
    PluginManifest plugin,
    String filename,
  ) async {
    final content = await _store.readText(plugin.id, filename);
    if (content == null) return const {};
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw PluginManifestException(
        '$filename for "${plugin.id}" must be a JSON object',
      );
    }
    return Map<String, Object?>.from(decoded);
  }

  void _validateAgainstTemplates(PluginManifest manifest) {
    if (manifest.requiresJsRendering) {
      throw PluginManifestException(
        'Plugin "${manifest.id}" requires browser (JS) rendering, which is '
        'not supported in this release',
      );
    }
    final template = templateRegistry.resolve(manifest.templateId);
    final unsupported = manifest.capabilities
        .where((c) => !template.supportedCapabilities.contains(c))
        .toList();
    if (unsupported.isNotEmpty) {
      throw PluginManifestException(
        'Plugin "${manifest.id}" declares capabilities not implemented by '
        'template "${manifest.templateId}": '
        '${unsupported.map((c) => c.name).join(', ')}',
      );
    }
  }
}
