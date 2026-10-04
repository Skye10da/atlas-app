// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() {
  final runDir = Directory('eval/runs/bootstrap/pred');
  if (!runDir.existsSync()) {
    print('no pred dir ${runDir.path}');
    return;
  }
  print('=== BlockCard + Character Extractor Strength/Weakness (10-20 controls) ===\n');
  for (final novelDir in runDir.listSync().whereType<Directory>()) {
    final novelId = novelDir.path.split(Platform.pathSeparator).last;
    final files = novelDir.listSync().whereType<File>().where((f)=>f.path.endsWith('.pred.json')).toList()..sort((a,b)=>a.path.compareTo(b.path));
    final int totalCh = files.length;
    int totalCards = 0, fallback = 0, footballScout = 0, footballTalent = 0, system = 0, cultivation = 0, other = 0;
    int totalChars = 0;
    final charNames = <String>{};
    final typeCounts = <String,int>{};
    for (final f in files) {
      final json = jsonDecode(f.readAsStringSync()) as Map<String,dynamic>;
      final cards = (json['blockCards'] as List).cast<Map<String,dynamic>>();
      totalCards += cards.length;
      for (final c in cards) {
        final t = c['type'] as String;
        typeCounts[t] = (typeCounts[t]??0)+1;
        if (c['isLow'] == true) fallback++;
        switch (t) {
          case 'footballScout': footballScout++; break;
          case 'footballTalent': footballTalent++; break;
          case 'system': system++; break;
          case 'cultivation': cultivation++; break;
          default: other++; break;
        }
      }
      final chars = (json['characters'] as List).cast<Map<String,dynamic>>();
      totalChars += chars.length;
      for (final ch in chars) {
        charNames.add(ch['name'] as String);
      }
    }
    print('Novel $novelId: $totalCh chapters');
    print('  BlockCards: $totalCards total, fallback $fallback (${totalCards>0?(fallback/totalCards*100).toStringAsFixed(1):0}%)');
    print('    types: $typeCounts');
    print('    footballScout $footballScout / footballTalent $footballTalent / system $system / cultivation $cultivation / other $other');
    print('  Characters: $totalChars mentions, unique ${charNames.length}, sample: ${charNames.take(5).join(', ')}');
    print('');
  }
  print('--- Upgrade hypotheses ---');
  print('H1 Panel parser (footballScout CA/PA 0-200 bar, Talent grades U/L) already in place — expect Scout 28/200→PA 35/200 and Possessed Talents (B) to be captured after previous fix.');
  print('H2 Alias: Kevin "Kev" Jones vs Kev — check if charNames contains both separately (duplicate).');
  print('H3 Korean hyphen: Ho-young vs Hoyoung — check charNames for split.');
}
