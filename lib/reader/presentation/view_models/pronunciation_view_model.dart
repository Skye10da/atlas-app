import 'package:flutter/foundation.dart';

import 'package:atlas_app/reader/speech/pronunciation/models/pronunciation_rule.dart';
import 'package:atlas_app/reader/speech/pronunciation/pronunciation_repository.dart';

/// ViewModel: manages pronunciation lexicon UI state.
/// MVVM — injected via constructor, exposes immutable snapshots.
class PronunciationViewModel extends ChangeNotifier {
  PronunciationViewModel({required PronunciationRepository repository}) : _repository = repository;

  final PronunciationRepository _repository;

  List<PronunciationRule> _rules = [];
  List<PronunciationRule> get rules => List.unmodifiable(_rules);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;
  set isEnabled(bool v) {
    _isEnabled = v;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _rules = await _repository.getRules();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> save() async {
    _error = null;
    try {
      await _repository.saveRules(_rules);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void addRule(PronunciationRule rule) {
    _rules = [..._rules, rule];
    notifyListeners();
  }

  void updateRule(String id, PronunciationRule updated) {
    _rules = _rules.map((r) => r.id == id ? updated : r).toList();
    notifyListeners();
  }

  void toggleRule(String id, bool enabled) {
    _rules = _rules.map((r) => r.id == id ? r.copyWith(isEnabled: enabled) : r).toList();
    notifyListeners();
  }

  void removeRule(String id) {
    _rules = _rules.where((r) => r.id != id).toList();
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _error = null;
    try {
      await _repository.resetToDefaults();
      _rules = await _repository.getRules();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
