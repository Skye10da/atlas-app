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

  String get _base => 'https://raw.githubusercontent.com/$owner/$repo/$branch';

  Uri catalogUrl() => Uri.parse('$_base/$pluginsDir/$catalogFilename');

  Uri fileUrl(String pluginId, String filename) =>
      Uri.parse('$_base/$pluginsDir/$pluginId/$filename');
}