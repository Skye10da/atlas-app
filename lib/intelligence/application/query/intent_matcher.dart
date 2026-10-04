import 'package:atlas_app/intelligence/application/query/query_intent.dart';

/// Matches natural language user questions to structured intents and extracted entity/chapter slots.
class IntentMatcher {
  const IntentMatcher();

  QueryIntentMatch match(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return QueryIntentMatch(
        intent: QueryIntentType.unknown,
        rawQuery: rawQuery,
        confidence: 0.0,
      );
    }

    // 1. Relationship patterns (must be tested before WhoIs/WhereIs)
    final relPatterns = [
      RegExp(r'^(?:how (?:does|do|did|is|are) )(.+?)(?: (?:know|related to|connected to) )(.+?)\??$', caseSensitive: false),
      RegExp(r'^(?:what is the relationship between )(.+?)(?: and )(.+?)\??$', caseSensitive: false),
      RegExp(r'^(?:how are )(.+?)(?: and )(.+?)(?: related)\??$', caseSensitive: false),
      RegExp(r'^(?:relationship between )(.+?)(?: and )(.+?)\??$', caseSensitive: false),
    ];

    for (final pattern in relPatterns) {
      final m = pattern.firstMatch(query);
      if (m != null) {
        return QueryIntentMatch(
          intent: QueryIntentType.relationship,
          rawQuery: rawQuery,
          primarySlot: _cleanSlot(m.group(1)),
          secondarySlot: _cleanSlot(m.group(2)),
          confidence: 0.95,
        );
      }
    }

    // 2. Recap patterns
    final recapPatterns = [
      RegExp(r'^(?:catch me up|recap|give me a recap)\??$', caseSensitive: false),
      RegExp(r'^(?:what (?:has )?happened so far)\??$', caseSensitive: false),
      RegExp(r'^(?:recap|summarize|summary)(?: up to| until)?(?: chapter)?\s*(\d+)\??$', caseSensitive: false),
      RegExp(r'^(?:summarize what happened so far)\??$', caseSensitive: false),
    ];

    for (final pattern in recapPatterns) {
      final m = pattern.firstMatch(query);
      if (m != null) {
        int? ch;
        if (m.groupCount >= 1 && m.group(1) != null) {
          ch = int.tryParse(m.group(1)!);
        }
        return QueryIntentMatch(
          intent: QueryIntentType.recap,
          rawQuery: rawQuery,
          chapterSlot: ch,
          confidence: 0.95,
        );
      }
    }

    // 3. What happened patterns (specific chapter or entity)
    final whatHappenedChapterPatterns = [
      RegExp(r'^what happened in ch(?:apter)?\.?\s*(\d+)\??$', caseSensitive: false),
      RegExp(r'^what happens in ch(?:apter)?\.?\s*(\d+)\??$', caseSensitive: false),
    ];

    for (final pattern in whatHappenedChapterPatterns) {
      final m = pattern.firstMatch(query);
      if (m != null) {
        return QueryIntentMatch(
          intent: QueryIntentType.whatHappened,
          rawQuery: rawQuery,
          chapterSlot: int.tryParse(m.group(1)!),
          confidence: 0.95,
        );
      }
    }

    final whatHappenedEntityPatterns = [
      RegExp(r'^what happened to (.+?)\??$', caseSensitive: false),
      RegExp(r'^what did (.+?) do\??$', caseSensitive: false),
    ];

    for (final pattern in whatHappenedEntityPatterns) {
      final m = pattern.firstMatch(query);
      if (m != null) {
        return QueryIntentMatch(
          intent: QueryIntentType.whatHappened,
          rawQuery: rawQuery,
          primarySlot: _cleanSlot(m.group(1)),
          confidence: 0.90,
        );
      }
    }

    // 4. Who is / Tell me about patterns
    final whoIsPatterns = [
      RegExp(r'^who (?:is|was|are|were) (.+?)\??$', caseSensitive: false),
      RegExp(r"^who(?:'s|s) (.+?)\??$", caseSensitive: false),
      RegExp(r'^tell me about (.+?)\??$', caseSensitive: false),
      RegExp(r'^describe (.+?)\??$', caseSensitive: false),
      RegExp(r'^who the heck is (.+?)\??$', caseSensitive: false),
    ];

    for (final pattern in whoIsPatterns) {
      final m = pattern.firstMatch(query);
      if (m != null) {
        return QueryIntentMatch(
          intent: QueryIntentType.whoIs,
          rawQuery: rawQuery,
          primarySlot: _cleanSlot(m.group(1)),
          confidence: 0.90,
        );
      }
    }

    // 5. Where is / location patterns
    final whereIsPatterns = [
      RegExp(r'^where (?:is|was|are|were) (.+?)\??$', caseSensitive: false),
      RegExp(r'^where does (.+?) (?:live|stay|reside|belong)\??$', caseSensitive: false),
      RegExp(r'^(?:where can i find|location of) (.+?)\??$', caseSensitive: false),
    ];

    for (final pattern in whereIsPatterns) {
      final m = pattern.firstMatch(query);
      if (m != null) {
        return QueryIntentMatch(
          intent: QueryIntentType.whereIs,
          rawQuery: rawQuery,
          primarySlot: _cleanSlot(m.group(1)),
          confidence: 0.90,
        );
      }
    }

    // 6. Scene search patterns
    final scenePatterns = [
      RegExp(r'^(?:find|search|show)(?: the)? scene (?:where|when) (.+?)\??$', caseSensitive: false),
      RegExp(r'^when did (.+?) (?:battle|fight|defeat|kill|meet|find|encounter) (.+?)\??$', caseSensitive: false),
    ];

    for (final pattern in scenePatterns) {
      final m = pattern.firstMatch(query);
      if (m != null) {
        return QueryIntentMatch(
          intent: QueryIntentType.sceneSearch,
          rawQuery: rawQuery,
          primarySlot: _cleanSlot(m.group(1)),
          secondarySlot: m.groupCount >= 2 ? _cleanSlot(m.group(2)) : null,
          confidence: 0.85,
        );
      }
    }

    // Fallback: If query is just a name (e.g. "Lin Dong"), default to WhoIs
    if (!query.contains(' ') && query.length > 1) {
      return QueryIntentMatch(
        intent: QueryIntentType.whoIs,
        rawQuery: rawQuery,
        primarySlot: query,
        confidence: 0.70,
      );
    }

    return QueryIntentMatch(
      intent: QueryIntentType.unknown,
      rawQuery: rawQuery,
      confidence: 0.0,
    );
  }

  static String? _cleanSlot(String? raw) {
    if (raw == null) return null;
    var cleaned = raw.trim();
    // Remove leading "the " or "a " if present
    if (cleaned.toLowerCase().startsWith('the ')) {
      cleaned = cleaned.substring(4).trim();
    } else if (cleaned.toLowerCase().startsWith('a ')) {
      cleaned = cleaned.substring(2).trim();
    }
    // Remove trailing question mark or punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[?!.,;:]+$'), '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }
}

