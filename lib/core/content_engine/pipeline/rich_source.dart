import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_engine/models/atlas_document.dart';

/// A source that can produce the post-normalization [AtlasDocument] for a
/// chapter, not just rendered text. Plugin sources implement this so the
/// pipeline can cache rich JSON content beside the plain-text file.
abstract interface class RichSource {
  Future<AtlasDocument> getDocument(ChapterModel chapter);
}
