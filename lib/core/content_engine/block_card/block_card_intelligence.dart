library;

/// Local-only intelligence for BlockCard confidence / type.
///
/// Reuses the `story_corrections` table with `entity_type = 'block_card'` and
/// `book_id = <bookId>` (no global). Pattern stores a stable hash of the
/// raw block text; for type corrections the pattern encodes the target type
/// as `<hash>::<typeName>` with decision `rename`.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/intelligence/domain/entities/correction_record.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';

/// Stable hash for a block's raw text (lowercased, whitespace-collapsed).
String blockCardHash(String rawText) {
  final normalized = rawText.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  final digest = sha256.convert(utf8.encode(normalized)).toString();
  // 16 hex chars are enough to avoid collisions while keeping pattern short.
  return digest.substring(0, 16);
}

/// Result of rescoring a parsed card against local feedback.
class BlockCardRescoreResult {
  const BlockCardRescoreResult({
    required this.card,
    required this.delta,
    required this.overrodeType,
  });

  final BlockCard card;
  final double delta;
  final bool overrodeType;
}

/// Pure scorer — no DB access. Takes already-fetched local corrections.
class BlockCardIntelligenceScorer {
  const BlockCardIntelligenceScorer();

  static const String entityTypeId = 'block_card';
  static const StoryEntityType entityType = StoryEntityType.blockCard;

  /// Rescores [card] using [localCorrections] for the same book.
  /// - `confirm`/`merge` → +0.20
  /// - `reject` → -0.40 and forces type to custom (fallback)
  /// - `rename` with pattern `<hash>::<typeName>` → overrides type
  BlockCardRescoreResult rescore(
    BlockCard card,
    List<CorrectionRecord> localCorrections,
  ) {
    final hash = blockCardHash(card.rawText);
    final matching = localCorrections.where((r) {
      if (r.entityType.id != entityTypeId) return false;
      // exact hash or hash::type suffix for rename
      return r.pattern == hash || r.pattern.startsWith('$hash::') || r.pattern.startsWith('$hash|');
    }).toList();

    if (matching.isEmpty) {
      return BlockCardRescoreResult(card: card, delta: 0, overrodeType: false);
    }

    // Most recent first to decide type override precedence.
    matching.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    double delta = 0;
    BlockCardType? correctedType;
    bool hasReject = false;

    for (final r in matching) {
      switch (r.decision) {
        case CorrectionDecision.confirm:
        case CorrectionDecision.merge:
          delta += 0.20;
          break;
        case CorrectionDecision.reject:
          delta -= 0.40;
          hasReject = true;
          break;
        case CorrectionDecision.rename:
          // pattern = "<hash>::<typeName>"
          final parts = r.pattern.split('::');
          if (parts.length == 2) {
            final t = BlockCardType.values
                .where((e) => e.name == parts[1])
                .firstOrNull;
            if (t != null) correctedType ??= t;
          }
          break;
        case CorrectionDecision.split:
          break;
      }
    }

    // Latest record wins for type override.
    final latest = matching.first;
    BlockCardType? overrideType;
    if (hasReject) {
      // Requirement: learned reject overrides type to custom regardless of confidence.
      overrideType = BlockCardType.custom;
    } else if (latest.decision == CorrectionDecision.rename) {
      final parts = latest.pattern.split('::');
      if (parts.length == 2) {
        overrideType = BlockCardType.values
            .where((e) => e.name == parts[1])
            .firstOrNull;
      }
    } else if (correctedType != null && latest.decision != CorrectionDecision.reject) {
      overrideType = correctedType;
    }

    final adjustedConfidence = (card.confidence + delta).clamp(0.0, 1.0);

    // If reject forced custom, ensure confidence is below threshold so
    // fallback rendering is guaranteed even if delta alone wasn't enough.
    final double finalConfidence;
    if (overrideType == BlockCardType.custom && hasReject) {
      finalConfidence = adjustedConfidence < BlockCard.lowConfidenceThreshold
          ? adjustedConfidence
          : (BlockCard.lowConfidenceThreshold - 0.05).clamp(0.0, 1.0);
    } else {
      finalConfidence = adjustedConfidence;
    }

    if (overrideType != null && overrideType != card.type || finalConfidence != card.confidence) {
      final rescored = BlockCard(
        type: overrideType ?? card.type,
        confidence: finalConfidence,
        rawText: card.rawText,
        title: card.title,
        subtitle: card.subtitle,
        fields: card.fields,
        tags: card.tags,
        footnote: card.footnote,
      );
      return BlockCardRescoreResult(
        card: rescored,
        delta: delta,
        overrodeType: overrideType != null,
      );
    }

    return BlockCardRescoreResult(card: card, delta: delta, overrodeType: false);
  }
}

/// Helper to build CorrectionRecords for BlockCard feedback (local only).
class BlockCardFeedbackBuilder {
  static CorrectionRecord confirm({
    required String bookId,
    required String rawText,
  }) {
    return CorrectionRecord(
      id: '$bookId:blockcard:${DateTime.now().microsecondsSinceEpoch}',
      pattern: blockCardHash(rawText),
      decision: CorrectionDecision.confirm,
      entityType: StoryEntityType.blockCard,
      bookId: bookId,
      createdAt: DateTime.now(),
    );
  }

  static CorrectionRecord reject({
    required String bookId,
    required String rawText,
  }) {
    return CorrectionRecord(
      id: '$bookId:blockcard:${DateTime.now().microsecondsSinceEpoch}',
      pattern: blockCardHash(rawText),
      decision: CorrectionDecision.reject,
      entityType: StoryEntityType.blockCard,
      bookId: bookId,
      createdAt: DateTime.now(),
    );
  }

  static CorrectionRecord typeCorrection({
    required String bookId,
    required String rawText,
    required BlockCardType correctedType,
  }) {
    final hash = blockCardHash(rawText);
    return CorrectionRecord(
      id: '$bookId:blockcard:${DateTime.now().microsecondsSinceEpoch}',
      pattern: '$hash::${correctedType.name}',
      decision: CorrectionDecision.rename,
      entityType: StoryEntityType.blockCard,
      bookId: bookId,
      createdAt: DateTime.now(),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
