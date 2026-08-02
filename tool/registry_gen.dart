// Generates atlas-plugins/registry.json from the plugin manifests: a compact
// registry the app can consume to know what plugins exist and which template
// each targets, without scanning plugin.json files at startup.
//
// Run from the package root:
//   dart run tool/registry_gen.dart
//
// Commit the resulting atlas-plugins/registry.json; CI runs this alongside
// the validator.

import 'dart:convert';
import 'dart:io';

import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';

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
    final PluginManifest manifest;
    try {
      manifest = PluginManifest.fromJson(
        (jsonDecode(await manifestFile.readAsString()) as Map)
            .map((k, v) => MapEntry('$k', v)),
      );
    } catch (e) {
      stderr.writeln('Skip ${entry.path}: plugin.json does not parse: $e');
      continue;
    }
    entries.add({
      'id': manifest.id,
      'name': manifest.name,
      'sourceName': manifest.sourceName,
      'version': manifest.version.toString(),
      'templateId': manifest.templateId,
      'transport': manifest.transport,
      'baseUrl': manifest.baseUrl,
      'capabilities': manifest.capabilities.map((c) => c.name).toList(),
    });
  }

  entries.sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));

  final outFile =
      File('${pluginsDir.path}${Platform.pathSeparator}registry.json');
  await outFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert({'plugins': entries})}\n',
  );
  stdout.writeln('Wrote ${outFile.path} with ${entries.length} plugin(s)');
}
