import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/dictionary/domain/entities/dictionary_word_entity.dart';
import 'package:atlas_app/dictionary/domain/repository_interfaces/dictionary_repository_interface.dart';
import 'package:atlas_app/dictionary/infrastructure/repositories/drift_dictionary_repository.dart';

final dictionaryRepositoryProvider = Provider<DictionaryRepositoryInterface>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return DriftDictionaryRepository(db);
});

final savedWordsProvider = FutureProvider<List<DictionaryWordEntity>>((
  ref,
) async {
  final repo = ref.watch(dictionaryRepositoryProvider);
  return repo.getAll();
});

final wordExistsProvider = FutureProvider.family<bool, String>((ref, id) async {
  final repo = ref.watch(dictionaryRepositoryProvider);
  return repo.exists(id);
});
