import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/presentation/widgets/trending_book_action_sheet.dart';

class ForYouSection extends StatelessWidget {
  const ForYouSection({
    super.key,
    required this.recommendations,
  });

  final List<TrendingBook> recommendations;

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    // Gradient covers for recommendation cards
    final gradients = [
      const [Color(0xFF667EEA), Color(0xFF764BA2)],
      const [Color(0xFFF093FB), Color(0xFFF5576C)],
      const [Color(0xFF4FACFE), Color(0xFF00F2FE)],
      const [Color(0xFF43E97B), Color(0xFF38F9D7)],
      const [Color(0xFFFA709A), Color(0xFFFEE140)],
      const [Color(0xFF30CFD0), Color(0xFF330867)],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'For You',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1B1F),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/library'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Horizontal Scroll
        SizedBox(
          height: 275,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = recommendations[index];
              final grad = gradients[index % gradients.length];
              final matchPct = item.matchPercentage ?? (98 - index * 3);

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  showTrendingBookActionSheet(context, item);
                },
                child: SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card Cover
                      Container(
                        width: 150,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: grad,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          image: item.coverUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(item.coverUrl!),
                                  fit: BoxFit.cover,
                                  onError: (_, _) {},
                                )
                              : null,
                        ),
                        child: Stack(
                          children: [
                            // Match % Badge
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$matchPct% match',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            // Genre Tag
                            if (item.genre != null && item.genre!.isNotEmpty)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.genre!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1B1F),
                          height: 1.25,
                        ),
                      ),

                      // Author
                      if (item.author != null)
                        Text(
                          item.author!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF79747E),
                          ),
                        ),
                    ],
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

