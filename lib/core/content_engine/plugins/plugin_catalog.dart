import 'package:atlas_app/core/content_engine/plugins/verification.dart';

class PluginCatalogException implements Exception {
  const PluginCatalogException(this.message);

  final String message;

  @override
  String toString() => 'PluginCatalogException: $message';
}

/// One entry in `plugins/index.json`: the identity of a plugin release plus
/// sha256 checksums for every file that release ships. The checksums are the
/// trust anchor — `GithubPluginSource` verifies every downloaded file against
/// them, so tampering in transit is detected.
class PluginCatalogEntry {
  const PluginCatalogEntry({
    required this.id,
    required this.version,
    required this.checksums,
  });

  factory PluginCatalogEntry.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const PluginCatalogException(
        'catalog entry must have a non-empty "id"',
      );
    }
    final versionRaw = json['version'];
    if (versionRaw is! String) {
      throw PluginCatalogException(
        'catalog entry "$id" must have a semver "version"',
      );
    }
    final version = PluginVersion.tryParse(versionRaw);
    if (version == null) {
      throw PluginCatalogException(
        'catalog entry "$id" version "$versionRaw" is not valid semver',
      );
    }
    final rawChecksums = json['checksums'];
    if (rawChecksums is! Map || rawChecksums.isEmpty) {
      throw PluginCatalogException(
        'catalog entry "$id" must list at least one file in "checksums"',
      );
    }
    final checksums = rawChecksums.map((key, value) {
      if (value is! String || value.isEmpty) {
        throw PluginCatalogException(
          'catalog entry "$id" has a non-string checksum for "$key"',
        );
      }
      return MapEntry('$key', value);
    });
    return PluginCatalogEntry(
      id: id,
      version: version,
      checksums: checksums,
    );
  }

  final String id;
  final PluginVersion version;

  /// filename -> sha256 hex of that file's content.
  final Map<String, String> checksums;

  Map<String, Object?> toJson() => {
        'id': id,
        'version': version.toString(),
        'checksums': checksums,
      };
}

/// `plugins/index.json` in the distribution GitHub repo.
class PluginCatalog {
  const PluginCatalog(this.plugins);

  factory PluginCatalog.fromJson(Map<String, Object?> json) {
    final raw = json['plugins'];
    if (raw is! List) {
      throw const PluginCatalogException(
        'catalog must have a "plugins" list',
      );
    }
    final plugins = <PluginCatalogEntry>[];
    for (final entry in raw) {
      if (entry is! Map) {
        throw const PluginCatalogException(
          'catalog "plugins" must be a list of objects',
        );
      }
      plugins.add(PluginCatalogEntry.fromJson(Map<String, Object?>.from(entry)));
    }
    return PluginCatalog(plugins);
  }

  final List<PluginCatalogEntry> plugins;

  PluginCatalogEntry? entryFor(String id) {
    for (final entry in plugins) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Map<String, Object?> toJson() =>
      {'plugins': [for (final entry in plugins) entry.toJson()]};
}
