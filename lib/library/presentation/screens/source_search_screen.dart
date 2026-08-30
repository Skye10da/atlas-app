import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/design_system/atoms/book_badge.dart';
import 'package:atlas_app/core/design_system/atoms/book_cover.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/router/navigation.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';

class SourceSearchScreen extends ConsumerStatefulWidget {
  const SourceSearchScreen({super.key, required this.sourceName});

  final String sourceName;

  @override
  ConsumerState<SourceSearchScreen> createState() => _SourceSearchScreenState();
}

class _SourceSearchScreenState extends ConsumerState<SourceSearchScreen>
    with SingleTickerProviderStateMixin {
  SearchableSource? _source;
  final _searchController = TextEditingController();
  String _term = '';
  int _page = 1;
  List<SourceSearchResult> _results = [];
  SourceSearchResponse? _lastResponse;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _isImporting = false;
  late final AnimationController _searchAnimCtrl;

  @override
  void initState() {
    super.initState();
    _source = ref
        .read(searchableSourcesProvider)
        .where((s) => s.sourceName == widget.sourceName)
        .firstOrNull;
    _searchAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _searchAnimCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search({bool loadMore = false}) async {
    final term = _searchController.text.trim();
    if (term.isEmpty) return;

    setState(() {
      _term = term;
      if (!loadMore) {
        _page = 1;
        _results = [];
        _isSearching = true;
      }
      _isLoadingMore = loadMore;
    });

    final source = _source;
    if (source == null) return;

    try {
      final response = await source.search(
        SourceSearchQuery(term: term, page: _page),
      );
      if (!mounted) return;
      setState(() {
        _lastResponse = response;
        _results.addAll(response.results);
        _isLoadingMore = false;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _isSearching = false;
      });
    }
  }

  Future<void> _import(SourceSearchResult result) async {
    final source = _source;
    if (source == null) return;
    if (_isImporting) return;
    setState(() => _isImporting = true);

    try {
      final previewModel = NovelModel(
        sourceId: result.id,
        title: result.title,
        author: result.author,
        description: result.description,
        coverUrl: result.coverUrl,
        language: result.language,
        source: source.sourceName,
        sourceUrl: result.importUrl,
        category: source.contentCategory,
      );

      final outcome = await showImportUrlSheet(
        context,
        title: result.title,
        skipInputStage: true,
        previewModel: previewModel,
      );
      if (outcome == null || !mounted) return;
      final route = outcome.category == ContentCategory.novel
          ? '/novel/${outcome.bookId}'
          : '/book/${outcome.bookId}';
      context.go(route);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final source = _source;

    if (source == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => popOrGoToLibrary(context),
          ),
          title: Text(
            widget.sourceName,
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.extension_off_rounded,
                  size: 48,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Source "${widget.sourceName}" is unavailable.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'This source plugin may not be installed or enabled.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => popOrGoToLibrary(context),
                  child: const Text('Back to Library'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGoToLibrary(context),
        ),
        title: Row(
          children: [
            Text(
              source.sourceName,
              style: const TextStyle(
                fontFamily: 'Playfair Display',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const BookBadge.primary(label: 'Source', isCompact: true),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formContentMaxWidth,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search catalog on ${source.sourceName}…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _term = '';
                                _results = [];
                                _lastResponse = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
              ),
              Expanded(
                child: _results.isEmpty
                    ? _isSearching
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedBuilder(
                                    animation: _searchAnimCtrl,
                                    builder: (_, _) => SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: CustomPaint(
                                        painter: _ArcPainter(
                                          progress: _searchAnimCtrl.value,
                                          color: cs.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'Searching...',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.travel_explore_rounded,
                                    size: 56,
                                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    _term.isEmpty
                                        ? 'Search for novels across ${source.sourceName}'
                                        : 'No results found on ${source.sourceName}',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollEndNotification &&
                              !_isLoadingMore &&
                              _lastResponse?.nextPage != null &&
                              notification.metrics.pixels >=
                                  notification.metrics.maxScrollExtent - 200) {
                            _page = _lastResponse!.nextPage!;
                            _search(loadMore: true);
                          }
                          return false;
                        },
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 170,
                                childAspectRatio: 0.6,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                              ),
                          itemCount: _results.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _results.length) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final result = _results[index];
                            return _SearchResultCard(
                              result: result,
                              onTap: _isImporting ? null : () => _import(result),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.result, required this.onTap});

  final SourceSearchResult result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final disabled = onTap == null;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
                  child: BookCover(
                    coverUrl: result.coverUrl,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                result.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (result.author != null) ...[
                const SizedBox(height: 2),
                Text(
                  result.author!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const startAngle = -3.14159 / 2;
    final sweepAngle = 3.14159 * 2 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + sweepAngle * 0.8,
      sweepAngle * 0.2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}
