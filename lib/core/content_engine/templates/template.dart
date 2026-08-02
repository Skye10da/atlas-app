import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_filters.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_permissions.dart';
import 'package:atlas_app/core/content_engine/selectors/selector_set.dart';
import 'package:atlas_app/core/content_engine/templates/template_models.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Everything a template needs to service one request. Bundled so the Template
/// contract stays small and templates can reach filters, selectors and
/// transport without threading five parameters through every call.
class PluginContext {
  const PluginContext({
    required this.plugin,
    required this.transport,
    this.selectors,
    this.filters,
    this.permissions,
  });

  final PluginManifest plugin;
  final Transport transport;
  final SelectorSet? selectors;
  final PluginFilters? filters;
  final PluginPermissions? permissions;
}

/// A compiled template that interprets plugin manifests for a given site
/// family. `templateId` on [PluginManifest] selects which [Template] runs.
///
/// Every `chapterContent` implementation ends the same way: fetch →
/// DomParser → ContentCleaner (with the plugin's filters) → ContentNormalizer
/// → AtlasDocument. That shared tail is `ContentPipeline`; no template
/// re-implements DOM-to-document conversion.
abstract interface class Template {
  String get templateId;

  /// Capabilities this template can actually deliver. Manifests that declare
  /// more than this fail validation at plugin-load time.
  Set<PluginCapability> get supportedCapabilities;

  Future<List<SearchResult>> search(PluginContext context, String query);

  Future<List<ChapterRef>> chapterList(PluginContext context, String novelUrl);

  Future<AtlasDocument> chapterContent(PluginContext context, String chapterUrl);

  Future<NovelMetadata> metadata(PluginContext context, String novelUrl);
}

/// Thrown when a capability is invoked on a plugin that doesn't declare it —
/// e.g. calling `search` on a plugin whose manifest omits the `search`
/// capability.
class PluginCapabilityException implements Exception {
  const PluginCapabilityException(this.capability, this.message);

  final PluginCapability capability;
  final String message;

  @override
  String toString() => 'PluginCapabilityException: $message';
}
