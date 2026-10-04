import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/domain/entities/confidence.dart';
import 'package:atlas_app/intelligence/domain/entities/read_through.dart';
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/domain/entities/story_cooccurrence.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/entities/story_event.dart';
import 'package:atlas_app/intelligence/domain/entities/story_relationship.dart';
import 'package:atlas_app/intelligence/domain/repositories/story_memory_repository.dart';

class DriftStoryMemoryRepository implements StoryMemoryRepository {
  DriftStoryMemoryRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;
  final _entityStreamControllers = <String, StreamController<List<StoryEntity>>>{};

  String _streamKey(String bookId, String readThroughId) => '${bookId}_$readThroughId';

  StreamController<List<StoryEntity>> _controllerFor(String bookId, String readThroughId) {
    return _entityStreamControllers.putIfAbsent(
      _streamKey(bookId, readThroughId),
      () => StreamController<List<StoryEntity>>.broadcast(),
    );
  }

  void _notifyEntityChange(String bookId, String readThroughId) async {
    final key = _streamKey(bookId, readThroughId);
    final controller = _entityStreamControllers[key];
    if (controller != null && controller.hasListener) {
      final res = await getEntities(bookId, readThroughId: readThroughId);
      if (res is Success<List<StoryEntity>>) {
        controller.add(res.value);
      }
    }
  }

  @override
  Stream<List<StoryEntity>> watchEntities(String bookId, {String readThroughId = 'default'}) {
    final controller = _controllerFor(bookId, readThroughId);
    // Emit initial snapshot asynchronously
    Future.microtask(() async {
      final res = await getEntities(bookId, readThroughId: readThroughId);
      if (res is Success<List<StoryEntity>> && !controller.isClosed) {
        controller.add(res.value);
      }
    });
    return controller.stream;
  }

  @override
  Future<Result<List<StoryEntity>>> getEntities(
    String bookId, {
    String readThroughId = 'default',
    StoryEntityType? type,
    ConfidenceTier? minTier,
  }) async {
    try {
      final sql = StringBuffer('SELECT * FROM story_entities WHERE book_id = ? AND read_through_id = ?');
      final vars = <Variable<Object>>[
        Variable<String>(bookId),
        Variable<String>(readThroughId),
      ];

      if (type != null) {
        sql.write(' AND type = ?');
        vars.add(Variable<String>(type.id));
      }

      sql.write(' ORDER BY mention_count DESC, confidence_score DESC');

      final rows = await _db.customSelect(sql.toString(), variables: vars).get();
      final entities = rows.map(_mapRowToStoryEntity).toList();

      if (minTier != null) {
        final filtered = entities.where((e) {
          if (minTier == ConfidenceTier.high) {
            return e.tier == ConfidenceTier.high;
          } else if (minTier == ConfidenceTier.medium) {
            return e.tier == ConfidenceTier.high || e.tier == ConfidenceTier.medium;
          }
          return true;
        }).toList();
        return Success(filtered);
      }

      return Success(entities);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to get story entities', e), st);
    }
  }

  @override
  Future<Result<StoryEntity?>> getEntityById(String entityId) async {
    try {
      final rows = await _db
          .customSelect(
            'SELECT * FROM story_entities WHERE id = ? LIMIT 1',
            variables: [Variable<String>(entityId)],
          )
          .get();

      if (rows.isEmpty) return const Success(null);
      return Success(_mapRowToStoryEntity(rows.first));
    } catch (e, st) {
      return Failure(DatabaseException('Failed to get story entity by id', e), st);
    }
  }

  @override
  Future<Result<StoryEntity?>> findEntityByNameOrAlias(
    String bookId,
    String name, {
    String readThroughId = 'default',
  }) async {
    try {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return const Success(null);

      // Exact match on canonical name
      final rows = await _db
          .customSelect(
            'SELECT * FROM story_entities WHERE book_id = ? AND read_through_id = ? AND LOWER(canonical_name) = LOWER(?) LIMIT 1',
            variables: [
              Variable<String>(bookId),
              Variable<String>(readThroughId),
              Variable<String>(trimmed),
            ],
          )
          .get();

      if (rows.isNotEmpty) {
        return Success(_mapRowToStoryEntity(rows.first));
      }

      // Check aliases in this book
      final allRows = await _db
          .customSelect(
            'SELECT * FROM story_entities WHERE book_id = ? AND read_through_id = ?',
            variables: [
              Variable<String>(bookId),
              Variable<String>(readThroughId),
            ],
          )
          .get();

      final targetLower = trimmed.toLowerCase();
      for (final r in allRows) {
        final entity = _mapRowToStoryEntity(r);
        for (final alias in entity.aliases) {
          if (alias.toLowerCase() == targetLower) {
            return Success(entity);
          }
        }
      }

      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to find entity by name or alias', e), st);
    }
  }

  @override
  Future<Result<void>> saveEntity(StoryEntity entity) async {
    try {
      await _db.customStatement(
        '''
        INSERT INTO story_entities (
          id, book_id, read_through_id, type, canonical_name, aliases, confidence_score, tier,
          user_confirmed, attributes, first_seen_chapter, last_seen_chapter,
          mention_count, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          type = excluded.type,
          canonical_name = excluded.canonical_name,
          aliases = excluded.aliases,
          confidence_score = excluded.confidence_score,
          tier = excluded.tier,
          user_confirmed = excluded.user_confirmed,
          attributes = excluded.attributes,
          first_seen_chapter = MIN(story_entities.first_seen_chapter, excluded.first_seen_chapter),
          last_seen_chapter = MAX(story_entities.last_seen_chapter, excluded.last_seen_chapter),
          mention_count = excluded.mention_count,
          updated_at = excluded.updated_at;
        ''',
        [
          entity.id,
          entity.bookId,
          entity.readThroughId,
          entity.type.id,
          entity.canonicalName,
          jsonEncode(entity.aliases),
          entity.confidenceScore,
          entity.tier.id,
          entity.userConfirmed ? 1 : 0,
          jsonEncode(entity.attributes),
          entity.firstSeenChapter,
          entity.lastSeenChapter,
          entity.mentionCount,
          entity.createdAt.millisecondsSinceEpoch,
          entity.updatedAt.millisecondsSinceEpoch,
        ],
      );
      _notifyEntityChange(entity.bookId, entity.readThroughId);
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to save story entity', e), st);
    }
  }

  @override
  Future<Result<void>> saveEntities(List<StoryEntity> entities) async {
    try {
      await _db.transaction(() async {
        for (final entity in entities) {
          await saveEntity(entity);
        }
      });
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to batch save story entities', e), st);
    }
  }

  @override
  Future<Result<void>> deleteEntity(String entityId) async {
    try {
      final entityRes = await getEntityById(entityId);
      final entity = entityRes is Success<StoryEntity?> ? entityRes.value : null;
      final bookId = entity?.bookId;
      final readThroughId = entity?.readThroughId ?? 'default';

      await _db.transaction(() async {
        await _db.customStatement(
          'DELETE FROM story_entities WHERE id = ?',
          [entityId],
        );
        await _db.customStatement(
          'DELETE FROM story_relationships WHERE source_entity_id = ? OR target_entity_id = ?',
          [entityId, entityId],
        );
        await _db.customStatement(
          'DELETE FROM story_cooccurrences WHERE entity_a_id = ? OR entity_b_id = ?',
          [entityId, entityId],
        );
      });

      if (bookId != null) {
        _notifyEntityChange(bookId, readThroughId);
      }
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to delete story entity', e), st);
    }
  }

  @override
  Future<Result<StoryEntity>> mergeEntities(
    String bookId, {
    String readThroughId = 'default',
    required String keepEntityId,
    required String absorbedEntityId,
  }) async {
    try {
      final keepRes = await getEntityById(keepEntityId);
      final absorbedRes = await getEntityById(absorbedEntityId);

      if (keepRes is! Success<StoryEntity?> || keepRes.value == null) {
        return const Failure(DatabaseException('Target entity to keep was not found'));
      }
      if (absorbedRes is! Success<StoryEntity?> || absorbedRes.value == null) {
        return const Failure(DatabaseException('Entity to absorb was not found'));
      }

      final keep = keepRes.value!;
      final absorbed = absorbedRes.value!;

      // Combine aliases
      final mergedAliases = <String>{
        ...keep.aliases,
        absorbed.canonicalName,
        ...absorbed.aliases,
      }..remove(keep.canonicalName);

      // Combine attributes
      final mergedAttributes = Map<String, dynamic>.from(keep.attributes);
      for (final entry in absorbed.attributes.entries) {
        mergedAttributes.putIfAbsent(entry.key, () => entry.value);
      }

      final updatedKeep = keep.copyWith(
        aliases: mergedAliases.toList(),
        mentionCount: keep.mentionCount + absorbed.mentionCount,
        confidenceScore: math.max(keep.confidenceScore, absorbed.confidenceScore),
        firstSeenChapter: math.min(keep.firstSeenChapter, absorbed.firstSeenChapter),
        lastSeenChapter: math.max(keep.lastSeenChapter, absorbed.lastSeenChapter),
        attributes: mergedAttributes,
        userConfirmed: keep.userConfirmed || absorbed.userConfirmed,
        updatedAt: DateTime.now(),
      );

      await _db.transaction(() async {
        // 1. Update keep entity
        await saveEntity(updatedKeep);

        // 2. Re-point relationships
        await _db.customStatement(
          'UPDATE story_relationships SET source_entity_id = ? WHERE source_entity_id = ?',
          [keepEntityId, absorbedEntityId],
        );
        await _db.customStatement(
          'UPDATE story_relationships SET target_entity_id = ? WHERE target_entity_id = ?',
          [keepEntityId, absorbedEntityId],
        );

        // 3. Delete absorbed entity
        await _db.customStatement(
          'DELETE FROM story_entities WHERE id = ?',
          [absorbedEntityId],
        );

        // 4. Update cooccurrences
        await _db.customStatement(
          'DELETE FROM story_cooccurrences WHERE entity_a_id = ? OR entity_b_id = ?',
          [absorbedEntityId, absorbedEntityId],
        );
      });

      _notifyEntityChange(bookId, readThroughId);
      return Success(updatedKeep);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to merge entities', e), st);
    }
  }

  @override
  Future<Result<List<StoryRelationship>>> getRelationships(
    String bookId, {
    String readThroughId = 'default',
    String? entityId,
  }) async {
    try {
      final sql = StringBuffer('SELECT * FROM story_relationships WHERE book_id = ? AND read_through_id = ?');
      final vars = <Variable<Object>>[
        Variable<String>(bookId),
        Variable<String>(readThroughId),
      ];

      if (entityId != null) {
        sql.write(' AND (source_entity_id = ? OR target_entity_id = ?)');
        vars.add(Variable<String>(entityId));
        vars.add(Variable<String>(entityId));
      }

      sql.write(' ORDER BY confidence_score DESC');
      final rows = await _db.customSelect(sql.toString(), variables: vars).get();
      final relationships = rows.map(_mapRowToRelationship).toList();
      return Success(relationships);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to get relationships', e), st);
    }
  }

  @override
  Future<Result<void>> saveRelationship(StoryRelationship relationship) async {
    try {
      await _db.customStatement(
        '''
        INSERT INTO story_relationships (
          id, book_id, read_through_id, source_entity_id, target_entity_id, relation_type,
          confidence_score, chapter_established, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          relation_type = excluded.relation_type,
          confidence_score = excluded.confidence_score,
          chapter_established = MIN(story_relationships.chapter_established, excluded.chapter_established);
        ''',
        [
          relationship.id,
          relationship.bookId,
          relationship.readThroughId,
          relationship.sourceEntityId,
          relationship.targetEntityId,
          relationship.relationType,
          relationship.confidenceScore,
          relationship.chapterEstablished,
          relationship.createdAt.millisecondsSinceEpoch,
        ],
      );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to save relationship', e), st);
    }
  }

  @override
  Future<Result<void>> saveRelationships(List<StoryRelationship> relationships) async {
    try {
      await _db.transaction(() async {
        for (final r in relationships) {
          await saveRelationship(r);
        }
      });
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to batch save relationships', e), st);
    }
  }

  @override
  Future<Result<List<StoryEvent>>> getEvents(
    String bookId, {
    String readThroughId = 'default',
    int? maxChapter,
    List<String>? involvedEntityIds,
  }) async {
    try {
      final sql = StringBuffer('SELECT * FROM story_events WHERE book_id = ? AND read_through_id = ?');
      final vars = <Variable<Object>>[
        Variable<String>(bookId),
        Variable<String>(readThroughId),
      ];

      if (maxChapter != null) {
        sql.write(' AND chapter <= ?');
        vars.add(Variable<int>(maxChapter));
      }

      sql.write(' ORDER BY chapter ASC, created_at ASC');
      final rows = await _db.customSelect(sql.toString(), variables: vars).get();
      var events = rows.map(_mapRowToEvent).toList();

      if (involvedEntityIds != null && involvedEntityIds.isNotEmpty) {
        final targetIds = involvedEntityIds.toSet();
        events = events.where((event) {
          return event.involvedEntityIds.any(targetIds.contains);
        }).toList();
      }

      return Success(events);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to get story events', e), st);
    }
  }

  @override
  Future<Result<void>> saveEvents(List<StoryEvent> events) async {
    try {
      await _db.transaction(() async {
        for (final event in events) {
          await _db.customStatement(
            '''
            INSERT INTO story_events (
              id, book_id, read_through_id, chapter, summary, involved_entity_ids, confidence_score, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              summary = excluded.summary,
              confidence_score = excluded.confidence_score,
              involved_entity_ids = excluded.involved_entity_ids;
            ''',
            [
              event.id,
              event.bookId,
              event.readThroughId,
              event.chapter,
              event.summary,
              jsonEncode(event.involvedEntityIds),
              event.confidenceScore,
              event.createdAt.millisecondsSinceEpoch,
            ],
          );
        }
      });
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to save story events', e), st);
    }
  }

  @override
  Future<Result<List<StoryCooccurrence>>> getCooccurrences(
    String bookId, {
    String readThroughId = 'default',
  }) async {
    try {
      final rows = await _db
          .customSelect(
            'SELECT * FROM story_cooccurrences WHERE book_id = ? AND read_through_id = ? ORDER BY weight DESC',
            variables: [
              Variable<String>(bookId),
              Variable<String>(readThroughId),
            ],
          )
          .get();

      final edges = rows.map(_mapRowToCooccurrence).toList();
      return Success(edges);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to get cooccurrences', e), st);
    }
  }

  @override
  Future<Result<void>> updateCooccurrences(
    String bookId,
    List<StoryCooccurrence> edges, {
    String readThroughId = 'default',
  }) async {
    try {
      await _db.transaction(() async {
        for (final edge in edges) {
          await _db.customStatement(
            '''
            INSERT INTO story_cooccurrences (
              id, book_id, read_through_id, entity_a_id, entity_b_id, weight, last_seen_chapter
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              weight = story_cooccurrences.weight + excluded.weight,
              last_seen_chapter = MAX(story_cooccurrences.last_seen_chapter, excluded.last_seen_chapter);
            ''',
            [
              edge.id,
              edge.bookId,
              edge.readThroughId,
              edge.entityAId,
              edge.entityBId,
              edge.weight,
              edge.lastSeenChapter,
            ],
          );
        }
      });
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to update cooccurrences', e), st);
    }
  }

  @override
  Future<Result<List<ReviewItem>>> getReviewQueue(
    String bookId, {
    String readThroughId = 'default',
    ReviewStatus status = ReviewStatus.pending,
  }) async {
    try {
      final rows = await _db
          .customSelect(
            'SELECT * FROM story_review_queue WHERE book_id = ? AND read_through_id = ? AND status = ? ORDER BY created_at DESC',
            variables: [
              Variable<String>(bookId),
              Variable<String>(readThroughId),
              Variable<String>(status.id),
            ],
          )
          .get();

      final items = rows.map(_mapRowToReviewItem).toList();
      return Success(items);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to get review queue', e), st);
    }
  }

  @override
  Future<Result<void>> saveReviewItem(ReviewItem item) async {
    try {
      await _db.customStatement(
        '''
        INSERT INTO story_review_queue (
          id, book_id, read_through_id, type, entity_id, target_entity_id, candidate_name,
          target_name, confidence_score, similarity_score, cooccurrence_count,
          evidence_json, status, chapter_index, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          confidence_score = excluded.confidence_score,
          similarity_score = excluded.similarity_score,
          evidence_json = excluded.evidence_json,
          status = excluded.status;
        ''',
        [
          item.id,
          item.bookId,
          item.readThroughId,
          item.type.id,
          item.entityId,
          item.targetEntityId,
          item.candidateName,
          item.targetName,
          item.confidenceScore,
          item.similarityScore,
          item.cooccurrenceCount,
          jsonEncode(item.evidence),
          item.status.id,
          item.chapterIndex,
          item.createdAt.millisecondsSinceEpoch,
        ],
      );
        return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to save review item', e), st);
    }
  }

  @override
  Future<Result<void>> resolveReviewItem(String reviewId, ReviewStatus status) async {
    try {
      await _db.customStatement(
        'UPDATE story_review_queue SET status = ? WHERE id = ?',
        [status.id, reviewId],
      );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to resolve review item', e), st);
    }
  }

  @override
  Future<Result<void>> deleteBookStoryMemory(String bookId, {String? readThroughId}) async {
    try {
      await _db.transaction(() async {
        if (readThroughId != null) {
          await _db.customStatement(
            'DELETE FROM story_entities WHERE book_id = ? AND read_through_id = ?',
            [bookId, readThroughId],
          );
          await _db.customStatement(
            'DELETE FROM story_relationships WHERE book_id = ? AND read_through_id = ?',
            [bookId, readThroughId],
          );
          await _db.customStatement(
            'DELETE FROM story_events WHERE book_id = ? AND read_through_id = ?',
            [bookId, readThroughId],
          );
          await _db.customStatement(
            'DELETE FROM story_cooccurrences WHERE book_id = ? AND read_through_id = ?',
            [bookId, readThroughId],
          );
          await _db.customStatement(
            'DELETE FROM story_review_queue WHERE book_id = ? AND read_through_id = ?',
            [bookId, readThroughId],
          );
          await _db.customStatement(
            'DELETE FROM story_corrections WHERE book_id = ? AND read_through_id = ?',
            [bookId, readThroughId],
          );
          await _db.customStatement(
            'DELETE FROM story_read_throughs WHERE book_id = ? AND id = ?',
            [bookId, readThroughId],
          );
        } else {
          await _db.customStatement('DELETE FROM story_entities WHERE book_id = ?', [bookId]);
          await _db.customStatement('DELETE FROM story_relationships WHERE book_id = ?', [bookId]);
          await _db.customStatement('DELETE FROM story_events WHERE book_id = ?', [bookId]);
          await _db.customStatement('DELETE FROM story_cooccurrences WHERE book_id = ?', [bookId]);
          await _db.customStatement('DELETE FROM story_review_queue WHERE book_id = ?', [bookId]);
          await _db.customStatement('DELETE FROM story_corrections WHERE book_id = ?', [bookId]);
          await _db.customStatement('DELETE FROM story_scenes_fts WHERE book_id = ?', [bookId]);
          await _db.customStatement('DELETE FROM story_read_throughs WHERE book_id = ?', [bookId]);
        }
      });

      if (readThroughId != null) {
        _notifyEntityChange(bookId, readThroughId);
      } else {
        for (final entry in _entityStreamControllers.entries) {
          if (entry.key.startsWith('${bookId}_') && entry.value.hasListener) {
            entry.value.add(const []);
          }
        }
      }
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to delete book story memory', e), st);
    }
  }

  @override
  Future<Result<List<String>>> searchScenes(
    String bookId,
    String query, {
    String readThroughId = 'default',
    int? maxChapter,
    int limit = 10,
  }) async {
    try {
      final sanitized = query.replaceAll('"', '""').trim();
      if (sanitized.isEmpty) return const Success([]);

      final sql = StringBuffer(
        '''
        SELECT scene_text FROM story_scenes_fts
        WHERE book_id = ? AND story_scenes_fts MATCH ?
        ''',
      );
      final vars = <Variable<Object>>[
        Variable<String>(bookId),
        Variable<String>('"$sanitized"'),
      ];

      if (maxChapter != null) {
        sql.write(' AND CAST(chapter_index AS INTEGER) <= ?');
        vars.add(Variable<int>(maxChapter));
      }

      sql.write(' LIMIT ?');
      vars.add(Variable<int>(limit));

      final rows = await _db.customSelect(sql.toString(), variables: vars).get();
      final excerpts = rows.map((r) => r.read<String>('scene_text')).toList();
      return Success(excerpts);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to execute scene search', e), st);
    }
  }

  @override
  Future<Result<List<ReadThrough>>> getReadThroughs(String bookId) async {
    try {
      var rows = await _db.customSelect(
        'SELECT * FROM story_read_throughs WHERE book_id = ? ORDER BY created_at ASC',
        variables: [Variable<String>(bookId)],
      ).get();

      final hasDefault = rows.any((r) => r.read<String>('id') == 'default');
      if (!hasDefault) {
        final now = DateTime.now();
        final defaultRt = ReadThrough(
          id: 'default',
          bookId: bookId,
          name: 'Primary Read',
          currentChapter: 1,
          isActive: rows.isEmpty || !rows.any((r) => r.read<int>('is_active') == 1),
          createdAt: now,
          updatedAt: now,
        );
        await _db.customStatement(
          '''
          INSERT OR IGNORE INTO story_read_throughs (
            id, book_id, name, current_chapter, is_active, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            defaultRt.id,
            defaultRt.bookId,
            defaultRt.name,
            defaultRt.currentChapter,
            defaultRt.isActive ? 1 : 0,
            now.millisecondsSinceEpoch,
            now.millisecondsSinceEpoch,
          ],
        );
        rows = await _db.customSelect(
          'SELECT * FROM story_read_throughs WHERE book_id = ? ORDER BY created_at ASC',
          variables: [Variable<String>(bookId)],
        ).get();
      }

      return Success(rows.map(_mapRowToReadThrough).toList());
    } catch (e, st) {
      return Failure(DatabaseException('Failed to get read-throughs', e), st);
    }
  }

  @override
  Future<Result<ReadThrough>> getActiveReadThrough(String bookId) async {
    try {
      await getReadThroughs(bookId);

      final rows = await _db.customSelect(
        'SELECT * FROM story_read_throughs WHERE book_id = ? AND is_active = 1 LIMIT 1',
        variables: [Variable<String>(bookId)],
      ).get();

      if (rows.isNotEmpty) {
        return Success(_mapRowToReadThrough(rows.first));
      }

      final all = await getReadThroughs(bookId);
      if (all is Success<List<ReadThrough>> && all.value.isNotEmpty) {
        final first = all.value.first;
        await setActiveReadThrough(bookId, first.id);
        return Success(first.copyWith(isActive: true));
      }

      return const Failure(DatabaseException('Failed to find or create an active read-through'));
    } catch (e, st) {
      return Failure(DatabaseException('Failed to get active read-through', e), st);
    }
  }

  @override
  Future<Result<ReadThrough>> createReadThrough(
    String bookId, {
    required String name,
    bool copyFromDefault = false,
  }) async {
    try {
      // Ensure 'default' read-through exists before creating additional sessions
      await getReadThroughs(bookId);

      final now = DateTime.now();
      final id = 'rt_${now.millisecondsSinceEpoch}_${math.Random().nextInt(10000)}';
      final newRt = ReadThrough(
        id: id,
        bookId: bookId,
        name: name,
        currentChapter: 1,
        isActive: false,
        createdAt: now,
        updatedAt: now,
      );

      await _db.transaction(() async {
        await _db.customStatement(
          '''
          INSERT INTO story_read_throughs (
            id, book_id, name, current_chapter, is_active, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            newRt.id,
            newRt.bookId,
            newRt.name,
            newRt.currentChapter,
            0,
            now.millisecondsSinceEpoch,
            now.millisecondsSinceEpoch,
          ],
        );

        if (copyFromDefault) {
          final defaultEntitiesRes = await getEntities(bookId, readThroughId: 'default');
          if (defaultEntitiesRes is Success<List<StoryEntity>>) {
            final confirmedEntities = defaultEntitiesRes.value.where((e) => e.userConfirmed).toList();
            final idMap = <String, String>{};

            for (final entity in confirmedEntities) {
              final clonedId = '${newRt.id}_${entity.id}';
              idMap[entity.id] = clonedId;
              final clonedEntity = entity.copyWith(
                id: clonedId,
                readThroughId: newRt.id,
                createdAt: now,
                updatedAt: now,
              );
              await saveEntity(clonedEntity);
            }

            final defaultRelsRes = await getRelationships(bookId, readThroughId: 'default');
            if (defaultRelsRes is Success<List<StoryRelationship>>) {
              for (final rel in defaultRelsRes.value) {
                if (idMap.containsKey(rel.sourceEntityId) && idMap.containsKey(rel.targetEntityId)) {
                  final clonedRel = rel.copyWith(
                    id: '${newRt.id}_${rel.id}',
                    readThroughId: newRt.id,
                    sourceEntityId: idMap[rel.sourceEntityId]!,
                    targetEntityId: idMap[rel.targetEntityId]!,
                    createdAt: now,
                  );
                  await saveRelationship(clonedRel);
                }
              }
            }
          }
        }
      });

      return Success(newRt);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to create read-through', e), st);
    }
  }

  @override
  Future<Result<void>> setActiveReadThrough(String bookId, String readThroughId) async {
    try {
      await _db.transaction(() async {
        await _db.customStatement(
          'UPDATE story_read_throughs SET is_active = 0 WHERE book_id = ?',
          [bookId],
        );
        await _db.customStatement(
          'UPDATE story_read_throughs SET is_active = 1 WHERE book_id = ? AND id = ?',
          [bookId, readThroughId],
        );
      });
      _notifyEntityChange(bookId, readThroughId);
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to set active read-through', e), st);
    }
  }

  @override
  Future<Result<void>> updateReadThroughProgress(
    String bookId,
    String readThroughId,
    int chapter,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.customStatement(
        'UPDATE story_read_throughs SET current_chapter = ?, updated_at = ? WHERE book_id = ? AND id = ?',
        [chapter, now, bookId, readThroughId],
      );
      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to update read-through progress', e), st);
    }
  }

  @override
  Future<Result<void>> deleteReadThrough(String bookId, String readThroughId) async {
    try {
      final activeRes = await getActiveReadThrough(bookId);
      final wasActive = activeRes is Success<ReadThrough> && activeRes.value.id == readThroughId;

      await deleteBookStoryMemory(bookId, readThroughId: readThroughId);

      if (wasActive) {
        final remaining = await getReadThroughs(bookId);
        if (remaining is Success<List<ReadThrough>> && remaining.value.isNotEmpty) {
          await setActiveReadThrough(bookId, remaining.value.first.id);
        }
      }

      return const Success(null);
    } catch (e, st) {
      return Failure(DatabaseException('Failed to delete read-through', e), st);
    }
  }

  // Row mapping helpers
  StoryEntity _mapRowToStoryEntity(QueryRow row) {
    List<String> aliases = [];
    final aliasesRaw = row.read<String?>('aliases');
    if (aliasesRaw != null && aliasesRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(aliasesRaw);
        if (decoded is List) {
          aliases = decoded.whereType<String>().toList();
        }
      } catch (_) {}
    }

    Map<String, dynamic> attributes = {};
    final attributesRaw = row.read<String?>('attributes');
    if (attributesRaw != null && attributesRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(attributesRaw);
        if (decoded is Map) {
          attributes = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return StoryEntity(
      id: row.read<String>('id'),
      bookId: row.read<String>('book_id'),
      readThroughId: row.read<String?>('read_through_id') ?? 'default',
      type: StoryEntityType.fromId(row.read<String>('type')),
      canonicalName: row.read<String>('canonical_name'),
      aliases: aliases,
      confidenceScore: row.read<double>('confidence_score'),
      tier: ConfidenceTier.fromId(row.read<String>('tier')),
      userConfirmed: (row.read<int>('user_confirmed')) == 1,
      attributes: attributes,
      firstSeenChapter: row.read<int>('first_seen_chapter'),
      lastSeenChapter: row.read<int>('last_seen_chapter'),
      mentionCount: row.read<int>('mention_count'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('updated_at')),
    );
  }

  StoryRelationship _mapRowToRelationship(QueryRow row) {
    return StoryRelationship(
      id: row.read<String>('id'),
      bookId: row.read<String>('book_id'),
      readThroughId: row.read<String?>('read_through_id') ?? 'default',
      sourceEntityId: row.read<String>('source_entity_id'),
      targetEntityId: row.read<String>('target_entity_id'),
      relationType: row.read<String>('relation_type'),
      confidenceScore: row.read<double>('confidence_score'),
      chapterEstablished: row.read<int>('chapter_established'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
    );
  }

  StoryEvent _mapRowToEvent(QueryRow row) {
    List<String> involvedIds = [];
    final raw = row.read<String?>('involved_entity_ids');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          involvedIds = decoded.whereType<String>().toList();
        }
      } catch (_) {}
    }

    return StoryEvent(
      id: row.read<String>('id'),
      bookId: row.read<String>('book_id'),
      readThroughId: row.read<String?>('read_through_id') ?? 'default',
      chapter: row.read<int>('chapter'),
      summary: row.read<String>('summary'),
      involvedEntityIds: involvedIds,
      confidenceScore: row.read<double>('confidence_score'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
    );
  }

  StoryCooccurrence _mapRowToCooccurrence(QueryRow row) {
    return StoryCooccurrence(
      id: row.read<String>('id'),
      bookId: row.read<String>('book_id'),
      readThroughId: row.read<String?>('read_through_id') ?? 'default',
      entityAId: row.read<String>('entity_a_id'),
      entityBId: row.read<String>('entity_b_id'),
      weight: row.read<int>('weight'),
      lastSeenChapter: row.read<int>('last_seen_chapter'),
    );
  }

  ReviewItem _mapRowToReviewItem(QueryRow row) {
    List<String> evidence = [];
    final raw = row.read<String?>('evidence_json');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          evidence = decoded.whereType<String>().toList();
        }
      } catch (_) {}
    }

    return ReviewItem(
      id: row.read<String>('id'),
      bookId: row.read<String>('book_id'),
      readThroughId: row.read<String?>('read_through_id') ?? 'default',
      type: ReviewType.fromId(row.read<String>('type')),
      entityId: row.read<String>('entity_id'),
      targetEntityId: row.read<String?>('target_entity_id'),
      candidateName: row.read<String>('candidate_name'),
      targetName: row.read<String?>('target_name'),
      confidenceScore: row.read<double>('confidence_score'),
      similarityScore: row.read<double?>('similarity_score'),
      cooccurrenceCount: row.read<int>('cooccurrence_count'),
      evidence: evidence,
      status: ReviewStatus.fromId(row.read<String>('status')),
      chapterIndex: row.read<int>('chapter_index'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
    );
  }

  ReadThrough _mapRowToReadThrough(QueryRow row) {
    return ReadThrough(
      id: row.read<String>('id'),
      bookId: row.read<String>('book_id'),
      name: row.read<String>('name'),
      currentChapter: row.read<int>('current_chapter'),
      isActive: (row.read<int>('is_active')) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('updated_at')),
    );
  }
}
