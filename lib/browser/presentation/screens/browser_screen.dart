import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/design_system/widgets/app_context_menu.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';
import 'package:atlas_app/reader/speech/selection_speaker.dart';
import 'package:go_router/go_router.dart';

const bool _kNovelDetectionEnabled = true;

class BrowserScreen extends HookConsumerWidget {
  const BrowserScreen({super.key, this.initialUrl});

  final String? initialUrl;

  static final ValueNotifier<bool> _constFalse = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browserRepo = ref.watch(browserRepositoryProvider);
    final engineFactory = ref.watch(browserEngineFactoryProvider);

    final tabs = useMemoized(
      () => BrowserTabsController(
        repository: browserRepo,
        engineFactory: engineFactory,
      ),
      [browserRepo, engineFactory],
    );

    final urlController = useTextEditingController();
    final findController = useTextEditingController();
    final findDebounce = useRef<Timer?>(null);
    final findMatchCount = useState(0);
    final findVisible = useState(false);

    final boundEngine = useRef<BrowserWebEngine?>(null);
    final lastRecordedUrl = useRef<String?>(null);
    final lastSyncedUrl = useRef<String?>(null);
    final selection = useState<WebSelection?>(null);
    final novelUrl = useState<String?>(null);
    final tabsTick = useState(0);

    void syncWebViewFetcher() {
      final service = WebViewFetchService.instance;
      if (tabs.hasTabs) {
        service.fetcher =
            (url, {headers, method, jsonBody, bool binary = false}) async {
              for (final tab in tabs.tabs) {
                final result = await WebViewPageFetcher(engine: tab.engine)
                    .fetchHtml(
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

    void syncUrlField() {
      final url = tabs.activeTab?.url;
      if (url == null || url == kBrowserStartPageUrl) {
        if (urlController.text.isNotEmpty) urlController.text = '';
        return;
      }
      if (urlController.text == url) return;
      urlController.text = url;
    }

    Future<void> captureBrowserSession(String url) async {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.host.isEmpty || uri.scheme == 'about') return;
      await ref.read(browserSessionRepositoryProvider).captureForOrigin(uri);
    }

    Future<void> checkForNovel(String url) async {
      if (!_kNovelDetectionEnabled) return;
      final uri = Uri.tryParse(url);
      if (uri == null) {
        if (context.mounted) novelUrl.value = null;
        return;
      }
      final adapter = ref.read(sourceRegistryProvider).resolve(uri);
      final isNovel =
          adapter != null && adapter.contentCategory == ContentCategory.novel;
      if (context.mounted) novelUrl.value = isNovel ? url : null;
    }

    void recordTitle() {
      final url = boundEngine.value?.currentUrl.value;
      final title = boundEngine.value?.currentTitle.value;
      if (url == null || url.isEmpty || url == kBrowserStartPageUrl) return;
      if (title == null || title.isEmpty) return;
      unawaited(
        ref.read(browserRepositoryProvider).recordVisit(url: url, title: title),
      );
    }

    Future<void> recordNavigation() async {
      final url = boundEngine.value?.currentUrl.value;
      if (context.mounted && url != lastSyncedUrl.value) {
        lastSyncedUrl.value = url;
        tabsTick.value++;
        syncUrlField();
      }
      if (url == null || url.isEmpty || url == kBrowserStartPageUrl) return;
      if (url == lastRecordedUrl.value) return;
      lastRecordedUrl.value = url;
      await ref
          .read(browserRepositoryProvider)
          .recordVisit(url: url, title: boundEngine.value?.currentTitle.value);
      unawaited(captureBrowserSession(url));
      if (context.mounted && _kNovelDetectionEnabled) {
        unawaited(checkForNovel(url));
      }
    }

    void bindUrlListener(BrowserWebEngine? engine) {
      if (boundEngine.value == engine) return;
      boundEngine.value?.currentUrl.removeListener(recordNavigation);
      boundEngine.value?.currentTitle.removeListener(recordTitle);
      boundEngine.value = engine;
      boundEngine.value?.currentUrl.addListener(recordNavigation);
      boundEngine.value?.currentTitle.addListener(recordTitle);
    }

    void onWebSelection(WebSelection sel) {
      if (!context.mounted) return;
      selection.value = sel;
    }

    void onTabsChanged() {
      if (context.mounted) tabsTick.value++;
      bindUrlListener(tabs.activeTab?.engine);
      syncWebViewFetcher();
      syncUrlField();
      unawaited(tabs.bindSelectionListener(onWebSelection));
      unawaited(tabs.bindDownloadListener((url, mimeType) async {
        if (!context.mounted) return;
        final isPdf =
            looksLikePdfUrl(url) ||
            (mimeType?.toLowerCase().contains('pdf') ?? false);
        if (isPdf) {
          final choice = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('PDF found'),
              content: Text(
                '$url\n\nDownload the file or import it into your library.',
              ),
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
          if (!context.mounted) return;
          if (choice == 'download') {
            try {
              final transport = HttpTransport(client: ref.read(httpClientProvider));
              final bytes = await transport.fetchBytes(Uri.parse(url));
              final directory =
                  await getDownloadsDirectory() ??
                  await getApplicationDocumentsDirectory();
              final file = File(p.join(directory.path, _pdfFileName(url)));
              await file.writeAsBytes(bytes, flush: true);
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
            }
          } else if (choice == 'import') {
            try {
              final transport = HttpTransport(client: ref.read(httpClientProvider));
              final bytes = await transport.fetchBytes(Uri.parse(url));
              final result = await ref
                  .read(pdfImportServiceProvider)
                  .importBytes(bytes, _pdfFileName(url));
              if (!context.mounted) return;
              if (result is Success<String>) {
                context.go('/book/${result.value}');
              } else if (result is Failure<String>) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Import failed: ${result.error}')),
                );
              }
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
            }
          }
          return;
        }

        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Import this ebook?'),
            content: Text(
              '$url\n\nAtlas will grab the ebook and add it to your library.',
            ),
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
        if (ok == true && context.mounted) {
          await captureBrowserSession(url);
          if (!context.mounted) return;
          final webViewService = WebViewFetchService.instance;
          final previousFetcher = webViewService.fetcher;
          final activeEngine = tabs.activeTab?.engine;
          if (activeEngine != null) {
            webViewService.fetcher = WebViewPageFetcher(
              engine: activeEngine,
            ).fetchHtml;
          }

          try {
            final engine = ref.read(contentAcquisitionEngineProvider);
            final outcome = await showImportUrlSheet(
              context,
              title: 'Add to Library',
              initialUrl: url,
              skipInputStage: true,
              onImport: (bytes, fileName, sheetUrl, onProgress) =>
                  engine.importAndSave(url, onProgress: onProgress),
            );
            if (outcome == null || !context.mounted) return;
            final route = outcome.category == ContentCategory.novel
                ? '/novel/${outcome.bookId}'
                : '/book/${outcome.bookId}';
            context.go(route);
          } finally {
            webViewService.fetcher = previousFetcher;
          }
        }
      }));
      if (selection.value != null || novelUrl.value != null) {
        selection.value = null;
        novelUrl.value = null;
      }
    }

    void openUrl(String url) {
      final existingIndex = tabs.tabs.indexWhere((t) => t.url == url);
      if (existingIndex >= 0) {
        tabs.activate(existingIndex);
      } else {
        tabs.addTab(url: url);
      }
    }

    useEffect(() {
      if (initialUrl != null) {
        tabs.addTab(url: initialUrl);
      } else {
        tabs.restore();
      }
      tabs.addListener(onTabsChanged);
      onTabsChanged();
      syncWebViewFetcher();

      return () {
        WebViewFetchService.instance.fetcher = null;
        findDebounce.value?.cancel();
        bindUrlListener(null);
        tabs.removeListener(onTabsChanged);
        tabs.dispose();
      };
    }, const []);

    useEffect(() {
      if (initialUrl != null) {
        openUrl(initialUrl!);
      }
      return null;
    }, [initialUrl]);

    void dismissSelectionMenu() {
      selection.value = null;
      tabs.activeTab?.engine.clearSelection();
    }

    Future<void> runFind() async {
      final query = findController.text.trim();
      if (query.isEmpty) {
        findMatchCount.value = 0;
        return;
      }
      final count = await tabs.activeTab?.engine.search(query) ?? 0;
      if (!context.mounted) return;
      findMatchCount.value = count;
    }

    void toggleFind() {
      findVisible.value = !findVisible.value;
      if (findVisible.value) {
        findController.clear();
        findMatchCount.value = 0;
        runFind();
      } else {
        tabs.activeTab?.engine.clearFind();
      }
    }

    void onFindChanged(String value) {
      findDebounce.value?.cancel();
      findDebounce.value = Timer(const Duration(milliseconds: 250), () {
        if (!context.mounted) return;
        runFind();
      });
    }

    void goHome() {
      final engine = tabs.activeTab?.engine;
      if (engine == null) return;
      if (selection.value != null) selection.value = null;
      if (urlController.text.isNotEmpty) urlController.text = '';
      unawaited(engine.goHome());
    }

    Future<void> toggleBookmark() async {
      final url = tabs.activeTab?.url;
      final title = tabs.activeTab?.title;
      if (url == null || url.isEmpty || url == kBrowserStartPageUrl) return;

      final repo = ref.read(browserRepositoryProvider);
      final alreadyBookmarked = (ref.read(webBookmarksProvider).value ?? const [])
          .any((b) => b.url == url);
      if (alreadyBookmarked) {
        await repo.removeBookmark(url);
        return;
      }
      final now = DateTime.now();
      await repo.addBookmark(
        BrowserBookmark(
          id: url,
          url: url,
          title: title == 'New tab' ? null : title,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    void openLibrarySheets() {
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
                  showBrowserHistorySheet(
                    context,
                    onOpenUrl: (url) {
                      tabs.activeTab?.engine.load(url);
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_rounded),
                title: const Text('Bookmarks'),
                onTap: () {
                  Navigator.pop(ctx);
                  showBrowserBookmarksSheet(
                    context,
                    onOpenUrl: (url) {
                      tabs.activeTab?.engine.load(url);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    Future<void> submitUrl(String raw) async {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return;
      FocusManager.instance.primaryFocus?.unfocus();
      final normalized = normalizeBrowserUrl(trimmed);
      final uri = Uri.tryParse(normalized);
      if (uri == null || (uri.scheme != 'about' && uri.host.isEmpty)) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not open "$trimmed".')));
        }
        return;
      }
      await tabs.activeTab?.engine.load(normalized);
    }

    Future<void> openExternally() async {
      final url = tabs.activeTab?.url;
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
      if (ok == true && context.mounted) {
        await launchUrl(uri);
      }
    }

    final cs = Theme.of(context).colorScheme;

    Widget buildErrorBanner() {
      final engine = tabs.activeTab?.engine;
      if (engine == null) return const SizedBox.shrink();
      return ValueListenableBuilder<String?>(
        valueListenable: engine.lastError,
        builder: (ctx, message, _) {
          if (message == null) return const SizedBox.shrink();
          final active = tabs.activeTab;
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

    Widget buildFindBar() {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
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
                controller: findController,
                autofocus: true,
                onChanged: onFindChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => tabs.activeTab?.engine.findNext(),
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Find on page',
                  filled: true,
                  fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.85),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusFull,
                    ),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${findMatchCount.value}',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            IconButton(
              tooltip: 'Previous match',
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              onPressed: () => tabs.activeTab?.engine.findPrevious(),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Next match',
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: () => tabs.activeTab?.engine.findNext(),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Close find',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: toggleFind,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
    }

    Widget buildTabStrip() {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
        ),
        child: ListenableBuilder(
          listenable: tabs,
          builder: (ctx, _) {
            return SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      scrollDirection: Axis.horizontal,
                      itemCount: tabs.tabs.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (ctx2, index) {
                        final tab = tabs.tabs[index];
                        return _TabChip(
                          tab: tab,
                          selected: index == tabs.activeIndex,
                          onTap: () => tabs.activate(index),
                          onClose: () => tabs.close(index),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'New tab',
                    icon: const Icon(Icons.add_rounded, size: 20),
                    onPressed: tabs.canAddTab ? () => tabs.addTab() : null,
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

    Widget buildChrome() {
      final engine = tabs.activeTab?.engine;
      final currentUrl = tabs.activeTab?.url;
      final isBookmarked =
          ref
              .watch(webBookmarksProvider)
              .value
              ?.any((b) => b.url == currentUrl) ??
          false;
      final canBookmark =
          currentUrl != null && currentUrl != kBrowserStartPageUrl;
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
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
              builder: (ctx, loading, _) => _GlassIconButton(
                tooltip: loading ? 'Stop' : 'Reload',
                icon: loading ? Icons.close_rounded : Icons.refresh_rounded,
                onPressed: () => loading ? engine?.stop() : engine?.reload(),
              ),
            ),
            _GlassIconButton(
              tooltip: 'Home',
              icon: Icons.home_rounded,
              onPressed: goHome,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: urlController,
                textInputAction: TextInputAction.go,
                onSubmitted: submitUrl,
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
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _GlassIconButton(
              tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark this page',
              icon: isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              enabled: canBookmark,
              onPressed: toggleBookmark,
            ),
            _GlassIconButton(
              tooltip: 'Find on page',
              icon: Icons.manage_search_rounded,
              onPressed: toggleFind,
            ),
            _GlassIconButton(
              tooltip: 'History & bookmarks',
              icon: Icons.history_rounded,
              onPressed: openLibrarySheets,
            ),
            _GlassIconButton(
              tooltip: 'Open externally',
              icon: Icons.open_in_new_rounded,
              onPressed: openExternally,
            ),
          ],
        ),
      );
    }

    Widget buildProgress() {
      final engine = tabs.activeTab?.engine;
      if (engine == null) return const SizedBox(height: 0);
      return ListenableBuilder(
        listenable: Listenable.merge([engine.progress, engine.isLoading]),
        builder: (ctx, _) {
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

    Widget buildSelectionMenu(WebSelection sel, BrowserTab tab) {
      const menuWidth = 300.0;
      final word = sel.text.trim().length > 80
          ? sel.text.trim().substring(0, 80)
          : sel.text.trim();
      final url = tab.url ?? 'web';
      return SizedBox(
        width: menuWidth,
        child: AppContextMenu(
          anchor: Offset.zero,
          externallyPositioned: true,
          useBackdropFilter: false,
          quickActions: [
            AppContextMenuAction(
              label: 'Copy',
              icon: Icons.content_copy_rounded,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: sel.text));
                dismissSelectionMenu();
              },
            ),
            AppContextMenuAction(
              label: 'Listen',
              icon: Icons.play_circle_outline_rounded,
              onPressed: () {
                dismissSelectionMenu();
                const SelectionSpeaker().speak(
                  ref: ref,
                  bookId: 'web',
                  chapterId: url,
                  text: sel.text,
                  language: sel.language ?? 'en',
                );
              },
            ),
          ],
          listActions: [
            AppContextMenuAction(
              label: 'Look up "$word"',
              icon: Icons.translate_rounded,
              onPressed: () {
                dismissSelectionMenu();
                AppSheet.show(
                  context: context,
                  id: 'word_lookup',
                  initialHeight: 0.7,
                  child: WordLookupSheet(
                    word: word,
                    sourceSentence: sel.text,
                    sourceTitle: tab.title,
                  ),
                );
              },
            ),
            AppContextMenuAction(
              label: 'Search the web for "$word"',
              icon: Icons.search_rounded,
              onPressed: () {
                dismissSelectionMenu();
                tabs.addTab(
                  url:
                      'https://www.google.com/search?q=${Uri.encodeQueryComponent(sel.text)}',
                );
              },
            ),
            AppContextMenuAction(
              label: 'Select all',
              icon: Icons.select_all_rounded,
              onPressed: () {
                dismissSelectionMenu();
                tabs.activeTab?.engine.selectAllInPage();
              },
            ),
          ],
        ),
      );
    }

    Widget buildContent() {
      final active = tabs.activeTab;
      if (active == null) return const SizedBox.shrink();
      final child = Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            index: tabs.activeIndex,
            children: [
              for (final tab in tabs.tabs)
                KeyedSubtree(
                  key: ValueKey(tab.id),
                  child: tab.engine.buildView(),
                ),
            ],
          ),
          if (active.isOnStartPage)
            BrowserStartPage(onOpenSite: (url) => active.engine.load(url)),
        ],
      );

      final currentSel = selection.value;
      final curNovelUrl = novelUrl.value;
      final showPill =
          _kNovelDetectionEnabled && curNovelUrl != null && !active.isOnStartPage;

      return LayoutBuilder(
        builder: (ctx, constraints) {
          final area = constraints.biggest;
          const menuWidth = 300.0;
          final anchorX =
              currentSel?.center.dx.clamp(0.0, area.width) ?? area.width / 2;
          final left = (anchorX - menuWidth / 2).clamp(
            8.0,
            (area.width - menuWidth - 8).clamp(0.0, area.width),
          );
          final top = currentSel?.y1.clamp(0.0, area.height) ?? area.height;
          return Stack(
            children: [
              child,
              if (currentSel != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: dismissSelectionMenu,
                  ),
                ),
              if (showPill)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpacing.md,
                  child: Center(
                    child: _AddToLibraryPill(
                      onPressed: () async {
                        // Capture current browser cookies *before* import so
                        // CookieTransport replay has cf_clearance if the
                        // challenge was just solved in this tab.
                        final activeUrl = tabs.activeTab?.url;
                        if (activeUrl != null) {
                          await captureBrowserSession(activeUrl);
                        }
                        final webViewService = WebViewFetchService.instance;
                        final previousFetcher = webViewService.fetcher;
                        final activeEngine = tabs.activeTab?.engine;
                        if (activeEngine != null) {
                          webViewService.fetcher = WebViewPageFetcher(
                            engine: activeEngine,
                          ).fetchHtml;
                        }

                        if (!context.mounted) return;
                        final outcome = await showImportUrlSheet(
                          context,
                          title: 'Add to Library',
                          initialUrl: curNovelUrl,
                          skipInputStage: true,
                          onImport: (bytes, fileName, sheetUrl, onProgress) =>
                              ref.read(contentAcquisitionEngineProvider).importAndSave(
                                curNovelUrl,
                                onProgress: onProgress,
                              ),
                        );
                        webViewService.fetcher = previousFetcher;
                        if (outcome == null || !context.mounted) return;
                        final route = outcome.category == ContentCategory.novel
                            ? '/novel/${outcome.bookId}'
                            : '/book/${outcome.bookId}';
                        context.go(route);
                      },
                    ),
                  ),
                ),
              if (currentSel != null)
                Positioned(
                  left: left,
                  top: top,
                  child: buildSelectionMenu(currentSel, active),
                ),
            ],
          );
        },
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            buildTabStrip(),
            buildChrome(),
            if (findVisible.value) buildFindBar(),
            buildErrorBanner(),
            buildProgress(),
            Expanded(child: buildContent()),
          ],
        ),
      ),
    );
  }

  static String _pdfFileName(String url) {
    final name = p.basename(Uri.parse(url).path);
    if (name.isNotEmpty && name.toLowerCase().endsWith('.pdf')) return name;
    return 'download_${DateTime.now().millisecondsSinceEpoch}.pdf';
  }
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
              Icon(
                Icons.library_add_rounded,
                size: 18,
                color: cs.onPrimaryContainer,
              ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      tab.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
