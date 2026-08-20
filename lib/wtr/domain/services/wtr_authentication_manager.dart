import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_auth_state.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_exceptions.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_session_record.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_session_repository.dart';
import 'package:atlas_app/wtr/domain/services/wtr_session_auxiliary.dart';

/// Drives the WTR-Lab authentication state machine and owns session capture /
/// validation / clearing.
///
/// The login form itself is entirely WTR-Lab's (rendered in an app WebView via
/// `WtrLoginScreen`); this manager only records *that* a browser session was
/// established and validates it is still usable. It never sees, stores, or
/// logs passwords, tokens or cookie values.
///
/// State transitions:
///   notAuthenticated ─beginLogin─> authenticating ─completeLogin─> authenticated
///                                       │  (failure)                 │
///                                       ▼                            ▼
///                               authenticationFailed            sessionExpired
///
/// `sessionExpired` is reached when WTR-Lab rejects the stored session during
/// an AI fetch, or when a stored-but-invalid session is detected at startup.
class WtrAuthenticationManager {
  WtrAuthenticationManager({
    WtrSessionRepository? sessionRepository,
    WtrSessionAuxiliary? auxiliary,
  }) : _repository = sessionRepository ?? InMemoryWtrSessionRepository(),
       _auxiliary = auxiliary;

  /// Origin scoping all WTR-Lab session state (cookies, preference keying).
  static final Uri origin = Uri.parse('https://wtr-lab.com');

  /// The WTR-Lab sign-in page opened inside the auth WebView. The form itself
  /// is served by WTR-Lab; Atlas never renders or collects it.
  static const String loginUrl = 'https://wtr-lab.com/en/auth/login';

  final WtrSessionRepository _repository;
  final WtrSessionAuxiliary? _auxiliary;

  /// Current auth state; the UI (and [WtrChapterProvider]'s AI gate) watch it.
  final ValueNotifier<WtrAuthState> state = ValueNotifier<WtrAuthState>(
    WtrAuthState.notAuthenticated,
  );

  /// When the session was captured (null before any successful login).
  DateTime? connectedAt;

  /// Restores the persisted connection metadata at startup. A stored "connected"
  /// record whose cookies can no longer be probed is downgraded to
  /// [WtrAuthState.sessionExpired] so the UI asks for a re-login rather than
  /// silently claiming the session is reusable.
  Future<void> initialize() async {
    final record = await _repository.load();
    if (record == null || !record.authenticated) return;
    if (await _validateSession()) {
      state.value = WtrAuthState.authenticated;
    } else {
      // We can't prove the session is still valid. Do not trust the record.
      state.value = WtrAuthState.sessionExpired;
    }
    connectedAt = record.connectedAt;
  }

  /// Signals a login flow is starting (used by [WtrLoginScreen]).
  void beginLogin() => state.value = WtrAuthState.authenticating;

  /// Captures the WTR-Lab browser session, validates it, and marks the account
  /// connected. Returns false (state → [WtrAuthState.authenticationFailed])
  /// when cookies could not be captured or validated.
  Future<bool> completeLogin() async {
    state.value = WtrAuthState.authenticating;
    try {
      await _auxiliary?.captureCookies();
      final ok = await _validateSession();
      if (ok) {
        final now = DateTime.now();
        connectedAt = now;
        await _repository.save(
          WtrSessionRecord(authenticated: true, connectedAt: now),
        );
        state.value = WtrAuthState.authenticated;
        return true;
      }
      state.value = WtrAuthState.authenticationFailed;
      return false;
    } on Object catch (e) {
      AppLogger.warning('WTR-Lab login capture failed: $e');
      state.value = WtrAuthState.authenticationFailed;
      return false;
    }
  }

  /// True when the platform cookie store currently has WTR-Lab cookies. When
  /// no auxiliary is available (pure-logic contexts) this returns false so the
  /// caller never assumes a session that cannot be proven.
  Future<bool> _validateSession() async {
    final auxiliary = _auxiliary;
    if (auxiliary == null) return false;
    return auxiliary.hasSessionCookies();
  }

  /// WTR-Lab rejected the stored session (expired / logged out).
  void markSessionExpired() {
    state.value = WtrAuthState.sessionExpired;
    connectedAt = null;
    unawaited(_repository.clear());
  }

  /// A login attempt failed without a clear reason.
  void markAuthenticationFailed() {
    state.value = WtrAuthState.authenticationFailed;
  }

  /// Clears the stored session metadata and the platform cookies (logout /
  /// "Change Account"). Returns to [WtrAuthState.notAuthenticated].
  Future<void> clearSession() async {
    await _repository.clear();
    await _auxiliary?.clearCookies();
    connectedAt = null;
    state.value = WtrAuthState.notAuthenticated;
  }

  /// Enforces the AI gate for a chapter request.
  ///
  /// Throws [WtrAuthRequiredException] when no usable session exists and
  /// [WtrSessionExpiredException] when the stored session is known-bad.
  void ensureAuthenticatedOrThrow() {
    switch (state.value) {
      case WtrAuthState.authenticated:
        return;
      case WtrAuthState.sessionExpired:
        throw const WtrSessionExpiredException();
      case WtrAuthState.notAuthenticated:
      case WtrAuthState.authenticating:
      case WtrAuthState.authenticationFailed:
        throw const WtrAuthRequiredException();
    }
  }

  void dispose() {
    state.dispose();
  }
}
