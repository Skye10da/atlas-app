import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/browser/presentation/screens/session_refresh_screen.dart';
import 'package:atlas_app/core/router/app_router.dart';
import 'package:atlas_app/core/session/session_refresh_service.dart';

/// Installs [SessionRefreshService]'s UI driver: pushes the quick session
/// re-verify webview on the root navigator (so it works from the reader and
/// detail screens alike), waits for verification to pass, captures the fresh
/// cookies, and reports back so the caller retries. Mounted once in the app
/// root beside `SilentWebViewHost`.
class AppSessionRefreshBridge extends HookConsumerWidget {
  const AppSessionRefreshBridge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      Future<bool> runRefresh(SessionRefreshRequest request) async {
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

      SessionRefreshService.instance.driver = runRefresh;

      return () {
        SessionRefreshService.instance.driver = null;
      };
    }, const []);

    return const SizedBox.shrink();
  }
}
