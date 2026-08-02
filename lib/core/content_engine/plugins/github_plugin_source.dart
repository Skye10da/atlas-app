import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_engine/models/content_hasher.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_catalog.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_distribution_config.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

class PluginDistributionException implements Exception {
  const PluginDistributionException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'PluginDistributionException: $message';
}

/// Fetches and verifies plugin artifacts from the distribution GitHub repo,
/// over a [Transport] so tests substitute a `FakeTransport` and the fetcher
/// reuses the engine's caching/stealth layers in production.
class GithubPluginSource {
  GithubPluginSource({
    required this.config,
    required this.transport,
    ContentHasher hasher = const ContentHasher(),
  }) : _hasher = hasher;

  final GithubPluginDistributionConfig config;
  final Transport transport;
  final ContentHasher _hasher;

  Future<PluginCatalog> fetchCatalog() async {
    final Object? value;
    try {
      value = await transport.fetchJson(config.catalogUrl());
    } on TransportException catch (e) {
      throw PluginDistributionException(
        'Failed to fetch plugin catalog from ${config.catalogUrl()}: '
        '${e.message}',
        cause: e,
      );
    }
    if (value is! Map) {
      throw const PluginDistributionException(
        'Plugin catalog must be a JSON object',
      );
    }
    try {
      return PluginCatalog.fromJson(Map<String, Object?>.from(value));
    } on PluginCatalogException catch (e) {
      throw PluginDistributionException(
        'Invalid plugin catalog: ${e.message}',
        cause: e,
      );
    }
  }

  /// Downloads the files listed in [entry], verifying each against its
  /// catalog checksum. Returns filename -> UTF-8 content. Throws
  /// [PluginDistributionException] on any network or checksum failure.
  Future<Map<String, String>> download(PluginCatalogEntry entry) async {
    final files = <String, String>{};
    for (final filename in entry.checksums.keys) {
      final uri = config.fileUrl(entry.id, filename);
      final String body;
      try {
        body = await transport.fetchHtml(uri);
      } on TransportException catch (e) {
        throw PluginDistributionException(
          'Failed to fetch ${entry.id}/$filename: ${e.message}',
          cause: e,
        );
      }
      final actual = _hasher.sha256OfBytes(utf8.encode(body));
      final expected = entry.checksums[filename]!;
      if (actual != expected) {
        throw PluginDistributionException(
          'Checksum mismatch for ${entry.id}/$filename '
          '(expected $expected, got $actual)',
        );
      }
      files[filename] = body;
    }
    return files;
  }

  /// Writes downloaded [files] into `targetDir/<id>/`, removing any stale
  /// files that are no longer part of this release.
  Future<void> writeFiles(
    PluginCatalogEntry entry,
    Map<String, String> files,
    Directory targetDir,
  ) async {
    final dir = Directory(p.join(targetDir.path, entry.id));
    await dir.create(recursive: true);
    await for (final existing in dir.list()) {
      if (existing is File &&
          !entry.checksums.containsKey(p.basename(existing.path))) {
        await existing.delete();
      }
    }
    for (final file in files.entries) {
      await File(p.join(dir.path, file.key)).writeAsString(file.value);
    }
  }
}
