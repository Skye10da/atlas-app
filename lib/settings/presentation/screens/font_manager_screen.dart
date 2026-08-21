import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/core/theme/font_catalog_service.dart';
import 'package:atlas_app/core/theme/font_downloader.dart';
import 'package:atlas_app/settings/infrastructure/repositories/font_download_repository.dart';
import 'package:atlas_app/settings/presentation/providers/font_download_provider.dart';
import 'package:atlas_app/settings/presentation/widgets/settings_widgets.dart';

class FontManagerScreen extends ConsumerStatefulWidget {
  const FontManagerScreen({super.key});

  @override
  ConsumerState<FontManagerScreen> createState() => _FontManagerScreenState();
}

class _FontManagerScreenState extends ConsumerState<FontManagerScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  FontCatalogCategory? _categoryFilter;
  FontSort _sort = FontSort.popularity;
  final Set<String> _previewLoading = {};
  final Set<String> _previewFailed = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontState = ref.watch(fontDownloadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Font Browser'),
        actions: [
          PopupMenuButton<FontSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: FontSort.popularity, child: Text('Popularity')),
              PopupMenuItem(value: FontSort.trending, child: Text('Trending')),
              PopupMenuItem(
                value: FontSort.alphabetical,
                child: Text('A – Z'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search fonts…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

          // Category chips
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CategoryChip(
                    label: 'All',
                    selected: _categoryFilter == null,
                    onTap: () => setState(() => _categoryFilter = null),
                  ),
                  for (final cat in FontCatalogCategory.values)
                    _CategoryChip(
                      label: cat.label,
                      selected: _categoryFilter == cat,
                      onTap: () => setState(() => _categoryFilter = cat),
                    ),
                ],
              ),
            ),
          ),

          // Font list
          Expanded(
            child: _FontBrowserBody(
              query: _query,
              categoryFilter: _categoryFilter,
              sort: _sort,
              fontState: fontState,
              previewLoading: _previewLoading,
              previewFailed: _previewFailed,
              onPreviewLoaded: (family) =>
                  setState(() => _previewLoading.remove(family)),
              onPreviewFailed: (family) {
                setState(() {
                  _previewLoading.remove(family);
                  _previewFailed.add(family);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body: async catalog + sections
// ---------------------------------------------------------------------------

class _FontBrowserBody extends ConsumerWidget {
  const _FontBrowserBody({
    required this.query,
    required this.categoryFilter,
    required this.sort,
    required this.fontState,
    required this.previewLoading,
    required this.previewFailed,
    required this.onPreviewLoaded,
    required this.onPreviewFailed,
  });

  final String query;
  final FontCatalogCategory? categoryFilter;
  final FontSort sort;
  final FontDownloadState fontState;
  final Set<String> previewLoading;
  final Set<String> previewFailed;
  final ValueChanged<String> onPreviewLoaded;
  final ValueChanged<String> onPreviewFailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(fontCatalogProvider);
    final service = ref.watch(fontCatalogServiceProvider);
    // Guard against null state during hot-reload (const default edge case).
    final installedWeights = fontState.installedWeights;

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(
        child: Text('Failed to load font catalog'),
      ),
      data: (allEntries) {
        final filtered = service.filter(
          allEntries,
          query: query,
          category: categoryFilter,
          sort: sort,
        );

        // Separate popular + rest.
        final popular = filtered
            .where((e) => FontDownloadRepository.popularFamilies.contains(e.family))
            .toList();
        final rest = filtered
            .where((e) => !FontDownloadRepository.popularFamilies.contains(e.family))
            .toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No fonts found',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        const bundled = FontDownloadRepository.bundledFamilies;

        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            // Bundled section
            const SectionHeader(title: 'Bundled'),
            ...bundled.map(
              (family) => _FontTile(
                family: family,
                isBundled: true,
                isDownloaded: fontState.downloaded.contains(family),
                isDownloading: fontState.downloading.contains(family),
                hasError: fontState.errors.contains(family),
                isLoadingPreview: false,
                hasPreviewFailed: false,
                installedWeights: installedWeights[family],
                onPreviewLoaded: onPreviewLoaded,
                onPreviewFailed: onPreviewFailed,
                onDownload: null,
                onRemove: null,
              ),
            ),

            // Popular section
            if (popular.isNotEmpty) ...[
              const SectionHeader(title: 'Popular'),
              ...popular.map(
                (entry) => _FontTile(
                  family: entry.family,
                  isBundled: false,
                  isDownloaded: fontState.downloaded.contains(entry.family),
                  isDownloading: fontState.downloading.contains(entry.family),
                  hasError: fontState.errors.contains(entry.family),
                  isLoadingPreview: previewLoading.contains(entry.family),
                  hasPreviewFailed: previewFailed.contains(entry.family),
                  availableWeights: entry.weights,
                  installedWeights: installedWeights[entry.family],
                  onPreviewLoaded: onPreviewLoaded,
                  onPreviewFailed: onPreviewFailed,
                  onDownload: () => _downloadFamily(
                    ref,
                    entry.family,
                    entry.weights,
                  ),
                  onRemove: () => _removeFamily(ref, entry.family),
                ),
              ),
            ],

            // All fonts section
            if (rest.isNotEmpty) ...[
              const SectionHeader(title: 'All Fonts'),
              ...rest.map(
                (entry) => _FontTile(
                  family: entry.family,
                  isBundled: false,
                  isDownloaded: fontState.downloaded.contains(entry.family),
                  isDownloading: fontState.downloading.contains(entry.family),
                  hasError: fontState.errors.contains(entry.family),
                  isLoadingPreview: previewLoading.contains(entry.family),
                  hasPreviewFailed: previewFailed.contains(entry.family),
                  availableWeights: entry.weights,
                  installedWeights: installedWeights[entry.family],
                  onPreviewLoaded: onPreviewLoaded,
                  onPreviewFailed: onPreviewFailed,
                  onDownload: () => _downloadFamily(
                    ref,
                    entry.family,
                    entry.weights,
                  ),
                  onRemove: () => _removeFamily(ref, entry.family),
                ),
              ),
            ],

            // Cache info
            _CacheTile(fontState: fontState),
          ],
        );
      },
    );
  }

  Future<void> _downloadFamily(
    WidgetRef ref,
    String family,
    List<int> weights,
  ) async {
    final notifier = ref.read(fontDownloadProvider.notifier);
    final repo = ref.read(fontDownloadRepositoryProvider);
    notifier.markDownloading(family);
    try {
      final downloadedWeights = await FontDownloader.download(
        family,
        weights: weights,
      );
      await repo.markDownloaded(family, weights: downloadedWeights);
      notifier.markDownloaded(family, weights: downloadedWeights);
    } on Object catch (e, stack) {
      AppLogger.error('Font download failed for $family', e, stack);
      notifier.markError(family);
    }
  }

  Future<void> _removeFamily(WidgetRef ref, String family) async {
    final notifier = ref.read(fontDownloadProvider.notifier);
    await FontDownloader.remove(family);
    await ref.read(fontDownloadRepositoryProvider).removeFamily(family);
    await notifier.remove(family);
  }
}

// ---------------------------------------------------------------------------
// Font tile with lazy preview + weight info
// ---------------------------------------------------------------------------

class _FontTile extends StatefulWidget {
  const _FontTile({
    required this.family,
    required this.isBundled,
    required this.isDownloaded,
    required this.isDownloading,
    required this.hasError,
    required this.isLoadingPreview,
    required this.hasPreviewFailed,
    required this.onPreviewLoaded,
    required this.onPreviewFailed,
    required this.onDownload,
    required this.onRemove,
    this.availableWeights,
    this.installedWeights,
  });

  final String family;
  final bool isBundled;
  final bool isDownloaded;
  final bool isDownloading;
  final bool hasError;
  final bool isLoadingPreview;
  final bool hasPreviewFailed;
  final List<int>? availableWeights;
  final Set<int>? installedWeights;
  final ValueChanged<String> onPreviewLoaded;
  final ValueChanged<String> onPreviewFailed;
  final VoidCallback? onDownload;
  final VoidCallback? onRemove;

  @override
  State<_FontTile> createState() => _FontTileState();
}

class _FontTileState extends State<_FontTile> {
  bool _previewStarted = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isBundled) _maybeStartPreview();
  }

  @override
  void didUpdateWidget(covariant _FontTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.family != widget.family) {
      _previewStarted = false;
      _maybeStartPreview();
    }
  }

  void _maybeStartPreview() {
    if (_previewStarted) return;
    if (widget.isDownloaded || widget.isLoadingPreview || widget.hasPreviewFailed) {
      return;
    }
    _previewStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreview());
  }

  Future<void> _loadPreview() async {
    try {
      await FontDownloader.download(widget.family, weights: const [400]);
      if (mounted) widget.onPreviewLoaded(widget.family);
    } on Object catch (_) {
      if (mounted) widget.onPreviewFailed(widget.family);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final weightInfo = widget.installedWeights != null &&
            widget.installedWeights!.isNotEmpty
        ? '${widget.installedWeights!.length} weight${widget.installedWeights!.length > 1 ? 's' : ''}'
        : widget.isBundled
        ? 'Bundled'
        : null;

    return ListTile(
      title: Text(
        widget.family,
        style: textTheme.bodyLarge?.copyWith(
          fontFamily: widget.isDownloaded || widget.isBundled
              ? widget.family
              : null,
        ),
      ),
      subtitle: widget.hasError
          ? Text(
              'Download failed — tap to retry',
              style: textTheme.bodySmall?.copyWith(color: colors.error),
            )
          : weightInfo != null
          ? Text(
              weightInfo,
              style: textTheme.bodySmall?.copyWith(
                color: widget.isBundled
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
            )
          : null,
      trailing: widget.isBundled
          ? Icon(Icons.check_circle_outline, color: colors.primary, size: 20)
          : widget.isDownloading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : widget.isLoadingPreview
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : widget.isDownloaded
          ? IconButton(
              icon: Icon(Icons.cloud_done, color: colors.primary),
              onPressed: widget.onRemove,
              tooltip: 'Remove download',
            )
          : IconButton(
              icon: const Icon(Icons.cloud_download_outlined),
              onPressed: widget.hasPreviewFailed
                  ? () {
                      setState(() => _previewStarted = false);
                      _maybeStartPreview();
                    }
                  : widget.onDownload,
              tooltip: widget.hasPreviewFailed ? 'Retry' : 'Download font',
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category filter chip
// ---------------------------------------------------------------------------

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: colors.primaryContainer,
        labelStyle: TextStyle(
          color: selected ? colors.onPrimaryContainer : colors.onSurface,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cache info tile
// ---------------------------------------------------------------------------

class _CacheTile extends ConsumerWidget {
  const _CacheTile({required this.fontState});
  final FontDownloadState fontState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final bytesAsync = ref.watch(cachedFontSizeBytesProvider);
    final bytes = bytesAsync.valueOrNull ?? 0;
    if (bytes == 0) return const SizedBox.shrink();
    final sizeStr = bytes > 1048576
        ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
        : '${(bytes / 1024).toStringAsFixed(0)} KB';
    return ListTile(
      title: Text(
        'Clear font cache',
        style: TextStyle(color: colors.error),
      ),
      subtitle: Text('Cached fonts: $sizeStr'),
      trailing: Icon(Icons.delete_outline, color: colors.error),
      onTap: () async {
        await FontDownloader.clearAllCachedFonts();
        ref.invalidate(cachedFontSizeBytesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Font cache cleared')),
          );
        }
      },
    );
  }
}
