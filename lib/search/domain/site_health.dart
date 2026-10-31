/// Circuit breaker for site search requests.
///
/// A site that failed twice is skipped for a while; a site that looks
/// blocked (anti-bot/Cloudflare) backs off much longer. Keeps searches
/// fast and keeps traffic low enough to avoid triggering bans.
/// In-memory only — resets on app start, never persisted, never touched
/// at launch.
class SiteHealth {
  SiteHealth({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  final Map<String, int> _fails = {};
  final Map<String, DateTime> _openUntil = {};
  final Map<String, int> _lastLatencyMs = {};

  /// Whether [site] is currently skipped by the breaker.
  bool shouldSkip(String site) => _openUntil[site]?.isAfter(_clock()) ?? false;

  /// Remaining back-off for [site]; zero when healthy.
  Duration backoffRemaining(String site) {
    final until = _openUntil[site];
    if (until == null || !until.isAfter(_clock())) return Duration.zero;
    return until.difference(_clock());
  }

  void success(String site, {int? latencyMs}) {
    _fails.remove(site);
    _openUntil.remove(site);
    if (latencyMs != null) _lastLatencyMs[site] = latencyMs;
  }

  void failure(String site, {bool blocked = false}) {
    final n = _fails[site] = (_fails[site] ?? 0) + 1;
    // A behavioral hard block (anti-bot/Cloudflare) backs off immediately
    // and much longer; an ordinary site only opens after 2 failures.
    if (blocked) {
      _openUntil[site] = _clock().add(const Duration(minutes: 30));
      return;
    }
    if (n >= 2) {
      final minutes = 5 * n;
      _openUntil[site] = _clock().add(
        Duration(minutes: minutes.clamp(5, 60)),
      );
    }
  }

  /// Explicit reset (the Retry action) — re-admits [site] immediately.
  void reset(String site) {
    _fails.remove(site);
    _openUntil.remove(site);
  }

  int get failureCount => _fails.values.fold(0, (sum, n) => sum + n);

  /// Sites currently kept out by the breaker.
  List<String> get skippedSites => [
        for (final entry in _openUntil.entries) if (shouldSkip(entry.key)) entry.key,
      ];

  void clearAll() {
    _fails.clear();
    _openUntil.clear();
    _lastLatencyMs.clear();
  }

  int? lastLatencyMs(String site) => _lastLatencyMs[site];
}
