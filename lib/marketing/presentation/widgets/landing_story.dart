import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/marketing/domain/entities/github_release.dart';
import 'package:atlas_app/marketing/presentation/content/landing_content.dart';
import 'package:atlas_app/marketing/domain/services/release_asset_resolver.dart';

/// Alternating text/image showcase — the page's core storytelling.
///
/// Story slots consume the live release's screenshot assets positionally;
/// when the release carries no images (or fewer than the stories), each
/// section degrades to an icon-led glass visual so the page never ships
/// broken or empty.
class LandingStories extends StatelessWidget {
  const LandingStories({super.key, required this.release});

  final GitHubRelease release;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;
    final images = release.assets
        .where(ReleaseAssetResolver.isDownloadableAsset)
        .where((a) => a.isImage)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  'Built for the way you actually read',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Four faces of Atlas — from the shelf to the spoken sentence.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (var i = 0; i < landingStories.length; i++) ...[
            _StorySection(
              story: landingStories[i],
              image: i < images.length ? images[i] : null,
              imageFirst: !isWide ? false : i.isOdd,
            ),
            if (i != landingStories.length - 1)
              const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }
}

class _StorySection extends StatelessWidget {
  const _StorySection({
    required this.story,
    required this.image,
    required this.imageFirst,
  });

  final LandingStory story;
  final GitHubReleaseAsset? image;
  final bool imageFirst;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          story.kicker,
          style: theme.textTheme.labelMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          story.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: theme.colorScheme.onSurface,
            height: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          story.body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        if (story.bullets.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          for (final bullet in story.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 18, color: accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      bullet,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );

    final visual = image == null
        ? _StoryIconPanel(story: story)
        : _StoryImagePanel(image: image!);

    final content = isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: imageFirst
                ? [
                    Expanded(flex: 5, child: visual),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(flex: 6, child: text),
                  ]
                : [
                    Expanded(flex: 6, child: text),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(flex: 5, child: visual),
                  ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              visual,
              const SizedBox(height: AppSpacing.lg),
              text,
            ],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: content,
    );
  }
}

class _StoryImagePanel extends StatelessWidget {
  const _StoryImagePanel({required this.image});

  final GitHubReleaseAsset image;

  @override
  Widget build(BuildContext context) {
    return GlassCapsule(
      borderRadius: 28,
      blur: 20,
      strong: true,
      child: _ImageFrame(url: image.browserDownloadUrl, label: image.name),
    );
  }
}

class _StoryIconPanel extends StatelessWidget {
  const _StoryIconPanel({required this.story});

  final LandingStory story;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return GlassCapsule(
      borderRadius: 28,
      blur: 20,
      strong: true,
      child: Container(
        // House layout rule: a filling Center must not stretch inside a
        // bounded capsule — fixed-height frame keeps the glass honest.
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.22),
              accent.withValues(alpha: 0.04),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(story.icon, size: 56, color: accent)],
        ),
      ),
    );
  }
}

/// Release images load straight from GitHub; a load failure collapses to the
/// icon panel look rather than a broken-image box.
class _ImageFrame extends StatelessWidget {
  const _ImageFrame({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 240,
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Icon(
                Icons.image_not_supported_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : child,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              _humanizeName(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "atlas-screenshot-01.png" → "Atlas screenshot 01" — asset filenames are
  /// machine identifiers, the caption is marketing copy.
  static String _humanizeName(String name) {
    var text = name;
    final dot = text.lastIndexOf('.');
    if (dot > 0) text = text.substring(0, dot);
    text = text.replaceAll(RegExp(r'[-_]+'), ' ').trim();
    if (text.isEmpty) return 'Latest release screenshot';
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }
}
