import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/speech/packs/voice_pack_manifest.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_providers.dart';
import 'package:atlas_app/reader/speech/packs/voice_pack_store.dart';
import 'package:atlas_app/reader/speech/speech_models.dart';

VoicePackRecord record(
  String packId,
  String familyId,
  VoicePackQuality quality,
  VoicePackState state,
) => VoicePackRecord(
  packId: packId,
  familyId: familyId,
  quality: quality,
  state: state,
  bytes: 1,
  totalBytes: 1,
  updatedAt: DateTime.now(),
);

void main() {
  const catalog = '''
  {"schemaVersion": 1, "families": [
    {"id": "piper-en_US-amy", "name": "Amy", "language": "en",
     "locale": "en-US", "previewUrl": "https://cdn/amy.ogg",
     "flavors": [
       {"quality": "compact", "packId": "p-amy-low", "sizeBytes": 10,
        "files": {"m.onnx": {"sha256": "s"}}},
       {"quality": "standard", "packId": "p-amy-med", "sizeBytes": 20,
        "files": {"m.onnx": {"sha256": "s"}}}
     ]},
    {"id": "piper-de_karla", "name": "Karla", "language": "de",
     "locale": "de-DE",
     "flavors": [
       {"quality": "standard", "packId": "p-karla-med", "sizeBytes": 30,
        "files": {"m.onnx": {"sha256": "s"}}}
     ]}
  ]}
  ''';

  final catalogParsed = VoicePackCatalog.tryDecode(catalog)!;

  test('families come first, platform voices after', () {
    final entries = buildVoiceGallery(
      catalog: catalogParsed,
      records: const [],
      platformVoices: const [
        VoiceDescriptor(id: 'platform-voice-1', language: 'en', locale: 'en-US'),
      ],
    );
    expect(entries, hasLength(3));
    expect(entries[0], isA<PackVoiceEntry>());
    expect((entries[0] as PackVoiceEntry).family.name, 'Amy');
    expect(entries[2], isA<PlatformVoiceEntry>());
    expect((entries[2] as PlatformVoiceEntry).voice.id, 'platform-voice-1');
  });

  test('a ready record exposes the pack id as the installed voice', () {
    final entries = buildVoiceGallery(
      catalog: catalogParsed,
      records: [record('p-amy-med', 'piper-en_US-amy', VoicePackQuality.standard, VoicePackState.ready)],
      platformVoices: const [],
    );
    final amy = entries.first as PackVoiceEntry;
    expect(amy.installedPackIds, {'p-amy-med'});
    final karla = entries[1] as PackVoiceEntry;
    expect(karla.installedPackIds, isEmpty);
  });

  test('multiple installed flavors all surface as usable voices', () {
    final entries = buildVoiceGallery(
      catalog: catalogParsed,
      records: [
        record('p-amy-low', 'piper-en_US-amy', VoicePackQuality.compact, VoicePackState.ready),
        record('p-amy-med', 'piper-en_US-amy', VoicePackQuality.standard, VoicePackState.ready),
      ],
      platformVoices: const [],
    );
    final amy = entries.first as PackVoiceEntry;
    expect(amy.installedPackIds, {'p-amy-low', 'p-amy-med'});
    expect(amy.readyRecord(VoicePackQuality.compact)!.packId, 'p-amy-low');
    expect(amy.readyRecord(VoicePackQuality.standard)!.packId, 'p-amy-med');
  });

  test('mid-download records do not count as installed', () {
    final entries = buildVoiceGallery(
      catalog: catalogParsed,
      records: [
        record('p-amy-low', 'piper-en_US-amy', VoicePackQuality.compact, VoicePackState.downloading),
      ],
      platformVoices: const [],
    );
    expect((entries.first as PackVoiceEntry).installedPackIds, isEmpty);
  });

  test('null catalog yields platform voices only', () {
    final entries = buildVoiceGallery(
      catalog: null,
      records: const [],
      platformVoices: const [
        VoiceDescriptor(id: 'v', language: 'en', locale: 'en-US'),
      ],
    );
    expect(entries, hasLength(1));
    expect(entries.single, isA<PlatformVoiceEntry>());
  });

  test('corrupt + ready records coexist; ready wins the install slot', () {
    final entries = buildVoiceGallery(
      catalog: catalogParsed,
      records: [
        record('p-amy-low', 'piper-en_US-amy', VoicePackQuality.compact, VoicePackState.corrupt),
        record('p-amy-med', 'piper-en_US-amy', VoicePackQuality.standard, VoicePackState.ready),
      ],
      platformVoices: const [],
    );
    expect((entries.first as PackVoiceEntry).installedPackIds, {'p-amy-med'});
    expect((entries.first as PackVoiceEntry).records, hasLength(2));
  });
}
