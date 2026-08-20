import 'package:atlas_app/core/error_handling/result.dart';

/// Base type for WTR-Lab authentication failures. Being an [AppException]
/// lets them flow through `Result`-based services (`ChapterDownloadService`)
/// and surface a user-facing message without WTR leaking into other sources.
sealed class WtrAuthException extends AppException {
  const WtrAuthException(super.message, [super.cause]);
}

/// AI translation was selected but no WTR-Lab session exists.
class WtrAuthRequiredException extends WtrAuthException {
  const WtrAuthRequiredException()
    : super(
        'AI translation requires you to sign in to your WTR-Lab account. '
        'Your login and account data are handled by WTR-Lab; Atlas only uses '
        'the authenticated session to retrieve chapter content.',
      );

  @override
  String get code => 'WTR_AUTH_REQUIRED';

  @override
  String get userMessage =>
      'AI translation requires a WTR-Lab account. Sign in to WTR-Lab to use '
      'AI translation.';
}

/// The stored session was rejected by WTR-Lab (expired or logged out), or a
/// login attempt failed.
class WtrSessionExpiredException extends WtrAuthException {
  const WtrSessionExpiredException()
    : super(
        'Your WTR-Lab session is no longer valid. Please sign in again to '
        'use AI translation.',
      );

  @override
  String get code => 'WTR_SESSION_EXPIRED';

  @override
  String get userMessage =>
      'Your WTR-Lab session expired. Sign in again to use AI translation.';
}

/// A login attempt failed (browser closed early, cookies could not be
/// captured, or WTR-Lab rejected the login).
class WtrAuthenticationFailedException extends WtrAuthException {
  const WtrAuthenticationFailedException()
    : super('Signing in to WTR-Lab failed. Please try again.');

  @override
  String get code => 'WTR_AUTH_FAILED';

  @override
  String get userMessage =>
      'Signing in to WTR-Lab did not complete. Please try again.';
}
