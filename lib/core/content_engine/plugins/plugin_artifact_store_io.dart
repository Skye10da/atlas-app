import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_engine/plugins/plugin_artifact_store.dart';

/// File-system implementation of [PluginArtifactStore]: plugins live under
/// `<baseDirectory>/<pluginId>/<filename>`, exactly where [PluginUpdater]
/// installs them.
class DirectoryPluginArtifactStore implements PluginArtifactStore {
  DirectoryPluginArtifactStore(this.baseDir);

  final Directory baseDir;

  Directory pluginDir(String pluginId) => Directory(p.join(baseDir.path, pluginId));

  @override
  Future<List<String>> listPluginIds() async {
    if (!await baseDir.exists()) return const [];
    final ids = <String>[];
    await for (final entry in baseDir.list()) {
      if (entry is! Directory) continue;
      ids.add(p.basename(entry.path));
    }
    return ids;
  }

  @override
  Future<String?> readText(String pluginId, String filename) async {
    final file = File(p.join(pluginDir(pluginId).path, filename));
    if (!await file.exists()) return null;
    return file.readAsString();
  }
}
