// Validates every plugin package under atlas-plugins/ the way CI would:
// schema + semver, template wiring, catalog checksums, and fixture smoke
// tests over recorded HTML (no live network).
//
// Run from the package root:
//   dart run tool/plugin_validator.dart
//
// Exits non-zero on any issue, so CI fails loudly.

import 'dart:io';

import 'package:atlas_app/core/content_engine/plugins/plugin_validator.dart';

Future<void> main() async {
  const pluginsRoot = 'atlas-plugins';
  final issues = await PluginValidator().validateAll(Directory(pluginsRoot));
  if (issues.isEmpty) {
    stdout.writeln('OK: all plugins in $pluginsRoot validate');
    return;
  }
  for (final issue in issues) {
    stderr.writeln('ERROR: $issue');
  }
  exitCode = 1;
}
