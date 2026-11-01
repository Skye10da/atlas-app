import 'package:flutter/material.dart';

import 'package:atlas_app/onboarding/domain/entities/onboarding_step.dart';

class OnboardingBullet {
  const OnboardingBullet(this.icon, this.text);

  final IconData icon;
  final String text;
}

class OnboardingSlide {
  const OnboardingSlide({
    required this.step,
    required this.icon,
    required this.title,
    required this.body,
    required this.bullets,
  });

  final OnboardingStep step;
  final IconData icon;
  final String title;
  final String body;
  final List<OnboardingBullet> bullets;
}

/// Copy for the four introduction slides. Kept apart from the widgets so the
/// wording can change without touching layout code.
const List<OnboardingSlide> kOnboardingSlides = [
  OnboardingSlide(
    step: OnboardingStep.welcome,
    icon: Icons.auto_stories_rounded,
    title: 'Welcome to Atlas',
    body:
        'Your sanctuary for stories. Read books and follow web novels in one '
        'calm, private place.',
    bullets: [
      OnboardingBullet(
        Icons.lock_outline_rounded,
        'Your library stays on this device',
      ),
      OnboardingBullet(
        Icons.cloud_off_rounded,
        'Works offline once a chapter is saved',
      ),
      OnboardingBullet(
        Icons.person_outline_rounded,
        'No sign-up, no email, no password',
      ),
    ],
  ),
  OnboardingSlide(
    step: OnboardingStep.read,
    icon: Icons.chrome_reader_mode_outlined,
    title: 'Read anything, your way',
    body: 'EPUB, PDF, text files and web novels all open in the same reader.',
    bullets: [
      OnboardingBullet(
        Icons.text_fields_rounded,
        'Tune fonts, spacing, themes and page turns',
      ),
      OnboardingBullet(
        Icons.bookmark_border_rounded,
        'Bookmarks, highlights and notes for every book',
      ),
      OnboardingBullet(
        Icons.translate_rounded,
        'Look up and save words as you read',
      ),
    ],
  ),
  OnboardingSlide(
    step: OnboardingStep.discover,
    icon: Icons.explore_outlined,
    title: 'Find your next story',
    body:
        'Browse sources, search across them, and bring anything into your '
        'library from a link or a file.',
    bullets: [
      OnboardingBullet(
        Icons.public_rounded,
        'Browse and search online sources',
      ),
      OnboardingBullet(
        Icons.link_rounded,
        'Import from a link or a local file',
      ),
      OnboardingBullet(
        Icons.notifications_none_rounded,
        'Get told when new chapters arrive',
      ),
    ],
  ),
  OnboardingSlide(
    step: OnboardingStep.companion,
    icon: Icons.psychology_alt_outlined,
    title: 'A smarter reading companion',
    body:
        'Optional extras that help you keep track of long stories. Nothing '
        'here is required.',
    bullets: [
      OnboardingBullet(
        Icons.hub_outlined,
        'Story Intelligence: characters, relationships and recaps that avoid spoilers',
      ),
      OnboardingBullet(
        Icons.key_rounded,
        'Bring your own AI provider; it stays off until you add one',
      ),
      OnboardingBullet(
        Icons.record_voice_over_outlined,
        'Listen with built-in text-to-speech',
      ),
    ],
  ),
];
