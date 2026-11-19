/// CDN voice-pack downloader (NTD §3.5, M5): queued → downloading →
/// verifying → ready, with sha256 verification per file and an atomic
/// `.tmp-<id>` → `<id>` directory rename on success. Failure lands in
/// `corrupt` — never a dead end, platform TTS keeps narrating and the
/// gallery offers a retry.
///
/// Every network and filesystem dependency is injected so the whole state
/// machine is testable without touching a CDN (see the test suite).
library;

import 'dart:async';
import 'dart:io' show Directory, File, IOException;

import 'package:crypto/crypto.dart' show Digest, sha256;
import 'package:http/http.dart' as http;

import 'package:atlas_app/reader/speech/packs/voice_pack_manifest.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_store.dart';

/// Outcome of one download attempt.
enum VoicePackDownloadResult { ready, failed, cancelled }

/// Live progress of the active download.
class VoicePackProgress {
  const VoicePackProgress({
    required this.packId,
    required this.file,
    required this.bytes,
    required this.totalBytes,
  });

  final String packId;
  final String file;
  final int bytes;
  final int totalBytes;

  double? get fraction =>
      totalBytes > 0 ? (bytes / totalBytes).clamp(0.0, 1.0) : null;
}







/// One CDN-hosted pack flavor: files are fetched from
/// `<catalog base>/<family>/<packId>/<fileName>`.
class VoicePackLocation {
  const VoicePackLocation({required this.baseUrl});

  /// e.g. `https://cdn.example/atlas_tts/voices`
  final String baseUrl;

  Uri fileUri({
    required String familyId,
    required String packId,
    required String fileName,
  }) =>
      Uri.parse('$baseUrl/$familyId/$packId/$fileName');
}
class VoicePackDownloader {
  VoicePackDownloader({
    required this.store,
    required this.documentsRoot,
    required this.location,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final VoicePackStore store;
  final String documentsRoot;
  final VoicePackLocation location;
  final http.Client _client;

  /// Only one download at a time (a 60 MB fetch is exactly the kind of
  /// work a user should serialize); a second request joins the in-flight
  /// one instead of racing it.
  final Map<String, Completer<VoicePackDownloadResult>> _running = {};
  final Set<String> _cancelled = {};
  final _progress = StreamController<VoicePackProgress>.broadcast();
  final _stateChanges = StreamController<String>.broadcast();

  Stream<VoicePackProgress> get progressStream => _progress.stream;
  Stream<String> get stateChangeStream => _stateChanges.stream;
  Iterable<String> get activePackIds => _running.keys;

  /// Downloads [flavor] into `<docs>/atlas_tts/voices/<packId>` and marks
  /// the record ready. Concurrent calls for the same pack join in flight.
  Future<VoicePackDownloadResult> download(
    VoicePackFlavor flavor, {
    required String familyId,
  }) async {
    if (!flavor.isValid) {
      await _markCorrupt(flavor.packId, familyId, flavor, 'invalid manifest');
      return VoicePackDownloadResult.failed;
    }
    final existing = _running[flavor.packId];
    if (existing != null) return existing.future;

    final completer = Completer<VoicePackDownloadResult>();
    _running[flavor.packId] = completer;
    // _run handles its own errors; this is a pure safety net.
    unawaited(
      _run(flavor, familyId: familyId).then(
        (result) {
          if (!completer.isCompleted) completer.complete(result);
        },
        onError: (Object _) {
          if (!completer.isCompleted) {
            completer.complete(VoicePackDownloadResult.failed);
          }
        },
      ),
    );
    return completer.future;
  }

  /// Cooperative cancellation: checked between chunks.
  void cancel(String packId) => _cancelled.add(packId);

  Future<VoicePackDownloadResult> _run(
    VoicePackFlavor flavor, {
    required String familyId,
  }) async {
    final packId = flavor.packId;
    try {
      _cancelled.remove(packId);
      await store.upsert(
        VoicePackRecord(
          packId: packId,
          familyId: familyId,
          quality: flavor.quality,
          state: VoicePackState.downloading,
          bytes: 0,
          totalBytes: flavor.sizeBytes,
          updatedAt: DateTime.now(),
        ),
      );
      _stateChanges.add(packId);

      final tmpDir = Directory(store.tmpDirectory(documentsRoot, packId));
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true); // stale partial from a crash
      }
      tmpDir.createSync(recursive: true);

      var transferred = 0;
      for (final entry in flavor.files.entries) {
        if (_cancelled.contains(packId)) {
          return await _abort(packId, tmpDir);
        }
        final sha = await _downloadFileToTmp(
          location.fileUri(
            familyId: familyId,
            packId: packId,
            fileName: entry.key,
          ),
          '${tmpDir.path}/${entry.key}',
          onBytes: (n) {
            transferred += n;
            _progress.add(
              VoicePackProgress(
                packId: packId,
                file: entry.key,
                bytes: transferred,
                totalBytes: flavor.sizeBytes,
              ),
            );
          },
        );
        if (_cancelled.contains(packId)) {
          return await _abort(packId, tmpDir);
        }
        // Case-insensitive compare: manifests are lowercase, we stay exact.
        if (sha == null || sha != entry.value.toLowerCase()) {
          await _markCorrupt(packId, familyId, flavor, 'sha256 mismatch');
          return VoicePackDownloadResult.failed;
        }
      }

      await store.upsert(
        VoicePackRecord(
          packId: packId,
          familyId: familyId,
          quality: flavor.quality,
          state: VoicePackState.verifying,
          bytes: flavor.sizeBytes,
          totalBytes: flavor.sizeBytes,
          updatedAt: DateTime.now(),
        ),
      );
      _stateChanges.add(packId);

      // Atomic activation (NTD §3.5): the scratch directory is renamed
      // into place; a previous install is replaced whole, never mixed.
      final dest = Directory(store.packDirectory(documentsRoot, packId));
      if (dest.existsSync()) dest.deleteSync(recursive: true);
      tmpDir.renameSync(dest.path);

      await store.upsert(
        VoicePackRecord(
          packId: packId,
          familyId: familyId,
          quality: flavor.quality,
          state: VoicePackState.ready,
          bytes: flavor.sizeBytes,
          totalBytes: flavor.sizeBytes,
          updatedAt: DateTime.now(),
        ),
      );
      _stateChanges.add(packId);
      return VoicePackDownloadResult.ready;
    } catch (e) {
      if (_cancelled.contains(packId)) {
        return _abort(
          packId,
          Directory(store.tmpDirectory(documentsRoot, packId)),
        );
      }
      await _markCorrupt(
        packId,
        familyId,
        flavor,
        e is IOException ? 'network' : '$e',
      );
      return VoicePackDownloadResult.failed;
    } finally {
      _running.remove(packId);
      _cancelled.remove(packId);
    }
  }

  /// Streams [url] into [target], returning its sha256 — or null when the
  /// response is unusable. Consumes the body in chunks so a 60 MB model
  /// never materializes in memory.
  Future<String?> _downloadFileToTmp(
    Uri url,
    String target, {
    required void Function(int chunkBytes) onBytes,
  }) async {
    final request = http.Request('GET', url);
    final http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } catch (_) {
      return null;
    }
    if (response.statusCode != 200) {
      await response.stream.drain<void>().catchError((_) => <int>[]);
      return null;
    }
    try {
      final targetFile = File(target);
      // Nested keys ("espeak-ng-data/lang/…") need their subdirectories.
      targetFile.parent.createSync(recursive: true);
      final sink = targetFile.openWrite();
      final digestSink = _LastDigestSink();
      final hasher = sha256.startChunkedConversion(digestSink);
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          hasher.add(chunk);
          onBytes(chunk.length);
        }
        await sink.flush();
      } finally {
        hasher.close();
        await sink.close();
      }
      return digestSink.digest?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<VoicePackDownloadResult> _abort(
    String packId,
    Directory tmpDir,
  ) async {
    try {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    } catch (_) {}
    await store.delete(packId);
    _stateChanges.add(packId);
    return VoicePackDownloadResult.cancelled;
  }

  Future<void> _markCorrupt(
    String packId,
    String familyId,
    VoicePackFlavor flavor,
    String reason,
  ) async {
    try {
      final tmp = Directory(store.tmpDirectory(documentsRoot, packId));
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } catch (_) {}
    await store.upsert(
      VoicePackRecord(
        packId: packId,
        familyId: familyId,
        quality: flavor.quality,
        state: VoicePackState.corrupt,
        bytes: 0,
        totalBytes: flavor.sizeBytes,
        error: reason,
        updatedAt: DateTime.now(),
      ),
    );
    _stateChanges.add(packId);
  }

  /// Startup scan: recover interrupted rows and clean stale `.tmp-*`
  /// directories (a crash mid-download leaves both behind).
  Future<void> recoverStaleState() async {
    await store.recoverInterrupted();
    final voicesRoot = Directory(
      '$documentsRoot/atlas_tts/voices',
    );
    try {
      if (voicesRoot.existsSync()) {
        for (final dir in voicesRoot.listSync().whereType<Directory>()) {
          final name = basenameOf(dir.path);
          if (name.startsWith('.tmp-')) {
            try {
              dir.deleteSync(recursive: true);
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _progress.close();
    await _stateChanges.close();
  }
}

/// Collects the final [Digest] from a chunked sha256 conversion.
class _LastDigestSink implements Sink<Digest> {
  Digest? digest;
  @override
  void add(Digest data) => digest = data;
  @override
  void close() {}
}
