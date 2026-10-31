import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/domain/entities/correction_record.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/repositories/correction_repository.dart';

class CorrectionRuleEngine {
  CorrectionRuleEngine({required CorrectionRepository repository})
      : _repository = repository;

  final CorrectionRepository _repository;

  /// Loads every correction rule relevant to one book — book-scoped and
  /// 'global' — in a single DB round trip. This is the prefetch an extraction
  /// pass should call once per chapter instead of hitting the database per
  /// candidate name.
  Future<List<CorrectionRecord>> loadCorrectionsForBook(String bookId) async {
    final res = await _repository.getAllCorrections();
    if (res is! Success<List<CorrectionRecord>>) return const [];
    return res.value
        .where((r) => r.bookId == bookId || r.bookId == 'global')
        .toList();
  }

  /// Sums the confidence delta that [rules] apply to a candidate name.
  /// Mirrors the repository's SQL semantics: a rule matches when the
  /// lower-cased candidate name contains the lower-cased rule pattern and
  /// the entity types align (a 'global' rule applies to every novel).
  double adjustmentFor(
    List<CorrectionRecord> rules,
    String candidateName,
    StoryEntityType type,
  ) {
    final candidateLower = candidateName.toLowerCase();
    double delta = 0.0;
    for (final rule in rules) {
      if (rule.entityType != type) continue;
      if (!candidateLower.contains(rule.pattern.toLowerCase())) continue;
      switch (rule.decision) {
        case CorrectionDecision.confirm:
        case CorrectionDecision.merge:
          delta += 0.20;
          break;
        case CorrectionDecision.reject:
          delta -= 0.40;
          break;
        default:
          break;
      }
    }
    return delta;
  }

  /// Evaluates a candidate name against stored correction rules and returns
  /// an optional confidence score delta (e.g. +0.20 on confirmation pattern,
  /// or -0.50 / rejection on rejected patterns).
  ///
  /// Prefer [loadCorrectionsForBook] + [adjustmentFor] in extraction passes:
  /// evaluating many candidates through this method costs one DB query per
  /// candidate.
  Future<double> evaluateConfidenceAdjustment({
    required String bookId,
    required String candidateName,
    required StoryEntityType type,
  }) async {
    final rules = await loadCorrectionsForBook(bookId);
    return adjustmentFor(rules, candidateName, type);
  }
}

