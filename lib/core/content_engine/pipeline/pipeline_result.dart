import 'package:atlas_app/core/content_engine/models/atlas_document.dart';

/// Result of a full pipeline run: the delivered document plus the
/// post-normalize version/checksum metadata the storage layer persists.
class PipelineResult {
  const PipelineResult({
    required this.document,
    required this.text,
    required this.wordCount,
    required this.version,
    required this.checksum,
  });

  final AtlasDocument document;
  final String text;
  final int wordCount;
  final int version;
  final String checksum;
}
