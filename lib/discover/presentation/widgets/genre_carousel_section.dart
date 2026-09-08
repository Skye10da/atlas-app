import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

class _CollectionItem {
  const _CollectionItem({
    required this.title,
    required this.key,
    required this.query,
    required this.gradientColors,
    required this.textColor,
    required this.icon,
  });

  final String title;
  final String key;
  final String query;
  final List<Color> gradientColors;
  final Color textColor;
  final IconData icon;
}

/// Curated collections / genres 2-column grid backed by real library book counts.
class GenreCarouselSection extends StatelessWidget {
  const GenreCarouselSection({
    super.key,
    this.genreBookCounts = const {},
  });

  final Map<String, int> genreBookCounts;

  static const List<_CollectionItem> _collections = [
    _CollectionItem(
      title: 'Wuxia',
      key: 'wuxia',
      query: 'wuxia',
      gradientColors: [Color(0xFFFDD8D8), Color(0xFFFBCFE8)],
      textColor: Color(0xFF9D174D),
      icon: Icons.sports_martial_arts_rounded,
    ),
    _CollectionItem(
      title: 'Romance',
      key: 'romance',
      query: 'romance',
      gradientColors: [Color(0xFFE8D8FD), Color(0xFFDDD6FE)],
      textColor: Color(0xFF5B21B6),
      icon: Icons.favorite_rounded,
    ),
    _CollectionItem(
      title: 'Sci-Fi',
      key: 'scifi',
      query: 'sci-fi',
      gradientColors: [Color(0xFFD8ECFD), Color(0xFFBFDBFE)],
      textColor: Color(0xFF1E40AF),
      icon: Icons.rocket_launch_rounded,
    ),
    _CollectionItem(
      title: 'Fantasy',
      key: 'fantasy',
      query: 'fantasy',
      gradientColors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
      textColor: Color(0xFF065F46),
      icon: Icons.auto_fix_high_rounded,
    ),
    _CollectionItem(
      title: 'Mystery',
      key: 'mystery',
      query: 'mystery',
      gradientColors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
      textColor: Color(0xFF92400E),
      icon: Icons.search_rounded,
    ),
    _CollectionItem(
      title: 'Classics',
      key: 'classic',
      query: 'classic',
      gradientColors: [Color(0xFFFEE2E2), Color(0xFFFECACA)],
      textColor: Color(0xFF991B1B),
      icon: Icons.account_balance_rounded,
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
              'Curated Collections',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.go('/library'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'All genres',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.smMd),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.45,
          ),
          itemCount: _collections.length,
          itemBuilder: (context, index) {
            final item = _collections[index];
            final count = genreBookCounts[item.key] ?? 0;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  context.go('/library?genre=${Uri.encodeComponent(item.query)}');
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: item.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item.gradientColors.last.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        item.icon,
                        size: 26,
                        color: item.textColor.withValues(alpha: 0.9),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontFamily: 'Playfair Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: item.textColor,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$count ${count == 1 ? 'book' : 'books'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: item.textColor.withValues(alpha: 0.75),
                            ),
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
      ],
    );
  }
}
