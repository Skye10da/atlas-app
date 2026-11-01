import 'package:flutter/material.dart';

import 'package:atlas_app/marketing/domain/entities/github_release.dart';

/// Curated fallback release used while the live GitHub lookup is in flight or
/// after it fails — the landing page renders curated copy merged over this.
const GitHubRelease fallbackGitHubRelease = GitHubRelease(
  tagName: 'v1.0.7',
  name: 'Atlas 1.0.7',
  publishedAt: null,
  body:
      '## Atlas 1.0.7\n\n- Refined AI context assembly for long novels.\n- Faster library sync across sources.\n- Stability fixes for large libraries.\n\nFull notes: https://github.com/Skye10da/atlas-app/releases/latest',
  htmlUrl: 'https://github.com/Skye10da/atlas-app/releases/latest',
  assets: <GitHubReleaseAsset>[],
);

const String landingHeroHeadline = 'Read widely. Know deeply.';

const String landingHeroSubhead =
    'Atlas turns every EPUB, PDF, and web-novel feed into a deeply understood reading experience — AI chapter context, instant search, offline-first, and more.';

class LandingFeature {
  const LandingFeature({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String id;
  final String title;
  final String body;
  final IconData icon;
}

/// Curated feature set powering the landing page grid. Merged conceptually
/// with live release data (version / notes / screenshots) via the fallback.
final List<LandingFeature> landingFeatures = <LandingFeature>[
  const LandingFeature(
    id: 'ai-depth',
    title: 'AI-native depth',
    body:
        'Every chapter opens with grounded context — summaries, key threads, and an AI chat that actually knows the story.',
    icon: Icons.auto_awesome,
  ),
  const LandingFeature(
    id: 'source-agnostic',
    title: 'Every source, one library',
    body:
        'EPUB, PDF, Gutenberg, Royal Road, Open Library and more — unified, searchable, offline-first.',
    icon: Icons.library_books,
  ),
  const LandingFeature(
    id: 'reader-first',
    title: 'Reader-first',
    body:
        'Typography, themes, offline reading, bookmarks and highlights tuned for long-form.',
    icon: Icons.bookmark,
  ),
  const LandingFeature(
    id: 'discovery',
    title: 'Discovery that learns',
    body:
        'Reading analytics and trending sources shaped by your own reading habits.',
    icon: Icons.explore,
  ),
  const LandingFeature(
    id: 'listen',
    title: 'Listen anywhere',
    body: 'Read aloud with natural narration — your library, in your ears.',
    icon: Icons.volume_up,
  ),
  const LandingFeature(
    id: 'private',
    title: 'Private by design',
    body: 'Local-first storage keeps your reading life on your device.',
    icon: Icons.shield,
  ),
];

/// One story section: kicker + headline + body, optionally backed by a
/// screenshot asset from the live release (positionally matched by the
/// widget when the release carries images).
class LandingStory {
  const LandingStory({
    required this.id,
    required this.kicker,
    required this.title,
    required this.body,
    required this.icon,
    this.bullets = const <String>[],
  });

  final String id;
  final String kicker;
  final String title;
  final String body;
  final IconData icon;
  final List<String> bullets;
}

/// Alternating text/image showcase — the page's core storytelling.
final List<LandingStory> landingStories = <LandingStory>[
  const LandingStory(
    id: 'one-shelf',
    kicker: 'Every source, one shelf',
    title: 'Your whole reading life in one place',
    body:
        'Import EPUBs and PDFs, pull serials straight from Royal Road and other portals, and browse Project Gutenberg — Atlas keeps them all on one searchable, offline-first shelf.',
    icon: Icons.library_books,
    bullets: <String>[
      'Instant search across every title and author',
      'Exact resume — down to the sentence you left off',
      'Grid, list, and compact shelf layouts',
    ],
  ),
  const LandingStory(
    id: 'ai-knows',
    kicker: 'AI that knows the story',
    title: 'Chapter context that survives long books',
    body:
        'Atlas assembles grounded context for every chapter — who is who, what just happened, and where this is going — then lets you ask about any thread while you read.',
    icon: Icons.auto_awesome,
    bullets: <String>[
      'OpenAI, Anthropic, Gemini, DeepSeek, Groq — your keys',
      'Translation pipelines with glossary memory',
      'Works offline too: local-first by design',
    ],
  ),
  const LandingStory(
    id: 'litrpg',
    kicker: 'Made for progression fantasy',
    title: 'LitRPG status windows, rendered like the app burned them in',
    body:
        'Atlas detects stat blocks, skill notifications, and system cards inside the prose and renders them as interactive windows — no breaking your scroll, no losing your selection.',
    icon: Icons.sports_esports,
    bullets: <String>[
      'Interactive block cards across GameLit scenes',
      'Dialogue-aware italics and quote styling',
      'Perfect for Royal Road and Kindle-Vella-style serials',
    ],
  ),
  const LandingStory(
    id: 'narration',
    kicker: 'Read with your ears',
    title: 'Karaoke narration that tracks the sentence',
    body:
        'Sentence-level highlighting follows the voice, the view auto-scrolls along, and the floating mini-player keeps speed and pitch within thumb\'s reach.',
    icon: Icons.headphones,
    bullets: <String>[
      '0.5×–3× playback, per-sentence resume',
      'Auto-scroll sync with the spoken sentence',
      'Background audio service with lock-screen controls',
    ],
  ),
];

class LandingStep {
  const LandingStep({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;
}

/// Three-step "how it works" ribbon under the hero.
const List<LandingStep> landingHowItWorks = <LandingStep>[
  LandingStep(
    title: 'Import your sources',
    body: 'Books, feeds, portals — EPUB, PDF, TXT, Markdown, or a URL.',
    icon: Icons.download_for_offline,
  ),
  LandingStep(
    title: 'Read & learn',
    body: 'Typography, themes, AI context, and highlights tuned for long-form.',
    icon: Icons.auto_stories,
  ),
  LandingStep(
    title: 'Keep everything',
    body: 'Local-first storage; export to TXT, EPUB, or clean printables.',
    icon: Icons.inventory_2,
  ),
];

/// One row of the Atlas-vs-alternatives table. Cell convention: `true` = has
/// it, `false` = does not, `null` = partial/varies.
class LandingComparisonRow {
  const LandingComparisonRow({
    required this.capability,
    required this.atlas,
    required this.epubReaders,
    required this.cloudApps,
  });

  final String capability;
  final bool? atlas;
  final bool? epubReaders;
  final bool? cloudApps;
}

const List<LandingComparisonRow> landingComparison = <LandingComparisonRow>[
  LandingComparisonRow(
    capability: 'Offline-first library',
    atlas: true,
    epubReaders: true,
    cloudApps: false,
  ),
  LandingComparisonRow(
    capability: 'Books + web serials',
    atlas: true,
    epubReaders: false,
    cloudApps: null,
  ),
  LandingComparisonRow(
    capability: 'AI chapter context & chat',
    atlas: true,
    epubReaders: false,
    cloudApps: null,
  ),
  LandingComparisonRow(
    capability: 'Translation with glossary memory',
    atlas: true,
    epubReaders: false,
    cloudApps: false,
  ),
  LandingComparisonRow(
    capability: 'Sentence-tracked narration',
    atlas: true,
    epubReaders: null,
    cloudApps: null,
  ),
  LandingComparisonRow(
    capability: 'Your data stays on your device',
    atlas: true,
    epubReaders: true,
    cloudApps: false,
  ),
];

class LandingFaqEntry {
  const LandingFaqEntry({required this.question, required this.answer});

  final String question;
  final String answer;
}

const List<LandingFaqEntry> landingFaq = <LandingFaqEntry>[
  LandingFaqEntry(
    question: 'Where do I download Atlas?',
    answer:
        'Right here. The download section detects your device and hands you the correct build straight from the latest GitHub release — Windows, macOS, Linux, and Android. The download page below also lists every artifact manually.',
  ),
  LandingFaqEntry(
    question: 'Do I need an account?',
    answer:
        'No. Atlas is a local application: install it and start reading. There is no sign-up, no telemetry gate, and no sync requirement.',
  ),
  LandingFaqEntry(
    question: 'Where is my reading data kept?',
    answer:
        'On your device. Your library, notes, highlights, and AI keys live in local storage — nothing is uploaded unless you turn sync features on yourself.',
  ),
  LandingFaqEntry(
    question: 'Is AI usage extra?',
    answer:
        'Atlas ships the engines, you supply the keys. Bring keys from OpenAI, Anthropic, Google Gemini, DeepSeek, or Groq — or run no AI at all; the reader is fully functional without it.',
  ),
  LandingFaqEntry(
    question: 'Can I translate web novels?',
    answer:
        'Yes. Atlas integrates WTR and AI translation pipelines with glossary memory for consistent names and cultivation terms even across long series.',
  ),
  LandingFaqEntry(
    question: 'Is there a web (browser) version of the reader itself?',
    answer:
        'Atlas is a native app for Windows, macOS, Linux, Android, and iOS — a native app keeps your library on-device, works fully offline, and lets the embedded browser and background scheduler do their jobs. This landing page is the only web surface.',
  ),
];

/// Near-term roadmap teasers (mirrors the README's active phases).
const List<String> landingRoadmap = <String>[
  'Cloud sync between your devices',
  'Offline neural voices on-device',
  'Dual-page PDF spread for desktops',
  'Community source extensions',
];

/// Social-proof strip facts (kept static & verifiable rather than vanity).
const List<(String, String)> landingSocialProof = <(String, String)>[
  ('MIT', 'Open source license'),
  ('100%', 'Offline-first'),
  ('738+', 'Automated tests passing'),
  ('0', 'Accounts required'),
];
