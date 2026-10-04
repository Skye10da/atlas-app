import 'package:atlas_app/reader/speech/pronunciation/models/pronunciation_rule.dart';
import 'package:atlas_app/reader/speech/pronunciation/pronunciation_service.dart';

/// Repository: single source of truth for pronunciation lexicon.
/// Transforms raw service models → domain `PronunciationRule`, handles defaults.
class PronunciationRepository {
  PronunciationRepository({PronunciationService? service}) : _service = service ?? const PronunciationService();

  final PronunciationService _service;
  List<PronunciationRule>? _cached;

  Future<List<PronunciationRule>> getRules() async {
    if (_cached != null) return _cached!;
    final raw = await _service.fetchRaw();
    if (raw == null) {
      _cached = PronounCatalog.cloneDefaults();
      await _service.persistRaw(_cached!.map((r) => r.toJson()).toList());
      return _cached!;
    }
    try {
      final loaded = raw.map((m) => PronunciationRule.fromJson(m)).toList();
      final existingIds = loaded.map((r) => r.id).toSet();
      final missingDefaults =
          PronounCatalog.defaults.where((d) => !existingIds.contains(d.id));
      if (missingDefaults.isNotEmpty) {
        _cached = [...missingDefaults, ...loaded];
      } else {
        _cached = loaded;
      }
      return _cached!;
    } catch (_) {
      _cached = PronounCatalog.cloneDefaults();
      return _cached!;
    }
  }

  Future<void> saveRules(List<PronunciationRule> rules) async {
    _cached = List.unmodifiable(rules);
    await _service.persistRaw(rules.map((r) => r.toJson()).toList());
  }

  Future<void> resetToDefaults() async {
    _cached = PronounCatalog.cloneDefaults();
    await _service.persistRaw(_cached!.map((r) => r.toJson()).toList());
  }

  void invalidateCache() => _cached = null;
}
