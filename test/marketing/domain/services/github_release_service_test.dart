import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:atlas_app/marketing/domain/services/github_release_service.dart';

class _MockClient extends Mock implements http.Client {}

void main() {
  late _MockClient client;

  setUp(() {
    client = _MockClient();
  });

  final Uri releaseUri = Uri.parse(
    'https://api.github.com/repos/Skye10da/atlas-app/releases/latest',
  );
  final Map<String, String> releaseHeaders = <String, String>{
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  group('GitHubReleaseService', () {
    test('returns the latest release on a 200 response', () async {
      when(() => client.get(releaseUri, headers: releaseHeaders)).thenAnswer(
        (_) async => http.Response(
          '{"tag_name":"v1.0.7","name":"Atlas 1.0.7","body":"hi"}',
          200,
        ),
      );

      final release = await GitHubReleaseService(
        client: client,
      ).fetchLatestRelease();

      expect(release, isNotNull);
      expect(release!.tagName, 'v1.0.7');
      expect(release.versionLabel, '1.0.7');
      verify(() => client.get(releaseUri, headers: releaseHeaders)).called(1);
    });

    test('returns null on a non-200 response', () async {
      when(
        () => client.get(releaseUri, headers: releaseHeaders),
      ).thenAnswer((_) async => http.Response('Not Found', 404));

      final release = await GitHubReleaseService(
        client: client,
      ).fetchLatestRelease();

      expect(release, isNull);
      verify(() => client.get(releaseUri, headers: releaseHeaders)).called(1);
    });

    test('returns null when the lookup throws', () async {
      when(
        () => client.get(releaseUri, headers: releaseHeaders),
      ).thenThrow(Exception('offline'));

      final release = await GitHubReleaseService(
        client: client,
      ).fetchLatestRelease();

      expect(release, isNull);
    });
  });
}
