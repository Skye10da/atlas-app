/// One version's changelog as shown in Settings → What's new and after an
/// in-app update. Sourced from GitHub release notes (release body) and cached
/// in shared_preferences so history stays readable offline and after install.
class ChangelogEntry {
  const ChangelogEntry({
    required this.tag,
    required this.version,
    required this.versionCode,
    required this.publishedAt,
    required this.notes,
  });

  /// Raw release tag, e.g. `v1.0.8+8`. Changelog save/uniqueness key.
  final String tag;

  /// Semver without the build suffix, e.g. `1.0.8`.
  final String version;

  /// The `+<build>` number — used for ordering (newest first).
  final int versionCode;

  /// When the release shipped, from GitHub (floor of epoch when unknown).
  final DateTime publishedAt;

  /// Release notes body: plain markdown-ish text, rendered lite (see
  /// FormatReleaseNotes in changelog_text.dart).
  final String notes;

  ChangelogEntry copyWith({String? notes}) => ChangelogEntry(
        tag: tag,
        version: version,
        versionCode: versionCode,
        publishedAt: publishedAt,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'version': version,
        'versionCode': versionCode,
        'publishedAt': publishedAt.toIso8601String(),
        'notes': notes,
      };

  static ChangelogEntry? fromJson(Map<String, dynamic> json) {
    try {
      final tag = json['tag'];
      final version = json['version'];
      final versionCode = json['versionCode'];
      final publishedAt = json['publishedAt'];
      final notes = json['notes'];
      if (tag is! String || tag.isEmpty) return null;
      if (version is! String || version.isEmpty) return null;
      if (versionCode is! int) return null;
      if (publishedAt is! String) return null;
      final at = DateTime.tryParse(publishedAt);
      if (at == null) return null;
      if (notes is! String) return null;
      return ChangelogEntry(
        tag: tag,
        version: version,
        versionCode: versionCode,
        publishedAt: at,
        notes: notes,
      );
    } catch (_) {
      return null;
    }
  }
}
