import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/browser/domain/entities/browser_session_cookie.dart';
import 'package:atlas_app/browser/infrastructure/repositories/json_browser_session_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('browser_session_repo');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  File sessionFile() =>
      File('${tempDir.path}${Platform.pathSeparator}sessions.json');

  /// Seeds the store the same way the production `_saveOrigin` path does (the
  /// platform cookie-store read in `captureForOrigin` is unavailable in tests),
  /// so `loadForOrigin` exercises the real file shape.
  Future<void> seed(String json) => sessionFile().writeAsString(json);

  group('JsonBrowserSessionRepository', () {
    test('loads a persisted session back by origin', () async {
      final repository = JsonBrowserSessionRepository(file: sessionFile());
      final origin = Uri.parse('https://novelfull.net/legend-of-swordsman.html');
      final future =
          DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch;

      await seed(
        '{"https://novelfull.net/":['
        '{"name":"cf_clearance","value":"abc123","path":"/","expiresDate":$future}'
        ']}',
      );

      final cookies = await repository.loadForOrigin(origin);
      expect(cookies, hasLength(1));
      expect(cookies.single.name, 'cf_clearance');
      expect(cookies.single.value, 'abc123');
      expect(cookies.single.isExpired, isFalse);
    });

    test('drops expired cookies on load', () async {
      final repository = JsonBrowserSessionRepository(file: sessionFile());
      final origin = Uri.parse('https://novelfull.net/');
      final past = DateTime.now()
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      final future =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;

      await seed(
        '{"https://novelfull.net/":['
        '{"name":"stale","value":"1","expiresDate":$past},'
        '{"name":"fresh","value":"2","expiresDate":$future}'
        ']}',
      );

      final cookies = await repository.loadForOrigin(origin);
      expect(cookies.map((c) => c.name), ['fresh']);
    });

    test('scopes cookies by origin (host, not path)', () async {
      final repository = JsonBrowserSessionRepository(file: sessionFile());
      final a = Uri.parse('https://novelfull.net/novel.html');
      final b = Uri.parse('https://readnovelfull.com/novel.html');

      await seed(
        '{"https://novelfull.net/":[{"name":"a","value":"1"}],'
        '"https://readnovelfull.com/":[{"name":"b","value":"2"}]}',
      );

      expect((await repository.loadForOrigin(a)).single.name, 'a');
      expect((await repository.loadForOrigin(b)).single.name, 'b');
    });

    test('missing or malformed files load as empty without throwing', () async {
      final missing = JsonBrowserSessionRepository(
          file: File('${tempDir.path}${Platform.pathSeparator}missing.json'));
      expect(await missing.loadForOrigin(Uri.parse('https://x.com/')), isEmpty);

      await seed('not json at all');
      final malformed = JsonBrowserSessionRepository(file: sessionFile());
      expect(await malformed.loadForOrigin(Uri.parse('https://x.com/')), isEmpty);
    });

    test('session cookies (no expiry) survive the JSON round-trip', () async {
      const cookie = BrowserSessionCookie(
        name: 'sid',
        value: 'xyz',
        domain: '.novelfull.net',
        path: '/',
        isHttpOnly: true,
      );
      final restored = BrowserSessionCookie.fromJson(
          Map<String, Object?>.from(cookie.toJson()));
      expect(restored.name, 'sid');
      expect(restored.value, 'xyz');
      expect(restored.domain, '.novelfull.net');
      expect(restored.path, '/');
      expect(restored.isHttpOnly, isTrue);
      expect(restored.isExpired, isFalse);
    });
  });
}
