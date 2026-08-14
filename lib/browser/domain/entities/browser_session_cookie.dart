/// A cookie captured from the platform WebView's cookie store for a single
/// origin and persisted on disk, so a background web view can re-seed the
/// store after an app restart (Cloudflare `cf_clearance` and friends).
///
/// Kept free of any engine-specific types; the bridge from flutter_inappwebview's
/// [Cookie] lives in the infrastructure repository.
class BrowserSessionCookie {
  const BrowserSessionCookie({
    required this.name,
    required this.value,
    this.domain,
    this.path,
    this.expiresDate,
    this.isSecure = false,
    this.isHttpOnly = false,
  });

  factory BrowserSessionCookie.fromJson(Map<String, Object?> json) =>
      BrowserSessionCookie(
        name: json['name'] as String? ?? '',
        value: json['value'] as String? ?? '',
        domain: json['domain'] as String?,
        path: json['path'] as String?,
        expiresDate: json['expiresDate'] as int?,
        isSecure: json['secure'] as bool? ?? false,
        isHttpOnly: json['httpOnly'] as bool? ?? false,
      );

  final String name;
  final String value;

  /// Cookie's scope domain (may be absent from a store lookup).
  final String? domain;

  /// Cookie path; absent reads as `/` when re-seeded.
  final String? path;

  /// Expiration as epoch milliseconds; `null` is a session cookie.
  final int? expiresDate;
  final bool isSecure;
  final bool isHttpOnly;

  /// A dated cookie past its expiry is useless to replay.
  bool get isExpired {
    final expires = expiresDate;
    if (expires == null) return false;
    return DateTime.now().millisecondsSinceEpoch > expires;
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'value': value,
        if (domain != null) 'domain': domain,
        if (path != null) 'path': path,
        if (expiresDate != null) 'expiresDate': expiresDate,
        'secure': isSecure,
        'httpOnly': isHttpOnly,
      };
}
