import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/updater/domain/entities/app_release.dart';
import 'package:atlas_app/updater/domain/repositories/app_update_repository.dart';
import 'package:atlas_app/updater/domain/version_policy.dart';
import 'package:atlas_app/updater/infrastructure/manifest_codec.dart';

/// GitHub repository whose Releases feed the app consumes. The slug is a
/// compile-time constant so forks can point their builds elsewhere:
/// `--dart-define=UPDATER_REPO=owner/repo`.
class GithubReleaseRepository implements AppUpdateRepository {
  GithubReleaseRepository({required http.Client client})
    : _client = client,
      repoSlug = const String.fromEnvironment(
        'UPDATER_REPO',
        defaultValue: 'Skye10da/atlas-app',
      );

  static const _apiBase = 'https://api.github.com';
  static const Map<String, String> _headers = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  final http.Client _client;
  final String repoSlug;
  final ManifestCodec _codec = const ManifestCodec();

  @override
  Future<AppRelease?> fetchLatest({
    UpdateChannel channel = UpdateChannel.stable,
  }) async {
    try {
      return channel == UpdateChannel.beta
          ? await _fetchNewestBeta()
          : await _fetchStableLatest();
    } on AppUpdateException {
      rethrow;
    } catch (e, st) {
      AppLogger.error('Updater: fetching latest release failed', e, st);
      throw AppUpdateException('Could not reach GitHub to check for updates.', e);
    }
  }

  /// Stable channel: `/releases/latest` is GitHub's own "newest non-prerelease,
  /// non-draft" endpoint. 404 means the repo has no releases yet — a
  /// legitimate "you are current", not an error.
  Future<AppRelease?> _fetchStableLatest() async {
    final response = await _client.get(
      Uri.parse('$_apiBase/repos/$repoSlug/releases/latest'),
      headers: _headers,
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AppUpdateException(
        'GitHub returned ${response.statusCode} while checking for updates.',
      );
    }
    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) return null;
    return _decodeReleaseMap(decoded);
  }

  /// Beta channel: the listing is ordered newest first, so the first
  /// non-draft entry (prerelease or stable) is the newest beta offer.
  Future<AppRelease?> _fetchNewestBeta() async {
    final response = await _client.get(
      Uri.parse('$_apiBase/repos/$repoSlug/releases?per_page=10'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw AppUpdateException(
        'GitHub returned ${response.statusCode} while checking for updates.',
      );
    }
    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! List) return null;
    for (final candidate in decoded.cast<Map<String, dynamic>>()) {
      if (candidate['draft'] == true) continue;
      final release = await _decodeReleaseMap(candidate);
      if (release != null) return release;
    }
    return null;
  }

  /// What's-new history: the release listing alone (tag, date, notes) — no
  /// per-release manifest round-trip. Drafts and non-workflow tags (no
  /// `+<build>`) are skipped; parsing failures degrade entry-by-entry.
  @override
  Future<List<AppRelease>> fetchReleaseHistory({int limit = 20}) async {
    try {
      final response = await _client.get(
        Uri.parse('$_apiBase/repos/$repoSlug/releases?per_page=$limit'),
        headers: _headers,
      );
      if (response.statusCode != 200) {
        throw AppUpdateException(
          'GitHub returned ${response.statusCode} while loading the release '
          'history.',
        );
      }
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! List) return const [];
      final releases = <AppRelease>[];
      for (final candidate in decoded.whereType<Map>()) {
        if (candidate['draft'] == true) continue;
        final tag = candidate['tag_name'];
        if (tag is! String) continue;
        final parsed = VersionPolicy.parseTag(tag);
        if (parsed.versionCode == null) continue;
        final publishedAtRaw =
            candidate['published_at'] ?? candidate['created_at'];
        final publishedAt =
            publishedAtRaw is String ? DateTime.tryParse(publishedAtRaw) : null;
        final htmlUrl = candidate['html_url'];
        releases.add(
          AppRelease(
            tag: tag,
            version: parsed.version,
            versionCode: parsed.versionCode!,
            channel: parsed.isPrerelease
                ? UpdateChannel.beta
                : UpdateChannel.stable,
            publishedAt: publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            notes: candidate['body'] is String ? candidate['body'] as String : null,
            releaseUrl: htmlUrl is String ? htmlUrl : null,
            artifacts: const {},
          ),
        );
      }
      return releases;
    } on AppUpdateException {
      rethrow;
    } catch (e, st) {
      AppLogger.error('Updater: fetching release history failed', e, st);
      throw AppUpdateException('Could not load the release history.', e);
    }
  }

  /// Release JSON → [AppRelease] with artifact URLs resolved. Requires the
  /// workflow-generated `manifest.json` asset; any breakage yields null.
  Future<AppRelease?> _decodeReleaseMap(Map releaseJson) async {
    try {
      final assets = releaseJson['assets'];
      if (assets is! List) return null;

      final manifestUrl = _codec.findManifestJson(assets);
      if (manifestUrl == null) return null;

      final manifestResponse = await _client.get(
        Uri.parse(manifestUrl),
        headers: _headers,
      );
      if (manifestResponse.statusCode != 200) return null;

      final manifestJson =
          json.decode(utf8.decode(manifestResponse.bodyBytes))
              as Map<String, dynamic>?;
      if (manifestJson == null) return null;

      final manifest = _codec.parseManifest(manifestJson);
      if (manifest == null) return null;

      final htmlUrl = releaseJson['html_url'];
      final withUrl = htmlUrl is String
          ? AppRelease(
              tag: manifest.tag,
              version: manifest.version,
              versionCode: manifest.versionCode,
              channel: manifest.channel,
              publishedAt: manifest.publishedAt,
              notes: manifest.notes,
              releaseUrl: htmlUrl,
              artifacts: manifest.artifacts,
            )
          : manifest;
      return _codec.withAssetUrls(withUrl, assets);
    } catch (e, st) {
      AppLogger.error('Updater: failed to decode release', e, st);
      return null;
    }
  }
}
