import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'dart:async';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/engines/webview_page_fetcher.dart';
import 'package:atlas_app/browser/infrastructure/engines/inapp_webview_engine.dart';
import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';
import 'package:atlas_app/core/content_engine/universal/origin_rules.dart';
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
    final currentDisplayUrl = useState<String?>(initialUrl);

    void checkForNovel(String url) {
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

    void onUrlChanged() {
      final url = engine.currentUrl.value;
      if (url != null && url.isNotEmpty && context.mounted) {
        currentDisplayUrl.value = url;
        checkForNovel(url);
      }
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

    useEffect(() {
      engine.currentUrl.addListener(onUrlChanged);
      return () {
        engine.currentUrl.removeListener(onUrlChanged);
        engine.dispose();
      };
    }, [engine]);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                    onTap: () => importFromPage(novelUrl.value!),
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
                            onPressed: () => importFromPage(novelUrl.value!),
                            child: const Text('Import'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // TEMPORARY: import affordance for pages on sites without a
            // dedicated adapter — hands the current page URL to the standard
            // import sheet (session captured, direct-URL fallback import).
            // Remove once unsupported-site detection ships.
            if (novelUrl.value == null && _isWebPage(currentDisplayUrl.value))
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.lg,
                child: _GlassCircleNav(
                  tooltip: 'Import from this page (experimental)',
                  icon: Icons.bookmark_add_rounded,
                  colorScheme: colorScheme,
                  onPressed: () {
                    final url = currentDisplayUrl.value;
                    if (url != null) unawaited(importFromPage(url));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Whether [url] is a browsable http(s) page (used to gate the temporary
/// unsupported-site import button).
bool _isWebPage(String? url) {
  if (url == null) return false;
  final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
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
