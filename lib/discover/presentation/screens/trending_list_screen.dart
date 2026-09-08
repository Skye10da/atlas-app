import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/discover/presentation/providers/discover_providers.dart';
import 'package:atlas_app/discover/presentation/widgets/trending_book_action_sheet.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';

/// Dedicated screen displaying Top 20, 30, or 50 trending titles from OPDS catalogs or web novel plugins.
class TrendingListScreen extends ConsumerStatefulWidget {
  const TrendingListScreen({
    this.initialType = 'opds',
    this.initialSource,
    super.key,
  });

  final String initialType; // 'opds' or 'webnovel'
  final String? initialSource;

  @override
  ConsumerState<TrendingListScreen> createState() => _TrendingListScreenState();
}

class _TrendingListScreenState extends ConsumerState<TrendingListScreen> {
  late String _selectedType; // 'opds' or 'webnovel'
  String _selectedSource = 'All';
  int _selectedLimit = 30; // 20, 30, 50
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    if (widget.initialSource != null && widget.initialSource!.isNotEmpty) {
      _selectedSource = widget.initialSource!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(discoverDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedType == 'opds' ? 'OPDS Trending Catalog' : 'Web Novel Trending',
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh feeds',
            onPressed: () => ref.invalidate(discoverDashboardProvider),
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: AppLoading()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Could not load trending books.'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(discoverDashboardProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (result) => switch (result) {
          Failure(error: final err) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(err.userMessage),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(discoverDashboardProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          Success(value: final DiscoverDashboardData data) =>
            _buildTrendingContent(context, data),
        },
      ),
    );
  }

  Widget _buildTrendingContent(
    BuildContext context,
    DiscoverDashboardData data,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Pick appropriate map based on selected type
    final sourceMap = _selectedType == 'opds'
        ? data.opdsTrendingBooks
        : data.webNovelTrendingBooks;

    // Build source list for filter pills
    final sourceKeys = sourceMap.keys.toList();
    final sourceLabels = <String, String>{'All': 'All'};
    for (final sId in sourceKeys) {
      final name = sourceMap[sId]?.firstOrNull?.sourceName ?? sId;
      sourceLabels[sId] = name;
    }

    // Filter books by selected source
    final rawBooks = <TrendingBook>[];
    if (_selectedSource == 'All' || !sourceMap.containsKey(_selectedSource)) {
      for (final list in sourceMap.values) {
        rawBooks.addAll(list);
      }
    } else {
      rawBooks.addAll(sourceMap[_selectedSource] ?? []);
    }

    // Filter by search query if non-empty
    var filteredBooks = rawBooks;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      filteredBooks = rawBooks.where((b) {
        final t = b.title.toLowerCase();
        final a = (b.author ?? '').toLowerCase();
        final g = (b.genre ?? '').toLowerCase();
        return t.contains(q) || a.contains(q) || g.contains(q);
      }).toList();
    }

    // Apply Limit (Top 20 / 30 / 50)
    final displayBooks = filteredBooks.take(_selectedLimit).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.formContentMaxWidth,
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(discoverDashboardProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            children: [
              // 1. Type Toggle (OPDS Books vs Web Novels)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'opds',
                    label: Text('OPDS Books'),
                    icon: Icon(Icons.auto_stories_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: 'webnovel',
                    label: Text('Web Novels'),
                    icon: Icon(Icons.language_rounded, size: 18),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedType = set.first;
                    _selectedSource = 'All';
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // 2. Search & Limit Row
              Row(
                children: [
                  // Search Bar
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search trending...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Limit Selector (Top 20, 30, 50)
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedLimit,
                        borderRadius: BorderRadius.circular(12),
                        items: const [
                          DropdownMenuItem(value: 20, child: Text('Top 20')),
                          DropdownMenuItem(value: 30, child: Text('Top 30')),
                          DropdownMenuItem(value: 50, child: Text('Top 50')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedLimit = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // 3. Source Filter Chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: sourceLabels.entries.map((entry) {
                    final isSelected = _selectedSource == entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(entry.value),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedSource = entry.key);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 4. Header summary
              Text(
                'Showing ${displayBooks.length} titles (Top $_selectedLimit)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // 5. Trending Items List
              if (displayBooks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  alignment: Alignment.center,
                  child: Text(
                    'No trending books match your filter.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              else
                ...displayBooks.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final book = entry.value;
                  return _TrendingListTile(
                    book: book,
                    rank: rank,
                  );
                }),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingListTile extends StatelessWidget {
  const _TrendingListTile({
    required this.book,
    required this.rank,
  });

  final TrendingBook book;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Palette gradients for rank covers
    final gradients = [
      const [Color(0xFF1A1A2E), Color(0xFF16213E)],
      const [Color(0xFF2D1B69), Color(0xFF11998E)],
      const [Color(0xFFC94B4B), Color(0xFF4B134F)],
      const [Color(0xFF0F0C29), Color(0xFF302B63)],
      const [Color(0xFF373B44), Color(0xFF4286F4)],
      const [Color(0xFF56AB2F), Color(0xFFA8E063)],
    ];
    final cardGrad = gradients[(rank - 1) % gradients.length];

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.smMd),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showTrendingBookActionSheet(context, book),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.smMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank Badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? const Color(0xFFFFD700)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: rank <= 3
                          ? const Color(0xFF1C1B1F)
                          : colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.smMd),

              // Book Cover
              Container(
                width: 64,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: cardGrad,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  image: book.coverUrl != null && book.coverUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(book.coverUrl!),
                          fit: BoxFit.cover,
                          onError: (_, _) {},
                        )
                      : null,
                ),
                child: (book.coverUrl == null || book.coverUrl!.isEmpty)
                    ? Center(
                        child: Icon(
                          book.isOpds
                              ? Icons.menu_book_rounded
                              : Icons.auto_stories_rounded,
                          size: 24,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),

              // Title, Author, Tags & Actions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),

                    if (book.author != null && book.author!.isNotEmpty)
                      Text(
                        'by ${book.author}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 6),

                    // Badges (Source, Genre, Popularity)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            book.sourceName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (book.genre != null && book.genre!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              book.genre!,
                              style: TextStyle(
                                fontSize: 9,
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (book.popularity != null &&
                            book.popularity!.isNotEmpty)
                          Text(
                            book.popularity!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF7C3AED),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Actions: 1-Tap Import & Web Read
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(
                            Icons.bookmark_add_outlined,
                            size: 16,
                          ),
                          label: const Text(
                            'Import',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            if (book.detailUrl != null &&
                                book.detailUrl!.isNotEmpty) {
                              showImportUrlSheet(
                                context,
                                initialUrl: book.detailUrl,
                                skipInputStage: true,
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        if (book.detailUrl != null &&
                            book.detailUrl!.isNotEmpty)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(
                              Icons.public_rounded,
                              size: 14,
                            ),
                            label: const Text(
                              'Web',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              context.push(
                                '/web?url=${Uri.encodeComponent(book.detailUrl!)}',
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
