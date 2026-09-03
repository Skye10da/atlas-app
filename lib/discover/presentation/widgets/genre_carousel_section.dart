import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';

class GenreCarouselSection extends StatelessWidget {
  const GenreCarouselSection({super.key});

  static const _genres = [
    GenreMoodCategory(
      title: 'Wuxia',
      countLabel: 'Martial Arts & Cultivation',
      bgColor: Color(0xFF2C1814),
      accentColor: Color(0xFFFF7043),
      icon: Icons.sports_martial_arts_rounded,
      tagQuery: 'wuxia',
    ),
    GenreMoodCategory(
      title: 'Sci-Fi',
      countLabel: 'Space & Cyberpunk',
      bgColor: Color(0xFF102A43),
      accentColor: Color(0xFF38BEC9),
      icon: Icons.rocket_launch_rounded,
      tagQuery: 'sci-fi',
    ),
    GenreMoodCategory(
      title: 'Dark Fantasy',
      countLabel: 'Magic & Monsters',
      bgColor: Color(0xFF231834),
      accentColor: Color(0xFFB794F4),
      icon: Icons.auto_fix_high_rounded,
      tagQuery: 'fantasy',
    ),
    GenreMoodCategory(
      title: 'Romance',
      countLabel: 'Drama & Royalty',
      bgColor: Color(0xFF331422),
      accentColor: Color(0xFFF687B3),
      icon: Icons.favorite_rounded,
      tagQuery: 'romance',
    ),
  ];

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
              'Explore Genres',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Mood Catalogs',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.smMd),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _genres.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.smMd),
            itemBuilder: (context, index) {
              final cat = _genres[index];
              return Material(
                color: cat.bgColor,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    final query = cat.tagQuery ?? cat.title.toLowerCase();
                    context.go('/library?genre=${Uri.encodeComponent(query)}');
                  },
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(AppSpacing.smMd),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cat.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(cat.icon, size: 22, color: cat.accentColor),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: cat.accentColor,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'Explore catalog',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
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
            },
          ),
        ),
      ],
    );
  }
}
