import 'dart:async';
import 'dart:io' show InternetAddress, InternetAddressType;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/core/logging/logger.dart';

/// How a watched engine should be paused when connectivity drops.
enum OfflinePauseBehavior {
  /// Visible, user-facing view: only abort in-flight loads. The page the user
  /// sees is never replaced from under them.
  userView,

  /// Background headless view: abort in-flight loads AND navigate to
  /// `about:blank`, so no live page JS keeps firing requests into the native
  /// plugin while offline. Novel sites poll continuously (ads, beacons,
  /// anti-bot pings); that steady stream of failing requests is what drives
  /// the plugin's native crash on connection loss.
  headless,
}

/// Watches connectivity and, the moment it drops, moves every registered
/// webview engine into a safe network state.
///
/// WHY this exists: `flutter_inappwebview_windows_plugin.dll` has native
/// crash bugs (access violations, 0xc0000005 in `flutter_inappwebview_windows_plugin.dll`,
/// confirmed in the Windows Event Log at a stable fault offset) that fire when
/// network requests start failing under a live view. A Dart-side/global error
/// handler can never see those — the process dies in the plugin's own native
/// callbacks. So this guard works *prevention*: as soon as the network is gone,
/// in-flight loads are aborted and idle headless views are parked on
/// `about:blank`, taking the plugin out of its crash window.
///
/// Detection is a DNS-probe poll (no extra dependencies, works on every
/// desktop platform): a single failed probe means offline (reacting fast
/// matters; a brief false pause is harmless), and two consecutive successful
/// probes mean online again (slower recovery avoids flapping).
///
/// Engines register via [watch] (call from their constructors) and unregister
/// via [unwatch] (from `dispose`), so no engine is ever touched after release.
class WebViewOfflineGuard {
  /// Isolated guard for tests.
  @visibleForTesting
  factory WebViewOfflineGuard.test() => WebViewOfflineGuard._();

  WebViewOfflineGuard._();

  /// The process-wide guard every engine registers with.
  static final WebViewOfflineGuard instance = WebViewOfflineGuard._();

  final Map<BrowserWebEngine, OfflinePauseBehavior> _engines = {};
  Timer? _timer;
  int _okProbes = 0;
  bool _lastOnline = true;

  /// True as far as the most recent probes know: connectivity is down.
  bool get isOffline => !_lastOnline;

  /// Overridable liveness check for tests.
  @visibleForTesting
  Future<bool> Function()? probeOverride;

  /// Keeps [engine] under offline protection. Re-registering with a different
  /// [behavior] updates it. Also immediately pauses new engines created
  /// during an ongoing outage.
  void watch(BrowserWebEngine engine, OfflinePauseBehavior behavior) {
    _engines[engine] = behavior;
    if (!_lastOnline) {
      unawaited(_pauseEngine(engine, behavior, quiet: true));
    }
  }

  void unwatch(BrowserWebEngine engine) {
    _engines.remove(engine);
  }

  /// Starts the periodic probe. Safe to call repeatedly.
  void start({Duration interval = const Duration(seconds: 2)}) {
    _timer ??= Timer.periodic(interval, (_) => unawaited(_tick()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Runs one probe → react cycle without waiting for the timer (tests).
  @visibleForTesting
  Future<void> tick() => _tick();

  Future<void> _tick() async {
    final online = await probeConnectivity();
    if (online) {
      _okProbes++;
      if (_okProbes >= 2 && !_lastOnline) {
        _lastOnline = true;
        AppLogger.info('WebViewOfflineGuard: connectivity restored');
      }
      return;
    }
    // A failure resets the recovery streak…
    _okProbes = 0;
    // …and one failed probe is enough to react: pausing webviews briefly when
    // the probe itself blipped is harmless; missing the drop is not.
    if (_lastOnline) {
      _lastOnline = false;
      AppLogger.warning(
        'WebViewOfflineGuard: connectivity lost — pausing webview engines',
      );
      try {
        await _pauseAll();
      } on Object catch (e) {
        AppLogger.warning('WebViewOfflineGuard: pause pass failed: $e');
      }
    }
  }

  /// Best-effort DNS probe. A resolved record is treated as "online".
  ///
  /// On web this is a no-op that always reports "online": `InternetAddress`
  /// is a `dart:io` stub there (it throws synchronously, which previously
  /// surfaced as an unhandled root-zone error every 2s), and there is no
  /// native webview plugin DLL to protect on the web target.
  Future<bool> probeConnectivity() {
    final probe = probeOverride;
    if (probe != null) return probe();
    if (kIsWeb) return Future<bool>.value(true);
    return InternetAddress.lookup('pub.dev', type: InternetAddressType.IPv4)
        .then<bool>(
      (records) => records.isNotEmpty,
      onError: (_) => false,
    ).timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    );
  }

  Future<void> _pauseAll() async {
    final entries = List.of(_engines.entries);
    for (final entry in entries) {
      await _pauseEngine(entry.key, entry.value);
    }
  }

  /// Moves [engine] into its offline-safe state. An engine that disposes while
  /// being paused just fails here — every call below is guarded because the
  /// engine implementations themselves no-op after dispose too.
  Future<void> _pauseEngine(
    BrowserWebEngine engine,
    OfflinePauseBehavior behavior, {
    bool quiet = false,
  }) async {
    try {
      await engine.stop();
      if (behavior == OfflinePauseBehavior.headless) {
        await engine.load('about:blank');
      }
    } on Object catch (e) {
      if (!quiet && !_lastOnline) {
        AppLogger.warning('WebViewOfflineGuard: pausing engine failed: $e');
      }
    }
  }
}
