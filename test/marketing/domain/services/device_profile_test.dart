import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/marketing/domain/entities/device_profile.dart';
import 'package:atlas_app/marketing/domain/services/device_profile_service.dart';

DeviceProbe probe({
  String userAgent = '',
  String platform = '',
  String? uaPlatform,
  String? uaPlatformVersion,
  String? uaArchitecture,
  String? uaBitness,
  int maxTouchPoints = 0,
}) => DeviceProbe(
  userAgent: userAgent,
  platform: platform,
  uaPlatform: uaPlatform,
  uaPlatformVersion: uaPlatformVersion,
  uaArchitecture: uaArchitecture,
  uaBitness: uaBitness,
  maxTouchPoints: maxTouchPoints,
);

void main() {
  group('OS classification — UA-string matrix', () {
    const windowsChromeUA =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
    const macSafariUA =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15';
    const androidChromeUA =
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';
    const iPhoneSafariUA =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1';
    const linuxFirefoxUA =
        'Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0';

    test('Windows Chrome', () {
      final profile = DeviceProfileService.classify(
        probe(userAgent: windowsChromeUA, platform: 'Win32'),
      );
      expect(profile.os, DeviceOs.windows);
      expect(profile.arch, DeviceArch.x64); // x64 token + Intel in UA
      expect(profile.summary, 'Windows (x64)');
    });

    test(
      'Apple-silicon Safari → arm64 (UA compat "Intel Mac OS X" ignored)',
      () {
        final profile = DeviceProfileService.classify(
          probe(userAgent: macSafariUA, platform: 'MacIntel'),
        );
        expect(profile.os, DeviceOs.macos);
        expect(profile.arch, DeviceArch.arm64);
        expect(profile.summary, 'macOS (Apple silicon)');
      },
    );

    test('Intel Mac is only knowable through UA-CH (Chromium)', () {
      final profile = DeviceProfileService.classify(
        probe(
          // Plain Safari UA — indistinguishable from Apple silicon in strings.
          userAgent: macSafariUA,
          platform: 'MacIntel',
        ),
      );
      expect(profile.arch, DeviceArch.arm64);
    });

    test('Android Chrome', () {
      final profile = DeviceProfileService.classify(
        probe(userAgent: androidChromeUA, platform: 'Linux armv8l'),
      );
      expect(profile.os, DeviceOs.android);
    });

    test('iPhone Safari', () {
      final profile = DeviceProfileService.classify(
        probe(userAgent: iPhoneSafariUA, platform: 'iPhone'),
      );
      expect(profile.os, DeviceOs.ios);
    });

    test('iPad desktop-masquerade: MacIntel + touch points ⇒ iPadOS', () {
      final profile = DeviceProfileService.classify(
        probe(
          userAgent:
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15',
          platform: 'MacIntel',
          maxTouchPoints: 5,
        ),
      );
      expect(profile.os, DeviceOs.ios);
    });

    test('Linux Firefox', () {
      final profile = DeviceProfileService.classify(
        probe(userAgent: linuxFirefoxUA, platform: 'Linux x86_64'),
      );
      expect(profile.os, DeviceOs.linux);
      expect(profile.arch, DeviceArch.x64);
    });

    test('ChromeOS routes to Linux lineage', () {
      final profile = DeviceProfileService.classify(
        probe(
          userAgent:
              'Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
          platform: 'Linux x86_64',
        ),
      );
      expect(profile.os, DeviceOs.linux);
    });
  });

  group('UA Client Hints precedence', () {
    test('UA-CH platform + architecture override UA ambiguity (Windows ARM)', () {
      final profile = DeviceProfileService.classify(
        probe(
          userAgent:
              'Mozilla/5.0 (Windows NT 10.0; Win64; ARM) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          platform: 'Win32',
          uaPlatform: 'Windows',
          uaPlatformVersion: '15.0.0',
          uaArchitecture: 'arm',
          uaBitness: '64',
        ),
      );
      expect(profile.os, DeviceOs.windows);
      expect(profile.arch, DeviceArch.arm64);
      expect(profile.osVersion, 'Windows 11');
    });

    test('UA-CH x86 + bitness 64 → x64 even when UA strings are missing', () {
      final profile = DeviceProfileService.classify(
        probe(
          userAgent: 'empty/1.0',
          platform: '',
          uaPlatform: 'Windows',
          uaPlatformVersion: '10.0.0',
          uaArchitecture: 'x86',
          uaBitness: '64',
        ),
      );
      expect(profile.os, DeviceOs.windows);
      expect(profile.arch, DeviceArch.x64);
      expect(profile.osVersion, 'Windows 10');
    });

    test('UA-CH beats a stale UA platform hint (mac semantics)', () {
      final profile = DeviceProfileService.classify(
        probe(
          userAgent:
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15',
          platform: 'MacIntel',
          uaPlatform: 'macOS',
          uaPlatformVersion: '15.4.1',
          uaArchitecture: 'arm',
          uaBitness: '64',
        ),
      );
      expect(profile.os, DeviceOs.macos);
      expect(profile.arch, DeviceArch.arm64);
      expect(profile.osVersion, 'macOS 15');
    });

    test('Bitness unknown + arm architecture still resolves arm64', () {
      final profile = DeviceProfileService.classify(
        probe(
          userAgent: 'test/1.0',
          platform: '',
          uaPlatform: 'Windows',
          uaArchitecture: 'arm',
        ),
      );
      expect(profile.arch, DeviceArch.arm64);
    });

    test('32-bit x86 degrades honestly to unknown instead of wrong build', () {
      final profile = DeviceProfileService.classify(
        probe(
          userAgent: 'very-old/1.0',
          platform: '',
          uaPlatform: 'Windows',
          uaArchitecture: 'x86',
          uaBitness: '32',
        ),
      );
      expect(profile.arch, DeviceArch.unknown);
    });
  });

  group('Robust fallback', () {
    test('blank probe → DeviceProfile.fallback, never throws', () {
      final profile = DeviceProfileService.classify(probe());
      expect(profile.os, DeviceOs.other);
      expect(profile.isDetected, isFalse);
      expect(profile.summary, 'this device');
    });

    test(
      'detect({probe: … }) with a browser probe classifies directly',
      () async {
        final profile = await const DeviceProfileService().detect(
          probe: probe(
            userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) test',
            platform: 'Win32',
          ),
        );
        expect(profile.os, DeviceOs.windows);
      },
    );
  });
}
