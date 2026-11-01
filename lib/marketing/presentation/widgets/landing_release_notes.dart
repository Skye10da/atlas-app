import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/marketing/domain/entities/github_release.dart';

/// Release notes section that renders the latest release body as markdown.
class LandingReleaseNotes extends StatelessWidget {
  const LandingReleaseNotes({super.key, required this.release});

  final GitHubRelease release;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = release.body;
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
          Text(
            'What\'s new',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            release.name ?? 'Atlas',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (body != null && body.trim().isNotEmpty)
            MarkdownBody(data: body, styleSheet: MarkdownStyleSheet())
          else
            Text(
              release.tagName,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
