import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/atlas_glossary_repository_interface.dart';
import 'package:atlas_app/reader/infrastructure/repositories/shared_prefs_atlas_glossary_repository.dart';

/// The persistence layer behind the per-novel reader glossary.
final atlasGlossaryRepositoryProvider = Provider<AtlasGlossaryRepository>((ref) {
  return const SharedPrefsAtlasGlossaryRepository();
});

/// The user's glossary entries for [bookId]. Watching this rebuilds the reader
/// whenever a term changes, which is what makes the replacement apply at render
/// time.
final atlasGlossaryProvider =
    FutureProvider.family<List<AtlasGlossaryEntry>, String>((ref, bookId) {
  return ref.watch(atlasGlossaryRepositoryProvider).load(bookId);
});

/// Mutation surface for the glossary. Callers invalidate
/// [atlasGlossaryProvider] after an operation so watched content refreshes.
final atlasGlossaryControllerProvider = Provider<AtlasGlossaryController>((ref) {
  return AtlasGlossaryController(ref.watch(atlasGlossaryRepositoryProvider));
});

class AtlasGlossaryController {
  AtlasGlossaryController(this._repo);

  final AtlasGlossaryRepository _repo;

  /// Ensures [term] has a glossary entry carrying [replacement]. When an entry
  /// already exists for the term the replacement is added (or, if already one
  /// of its options, just made active); otherwise a new entry is created with
  /// it as the only option.
  Future<void> upsertTerm(String bookId, String term, String replacement) async {
    final normalized = term.trim();
    final option = replacement.trim();
    if (normalized.isEmpty || option.isEmpty) return;

    final entries = await _repo.load(bookId);
    final index = entries.indexWhere((e) => e.term == normalized);
    if (index >= 0) {
      final entry = entries[index];
      final optionIndex = entry.replacements.indexOf(option);
      entries[index] = entry.copyWith(
        replacements: optionIndex >= 0
            ? entry.replacements
            : [...entry.replacements, option],
        activeIndex: optionIndex >= 0 ? optionIndex : entry.replacements.length,
      );
    } else {
      entries.add(AtlasGlossaryEntry(
        id: '$bookId:$normalized',
        bookId: bookId,
        term: normalized,
        replacements: [option],
        createdAt: DateTime.now(),
      ));
    }
    await _repo.save(bookId, entries);
  }

  /// Adds another replacement option to an existing entry, leaving the active
  /// choice untouched.
  Future<void> addReplacement(String bookId, String id, String replacement) async {
    final option = replacement.trim();
    if (option.isEmpty) return;
    final entries = await _repo.load(bookId);
    final index = entries.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final entry = entries[index];
    if (entry.replacements.contains(option)) return;
    entries[index] = entry.copyWith(
      replacements: [...entry.replacements, option],
    );
    await _repo.save(bookId, entries);
  }

  /// Makes entry [id] display its [activeIndex]-th replacement option.
  Future<void> setActiveReplacement(String bookId, String id, int activeIndex) async {
    final entries = await _repo.load(bookId);
    final index = entries.indexWhere((e) => e.id == id);
    if (index < 0) return;
    entries[index] = entries[index].copyWith(activeIndex: activeIndex);
    await _repo.save(bookId, entries);
  }

  /// Removes an entry entirely so the original term renders again.
  Future<void> removeEntry(String bookId, String id) async {
    final entries = await _repo.load(bookId);
    final updated = [for (final e in entries) if (e.id != id) e];
    if (updated.length == entries.length) return;
    await _repo.save(bookId, updated);
  }
}