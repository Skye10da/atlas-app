import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/repositories/story_memory_repository.dart';
import 'package:atlas_app/intelligence/infrastructure/parsing/transliteration_matcher.dart';
import 'package:atlas_app/core/error_handling/result.dart';

enum ResolutionStatus {
  resolved,
  ambiguous,
  notFound,
}

/// The result of attempting to resolve an extracted slot token into a known StoryEntity.
class EntityResolutionResult {
  const EntityResolutionResult.resolved(this.entity)
      : status = ResolutionStatus.resolved,
        candidates = const [];

  const EntityResolutionResult.ambiguous(this.candidates)
      : status = ResolutionStatus.ambiguous,
        entity = null;

  const EntityResolutionResult.notFound()
      : status = ResolutionStatus.notFound,
        entity = null,
        candidates = const [];

  final ResolutionStatus status;
  final StoryEntity? entity;
  final List<StoryEntity> candidates;
}

/// Resolves raw text tokens into Story Memory entities via:
/// 1. Exact canonical name match
/// 2. Alias match
/// 3. Transliteration / phonetic fuzzy match
/// 4. Disambiguation if multiple candidates match
class EntitySlotResolver {
  EntitySlotResolver({
    required StoryMemoryRepository repository,
    TransliterationMatcher? matcher,
  })  : _repository = repository,
        _matcher = matcher ?? const TransliterationMatcher();

  final StoryMemoryRepository _repository;
  final TransliterationMatcher _matcher;

  Future<EntityResolutionResult> resolve({
    required String bookId,
    String readThroughId = 'default',
    required String slotText,
  }) async {
    final query = slotText.trim();
    if (query.isEmpty) {
      return const EntityResolutionResult.notFound();
    }

    // 1. Check exact canonical name or alias in Story Memory
    final directRes = await _repository.findEntityByNameOrAlias(
      bookId,
      query,
      readThroughId: readThroughId,
    );
    if (directRes is Success<StoryEntity?> && directRes.value != null) {
      return EntityResolutionResult.resolved(directRes.value!);
    }

    // 2. Fetch all entities for this book and read-through to perform fuzzy/substring/transliteration resolution
    final allRes = await _repository.getEntities(
      bookId,
      readThroughId: readThroughId,
    );
    if (allRes is! Success<List<StoryEntity>>) {
      return const EntityResolutionResult.notFound();
    }

    final entities = allRes.value;
    if (entities.isEmpty) {
      return const EntityResolutionResult.notFound();
    }

    final lowerQuery = query.toLowerCase();

    // 3. Check for substring / prefix match (e.g. "Lin" matching "Lin Dong")
    final substringMatches = <StoryEntity>[];
    for (final e in entities) {
      final cName = e.canonicalName.toLowerCase();
      if (cName.contains(lowerQuery) || lowerQuery.contains(cName)) {
        substringMatches.add(e);
      } else {
        for (final a in e.aliases) {
          if (a.toLowerCase().contains(lowerQuery)) {
            substringMatches.add(e);
            break;
          }
        }
      }
    }

    if (substringMatches.length == 1) {
      return EntityResolutionResult.resolved(substringMatches.first);
    } else if (substringMatches.length > 1) {
      return EntityResolutionResult.ambiguous(substringMatches);
    }

    // 4. Check transliteration phonetic similarity (Levenshtein / Soundex / Pinyin)
    final fuzzyMatches = <StoryEntity>[];
    for (final e in entities) {
      if (_matcher.isPotentialAlias(e.canonicalName, query)) {
        fuzzyMatches.add(e);
      }
    }

    if (fuzzyMatches.length == 1) {
      return EntityResolutionResult.resolved(fuzzyMatches.first);
    } else if (fuzzyMatches.length > 1) {
      return EntityResolutionResult.ambiguous(fuzzyMatches);
    }

    return const EntityResolutionResult.notFound();
  }
}

