import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/updater/domain/entities/app_release.dart';
import 'package:atlas_app/updater/domain/repositories/app_update_repository.dart';

/// Events emitted while the updater pulls an artifact down.
sealed class DownloadEvent {
  const DownloadEvent();
}

/// 0.0 … 1.0 progress across the whole body.
final class DownloadProgress extends DownloadEvent {
  const DownloadProgress(this.fraction);
  final double fraction;
}

/// Terminal event: the artifact is fully written and hash-verified.
final class DownloadDone extends DownloadEvent {
  const DownloadDone(this.filePath);
  final String filePath;
}

/// Captures the final [Digest] the chunked SHA-256 conversion produces on
/// close. Accumulator-style convenience sinks are not exported by the crypto
/// package on all versions, so the tiny sink is inlined here.
final class _DigestCollector implements ChunkedConversionSink<Digest> {
  Digest? digest;

  @override
  void add(Digest event) => digest = event;

  @override
  void close() {}
}

/// Streams a release artifact to the app's temporary directory, hash-verifying
/// the bytes as they land. Nothing leaves the temp area: the installer either
/// consumes the verified file or it is removed.
class ReleaseDownloader {
  ReleaseDownloader({required http.Client client}) : _client = client;

  final http.Client _client;

  Stream<DownloadEvent> download(ReleaseArtifact artifact) async* {
    final tempDir = await getTemporaryDirectory();
    final updatesDir = Directory(p.join(tempDir.path, 'updates'))
      ..createSync(recursive: true);
    final target = File(p.join(updatesDir.path, artifact.file));

    final request = http.Request('GET', Uri.parse(artifact.downloadUrl));
    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw AppUpdateException(
        'The update download failed (HTTP ${response.statusCode}).',
      );
    }

    final total = response.contentLength;
    final fileSink = target.openWrite();
    final digestCollector = _DigestCollector();
    final hasher = sha256.startChunkedConversion(digestCollector);
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        fileSink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) {
          yield DownloadProgress((received / total).clamp(0.0, 1.0));
        }
      }
      hasher.close();
      await fileSink.flush();
      await fileSink.close();
    } catch (e) {
      // A mid-transfer failure must never leave a truncated file behind for
      // the installer to pick up. Sink may already be closed; ignore failures.
      try { await fileSink.close(); } catch (_) {}
      try { await target.delete(); } catch (_) {}
      throw AppUpdateException('The update download was interrupted.', e);
    }

    final actual = digestCollector.digest?.toString();
    if (actual == null || actual.toLowerCase() != artifact.sha256.toLowerCase()) {
      try { await target.delete(); } catch (_) {}
      throw const AppUpdateException(
        'Downloaded update failed its integrity check — try again later.',
      );
    }

    yield DownloadDone(target.path);
  }
}
