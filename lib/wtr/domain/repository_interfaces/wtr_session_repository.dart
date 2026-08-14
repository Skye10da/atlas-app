import 'package:atlas_app/wtr/domain/entities/wtr_session_record.dart';

/// Persists the *metadata* of the WTR-Lab connection so the UI can restore the
/// "connected" state across app restarts.
///
/// **No credentials are ever stored through this interface** — the browser
/// session itself (cookies) lives in the platform WebView cookie store and the
/// app's existing per-origin browser-session repository.
abstract interface class WtrSessionRepository {
  Future<WtrSessionRecord?> load();
  Future<void> save(WtrSessionRecord record);
  Future<void> clear();
}

/// In-memory default for unit tests and cold-boot paths.
class InMemoryWtrSessionRepository implements WtrSessionRepository {
  WtrSessionRecord? _record;

  @override
  Future<WtrSessionRecord?> load() async => _record;

  @override
  Future<void> save(WtrSessionRecord record) async => _record = record;

  @override
  Future<void> clear() async => _record = null;
}
