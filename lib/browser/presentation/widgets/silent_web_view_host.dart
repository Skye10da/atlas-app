import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class SilentWebViewHost extends ConsumerStatefulWidget {
  const SilentWebViewHost({super.key});

  @override
  ConsumerState<SilentWebViewHost> createState() => _SilentWebViewHostState();
}

class _SilentWebViewHostState extends ConsumerState<SilentWebViewHost> {
  BrowserWebEngine? _engine;

  @override
  void initState() {
    super.initState();
    final engine = ref.read(browserEngineFactoryProvider)();
    final service = SilentWebViewService(
      engine: engine,
      sessionStore: ref.read(browserSessionRepositoryProvider),
    );
    _engine = engine;
    // The tear-off keeps [service] (and its engine) alive for the host's whole
    // lifetime; [WebViewFetchService] releases it on dispose.
    WebViewFetchService.instance.fallbackFetcher = service.fetchHtml;
  }

  @override
  void dispose() {
    WebViewFetchService.instance.fallbackFetcher = null;
    _engine?.dispose();
    _engine = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    if (engine == null) return const SizedBox.shrink();
    // The host is deliberately tiny (see the 1x1 SizedBox in main.dart), never
    // focused, and never hit-testable so it can't steal input from the app.
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
