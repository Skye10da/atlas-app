// ignore_for_file: avoid_print
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

Future<String?> fetchChapterText(int code, int n) async {
  final url = 'https://www.mvlempyr.io/chapter/$code-$n';
  try {
    final res = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0',
      'Accept': 'text/html,application/xhtml+xml',
    });
    if (res.statusCode != 200) {
      print(' $code-$n HTTP ${res.statusCode}');
      return null;
    }
    final doc = html_parser.parse(res.body);
    // mvlempyr chapter content is inside .oxy-stock-content-styles or #chapter-content
    var el = doc.querySelector('.oxy-stock-content-styles');
    el ??= doc.querySelector('#chapter-content');
    el ??= doc.querySelector('article');
    if (el == null) {
      print(' $code-$n no content element');
      return null;
    }
    // Preserve block internal line breaks: <br> => \n, </p><p> => \n\n, then strip tags
    String html = el.innerHtml;
    html = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    html = html.replaceAll(RegExp(r'</p>\s*<p[^>]*>', caseSensitive: false), '\n\n');
    // Strip remaining tags
    html = html.replaceAll(RegExp(r'<[^>]+>'), '');
    // Decode HTML entities via parser
    final frag = html_parser.parseFragment(html);
    final text = frag.text ?? html;
    final cleaned = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (cleaned.isNotEmpty) return cleaned;
    // fallback
    final fallback = el.text.trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return fallback.isEmpty ? null : fallback;
  } catch (e) {
    print(' $code-$n error $e');
    return null;
  }
}

Future<void> main(List<String> args) async {
  final codes = [12132, 12697];
  int total = 0, ok = 0;
  for (final code in codes) {
    for (int n = 10; n <= 30; n++) {
      final existing = File('eval/golden/$code/raw/ch$n.txt');
      if (existing.existsSync() && existing.lengthSync() > 100) {
        print('skip existing $code-$n');
        continue;
      }
      total++;
      String? text;
      for (int retry = 0; retry < 3; retry++) {
        text = await fetchChapterText(code, n);
        if (text != null) break;
        print(' retry $code-$n attempt ${retry+1}');
        await Future.delayed(const Duration(seconds: 2));
      }
      if (text == null || text.trim().isEmpty) {
        print('skip $code-$n empty');
        continue;
      }
      final dir = Directory('eval/golden/$code/raw');
      dir.createSync(recursive: true);
      final file = File('${dir.path}/ch$n.txt');
      file.writeAsStringSync(text);
      print('wrote $code-$n ${text.length} chars -> ${file.path}');
      ok++;
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }
  print('done $ok/$total');
}
