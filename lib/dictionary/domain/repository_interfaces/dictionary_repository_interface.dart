import 'package:atlas_app/dictionary/domain/entities/dictionary_word_entity.dart';

abstract interface class DictionaryRepositoryInterface {
  Future<List<DictionaryWordEntity>> getAll();
  Future<void> save(DictionaryWordEntity word);
  Future<void> delete(String id);
  Future<bool> exists(String id);
}
