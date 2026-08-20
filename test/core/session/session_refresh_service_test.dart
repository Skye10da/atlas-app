import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/session/session_refresh_service.dart';

void main() {
  final session = SessionRefreshService.instance;

  setUp(() => session.clearInvalid());

  group('SessionRefreshService', () {
    test('originOf reduces a URL to its origin and nulls unparsable input', () {
      expect(
        SessionRefreshService.originOf(
          'https://novelfull.net/the-99th.html',
        )?.toString(),
        'https://novelfull.net/',
      );
      expect(SessionRefreshService.originOf('not a url'), isNull);
      expect(SessionRefreshService.originOf(null), isNull);
    });

    test('sameOrigin compares scheme, host and port', () {
      expect(
        SessionRefreshService.sameOrigin(
          Uri.parse('https://novelfull.net/x'),
          Uri.parse('https://novelfull.net/y'),
        ),
        isTrue,
      );
      expect(
        SessionRefreshService.sameOrigin(
          Uri.parse('https://novelfull.net/x'),
          Uri.parse('https://other.net/y'),
        ),
        isFalse,
      );
    });

    test('markInvalid latches the origin; clearInvalid resets it', () {
      final origin = Uri.parse('https://novelfull.net/');
      expect(session.lastInvalidOrigin.value, isNull);

      session.markInvalid(origin);
      expect(session.lastInvalidOrigin.value, origin);
      expect(session.lastInvalidSeedUrl.value, isNull);

      session.clearInvalid();
      expect(session.lastInvalidOrigin.value, isNull);
      expect(session.lastInvalidSeedUrl.value, isNull);
    });

    test('markInvalid latches an optional seed URL and keeps it in sync', () {
      final origin = Uri.parse('https://novelfull.net/');
      final seed = Uri.parse('https://novelfull.net/the-99th.html');

      session.markInvalid(origin, seedUrl: seed);
      expect(session.lastInvalidOrigin.value, origin);
      expect(session.lastInvalidSeedUrl.value, seed);

      session.markInvalid(origin);
      expect(
        session.lastInvalidSeedUrl.value,
        isNull,
        reason: 'a wall without a seed URL must not leak a stale one',
      );

      session.clearInvalid();
      expect(session.lastInvalidSeedUrl.value, isNull);
    });

    test(
      'markInvalid latches a verification probe and clears it with the latch',
      () {
        final origin = Uri.parse('https://wtr-lab.com/');
        Future<bool> probe() async => true;

        session.markInvalid(origin, verificationProbe: probe);
        expect(session.lastInvalidVerificationProbe, probe);

        session.markInvalid(origin);
        expect(
          session.lastInvalidVerificationProbe,
          isNull,
          reason: 'a wall without a probe must not leak a stale one',
        );

        session.markInvalid(origin, verificationProbe: probe);
        session.clearInvalid();
        expect(session.lastInvalidVerificationProbe, isNull);
      },
    );

    test('hasAutoRefreshed / markAutoRefreshed gate one-shot auto refresh', () {
      final origin = Uri.parse('https://novelfull.net/');
      expect(session.hasAutoRefreshed(origin), isFalse);

      session.markAutoRefreshed(origin);
      expect(session.hasAutoRefreshed(origin), isTrue);

      session.clearInvalid();
      expect(session.hasAutoRefreshed(origin), isFalse);
    });

    test('ensureFresh runs the driver and clears the latch', () async {
      final origin = Uri.parse('https://novelfull.net/');
      final seedUrl = Uri.parse('https://novelfull.net/the-99th.html');
      SessionRefreshRequest? seen;
      session.driver = (request) async {
        seen = request;
        return true;
      };

      final ok = await session.ensureFresh(origin, seedUrl: seedUrl);

      expect(ok, isTrue);
      expect(seen?.origin, origin);
      expect(seen?.seedUrl, seedUrl);
      expect(session.lastInvalidOrigin.value, isNull);
    });

    test(
      'ensureFresh forwards a latched verification probe to the driver',
      () async {
        final origin = Uri.parse('https://wtr-lab.com/');
        Future<bool> probe() async => true;
        session.markInvalid(origin, verificationProbe: probe);
        SessionRefreshRequest? seen;
        session.driver = (request) async {
          seen = request;
          return true;
        };

        await session.ensureFresh(origin);

        expect(seen?.verificationProbe, probe);
      },
    );

    test('ensureFresh returns false and clears the latch when no driver is '
        'installed', () async {
      final origin = Uri.parse('https://novelfull.net/');
      session.markInvalid(origin);
      session.markAutoRefreshed(origin);
      session.driver = null;

      final ok = await session.ensureFresh(origin);

      expect(ok, isFalse);
      expect(session.lastInvalidOrigin.value, isNull);
      expect(
        session.hasAutoRefreshed(origin),
        isFalse,
        reason: 'a cleared latch must not leave stale one-shot gates',
      );
    });
  });
}
