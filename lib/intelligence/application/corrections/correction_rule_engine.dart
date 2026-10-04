import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/domain/entities/correction_record.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/repositories/correction_repository.dart';

class CorrectionRuleEngine {
  CorrectionRuleEngine({required CorrectionRepository repository})
      : _repository = repository;

  final CorrectionRepository _repository;

  /// Evaluates a candidate name against stored correction rules and returns
  /// an optional confidence score delta (e.g. +0.20 on confirmation pattern,
  /// or -0.50 / rejection on rejected patterns).
  Future<double> evaluateConfidenceAdjustment({
    required String bookId,
    required String candidateName,
    required StoryEntityType type,
  }) async {
    final matchesRes = await _repository.findMatchingCorrections(
      bookId,
      candidateName,
      type,
    );

    if (matchesRes is! Success<List<CorrectionRecord>>) return 0.0;
    final rules = matchesRes.value;
    if (rules.isEmpty) return 0.0;

    double delta = 0.0;
    for (final rule in rules) {
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
}

