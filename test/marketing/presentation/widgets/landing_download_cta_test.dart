import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/marketing/domain/entities/device_profile.dart';
import 'package:atlas_app/marketing/domain/entities/github_release.dart';
import 'package:atlas_app/marketing/domain/services/download_launcher.dart';
import 'package:atlas_app/marketing/presentation/providers/landing_providers.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_download_cta.dart';

class RecordingLauncher implements DownloadLauncher {
  final List<({String url, String fileName})> launches = [];

  @override
  Future<void> launch({
    required String url,
    required String suggestedFileName,
  }) async {
    launches.add((url: url, fileName: suggestedFileName));
  }
}

void main() {
  const windowsProfile = DeviceProfile(
    os: DeviceOs.windows,
    arch: DeviceArch.x64,
    osVersion: 'Windows 11',
  );
  const release = GitHubRelease(
    tagName: 'v1.0.8',
    name: 'Atlas 1.0.8',
    publishedAt: null,
    body: null,
    htmlUrl: 'https://github.com/Skye10da/atlas-app/releases/latest',
    assets: [
      GitHubReleaseAsset(
        name: 'atlas-v1.0.8-android.apk',
        browserDownloadUrl: 'https://example.com/atlas-v1.0.8-android.apk',
        size: 50 * 1024 * 1024,
      ),
      GitHubReleaseAsset(
        name: 'atlas-v1.0.8-windows-x64.zip',
        browserDownloadUrl: 'https://example.com/atlas-v1.0.8-windows-x64.zip',
        size: 84 * 1024 * 1024,
      ),
    ],
  );

  Future<void> pumpCta(
    WidgetTester tester, {
    required DeviceProfile profile,
    RecordingLauncher? launcher,
    GitHubRelease? liveRelease,
  }) async {
    final effectiveLauncher = launcher ?? RecordingLauncher();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          latestReleaseProvider.overrideWith(
            (ref) async => liveRelease ?? release,
          ),
          deviceProfileProvider.overrideWith((ref) async => profile),
          if (launcher != null)
            downloadLauncherProvider.overrideWithValue(launcher)
          else
            downloadLauncherProvider.overrideWithValue(effectiveLauncher),
        ],
        child: const MaterialApp(home: Scaffold(body: LandingDownloadCta())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('resolved device shows the smart label and fires the launcher', (
    tester,
  ) async {
    final launcher = RecordingLauncher();
    await pumpCta(tester, profile: windowsProfile, launcher: launcher);

    expect(find.text('Atlas 1.0.8 for Windows (x64)'), findsOneWidget);
    expect(
      find.text('Detected: Windows (x64) · release 1.0.8'),
      findsOneWidget,
    );
    expect(find.textContaining('84 MB'), findsNWidgets(2));

    await tester.tap(find.text('Atlas 1.0.8 for Windows (x64)'));
    await tester.pumpAndSettle();

    expect(launcher.launches, hasLength(1));
    expect(
      launcher.launches.single.url,
      'https://example.com/atlas-v1.0.8-windows-x64.zip',
    );
    expect(launcher.launches.single.fileName, 'atlas-v1.0.8-windows-x64.zip');
  });

  testWidgets('manual grid lists every artifact and flags the detected one', (
    tester,
  ) async {
    await pumpCta(tester, profile: windowsProfile);

    expect(find.text('Android'), findsOneWidget);
    expect(find.text('Windows (x64)'), findsOneWidget);
    // The grid pill for the resolved combo carries the "your device" check.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('unmatched device (iOS) falls back to the releases page copy', (
    tester,
  ) async {
    final launcher = RecordingLauncher();
    await pumpCta(
      tester,
      profile: const DeviceProfile(
        os: DeviceOs.ios,
        arch: DeviceArch.unknown,
        osVersion: '',
      ),
      launcher: launcher,
    );

    expect(find.text('Atlas 1.0.8 — see all downloads'), findsOneWidget);
    // Grid still offers the actual artifacts.
    expect(find.text('Android'), findsOneWidget);
    expect(find.text('Windows (x64)'), findsOneWidget);
    // No check mark — nothing matched this device.
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('grid tap launches the picked artifact directly', (tester) async {
    final launcher = RecordingLauncher();
    await pumpCta(tester, profile: windowsProfile, launcher: launcher);

    await tester.tap(find.text('Android'));
    await tester.pumpAndSettle();

    expect(launcher.launches, hasLength(1));
    expect(
      launcher.launches.single.url,
      'https://example.com/atlas-v1.0.8-android.apk',
    );
    expect(launcher.launches.single.fileName, 'atlas-v1.0.8-android.apk');
  });

  testWidgets('humanized sizes render in subtitle and grid captions', (
    tester,
  ) async {
    await pumpCta(tester, profile: windowsProfile);
    // Smart-button subtitle + the grid pill caption for the resolved combo.
    expect(find.textContaining('84 MB'), findsNWidgets(2));
    expect(find.textContaining('50 MB'), findsOneWidget);
  });
}
