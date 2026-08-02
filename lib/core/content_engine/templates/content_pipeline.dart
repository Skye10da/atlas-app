import 'package:html/dom.dart';

import 'package:atlas_app/core/content_engine/cleaner/content_cleaner.dart';
import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/normalizer/content_normalizer.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_filters.dart';

/// The shared tail every template's `chapterContent` runs: clean the parsed
/// DOM with the plugin's filters, then normalize to an [AtlasDocument]. This
/// is the entire point of Phase 0 existing before Phase 1 — no template
/// re-implements DOM-to-document conversion.
class ContentPipeline {
  const ContentPipeline();

  AtlasDocument run(
    Element root, {
    String? title,
    DocumentMetadata metadata = const DocumentMetadata(),
    PluginFilters? filters,
  }) {
    final cleaner = ContentCleaner(
      extraStripSelectors: filters?.extraStripSelectors ?? const [],
      disableDefaultStrips: filters?.disableDefaultStrips ?? false,
    );
    cleaner.clean(root);
    return const ContentNormalizer().normalizeFromElement(
      root,
      options: NormalizerOptions(title: title, metadata: metadata),
    );
  }
}
