import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/marketing/domain/entities/device_profile.dart';
import 'package:atlas_app/marketing/presentation/content/landing_content.dart';
import 'package:atlas_app/marketing/presentation/providers/landing_providers.dart';
import 'package:atlas_app/marketing/presentation/screens/landing_screen.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_comparison.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_download_cta.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_faq.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_features.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_how_it_works.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_roadmap.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_social_proof.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_story.dart';

void main() {
  testWidgets(
    'landing renders the full narrative from curated fallback data and '
    'neutral (undetected) device copy',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            latestReleaseProvider.overrideWith(
              (ref) async => fallbackGitHubRelease,
            ),
            deviceProfileProvider.overrideWith(
              (ref) async => DeviceProfile.fallback,
            ),
          ],
          child: const MaterialApp(home: LandingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Hero (neutral device summary — no fake platform claim).
      expect(find.text('Read widely. Know deeply.'), findsOneWidget);
      expect(find.text('Download the app'), findsWidgets);
      expect(find.text('See how it works'), findsOneWidget);
      expect(find.text('Try the demo'), findsOneWidget);
      expect(find.text('v1.0.7 · Latest release'), findsOneWidget);
      expect(find.text('Detected: this device · release 1.0.7'), findsNothing);
      expect(
        find.text('Detected automatically — always the right build.'),
        findsNothing,
      );

      // Scroll beats: proof strip → how it works → features.
      await tester.scrollUntilVisible(
        find.byType(LandingSocialProof),
        400.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Open source license'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byType(LandingHowItWorks),
        400.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Import your sources'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byType(LandingFeatures),
        400.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('AI-native depth'), findsOneWidget);

      // Story sections degrade to icon panels without release screenshots.
      await tester.scrollUntilVisible(
        find.byType(LandingStories),
        400.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Your whole reading life in one place'), findsOneWidget);

      // Objection handling + roadmap.
      await tester.scrollUntilVisible(
        find.byType(LandingComparison),
        400.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('How Atlas compares'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byType(LandingFaq),
        400.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Do I need an account?'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byType(LandingRoadmap),
        400.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(LandingRoadmap), findsOneWidget);

      // Smart download CTA is reachable and honest about the fallback path.
      await tester.scrollUntilVisible(
        find.byType(LandingDownloadCta),
        400.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Get Atlas'), findsOneWidget);
      expect(find.text('Atlas 1.0.7 — see all downloads'), findsOneWidget);
    },
  );

  testWidgets('landing hero names the detected device', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          latestReleaseProvider.overrideWith(
            (ref) async => fallbackGitHubRelease,
          ),
          deviceProfileProvider.overrideWith(
            (ref) async => const DeviceProfile(
              os: DeviceOs.windows,
              arch: DeviceArch.x64,
              osVersion: 'Windows 11',
            ),
          ),
        ],
        child: const MaterialApp(home: LandingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LandingDownloadCta), findsNothing);
    // Hero names the resolved device on the first screenful.
    expect(
      find.text('Detected automatically — always the right build.'),
      findsOneWidget,
    );

    // Smart download CTA lives further down the list — scroll to it first
    // (ListView builds lazily, so nothing below the fold exists yet).
    await tester.scrollUntilVisible(
      find.byType(LandingDownloadCta),
      400.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(LandingDownloadCta), findsOneWidget);
  });

  testWidgets('landing hero try-the-demo entry opens the app flow', (
    tester,
  ) async {
    final splashPaths = <String>[];
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LandingScreen(),
        ),
        GoRoute(
          path: '/splash',
          builder: (context, state) {
            splashPaths.add(state.uri.path);
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          latestReleaseProvider.overrideWith(
            (ref) async => fallbackGitHubRelease,
          ),
          deviceProfileProvider.overrideWith(
            (ref) async => DeviceProfile.fallback,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // The demo entry exists on the hero and is discoverable without scrolling.
    expect(find.text('Try the demo'), findsOneWidget);
    await tester.tap(find.text('Try the demo'));
    await tester.pumpAndSettle();

    // Tapping it opens the splash screen, which continues into the library.
    expect(splashPaths, ['/splash']);
  });
}
