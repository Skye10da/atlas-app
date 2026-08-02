/// `permissions.json` — per-site rate-limiting and politeness policy, kept
/// separate from `plugin.json` so it can be tightened centrally without
/// touching the identity/routing manifest.
class PluginPermissions {
  const PluginPermissions({
    this.allowOfflineCache = true,
    this.maxConcurrentRequests = 2,
    this.requestDelayMs = const [800, 2000],
    this.respectRobotsTxt = true,
  });

  factory PluginPermissions.fromJson(Map<String, Object?> json) {
    final delays = json['requestDelayMs'];
    return PluginPermissions(
      allowOfflineCache: _bool(json['allowOfflineCache'], true),
      maxConcurrentRequests: _int(json['maxConcurrentRequests'], 2),
      requestDelayMs: delays is List
          ? delays.whereType<num>().map((e) => e.toInt()).toList()
          : const [800, 2000],
      respectRobotsTxt: _bool(json['respectRobotsTxt'], true),
    );
  }

  final bool allowOfflineCache;
  final int maxConcurrentRequests;

  /// Min/max jitter range in milliseconds, used by StealthTransport.
  final List<int> requestDelayMs;

  final bool respectRobotsTxt;

  Map<String, Object?> toJson() => {
        'allowOfflineCache': allowOfflineCache,
        'maxConcurrentRequests': maxConcurrentRequests,
        'requestDelayMs': requestDelayMs,
        'respectRobotsTxt': respectRobotsTxt,
      };

  static bool _bool(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;
}
