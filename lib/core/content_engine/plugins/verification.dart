import 'package:atlas_app/core/content_engine/models/content_hasher.dart';

/// A parsed semver version (major.minor.patch). Used for manifest validation
/// now and, in Phase 4, by PluginUpdater to compare published vs installed
/// versions.
class PluginVersion implements Comparable<PluginVersion> {
  const PluginVersion({
    required this.major,
    required this.minor,
    required this.patch,
  });

  final int major;
  final int minor;
  final int patch;

  static const _pattern = r'^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$';

  static PluginVersion? tryParse(String raw) {
    final match = RegExp(_pattern).firstMatch(raw.trim());
    if (match == null) return null;
    return PluginVersion(
      major: int.parse(match[1]!),
      minor: int.parse(match[2]!),
      patch: int.parse(match[3]!),
    );
  }

  @override
  int compareTo(PluginVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) =>
      other is PluginVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// SHA256 + semver verification helpers for plugin manifests and, in Phase 4,
/// plugin updates.
class PluginVerifier {
  const PluginVerifier();

  static const _hasher = ContentHasher();

  String sha256Of(String content) => _hasher.sha256Of(content);

  bool matchesChecksum(String content, String expectedChecksum) =>
      _hasher.sha256Of(content) == expectedChecksum;
}
