import 'package:flutter/foundation.dart';

import 'package:atlas_app/marketing/domain/entities/device_profile.dart';
import 'package:atlas_app/marketing/domain/entities/github_release.dart';

/// One actionable download option for the landing page: either the fully
/// resolved artifact for this device, or an honest fallback to the release
/// page when no asset can be confidently matched.
@immutable
class ResolvedDownload {
  const ResolvedDownload({
    required this.label,
    required this.downloadUrl,
    this.fileName,
    this.sizeBytes,
    this.isExactMatch = true,
  });

  /// "Atlas 1.0.8 for Windows (x64)" — the smart-button text.
  final String label;

  /// Direct asset URL on an exact match; the GitHub releases page otherwise.
  final String downloadUrl;

  /// Suggested file name for the browser's `download` attribute (null for
  /// fallback links, which navigate to the releases page instead).
  final String? fileName;

  /// Asset size in bytes, when known (drives the "· 84 MB" micro-copy).
  final int? sizeBytes;

  /// False → we could not confidently match an asset; the UI must label the
  /// action "See all downloads" instead of promising a guessed file.
  final bool isExactMatch;
}

/// Maps a [DeviceProfile] onto the best release artifact.
///
/// Matching contract (asset naming, `docs/plans/landing_upgrade_plan.md`):
///
///     atlas-<version>-<platform>[-<arch>].<ext>
///
/// Token matching is deliberately tolerant of both the canonical contract and
/// legacy names (`atlas-android-arm64-v1.0.0.apk`). Specificity order:
///
/// 1. platform token **and** matching architecture token → exact
/// 2. platform token, no architecture token (universal APK / plain zip)
/// 3. platform token with a *different* arch (e.g. an ARM64 Windows client
///    offered the only x64 zip, which runs under emulation) — still exact
/// 4. nothing matches → release page, `isExactMatch: false`
class ReleaseAssetResolver {
  const ReleaseAssetResolver();

  /// Assets that are never offered as downloads (screenshots are content,
  /// checksums/manifests are metadata).
  static bool isDownloadableAsset(GitHubReleaseAsset asset) {
    if (asset.isImage) return false;
    final ext = asset.fileExtension?.toLowerCase();
    if (ext == '.json' || ext == '.sha256' || ext == '.sha256sum') {
      return false;
    }
    final lower = asset.name.toLowerCase();
    if (lower.startsWith('manifest') || lower.endsWith('.sha256')) return false;
    return asset.browserDownloadUrl.startsWith('http');
  }

  static const Map<DeviceOs, List<String>> _platformTokens = {
    DeviceOs.windows: ['windows', 'win64', 'win32'],
    DeviceOs.macos: ['macos', 'mac os', 'darwin', 'osx'],
    DeviceOs.linux: ['linux'],
    DeviceOs.android: ['android'],
    // No side-loadable iOS artifact exists; the resolver never matches and
    // iOS visitors get the release-page fallback (App Store later).
    DeviceOs.ios: [],
    DeviceOs.other: [],
  };

  static const Map<DeviceArch, List<String>> _archTokens = {
    DeviceArch.x64: ['x64', 'x86_64', 'amd64', 'win64', 'intel'],
    DeviceArch.arm64: ['arm64', 'aarch64', 'arm64-v8a'],
  };

  /// Every arch token merged — plain literal because const spreads over
  /// map entries aren't const-evaluable (and the strings must stay in sync
  /// with the table above; the resolver tests pin that).
  static const List<String> _allArchTokens = [
    'x64',
    'x86_64',
    'amd64',
    'win64',
    'intel',
    'arm64',
    'aarch64',
    'arm64-v8a',
  ];

  /// Resolves the download for [profile]; never returns null. On no match the
  /// fallback is the release page with [ResolvedDownload.isExactMatch] false.
  ResolvedDownload resolve({
    required GitHubRelease release,
    required DeviceProfile profile,
  }) {
    final releasesUrl = release.releasePageUrl;
    final version = release.versionLabel;

    final artifacts = release.assets
        .where(isDownloadableAsset)
        .toList(growable: false);
    if (artifacts.isEmpty || !profile.isDetected) {
      return _fallback(versionLabel: version, url: releasesUrl);
    }

    bool nameHas(String name, List<String> tokens) => tokens.any(name.contains);

    final platformTokens = _platformTokens[profile.os]!;
    final wantedArch = profile.arch;

    GitHubReleaseAsset? exact;
    GitHubReleaseAsset? universal;
    GitHubReleaseAsset? otherArch;
    for (final asset in artifacts) {
      final lower = asset.name.toLowerCase();
      final hasPlatform = nameHas(lower, platformTokens);
      if (!hasPlatform) {
        // Android fallback: canonical .apk extension on an otherwise
        // unmatched name still reads as an Android artifact.
        if (profile.os == DeviceOs.android &&
            asset.fileExtension?.toLowerCase() == '.apk') {
          final hasArch = nameHas(lower, _allArchTokens);
          final archMatch =
              wantedArch != DeviceArch.unknown &&
              nameHas(lower, _archTokens[wantedArch]!);
          if (archMatch) {
            exact ??= asset;
          } else if (!hasArch) {
            universal ??= asset;
          } else {
            otherArch ??= asset;
          }
        }
        continue;
      }
      final hasArch = nameHas(lower, _allArchTokens);
      final archMatch =
          wantedArch != DeviceArch.unknown &&
          nameHas(lower, _archTokens[wantedArch]!);
      if (archMatch) {
        exact ??= asset;
      } else if (!hasArch) {
        universal ??= asset;
      } else {
        otherArch ??= asset;
      }
    }

    final pick = exact ?? universal ?? otherArch;
    if (pick == null) return _fallback(versionLabel: version, url: releasesUrl);

    final lower = pick.name.toLowerCase();
    final archLabel = nameHas(lower, _archTokens[DeviceArch.arm64]!)
        ? 'arm64'
        : nameHas(lower, _archTokens[DeviceArch.x64]!)
        ? 'x64'
        : wantedArch == DeviceArch.arm64
        ? 'arm64'
        : wantedArch == DeviceArch.x64
        ? 'x64'
        : null;
    final osLabel = _osDisplay(profile.os);
    final qualifier = archLabel != null ? ' ($archLabel)' : '';
    return ResolvedDownload(
      label: 'Atlas $version for $osLabel$qualifier',
      downloadUrl: pick.browserDownloadUrl,
      fileName: pick.name,
      sizeBytes: pick.size,
    );
  }

  /// All downloadable assets of a release, labeled for the secondary chooser
  /// grid (manual override path). Sorted platform → name for stable order.
  List<ResolvedDownload> allDownloads(GitHubRelease release) {
    final artifacts = release.assets
        .where(isDownloadableAsset)
        .toList(growable: false);
    final labeled = artifacts.map(_describeAsset).toList();
    labeled.sort((a, b) => a.label.compareTo(b.label));
    return labeled;
  }

  ResolvedDownload _describeAsset(GitHubReleaseAsset asset) {
    final lower = asset.name.toLowerCase();
    DeviceOs? matchedOs;
    for (final entry in _platformTokens.entries) {
      if (entry.value.any(lower.contains)) {
        matchedOs = entry.key;
        break;
      }
    }
    final osLabel = matchedOs == null
        ? 'Other platform'
        : _osDisplay(matchedOs);
    final archLabel = lower.contains('universal')
        ? 'universal'
        : lower.contains('arm64-v8a')
        ? 'arm64'
        : nameContains(lower, _archTokens[DeviceArch.arm64]!)
        ? 'arm64'
        : nameContains(lower, _archTokens[DeviceArch.x64]!)
        ? 'x64'
        : null;
    final qualifier = archLabel != null ? ' ($archLabel)' : '';
    return ResolvedDownload(
      label: '$osLabel$qualifier',
      downloadUrl: asset.browserDownloadUrl,
      fileName: asset.name,
      sizeBytes: asset.size,
    );
  }

  static bool nameContains(String name, List<String> tokens) =>
      tokens.any(name.contains);

  static String _osDisplay(DeviceOs os) => switch (os) {
    DeviceOs.windows => 'Windows',
    DeviceOs.macos => 'macOS',
    DeviceOs.linux => 'Linux',
    DeviceOs.android => 'Android',
    DeviceOs.ios => 'iOS',
    DeviceOs.other => 'this device',
  };

  ResolvedDownload _fallback({
    required String versionLabel,
    required String url,
  }) => ResolvedDownload(
    label: 'Atlas $versionLabel — see all downloads',
    downloadUrl: url,
    isExactMatch: false,
  );
}

/// "84.2 MB" / "512 KB" — trust-row micro-copy on the download section.
String humanizeBytes(int bytes) {
  if (bytes <= 0) return '';
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = value >= 100 || value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
