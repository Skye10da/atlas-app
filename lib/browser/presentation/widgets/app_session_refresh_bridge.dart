import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/browser/presentation/screens/session_refresh_screen.dart';
import 'package:atlas_app/core/router/app_router.dart';
import 'package:atlas_app/core/session/session_refresh_service.dart';

/// Installs [SessionRefreshService]'s UI driver: pushes the quick session
/// re-verify webview on the root navigator (so it works from the reader and
/// detail screens alike), waits for verification to pass, captures the fresh
/// cookies, and reports back so the caller retries. Mounted once in the app
/// root beside `SilentWebViewHost`.
class AppSessionRefreshBridge extends ConsumerStatefulWidget {
  const AppSessionRefreshBridge({super.key});

  @override
  ConsumerState<AppSessionRefreshBridge> createState() =>
      _AppSessionRefreshBridgeState();
}

class _AppSessionRefreshBridgeState
    extends ConsumerState<AppSessionRefreshBridge> {
  @override
  void initState() {
    super.initState();
    SessionRefreshService.instance.driver = _runRefresh;
  }

  @override
  void dispose() {
    SessionRefreshService.instance.driver = null;
    super.dispose();
  }

  Future<bool> _runRefresh(SessionRefreshRequest request) async {
    final navigator = AppRouter.rootNavigatorKey.currentState;
    if (navigator == null) return false;
    final result = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => SessionRefreshScreen(
          origin: request.origin,
          seedUrl: request.seedUrl,
          verificationProbe: request.verificationProbe,
          engineFactory: ref.read(browserEngineFactoryProvider),
          sessionStore: ref.read(browserSessionRepositoryProvider),
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
