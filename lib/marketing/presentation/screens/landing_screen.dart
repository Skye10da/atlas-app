import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/marketing/presentation/content/landing_content.dart';
import 'package:atlas_app/marketing/presentation/providers/landing_providers.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_app_bar.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_comparison.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_download_cta.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_faq.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_features.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_footer.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_hero.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_how_it_works.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_release_notes.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_roadmap.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_social_proof.dart';
import 'package:atlas_app/marketing/presentation/widgets/landing_story.dart';

/// Public marketing landing page for Atlas.
///
/// Rendered with Flutter Web, styled with the Atlas liquid-glass design
/// system, and fed by the latest GitHub release (with curated fallbacks).
///
/// Narrative arc: promise (hero + proof strip) → how it works → capability
/// grid → storytelling → what's new → objections (comparison, FAQ) →
/// roadmap → action (smart download) → footer.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _storiesKey = GlobalKey();
  final GlobalKey _releaseKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();
  final GlobalKey _downloadKey = GlobalKey();

  void _handleNavigate(String anchor) {
    final key = switch (anchor) {
      '#features' => _featuresKey,
      '#stories' => _storiesKey,
      '#release' => _releaseKey,
      '#faq' => _faqKey,
      '#download' => _downloadKey,
      _ => null,
    };
    final context = key?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  /// Demo entry: the landing page → splash → app start (library). Only the
  /// web landing page offers this; native installs go straight to onboarding.
  void _openDemo() {
    context.go('/splash');
  }

  @override
  Widget build(BuildContext context) {
    final release =
        ref.watch(latestReleaseProvider).valueOrNull ?? fallbackGitHubRelease;
    final device = ref.watch(deviceProfileProvider);
    final profile = device.valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A12)
          : const Color(0xFFF6F3EC),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark ? const Color(0xFF0A0A12) : const Color(0xFFF6F3EC),
              isDark ? const Color(0xFF12121C) : const Color(0xFFFFFCF7),
            ],
          ),
        ),
        child: Column(
          children: [
            LandingAppBar(
              onNavigate: _handleNavigate,
              onDownload: () => _handleNavigate('#download'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  LandingHero(
                    versionLabel: release.versionLabel,
                    deviceSummary: profile?.isDetected == true
                        ? profile!.summary
                        : null,
                    onDownload: () => _handleNavigate('#download'),
                    onSeeHow: () => _handleNavigate('#features'),
                    onTryDemo: _openDemo,
                  ),
                  const LandingSocialProof(),
                  const LandingHowItWorks(),
                  KeyedSubtree(
                    key: _featuresKey,
                    child: const LandingFeatures(),
                  ),
                  KeyedSubtree(
                    key: _storiesKey,
                    child: LandingStories(release: release),
                  ),
                  KeyedSubtree(
                    key: _releaseKey,
                    child: LandingReleaseNotes(release: release),
                  ),
                  const LandingComparison(),
                  KeyedSubtree(key: _faqKey, child: const LandingFaq()),
                  const LandingRoadmap(),
                  KeyedSubtree(
                    key: _downloadKey,
                    child: const LandingDownloadCta(),
                  ),
                  LandingFooter(release: release),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
