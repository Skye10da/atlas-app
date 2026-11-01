import 'package:flutter/foundation.dart';

/// A downloadable asset attached to a GitHub release (e.g. an APK, IPA, or
/// screenshot image).
@immutable
class GitHubReleaseAsset {
  const GitHubReleaseAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
  });

  final String name;
  final String browserDownloadUrl;
  final int size;

  String? get fileExtension {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return null;
    return '.${name.substring(dot + 1).toLowerCase()}';
  }

  bool get isImage {
    const imageExtensions = <String>[
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.svg',
    ];
    final ext = fileExtension;
    return ext != null && imageExtensions.contains(ext);
  }
}

/// The latest published GitHub release for the Atlas app.
@immutable
class GitHubRelease {
  const GitHubRelease({
    required this.tagName,
    required this.name,
    required this.publishedAt,
    required this.body,
    required this.htmlUrl,
    required this.assets,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    final List<GitHubReleaseAsset> assets = <GitHubReleaseAsset>[];
    final rawAssets = json['assets'];
    if (rawAssets is List) {
      for (final raw in rawAssets) {
        if (raw is Map) {
          assets.add(
            GitHubReleaseAsset(
              name: raw['name']?.toString() ?? '',
              browserDownloadUrl: raw['browser_download_url']?.toString() ?? '',
              size: (raw['size'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }
    }
    return GitHubRelease(
      tagName: json['tag_name']?.toString() ?? 'v1.0.7',
      name: json['name']?.toString(),
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      body: json['body']?.toString(),
      htmlUrl:
          json['html_url']?.toString() ??
          'https://github.com/Skye10da/atlas-app/releases/latest',
      assets: assets,
    );
  }

  final String tagName;
  final String? name;
  final DateTime? publishedAt;
  final String? body;
  final String htmlUrl;
  final List<GitHubReleaseAsset> assets;

  /// Version without the leading `v` (e.g. `1.0.7`).
  String get versionLabel => tagName.replaceFirst(RegExp(r'^v'), '');

  /// Picks the most likely download artifact for a platform from the release's
  /// asset list, falling back to no asset when the release carries none.
  GitHubReleaseAsset? assetForPlatform(String platform) {
    if (assets.isEmpty) return null;
    final needle = switch (platform) {
      'android' => 'android',
      'ios' => 'ios',
      'desktop' => 'desktop',
      _ => platform,
    };
    for (final asset in assets) {
      final lower = asset.name.toLowerCase();
      if (lower.contains(needle)) {
        return asset;
      }
      if (platform == 'android' &&
          (lower.contains('apk') ||
              lower.contains('arm64') ||
              lower.contains('x64') ||
              lower.contains('universal'))) {
        return asset;
      }
    }
    return null;
  }

  String get releasePageUrl => htmlUrl;
}
