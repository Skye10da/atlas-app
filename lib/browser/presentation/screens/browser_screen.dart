import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:atlas_app/browser/domain/controllers/browser_tabs_controller.dart';
import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/engines/webview_page_fetcher.dart';
import 'package:atlas_app/browser/domain/entities/web_bookmark.dart';
import 'package:atlas_app/browser/domain/entities/web_selection.dart';
import 'package:atlas_app/browser/domain/utils/browser_url.dart';
import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/browser/presentation/widgets/browser_library_sheets.dart';
import 'package:atlas_app/browser/presentation/widgets/browser_start_page.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/content_engine/transport/http_transport.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';
import 'package:atlas_app/core/design_system/organisms/draggable_bottom_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/design_system/widgets/app_context_menu.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';
import 'package:atlas_app/reader/speech/selection_speaker.dart';
import 'package:go_router/go_router.dart';

/// Whether to run the "Add to library" novel-detection pill. Disabled for now:
/// showing the overlay above the WebView2 platform view forces per-frame
/// compositing that starves the UI isolate on heavy novel sites (mvlempyr),
/// freezing the whole window. Re-enable once the pill is rendered off-band
/// (e.g. inside the start page or as a detached flyout, never stacked on the
/// live webview).
const bool _kNovelDetectionEnabled = true;

/// Full-screen, glass-styled browser shell backed by [BrowserWebEngine].
///
/// Phase 1: multi-tab strip over an [IndexedStack] of live engines, native
/// start page, one-tap home reset and history recording on navigation.
class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key, this.initialUrl});

  /// Optional URL to load on open. When null the persisted tab strip is
  /// restored (or a fresh tab lands on the start page).
  final String? initialUrl;

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  late final BrowserTabsController _tabs;
  final _urlController = TextEditingController();
  final _findController = TextEditingController();
  Timer? _findDebounce;
  int _findMatchCount = 0;
  bool _findVisible = false;

  BrowserWebEngine? _boundEngine;
  String? _lastRecordedUrl;

  /// Last URL the address pill synced to, so [_recordNavigation] refreshes
  /// the UI on every URL change (including to/from the start page, which is
  /// never recorded as history) without re-rendering on no-op notifications.
  String? _lastSyncedUrl;
  WebSelection? _selection;
  String? _novelUrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _tabs = BrowserTabsController(
      repository: ref.read(browserRepositoryProvider),
      engineFactory: ref.read(browserEngineFactoryProvider),
    );
    if (widget.initialUrl != null) {
      _tabs.addTab(url: widget.initialUrl);
    } else {
      _tabs.restore();
    }
    _tabs.addListener(_onTabsChanged);
    _onTabsChanged();
    _syncWebViewFetcher();
    _ready = true;
  }

  @override
  void didUpdateWidget(BrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final url = widget.initialUrl;
    if (url == null || url == oldWidget.initialUrl) return;
    _openUrl(url);
  }

  /// Loads [url] into the active tab (or a new one when it isn't already open),
  /// used when the shell reuses this screen for a fresh `/web?url=` navigation.
  void _openUrl(String url) {
    final existingIndex = _tabs.tabs.indexWhere((t) => t.url == url);
    if (existingIndex >= 0) {
      _tabs.activate(existingIndex);
    } else {
      _tabs.addTab(url: url);
    }
  }

  @override
  void dispose() {
    // Drop the shared web-view fetcher before the engines are disposed, so no
    // later plugin fetch (reader chapter download, ...) routes into a torn-down
    // web view.
    WebViewFetchService.instance.fetcher = null;
    _findDebounce?.cancel();
    _bindUrlListener(null);
    _tabs.removeListener(_onTabsChanged);
    _tabs.dispose();
    _urlController.dispose();
    _findController.dispose();
    super.dispose();
  }

  /// Routes plugin fetches (imports, reader chapter downloads) through whichever
  /// live tab engine is already on the target origin. A same-origin in-page
  /// `fetch` carries the browser's cookies and TLS fingerprint and passes the
  /// Cloudflare-style bot checks that block plain HTTP, so bot-protected sites
  /// keep loading after the import dialog closes — not just during it. When no
  /// tab is on the origin the fetcher returns null and transports fall back to
  /// plain HTTP unchanged.
  void _syncWebViewFetcher() {
    final service = WebViewFetchService.instance;
    if (_tabs.hasTabs) {
      service.fetcher = (
        url, {
        headers,
        method,
        jsonBody,
        bool binary = false,
      }) async {
        for (final tab in _tabs.tabs) {
          final result = await WebViewPageFetcher(engine: tab.engine).fetchHtml(
            url,
            headers: headers,
            method: method,
            jsonBody: jsonBody,
            binary: binary,
          );
          if (result?.body != null || result?.bytes != null) return result;
        }
        return null;
      };
    } else {
      service.fetcher = null;
    }
  }

  void _onTabsChanged() {
    if (_ready && mounted) setState(() {});
    _bindUrlListener(_tabs.activeTab?.engine);
    _syncWebViewFetcher();
    _syncUrlField();
    unawaited(_tabs.bindSelectionListener(_onWebSelection));
    unawaited(_tabs.bindDownloadListener(_onDownloadRequested));
    if (_selection != null || _novelUrl != null) {
      setState(() {
        _selection = null;
        _novelUrl = null;
      });
    }
  }

  void _onWebSelection(WebSelection selection) {
    if (!mounted) return;
    setState(() => _selection = selection);
  }

  void _dismissSelectionMenu() {
    setState(() => _selection = null);
    _tabs.activeTab?.engine.clearSelection();
  }

  void _bindUrlListener(BrowserWebEngine? engine) {
    if (_boundEngine == engine) return;
    _boundEngine?.currentUrl.removeListener(_recordNavigation);
    _boundEngine?.currentTitle.removeListener(_recordTitle);
    _boundEngine = engine;
    _boundEngine?.currentUrl.addListener(_recordNavigation);
    _boundEngine?.currentTitle.addListener(_recordTitle);
  }

  Future<void> _recordNavigation() async {
    final url = _boundEngine?.currentUrl.value;
    // Refresh the chrome whenever the URL changes — including transitions to
    // and from the start page, which are never recorded as history. This
    // keeps the address pill and the start-page overlay honest on Home.
    if (mounted && url != _lastSyncedUrl) {
      _lastSyncedUrl = url;
      setState(() {});
      _syncUrlField();
    }
    if (url == null || url.isEmpty || url == kBrowserStartPageUrl) return;
    if (url == _lastRecordedUrl) return;
    _lastRecordedUrl = url;
    await ref.read(browserRepositoryProvider).recordVisit(
          url: url,
          title: _boundEngine?.currentTitle.value,
        );
    unawaited(_captureBrowserSession(url));
    if (mounted && _kNovelDetectionEnabled) {
      unawaited(_checkForNovel(url));
    }
  }

  /// Snapshots the platform cookie store for the committed page's origin so a
  /// later restart can re-seed it into the silent background web view (Cloudflare
  /// clearance and friends). Best-effort; the repository swallows platform
  /// failures.
  Future<void> _captureBrowserSession(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty || uri.scheme == 'about') return;
    await ref.read(browserSessionRepositoryProvider).captureForOrigin(uri);
  }

  /// Patches the history row once the document title actually arrives —
  /// [currentTitle] updates after [currentUrl], so recording it at
  /// navigation time ships the previous page's title.
  void _recordTitle() {
    final url = _boundEngine?.currentUrl.value;
    final title = _boundEngine?.currentTitle.value;
    if (url == null || url.isEmpty || url == kBrowserStartPageUrl) return;
    if (title == null || title.isEmpty) return;
    unawaited(
      ref.read(browserRepositoryProvider).recordVisit(url: url, title: title),
    );
  }

  Future<void> _checkForNovel(String url) async {
    if (!_kNovelDetectionEnabled) return;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) setState(() => _novelUrl = null);
      return;
    }
    final adapter = ref.read(sourceRegistryProvider).resolve(uri);
    final isNovel =
        adapter != null && adapter.contentCategory == ContentCategory.novel;
    if (mounted) setState(() => _novelUrl = isNovel ? url : null);
  }

  Future<void> _onDownloadRequested(String url, String? mimeType) async {
    if (!mounted) return;
    final isPdf =
        looksLikePdfUrl(url) ||
        (mimeType?.toLowerCase().contains('pdf') ?? false);
    if (isPdf) {
      await _handlePdf(url);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import this ebook?'),
        content: Text('$url\n\nAtlas will grab the ebook and add it to your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _importFromWeb(url);
    }
  }

  Future<void> _handlePdf(String url) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PDF found'),
        content: Text('$url\n\nDownload the file or import it into your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'download'),
            child: const Text('Download file'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'import'),
            child: const Text('Import to library'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'download':
        await _downloadPdf(url);
      case 'import':
        await _importPdfFromWeb(url);
    }
  }

  Future<void> _downloadPdf(String url) async {
    try {
      final bytes = await _fetchUrlBytes(url);
      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(p.join(directory.path, _pdfFileName(url)));
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Future<void> _importPdfFromWeb(String url) async {
    try {
      final bytes = await _fetchUrlBytes(url);
      final result = await ref
          .read(pdfImportServiceProvider)
          .importBytes(bytes, _pdfFileName(url));
      if (!mounted) return;
      if (result is Success<String>) {
        context.go('/book/${result.value}');
      } else if (result is Failure<String>) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${result.error}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  Future<List<int>> _fetchUrlBytes(String url) async {
    final transport = HttpTransport(client: ref.read(httpClientProvider));
    return transport.fetchBytes(Uri.parse(url));
  }

  static String _pdfFileName(String url) {
    final name = p.basename(Uri.parse(url).path);
    if (name.isNotEmpty && name.toLowerCase().endsWith('.pdf')) return name;
    return 'download_${DateTime.now().millisecondsSinceEpoch}.pdf';
  }

  Future<void> _importFromWeb(String url) async {
    if (!mounted) return;

    // The page is open in the live web view, so route the import's fetches
    // through it: a same-origin `fetch` carries the browser's cookies and TLS
    // fingerprint and passes Cloudflare bot checks that block plain HTTP.
    final webViewService = WebViewFetchService.instance;
    final previousFetcher = webViewService.fetcher;
    final activeEngine = _tabs.activeTab?.engine;
    if (activeEngine != null) {
      webViewService.fetcher =
          WebViewPageFetcher(engine: activeEngine).fetchHtml;
    }

    try {
      final engine = ref.read(contentAcquisitionEngineProvider);
      final outcome = await showImportUrlSheet(
        context,
        title: 'Add to Library',
        initialUrl: url,
        skipInputStage: true,
        onImport: (bytes, fileName, onProgress) =>
            engine.importAndSave(url, onProgress: onProgress),
      );
      if (outcome == null || !mounted) return;
      final route = outcome.category == ContentCategory.novel
          ? '/novel/${outcome.bookId}'
          : '/book/${outcome.bookId}';
      context.go(route);
    } finally {
      webViewService.fetcher = previousFetcher;
    }
  }

  void _syncUrlField() {
    final url = _tabs.activeTab?.url;
    if (url == null || url == kBrowserStartPageUrl) {
      if (_urlController.text.isNotEmpty) _urlController.text = '';
      return;
    }
    if (_urlController.text == url) return;
    _urlController.text = url;
  }

  Future<void> _submitUrl(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final normalized = normalizeBrowserUrl(trimmed);
    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'about' && uri.host.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open "$trimmed".')),
        );
      }
      return;
    }
    await _tabs.activeTab?.engine.load(normalized);
  }

  Future<void> _openExternally() async {
    final url = _tabs.activeTab?.url;
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || !uri.hasScheme) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open in system browser?'),
        content: Text('$url\n\nThis leaves the Atlas reader view.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await launchUrl(uri);
    }
  }

  void _toggleFind() {
    setState(() => _findVisible = !_findVisible);
    if (_findVisible) {
      _findController.clear();
      _findMatchCount = 0;
      _runFind();
    } else {
      _tabs.activeTab?.engine.clearFind();
    }
  }

  void _onFindChanged(String value) {
    _findDebounce?.cancel();
    _findDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _runFind();
    });
  }

  Future<void> _runFind() async {
    final query = _findController.text.trim();
    if (query.isEmpty) {
      setState(() => _findMatchCount = 0);
      return;
    }
    final count = await _tabs.activeTab?.engine.search(query) ?? 0;
    if (!mounted) return;
    setState(() => _findMatchCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTabStrip(cs),
            _buildChrome(cs),
            if (_findVisible) _buildFindBar(cs),
            _buildErrorBanner(),
            _buildProgress(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  /// Load-failure notice shown between the chrome and the page. Rendered as a
  /// normal [Column] child (never replacing or overlaying the live web view) so
  /// the WebView2 platform view stays mounted and keeps receiving input.
  Widget _buildErrorBanner() {
    final engine = _tabs.activeTab?.engine;
    if (engine == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<String?>(
      valueListenable: engine.lastError,
      builder: (context, message, _) {
        if (message == null) return const SizedBox.shrink();
        final active = _tabs.activeTab;
        if (active == null || active.isOnStartPage) {
          return const SizedBox.shrink();
        }
        return Material(
          color: cs.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: cs.onErrorContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onErrorContainer,
                        ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () {
                    final url = active.engine.currentUrl.value;
                    unawaited(
                      url != null && url.isNotEmpty
                          ? active.engine.load(url)
                          : active.engine.reload(),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onErrorContainer,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFindBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainer.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _findController,
              autofocus: true,
              onChanged: _onFindChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _tabs.activeTab?.engine.findNext(),
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Find on page',
                filled: true,
                fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.85),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadiusFull),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$_findMatchCount',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          IconButton(
            tooltip: 'Previous match',
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            onPressed: () => _tabs.activeTab?.engine.findPrevious(),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Next match',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => _tabs.activeTab?.engine.findNext(),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Close find',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: _toggleFind,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildTabStrip(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: ListenableBuilder(
        listenable: _tabs,
        builder: (context, _) {
          return SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.tabs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final tab = _tabs.tabs[index];
                      return _TabChip(
                        tab: tab,
                        selected: index == _tabs.activeIndex,
                        onTap: () => _tabs.activate(index),
                        onClose: () => _tabs.close(index),
                      );
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'New tab',
                  icon: const Icon(Icons.add_rounded, size: 20),
                  onPressed:
                      _tabs.canAddTab ? () => _tabs.addTab() : null,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChrome(ColorScheme cs) {
    final engine = _tabs.activeTab?.engine;
    final currentUrl = _tabs.activeTab?.url;
    final isBookmarked = ref
            .watch(webBookmarksProvider)
            .value
            ?.any((b) => b.url == currentUrl) ??
        false;
    final canBookmark = currentUrl != null && currentUrl != kBrowserStartPageUrl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainer.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          _NavIconButton(
            tooltip: 'Back',
            icon: Icons.arrow_back_rounded,
            listenable: engine?.canGoBack ?? _constFalse,
            onPressed: () => engine?.goBack(),
          ),
          _NavIconButton(
            tooltip: 'Forward',
            icon: Icons.arrow_forward_rounded,
            listenable: engine?.canGoForward ?? _constFalse,
            onPressed: () => engine?.goForward(),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: engine?.isLoading ?? _constFalse,
            builder: (context, loading, _) => _GlassIconButton(
              tooltip: loading ? 'Stop' : 'Reload',
              icon: loading ? Icons.close_rounded : Icons.refresh_rounded,
              onPressed: () => loading ? engine?.stop() : engine?.reload(),
            ),
          ),
          _GlassIconButton(
            tooltip: 'Home',
            icon: Icons.home_rounded,
            onPressed: _goHome,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _urlPill(cs)),
          const SizedBox(width: AppSpacing.sm),
          _GlassIconButton(
            tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark this page',
            icon: isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            enabled: canBookmark,
            onPressed: () => _toggleBookmark(),
          ),
          _GlassIconButton(
            tooltip: 'Find on page',
            icon: Icons.manage_search_rounded,
            onPressed: _toggleFind,
          ),
          _GlassIconButton(
            tooltip: 'History & bookmarks',
            icon: Icons.history_rounded,
            onPressed: _openLibrarySheets,
          ),
          _GlassIconButton(
            tooltip: 'Open externally',
            icon: Icons.open_in_new_rounded,
            onPressed: _openExternally,
          ),
        ],
      ),
    );
  }

  void _goHome() {
    final engine = _tabs.activeTab?.engine;
    if (engine == null) return;
    if (_selection != null) setState(() => _selection = null);
    // The pill mirrors the tab's URL; returning to the start page means there
    // is no URL, so blank it immediately rather than waiting on a navigation
    // callback to flip state.
    if (_urlController.text.isNotEmpty) _urlController.text = '';
    unawaited(engine.goHome());
  }

  Future<void> _toggleBookmark() async {
    final url = _tabs.activeTab?.url;
    final title = _tabs.activeTab?.title;
    if (url == null || url.isEmpty || url == kBrowserStartPageUrl) return;

    final repo = ref.read(browserRepositoryProvider);
    final alreadyBookmarked = (ref.read(webBookmarksProvider).value ?? const [])
        .any((b) => b.url == url);
    if (alreadyBookmarked) {
      await repo.removeBookmark(url);
      return;
    }
    final now = DateTime.now();
    await repo.addBookmark(BrowserBookmark(
      id: url,
      url: url,
      title: title == 'New tab' ? null : title,
      createdAt: now,
      updatedAt: now,
    ));
  }

  void _openLibrarySheets() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('History'),
              onTap: () {
                Navigator.pop(ctx);
                showBrowserHistorySheet(context, onOpenUrl: (url) {
                  _tabs.activeTab?.engine.load(url);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_rounded),
              title: const Text('Bookmarks'),
              onTap: () {
                Navigator.pop(ctx);
                showBrowserBookmarksSheet(context, onOpenUrl: (url) {
                  _tabs.activeTab?.engine.load(url);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _urlPill(ColorScheme cs) {
    return TextField(
      controller: _urlController,
      textInputAction: TextInputAction.go,
      onSubmitted: (value) => _submitUrl(value),
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search or enter address',
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.85),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final engine = _tabs.activeTab?.engine;
    if (engine == null) return const SizedBox(height: 0);
    return ListenableBuilder(
      listenable: Listenable.merge([engine.progress, engine.isLoading]),
      builder: (context, _) {
        final progress = engine.progress.value;
        if (!engine.isLoading.value || progress >= 1) {
          return const SizedBox(height: 0);
        }
        return LinearProgressIndicator(
          value: progress,
          minHeight: 2,
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Colors.transparent,
        );
      },
    );
  }

  Widget _buildContent() {
    final active = _tabs.activeTab;
    if (active == null) return const SizedBox.shrink();
    // Web views stay mounted even for start-page tabs, so a tile tap or an
    // address-bar submit can reach a live controller. The start page overlays
    // the (about:blank) view until the first navigation flips isOnStartPage.
    final child = Stack(
      fit: StackFit.expand,
      children: [
        IndexedStack(
          index: _tabs.activeIndex,
          children: [
            for (final tab in _tabs.tabs)
              KeyedSubtree(
                key: ValueKey(tab.id),
                child: tab.engine.buildView(),
              ),
          ],
        ),
        if (active.isOnStartPage)
          BrowserStartPage(
            onOpenSite: (url) => active.engine.load(url),
          ),
      ],
    );

    final selection = _selection;
    final novelUrl = _novelUrl;
    final showPill =
        _kNovelDetectionEnabled && novelUrl != null && !active.isOnStartPage;

    // Always return a LayoutBuilder wrapping a Stack, whether or not there's
    // a selection/pill to overlay. Selection state used to gate which root
    // widget type was returned here (bare Stack vs LayoutBuilder), and since
    // that's the widget occupying this slot in the tree, a type change on
    // every selection open/close made Flutter treat it as a totally
    // different widget: it tore down and remounted everything below,
    // including the IndexedStack of InAppWebViews — a full webview reload on
    // every long-press and every menu dismiss. Keeping the same root type
    // here means only the overlay children (added/removed below) change,
    // and the webview subtree's Elements — and their native platform
    // views — are never touched.
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        const menuWidth = 300.0;
        final anchorX =
            selection?.center.dx.clamp(0.0, area.width) ?? area.width / 2;
        final left = (anchorX - menuWidth / 2).clamp(
          8.0,
          (area.width - menuWidth - 8).clamp(0.0, area.width),
        );
        final top = selection?.y1.clamp(0.0, area.height) ?? area.height;
        return Stack(
          children: [
            child,
            if (selection != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _dismissSelectionMenu,
                ),
              ),
            if (showPill)
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.md,
                child: Center(
                  child: _AddToLibraryPill(
                    onPressed: () => _importFromWeb(novelUrl),
                  ),
                ),
              ),
            if (selection != null)
              Positioned(
                left: left,
                top: top,
                child: _buildSelectionMenu(selection, active),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSelectionMenu(WebSelection selection, BrowserTab tab) {
    const menuWidth = 300.0;
    final word = selection.text.trim().length > 80
        ? selection.text.trim().substring(0, 80)
        : selection.text.trim();
    final url = tab.url ?? 'web';
    return SizedBox(
      width: menuWidth,
      child: AppContextMenu(
        anchor: Offset.zero,
        externallyPositioned: true,
        // No backdrop blur: it forces per-frame compositing over the live
        // WebView2 platform view (the same freeze the novel pill had).
        useBackdropFilter: false,
        quickActions: [
          AppContextMenuAction(
            label: 'Copy',
            icon: Icons.content_copy_rounded,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: selection.text));
              _dismissSelectionMenu();
            },
          ),
          AppContextMenuAction(
            label: 'Listen',
            icon: Icons.play_circle_outline_rounded,
            onPressed: () {
              _dismissSelectionMenu();
              const SelectionSpeaker().speak(
                ref: ref,
                bookId: 'web',
                chapterId: url,
                text: selection.text,
                language: selection.language ?? 'en',
              );
            },
          ),
        ],
        listActions: [
          AppContextMenuAction(
            label: 'Look up "$word"',
            icon: Icons.translate_rounded,
            onPressed: () {
              _dismissSelectionMenu();
              DraggableBottomSheet.show(
                context: context,
                id: 'word_lookup',
                initialHeight: 0.7,
                child: WordLookupSheet(
                  word: word,
                  sourceSentence: selection.text,
                  sourceTitle: tab.title,
                ),
              );
            },
          ),
          AppContextMenuAction(
            label: 'Search the web for "$word"',
            icon: Icons.search_rounded,
            onPressed: () {
              _dismissSelectionMenu();
              _tabs.addTab(
                url:
                    'https://www.google.com/search?q=${Uri.encodeQueryComponent(selection.text)}',
              );
            },
          ),
          AppContextMenuAction(
            label: 'Select all',
            icon: Icons.select_all_rounded,
            onPressed: () {
              _dismissSelectionMenu();
              _tabs.activeTab?.engine.selectAllInPage();
            },
          ),
        ],
      ),
    );
  }

  static final ValueNotifier<bool> _constFalse = ValueNotifier<bool>(false);
}

class _AddToLibraryPill extends StatelessWidget {
  const _AddToLibraryPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.library_add_rounded,
                  size: 18, color: cs.onPrimaryContainer),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Add to Library',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final BrowserTab tab;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<String?>(
      valueListenable: tab.engine.currentTitle,
      builder: (context, _, _) {
        return Material(
          color: selected
              ? cs.primaryContainer
              : cs.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
            onTap: onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      tab.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                            color: selected
                                ? cs.onPrimaryContainer
                                : cs.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: selected
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.tooltip,
    required this.icon,
    required this.listenable,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final ValueListenable<bool> listenable;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, enabled, _) => _GlassIconButton(
        tooltip: tooltip,
        icon: icon,
        enabled: enabled,
        onPressed: onPressed,
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: IconButton(
          icon: Icon(icon, size: 20),
          color: cs.onSurface,
          onPressed: enabled ? onPressed : null,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}