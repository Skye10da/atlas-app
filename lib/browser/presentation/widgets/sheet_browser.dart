import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:atlas_app/browser/domain/engines/webview_page_fetcher.dart';
import 'package:atlas_app/browser/infrastructure/engines/inapp_webview_engine.dart';
import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

Future<void> showSearchSheetBrowser(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  // Capture session proactively like bot-challenge flow before opening.
  final uri = Uri.tryParse(url);
  if (uri != null && uri.host.isNotEmpty) {
    await ref
        .read(browserSessionRepositoryProvider)
        .captureForOrigin(uri)
        .catchError((_) {});
  }
  if (!context.mounted) return;
  await AppSheet.show<void>(
    context: context,
    id: 'search_sheet_browser',
    initialHeight: 0.85,
    snapPoints: const [0.5, 0.85],
    maxHeightFactor: 0.92,
    title: 'Web Search',
    subtitle: uri?.host ?? url,
    child: _SheetBrowserContent(initialUrl: url),
  );
}

class _SheetBrowserContent extends HookConsumerWidget {
  const _SheetBrowserContent({required this.initialUrl});

  final String initialUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = useMemoized(
      () => InappWebviewEngine(initialUrl: initialUrl),
      [initialUrl],
    );

    final currentUrl = useState(initialUrl);

    useEffect(() {
      // Bind WebView fetcher so CookieTransport can reuse solved challenges,
      // same as BrowserScreen.captureBrowserSession + WebViewFetchService flow.
      final service = WebViewFetchService.instance;
      final previous = service.fetcher;
      service.fetcher = WebViewPageFetcher(engine: engine).fetchHtml;

      void onUrlChanged() {
        final url = engine.currentUrl.value;
        if (url != null && url.isNotEmpty) {
          currentUrl.value = url;
          final uri = Uri.tryParse(url);
          if (uri != null && uri.host.isNotEmpty) {
            // Capture cookies for bot challenge replay.
            ref
                .read(browserSessionRepositoryProvider)
                .captureForOrigin(uri)
                .catchError((_) {});
          }
        }
      }

      engine.currentUrl.addListener(onUrlChanged);
      return () {
        engine.currentUrl.removeListener(onUrlChanged);
        service.fetcher = previous;
        engine.dispose();
      };
    }, [engine]);

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Top bar with navigation
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer.withValues(alpha: 0.95),
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: engine.canGoBack,
                builder: (context, canBack, _) => IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  tooltip: 'Back',
                  onPressed: canBack ? () => engine.goBack() : null,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: engine.canGoForward,
                builder: (context, canForward, _) => IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  tooltip: 'Forward',
                  onPressed: canForward ? () => engine.goForward() : null,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: engine.isLoading,
                builder: (context, loading, _) => IconButton(
                  icon: Icon(
                    loading ? Icons.close_rounded : Icons.refresh_rounded,
                    size: 20,
                  ),
                  tooltip: loading ? 'Stop' : 'Reload',
                  onPressed: () => loading ? engine.stop() : engine.reload(),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  currentUrl.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                tooltip: 'Open in browser',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  final uri = Uri.tryParse(currentUrl.value);
                  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            ],
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: engine.progress,
          builder: (context, p, _) {
            if (p <= 0 || p >= 1) return const SizedBox(height: 2);
            return LinearProgressIndicator(
              value: p,
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: colorScheme.primary,
            );
          },
        ),
        Expanded(child: engine.buildView()),
      ],
    );
  }
}
