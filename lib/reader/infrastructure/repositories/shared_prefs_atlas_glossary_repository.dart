import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/atlas_glossary_repository_interface.dart';

/// `SharedPreferences`-backed [AtlasGlossaryRepository].
///
/// Each book's entries are stored under its own key (`atlas_glossary_<bookId>`)
/// as a JSON array, so loading one novel never touches another's glossary.
class SharedPrefsAtlasGlossaryRepository implements AtlasGlossaryRepository {
  const SharedPrefsAtlasGlossaryRepository();

  static String _key(String bookId) => 'atlas_glossary_$bookId';

  @override
  Future<List<AtlasGlossaryEntry>> load(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(bookId));
    if (raw == null) return <AtlasGlossaryEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <AtlasGlossaryEntry>[];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>)
            AtlasGlossaryEntry.fromJson(item),
      ];
    } catch (_) {
      return <AtlasGlossaryEntry>[];
    }
  }

  @override
  Future<void> save(String bookId, List<AtlasGlossaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(bookId),
      jsonEncode([for (final e in entries) e.toJson()]),
    );
  }
}