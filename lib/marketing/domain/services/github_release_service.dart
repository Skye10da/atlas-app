import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:atlas_app/marketing/domain/entities/github_release.dart';

/// Reads the latest GitHub release for the Atlas app. Any failure resolves to
/// `null` so callers can fall back to curated landing content.
class GitHubReleaseService {
  GitHubReleaseService({http.Client? client})
    : _client = client ?? http.Client();

  static const String owner = 'Skye10da';
  static const String repository = 'atlas-app';
  static const String apiBaseUrl = 'https://api.github.com/repos';

  final http.Client _client;

  Future<GitHubRelease?> fetchLatestRelease() async {
    try {
      final response = await _client.get(
        Uri.parse('$apiBaseUrl/$owner/$repository/releases/latest'),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return GitHubRelease.fromJson(decoded);
    } catch (_) {
      // Offline / rate-limited / malformed payload → curated fallback.
      return null;
    }
  }
}
