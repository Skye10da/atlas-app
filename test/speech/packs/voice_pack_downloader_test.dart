import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_downloader.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_manifest.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_store.dart';

void main() {
  late Directory sandbox;
  late String documentsRoot;
  late AppDatabase db;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('atlas_packs_test');
    documentsRoot = '${sandbox.path}/docs';
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
    try {
      sandbox.deleteSync(recursive: true);
    } catch (_) {}
  });

  VoicePackFlavor flavor({
    String packId = 'vits-piper-en_US-amy-low',
    String familyId = 'piper-en_US-amy',
    Map<String, String>? files,
    int sizeBytes = 0,
  }) {
    final effective = files ??
        {
          'model.onnx': sha256.convert(utf8.encode('model-bytes')).toString(),
          'tokens.txt': sha256.convert(utf8.encode('tokens')).toString(),
        };
    return VoicePackFlavor(
      quality: VoicePackQuality.compact,
      packId: packId,
      sizeBytes: sizeBytes == 0
          ? utf8.encode('model-bytes').length + utf8.encode('tokens').length
          : sizeBytes,
      files: effective,
      modelFormatVersion: 1,
    );
  }

  http.Client clientServing(Map<String, Uint8List> responses) =>
      MockClient.streaming((request, bodyStream) async {
        final path = request.url.toString();
        final body = responses[path];
        if (body == null) {
          return http.StreamedResponse(
            Stream.value(utf8.encode('missing')),
            404,
          );
        }
        return http.StreamedResponse(Stream.value(body), 200);
      });

  VoicePackDownloader makeDownloader({http.Client? client}) {
    return VoicePackDownloader(
      store: VoicePackStore(database: db),
      documentsRoot: documentsRoot,
      location: const VoicePackLocation(
        baseUrl: 'https://cdn.test/atlas_tts/voices',
      ),
      client: client,
    );
  }

  test('happy path: downloads every file, verifies sha, activates atomically',
      () async {
    final downloader = makeDownloader(
      client: clientServing({
        'https://cdn.test/atlas_tts/voices/piper-en_US-amy/vits-piper-en_US-amy-low/model.onnx':
            Uint8List.fromList(utf8.encode('model-bytes')),
        'https://cdn.test/atlas_tts/voices/piper-en_US-amy/vits-piper-en_US-amy-low/tokens.txt':
            Uint8List.fromList(utf8.encode('tokens')),
      }),
    );
    final store = VoicePackStore(database: db);

    final result = await downloader.download(
      flavor(),
      familyId: 'piper-en_US-amy',
    );
    expect(result, VoicePackDownloadResult.ready);

    final record = await store.get(flavor().packId);
    expect(record!.state, VoicePackState.ready);
    expect(record.progress, 1.0);

    // Activated under the driver-discoverable directory.
    final dir = Directory(store.packDirectory(documentsRoot, flavor().packId));
    expect(dir.existsSync(), isTrue);
    expect(File('${dir.path}/model.onnx').readAsStringSync(), 'model-bytes');
    expect(File('${dir.path}/tokens.txt').readAsStringSync(), 'tokens');
    expect(store.installedPackIds(documentsRoot), contains(flavor().packId));

    // Scratch directory is gone.
    expect(
      Directory(store.tmpDirectory(documentsRoot, flavor().packId)).existsSync(),
      isFalse,
    );
    await downloader.dispose();
  });

  test('sha mismatch marks corrupt and cleans the scratch dir', () async {
    final downloader = makeDownloader(
      client: clientServing({
        'https://cdn.test/atlas_tts/voices/piper-en_US-amy/vits-piper-en_US-amy-low/model.onnx':
            Uint8List.fromList(utf8.encode('tampered-bytes')),
        'https://cdn.test/atlas_tts/voices/piper-en_US-amy/vits-piper-en_US-amy-low/tokens.txt':
            Uint8List.fromList(utf8.encode('tokens')),
      }),
    );
    final store = VoicePackStore(database: db);

    final result = await downloader.download(
      flavor(),
      familyId: 'piper-en_US-amy',
    );
    expect(result, VoicePackDownloadResult.failed);

    final record = await store.get(flavor().packId);
    expect(record!.state, VoicePackState.corrupt);
    expect(record.error, 'sha256 mismatch');
    expect(
      Directory(store.tmpDirectory(documentsRoot, flavor().packId)).existsSync(),
      isFalse,
    );
    expect(store.installedPackIds(documentsRoot), isNot(contains(flavor().packId)));
    await downloader.dispose();
  });

  test('HTTP failure (404) marks corrupt, not ready', () async {
    final downloader = makeDownloader(client: clientServing({}));
    final store = VoicePackStore(database: db);

    final result = await downloader.download(
      flavor(),
      familyId: 'piper-en_US-amy',
    );
    expect(result, VoicePackDownloadResult.failed);
    expect((await store.get(flavor().packId))!.state, VoicePackState.corrupt);
    await downloader.dispose();
  });

  test('malformed flavor (empty files) fails fast without touching disk',
      () async {
    final downloader = makeDownloader(client: clientServing({}));
    final store = VoicePackStore(database: db);

    final result = await downloader.download(
      flavor(files: {}),
      familyId: 'piper-en_US-amy',
    );
    expect(result, VoicePackDownloadResult.failed);
    expect((await store.get(flavor().packId))!.state, VoicePackState.corrupt);
    expect(store.installedPackIds(documentsRoot), isEmpty);
    await downloader.dispose();
  });

  test('cancel between chunks: no install, no record, scratch removed',
      () async {
    // A never-ending stream exercises the cancellation check between chunks.
    final controller = StreamController<List<int>>();
    final downloader = makeDownloader(
      client: MockClient.streaming((request, _) async {
        return http.StreamedResponse(controller.stream, 200);
      }),
    );
    final store = VoicePackStore(database: db);

    final downloadFuture = downloader.download(
      flavor(files: {'model.onnx': sha256.convert(utf8.encode('x')).toString()}),
      familyId: 'piper-en_US-amy',
    );
    // Let the first chunk flow, then cancel.
    controller.add(utf8.encode('partial'));
    await pumpEventQueue();
    downloader.cancel(flavor().packId);
    await controller.close();

    final result = await downloadFuture;
    expect(result, VoicePackDownloadResult.cancelled);
    expect((await store.get(flavor().packId)), isNull);
    expect(
      Directory(store.tmpDirectory(documentsRoot, flavor().packId)).existsSync(),
      isFalse,
    );
    await downloader.dispose();
  });

  test('concurrent downloads for one pack join in flight', () async {
    final downloader = makeDownloader(
      client: clientServing({
        'https://cdn.test/atlas_tts/voices/piper-en_US-amy/vits-piper-en_US-amy-low/model.onnx':
            Uint8List.fromList(utf8.encode('model-bytes')),
        'https://cdn.test/atlas_tts/voices/piper-en_US-amy/vits-piper-en_US-amy-low/tokens.txt':
            Uint8List.fromList(utf8.encode('tokens')),
      }),
    );
    final results = await Future.wait([
      downloader.download(flavor(), familyId: 'piper-en_US-amy'),
      downloader.download(flavor(), familyId: 'piper-en_US-amy'),
    ]);
    expect(results.first, VoicePackDownloadResult.ready);
    expect(results.last, VoicePackDownloadResult.ready);
    expect(downloader.activePackIds, isEmpty);
    await downloader.dispose();
  });

  test('recoverStaleState: interrupted rows become corrupt; tmp dirs die',
      () async {
    final store = VoicePackStore(database: db);
    // Simulate a crash mid-download: a downloading row + a leftover tmp dir.
    await store.upsert(
      VoicePackRecord(
        packId: 'stale-pack',
        familyId: 'f',
        quality: VoicePackQuality.compact,
        state: VoicePackState.downloading,
        bytes: 10,
        totalBytes: 100,
        updatedAt: DateTime.now(),
      ),
    );
    final tmp = Directory(store.tmpDirectory(documentsRoot, 'stale-pack'));
    tmp.createSync(recursive: true);
    File('${tmp.path}/partial.onnx').writeAsStringSync('partial');

    final downloader = makeDownloader();
    await downloader.recoverStaleState();

    expect((await store.get('stale-pack'))!.state, VoicePackState.corrupt);
    expect(tmp.existsSync(), isFalse);
    await downloader.dispose();
  });

  test('nested catalog keys (espeak-ng-data) land in subdirectories', () async {
    final nestedBytes = utf8.encode('espeak-lang-data');
    const nestedKey = 'espeak-ng-data/lang/en.dict';
    final downloader = makeDownloader(
      client: clientServing({
        'https://cdn.test/atlas_tts/voices/piper-en_US-amy/vits-piper-en_US-amy-low/model.onnx':
            Uint8List.fromList(utf8.encode('model-bytes')),
        'https://cdn.test/atlas_tts/voices/piper-en_US-amy/vits-piper-en_US-amy-low/$nestedKey':
            Uint8List.fromList(nestedBytes),
      }),
    );
    final store = VoicePackStore(database: db);

    final result = await downloader.download(
      flavor(
        files: {
          'model.onnx': sha256.convert(utf8.encode('model-bytes')).toString(),
          nestedKey: sha256.convert(nestedBytes).toString(),
        },
      ),
      familyId: 'piper-en_US-amy',
    );
    expect(result, VoicePackDownloadResult.ready);

    final dir = Directory(store.packDirectory(documentsRoot, flavor().packId));
    expect(
      File('${dir.path}/$nestedKey').readAsStringSync(),
      'espeak-lang-data',
      reason: 'the downloader must create intermediate directories',
    );
    await downloader.dispose();
  });

  test('progress events stream cumulative bytes while downloading',
      () async {
    final modelBytes = utf8.encode('model-bytes');
    final downloader = makeDownloader(
      client: MockClient.streaming((request, _) async {
        // Two chunks for the model file to exercise accumulation.
        final half = modelBytes.sublist(0, 5);
        final rest = modelBytes.sublist(5);
        return http.StreamedResponse(
          Stream.fromIterable([half, rest]),
          200,
        );
      }),
    );
    final flavor0 = flavor(files: {
      'model.onnx': sha256.convert(modelBytes).toString(),
    }, sizeBytes: 11);
    final progress = <VoicePackProgress>[];
    downloader.progressStream.listen(progress.add);

    final result = await downloader.download(
      flavor0,
      familyId: 'piper-en_US-amy',
    );
    expect(result, VoicePackDownloadResult.ready);
    expect(progress, isNotEmpty);
    expect(progress.last.bytes, 11);
    await downloader.dispose();
  });
}


