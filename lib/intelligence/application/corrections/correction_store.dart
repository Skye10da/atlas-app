import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/domain/entities/correction_record.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/repositories/correction_repository.dart';

class CorrectionStore {
  CorrectionStore({required CorrectionRepository repository}) : _repository = repository;

  final CorrectionRepository _repository;

  /// Records a user decision from the review queue.
  Future<Result<void>> recordDecision({
    required String id,
    required String pattern,
    required CorrectionDecision decision,
    required StoryEntityType entityType,
    required String bookId,
  }) {
    final record = CorrectionRecord(
      id: id,
      pattern: pattern,
      decision: decision,
      entityType: entityType,
      bookId: bookId,
      createdAt: DateTime.now(),
    );
    return _repository.saveCorrection(record);
  }

  /// Retrieves all learned correction rules for a novel.
  Future<Result<List<CorrectionRecord>>> getRules(String bookId) {
    return _repository.getCorrections(bookId);
  }
}

