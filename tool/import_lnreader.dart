// tool/import_lnreader.dart
//
// Converts LNReader "multisrc" site entries into Atlas declarative plugins.
// Standard library only (dart:io, dart:convert). Fails closed: any site using
// an option this script does not understand is skipped and reported, never
// guessed at.
//
// Usage:
//   dart run tool/import_lnreader.dart \
//     --lnreader <path-to-lnreader-plugins-checkout> \
//     --native atlas-plugins \
//     --out atlas-plugins \
//     --base-selectors atlas-plugins/allnovelfull/selectors.json \
//     --report import-report.json \
//     [--families madara,readnovelfull] [--dry-run]
//
// Plugins are emitted into <out>/<pluginId>/ and default to the distribution
// root (atlas-plugins/), which is the directory that pairs with atlas-plugins/
// index.json (catalog, sha256-verified) and registry.json (generated), and that
// passes tool/plugin_validator.dart. Community imports use the `lnr-` id prefix
// and are skipped past native plugins that already serve the same host.
//
// Output is NOT ready to ship: fixtures (tests/) must be recorded and
// plugin_validator.dart must pass before anything is added to index.json.
// Upstream: https://github.com/LNReader/lnreader-plugins (MIT).

import 'dart:convert';
import 'dart:io';

const _upstream = 'https://github.com/LNReader/lnreader-plugins';
const _upstreamLicense =
    'MIT License, Copyright (c) 2021 Rajarshee Chatterjee';

const _defaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

const _langCodes = <String, String>{
  'English': 'en',
  'Turkish': 'tr',
  'Arabic': 'ar',
  'Indonesian': 'id',
  'Spanish': 'es',
  'Portuguese': 'pt',
  'Thai': 'th',
  'French': 'fr',
  'Korean': 'ko',
  'Russian': 'ru',
  'Polish': 'pl',
  'Vietnamese': 'vi',
  'Chinese': 'zh',
  'Japanese': 'ja',
  'Ukrainian': 'uk',
  'Bangla': 'bn',
  'German': 'de',
  'Italian': 'it',
};

/// Options each family handler understands. Anything else => skip.
/// `down` is handled before this check.
const _supportedOptions = <String, Set<String>>{
  'madara': {'useNewChapterEndpoint', 'lang', 'versionIncrements'},
  'readnovelfull': {
    'searchPage',
    'searchKey',
    'chapterListing',
    'pageParam',
    'latestPage', // ignored: Atlas has no "latest" capability yet
    'versionIncrements', // ignored: Atlas versions by output hash
    'lang',
  },
};

const _flags = {'dry-run'};

final _idPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');

class _Skip {
  _Skip(this.family, this.id, this.reason);
  final String family;
  final String id;
  final String reason;
  Map<String, dynamic> toJson() =>
      {'family': family, 'id': id, 'reason': reason};
}

class _Plan {
  _Plan(this.id, this.family, this.files);
  final String id;
  final String family;
  final Map<String, String> files;
}

String _encode(Object o) => '${const JsonEncoder.withIndent('  ').convert(o)}\n';

void main(List<String> args) {
  final Map<String, String> opts;
  try {
    opts = _parseArgs(args);
  } on FormatException catch (e) {
    stderr.writeln('error: ${e.message}');
    exitCode = 1;
    return;
  }

  final lnreader = opts['lnreader'];
  if (lnreader == null) {
    stderr.writeln('error: --lnreader <path to lnreader-plugins checkout> is required');
    exitCode = 1;
    return;
  }
  final outDir = Directory(opts['out'] ?? 'atlas-plugins');
  final nativeDir = Directory(opts['native'] ?? 'atlas-plugins');
  final dryRun = opts['dry-run'] == 'true';
  final families =
      (opts['families'] ?? 'madara,readnovelfull').split(',').map((s) => s.trim()).toList();

  for (final f in families) {
    if (!_supportedOptions.containsKey(f)) {
      stderr.writeln('error: unsupported family "$f" '
          '(supported: ${_supportedOptions.keys.join(', ')})');
      exitCode = 1;
      return;
    }
  }

  Map<String, dynamic>? baseSelectors;
  final basePath = opts['base-selectors'];
  if (basePath != null) {
    final f = File(basePath);
    if (!f.existsSync()) {
      stderr.writeln('error: --base-selectors file not found: $basePath');
      exitCode = 1;
      return;
    }
    baseSelectors = (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>();
  }

  final commit = _gitHead(lnreader);
  final nativeHosts = _nativeHosts(nativeDir);
  final seenHosts = <String>{};
  final plans = <_Plan>[];
  final skips = <_Skip>[];

  for (final family in families) {
    final file = File('$lnreader/plugins/multisrc/$family/sources.json');
    if (!file.existsSync()) {
      stderr.writeln('error: missing ${file.path}');
      exitCode = 1;
      return;
    }
    final entries = jsonDecode(file.readAsStringSync()) as List;
    for (final raw in entries) {
      _convert(
        family: family,
        entry: (raw as Map).cast<String, dynamic>(),
        baseSelectors: baseSelectors,
        nativeHosts: nativeHosts,
        seenHosts: seenHosts,
        commit: commit,
        plans: plans,
        skips: skips,
      );
    }
  }

  final status = <String, int>{'new': 0, 'updated': 0, 'unchanged': 0};
  final written = <Map<String, dynamic>>[];
  for (final plan in plans) {
    final s = _write(outDir, plan, dryRun);
    status[s] = (status[s] ?? 0) + 1;
    written.add({'id': plan.id, 'family': plan.family, 'status': s});
  }

  final skipCounts = <String, int>{};
  for (final s in skips) {
    final category = s.reason.split(':').first;
    skipCounts[category] = (skipCounts[category] ?? 0) + 1;
  }

  final report = {
    'upstream': _upstream,
    'upstreamCommit': commit,
    'dryRun': dryRun,
    'imported': written,
    'skipped': skips.map((s) => s.toJson()).toList(),
  };
  final reportPath = opts['report'];
  if (reportPath != null) File(reportPath).writeAsStringSync(_encode(report));

  stdout.writeln('${dryRun ? '[dry run] ' : ''}upstream $commit');
  stdout.writeln('imported ${plans.length}: $status');
  stdout.writeln('skipped ${skips.length}: $skipCounts');
  if (reportPath != null) stdout.writeln('report: $reportPath');
}

Map<String, String> _parseArgs(List<String> args) {
  final m = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) throw FormatException('unexpected argument: $a');
    final eq = a.indexOf('=');
    if (eq > 0) {
      m[a.substring(2, eq)] = a.substring(eq + 1);
      continue;
    }
    final key = a.substring(2);
    if (_flags.contains(key)) {
      m[key] = 'true';
      continue;
    }
    if (i + 1 >= args.length) throw FormatException('missing value for $a');
    m[key] = args[++i];
  }
  return m;
}

String _gitHead(String repo) {
  try {
    final r = Process.runSync('git', ['-C', repo, 'rev-parse', 'HEAD']);
    if (r.exitCode == 0) return (r.stdout as String).trim();
  } on ProcessException {
    // git not available
  }
  return 'unknown';
}

Set<String> _nativeHosts(Directory dir) {
  final hosts = <String>{};
  if (!dir.existsSync()) return hosts;
  for (final e in dir.listSync()) {
    if (e is! Directory) continue;
    final f = File('${e.path}/plugin.json');
    if (!f.existsSync()) continue;
    final j = jsonDecode(f.readAsStringSync());
    if (j is Map && j['baseUrl'] is String) {
      hosts.add(Uri.parse(j['baseUrl'] as String).host.toLowerCase());
    }
  }
  return hosts;
}

void _convert({
  required String family,
  required Map<String, dynamic> entry,
  required Map<String, dynamic>? baseSelectors,
  required Set<String> nativeHosts,
  required Set<String> seenHosts,
  required String commit,
  required List<_Plan> plans,
  required List<_Skip> skips,
}) {
  final rawId = entry['id'];
  void skip(String reason) => skips.add(_Skip(family, '$rawId', reason));

  if (rawId is! String) return skip('invalid: id missing');
  final slug = rawId
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final id = 'lnr-$slug';
  if (!_idPattern.hasMatch(id)) return skip('invalid: unsafe id');

  final name = entry['sourceName'];
  final site = entry['sourceSite'];
  if (name is! String || name.trim().isEmpty || site is! String) {
    return skip('invalid: missing name or site');
  }
  final uri = Uri.tryParse(site);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return skip('invalid: baseUrl must be plain https');
  }
  final host = uri.host.toLowerCase();

  final options = entry['options'];
  final o = options is Map ? options.cast<String, dynamic>() : <String, dynamic>{};

  if (o['down'] == true) return skip('down');
  for (final key in o.keys) {
    if (!_supportedOptions[family]!.contains(key)) {
      return skip('unsupported option: $key');
    }
  }
  if (nativeHosts.contains(host)) return skip('native host: $host');
  if (seenHosts.contains(host)) return skip('duplicate host: $host');

  final langName = o['lang'] ?? 'English';
  final lang = _langCodes[langName];
  if (lang == null) return skip('unknown language: $langName');

  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  final baseUrl = '${uri.scheme}://${uri.authority}$path';

  final files = <String, String>{};
  final manifest = <String, dynamic>{
    'id': id,
    'name': name,
    'sourceName': name,
    'version': '1.0.0',
    'templateId': 'html',
    'transport': 'http',
    'baseUrl': baseUrl,
    'language': lang,
    'customUserAgent': _defaultUserAgent,
    'capabilities': ['search', 'chapterList', 'chapterContent', 'cover'],
  };

  if (family == 'madara') {
    // There is no dedicated Madara template in this codebase; Madara sources
    // are served by the generic `html` template through data-driven ajax
    // selectors — the same flow the native novel-hub plugin uses.
    final newEndpoint = o['useNewChapterEndpoint'] == true;
    final ajaxArchive = <String, Object?>{
      'method': 'POST',
      // Both the legacy (`/wp-admin/admin-ajax.php`) and the new
      // (`<novel>/ajax/chapters`) Madara chapter endpoints dispatch on
      // `action=manga_get_chapters` with the manga id — verified live against
      // sleepytranslations (new endpoint): POST with that form returns the
      // chapter listing; paging rides the `page` query parameter.
      'ajaxBase': newEndpoint ? 'novel' : 'base',
      'form': <String, String>{
        'action': 'manga_get_chapters',
        'manga': '{novelId}',
      },
      'responseField': newEndpoint ? null : 'data.content',
      'novelIdSelector':
          '#manga-chapters-holder@data-id|#madara-chapters-holder@data-id',
    };
    files['selectors.json'] = _encode({
      'chapterList': {
        'item': 'ul.main li.wp-manga-chapter',
        'title': 'a@text',
        'url': 'a@href',
        'ajaxPath': newEndpoint ? '/ajax/chapters' : '/wp-admin/admin-ajax.php',
        'ajaxArchive': ajaxArchive,
        'sortByChapterNumber': true,
      },
    });
  } else {
    if (baseSelectors == null) return skip('config: --base-selectors not provided');
    // Only the layout we can verify against the base selectors.
    if (o['chapterListing'] != 'ajax-chapter-option') {
      return skip('unverified layout: chapterListing=${o['chapterListing']}');
    }
    files['selectors.json'] = _encode(_readNovelFullSelectors(baseSelectors, o));
  }

  manifest['origin'] = {
    'type': 'lnreader-multisrc',
    'family': family,
    'upstreamId': rawId,
    'upstreamCommit': commit,
  };

  files['plugin.json'] = _encode(manifest);
  files['filters.json'] =
      _encode({'extraStripSelectors': <String>[], 'disableDefaultStrips': false});
  files['permissions.json'] = _encode({
    'allowOfflineCache': true,
    'maxConcurrentRequests': 2,
    'requestDelayMs': [400, 1200],
    'respectRobotsTxt': true,
  });
  files['README.md'] = '# $name\n\n'
      'Generated by `tool/import_lnreader.dart` from the `$family` family in '
      '[$_upstream]($_upstream) (upstream id `$rawId`).\n\n'
      'Do not edit by hand: changes are overwritten on the next import. '
      'Fixtures under `tests/` must be recorded before this plugin is published.\n\n'
      'Upstream license: $_upstreamLicense.\n';

  seenHosts.add(host);
  plans.add(_Plan(id, family, files));
}

Map<String, dynamic> _readNovelFullSelectors(
    Map<String, dynamic> base, Map<String, dynamic> o) {
  final s = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
  final search = s['search'] as Map<String, dynamic>;
  final list = s['chapterList'] as Map<String, dynamic>;
  String slash(String v) => v.startsWith('/') ? v : '/$v';

  final searchPage = o['searchPage'];
  if (searchPage is String) search['path'] = slash(searchPage);
  final searchKey = o['searchKey'];
  if (searchKey is String) search['queryParam'] = searchKey;
  list['ajaxPath'] = slash(o['chapterListing'] as String);
  final pageParam = o['pageParam'];
  if (pageParam is String) list['pageParam'] = pageParam;
  return s;
}

/// Writes one plugin. Returns 'new', 'updated' or 'unchanged'.
/// Bumps the patch version only when generated content actually changed.
String _write(Directory out, _Plan plan, bool dryRun) {
  final dir = Directory('${out.path}/${plan.id}');
  final manifestFile = File('${dir.path}/plugin.json');
  var files = plan.files;
  var status = 'new';

  if (manifestFile.existsSync()) {
    final old = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final oldVersion = old['version'] as String? ?? '1.0.0';
    final candidate = jsonDecode(files['plugin.json']!) as Map<String, dynamic>;

    // Compare ignoring version and upstream commit, so a new upstream commit
    // alone never causes a version bump.
    final compare = jsonDecode(jsonEncode(candidate)) as Map<String, dynamic>;
    compare['version'] = oldVersion;
    final oldOrigin = old['origin'];
    final newOrigin = compare['origin'];
    if (oldOrigin is Map && newOrigin is Map) {
      newOrigin['upstreamCommit'] = oldOrigin['upstreamCommit'];
    }

    final same = files.entries.every((e) {
      final f = File('${dir.path}/${e.key}');
      if (!f.existsSync()) return false;
      final text = e.key == 'plugin.json' ? _encode(compare) : e.value;
      return f.readAsStringSync() == text;
    });
    if (same) return 'unchanged';

    candidate['version'] = _bumpPatch(oldVersion);
    files = {...files, 'plugin.json': _encode(candidate)};
    status = 'updated';
  }

  if (!dryRun) {
    dir.createSync(recursive: true);
    files.forEach((name, content) => File('${dir.path}/$name').writeAsStringSync(content));
  }
  return status;
}

String _bumpPatch(String v) {
  final parts = v.split('.');
  if (parts.length != 3) return '1.0.1';
  final patch = int.tryParse(parts[2]);
  if (patch == null) return '1.0.1';
  return '${parts[0]}.${parts[1]}.${patch + 1}';
}

