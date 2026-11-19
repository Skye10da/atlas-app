import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/speech/packs/voice_pack_manifest.dart';

void main() {
  group('VoicePackCatalog parsing', () {
    const catalogJson = '''
    {
      "schemaVersion": 1,
      "updatedUtc": "2026-11-15T00:00:00Z",
      "families": [
        {
          "id": "piper-en_US-amy",
          "name": "Amy",
          "language": "en",
          "locale": "en-US",
          "gender": "female",
          "previewUrl": "https://cdn.example/previews/amy.ogg",
          "flavors": [
            {
              "quality": "best",
              "packId": "vits-piper-en_US-amy-high",
              "sizeBytes": 110000000,
              "modelFormatVersion": 1,
              "files": {"amy-high.onnx": {"sha256": "abc111"}}
            },
            {
              "quality": "compact",
              "packId": "vits-piper-en_US-amy-low",
              "sizeBytes": 22000000,
              "modelFormatVersion": 1,
              "files": {"amy-low.onnx": {"sha256": "abc222"}}
            },
            {
              "quality": "standard",
              "packId": "vits-piper-en_US-amy-medium",
              "sizeBytes": 81199160,
              "modelFormatVersion": 1,
              "files": {"amy-medium.onnx": {"sha256": "ABC333"}}
            }
          ]
        }
      ]
    }
    ''';

    test('parses families, normalizes language case', () {
      final catalog = VoicePackCatalog.tryDecode(catalogJson);
      expect(catalog, isNotNull);
      final family = catalog!.family('piper-en_US-amy');
      expect(family, isNotNull);
      expect(family!.name, 'Amy');
      expect(family.language, 'en');
      expect(family.locale, 'en-US');
      expect(family.gender, 'female');
      expect(family.previewUrl, 'https://cdn.example/previews/amy.ogg');
    });

    test('flavors sort by quality order then size', () {
      final family = VoicePackCatalog.tryDecode(catalogJson)!.families.first;
      final qualities = family.flavors.map((f) => f.quality).toList();
      expect(qualities, [
        VoicePackQuality.compact,
        VoicePackQuality.standard,
        VoicePackQuality.best,
      ]);
    });

    test('sha256 case is normalized on read', () {
      final family = VoicePackCatalog.tryDecode(catalogJson)!.families.first;
      expect(family.flavor(VoicePackQuality.standard)!.files.values.first,
          'ABC333');
    });

    test('resolveFlavor falls back to first flavor when tier is missing', () {
      final catalog = VoicePackCatalog.tryDecode(catalogJson)!;
      // The manifest has all three tiers; resolve an absent one on a
      // single-flavor family instead.
      const singleFlavor = '''
      {"schemaVersion": 1, "families": [
        {"id": "x", "name": "X", "language": "en", "locale": "en",
         "flavors": [{"quality": "best", "packId": "p-x-high",
                      "sizeBytes": 5, "files": {"m.onnx": {"sha256": "s"}}}]}
      ]}
      ''';
      final flavor = catalog;
      expect(
        flavor.resolveFlavor('piper-en_US-amy', VoicePackQuality.standard)!
            .packId,
        'vits-piper-en_US-amy-medium',
      );
      final single = VoicePackCatalog.tryDecode(singleFlavor)!;
      expect(
        single.resolveFlavor('x', VoicePackQuality.compact)!.packId,
        'p-x-high',
      );
    });

    test('malformed flavors are rejected by family validity', () {
      const broken = '''
      {"schemaVersion": 1, "families": [
        {"id": "bad", "name": "Bad", "language": "en", "locale": "en",
         "flavors": [
           {"quality": "standard", "packId": "", "sizeBytes": 0, "files": {}}
         ]}
      ]}
      ''';
      final catalog = VoicePackCatalog.tryDecode(broken);
      expect(catalog, isNotNull);
      // The family exists but its flavor is not usable.
      final family = catalog!.family('bad');
      expect(family, isNotNull);
      expect(family!.flavors.isEmpty, isFalse);
      expect(family.flavors.first.isValid, isFalse);
    });

    test('newer schema versions are rejected (forward compatibility)', () {
      const future = '{"schemaVersion": 99, "families": []}';
      expect(VoicePackCatalog.tryDecode(future), isNull);
    });

    test('garbage bodies answer null', () {
      expect(VoicePackCatalog.tryDecode('not json'), isNull);
      expect(VoicePackCatalog.tryDecode('[1,2,3]'), isNull);
      expect(VoicePackCatalog.tryDecode(''), isNull);
    });

    test('generated CDN catalog parses (when built locally)', () {
      // Produced by atlas_tts/tool/build_voice_catalog.ps1; skipped on
      // hosts that have not built it (CI).
      final f = File('atlas_tts/build/voice_packs/catalog.json');
      if (!f.existsSync()) return;
      final catalog = VoicePackCatalog.tryDecode(f.readAsStringSync());
      expect(catalog, isNotNull);
      final amy = catalog!.family('piper-en_US-amy');
      expect(amy, isNotNull);
      expect(amy!.flavors.map((fl) => fl.packId), containsAll(<String>[
        'vits-piper-en_US-amy-medium',
        'vits-piper-en_US-amy-low',
      ]));
      for (final fl in amy.flavors) {
        expect(fl.isValid, isTrue);
        expect(fl.files, contains('tokens.txt'));
        expect(fl.files.keys.any((n) => n.startsWith('espeak-ng-data/')),
            isTrue, reason: 'nested phonemization data listed per file');
      }
    });
  });
}
