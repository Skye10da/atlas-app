import 'package:atlas_app/updater/domain/entities/app_release.dart';

/// Portability boundary for everything network- and install-specific. Tests
/// replace this entirely; the platform installers live behind it.
abstract class AppUpdateRepository {
  /// Fetches the newest release visible on [channel]. Returns null when
  /// GitHub has no usable release (offline handling is delegated to the
  /// implementation; parse failures degrade to null).
  Future<AppRelease?> fetchLatest({UpdateChannel channel = UpdateChannel.stable});

  /// Fetches the most recent [limit] published releases (drafts excluded)
  /// for the What's-new history. Entries whose tag carries no versionCode
  /// (i.e. not produced by the Atlas release workflow) are omitted. Notes may
  /// be null when the release has no body; artifacts are not resolved here —
  /// use [fetchLatest] for installable updates.
  Future<List<AppRelease>> fetchReleaseHistory({int limit = 20});
}

/// Typed failure surface for update fetch/install flows. `userMessage` values
/// are shown verbatim in the updater UI.
class AppUpdateException implements Exception {
  const AppUpdateException(this.userMessage, [this.cause]);

  final String userMessage;
  final Object? cause;

  @override
  String toString() => 'AppUpdateException: $userMessage (cause: $cause)';
}
