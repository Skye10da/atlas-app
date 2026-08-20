import 'dart:io';

/// Locates plugin artifacts in the distribution GitHub repo.
///
/// Expected layout in that repo:
/// ```
/// atlas-plugins/index.json           <- PluginCatalog (with sha256 checksums)
/// atlas-plugins/<pluginId>/plugin.json      <- plugin manifest
/// atlas-plugins/<pluginId>/<supporting files>  <- filters.json, ...
/// ```
/// Files are fetched from `raw.githubusercontent.com`, so the catalog's
/// checksums are what protect against tampering in transit.
class GithubPluginDistributionConfig {
  const GithubPluginDistributionConfig({
    this.owner = 'Skye10da',
    this.repo = 'atlas-app',
    this.branch = 'master',
    this.pluginsDir = 'atlas-plugins',
    this.catalogFilename = 'index.json',
  });
  final String owner;
  final String repo;
  final String branch;
  final String pluginsDir;
  final String catalogFilename;

  /// When non-null, points to a local directory of plugin files to use instead
  /// of downloading from GitHub. Set via the `ATLAS_PLUGINS_DIR` environment
  /// variable (e.g. `set ATLAS_PLUGINS_DIR=C:\...\atlas-plugins` on Windows,
  /// or `export ATLAS_PLUGINS_DIR=...` on macOS/Linux).
  ///
  /// When active the GitHub sync is skipped entirely and plugins are read
  /// directly from this path, so edits take effect on next app launch without
  /// needing a commit or push.
  static String? get localPluginsDir =>
      Platform.environment['ATLAS_PLUGINS_DIR'];

  String get _base => 'https://raw.githubusercontent.com/$owner/$repo/$branch';

  Uri catalogUrl() => Uri.parse('$_base/$pluginsDir/$catalogFilename');

  Uri fileUrl(String pluginId, String filename) =>
      Uri.parse('$_base/$pluginsDir/$pluginId/$filename');
}
