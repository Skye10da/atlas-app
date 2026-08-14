/// Non-sensitive metadata describing the current WTR-Lab account connection.
///
/// **Deliberately contains no credentials.** No cookies, tokens or passwords
/// are ever persisted here — WTR session credentials live only in the
/// platform WebView cookie store (the OS-backed browser session storage) and
/// in the app's existing per-origin browser-session repository, which Atlas
/// already uses to persist Cloudflare-style browser sessions. This record is
/// the app-facing *fact* that such a session exists, so the UI can restore the
/// "connected" state across restarts.
class WtrSessionRecord {
  const WtrSessionRecord({
    required this.authenticated,
    this.connectedAt,
  });

  factory WtrSessionRecord.fromJson(Map<String, Object?> json) =>
      WtrSessionRecord(
        authenticated: json['authenticated'] == true,
        connectedAt: json['connectedAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch((json['connectedAt'] as num).toInt())
            : null,
      );

  /// True when a usable session was last captured.
  final bool authenticated;

  /// When the session was captured (or last validated), epoch millis.
  final DateTime? connectedAt;

  Map<String, Object?> toJson() => {
        'authenticated': authenticated,
        if (connectedAt != null) 'connectedAt': connectedAt!.millisecondsSinceEpoch,
      };
}
