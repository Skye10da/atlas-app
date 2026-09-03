import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/services/silent_web_view_service.dart';
import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';

/// Off-screen home for the [SilentWebViewService]'s background web view.
///
/// Mounted once in the app root ([AtlasApp], see `main.dart`) at a 1x1 size
/// and kept alive for the whole app lifetime. It registers the shared
/// fallback [WebViewFetcher] on [WebViewFetchService], so a browser-less
/// plugin fetch — e.g. a reader chapter download after a restart — can
/// silently load the target origin (re-establishing a Cloudflare clearance
/// cookie) and serve the request from a real browser context.
///
/// The live browser remains the primary fetcher whenever it is open; this
/// host only kicks in when no open tab covers the requested origin.
class SilentWebViewHost extends HookConsumerWidget {
  const SilentWebViewHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engineState = useState<BrowserWebEngine?>(null);

    useEffect(() {
      final engine = ref.read(browserEngineFactoryProvider)();
      final service = SilentWebViewService(
        engine: engine,
        sessionStore: ref.read(browserSessionRepositoryProvider),
      );
      engineState.value = engine;
      WebViewFetchService.instance.fallbackFetcher = service.fetchHtml;

      return () {
        WebViewFetchService.instance.fallbackFetcher = null;
        engine.dispose();
        engineState.value = null;
      };
    }, const []);

    final engine = engineState.value;
    if (engine == null) return const SizedBox.shrink();

    return Semantics(
      explicitChildNodes: true,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        child: IgnorePointer(child: engine.buildView()),
      ),
    );
  }
}
