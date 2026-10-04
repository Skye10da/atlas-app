import 'dart:math' as math;
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_event.dart';
import 'package:atlas_app/intelligence/domain/entities/story_relationship.dart';

class RelationshipDeriver {
  const RelationshipDeriver();

  static const Map<String, String> _keywords = {
    'father': 'father',
    'mother': 'mother',
    'son': 'son',
    'daughter': 'daughter',
    'brother': 'brother',
    'sister': 'sister',
    'master': 'master',
    'disciple': 'disciple',
    'senior brother': 'senior brother',
    'junior brother': 'junior brother',
    'ally': 'ally',
    'friend': 'friend',
    'companion': 'companion',
    'rival': 'rival',
    'enemy': 'enemy',
    'nemesis': 'nemesis',
  };

  /// Scans sentences where both [entityA] and [entityB] appear for relationship cues.
  List<StoryRelationship> deriveRelationships({
    required String chapterText,
    required int chapterIndex,
    required List<StoryEntity> presentEntities,
    String readThroughId = 'default',
  }) {
    if (presentEntities.length < 2) return const [];
    final derived = <StoryRelationship>[];

    // Split into sentences for proximity detection
    final sentences = chapterText.split(RegExp(r'(?<=[.!?])\s+'));

    for (final sentence in sentences) {
      final sentenceLower = sentence.toLowerCase();

      for (int i = 0; i < presentEntities.length; i++) {
        for (int j = i + 1; j < presentEntities.length; j++) {
          final e1 = presentEntities[i];
          final e2 = presentEntities[j];

          final hasE1 = _sentenceMentions(sentenceLower, e1);
          final hasE2 = _sentenceMentions(sentenceLower, e2);

          if (hasE1 && hasE2) {
            for (final entry in _keywords.entries) {
              if (sentenceLower.contains(entry.key)) {
                final relId = '${e1.bookId}:$readThroughId:${e1.id}:${e2.id}:${entry.value}';
                final inheritedScore = math.min(e1.confidenceScore, e2.confidenceScore);

                derived.add(
                  StoryRelationship(
                    id: relId,
                    bookId: e1.bookId,
                    readThroughId: readThroughId,
                    sourceEntityId: e1.id,
                    targetEntityId: e2.id,
                    relationType: entry.value,
                    confidenceScore: double.parse(inheritedScore.toStringAsFixed(3)),
                    chapterEstablished: chapterIndex,
                    createdAt: DateTime.now(),
                  ),
                );
                break; // One relationship per sentence pair
              }
            }
          }
        }
      }
    }

    return derived;
  }

  /// Derives notable plot events involving co-occurring entities in [chapterText].
  List<StoryEvent> deriveEvents({
    required String chapterText,
    required int chapterIndex,
    required String bookId,
    String readThroughId = 'default',
    required List<StoryEntity> presentEntities,
  }) {
    if (presentEntities.isEmpty) return const [];
    final events = <StoryEvent>[];

    // Identify major action verbs in sentences with 2+ characters
    final actionPattern = RegExp(
      r'\b(defeated|killed|escaped|fled|battled|fought|allied with|betrayed|rescued|saved|sealed|joined)\b',
      caseSensitive: false,
    );

    final sentences = chapterText.split(RegExp(r'(?<=[.!?])\s+'));
    for (final sentence in sentences) {
      final match = actionPattern.firstMatch(sentence);
      if (match != null) {
        final sentenceLower = sentence.toLowerCase();
        final involved = <StoryEntity>[];

        for (final e in presentEntities) {
          if (_sentenceMentions(sentenceLower, e)) {
            involved.add(e);
          }
        }

        if (involved.length >= 2) {
          final minConf = involved.map((e) => e.confidenceScore).reduce(math.min);
          final evtId = '$bookId:$readThroughId:ch$chapterIndex:${events.length + 1}';

          events.add(
            StoryEvent(
              id: evtId,
              bookId: bookId,
              readThroughId: readThroughId,
              chapter: chapterIndex,
              summary: sentence.trim(),
              involvedEntityIds: involved.map((e) => e.id).toList(),
              confidenceScore: double.parse(minConf.toStringAsFixed(3)),
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    }

    return events;
  }

  bool _sentenceMentions(String sentenceLower, StoryEntity entity) {
    if (sentenceLower.contains(entity.canonicalName.toLowerCase())) return true;
    for (final a in entity.aliases) {
      if (sentenceLower.contains(a.toLowerCase())) return true;
    }
    return false;
  }
}

