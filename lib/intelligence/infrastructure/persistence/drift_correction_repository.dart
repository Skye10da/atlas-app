import 'package:drift/drift.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/domain/entities/correction_record.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/repositories/correction_repository.dart';

class DriftCorrectionRepository implements CorrectionRepository {
  DriftCorrectionRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  @override
  Future<Result<void>> saveCorrection(CorrectionRecord record) async {
    try {
      await _db.customStatement(
        '''
        INSERT INTO story_corrections (
          id, book_id, pattern, decision, entity_type, created_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          decision = excluded.decision;
        ''',
        [
          record.id,
          record.bookId,
          record.pattern,
          record.decision.id,
          record.entityType.id,
          record.createdAt.millisecondsSinceEpoch,
        ],
      );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to save correction record', e), st);
    }
  }

  @override
  Future<Result<List<CorrectionRecord>>> getCorrections(String bookId) async {
    try {
      final rows = await _db
          .customSelect(
            'SELECT * FROM story_corrections WHERE book_id = ? ORDER BY created_at DESC',
            variables: [Variable<String>(bookId)],
          )
          .get();

      final records = rows.map(_mapRowToCorrection).toList();
      return Success(records);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to get corrections for book', e), st);
    }
  }

  @override
  Future<Result<List<CorrectionRecord>>> getAllCorrections() async {
    try {
      final rows = await _db
          .customSelect('SELECT * FROM story_corrections ORDER BY created_at DESC')
          .get();

      final records = rows.map(_mapRowToCorrection).toList();
      return Success(records);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to get all corrections', e), st);
    }
  }

  @override
  Future<Result<List<CorrectionRecord>>> findMatchingCorrections(
    String bookId,
    String pattern,
    StoryEntityType type,
  ) async {
    try {
      final rows = await _db
          .customSelect(
            '''
            SELECT * FROM story_corrections 
            WHERE (book_id = ? OR book_id = 'global') 
              AND entity_type = ? 
              AND LOWER(?) LIKE '%' || LOWER(pattern) || '%'
            ''',
            variables: [
              Variable<String>(bookId),
              Variable<String>(type.id),
              Variable<String>(pattern),
            ],
          )
          .get();

      final records = rows.map(_mapRowToCorrection).toList();
      return Success(records);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to find matching corrections', e), st);
    }
  }

  CorrectionRecord _mapRowToCorrection(QueryRow row) {
    return CorrectionRecord(
      id: row.read<String>('id'),
      bookId: row.read<String>('book_id'),
      pattern: row.read<String>('pattern'),
      decision: CorrectionDecision.fromId(row.read<String>('decision')),
      entityType: StoryEntityType.fromId(row.read<String>('entity_type')),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
    );
  }
}
