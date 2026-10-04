import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/domain/entities/correction_record.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';

/// Contract for persisting user corrections and active learning feedback rules.
///
/// Designed to be local-first; can be backed by a future remote sync repository
/// without altering application callers.
abstract interface class CorrectionRepository {
  /// Saves a user decision as a reusable correction record.
  Future<Result<void>> saveCorrection(CorrectionRecord record);

  /// Retrieves all corrections learned for a specific novel.
  Future<Result<List<CorrectionRecord>>> getCorrections(String bookId);

  /// Retrieves library-wide corrections.
  Future<Result<List<CorrectionRecord>>> getAllCorrections();

  /// Finds correction rules matching a candidate pattern or entity type.
  Future<Result<List<CorrectionRecord>>> findMatchingCorrections(
    String bookId,
    String pattern,
    StoryEntityType type,
  );
}

