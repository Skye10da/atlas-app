#!/usr/bin/env dart
// ignore_for_file: avoid_print
// Heuristic bootstrap for 10x20 evaluation — no model.
// Generates .pred.json via processSync + CharacterExtractor.extract
// Usage: dart run tool/eval_bootstrap.dart --novel 12132 --range 10-30
// Or: dart run tool/eval_bootstrap.dart --all
import 'dart:convert';
import 'dart:io';

import 'package:atlas_app/core/content_engine/block_card/block_card_detector.dart';
import 'package:atlas_app/intelligence/application/extraction/character_extractor.dart';

Future<void> main(List<String> args) async {
  final all = args.contains('--all');
  final novelArg = args.contains('--novel') ? args[args.indexOf('--novel') + 1] : null;
  final rangeArg = args.contains('--range') ? args[args.indexOf('--range') + 1] : '10-30';

  final range = _parseRange(rangeArg);
  final novels = all ? _novelsFromConfig() : (novelArg != null ? [novelArg] : ['12132', '12697']);

  // In plan mode this script is not executed; in build it fetches via HttpTransport.
  // For now, if eval/golden already contains rawText fixtures, we bootstrap from those.
  // Otherwise, warn and exit — scraper spider should populate first.
  print('eval_bootstrap: novels=$novels range=$rangeArg');
  print('Note: requires raw chapter text. If eval/golden/<id>/raw/*.txt missing, run scraper spider first.');
  print('Scraper: python -m scrapling.spiders or dart run tool/mvlempyr_bulk.dart (TBD)');

  // Placeholder bootstrap from existing fixtures (demonstrates metrics wiring without network)
  for (final novelId in novels) {
    final rawDir = Directory('eval/golden/$novelId/raw');
    if (!rawDir.existsSync()) {
      print('Skip $novelId — no raw dir ${rawDir.path}');
      continue;
    }
    final files = rawDir.listSync().whereType<File>().toList()..sort((a,b)=>a.path.compareTo(b.path));
    var processed = 0;
    for (final f in files) {
      final m = RegExp(r'ch(\d+)\.txt').firstMatch(f.path);
      final chNum = m != null ? int.parse(m.group(1)!) : -1;
      if (chNum < range.start || chNum > range.end) { continue; }
      final text = await f.readAsString();
      final detector = BlockCardDetector();
      final spans = await detector.process(text);
      final extractor = CharacterExtractor();
      final chars = extractor.extract(text);
      final pred = {
        'novelId': novelId,
        'chapterIndex': chNum,
        'rawTextLength': text.length,
        'blockCards': spans.where((s)=>s.isCard).map((s)=> {
          'type': s.card!.type.name,
          'confidence': s.card!.confidence,
          'isLow': s.card!.isLowConfidence,
          'title': s.card!.title,
          'fields': s.card!.fields.map((x)=> {'label':x.label,'value':x.value,'display':x.display.name}).toList(),
          'rawText': s.card!.rawText.substring(0, s.card!.rawText.length.clamp(0, 200)),
        }).toList(),
        'characters': chars.map((c)=> {
          'name': c.name,
          'signals': c.signals.map((e)=>e.name).toList(),
          'occurrenceCount': c.occurrenceCount,
          'evidence': c.evidence,
        }).toList(),
      };
      final outDir = Directory('eval/runs/bootstrap/pred/$novelId');
      outDir.createSync(recursive: true);
      final out = File('${outDir.path}/ch$chNum.pred.json');
      out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(pred));
      print('Wrote ${out.path}');
      processed++;
    }
    if (processed == 0) print('No files in range $range for $novelId');
  }
}

({int start, int end}) _parseRange(String s) {
  final parts = s.split('-').map(int.parse).toList();
  return (start: parts[0], end: parts[1]);
}

List<String> _novelsFromConfig() {
  final cfg = File('eval/config.yaml');
  if (!cfg.existsSync()) return ['12132','12697'];
  final txt = cfg.readAsStringSync();
  final ids = RegExp(r'novelId:\s*"([^"]+)"').allMatches(txt).map((m)=>m.group(1)!).where((id)=> id != 'wdqk' && !id.contains('TBD')).toList();
  return ids.isEmpty ? ['12132','12697'] : ids;
}
