/// Update channels exposed in Settings. Mirrors the `channel` field of
/// `manifest.json` written by the release workflow (.github/workflows).
enum UpdateChannel {
  /// Released tags, e.g. `v1.0.8+8`. What most users should follow.
  stable,

  /// Prerelease tags with a semver suffix, e.g. `v1.0.9-rc.1+9`.
  beta;

  String get label => switch (this) {
        UpdateChannel.stable => 'Stable releases',
        UpdateChannel.beta => 'Include beta (prereleases)',
      };
}

/// An artifact (downloadable file) attached to [AppRelease] for one platform.
class ReleaseArtifact {
  const ReleaseArtifact({
    required this.file,
    required this.downloadUrl,
    required this.sha256,
    this.sizeBytes,
  });

  /// Asset filename in the release, e.g. `atlas-v1.0.8+8-android.apk`.
  final String file;

  /// Absolute GitHub `browser_download_url` for the asset.
  final String downloadUrl;

  /// SHA-256 hex digest computed by the release workflow; verified after
  /// download before the file is handed to the system installer.
  final String sha256;

  /// Asset size in bytes when reported by GitHub; null when unknown.
  final int? sizeBytes;
}

/// A published Atlas release, parsed from GitHub Releases + the generated
/// `manifest.json` asset.
class AppRelease {
  const AppRelease({
    required this.tag,
    required this.version,
    required this.versionCode,
    required this.channel,
    required this.publishedAt,
    required this.artifacts,
    this.notes,
    this.releaseUrl,
  });

  /// Raw release tag, e.g. `v1.0.8+8` (also the release's `tag_name`).
  final String tag;

  /// Semver portion without the build suffix, e.g. `1.0.8`.
  final String version;

  /// The `+<build>` suffix — the number the updater compares first.
  final int versionCode;

  /// stable for plain tags, beta when the semver carries a suffix like `-rc.1`.
  final UpdateChannel channel;

  final DateTime publishedAt;

  /// Human-readable release notes from the GitHub release body.
  final String? notes;

  /// GitHub release page, shown via "View on GitHub" fallback actions.
  final String? releaseUrl;

  /// Artifacts keyed by platform: `android`, `windows`. Whatever platform this
  /// device runs on must have an entry before an in-app update is offered.
  final Map<String, ReleaseArtifact> artifacts;

  ReleaseArtifact? artifactFor(String platform) => artifacts[platform];
}
