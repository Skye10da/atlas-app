import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How many recent queries the field shows.
const recentSearchesLimit = 5;

const _recentSearchesKey = 'find_new.recent_searches';

final recentSearchesProvider =
    AutoDisposeNotifierProvider<RecentSearchesNotifier, List<String>>(
      RecentSearchesNotifier.new,
    );

/// The last few queries, shown as tappable rows when the search field is
/// focused and empty. Persisted in shared_preferences, but strictly lazy:
/// the store is read only when the rows are actually on screen — nothing
/// runs at app start.
class RecentSearchesNotifier extends AutoDisposeNotifier<List<String>> {
  bool _isInitialized = false;
  List<String> _entries = const [];
  Completer<void>? _restored;
  bool _touched = false;

  @override
  List<String> build() {
    if (!_isInitialized) {
      _isInitialized = true;
      _entries = const [];
      _restored = Completer<void>();
      // Fire-and-forget restore; adds wait for it so a fast early add
      // can't be clobbered by the slow store read.
      unawaited(_restore());
    }
    return _entries;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored =
        prefs.getStringList(_recentSearchesKey) ?? const <String>[];
    if (!_touched) {
      _entries = stored
          .where((t) => t.trim().isNotEmpty)
          .take(recentSearchesLimit)
          .toList(growable: false);
      _commit();
    }
    _restored?.complete();
    _restored = null;
  }

  /// Records a query that actually ran as the most recent one.
  Future<void> add(String term) async {
    await _restored?.future;
    _touched = true;
    final trimmed = term.trim();
    if (trimmed.isEmpty || trimmed.length < minSearchCharactersForRecent) {
      return;
    }
    final next = [
      trimmed,
      for (final t in _entries)
        if (t.toLowerCase() != trimmed.toLowerCase()) t,
    ].take(recentSearchesLimit).toList(growable: false);
    _entries = next;
    _commit();
    unawaited(_persist(next));
  }

  void _commit() {
    try {
      state = _entries;
    } on StateError {
      // Disposed between the restore completing and this write — ignore.
    }
  }

  Future<void> _persist(List<String> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, entries);
  }
}

/// Only real searches (2+ characters, like the search rule) are remembered.
const minSearchCharactersForRecent = 2;
