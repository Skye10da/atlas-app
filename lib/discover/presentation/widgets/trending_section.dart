import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/presentation/widgets/trending_book_action_sheet.dart';

/// A section displaying trending/popular books from OPDS or web novel plugin sources
/// with interactive source filter pills and rank tabs for MVLEMPYR / WTR-LAB.
/// Declarative: no setState — uses hooks (flutter_hooks) per CLAUDE rules.
class TrendingSection extends HookConsumerWidget {
  const TrendingSection({
    required this.trendingBooks,
    required this.isLoading,
    this.title = '🔥 Trending Now',
    this.onRefresh,
    this.onViewAll,
    super.key,
  });

  final Map<String, List<TrendingBook>> trendingBooks;
  final bool isLoading;
  final String title;
  final VoidCallback? onRefresh;
  final VoidCallback? onViewAll;

  static const _mvRanks = ['weekly', 'monthly', 'alltime'];
  static const _wtrRanks = ['daily', 'weekly'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedSource = useState('All');
    final selectedRank = useState('weekly');

    // Build source list: "All" + unique sources
    final sourceKeys = trendingBooks.keys.toList();
    final sourceLabels = <String, String>{'All': 'All'};
    for (final sId in sourceKeys) {
      final name = trendingBooks[sId]?.firstOrNull?.sourceName ?? sId;
      sourceLabels[sId] = name;
    }

    // Filter books by selected source
    final displayBooks = <TrendingBook>[];
    if (selectedSource.value == 'All') {
      for (final list in trendingBooks.values) {
        displayBooks.addAll(list);
      }
    } else {
      displayBooks.addAll(trendingBooks[selectedSource.value] ?? []);
    }

    if (displayBooks.isEmpty && !isLoading) {
      return const SizedBox.shrink();
    }

    // Rank tabs visibility: only for MVLEMPYR / WTR-LAB
    final showMvTabs =
        selectedSource.value == 'mvlempyr' ||
        (selectedSource.value == 'All' &&
            trendingBooks.containsKey('mvlempyr'));
    final showWtrTabs =
        selectedSource.value == 'wtrlab' ||
        (selectedSource.value == 'All' && trendingBooks.containsKey('wtrlab'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'Playfair Display',
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRefresh != null)
                  TextButton(
                    onPressed: onRefresh,
                    child: const Text('Refresh'),
                  ),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('See all'),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Source Filter Pills — includes wtr/mvlempyr when installed
        if (sourceLabels.length > 1)
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: sourceLabels.entries.map((entry) {
                final isSelected = selectedSource.value == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _SourcePillFilter(
                    label: entry.value,
                    isSelected: isSelected,
                    onTap: () => selectedSource.value = entry.key,
                  ),
                );
              }).toList(),
            ),
          ),
        // Rank tabs for MVLEMPYR (weekly/monthly/alltime) and WTR-LAB (daily/weekly)
        // Visual only for now — wires to future TrendingService rank param; stays gradient.
        if (showMvTabs || showWtrTabs) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (showMvTabs)
                  ..._mvRanks.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(r),
                        selected: selectedRank.value == r,
                        onSelected: (_) => selectedRank.value = r,
                        visualDensity: VisualDensity.compact,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selectedRank.value == r
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      ),
                    ),
                  ),
                if (showWtrTabs)
                  ..._wtrRanks.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(r),
                        selected: selectedRank.value == r,
                        onSelected: (_) => selectedRank.value = r,
                        visualDensity: VisualDensity.compact,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selectedRank.value == r
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),

        // Horizontal Card Carousel — stays gradient per spec
        if (isLoading)
          const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          SizedBox(
            height: 265,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: displayBooks.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _TrendingBookCard(
                  book: displayBooks[index],
                  rank: index + 1,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SourcePillFilter extends StatelessWidget {
  const _SourcePillFilter({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primaryPurple = cs.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryPurple : cs.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendingBookCard extends StatelessWidget {
  const _TrendingBookCard({required this.book, required this.rank});

  final TrendingBook book;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final gradients = [
      const [Color(0xFF1A1A2E), Color(0xFF16213E)],
      const [Color(0xFF2D1B69), Color(0xFF11998E)],
      const [Color(0xFFC94B4B), Color(0xFF4B134F)],
      const [Color(0xFF0F0C29), Color(0xFF302B63)],
      const [Color(0xFF373B44), Color(0xFF4286F4)],
      const [Color(0xFF56AB2F), Color(0xFFA8E063)],
    ];
    final cardGrad = gradients[(rank - 1) % gradients.length];

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        showTrendingBookActionSheet(context, book);
      },
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: cardGrad,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                image: book.coverUrl != null && book.coverUrl!.isNotEmpty
                    ? DecorationImage(
                        image: ResizeImage(
                          NetworkImage(book.coverUrl!),
                          width: 280,
                        ),
                        fit: BoxFit.cover,
                        onError: (_, _) {},
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '#$rank',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (rank <= 3 ||
                      (book.popularity != null &&
                          book.popularity!.contains('Hot')))
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🔥', style: TextStyle(fontSize: 10)),
                            SizedBox(width: 2),
                            Text(
                              'Hot',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        book.sourceName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  if (book.genre != null && book.genre!.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          book.genre!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            if (book.author != null)
              Text(
                book.author!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
            if (book.popularity != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  book.popularity!,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
