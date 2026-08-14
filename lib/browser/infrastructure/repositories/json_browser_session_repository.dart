import 'dart:convert';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/browser/domain/entities/browser_session_cookie.dart';
import 'package:atlas_app/browser/domain/repository_interfaces/browser_session_repository_interface.dart';
import 'package:atlas_app/core/logging/logger.dart';

/// JSON-file backing for [BrowserSessionRepositoryInterface]. Cookies are
/// keyed by origin (`scheme://host[:port]`) in `<support>/browser_sessions.json`
/// so a restart can re-seed the same-origin set into the platform store.
///
/// Both [captureForOrigin] and [loadForOrigin] are best-effort: a missing or
/// unreadable file, a platform cookie-store failure, or a test environment
/// without a plugin channel degrades to no-op instead of throwing.
class JsonBrowserSessionRepository implements BrowserSessionRepositoryInterface {
  JsonBrowserSessionRepository({File? file}) : _file = file;

  final File? _file;

  Future<File> _fileHandle() async {
    final fixed = _file;
    if (fixed != null) return fixed;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}browser_sessions.json');
  }

  @override
  Future<void> captureForOrigin(Uri origin) async {
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri.uri(origin),
      );
      if (cookies.isEmpty) return;
      final persisted = cookies
          .map(_fromWebCookie)
          .where((c) => !c.isExpired)
          .toList();
      if (persisted.isEmpty) return;
      await _saveOrigin(_originKey(origin), persisted);
    } on Object catch (e) {
      AppLogger.warning('Failed to capture browser session for $origin: $e');
    }
  }

  @override
  Future<List<BrowserSessionCookie>> loadForOrigin(Uri origin) async {
    try {
      final cookies = await _readAll();
      return (cookies[_originKey(origin)] ?? const <BrowserSessionCookie>[])
          .where((c) => !c.isExpired)
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> _saveOrigin(
    String origin,
    List<BrowserSessionCookie> cookies,
  ) async {
    final file = await _fileHandle();
    final all = await _readAll();
    all[origin] = cookies;
    _pruneExpired(all);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_encodeAll(all)));
  }

  /// Drops expired dated cookies across every stored origin so the persisted
  /// session file doesn't accumulate dead entries (they are re-filtered on
  /// load too, but pruning here keeps the file from growing stale forever).
  void _pruneExpired(Map<String, List<BrowserSessionCookie>> all) {
    all.removeWhere((_, cookies) {
      cookies.removeWhere((c) => c.isExpired);
      return cookies.isEmpty;
    });
  }

  Future<Map<String, List<BrowserSessionCookie>>> _readAll() async {
    final file = await _fileHandle();
    if (!await file.exists()) return {};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) return {};
    final result = <String, List<BrowserSessionCookie>>{};
    for (final entry in decoded.entries) {
      final raw = entry.value;
      if (raw is! List) continue;
      result[entry.key.toString()] = raw
          .whereType<Map>()
          .map((m) => BrowserSessionCookie.fromJson(
              Map<String, Object?>.from(m)))
          .toList();
    }
    return result;
  }

  Map<String, Object?> _encodeAll(
    Map<String, List<BrowserSessionCookie>> all,
  ) =>
      all.map(
          (origin, cookies) => MapEntry(origin, cookies.map((c) => c.toJson()).toList()));

  /// The store returns cookies for the exact origin queried, so scoping the
  /// key to `scheme://host[:port]` keeps the captured set stable regardless of
  /// the path that triggered the snapshot.
  String _originKey(Uri origin) => origin
      .replace(path: '/', query: null, fragment: null)
      .toString();

  BrowserSessionCookie _fromWebCookie(Cookie cookie) => BrowserSessionCookie(
        name: cookie.name,
        value: cookie.value is String ? cookie.value as String : '${cookie.value}',
        domain: cookie.domain,
        path: cookie.path,
        expiresDate: cookie.expiresDate,
        isSecure: cookie.isSecure ?? false,
        isHttpOnly: cookie.isHttpOnly ?? false,
      );
}
