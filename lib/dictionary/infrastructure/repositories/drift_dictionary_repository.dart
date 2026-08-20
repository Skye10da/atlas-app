import 'package:drift/drift.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/dictionary/domain/entities/dictionary_word_entity.dart';
import 'package:atlas_app/dictionary/domain/repository_interfaces/dictionary_repository_interface.dart';

class DriftDictionaryRepository implements DictionaryRepositoryInterface {
  DriftDictionaryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<DictionaryWordEntity>> getAll() async {
    final rows = await _db.select(_db.dictionaryWords).get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> save(DictionaryWordEntity word) async {
    await _db
        .into(_db.dictionaryWords)
        .insertOnConflictUpdate(
          DictionaryWordsCompanion.insert(
            id: word.id,
            word: word.word,
            language: word.language,
            languageLabel: word.languageLabel,
            source: Value(word.source),
            sourceLabel: Value(word.sourceLabel),
            phonetic: Value(word.phonetic),
            partOfSpeech: word.partOfSpeech,
            definition: word.definition,
            fullJson: word.fullJson,
            savedAt: word.savedAt,
            sourceSentence: Value(word.sourceSentence),
            sourceTitle: Value(word.sourceTitle),
            reviewLevel: Value(word.reviewLevel),
            reviewCount: Value(word.reviewCount),
            lastReviewedAt: Value(word.lastReviewedAt),
            nextReviewAt: Value(word.nextReviewAt),
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.dictionaryWords)..where((w) => w.id.equals(id))).go();
  }

  @override
  Future<bool> exists(String id) async {
    final count = await (_db.select(
      _db.dictionaryWords,
    )..where((w) => w.id.equals(id))).get();
    return count.isNotEmpty;
  }

  DictionaryWordEntity _fromRow(DictionaryWord row) {
    return DictionaryWordEntity(
      id: row.id,
      word: row.word,
      language: row.language,
      languageLabel: row.languageLabel,
      source: row.source,
      sourceLabel: row.sourceLabel,
      phonetic: row.phonetic,
      partOfSpeech: row.partOfSpeech,
      definition: row.definition,
      fullJson: row.fullJson,
      savedAt: row.savedAt,
      sourceSentence: row.sourceSentence,
      sourceTitle: row.sourceTitle,
      reviewLevel: row.reviewLevel,
      reviewCount: row.reviewCount,
      lastReviewedAt: row.lastReviewedAt,
      nextReviewAt: row.nextReviewAt,
    );
  }
}
