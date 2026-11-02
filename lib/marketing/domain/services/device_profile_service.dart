import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/marketing/domain/entities/device_profile.dart';
import 'package:atlas_app/marketing/domain/services/web_interop.dart';

/// Detects the visitor's OS + CPU architecture on the Flutter Web landing
/// page using, in order of confidence:
///
/// 1. **UA Client Hints** (Chromium) — `navigator.userAgentData
///    .getHighEntropyValues([...])` gives an authoritative `platform`,
///    `architecture` and `bitness` (the only reliable way to see Windows-ARM).
///    NB: Android phones return empty architecture/bitness there, so Android
///    falls through to the platform-string tokens below.
/// 2. **UA-string heuristics** (Safari/Firefox/others) — pattern matching on
///    `navigator.userAgent` / `navigator.platform` / touch points. On Android
///    the frozen UA carries no arch at all; `navigator.platform` is the only
///    signal ("Linux armv8l"/"Linux aarch64" = 64-bit, "Linux armv7l" = 32-bit).
/// 3. Fallback — every failure degrades to `DeviceProfile.fallback` so
///    callers always receive a valid value (never a thrown error).
class DeviceProfileService {
  const DeviceProfileService();

  /// Runs detection. Memoization is the caller's job (providers).
  ///
  /// When [probe] is supplied, no browser is touched — classification is
  /// computed from the given strings. This is the unit-test seam.
  Future<DeviceProfile> detect({DeviceProbe? probe}) async {
    try {
      final effectiveProbe = probe ?? await collectDeviceProbe();
      if (effectiveProbe == null) return DeviceProfile.fallback;
      return classify(effectiveProbe);
    } catch (error) {
      AppLogger.warning('Device detection failed: $error');
      return DeviceProfile.fallback;
    }
  }

  /// Pure classification: maps a [DeviceProbe] onto a [DeviceProfile].
  ///
  /// Precedence (mirrored by tests in `test/marketing/…`):
  /// * UA-CH `platform` beats UA-string sniffing when present.
  /// * UA-CH `architecture` + `bitness` beat any UA-string arch token —
  ///   the only signal that reliably separates Windows-ARM from Windows-x64.
  /// * On Android UA-CH carries no arch at all (Chromium returns empty
  ///   strings); `navigator.platform`'s `armv8l`/`aarch64`/`armv7l` token is
  ///   what decides arm64 vs a genuine 32-bit ARMv7 device.
  /// * Apple-Silicon Safari/Chrome both print a compat "Intel Mac OS X" UA —
  ///   that string is useless on macOS; UA-CH is the only honest source, and
  ///   Safari defaults to arm64 (Apple's modern baseline).
  /// * Windows-ARM vs x64 is separated exclusively by UA-CH `architecture`,
  ///   or a `wow64`/`win64` UA token on x64 builds.
  static DeviceProfile classify(DeviceProbe probe) {
    final os = _classifyOs(probe);
    return DeviceProfile(
      os: os,
      arch: _classifyArch(probe, os),
      osVersion: _classifyOsVersion(probe, os),
    );
  }

  // ---------------------------------------------------------------------------
  // OS classification
  // ---------------------------------------------------------------------------

  static DeviceOs _classifyOs(DeviceProbe probe) {
    final uaPlatform = probe.uaPlatform?.toLowerCase();
    if (uaPlatform != null && uaPlatform.isNotEmpty) {
      if (uaPlatform.contains('windows')) return DeviceOs.windows;
      if (uaPlatform.contains('mac')) return DeviceOs.macos;
      if (uaPlatform.contains('ios')) return DeviceOs.ios;
      if (uaPlatform.contains('android')) return DeviceOs.android;
      if (uaPlatform.contains('chrome os')) return DeviceOs.linux;
    }

    final ua = probe.userAgent.toLowerCase();
    final navPlatform = probe.platform.toLowerCase();

    if (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod')) {
      return DeviceOs.ios;
    }
    // iPadOS ≥ 13 masquerades as desktop Safari: UA says "Macintosh" and
    // navigator.platform remains "MacIntel" — but real macOS has zero touch
    // points. Touch-capable "MacIntel" ⇒ iOS/iPadOS.
    if (navPlatform.contains('mac') && probe.maxTouchPoints > 0) {
      return DeviceOs.ios;
    }
    if (ua.contains('cros') || navPlatform.contains('cros')) {
      return DeviceOs.linux;
    }
    if (ua.contains('android')) return DeviceOs.android;
    if (ua.contains('windows nt') ||
        navPlatform.contains('win') ||
        uaPlatform?.contains('win') == true) {
      return DeviceOs.windows;
    }
    if (ua.contains('mac os x') ||
        ua.contains('macintosh') ||
        navPlatform.contains('mac') ||
        uaPlatform?.contains('mac') == true) {
      return DeviceOs.macos;
    }
    if (ua.contains('linux') ||
        navPlatform.contains('linux') ||
        uaPlatform?.contains('linux') == true) {
      return DeviceOs.linux;
    }
    return DeviceOs.other;
  }

  // ---------------------------------------------------------------------------
  // Architecture classification
  // ---------------------------------------------------------------------------

  static DeviceArch _classifyArch(DeviceProbe probe, DeviceOs os) {
    final uaArchitecture = probe.uaArchitecture?.toLowerCase().trim();
    if (uaArchitecture != null && uaArchitecture.isNotEmpty) {
      final is64 = probe.uaBitness == '64';
      if (uaArchitecture.contains('arm')) {
        return is64 || probe.uaBitness == null
            ? DeviceArch.arm64
            : DeviceArch.unknown;
      }
      if (uaArchitecture.contains('x86')) {
        return is64 ? DeviceArch.x64 : DeviceArch.unknown;
      }
    }

    final ua = probe.userAgent.toLowerCase();
    final navPlatform = probe.platform.toLowerCase();

    // 64-bit ARM tokens first: UA-CH returns *empty* architecture/bitness on
    // Android phones (Chromium's user_agent_utils.cc), and the reduced Android
    // UA carries no arch — so navigator.platform is the only signal there.
    // Chrome on 64-bit Android reports "Linux armv8l" or "Linux aarch64";
    // 32-bit builds report "Linux armv7l".
    if (ua.contains('aarch64') || navPlatform.contains('aarch64')) {
      return DeviceArch.arm64;
    }
    if (ua.contains('armv8') || navPlatform.contains('armv8')) {
      return DeviceArch.arm64;
    }
    if (ua.contains('armv7') || navPlatform.contains('armv7')) {
      return DeviceArch.armv7;
    }
    if (ua.contains('arm64')) return DeviceArch.arm64;
    // Legacy 32-bit ARM without a distinguishing token (plain "arm" in a UA
    // string): honest unknown — the resolver falls back to a universal APK
    // rather than promising a v7a build we can't verify.
    if (os == DeviceOs.android &&
        (ua.contains('arm') || navPlatform.contains('arm'))) {
      return DeviceArch.unknown;
    }

    // x64 hints that are meaningful *per platform* — 'Intel Mac OS X' appears
    // in the UA of Apple-Silicon Macs too (Safari compat), so 'intel' never
    // proves x64 on macOS; Chromium's UA-CH above is the only honest source
    // there, defaulting to arm64 (Apple's modern baseline) when absent.
    if (os == DeviceOs.windows) {
      if (ua.contains('wow64') ||
          ua.contains('win64') ||
          ua.contains('x86_64') ||
          ua.contains('amd64')) {
        return DeviceArch.x64;
      }
    }
    if (os == DeviceOs.linux) {
      if (ua.contains('x86_64') || ua.contains('amd64')) {
        return DeviceArch.x64;
      }
    }
    if (os == DeviceOs.macos) return DeviceArch.arm64;
    return DeviceArch.unknown;
  }

  // ---------------------------------------------------------------------------
  // Friendly version label (best-effort, UA-CH only)
  // ---------------------------------------------------------------------------

  /// Maps the UA-CH `platformVersion` major onto a human label. Desktop-only:
  /// Chromium exposes meaningful versions there; other platforms return ''.
  static String _classifyOsVersion(DeviceProbe probe, DeviceOs os) {
    final raw = probe.uaPlatformVersion?.trim() ?? '';
    if (raw.isEmpty) return '';
    final major = int.tryParse(raw.split('.').first);
    if (major == null) return '';
    return switch (os) {
      DeviceOs.windows => major >= 13 ? 'Windows 11' : 'Windows 10',
      DeviceOs.macos => 'macOS $major',
      _ => '',
    };
  }
}
