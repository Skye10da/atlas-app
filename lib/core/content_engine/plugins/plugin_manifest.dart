import 'package:atlas_app/core/content_engine/plugins/verification.dart';

/// A capability a plugin can declare. Manifests declare what they support;
/// templates declare what they implement; `PluginSource` bridges the two and
/// fails fast when a declared capability isn't available.
enum PluginCapability {
  search,
  chapterList,
  chapterContent,
  cover,
}

PluginCapability? _capabilityFromName(String name) {
  for (final capability in PluginCapability.values) {
    if (capability.name == name) return capability;
  }
  return null;
}

class PluginManifestException implements Exception {
  const PluginManifestException(this.message);

  final String message;

  @override
  String toString() => 'PluginManifestException: $message';
}

/// A plugin manifest (`plugin.json`). Pure data — `templateId` is the only
/// thing that determines which compiled template interprets this manifest;
/// everything else is data consumed by that template. The manifest itself
/// carries no logic.
class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.sourceName,
    required this.version,
    required this.templateId,
    required this.baseUrl,
    this.transport = 'http',
    this.language = 'en',
    this.customUserAgent,
    this.customImageHeaders = const {},
    this.capabilities = const [
      PluginCapability.search,
      PluginCapability.chapterList,
      PluginCapability.chapterContent,
      PluginCapability.cover,
    ],
    this.selectorsFile = 'selectors.json',
    this.filtersFile = 'filters.json',
    this.permissionsFile = 'permissions.json',
    this.extraStripSelectors = const [],
    this.requiresJsRendering = false,
  });

  factory PluginManifest.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const PluginManifestException(
        'plugin.json must have a non-empty "id"',
      );
    }
    final templateId = json['templateId'];
    if (templateId is! String || templateId.isEmpty) {
      throw const PluginManifestException(
        'plugin.json must have a non-empty "templateId"',
      );
    }
    final versionRaw = json['version'];
    if (versionRaw is! String) {
      throw const PluginManifestException(
        'plugin.json must have a semver "version"',
      );
    }
    final version = PluginVersion.tryParse(versionRaw);
    if (version == null) {
      throw PluginManifestException(
        'plugin.json "version" "$versionRaw" is not valid semver',
      );
    }
    final baseUrl = json['baseUrl'];
    if (baseUrl is! String || Uri.tryParse(baseUrl) == null) {
      throw const PluginManifestException(
        'plugin.json must have a valid "baseUrl"',
      );
    }
    final name = json['name'];
    final sourceName = json['sourceName'];
    final transport = json['transport'];
    final language = json['language'];
    final userAgent = json['customUserAgent'];
    final imageHeaders = json['customImageHeaders'];
    final extraStrips = json['extraStripSelectors'];
    final requiresJs = json['requiresJsRendering'];

    final capabilities = <PluginCapability>[];
    final rawCapabilities = json['capabilities'];
    if (rawCapabilities is List) {
      for (final raw in rawCapabilities) {
        if (raw is! String) {
          throw const PluginManifestException(
            'plugin.json "capabilities" must be a list of strings',
          );
        }
        final capability = _capabilityFromName(raw);
        if (capability == null) {
          throw PluginManifestException(
            'plugin.json declares unknown capability "$raw"',
          );
        }
        capabilities.add(capability);
      }
    } else {
      capabilities.addAll(const [
        PluginCapability.search,
        PluginCapability.chapterList,
        PluginCapability.chapterContent,
        PluginCapability.cover,
      ]);
    }
    if (capabilities.isEmpty) {
      throw const PluginManifestException(
        'plugin.json must declare at least one capability',
      );
    }

    return PluginManifest(
      id: id,
      name: name is String && name.isNotEmpty ? name : id,
      sourceName: sourceName is String && sourceName.isNotEmpty
          ? sourceName
          : (name is String && name.isNotEmpty ? name : id),
      version: version,
      templateId: templateId,
      baseUrl: baseUrl,
      transport: transport is String && transport.isNotEmpty
          ? transport
          : 'http',
      language: language is String && language.isNotEmpty ? language : 'en',
      customUserAgent: userAgent is String ? userAgent : null,
      customImageHeaders: imageHeaders is Map
          ? imageHeaders.map(
              (k, v) => MapEntry('$k', v is String ? v : '$v'),
            )
          : const {},
      capabilities: capabilities,
      selectorsFile: _stringOr(json['selectorsFile'], 'selectors.json'),
      filtersFile: _stringOr(json['filtersFile'], 'filters.json'),
      permissionsFile: _stringOr(json['permissionsFile'], 'permissions.json'),
      extraStripSelectors: extraStrips is List
          ? extraStrips.whereType<String>().toList()
          : const [],
      requiresJsRendering: requiresJs is bool ? requiresJs : false,
    );
  }

  /// Stable, unique, lowercase-kebab id.
  final String id;

  /// Display name.
  final String name;

  /// Shown in Library/Source picker UI.
  final String sourceName;

  /// Semver, compared by PluginUpdater (Phase 4).
  final PluginVersion version;

  /// Must match a registered template's `templateId`.
  final String templateId;

  final String baseUrl;

  /// "http" | "stealth" | "cached" | "offline" — key into `TransportRegistry`.
  final String transport;

  /// ISO 639-1, drives locale-aware parsing.
  final String language;

  final String? customUserAgent;

  /// e.g. Referer spoofing for hotlink-protected covers.
  final Map<String, String> customImageHeaders;

  final List<PluginCapability> capabilities;

  final String selectorsFile;
  final String filtersFile;
  final String permissionsFile;

  /// Convenience mirror of `filters.json` for templates that don't need the
  /// full filter model.
  final List<String> extraStripSelectors;

  /// True when the site needs a headless browser. Explicitly unsupported in
  /// this release — registration fails loudly rather than returning empty
  /// chapters.
  final bool requiresJsRendering;

  Map<String, String> get requestHeaders => {
        'User-Agent': ?customUserAgent,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'sourceName': sourceName,
        'version': version.toString(),
        'templateId': templateId,
        'baseUrl': baseUrl,
        'transport': transport,
        'language': language,
        'customUserAgent': ?customUserAgent,
        if (customImageHeaders.isNotEmpty)
          'customImageHeaders': customImageHeaders,
        'capabilities': capabilities.map((c) => c.name).toList(),
        'selectorsFile': selectorsFile,
        'filtersFile': filtersFile,
        'permissionsFile': permissionsFile,
        if (extraStripSelectors.isNotEmpty)
          'extraStripSelectors': extraStripSelectors,
        'requiresJsRendering': requiresJsRendering,
      };

  static String _stringOr(Object? value, String fallback) =>
      value is String && value.isNotEmpty ? value : fallback;
}
