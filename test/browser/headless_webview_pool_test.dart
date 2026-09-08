import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/browser/domain/services/headless_webview_pool.dart';
import 'silent_web_view_service_test.dart';

void main() {
  group('HeadlessWebViewPool', () {
    final origin1 = Uri.parse('https://example.com/ch1');
    final origin2 = Uri.parse('https://novelfull.net/ch1');
    final origin3 = Uri.parse('https://royalroad.com/ch1');

    test('reuses existing engine for the same origin', () async {
      var enginesCreated = 0;
      final pool = HeadlessWebViewPool(
        maxViews: 3,
        engineFactory: ({initialUrl}) {
          enginesCreated++;
          return FakeBackgroundEngine();
        },
      );

      final e1 = await pool.acquire(origin1);
      final e2 = await pool.acquire(origin1);

      expect(identical(e1, e2), isTrue);
      expect(enginesCreated, 1);

      pool.release(origin1);
      pool.release(origin1);
      pool.dispose();
    });

    test('creates distinct engines for different origins up to maxViews', () async {
      var enginesCreated = 0;
      final pool = HeadlessWebViewPool(
        maxViews: 3,
        engineFactory: ({initialUrl}) {
          enginesCreated++;
          return FakeBackgroundEngine();
        },
      );

      final e1 = await pool.acquire(origin1);
      final e2 = await pool.acquire(origin2);

      expect(identical(e1, e2), isFalse);
      expect(enginesCreated, 2);
      expect(pool.size, 2);

      pool.release(origin1);
      pool.release(origin2);
      pool.dispose();
    });

    test('evicts least-recently-used idle engine when maxViews is exceeded', () async {
      final pool = HeadlessWebViewPool(
        maxViews: 2,
        engineFactory: ({initialUrl}) => FakeBackgroundEngine(),
      );

      final e1 = await pool.acquire(origin1) as FakeBackgroundEngine;
      await pool.acquire(origin2);
      expect(pool.size, 2);

      // Release e1 so it becomes idle and eligible for eviction
      pool.release(origin1);

      // Acquire origin3, which exceeds maxViews (2) and evicts idle e1
      await pool.acquire(origin3);
      expect(pool.size, 2);
      expect(pool.hasOrigin(origin1), isFalse);
      expect(pool.hasOrigin(origin2), isTrue);
      expect(pool.hasOrigin(origin3), isTrue);
      expect(e1.disposed, isTrue);

      pool.release(origin2);
      pool.release(origin3);
      pool.dispose();
    });

    test('dispose disposes all pooled engines', () async {
      final engines = <FakeBackgroundEngine>[];
      final pool = HeadlessWebViewPool(
        maxViews: 3,
        engineFactory: ({initialUrl}) {
          final engine = FakeBackgroundEngine();
          engines.add(engine);
          return engine;
        },
      );

      await pool.acquire(origin1);
      await pool.acquire(origin2);
      expect(engines, hasLength(2));

      pool.dispose();
      for (final e in engines) {
        expect(e.disposed, isTrue);
      }
      expect(pool.size, 0);
    });
  });
}
