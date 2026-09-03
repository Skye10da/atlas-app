import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/repository_interfaces/browser_session_repository_interface.dart';
import 'package:atlas_app/browser/infrastructure/engines/inapp_webview_engine.dart';

/// Probe that answers "does [origin] have a usable browser session now?".
/// Injectable so widget tests can avoid the plugin's [CookieManager].
typedef SessionCookieProbe = Future<bool> Function(Uri origin);

Future<bool> _defaultCookieProbe(Uri origin) async {
  try {
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri.uri(origin),
    );
    return cookies.isNotEmpty;
  } on Object {
    return false;
  }
}

/// The "quick source" re-verify view: a full-screen webview seeded at the
/// novel's source address that stays up until bot verification passes (the
/// user can complete a manual captcha inside it), then captures the fresh
/// cookies and pops back to the previous screen. Drives
/// [SessionRefreshService.ensureFresh] via `AppSessionRefreshBridge`.
class SessionRefreshScreen extends HookWidget {
  const SessionRefreshScreen({
    super.key,
    required this.origin,
    this.seedUrl,
    this.engineFactory,
    this.sessionStore,
    this.cookieProbe,
    this.verificationProbe,
    this.timeout = const Duration(seconds: 90),
    this.pollInterval = const Duration(seconds: 1),
  });

  /// Origin whose session must be re-established (`scheme://host[:port]`).
  final Uri origin;

  /// Address to seed the webview at — the novel's source URL, so the page runs
  /// the real bot challenge and lands on content once cleared.
  final Uri? seedUrl;

  final BrowserEngineFactory? engineFactory;
  final BrowserSessionRepositoryInterface? sessionStore;
  final SessionCookieProbe? cookieProbe;

  /// Domain-specific check for "verification really passed" (see
  /// [SessionRefreshRequest.verificationProbe]). When provided it replaces the
  /// generic cookie-presence probe — cookies can exist before a bot challenge
  /// is solved, which would close the window too early.
  final Future<bool> Function()? verificationProbe;
  final Duration timeout;
  final Duration pollInterval;

  @override
  Widget build(BuildContext context) {
    final engine = useMemoized<BrowserWebEngine>(() {
      final factory =
          engineFactory ??
          ({String? initialUrl}) => InappWebviewEngine(initialUrl: initialUrl);
      return factory(
        initialUrl: seedUrl?.toString() ?? origin.toString(),
      );
    }, [engineFactory, seedUrl, origin]);

    final verifying = useState(true);
    final timedOut = useState(false);
    final done = useRef(false);
    final pollTimer = useRef<Timer?>(null);
    final timeoutTimer = useRef<Timer?>(null);

    void cancelTimers() {
      pollTimer.value?.cancel();
      timeoutTimer.value?.cancel();
      pollTimer.value = null;
      timeoutTimer.value = null;
    }

    Future<void> complete() async {
      if (done.value || !context.mounted) return;
      done.value = true;
      cancelTimers();
      final store = sessionStore;
      if (store != null) await store.captureForOrigin(origin);
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    }

    void onTimeout() {
      if (done.value || !context.mounted) return;
      done.value = true;
      cancelTimers();
      verifying.value = false;
      timedOut.value = true;
    }

    Future<bool> probeCookies() async {
      try {
        final hasAny = await (cookieProbe ?? _defaultCookieProbe)(origin);
        if (!hasAny) return false;
        final cookies = await CookieManager.instance().getCookies(
          url: WebUri.uri(origin),
        );
        if (cookies.isEmpty) return hasAny;
        final hasClearance = cookies.any((c) =>
            c.name.toLowerCase() == 'cf_clearance' ||
            c.name.toLowerCase() == '__cf_bm' ||
            c.name.toLowerCase().contains('turnstile') ||
            c.name.toLowerCase().contains('session'));
        return hasClearance || cookies.isNotEmpty;
      } on Object {
        return false;
      }
    }

    Future<bool> probePageJs() async {
      try {
        // Also evaluate in page if document is fully ready and not a challenge page
        final res = await engine.evaluate('''
(() => {
  const t = (document.title || '').toLowerCase();
  const b = (document.body ? document.body.innerText : '').toLowerCase();
  if (t.includes('just a moment') || t.includes('attention required') || b.includes('cf-turnstile')) {
    return false;
  }
  return document.readyState === 'complete' || document.readyState === 'interactive';
})()
''');
        return res == true;
      } on Object {
        return false;
      }
    }

    Future<void> checkVerified() async {
      if (done.value || !context.mounted) return;
      bool verified = false;
      if (verificationProbe != null) {
        try {
          verified = await verificationProbe!();
        } catch (_) {
          verified = false;
        }
      } else if (cookieProbe != null) {
        verified = await cookieProbe!(origin);
      } else {
        final hasCookies = await probeCookies();
        final pageReady = await probePageJs();
        // If cookies exist and page is loaded without challenge title/body, consider verified
        verified = hasCookies && pageReady;
      }

      if (verified) {
        await complete();
      }
    }

    void startPolling() {
      timeoutTimer.value = Timer(timeout, onTimeout);
      pollTimer.value = Timer.periodic(pollInterval, (_) => checkVerified());
    }

    void onRetry() {
      if (!context.mounted) return;
      done.value = false;
      verifying.value = true;
      timedOut.value = false;
      startPolling();
    }

    useEffect(() {
      startPolling();
      return () {
        cancelTimers();
        engine.dispose();
      };
    }, [engine]);

    final colorScheme = Theme.of(context).colorScheme;
    final status = verifying.value
        ? const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Waiting for verification…')),
              Text('Up to 90 s'),
            ],
          )
        : timedOut.value
        ? Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.error),
              const SizedBox(width: 12),
              const Expanded(child: Text('Verification timed out.')),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
            ],
          )
        : Row(
            children: [
              Icon(Icons.check_circle, color: colorScheme.primary),
              const SizedBox(width: 12),
              const Expanded(child: Text('Verified — closing…')),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Re-verify session'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload page',
            onPressed: () => engine.reload(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.tonalIcon(
              onPressed: complete,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Done'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: status,
          ),
          Expanded(
            child: Semantics(
              label: 'Source page open for verification',
              child: engine.buildView(),
            ),
          ),
        ],
      ),
    );
  }
}

