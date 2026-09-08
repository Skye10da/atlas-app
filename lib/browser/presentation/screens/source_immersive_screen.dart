import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/engines/webview_page_fetcher.dart';
import 'package:atlas_app/browser/infrastructure/engines/inapp_webview_engine.dart';
import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/presentation/widgets/import_url_dialog.dart';
import 'package:go_router/go_router.dart';

/// Full-screen immersive webview for a single source.
/// Replaces the multi-tab browser with a clean, focused browsing experience
/// featuring a floating glass top bar with Back and Close (×) buttons and
/// a slide-up novel detection pill.
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

    useEffect(() {
      engine.currentUrl.addListener(onUrlChanged);
      return () {
        engine.currentUrl.removeListener(onUrlChanged);
        engine.dispose();
      };
    }, [engine]);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final host = currentDisplayUrl.value != null
        ? Uri.tryParse(currentDisplayUrl.value!)?.host ?? currentDisplayUrl.value!
        : (sourceTitle ?? 'Source');

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            // Main Webview Column
            Column(
              children: [
                // Clean Glass Top Navigation Bar
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer.withValues(alpha: 0.95),
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back in webview
                      ValueListenableBuilder<bool>(
                        valueListenable: engine.canGoBack,
                        builder: (ctx, canBack, _) {
                          return IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                            ),
                            onPressed: canBack ? () => engine.goBack() : null,
                            tooltip: 'Go back',
                            visualDensity: VisualDensity.compact,
                          );
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),

                      // Host / Title
                      Expanded(
                        child: Text(
                          host,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),

                      // Close button (×)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close source',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),

                // Web Page Progress Indicator
                ValueListenableBuilder<double>(
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

                // Web Platform View
                Expanded(child: engine.buildView()),
              ],
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
                  child: Builder(
                    builder: (pillContext) {
                      Future<void> handleImmersiveImport() async {
                        final url = novelUrl.value;
                        if (url == null) return;
                        final uri = Uri.tryParse(url);
                        if (uri != null) {
                          await ref.read(browserSessionRepositoryProvider).captureForOrigin(uri);
                        }
                        final webViewService = WebViewFetchService.instance;
                        final previousFetcher = webViewService.fetcher;
                        webViewService.fetcher = WebViewPageFetcher(engine: engine).fetchHtml;
                        try {
                          if (!pillContext.mounted) return;
                          final outcome = await showImportUrlSheet(
                            pillContext,
                            initialUrl: url,
                            skipInputStage: true,
                            onImport: (bytes, fileName, sheetUrl, onProgress) =>
                                ref.read(contentAcquisitionEngineProvider).importAndSave(url, onProgress: onProgress),
                          );
                          if (outcome == null || !pillContext.mounted) return;
                          final route = outcome.category == ContentCategory.novel
                              ? '/novel/${outcome.bookId}'
                              : '/book/${outcome.bookId}';
                          GoRouter.of(pillContext).go(route);
                        } finally {
                          webViewService.fetcher = previousFetcher;
                        }
                      }

                      return InkWell(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.borderRadiusLg,
                        ),
                        onTap: handleImmersiveImport,
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
                                onPressed: handleImmersiveImport,
                                child: const Text('Import'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
