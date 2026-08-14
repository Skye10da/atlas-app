import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/image/image_pipeline.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

class _FakeTransport implements Transport {
  _FakeTransport({Map<String, List<int>>? bytes, this.onBytes})
      : bytes = {...?bytes};

  final Map<String, List<int>> bytes;
  final void Function(Uri url, Map<String, String>? headers)? onBytes;
  int byteCalls = 0;

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) async =>
      throw UnimplementedError();

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async =>
      throw UnimplementedError();

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) async {
    byteCalls++;
    onBytes?.call(url, headers);
    final value = bytes[url.toString()];
    if (value == null) throw TransportException('missing $url');
    return value;
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('image_pipeline_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('ImagePipeline', () {
    test('downloads bytes and stores them content-addressed', () async {
      final bytes = List<int>.generate(16, (i) => i);
      final transport = _FakeTransport(bytes: {'https://example.com/a.png': bytes});
      final pipeline = ImagePipeline(transport: transport, basePath: tempDir.path);

      final path = await pipeline.download(Uri.parse('https://example.com/a.png'));

      expect(path, isNotNull);
      final file = File(path!);
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), bytes);
    });

    test('infers extension from the URL', () async {
      final transport = _FakeTransport(
        bytes: {'https://example.com/c.jpg': [1, 2]},
      );
      final pipeline = ImagePipeline(transport: transport, basePath: tempDir.path);

      final path = await pipeline.download(Uri.parse('https://example.com/c.jpg'));

      expect(path, endsWith('.jpg'));
    });

    test('dedupes identical content to a single file', () async {
      final shared = [1, 2, 3];
      final transport = _FakeTransport(bytes: {
        'https://example.com/a.png': shared,
        'https://cdn.example.com/b.png': shared,
      });
      final pipeline = ImagePipeline(transport: transport, basePath: tempDir.path);

      final first = await pipeline.download(Uri.parse('https://example.com/a.png'));
      final second = await pipeline.download(Uri.parse('https://cdn.example.com/b.png'));

      expect(first, second);
      final files = Directory(tempDir.path)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .toList();
      expect(files, hasLength(1));
    });

    test('skips the network fetch when the content hash already exists',
        () async {
      final bytes = [9, 8, 7];
      final transport = _FakeTransport(bytes: {'https://example.com/a.png': bytes});
      final pipeline = ImagePipeline(transport: transport, basePath: tempDir.path);

      final first = await pipeline.download(Uri.parse('https://example.com/a.png'));
      expect(transport.byteCalls, 1);

      final second = await pipeline.download(Uri.parse('https://example.com/a.png'));
      expect(transport.byteCalls, 1);
      expect(first, second);
    });

    test('forwards custom headers to the transport', () async {
      Map<String, String>? seen;
      final transport = _FakeTransport(
        bytes: {'https://example.com/a.png': [1]},
        onBytes: (url, headers) => seen = headers,
      );
      final pipeline = ImagePipeline(transport: transport, basePath: tempDir.path);

      await pipeline.download(
        Uri.parse('https://example.com/a.png'),
        headers: {'Referer': 'https://example.com'},
      );

      expect(seen, {'Referer': 'https://example.com'});
    });

    test('returns null on empty response', () async {
      final transport = _FakeTransport(bytes: {'https://example.com/e.png': []});
      final pipeline = ImagePipeline(transport: transport, basePath: tempDir.path);

      final path = await pipeline.download(Uri.parse('https://example.com/e.png'));

      expect(path, isNull);
    });
  });
}
