import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

class EcosystemQuickGrid extends StatelessWidget {
  const EcosystemQuickGrid({
    super.key,
    required this.dueReviewsCount,
    required this.totalBookmarksCount,
  });

  final int dueReviewsCount;
  final int totalBookmarksCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ecosystem Grid',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Quick Jump',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.smMd),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.smMd,
          mainAxisSpacing: AppSpacing.smMd,
          childAspectRatio: 1.45,
          children: [
            // 1. Smart Web Novel Explorer
            _GridTile(
              title: 'Novel Explorer',
              subtitle: 'Catalog & sources',
              icon: Icons.explore_rounded,
              badgeText: null,
              onTap: () => context.push('/sources'),
            ),
            // 2. Vocabulary & SRS Flashcards
            _GridTile(
              title: 'Vocabulary & SRS',
              subtitle: 'Spaced repetition',
              icon: Icons.school_rounded,
              badgeText: dueReviewsCount > 0 ? '$dueReviewsCount due' : null,
              badgeColor: colorScheme.error,
              onTap: () => context.push('/dictionary'),
            ),
            // 3. Saved Quotes & Highlights
            _GridTile(
              title: 'Quotes & Bookmarks',
              subtitle: totalBookmarksCount > 0 ? '$totalBookmarksCount saved' : 'Highlights gallery',
              icon: Icons.bookmark_added_rounded,
              badgeText: null,
              onTap: () => context.go('/bookmarks'),
            ),
            // 4. Library Shelves
            _GridTile(
              title: 'Library Shelf',
              subtitle: 'Downloaded & active',
              icon: Icons.local_library_rounded,
              badgeText: null,
              onTap: () => context.go('/library'),
            ),
          ],
        ),
      ],
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badgeText,
    this.badgeColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: colorScheme.primary,
                  ),
                  if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? colorScheme.primary)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (badgeColor ?? colorScheme.primary)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        badgeText!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeColor ?? colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
