// Generates atlas-plugins/index.json (the PluginCatalog) from the plugin
// directories under atlas-plugins/, computing sha256 checksums for every file.
//
// Run from the package root:
//   dart run tool/generate_plugin_catalog.dart
//
// Commit the resulting atlas-plugins/index.json alongside the plugin
// directories; that file is what the distribution GitHub repo serves as its
// catalog.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Future<void> main() async {
  final pluginsDir = Directory('atlas-plugins');
  if (!await pluginsDir.exists()) {
    stderr.writeln('No atlas-plugins/ directory at ${pluginsDir.path}');
    exitCode = 1;
    return;
  }

  final entries = <Map<String, Object?>>[];
  await for (final entry in pluginsDir.list()) {
    if (entry is! Directory) continue;
    final manifestFile = File('${entry.path}${Platform.pathSeparator}plugin.json');
    if (!await manifestFile.exists()) continue;
    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map) continue;
    final id = decoded['id'];
    final version = decoded['version'];
    if (id is! String || version is! String) {
      stderr.writeln(
        'Skip ${entry.path}: plugin.json missing a string "id"/"version"',
      );
      continue;
    }

    final checksums = <String, String>{};
    await for (final file in entry.list()) {
      if (file is! File) continue;
      checksums[file.uri.pathSegments.last] =
          sha256.convert(await file.readAsBytes()).toString();
    }
    entries.add({'id': id, 'version': version, 'checksums': checksums});
  }

  entries.sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));

  final catalogFile = File('${pluginsDir.path}${Platform.pathSeparator}index.json');
  await catalogFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert({'plugins': entries})}\n',
  );
  stdout.writeln(
    'Wrote ${catalogFile.path} with ${entries.length} plugin(s)',
  );
}
