/// Persistence for the M5 voice-pack system (NTD §3.5).
///
/// `voice_packs` tracks download states; files live under
/// `<docs>/atlas_tts/voices/<pack-id>/` — exactly the path
/// [NeuralTtsDriver.listVoices]/loadVoice already discover, so a `ready`
/// pack is automatically a usable voice.
///
/// The table is created with idempotent raw SQL instead of a drift table
/// definition: adding a codegen table means a build_runner regen of
/// `database.g.dart` (the repo notes analyzer-plugin issues with drift
/// table definitions), and the store only needs keyed lookups that map
/// cleanly onto `customSelect`. Same precedent as `notification_history`.
library;

import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_manifest.dart';

/// Download lifecycle per pack id (NTD: queued/downloading/ready/corrupt;
/// `verifying` splits the sha256 pass from the byte transfer).
enum VoicePackState {
  queued,
  downloading,
  verifying,
  ready,
  corrupt,
}

extension VoicePackStateName on VoicePackState {
  String get name => switch (this) {
    VoicePackState.queued => 'queued',
    VoicePackState.downloading => 'downloading',
    VoicePackState.verifying => 'verifying',
    VoicePackState.ready => 'ready',
    VoicePackState.corrupt => 'corrupt',
  };

  static VoicePackState from(String raw) => switch (raw) {
    'downloading' => VoicePackState.downloading,
    'verifying' => VoicePackState.verifying,
    'ready' => VoicePackState.ready,
    'corrupt' => VoicePackState.corrupt,
    _ => VoicePackState.queued,
  };
}

/// One row of `voice_packs`.
class VoicePackRecord {
  const VoicePackRecord({
    required this.packId,
    required this.familyId,
    required this.quality,
    required this.state,
    required this.bytes,
    required this.totalBytes,
    required this.updatedAt,
    this.error,
  });

  final String packId;
  final String familyId;
  final VoicePackQuality quality;
  final VoicePackState state;
  final int bytes;
  final int totalBytes;
  final DateTime updatedAt;
  final String? error;

  double? get progress =>
      state == VoicePackState.ready
          ? 1.0
          : (totalBytes > 0 ? (bytes / totalBytes).clamp(0.0, 1.0) : null);
}

/// The runtime pack root: `<documents>/atlas_tts/voices`. The resolver
/// mirrors [NeuralTtsDriver]'s sync gate, but async via path_provider and
/// therefore usable on all platforms. Returns null when the sandbox is
/// unknown (web, exotic desktop profiles).
Future<String?> voicePackRoot({String? documentsRoot}) async {
  final root = documentsRoot;
  if (root != null) return '$root/atlas_tts/voices';
  return null;
}

/// Persistence + file-system store for voice packs.
class VoicePackStore {
  VoicePackStore({
    required this.database,
    List<String> Function()? packDirsOverride,
  }) : _packDirsOverride = packDirsOverride;

  final AppDatabase database;
  final List<String> Function()? _packDirsOverride;

  static const _table = 'voice_packs';
  static const _qualityPrefsKey = 'voice_pack_quality_prefs';

  /// Ensures the raw-SQL table exists. Cheap and idempotent; called before
  /// every statement group like the defensive migrations in database.dart.
  Future<void> ensureTable() => database.customStatement('''
    CREATE TABLE IF NOT EXISTS $_table (
      pack_id TEXT NOT NULL PRIMARY KEY,
      family_id TEXT NOT NULL,
      quality TEXT NOT NULL,
      state TEXT NOT NULL,
      bytes INTEGER NOT NULL DEFAULT 0,
      total_bytes INTEGER NOT NULL DEFAULT 0,
      error TEXT,
      updated_at INTEGER NOT NULL
    );
  ''');

  Future<void> upsert(VoicePackRecord record) async {
    await ensureTable();
    await database.customStatement(
      'INSERT INTO $_table (pack_id, family_id, quality, state, bytes, '
      'total_bytes, error, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(pack_id) DO UPDATE SET family_id=excluded.family_id, '
      'quality=excluded.quality, state=excluded.state, bytes=excluded.bytes, '
      'total_bytes=excluded.total_bytes, error=excluded.error, '
      'updated_at=excluded.updated_at;',
      [
        record.packId,
        record.familyId,
        record.quality.name,
        record.state.name,
        record.bytes,
        record.totalBytes,
        record.error,
        record.updatedAt.millisecondsSinceEpoch,
      ],
    );
  }

  Future<VoicePackRecord?> get(String packId) async {
    await ensureTable();
    final rows = await database
        .customSelect(
          'SELECT * FROM $_table WHERE pack_id = ?',
          variables: [Variable(packId)],
        )
        .get();
    return rows.isEmpty ? null : _fromRow(rows.first.data);
  }

  Future<List<VoicePackRecord>> all() async {
    await ensureTable();
    final rows = await database.customSelect(
      'SELECT * FROM $_table ORDER BY updated_at DESC',
    ).get();
    return rows
        .map((r) => _fromRow(r.data))
        .whereType<VoicePackRecord>()
        .toList();
  }

  /// Marks anything mid-download as corrupt at startup (partial writes die
  /// with the process; the scan recovers them into the retry state).
  Future<void> recoverInterrupted() async {
    await ensureTable();
    for (final state in [VoicePackState.queued, VoicePackState.downloading]) {
      await database.customStatement(
        "UPDATE $_table SET state = 'corrupt', "
        "error = 'interrupted', updated_at = ? WHERE state = ?",
        [DateTime.now().millisecondsSinceEpoch, state.name],
      );
    }
  }

  Future<void> delete(String packId) async {
    await ensureTable();
    await database.customStatement(
      'DELETE FROM $_table WHERE pack_id = ?',
      [packId],
    );
    // File cleanup is the caller's job (it owns the directory).
  }

  VoicePackRecord? _fromRow(Map<String, Object?> row) {
    try {
      final packId = row['pack_id'] as String?;
      if (packId == null || packId.isEmpty) return null;
      return VoicePackRecord(
        packId: packId,
        familyId: row['family_id'] as String? ?? '',
        quality: VoicePackQuality.values.firstWhere(
          (q) => q.name == row['quality'],
          orElse: () => VoicePackQuality.standard,
        ),
        state: VoicePackStateName.from(row['state'] as String? ?? ''),
        bytes: (row['bytes'] as num?)?.toInt() ?? 0,
        totalBytes: (row['total_bytes'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (row['updated_at'] as num?)?.toInt() ?? 0,
        ),
        error: row['error'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Files on disk
  // -------------------------------------------------------------------------

  /// Absolute path of the pack directory (also the target of the atomic
  /// rename after a successful download).
  String packDirectory(String documentsRoot, String packId) =>
      '$documentsRoot/atlas_tts/voices/$packId';

  /// Download scratch directory, renamed on success (NTD: atomic swap).
  String tmpDirectory(String documentsRoot, String packId) =>
      '$documentsRoot/atlas_tts/voices/.tmp-$packId';

  /// Pack ids present on disk (driver-discoverable directories).
  List<String> installedPackIds(String documentsRoot) {
    final override = _packDirsOverride;
    if (override != null) return override();
    try {
      final root = Directory(
        '$documentsRoot/atlas_tts/voices',
      );
      if (!root.existsSync()) return const [];
      return root
          .listSync()
          .whereType<Directory>()
          .where((d) => !basenameOf(d.path).startsWith('.tmp-'))
          .map((d) => basenameOf(d.path))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // -------------------------------------------------------------------------
  // Quality preference (per family; explicit per-voice choice, remembered)
  // -------------------------------------------------------------------------

  Future<VoicePackQuality?> preferredQuality(
    String familyId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_qualityPrefsKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final q = map[familyId] as String?;
      return VoicePackQuality.values
          .where((v) => v.name == q)
          .firstOrNull;
    } catch (_) {
      return null;
    }
  }  Future<void> setPreferredQuality(
    String familyId,
    VoicePackQuality quality,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    try {
      final raw = prefs.getString(_qualityPrefsKey);
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is Map<String, dynamic>) map.addAll(decoded);
    } catch (_) {}
    map[familyId] = quality.name;
    await prefs.setString(_qualityPrefsKey, jsonEncode(map));
  }
}

// Re-exported for the downloader: hash checks belong to the pack system.
String voicePackSha256OfBytes(List<int> bytes) =>
    sha256.convert(bytes).toString();

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Last path segment across platforms ('/' on device, '\' on Windows hosts
/// running the test suite).
String basenameOf(String path) =>
    path.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).last;
