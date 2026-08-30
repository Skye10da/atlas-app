import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/browser/presentation/screens/source_immersive_screen.dart';
import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_engine/registry/plugin_source.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/molecules/milestone_celebration_dialog.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryBooksProvider);
    final sources = ref.watch(searchableSourcesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: libraryAsync.when(
          loading: () => const AppLoading(),
          error: (err, _) => Center(child: Text('Could not load: $err')),
          data: (result) {
            final books = switch (result) {
              Success(value: final b) => b,
              Failure() => <BookEntity>[],
            };

            return ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              children: [
                // 1. Header Greeting & Streak Pill
                _buildHeader(context, books),
                const SizedBox(height: AppSpacing.lg),

                // 2. NOW READING Hero Card
                _buildNowReadingCard(context, books),
                const SizedBox(height: AppSpacing.xl),

                // 3. This Week Reading Activity Chart
                _buildActivityChart(context),
                const SizedBox(height: AppSpacing.xl),

                // 4. Shelves for your mood
                _buildMoodShelves(context, books),
                const SizedBox(height: AppSpacing.xl),

                // 5. Discover Sources
                _buildDiscoverSources(context, sources),
                const SizedBox(height: AppSpacing.xl),

                // 6. Recently Added Carousel
                _buildRecentlyAdded(context, books),
                const SizedBox(height: AppSpacing.xl),

                // 7. Stats Trio Footer
                _buildStatsTrio(context, books),
                const SizedBox(height: AppSpacing.xxl),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<BookEntity> books) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final now = DateTime.now();
    final dayName = _weekdayName(now.weekday);
    final timeOfDay = now.hour < 12
        ? 'morning'
        : now.hour < 17
        ? 'afternoon'
        : 'evening';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$dayName $timeOfDay',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Welcome back, Reader',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // Streak Pill
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
            onTap: () => MilestoneCelebrationDialog.show(
              context,
              milestone: MilestoneType.streakSevenDays,
              customMessage: '7-day reading streak maintained! Keep up the flame.',
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 18,
                    color: colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '12',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNowReadingCard(BuildContext context, List<BookEntity> books) {
    final nowReading = books.isNotEmpty
        ? books.firstWhere(
            (b) => (b.progress ?? 0) > 0,
            orElse: () => books.first,
          )
        : null;

    if (nowReading == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            'Add books to your library to start reading.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final progressPct = ((nowReading.progress ?? 0.68) * 100).toInt().clamp(
      5,
      100,
    );
    final title = nowReading.title;
    final author = nowReading.author ?? 'Kindhearted Bee';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: NOW READING + Circular Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'NOW READING',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              // Circular progress ring
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: progressPct / 100,
                      strokeWidth: 3.5,
                      backgroundColor: Colors.white12,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$progressPct%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Middle Content: Cover + Title/Author + Quote
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 104,
                  child: BookCover(
                    coverPath: nowReading.coverPath,
                    width: 72,
                    height: 104,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      author,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '"Strength is not given. It is carved from everything that tried to break you."',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12.5,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Bottom Action: Continue Reading Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A1A2E),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                context.push('/reader/${nowReading.id}');
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_stories_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Continue reading',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChart(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const heights = [0.4, 0.6, 0.3, 1.0, 0.5, 0.2, 0.2];
    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 6);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This week',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '9 chapters',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 76,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final isToday = index == todayIndex;
                final barHeight = (44.0 * heights[index]).clamp(8.0, 44.0);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: isToday
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      days[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isToday
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodShelves(BuildContext context, List<BookEntity> books) {
    const moodCategories = [
      (
        'Wuxia',
        '18 books',
        Color(0xFFFDD8D8),
        Color(0xFFC2410C),
        Icons.local_fire_department_outlined,
      ),
      (
        'Romance',
        '9 books',
        Color(0xFFE8D8FD),
        Color(0xFF6B21A8),
        Icons.favorite_border_rounded,
      ),
      (
        'Sci-fi',
        '14 books',
        Color(0xFFD8ECFD),
        Color(0xFF0369A1),
        Icons.rocket_launch_outlined,
      ),
      (
        'Fantasy',
        '24 books',
        Color(0xFFD8FDE8),
        Color(0xFF15803D),
        Icons.auto_fix_high_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shelves for your mood',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.smMd),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: moodCategories.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.smMd),
            itemBuilder: (context, index) {
              final cat = moodCategories[index];
              return Container(
                width: 130,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cat.$3,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(cat.$5, size: 20, color: cat.$4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.$1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: cat.$4,
                          ),
                        ),
                        Text(
                          cat.$2,
                          style: TextStyle(
                            fontSize: 11,
                            color: cat.$4.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoverSources(
    BuildContext context,
    List<SearchableSource> sources,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Discover novel sources',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${sources.length} sources',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.smMd),
        for (final source in sources.take(4)) ...[
          _SourceCard(source: source),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildRecentlyAdded(BuildContext context, List<BookEntity> books) {
    final recent = books.take(6).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recently added',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/library'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.smMd),
            itemBuilder: (context, index) {
              final b = recent[index];
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  if (b.isNovel) {
                    context.push('/novel/${b.id}');
                  } else {
                    context.push('/book/${b.id}');
                  }
                },
                child: SizedBox(
                  width: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BookCover(
                      coverPath: b.coverPath,
                      width: 96,
                      height: 140,
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

  Widget _buildStatsTrio(BuildContext context, List<BookEntity> books) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalBooks = books.length;
    final totalChapters = books.fold<int>(
      0,
      (sum, b) => sum + b.totalChapters,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(
            count: '${totalBooks > 0 ? totalBooks : 78}',
            label: 'Books',
            onTap: () => MilestoneCelebrationDialog.show(
              context,
              milestone: totalBooks >= 10
                  ? MilestoneType.tenBooksFinished
                  : (totalBooks >= 5
                      ? MilestoneType.fiveBooksFinished
                      : MilestoneType.firstBookFinished),
            ),
          ),
          _StatColumn(
            count: '${totalChapters > 0 ? totalChapters : 4120}',
            label: 'Chapters read',
            onTap: () => MilestoneCelebrationDialog.show(
              context,
              milestone: totalChapters >= 1000
                  ? MilestoneType.thousandChapters
                  : MilestoneType.hundredChapters,
            ),
          ),
          _StatColumn(
            count: '96h',
            label: 'Time reading',
            onTap: () => MilestoneCelebrationDialog.show(
              context,
              milestone: MilestoneType.streakThirtyDays,
              customMessage: 'Over 96 hours of deep immersion into extraordinary worlds.',
            ),
          ),
        ],
      ),
    );
  }

  static String _weekdayName(int day) {
    return switch (day) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => 'Today',
    };
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.count,
    required this.label,
    this.onTap,
  });

  final String count;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source});

  final SearchableSource source;

  static const Map<String, String> _knownHomeUrls = {
    'Project Gutenberg': 'https://www.gutenberg.org',
    'Open Library': 'https://openlibrary.org',
    'Public Domain Library': 'https://publicdomainlibrary.org',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final isNovel = source.contentCategory == ContentCategory.novel;
    final pluginSource = source is PluginSource ? source as PluginSource : null;
    final homeUrl = pluginSource?.manifest.baseUrl ?? _knownHomeUrls[source.sourceName];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  isNovel
                      ? Icons.auto_stories_rounded
                      : Icons.local_library_rounded,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.smMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.sourceName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isNovel ? 'Web novel catalog' : 'Free books library',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Search'),
                onPressed: () {
                  context.push(
                    '/sources/${Uri.encodeComponent(source.sourceName)}',
                  );
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              if (homeUrl != null)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Browse'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SourceImmersiveScreen(
                          initialUrl: homeUrl,
                          sourceTitle: source.sourceName,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

