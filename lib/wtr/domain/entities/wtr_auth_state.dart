/// Explicit authentication state for a WTR-Lab account connection.
///
/// The UI renders a distinct surface per state (see
/// `WtrTranslationSelector`). State is driven exclusively by
/// `WtrAuthenticationManager`; nothing outside the WTR module mutates it.
enum WtrAuthState {
  /// No session has been established (default).
  notAuthenticated,

  /// A login flow is currently running inside the auth WebView.
  authenticating,

  /// A usable WTR-Lab session is present and being reused for AI chapters.
  authenticated,

  /// The stored session was rejected by WTR-Lab (expired / logged out).
  sessionExpired,

  /// The most recent login attempt failed (browser closed early, cookies could
  /// not be captured, WTR-Lab rejected the login, ...).
  authenticationFailed,
}

extension WtrAuthStateX on WtrAuthState {
  /// Whether [WtrChapterProvider] may issue an AI request right now.
  bool get allowsAi => this == WtrAuthState.authenticated;

  bool get isSettled => this != WtrAuthState.authenticating;
}
