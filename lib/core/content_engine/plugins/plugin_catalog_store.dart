import 'package:atlas_app/core/content_engine/plugins/github_plugin_source.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_artifact_store.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_catalog.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';

/// [PluginArtifactStore] backed by the distribution GitHub repo: plugin
/// artifacts are fetched over HTTP in memory ([GithubPluginSource.download])
/// instead of being read from installed files on disk.
///
/// Used by the web target — there are no installed files there — and by any
/// backend that wants live-from-repo behavior. Every downloaded file is
/// checksum-verified against the catalog, so transit integrity is the same
/// as the on-disk install path.
class PluginCatalogArtifactStore implements PluginArtifactStore {
  PluginCatalogArtifactStore({required this.source});

  final GithubPluginSource source;

  PluginCatalog? _catalog;
  final Map<String, Map<String, String>> _filesByPluginId = {};

  Future<PluginCatalog> _loadCatalog() => source.fetchCatalog();

  /// Downloads (or reuses, per session) every catalog-listed file of
  /// [pluginId]. Returns `null` when the plugin is not in the catalog —
  /// matching "no directory on disk" semantics — and rethrows download or
  /// checksum failures as [PluginManifestException] so a single unreachable
  /// plugin fails loudly without replacing the whole catalog's error shape.
  Future<Map<String, String>?> _pluginFiles(String pluginId) async {
    final cached = _filesByPluginId[pluginId];
    if (cached != null) return cached;

    final catalog = _catalog ??= await _loadCatalog();
    PluginCatalogEntry? entry;
    for (final candidate in catalog.plugins) {
      if (candidate.id == pluginId) {
        entry = candidate;
        break;
      }
    }
    if (entry == null) return null;

    final Map<String, String> files;
    try {
      files = await source.download(entry);
    } on PluginDistributionException catch (e) {
      throw PluginManifestException(
        'Plugin "$pluginId" failed to download: ${e.message}',
      );
    }
    return _filesByPluginId[pluginId] = files;
  }

  @override
  Future<List<String>> listPluginIds() async =>
      [for (final entry in (await _loadCatalog()).plugins) entry.id];

  @override
  Future<String?> readText(String pluginId, String filename) async {
    final files = await _pluginFiles(pluginId);
    if (files == null) return null;
    return files[filename];
  }
}
