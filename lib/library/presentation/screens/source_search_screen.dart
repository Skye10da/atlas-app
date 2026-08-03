import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/content_acquisition/services/import_service.dart';
import 'package:atlas_app/core/router/navigation.dart';
import 'package:atlas_app/library/presentation/providers/source_browser_provider.dart';
import 'package:atlas_app/library/presentation/widgets/import_progress_dialog.dart';

class SourceSearchScreen extends ConsumerStatefulWidget {
  const SourceSearchScreen({super.key, required this.sourceName});

  final String sourceName;

  @override
  ConsumerState<SourceSearchScreen> createState() => _SourceSearchScreenState();
}

class _SourceSearchScreenState extends ConsumerState<SourceSearchScreen> with SingleTickerProviderStateMixin {
  late final SearchableSource _source;
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
    _source = ref.read(searchableSourcesProvider).firstWhere(
      (s) => s.sourceName == widget.sourceName,
    );
    _searchAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
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

    final response = await _source.search(SourceSearchQuery(term: term, page: _page));
    setState(() {
      _lastResponse = response;
      _results.addAll(response.results);
      _isLoadingMore = false;
      _isSearching = false;
    });
  }

  Future<void> _import(SourceSearchResult result) async {
    // Re-entrancy guard: set this *before* the confirm dialog (not after),
    // so a fast double-tap or double-click on the card is ignored no matter
    // which `await` gap the second call lands in. Without this, two
    // concurrent imports of the same URL can both resolve to the same
    // bookId (if the acquisition engine dedupes/upserts by source URL) and
    // both end up calling `context.push('/book/$bookId')` — pushing the
    // same route twice before the first settles, which crashes the
    // Navigator with a duplicate page-key assertion.
    if (_isImporting) return;
    setState(() => _isImporting = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(result.title),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.coverUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(result.coverUrl!, height: 200, width: 320, fit: BoxFit.contain),
                  ),
                if (result.author != null) ...[
                  const SizedBox(height: 12),
                  Text('by ${result.author}', style: Theme.of(ctx).textTheme.bodyMedium),
                ],
                if (result.description != null) ...[
                  const SizedBox(height: 8),
                  Text(result.description!, style: Theme.of(ctx).textTheme.bodySmall),
                ],
                const SizedBox(height: 16),
                Text('Import from ${_source.sourceName}?',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final engine = ref.read(contentAcquisitionEngineProvider);
      final progress = ValueNotifier<double>(0);
      final importFuture = engine.importAndSave(
        result.importUrl,
        onProgress: (p) => progress.value = p,
      );

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ImportProgressDialog(
          future: importFuture.then((_) {}, onError: (_) {}),
          progress: progress,
        ),
      );

      if (!mounted) return;
      ImportOutcome? outcome;
      try {
        outcome = await importFuture;
      } on ImportRedirect catch (e) {
        if (!mounted) return;
        final shouldOpen = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(result.title),
            content: const Text('No full text available on Open Library. Open the book page in your browser?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open in Browser')),
            ],
          ),
        );
        if (shouldOpen == true && mounted) {
          // fallback: copy URL to clipboard so user can open manually
          await Clipboard.setData(ClipboardData(text: e.redirectUrl));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('URL copied: ${e.redirectUrl}')),
            );
          }
        }
        return;
      }

      if (!mounted) return;
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => popOrGoToLibrary(context),
        ),
        title: Text(_source.sourceName),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ${_source.sourceName}...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
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
                                  painter: _ArcPainter(progress: _searchAnimCtrl.value, color: theme.colorScheme.primary),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text('Searching...', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                            const SizedBox(height: 16),
                            Text(_term.isEmpty ? 'Search for books to import' : 'No results found',
                                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      )
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollEndNotification &&
                          !_isLoadingMore &&
                          _lastResponse?.nextPage != null &&
                          notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
                        _page = _lastResponse!.nextPage!;
                        _search(loadMore: true);
                      }
                      return false;
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.6,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _results.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _results.length) {
                          return const Center(child: CircularProgressIndicator());
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
    final disabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: result.coverUrl != null
                    ? Image.network(result.coverUrl!, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, _, _) => _placeholder(theme))
                    : _placeholder(theme),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              result.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (result.author != null)
              Text(
                result.author!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.auto_stories, size: 40, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
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
  bool shouldRepaint(_ArcPainter old) => old.progress != progress || old.color != color;
}