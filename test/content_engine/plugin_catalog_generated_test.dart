import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/plugins/plugin_catalog.dart';
import 'package:atlas_app/core/content_engine/plugins/verification.dart';

void main() {
  test('atlas-plugins/index.json is current: every file in atlas-plugins/ '
      'matches its committed checksum and version', () async {
    final indexFile = File('atlas-plugins/index.json');
    expect(
      await indexFile.exists(),
      isTrue,
      reason: 'run `dart run tool/generate_plugin_catalog.dart`',
    );

    final catalog = PluginCatalog.fromJson(
      jsonDecode(await indexFile.readAsString()) as Map<String, Object?>,
    );

    final entries = await Directory('atlas-plugins').list().toList();
    for (final entry in entries.whereType<Directory>()) {
      final manifestFile = File(
        '${entry.path}${Platform.pathSeparator}plugin.json',
      );
      if (!await manifestFile.exists()) continue;

      final manifest = jsonDecode(await manifestFile.readAsString()) as Map;
      final id = manifest['id'] as String;
      final catalogEntry = catalog.entryFor(id);
      expect(
        catalogEntry,
        isNotNull,
        reason: 'atlas-plugins/index.json is missing "$id"; re-run the tool',
      );

      expect(
        catalogEntry!.version,
        PluginVersion.tryParse(manifest['version'] as String),
        reason: 'index version for "$id" is stale',
      );

      await for (final file in entry.list()) {
        if (file is! File) continue;
        final name = file.uri.pathSegments.last;
        final expected = catalogEntry.checksums[name];
        if (expected == null) {
          fail('index has no checksum for "$id/$name"');
        }
        final actual = sha256.convert(await file.readAsBytes()).toString();
        expect(
          actual,
          expected,
          reason:
              'working tree "$id/$name" no longer matches the index; '
              're-run the tool',
        );
      }
    }
  });
}
