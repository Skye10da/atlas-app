import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'package:atlas_app/core/services/platform_service.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';

final _logger = Logger();

final readerSystemControllerProvider = Provider<ReaderSystemController>((ref) {
  final controller = ReaderSystemController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

class ReaderSystemController with WidgetsBindingObserver {
  ReaderSystemController(this._ref);

  final Ref _ref;
  Timer? _brightnessDebounce;
  double? _originalBrightness;
  bool _didOverrideBrightness = false;
  double? _lastAppliedBrightness;
  bool _keepAwakeActive = false;
  bool _autoOptimizeActive = false;
  StreamSubscription<void>? _batterySub;
  StreamSubscription<bool>? _chargingSub;
  bool _lifecycleObserverRegistered = false;
  // Latest settings snapshot for debounced path to check followSystem.
  ReadingSettingsEntity? _latestSettings;

  // Whether lifecycle restore applies (mobile only per requirement).
  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  PlatformService get _svc => _ref.read(platformServiceProvider);

  Future<bool> _canControl() async {
    return await _svc.canControlNativeBrightness;
  }

  void _ensureLifecycleObserver() {
    if (!_isMobile || _lifecycleObserverRegistered) return;
    WidgetsBinding.instance.addObserver(this);
    _lifecycleObserverRegistered = true;
  }

  void _removeLifecycleObserver() {
    if (!_lifecycleObserverRegistered) return;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _lifecycleObserverRegistered = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isMobile) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // Fire-and-forget but also cancel debounce so no re-apply after pause.
      _brightnessDebounce?.cancel();
      unawaited(restore());
    }
  }

  Future<void> captureOriginalBrightness() async {
    if (_originalBrightness != null) return;
    if (!await _canControl()) {
      _originalBrightness = 1.0;
      return;
    }
    try {
      _originalBrightness = await _svc.getBrightness();
    } catch (e) {
      _logger.d('captureOriginalBrightness failed: $e');
      _originalBrightness = 1.0;
    }
  }

  Future<void> applySettings(ReadingSettingsEntity settings) async {
    _latestSettings = settings;
    _ensureLifecycleObserver();
    await captureOriginalBrightness();
    // Wake lock — global setting, keep last intent.
    try {
      await _svc.setKeepScreenOn(settings.keepScreenAwake);
      _keepAwakeActive = settings.keepScreenAwake;
    } catch (e) {
      _logger.w('setKeepScreenOn failed: $e');
    }

    // Brightness — cancel any pending debounce before changing mode.
    // This is the fix for the "stuck at max after followSystem toggle" race.
    _brightnessDebounce?.cancel();

    if (settings.followSystemBrightness) {
      // Defensive: always try to clear any OS override, even if flag is stale.
      // Swallowed errors or crash could leave OS overridden while flag is false.
      bool needsReset = _didOverrideBrightness;
      // Also reset if we have a pending last value — indicates prior override.
      if (_lastAppliedBrightness != null) needsReset = true;
      if (needsReset) {
        final ok = await _svc.resetBrightness();
        if (ok) {
          _didOverrideBrightness = false;
          _lastAppliedBrightness = null;
        } else {
          _logger.w('resetBrightness returned false (followSystem path)');
          // Keep flag so next applySettings retries reset.
        }
      }
      _stopAutoOptimizeWatch();
    } else {
      if (await _canControl()) {
        final target = settings.brightness.clamp(0.0, 1.0);
        if (_lastAppliedBrightness != target) {
          final ok = await _svc.setBrightness(target, smooth: true);
          if (ok) {
            _didOverrideBrightness = true;
            _lastAppliedBrightness = target;
          } else {
            _logger.w('setBrightness($target) returned false — will retry');
            // Don't update flags so retry fires on next applySettings/slider move.
          }
        }
      }
      // Auto-optimize watch is managed below; ensure it reflects latest settings.
    }

    // Auto-optimize one-shot (threshold 0.2 -> 0.45)
    if (settings.autoOptimizeBrightness &&
        !settings.followSystemBrightness &&
        await _canControl()) {
      try {
        await _svc.optimizeForLowBattery(threshold: 0.2, targetBrightness: 0.45);
      } catch (e) {
        _logger.w('optimizeForLowBattery failed: $e');
      }
      _startAutoOptimizeWatch(settings);
    } else {
      _stopAutoOptimizeWatch();
    }
  }

  void applyBrightnessDebounced(double value) {
    _brightnessDebounce?.cancel();
    _brightnessDebounce = Timer(const Duration(milliseconds: 80), () async {
      // Re-check latest followSystem — if user toggled to followSystem while
      // debounce was pending, drop the manual set (fixes stuck-at-max race).
      final latest = _latestSettings;
      if (latest != null && latest.followSystemBrightness) {
        _logger.d('debounced setBrightness dropped — followSystem now true');
        return;
      }
      if (!await _canControl()) return;
      final v = value.clamp(0.0, 1.0);
      // Re-check followSystem after async gap (race window).
      final latest2 = _latestSettings;
      if (latest2 != null && latest2.followSystemBrightness) return;
      if (_lastAppliedBrightness == v) return;
      final ok = await _svc.setBrightness(v, smooth: true);
      if (ok) {
        _didOverrideBrightness = true;
        _lastAppliedBrightness = v;
      } else {
        _logger.w('debounced setBrightness($v) returned false');
      }
    });
  }

  void _startAutoOptimizeWatch(ReadingSettingsEntity settings) {
    if (_autoOptimizeActive) return;
    if (!settings.autoOptimizeBrightness || settings.followSystemBrightness) {
      return;
    }
    _autoOptimizeActive = true;

    _batterySub?.cancel();
    _chargingSub?.cancel();

    var isCharging = false;

    Future<void> evaluate() async {
      // Read latest settings instead of captured closure (fixes stale followSystem).
      final current = _latestSettings ?? settings;
      if (!current.autoOptimizeBrightness || current.followSystemBrightness) {
        return;
      }
      try {
        if (!await _canControl()) return;
        final level = await _svc.getBatteryLevel();
        final lowPower = await _svc.isLowPowerModeEnabled();
        final charging = await _svc.isCharging();
        isCharging = charging;

        // Re-read again in case toggled during awaits.
        final current2 = _latestSettings ?? current;
        if (!current2.autoOptimizeBrightness || current2.followSystemBrightness) {
          return;
        }

        final shouldDim = (!isCharging && ((level >= 0.0 && level <= 0.2) || lowPower));
        if (shouldDim) {
          const target = 0.45;
          final curBrightness = current2.brightness.clamp(0.0, 1.0);
          if (curBrightness > target) {
            _logger.i('autoOptimize dim: level=$level lowPower=$lowPower');
            applyBrightnessDebounced(target);
          }
        } else if (level > 0.4 || isCharging) {
          // Hysteresis restore — reapply on next settings change.
        }
      } catch (e) {
        _logger.d('autoOptimize evaluate failed: $e');
      }
    }

    // Initial evaluate
    unawaited(evaluate());

    // Periodic battery check every 30s
    _batterySub = Stream<void>.periodic(const Duration(seconds: 30)).listen((_) {
      unawaited(evaluate());
    });

    // Charging changes trigger immediate evaluate
    try {
      _chargingSub = _svc.onChargingChanged.listen((charging) {
        isCharging = charging;
        unawaited(evaluate());
      });
    } catch (e) {
      _logger.w('onChargingChanged listen failed: $e');
    }

    _logger.i('autoOptimize watch started (charging=$isCharging)');
  }

  void _stopAutoOptimizeWatch() {
    if (!_autoOptimizeActive) return;
    _autoOptimizeActive = false;
    _batterySub?.cancel();
    _batterySub = null;
    _chargingSub?.cancel();
    _chargingSub = null;
    _logger.i('autoOptimize watch stopped');
  }

  Future<void> restore() async {
    _brightnessDebounce?.cancel();
    _stopAutoOptimizeWatch();
    // Always try to reset on mobile when we believe we overrode.
    // Defensive extra: if _lastAppliedBrightness != null, reset even if flag false.
    final shouldReset = _didOverrideBrightness || _lastAppliedBrightness != null;
    if (shouldReset) {
      final ok = await _svc.resetBrightness();
      if (ok) {
        _didOverrideBrightness = false;
        _lastAppliedBrightness = null;
      } else {
        _logger.w('restore resetBrightness returned false');
      }
    }
    if (_keepAwakeActive) {
      try {
        await _svc.setKeepScreenOn(false);
      } catch (e) {
        _logger.w('restore setKeepScreenOn(false) failed: $e');
      }
      _keepAwakeActive = false;
    }
  }

  /// Called when reader is backgrounded/paused or when app is exiting.
  /// On mobile, ensures OS brightness override is cleared even if reader
  /// widget dispose was skipped (e.g., OS killed activity).
  Future<void> restoreForBackground() async {
    if (!_isMobile) return;
    _brightnessDebounce?.cancel();
    await restore();
  }

  void dispose() {
    _brightnessDebounce?.cancel();
    _stopAutoOptimizeWatch();
    _removeLifecycleObserver();
    unawaited(restore());
  }
}
