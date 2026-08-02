/// Locates plugin artifacts in the distribution GitHub repo.
///
/// Expected layout in that repo:
/// ```
/// plugins/index.json                 <- PluginCatalog (with sha256 checksums)
/// <pluginId>/plugin.json             <- plugin manifest
/// <pluginId>/<supporting files>      <- filters.json, permissions.json, ...
/// ```
/// Files are fetched from `raw.githubusercontent.com`, so the catalog's
/// checksums are what protect against tampering in transit.
class GithubPluginDistributionConfig {
  const GithubPluginDistributionConfig({
    this.owner = 'atlas-app',
    this.repo = 'atlas-plugins',
    this.branch = 'main',
    this.pluginsDir = 'plugins',
    this.catalogFilename = 'index.json',
  });
// TODO(plugins): set the real distribution repo before shipping. Until then
  final String owner;
  final String repo;
  final String branch;
  final String pluginsDir;
  final String catalogFilename;

  String get _base => 'https://raw.githubusercontent.com/$owner/$repo/$branch';

  Uri catalogUrl() => Uri.parse('$_base/$pluginsDir/$catalogFilename');

  Uri fileUrl(String pluginId, String filename) =>
      Uri.parse('$_base/$pluginsDir/$pluginId/$filename');
}