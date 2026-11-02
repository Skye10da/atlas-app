import 'package:flutter/foundation.dart';

/// The desktop/mobile OS the visitor's device runs, as far as the landing page
/// can know it. [other] means detection degraded (unknown UA, native target,
/// or a non-device context) and users are offered the full asset list.
enum DeviceOs { windows, macos, linux, android, ios, other }

/// CPU architecture as *reported by the browser*. This describes the client
/// device, not the build we might download for it — the resolver decides
/// which artifact fits. [armv7] is a genuine 32-bit ARM device (Android
/// `navigator.platform` "Linux armv7l"); [arm64] covers aarch64/armv8.
enum DeviceArch { x64, arm64, armv7, unknown }

/// Immutable input collected from the browser before classification.
///
/// Kept dependency-free (plain strings) so tests can feed synthetic probes
/// without any web plumbing.
@immutable
class DeviceProbe {
  const DeviceProbe({
    required this.userAgent,
    required this.platform,
    this.uaPlatform,
    this.uaPlatformVersion,
    this.uaArchitecture,
    this.uaBitness,
    this.maxTouchPoints = 0,
  });

  /// `navigator.userAgent` (empty string is allowed).
  final String userAgent;

  /// `navigator.platform` (also acceptable to pass the UA-CH platform).
  final String platform;

  /// UA-CH high-entropy `platform` (e.g. "Windows", "macOS"), when available.
  final String? uaPlatform;

  /// UA-CH high-entropy `platformVersion` (e.g. "13.0.0"), when available.
  final String? uaPlatformVersion;

  /// UA-CH high-entropy `architecture` (e.g. "x86", "arm"), when available.
  final String? uaArchitecture;

  /// UA-CH high-entropy `bitness` ("32" | "64"), when available.
  final String? uaBitness;

  /// `navigator.maxTouchPoints`, when available (web). The only signal that
  /// distinguishes iPadOS-≥13 desktop-masquerade Safari from real macOS
  /// (iPads report `MacIntel` + touch points > 0).
  final int maxTouchPoints;

  /// Merges collected UA-CH hint strings onto a base probe. Every field is
  /// optional because the collector skips unsupported hints per browser.
  DeviceProbe hinted({
    String? platform,
    String? platformVersion,
    String? architecture,
    String? bitness,
  }) => DeviceProbe(
    userAgent: userAgent,
    platform: this.platform,
    uaPlatform: platform,
    uaPlatformVersion: platformVersion,
    uaArchitecture: architecture,
    uaBitness: bitness,
    maxTouchPoints: maxTouchPoints,
  );
}

/// The landing-page visitor's device, used to auto-select the correct
/// release artifact (see `release_asset_resolver.dart` for the matching
/// contract and `docs/plans/landing_upgrade_plan.md` for the strategy).
@immutable
class DeviceProfile {
  const DeviceProfile({
    required this.os,
    required this.arch,
    required this.osVersion,
  });

  /// Graceful degradation used when detection is unavailable or fails; every
  /// UI built on a fallback profile renders the complete chooser instead of
  /// a guess.
  static const DeviceProfile fallback = DeviceProfile(
    os: DeviceOs.other,
    arch: DeviceArch.unknown,
    osVersion: '',
  );

  final DeviceOs os;
  final DeviceArch arch;

  /// Short human version ("Windows 11", "macOS 14", …) when UA-CH exposes a
  /// platform version; empty string otherwise.
  final String osVersion;

  /// False when detection degraded to [DeviceOs.other]; callers then surface
  /// the full platform chooser instead of a claimed match.
  bool get isDetected => os != DeviceOs.other;

  /// "Windows (x64)" / "macOS (Apple silicon)" / "iOS" — the string shown in
  /// micro-copy and smart-button labels.
  String get summary {
    final osLabel = switch (os) {
      DeviceOs.windows => 'Windows',
      DeviceOs.macos => 'macOS',
      DeviceOs.linux => 'Linux',
      DeviceOs.android => 'Android',
      DeviceOs.ios => 'iOS',
      DeviceOs.other => 'this device',
    };
    if (os == DeviceOs.macos && arch == DeviceArch.arm64) {
      return 'macOS (Apple silicon)';
    }
    final archLabel = switch (arch) {
      DeviceArch.x64 => ' (x64)',
      DeviceArch.arm64 => ' (ARM64)',
      DeviceArch.armv7 => ' (ARMv7)',
      DeviceArch.unknown => '',
    };
    return '$osLabel$archLabel';
  }

  @override
  String toString() => 'DeviceProfile($summary)';
}
