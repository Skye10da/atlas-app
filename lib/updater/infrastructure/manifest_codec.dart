import 'package:atlas_app/updater/domain/entities/app_release.dart';

/// Maps `<repo>/releases/latest` GitHub JSON + the generated `manifest.json`
/// asset onto [AppRelease]. All parsing is defensive: a malformed release must
/// degrade to null, never throw into the app's update flow.
class ManifestCodec {
  const ManifestCodec();

  /// Extracts the download URL of the `manifest.json` asset from the release's
  /// asset list (decoded GitHub `release['assets']` value).
  String? findManifestJson(List<dynamic> assets) {
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is String && url is String && name == 'manifest.json') return url;
    }
    return null;
  }

  /// Parses the workflow-generated manifest body (tool/generate_manifest.py).
  ///
  /// Shape:
  /// ```json
  /// {
  ///   "version": "1.0.8", "versionCode": 8,
  ///   "publishedAt": "2026-10-31T12:00:00Z",
  ///   "artifacts": { "android": { "file", "sha256", "size" } },
  ///   "notes": "…" (optional)
  /// }
  /// ```
  ///
  /// Artifact download URLs are filled in later by [withAssetUrls], which
  /// pairs each manifest filename with its real GitHub download URL.
  AppRelease? parseManifest(Map<String, dynamic> json) {
    try {
      final version = json['version'];
      final versionCode = json['versionCode'];
      final publishedAt = json['publishedAt'];
      final artifacts = json['artifacts'];
      if (version is! String || version.isEmpty) return null;
      if (versionCode is! int) return null;
      if (artifacts is! Map<String, dynamic> || artifacts.isEmpty) return null;

      final parsed = <String, ReleaseArtifact>{};
      for (final entry in artifacts.entries) {
        final platform = entry.key;
        final data = entry.value;
        if (data is! Map<String, dynamic>) return null;
        final file = data['file'];
        final sha256 = data['sha256'];
        final size = data['size'];
        if (file is! String || sha256 is! String) return null;
        parsed[platform] = ReleaseArtifact(
          file: file,
          downloadUrl: '', // patched by withAssetUrls
          sha256: sha256,
          sizeBytes: size is int ? size : null,
        );
      }

      final at = publishedAt is String ? DateTime.tryParse(publishedAt) : null;
      if (at == null) return null;

      return AppRelease(
        tag: 'v$version',
        version: version,
        versionCode: versionCode,
        // Beta iff the semver carries a prerelease suffix (mirrors how the
        // workflow classifies tags; kept independent from it on purpose).
        channel: version.contains('-') ? UpdateChannel.beta : UpdateChannel.stable,
        publishedAt: at,
        notes: _stringOrNull(json['notes']),
        artifacts: parsed,
      );
    } catch (_) {
      return null;
    }
  }

  /// Pairs each manifest artifact with its real `browser_download_url` from
  /// the release asset list (the manifest only stores filenames). Artifacts
  /// whose filename has no matching asset are dropped.
  AppRelease withAssetUrls(AppRelease release, List<dynamic> assets) {
    final urls = <String, String>{};
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is String && url is String) urls[name] = url;
    }
    final patched = <String, ReleaseArtifact>{};
    for (final entry in release.artifacts.entries) {
      final url = urls[entry.value.file];
      if (url == null) continue;
      patched[entry.key] = ReleaseArtifact(
        file: entry.value.file,
        downloadUrl: url,
        sha256: entry.value.sha256,
        sizeBytes: entry.value.sizeBytes,
      );
    }
    return AppRelease(
      tag: release.tag,
      version: release.version,
      versionCode: release.versionCode,
      channel: release.channel,
      publishedAt: release.publishedAt,
      notes: release.notes,
      releaseUrl: release.releaseUrl,
      artifacts: patched,
    );
  }

  String? _stringOrNull(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
