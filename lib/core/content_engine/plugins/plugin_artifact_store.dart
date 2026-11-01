import 'dart:async';

/// Reads plugin artifacts without coupling to where they come from.
///
/// The default backend is the device file system
/// (`<baseDirectory>/<pluginId>/<file>`). On the web target — where no device
/// file system exists — the distribution GitHub repo is fetched over HTTP
/// instead, so plugin loading keeps working live.
abstract interface class PluginArtifactStore {
  /// Ids of available plugins, in no particular order.
  Future<List<String>> listPluginIds();

  /// Content of one UTF-8 file belonging to [pluginId], or `null` when the
  /// file does not exist for that plugin.
  Future<String?> readText(String pluginId, String filename);
}
