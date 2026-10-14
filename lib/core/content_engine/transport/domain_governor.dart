import 'dart:async';

import 'package:atlas_app/core/content_engine/plugins/plugin_permissions.dart';
import 'package:atlas_app/core/content_engine/transport/robotstxt.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/logging/logger.dart';

/// Per-origin policy governor: concurrency, robots.txt, backoff, tier memory.
class DomainGovernor {
  DomainGovernor._();

  static final DomainGovernor instance = DomainGovernor._();

  final Map<String, OriginState> _states = {};
  PluginPermissions? _defaultPermissions;

  /// Configure default permissions (used when plugin doesn't specify).
  void setDefaultPermissions(PluginPermissions permissions) {
    _defaultPermissions = permissions;
  }

  /// Acquire a permit for [origin]. Returns when a slot is available.
  Future<Permit> acquire(Uri origin, {PluginPermissions? permissions}) async {
    final state = getState(origin);
    final effectivePermissions = permissions ?? _defaultPermissions ?? const PluginPermissions();
    
    while (true) {
      // Check backoff
      if (state.backoffUntil != null && DateTime.now().isBefore(state.backoffUntil!)) {
        final wait = state.backoffUntil!.difference(DateTime.now());
        AppLogger.debug('DomainGovernor: $origin backing off for ${wait.inMilliseconds}ms');
        await Future.delayed(wait);
        continue;
      }

      // Check robots.txt disallow
      if (effectivePermissions.respectRobotsTxt && state.robotsTxt != null) {
        if (!state.robotsTxt!.allows(origin)) {
          throw TransportException(
            'robots.txt disallows $origin',
            statusCode: 403,
          );
        }
      }

      // Check concurrency
      final active = state.activeCount;
      final maxConcurrent = effectivePermissions.maxConcurrentRequests;
      if (active < maxConcurrent) {
        state.activeCount++;
        return Permit._(this, origin, effectivePermissions, state);
      }

      // Wait for a slot
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Get or create state for [origin].
  OriginState getState(Uri origin) {
    final key = _originKey(origin);
    return _states.putIfAbsent(key, () => OriginState());
  }

  /// Select the best fetcher tier for [origin] based on history.
  FetcherTier selectTier(Uri origin) {
    final state = getState(origin);
    return state.lastSuccessfulTier;
  }

  /// Get stable profile (UA + TLS fingerprint) for origin.
  StableProfile? getProfile(Uri origin) {
    return _states[_originKey(origin)]?.stableProfile;
  }

  /// Record outcome for tier selection and backoff.
  void recordOutcome(Uri origin, FetcherTier tier,
      {required bool success, bool challenge = false, Duration? retryAfter}) {
    final state = getState(origin);
    if (success) {
      state.lastSuccessfulTier = tier;
      state.consecutiveFailures = 0;
      state.backoffUntil = null;
    } else {
      state.consecutiveFailures++;
      if (challenge && tier != FetcherTier.stealthy) {
        // Escalate tier on challenge
        state.lastSuccessfulTier = FetcherTier.values
            .firstWhere((t) => t.index > tier.index, orElse: () => FetcherTier.stealthy);
      }
      // Apply backoff
      if (retryAfter != null) {
        state.backoffUntil = DateTime.now().add(retryAfter);
      } else if (state.consecutiveFailures >= 2) {
        // Exponential backoff: 1s, 2s, 4s, 8s... max 60s
        final backoffSec = (1 << (state.consecutiveFailures - 1)).clamp(1, 60);
        state.backoffUntil = DateTime.now().add(Duration(seconds: backoffSec));
      }
    }
  }

  /// Ensure robots.txt is fetched and parsed for [origin].
  Future<void> ensureRobotsTxt(Uri origin, Transport transport) async {
    final state = getState(origin);
    if (state.robotsTxt != null) return;
    
    final robotsUrl = origin.replace(path: '/robots.txt');
    try {
      final body = await transport.fetchHtml(robotsUrl);
      state.robotsTxt = RobotsTxt.parse(body, origin);
      AppLogger.debug('DomainGovernor: parsed robots.txt for $origin');
    } on TransportException {
      // No robots.txt or fetch failed - treat as allow all
      state.robotsTxt = RobotsTxt.allowAll();
    }
  }

  String _originKey(Uri origin) => origin.replace(path: '/', query: null, fragment: null).toString();

  void _release(OriginState state) {
    if (state.activeCount > 0) {
      state.activeCount--;
    }
  }
}

class OriginState {
  FetcherTier lastSuccessfulTier = FetcherTier.http;
  StableProfile? stableProfile;
  DateTime? backoffUntil;
  RobotsTxt? robotsTxt;
  int consecutiveFailures = 0;
  int activeCount = 0;
}

class Permit {
  Permit._(this._governor, this.origin, this.permissions, this._state);
  final DomainGovernor _governor;
  final Uri origin;
  final PluginPermissions permissions;
  final OriginState _state;

  void release() => _governor._release(_state);
}

enum FetcherTier { http, webview, stealthy }

class StableProfile {
  const StableProfile({
    required this.userAgent,
    required this.secChUa,
    required this.tlsFingerprint,
  });

  final String userAgent;
  final Map<String, String> secChUa;
  final String tlsFingerprint; // "chrome124" | "firefox125" | "safari17"
}