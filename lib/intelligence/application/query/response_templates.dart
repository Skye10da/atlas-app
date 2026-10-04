import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_event.dart';
import 'package:atlas_app/intelligence/domain/entities/story_relationship.dart';

/// Renders human-readable deterministic markdown responses for Layer 2 without AI.
class ResponseTemplates {
  const ResponseTemplates();

  String formatWhoIs({
    required StoryEntity entity,
    List<StoryRelationship> relationships = const [],
    List<StoryEvent> events = const [],
  }) {
    final buffer = StringBuffer();
    final typeStr = entity.type.name.toLowerCase();
    buffer.writeln('**${entity.canonicalName}** is a $typeStr in this novel.');

    if (entity.aliases.isNotEmpty) {
      buffer.writeln('• **Also known as:** ${entity.aliases.join(", ")}');
    }

    final appearanceStr = entity.firstSeenChapter == entity.lastSeenChapter
        ? 'Chapter ${entity.firstSeenChapter}'
        : 'Chapters ${entity.firstSeenChapter} to ${entity.lastSeenChapter}';
    buffer.writeln('• **Appearances:** $appearanceStr (${entity.mentionCount} mentions)');

    if (relationships.isNotEmpty) {
      buffer.writeln('• **Key Connections:**');
      for (final r in relationships.take(3)) {
        buffer.writeln('  - ${r.relationType} (since Ch. ${r.chapterEstablished})');
      }
    }

    if (events.isNotEmpty) {
      buffer.writeln('• **Notable Events:**');
      for (final ev in events.take(3)) {
        buffer.writeln('  - [Ch. ${ev.chapter}] ${ev.summary}');
      }
    }

    return buffer.toString().trim();
  }

  String formatRelationship({
    required StoryEntity entityA,
    required StoryEntity entityB,
    StoryRelationship? relationship,
  }) {
    if (relationship == null) {
      return 'No direct relationship between **${entityA.canonicalName}** and **${entityB.canonicalName}** has been confirmed in the novel yet.';
    }

    return '**${entityA.canonicalName}** and **${entityB.canonicalName}** have a recorded connection: **${relationship.relationType}** (established in Chapter ${relationship.chapterEstablished}).';
  }

  String formatWhereIs({
    required StoryEntity location,
    List<StoryEvent> events = const [],
  }) {
    final buffer = StringBuffer();
    buffer.writeln('**${location.canonicalName}** is a location in the story.');
    buffer.writeln('• First visited in Chapter ${location.firstSeenChapter}.');

    if (events.isNotEmpty) {
      buffer.writeln('• **Events here:**');
      for (final ev in events.take(2)) {
        buffer.writeln('  - [Ch. ${ev.chapter}] ${ev.summary}');
      }
    }

    return buffer.toString().trim();
  }

  String formatRecap({
    required int maxChapter,
    required List<StoryEvent> events,
    String? extractiveSummary,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('### Story Recap (Up to Chapter $maxChapter)\n');

    if (extractiveSummary != null && extractiveSummary.isNotEmpty) {
      buffer.writeln(extractiveSummary);
      buffer.writeln();
    }

    if (events.isNotEmpty) {
      buffer.writeln('**Key Plot Milestones:**');
      for (final ev in events) {
        buffer.writeln('• **Ch. ${ev.chapter}:** ${ev.summary}');
      }
    } else if (extractiveSummary == null || extractiveSummary.isEmpty) {
      buffer.writeln('No major recorded milestones found up to Chapter $maxChapter.');
    }

    return buffer.toString().trim();
  }

  String formatChapterSummary({
    required int chapter,
    required List<StoryEvent> events,
    String? extractiveSummary,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('### Chapter $chapter Summary\n');

    if (extractiveSummary != null && extractiveSummary.isNotEmpty) {
      buffer.writeln(extractiveSummary);
      buffer.writeln();
    }

    if (events.isNotEmpty) {
      buffer.writeln('**Recorded Events:**');
      for (final ev in events) {
        buffer.writeln('• ${ev.summary}');
      }
    } else if (extractiveSummary == null || extractiveSummary.isEmpty) {
      buffer.writeln('No specific events or text found for Chapter $chapter in memory.');
    }

    return buffer.toString().trim();
  }

  String formatDisambiguation({
    required String query,
    required List<StoryEntity> candidates,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('I found multiple matches for "$query". Did you mean:');
    for (final c in candidates.take(5)) {
      buffer.writeln('• **${c.canonicalName}** (${c.type.name})');
    }
    return buffer.toString().trim();
  }

  String formatNotFound(String query) {
    return 'I couldn\'t find any information about "$query" in the story memory yet.';
  }

  String formatUnknown(String rawQuery) {
    return 'I\'m not sure how to answer that with offline Story Memory. Try asking "Who is [character]?", "How do [X] and [Y] know each other?", or "Catch me up".';
  }
}

