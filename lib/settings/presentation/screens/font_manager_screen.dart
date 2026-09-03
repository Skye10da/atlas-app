import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/core/theme/font_catalog_service.dart';
import 'package:atlas_app/core/theme/font_downloader.dart';
import 'package:atlas_app/settings/infrastructure/repositories/font_download_repository.dart';
import 'package:atlas_app/settings/presentation/providers/font_download_provider.dart';
import 'package:atlas_app/settings/presentation/widgets/settings_widgets.dart';

class FontManagerScreen extends HookConsumerWidget {
  const FontManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final query = useState('');
    final categoryFilter = useState<FontCatalogCategory?>(null);
    final sort = useState(FontSort.popularity);
    final previewLoading = useState<Set<String>>({});
    final previewFailed = useState<Set<String>>({});

    final fontState = ref.watch(fontDownloadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Font Catalog',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          PopupMenuButton<FontSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (s) => sort.value = s,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: FontSort.popularity,
                child: Text('Popularity'),
              ),
              PopupMenuItem(value: FontSort.trending, child: Text('Trending')),
              PopupMenuItem(value: FontSort.alphabetical, child: Text('A – Z')),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formContentMaxWidth,
          ),
          child: Column(
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
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search fonts…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: query.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              searchController.clear();
                              query.value = '';
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => query.value = v,
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
                        selected: categoryFilter.value == null,
                        onTap: () => categoryFilter.value = null,
                      ),
                      for (final cat in FontCatalogCategory.values)
                        _CategoryChip(
                          label: cat.label,
                          selected: categoryFilter.value == cat,
                          onTap: () => categoryFilter.value = cat,
                        ),
                    ],
                  ),
                ),
              ),

              // Font list
              Expanded(
                child: _FontBrowserBody(
                  query: query.value,
                  categoryFilter: categoryFilter.value,
                  sort: sort.value,
                  fontState: fontState,
                  previewLoading: previewLoading.value,
                  previewFailed: previewFailed.value,
                  onPreviewLoaded: (family) {
                    final next = Set<String>.from(previewLoading.value)..remove(family);
                    previewLoading.value = next;
                  },
                  onPreviewFailed: (family) {
                    final nextLoading = Set<String>.from(previewLoading.value)..remove(family);
                    final nextFailed = Set<String>.from(previewFailed.value)..add(family);
                    previewLoading.value = nextLoading;
                    previewFailed.value = nextFailed;
                  },
                ),
              ),
            ],
          ),
        ),
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
      error: (_, _) => const Center(child: Text('Failed to load font catalog')),
      data: (allEntries) {
        final filtered = service.filter(
          allEntries,
          query: query,
          category: categoryFilter,
          sort: sort,
        );

        // Separate popular + rest.
        final popular = filtered
            .where(
              (e) => FontDownloadRepository.popularFamilies.contains(e.family),
            )
            .toList();
        final rest = filtered
            .where(
              (e) => !FontDownloadRepository.popularFamilies.contains(e.family),
            )
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
                  onDownload: () =>
                      _downloadFamily(ref, entry.family, entry.weights),
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
                  onDownload: () =>
                      _downloadFamily(ref, entry.family, entry.weights),
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

class _FontTile extends HookWidget {
  const _FontTile({
    required this.family,
    required this.isBundled,
    required this.isDownloaded,
    required this.isDownloading,
    required this.hasError,
    required this.isLoadingPreview,
    required this.hasPreviewFailed,
    this.availableWeights,
    this.installedWeights,
    required this.onPreviewLoaded,
    required this.onPreviewFailed,
    required this.onDownload,
    required this.onRemove,
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
  Widget build(BuildContext context) {
    final previewStarted = useRef(false);

    Future<void> loadPreview() async {
      try {
        await FontDownloader.download(family, weights: const [400]);
        if (context.mounted) onPreviewLoaded(family);
      } on Object catch (_) {
        if (context.mounted) onPreviewFailed(family);
      }
    }

    void maybeStartPreview({bool force = false}) {
      if (force) previewStarted.value = false;
      if (previewStarted.value) return;
      if (isDownloaded || isLoadingPreview || (hasPreviewFailed && !force)) {
        return;
      }
      previewStarted.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => loadPreview());
    }

    useEffect(() {
      if (!isBundled) {
        maybeStartPreview(force: true);
      }
      return null;
    }, [family, isBundled]);

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final weightInfo =
        installedWeights != null && installedWeights!.isNotEmpty
        ? '${installedWeights!.length} weight${installedWeights!.length > 1 ? 's' : ''}'
        : isBundled
        ? 'Bundled'
        : null;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDownloaded || isBundled
              ? colors.primaryContainer.withValues(alpha: 0.6)
              : colors.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          'Aa',
          style: TextStyle(
            fontFamily: isDownloaded || isBundled
                ? family
                : null,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDownloaded || isBundled
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        family,
        style: textTheme.bodyLarge?.copyWith(
          fontFamily: isDownloaded || isBundled
              ? family
              : null,
        ),
      ),
      subtitle: hasError
          ? Text(
              'Download failed — tap to retry',
              style: textTheme.bodySmall?.copyWith(color: colors.error),
            )
          : weightInfo != null
          ? Text(
              weightInfo,
              style: textTheme.bodySmall?.copyWith(
                color: isBundled
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
            )
          : null,
      trailing: isBundled
          ? Icon(Icons.check_circle_outline, color: colors.primary, size: 20)
          : isDownloading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isLoadingPreview
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isDownloaded
          ? IconButton(
              icon: Icon(Icons.cloud_done, color: colors.primary),
              onPressed: onRemove,
              tooltip: 'Remove download',
            )
          : IconButton(
              icon: const Icon(Icons.cloud_download_outlined),
              onPressed: hasPreviewFailed
                  ? () => maybeStartPreview(force: true)
                  : onDownload,
              tooltip: hasPreviewFailed ? 'Retry' : 'Download font',
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
      title: Text('Clear font cache', style: TextStyle(color: colors.error)),
      subtitle: Text('Cached fonts: $sizeStr'),
      trailing: Icon(Icons.delete_outline, color: colors.error),
      onTap: () async {
        await FontDownloader.clearAllCachedFonts();
        ref.invalidate(cachedFontSizeBytesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Font cache cleared')));
        }
      },
    );
  }
}
