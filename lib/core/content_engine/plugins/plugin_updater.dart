import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_engine/plugins/github_plugin_source.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_catalog.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_repository.dart';
import 'package:atlas_app/core/content_engine/plugins/verification.dart';
import 'package:atlas_app/core/content_engine/templates/template_registry.dart';

enum PluginUpdateStatus {
  /// A previously unknown plugin was installed.
  installed,

  /// A newer version replaced the installed one.
  upgraded,

  /// Already at the catalog version; nothing to do.
  upToDate,

  /// The installed version is newer than the catalog one; kept as-is.
  newerInstalled,

  /// The plugin could not be fetched, verified, or validated.
  failed,
}

class PluginUpdate {
  const PluginUpdate({
    required this.pluginId,
    required this.status,
    required this.toVersion,
    this.fromVersion,
    this.error,
  });

  final String pluginId;
  final PluginUpdateStatus status;
  final PluginVersion toVersion;
  final PluginVersion? fromVersion;
  final String? error;
}

/// Synchronizes installed plugins with the catalog published in the
/// distribution GitHub repo.
///
/// Trust model: SHA256 + semver, *not* signing. Checksums protect against
/// tampering in transit; they do not protect against a malicious plugin
/// author. Signing is a deferred distribution risk.
class PluginUpdater {
  PluginUpdater({
    required this.source,
    required this.targetDirectory,
    required this.templateRegistry,
  });

  final GithubPluginSource source;
  final Directory targetDirectory;
  final TemplateRegistry templateRegistry;

  /// Pulls the catalog and updates every listed plugin, returning one outcome
  /// per plugin. A per-plugin failure (network, checksum, validation) becomes
  /// a `failed` outcome; only a catalog that cannot be fetched or parsed
  /// throws [PluginDistributionException].
  Future<List<PluginUpdate>> sync() async {
    final catalog = await source.fetchCatalog();
    final repository = PluginRepository(
      baseDirectory: targetDirectory,
      templateRegistry: templateRegistry,
    );
    final results = <PluginUpdate>[];
    for (final entry in catalog.plugins) {
      results.add(await _syncEntry(repository, entry));
    }
    return results;
  }

  Future<PluginUpdate> _syncEntry(
    PluginRepository repository,
    PluginCatalogEntry entry,
  ) async {
    final installed = await _installedVersion(repository, entry.id);
    if (installed != null) {
      final comparison = entry.version.compareTo(installed);
      if (comparison == 0) {
        return PluginUpdate(
          pluginId: entry.id,
          status: PluginUpdateStatus.upToDate,
          toVersion: entry.version,
          fromVersion: installed,
        );
      }
      if (comparison < 0) {
        return PluginUpdate(
          pluginId: entry.id,
          status: PluginUpdateStatus.newerInstalled,
          toVersion: entry.version,
          fromVersion: installed,
        );
      }
    }
    try {
      final files = await source.download(entry);
      await source.writeFiles(entry, files, targetDirectory);
      // Reload through PluginRepository so the full validation — id matches
      // the directory, templateId resolves, capabilities implemented, no JS
      // rendering — runs against the freshly written plugin.json.
      final manifest = await repository.load(entry.id);
      if (manifest.version != entry.version) {
        throw const PluginDistributionException(
          'manifest version does not match the catalog entry',
        );
      }
      return PluginUpdate(
        pluginId: entry.id,
        status: installed == null
            ? PluginUpdateStatus.installed
            : PluginUpdateStatus.upgraded,
        toVersion: entry.version,
        fromVersion: installed,
      );
    } catch (e) {
      // Roll back a partial install so a broken plugin is never left behind.
      try {
        await Directory(p.join(targetDirectory.path, entry.id))
            .delete(recursive: true);
      } catch (_) {}
      return PluginUpdate(
        pluginId: entry.id,
        status: PluginUpdateStatus.failed,
        toVersion: entry.version,
        fromVersion: installed,
        error: e.toString(),
      );
    }
  }

  Future<PluginVersion?> _installedVersion(
    PluginRepository repository,
    String pluginId,
  ) async {
    try {
      return (await repository.load(pluginId)).version;
    } catch (_) {
      // Not installed — or a broken install that fails validation; either
      // way it should be (re)installed from the catalog.
      return null;
    }
  }
}
