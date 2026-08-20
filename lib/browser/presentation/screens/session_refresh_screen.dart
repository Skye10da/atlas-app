import 'dart:async';

import 'package:flutter/material.dart';
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
class SessionRefreshScreen extends StatefulWidget {
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
  State<SessionRefreshScreen> createState() => _SessionRefreshScreenState();
}

class _SessionRefreshScreenState extends State<SessionRefreshScreen> {
  late final BrowserWebEngine _engine;
  Timer? _pollTimer;
  Timer? _timeoutTimer;
  bool _verifying = true;
  bool _timedOut = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final factory = widget.engineFactory ??
        ({String? initialUrl}) => InappWebviewEngine(initialUrl: initialUrl);
    _engine = factory(
      initialUrl: widget.seedUrl?.toString() ?? widget.origin.toString(),
    );
    _startPolling();
  }

  void _startPolling() {
    _timeoutTimer = Timer(widget.timeout, _onTimeout);
    _pollTimer = Timer.periodic(widget.pollInterval, (_) => _checkVerified());
  }

  Future<void> _checkVerified() async {
    if (_done || !mounted) return;
    final verified = widget.verificationProbe != null
        ? await widget.verificationProbe!()
        : await (widget.cookieProbe ?? _defaultCookieProbe)(widget.origin);
    if (verified) {
      await _complete();
    }
  }

  Future<void> _complete() async {
    if (_done || !mounted) return;
    _done = true;
    _cancelTimers();
    final store = widget.sessionStore;
    if (store != null) await store.captureForOrigin(widget.origin);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _onTimeout() {
    if (_done || !mounted) return;
    _done = true;
    _cancelTimers();
    setState(() {
      _verifying = false;
      _timedOut = true;
    });
  }

  void _onRetry() {
    if (!mounted) return;
    _done = false;
    setState(() {
      _verifying = true;
      _timedOut = false;
    });
    _startPolling();
  }

  void _cancelTimers() {
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    _pollTimer = null;
    _timeoutTimer = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = _verifying
        ? const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text('Waiting for verification…'),
              ),
              Text('Up to 90 s'),
            ],
          )
        : _timedOut
            ? Row(
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Verification timed out.'),
                  ),
                  TextButton(
                    onPressed: _onRetry,
                    child: const Text('Retry'),
                  ),
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
              child: _engine.buildView(),
            ),
          ),
        ],
      ),
    );
  }
}