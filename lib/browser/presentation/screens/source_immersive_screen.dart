import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'dart:async';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/engines/webview_page_fetcher.dart';
import 'package:atlas_app/browser/domain/utils/novel_page_classifier.dart';
import 'package:atlas_app/browser/infrastructure/engines/inapp_webview_engine.dart';
import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';
import 'package:atlas_app/core/content_engine/universal/origin_rules.dart';
import 'package:atlas_app/core/design_system/molecules/app_toast.dart';
import 'package:atlas_app/core/design_system/molecules/glass_surfaces.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';
import 'package:go_router/go_router.dart';

/// Full-screen immersive webview for a single source.
///
/// The webview is full-bleed: the former glass top navigation bar is removed;
/// its essential controls — back within the webview's history and close (×) —
/// survive as floating glass pills over the page (reader-pill design language),
/// backed by a floating hairline loading progress indicator and a slide-up
/// novel-detection pill.
class SourceImmersiveScreen extends HookConsumerWidget {
  const SourceImmersiveScreen({
    super.key,
    required this.initialUrl,
    this.sourceTitle,
  });

  final String initialUrl;
  final String? sourceTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = useMemoized<BrowserWebEngine>(
      () => InappWebviewEngine(initialUrl: initialUrl),
      [initialUrl],
    );

    final novelUrl = useState<String?>(null);

    /// The URL of the last *committed* document. The engine flips
    /// [currentUrl] the moment a navigation *starts* — before the new page's
    /// DOM exists — so the old code could show the pill for a page that was
    /// still the previous document underneath, and tapping Import then
    /// imported that stale page (homepage/category/Chapter 1). Only pages
    /// that finished loading are ever importable, so detection and the tap
    /// action both key off this.
    final committedUrl = useState<String?>(initialUrl);

    void recheckNovelPage() {
      final url = committedUrl.value;
      if (url == null || !context.mounted) {
        novelUrl.value = null;
        return;
      }
      final uri = Uri.tryParse(url);
      final adapter = uri == null
          ? null
          : ref.read(sourceRegistryProvider).resolve(uri);
      // Three gates, all required:
      // 1. a site adapter handles this URL and the site is a novel site;
      // 2. the URL itself is a novel *detail* page — homepages, category/
      //    genre/tag listings and search pages can never be imported;
      // 3. it is not a chapter page — chapter content must be indexed from
      //    the detail page or the book's chapter list is corrupted.
      final isNovelDetail =
          adapter != null &&
          adapter.contentCategory == ContentCategory.novel &&
          classifyNovelPageUrl(url) == NovelPageKind.novelDetail;
      novelUrl.value = isNovelDetail ? url : null;
    }

    /// The engine flips currentUrl at load *start*; only re-evaluate once the
    /// load settles, so an in-flight navigation can neither show the pill for
    /// a page that has not appeared yet nor import the document underneath.
    void onLoadingSettled() {
      final loading = engine.isLoading.value;
      if (loading) {
        // Navigation in flight: the pill reflects a page that is leaving.
        if (context.mounted) novelUrl.value = null;
        return;
      }
      final url = engine.currentUrl.value;
      if (url != null && url.isNotEmpty && context.mounted) {
        committedUrl.value = url;
        recheckNovelPage();
      }
    }

    void onUrlChanged() {
      if (!engine.isLoading.value) onLoadingSettled();
    }

    /// Validates the page the user is actually looking at right now and
    /// returns its URL, or null (with a toast) when the current page is not
    /// importable — in-flight navigation, homepage/listing pages, chapter
    /// pages and unsupported (non-novel-site) documents are all rejected.
    String? validateImportTarget() {
      final url = engine.currentUrl.value;
      final uri = Uri.tryParse(url ?? '');
      if (url == null ||
          uri == null ||
          uri.host.isEmpty ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        AppToast.showError(
          'Open the novel\'s own page, then import from there.',
        );
        return null;
      }
      if (engine.isLoading.value) {
        // The visible DOM may still be the PREVIOUS page (homepage or
        // categories), so importing now would index the wrong document.
        AppToast.showError('Still loading — wait for the page to finish.');
        return null;
      }
      final adapter = ref.read(sourceRegistryProvider).resolve(uri);
      final kind = classifyNovelPageUrl(url);
      if (adapter == null ||
          adapter.contentCategory != ContentCategory.novel ||
          kind != NovelPageKind.novelDetail) {
        AppToast.showError(
          'This isn\'t a novel page — import only works on a novel\'s own page.',
        );
        return null;
      }
      committedUrl.value = url;
      novelUrl.value = url;
      return url;
    }

    /// Hands a page URL to the standard import sheet, capturing the live
    /// session/cookies of this engine first. Shared by the novel-detection
    /// pill and the temporary unsupported-site import button.
    Future<void> importFromPage(String url) async {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await ref.read(browserSessionRepositoryProvider).captureForOrigin(uri);
      }
      final webViewService = WebViewFetchService.instance;
      final previousFetcher = webViewService.fetcher;
      webViewService.fetcher = WebViewPageFetcher(engine: engine).fetchHtml;
      try {
        if (!context.mounted) return;
        final outcome = await showImportUrlSheet(
          context,
          initialUrl: url,
          skipInputStage: true,
          onImport: (bytes, fileName, sheetUrl, onProgress) =>
              ref.read(contentAcquisitionEngineProvider).importAndSave(url, onProgress: onProgress),
        );
        if (outcome == null || !context.mounted) return;
        final route = outcome.category == ContentCategory.novel
            ? '/novel/${outcome.bookId}'
            : '/book/${outcome.bookId}';
        // Phase 3: a universal import makes the site searchable in Find new
        // (it shows up in the Bookmarks tab's saved directory). Nice-to-have,
        // never a blocker.
        if (uri != null) {
          try {
            await ref.read(learnedOriginSearchRegistrar)(
              UniversalOriginRuleStore.originOf(uri),
            );
          } on Object {
            // ignore.
          }
          if (!context.mounted) return;
        }
        GoRouter.of(context).go(route);
      } finally {
        webViewService.fetcher = previousFetcher;
      }
    }

    void onNovelPillTap() {
      // Always import the page the user is looking at NOW, not a URL the
      // pill may have remembered from a previous navigation.
      final url = validateImportTarget();
      if (url != null) unawaited(importFromPage(url));
    }

    /// Experimental import for pages on sites without a dedicated adapter.
    /// Same stale-page protection: re-validates the live engine URL at tap
    /// time and blocks mid-navigation, homepage/listing and chapter pages.
    void onExperimentalImportTap() {
      final url = engine.currentUrl.value;
      final uri = Uri.tryParse(url ?? '');
      if (url == null || uri == null || engine.isLoading.value) {
        AppToast.showError('Still loading — wait for the page to finish.');
        return;
      }
      if (classifyNovelPageUrl(url) != NovelPageKind.novelDetail) {
        AppToast.showError(
          'This isn\'t a novel page — opening a novel\'s own page enables import.',
        );
        return;
      }
      committedUrl.value = url;
      unawaited(importFromPage(url));
    }

    useEffect(() {
      engine.currentUrl.addListener(onUrlChanged);
      engine.isLoading.addListener(onLoadingSettled);
      // The initial page may already be committed by the time this effect
      // runs (cache hit): classify whatever the engine holds right now.
      onLoadingSettled();
      return () {
        engine.currentUrl.removeListener(onUrlChanged);
        engine.isLoading.removeListener(onLoadingSettled);
        engine.dispose();
      };
    }, [engine]);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    SourceAdapter? resolveAdapterFor(String? url) {
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri == null) return null;
      return ref.read(sourceRegistryProvider).resolve(uri);
    }

    // Informational guidance for pages that are deliberately NOT
    // novel-detail pages (novel-site homepages / listings, chapter pages,
    // unsupported sites): what the user should do next instead of a dead or
    // blocked import affordance.
    final String? infoMessage = novelUrl.value == null &&
            !engine.isLoading.value &&
            committedUrl.value != null
        ? blockedPageInfoMessage(
            url: committedUrl.value,
            isLoading: engine.isLoading.value,
            adapter: resolveAdapterFor(committedUrl.value),
          )
        : null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            // Full-bleed Web Platform View (the old glass top navbar is gone —
            // its controls live in the floating glass pills below).
            Positioned.fill(child: engine.buildView()),

            // Web page progress indicator — floating hairline at the very top.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: engine.progress,
                  builder: (ctx, p, _) {
                    if (p <= 0.0 || p >= 1.0) return const SizedBox.shrink();
                    return LinearProgressIndicator(
                      value: p,
                      minHeight: 2.5,
                      backgroundColor: Colors.transparent,
                      color: colorScheme.primary,
                    );
                  },
                ),
              ),
            ),

            // Back within the webview's own history. Hidden when there is
            // nothing to go back to (immersion), unlike the old always-on bar.
            Positioned(
              left: AppSpacing.md,
              top: AppSpacing.md,
              child: ValueListenableBuilder<bool>(
                valueListenable: engine.canGoBack,
                builder: (ctx, canBack, _) => canBack
                    ? _GlassCircleNav(
                        tooltip: 'Go back',
                        icon: Icons.arrow_back_ios_new_rounded,
                        colorScheme: colorScheme,
                        onPressed: () => engine.goBack(),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // Close — the only way out of the immersive screen, so it stays.
            Positioned(
              right: AppSpacing.md,
              top: AppSpacing.md,
              child: _GlassCircleNav(
                tooltip: 'Close source',
                icon: Icons.close_rounded,
                colorScheme: colorScheme,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            // Novel Detection Bottom Action Pill — browser import path:
            // captures live WebView session+cookies directly (no silent fallback)
            // via WebViewFetchService.fetcher bound to this immersive engine.
            if (novelUrl.value != null)
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.lg,
                child: Material(
                  elevation: 6,
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusLg,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusLg,
                    ),
                    onTap: onNovelPillTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.smMd,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            size: 20,
                            color: colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Novel detected on this page',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                Text(
                                  'Tap to import into library',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: onNovelPillTap,
                            child: const Text('Import'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Informational pill — pages that are not novel-detail pages
            // (novel-site homepage/listing, chapter pages, unsupported sites).
            // Informs the user what to do next; the actionable import pill
            // above only covers novel-detail pages.
            if (infoMessage != null)
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.lg,
                child: Material(
                  elevation: 6,
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusLg,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.smMd,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            infoMessage,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // TEMPORARY: import affordance for pages on sites without a
            // dedicated adapter — hands the current page URL to the standard
            // import sheet (session captured, direct-URL fallback import).
            // Same page-kind gates as the pill: never offered on the site's
            // homepage, category/genre listings or chapter pages, and never
            // while a navigation is still in flight (the DOM on screen is
            // then still the previous page).
            // Remove once unsupported-site detection ships.
            if (novelUrl.value == null &&
                _isUnsupportedSiteImportable(
                  committedUrl.value,
                  engine.isLoading.value,
                ))
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.lg,
                child: _GlassCircleNav(
                  tooltip: 'Import from this page (experimental)',
                  icon: Icons.bookmark_add_rounded,
                  colorScheme: colorScheme,
                  onPressed: onExperimentalImportTap,
                ),
              ),
          
 ],
        ),
      ),
    );
  }
}

/// Whether the experimental import affordance may be offered for a page that
/// no novel-site adapter claims: it must be an http(s) page already
/// committed (not mid-navigation), on a novel-detail-shaped URL — never the
/// site root, a listing page or a chapter page.
bool _isUnsupportedSiteImportable(String? url, bool isLoading) {
  if (isLoading || url == null) return false;
  final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  return classifyNovelPageUrl(url) == NovelPageKind.novelDetail;
}

/// Informational copy for pages where import is deliberately blocked — the
/// novel site's homepage / listing pages, chapter pages, or pages on sites
/// Atlas has not cataloged yet. Returns null for novel-detail pages, which are
/// surfaced through the import affordance instead.
String? blockedPageInfoMessage({
  required String? url,
  required bool isLoading,
  SourceAdapter? adapter,
}) {
  if (isLoading || url == null) return null;
  final kind = classifyNovelPageUrl(url);
  if (kind == NovelPageKind.novelDetail) return null;
  final uri = Uri.tryParse(url);
  final isHttpPage = uri != null &&
      (uri.scheme.toLowerCase() == 'http' ||
          uri.scheme.toLowerCase() == 'https') &&
      uri.host.isNotEmpty;
  if (!isHttpPage) return null;
  if (adapter != null && adapter.contentCategory == ContentCategory.novel) {
    if (kind == NovelPageKind.chapter) {
      return 'Chapter page - open the novel main page to start importing. On the right page ? pull down to trigger import button';
    }
    return 'Novel site detected - open a novel page to start importing. On the right page ? pull down to trigger import button';
  }
  if (adapter == null) {
    return 'This site isn\'t in Atlas yet - open a novel page to import.';
  }
  return 'This site isn\'t importable yet - open a novel page to import.';
}

/// A circular liquid-glass pill housing one navigation icon, floating over
/// the webview. Same [GlassCapsule] language as the reader's pills.
class _GlassCircleNav extends StatelessWidget {
  const _GlassCircleNav({
    required this.tooltip,
    required this.icon,
    required this.colorScheme,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final ColorScheme colorScheme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassCapsule(
      pill: true,
      blur: 16,
      strong: false,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Tooltip(
            message: tooltip,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Icon(
                icon,
                size: 19,
                color: colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
