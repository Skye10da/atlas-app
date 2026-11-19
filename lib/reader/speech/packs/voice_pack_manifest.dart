/// CDN voice-pack catalog models (NTD §3.5, M5).
///
/// The CDN serves one catalog JSON describing voice **families** — one human
/// voice (e.g. "Amy") — each offering downloadable **flavors** (quality tiers,
/// e.g. low/medium/high piper variants). Flavors are separate packs on disk
/// (`vits-piper-en_US-amy-low`) but one row in the gallery, which is why the
/// catalog groups them instead of listing packs flat.
///
/// Manifest format (v1):
/// ```json
/// {
///   "schemaVersion": 1,
///   "updatedUtc": "2026-11-15T00:00:00Z",
///   "families": [
///     {
///       "id": "piper-en_US-amy",
///       "name": "Amy",
///       "language": "en",
///       "locale": "en-US",
///       "gender": "female",
///       "previewUrl": "https://…/previews/amy.ogg",
///       "flavors": [
///         {
///           "quality": "standard",
///           "packId": "vits-piper-en_US-amy-medium",
///           "sizeBytes": 81199160,
///           "modelFormatVersion": 1,
///           "files": {"en_US-amy-medium.onnx": {"sha256": "…"},
///                     "tokens.txt": {"sha256": "…"}}
///         }
///       ]
///     }
///   ]
///   }
/// ```
library;

import 'dart:convert';

/// Quality tiers shown in the gallery. Order matters: it is the default
/// sort within a family (compact first, so a tap downloads the smallest
/// reasonable variant unless the user picks otherwise).
enum VoicePackQuality { compact, standard, best }

extension VoicePackQualityLabel on VoicePackQuality {
  String get label => switch (this) {
    VoicePackQuality.compact => 'Compact',
    VoicePackQuality.standard => 'Standard',
    VoicePackQuality.best => 'Best',
  };
}

/// One downloadable quality variant of a voice family.
class VoicePackFlavor {
  const VoicePackFlavor({
    required this.quality,
    required this.packId,
    required this.sizeBytes,
    required this.files,
    required this.modelFormatVersion,
    this.minAppVersion,
  });

  factory VoicePackFlavor.fromJson(Map<String, dynamic> json) {
    final qualityName = json['quality'] as String? ?? 'standard';
    final quality = VoicePackQuality.values.firstWhere(
      (q) => q.name == qualityName,
      orElse: () => VoicePackQuality.standard,
    );
    final files = <String, String>{};
    final rawFiles = json['files'];
    if (rawFiles is Map<String, dynamic>) {
      rawFiles.forEach((name, spec) {
        final sha = spec is Map<String, dynamic> ? spec['sha256'] : null;
        if (sha is String && name.isNotEmpty) files[name] = sha;
      });
    }
    return VoicePackFlavor(
      quality: quality,
      packId: json['packId'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      files: Map.unmodifiable(files),
      modelFormatVersion: (json['modelFormatVersion'] as num?)?.toInt() ?? 1,
      minAppVersion: json['minAppVersion'] as String?,
    );
  }

  final VoicePackQuality quality;
  final String packId;
  final int sizeBytes;

  /// sha256 per required file name; the downloader verifies every entry
  /// before activation (empty map = unverified flavor, rejected).
  final Map<String, String> files;
  final int modelFormatVersion;
  final String? minAppVersion;

  bool get isValid =>
      packId.isNotEmpty &&
      sizeBytes > 0 &&
      files.isNotEmpty &&
      !files.containsKey('');
}

/// One human voice with its downloadable variants.
class VoicePackFamily {
  VoicePackFamily({
    required this.id,
    required this.name,
    required String language,
    required this.locale,
    required List<VoicePackFlavor> flavors,
    this.gender,
    this.previewUrl,
  }) : language = language.toLowerCase(),
       _flavors = List.unmodifiable(flavors);

  factory VoicePackFamily.fromJson(Map<String, dynamic> json) {
    final rawFlavors = json['flavors'];
    final flavors = rawFlavors is List
        ? rawFlavors
              .whereType<Map<String, dynamic>>()
              .map(VoicePackFlavor.fromJson)
              .toList()
        : <VoicePackFlavor>[];
    return VoicePackFamily(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      language: (json['language'] as String? ?? '').toLowerCase(),
      locale: json['locale'] as String? ?? '',
      gender: json['gender'] as String?,
      previewUrl: json['previewUrl'] as String?,
      flavors: flavors,
    );
  }

  final String id;
  final String name;
  final String language;
  final String locale;
  final String? gender;

  /// Small (~100 KB) sample clip, played before any download decision.
  final String? previewUrl;

  final List<VoicePackFlavor> _flavors;

  /// Valid flavors only (the downloader refuses malformed ones); sorted by
  /// quality order [VoicePackQuality] then size.
  List<VoicePackFlavor> get flavors {
    final sorted = [..._flavors]..sort((a, b) {
      final byQuality = a.quality.index.compareTo(b.quality.index);
      if (byQuality != 0) return byQuality;
      return a.sizeBytes.compareTo(b.sizeBytes);
    });
    return sorted;
  }

  VoicePackFlavor? flavor(VoicePackQuality quality) =>
      flavors.where((f) => f.quality == quality).firstOrNull;

  bool get isValid => id.isNotEmpty && name.isNotEmpty && flavors.isNotEmpty;
}

/// The whole catalog document.
class VoicePackCatalog {
  const VoicePackCatalog({
    required this.schemaVersion,
    required this.families,
    this.updatedUtc,
  });

  factory VoicePackCatalog.fromJson(Map<String, dynamic> json) {
    final rawFamilies = json['families'];
    final families = rawFamilies is List
        ? rawFamilies
              .whereType<Map<String, dynamic>>()
              .map(VoicePackFamily.fromJson)
              .where((f) => f.isValid)
              .toList()
        : <VoicePackFamily>[];
    return VoicePackCatalog(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      families: List.unmodifiable(families),
      updatedUtc: json['updatedUtc'] as String?,
    );
  }

  static VoicePackCatalog? tryDecode(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final catalog = VoicePackCatalog.fromJson(json);
      return catalog.schemaVersion <= kVoicePackSchemaVersion ? catalog : null;
    } catch (_) {
      return null;
    }
  }

  final int schemaVersion;
  final List<VoicePackFamily> families;
  final String? updatedUtc;

  VoicePackFamily? family(String id) =>
      families.where((f) => f.id == id).firstOrNull;

  /// The pack id a [family] resolves to for [quality], falling back to the
  /// family's first flavor when the exact tier is absent.
  VoicePackFlavor? resolveFlavor(
    String familyId,
    VoicePackQuality quality,
  ) {
    final family = this.family(familyId);
    if (family == null) return null;
    return family.flavor(quality) ??
        (family.flavors.isNotEmpty ? family.flavors.first : null);
  }
}

/// Human-readable download size for gallery chips ("23 MB", "810 KB").
extension VoicePackFlavorSize on VoicePackFlavor {
  String get sizeLabel {
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1) {
      return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
    }
    return '${(sizeBytes / 1024).round()} KB';
  }
}

/// Highest schema this build understands; a newer CDN answers an old client
/// with a *forward-compatible* nothing (the parser rejects it and the UI
/// keeps its cached catalog), preventing mis-downloads.
const int kVoicePackSchemaVersion = 1;

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
