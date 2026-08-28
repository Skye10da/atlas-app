/// Detects and parses "status window" style blocks inside raw chapter
/// text, producing a list of ContentSpan (prose or BlockCard) in
/// original reading order.
///
/// Pipeline:
///   1. Split chapter text into paragraphs.
///   2. Flag paragraphs that LOOK block-shaped (candidate blocks) using
///      cheap structural signals (borders, bracket markers, dense
///      key:value lines).
///   3. Run each candidate through registered BlockCardRules in
///      priority order; first rule whose keyword signal matches AND
///      whose field regexes parse at/above a confidence floor wins.
///   4. If no rule parses the candidate with enough confidence, hand it
///      to an optional BlockCardAiExtractor (local Ollama model) as a
///      second pass, since raw scraped text varies a lot by source.
///   5. If that also fails/is unavailable, keep BlockCard.fallback —
///      never silently drop the text, never guess past the confidence
///      floor.
///
/// Steps 1-3 are the whole feature and work fully offline with zero
/// dependencies — a reader with no local model configured still gets
/// correct system/cultivation cards for any block the regex rules
/// recognize. Step 4 (aiExtractor) is optional assistance for
/// candidates the rules can't parse (odd site formatting, unusual
/// novel-specific templates); leaving it null is a fully supported
/// configuration, not a degraded one.
library;

import 'package:atlas_app/core/content_engine/block_card/block_card_model.dart';
import 'package:atlas_app/core/content_engine/block_card/rules/bracketed_line_rule.dart';

/// A single "does this look like a status block, and how do I parse it"
/// rule. Plugins register these for site- or novel-specific formats.
abstract class BlockCardRule {
  BlockCardType get type;

  /// Cheap keyword/structure check — should be a fast reject, not a
  /// full parse. Runs on every candidate block.
  bool signalMatches(String block);

  /// Full parse attempt. Only called if signalMatches() returned true.
  /// Return null if the signal matched but fields didn't parse cleanly
  /// (falls through to the AI extractor / fallback).
  BlockCard? parse(String block);
}

/// Detects LitRPG/system status windows: "Status Window", "HP:", "MP:",
/// "Lv.", stat blocks (STR/AGI/VIT/INT), skill/level-up notifications.
class SystemStatusRule implements BlockCardRule {
  @override
  BlockCardType get type => BlockCardType.system;

  static final _signal = RegExp(
    r'(status\s*window|system\s*notification|\bHP\s*[:：]|\bMP\s*[:：]|\bLv\.?\s*\d|\bSTR\b|\bAGI\b)',
    caseSensitive: false,
  );

  static final _kv = RegExp(
    r'^\s*([A-Za-z ]{2,20})\s*[:：]\s*(.+)$',
    multiLine: true,
  );

  static final _bar = RegExp(
    r'([A-Za-z]{2,4})\s*[:：]\s*([\d,]+)\s*/\s*([\d,]+)',
  );

  @override
  bool signalMatches(String block) => _signal.hasMatch(block);

  @override
  BlockCard? parse(String block) {
    final fields = <BlockCardField>[];
    final seenLabels = <String>{};

    for (final m in _bar.allMatches(block)) {
      final label = m.group(1)!.toUpperCase();
      final current = double.tryParse(m.group(2)!.replaceAll(',', ''));
      final max = double.tryParse(m.group(3)!.replaceAll(',', ''));
      if (current == null || max == null) continue;
      fields.add(
        BlockCardField(
          label: label,
          value: '${m.group(2)} / ${m.group(3)}',
          display: FieldDisplay.bar,
          current: current,
          max: max,
        ),
      );
      seenLabels.add(label);
    }

    for (final m in _kv.allMatches(block)) {
      final label = m.group(1)!.trim();
      if (seenLabels.contains(label.toUpperCase())) continue;
      if (label.length > 20) continue; // guards against matching prose lines
      fields.add(BlockCardField(label: label, value: m.group(2)!.trim()));
    }

    if (fields.isEmpty) return null;

    // Confidence scales with how many fields we actually extracted vs.
    // how many content lines the block has; decorative borders don't
    // dilute it.
    final confidence =
        (fields.length / BlockCardDetector._contentLineCount(block)).clamp(
          0.0,
          1.0,
        );

    return BlockCard(
      type: BlockCardType.system,
      title: 'Character status',
      fields: fields,
      confidence: confidence < 0.4 ? 0.4 : confidence,
      rawText: block,
    );
  }
}

/// Detects cultivation status: "Realm:", "Cultivation Base", "Dantian",
/// "Spiritual Root", "Meridians", breakthrough/tribulation language.
class CultivationStatusRule implements BlockCardRule {
  @override
  BlockCardType get type => BlockCardType.cultivation;

  static final _signal = RegExp(
    r'(cultivation\s*(base|realm)|dantian|spiritual\s*root|meridian|tribulation|breakthrough|sect\s*rank)',
    caseSensitive: false,
  );

  static final _kv = RegExp(
    r'^\s*([A-Za-z ]{2,24})\s*[:：]\s*(.+)$',
    multiLine: true,
  );

  static final _percent = RegExp(r'(\d{1,3})\s*%');

  @override
  bool signalMatches(String block) => _signal.hasMatch(block);

  @override
  BlockCard? parse(String block) {
    final fields = <BlockCardField>[];

    for (final m in _kv.allMatches(block)) {
      final label = m.group(1)!.trim();
      final value = m.group(2)!.trim();
      final pct = _percent.firstMatch(value);
      if (pct != null &&
          (label.toLowerCase().contains('base') ||
              label.toLowerCase().contains('dantian') ||
              label.toLowerCase().contains('qi'))) {
        final current = double.parse(pct.group(1)!);
        fields.add(
          BlockCardField(
            label: label,
            value: value,
            display: FieldDisplay.bar,
            current: current,
            max: 100,
          ),
        );
      } else {
        fields.add(BlockCardField(label: label, value: value));
      }
    }

    if (fields.isEmpty) return null;

    final confidence =
        (fields.length / BlockCardDetector._contentLineCount(block)).clamp(
          0.0,
          1.0,
        );

    return BlockCard(
      type: BlockCardType.cultivation,
      title: 'Cultivation status',
      fields: fields,
      confidence: confidence < 0.4 ? 0.4 : confidence,
      rawText: block,
    );
  }
}

/// Optional second-pass extractor backed by a local model (e.g. Ollama
/// running qwen3:8b). Implement this against your existing Ollama
/// client. Returns null if the model errors out or is unreachable —
/// caller falls back to BlockCard.fallback(candidate), never throws
/// into the reading flow.
abstract class BlockCardAiExtractor {
  Future<BlockCard?> extract(String candidateBlock);
}

class BlockCardDetector {
  BlockCardDetector({
    List<BlockCardRule>? rules,
    this.aiExtractor,
    this.ruleConfidenceFloor = 0.5,
  }) : rules =
           rules ??
           [
             SystemStatusRule(),
             CultivationStatusRule(),
             BracketedLineRule(),
             ..._registeredRules,
           ];

  final List<BlockCardRule> rules;
  final BlockCardAiExtractor? aiExtractor;

  /// Minimum confidence a rule-based parse needs before it's trusted
  /// without a second opinion from the AI extractor.
  final double ruleConfidenceFloor;

  static final List<BlockCardRule> _registeredRules = [];

  /// Plugin hook: register a novel- or site-specific rule without
  /// touching core detector code. Registered rules run after the
  /// built-in defaults.
  static void registerBlockCardRule(BlockCardRule rule) =>
      _registeredRules.add(rule);

  static List<BlockCardRule> get registeredRules =>
      List.unmodifiable(_registeredRules);

  /// Structural pre-filter regexes and helpers.
  ///
  /// NOTE: a lone bracketed word ("[Ward]", "[Luminous Beam]") is NOT
  /// a block signal on its own — LitRPG prose uses that formatting for
  /// ordinary inline skill/spell mentions constantly. Square/lenticular
  /// brackets only count when there are multiple bracketed segments OR
  /// an actual header keyword inside one ("[Status Window]",
  /// "[System Notification]") OR a single unit covering nearly the
  /// whole paragraph (system speech).
  ///
  /// Marker families recognized (surveyed across real web-novel sources):
  /// - lenticular brackets (CJK-style system windows)
  /// - square-bracket units / tag chains (`[Tier 9][Rank C]`)
  /// - angle-bracket lines and `>> Header <<` markers
  /// - box-drawing fences and underscore rules (`_____`)
  /// - audio cues on their own line (`Ding!`, `[Ding!]`)
  /// - two consecutive `key: value` lines, tolerating `>` quote markers
  static final _lenticular = RegExp(r'【[^】]*】');
  static final _systemKeyword = RegExp(
    r'(status|system|quest|task|mission|panel|reward\w*|notification|level\s*up|skill|inventory|loot|breakthrough|gift\s*pack|activated|unlocked)',
    caseSensitive: false,
  );
  static final _squareHeader = RegExp(
    r'\[\s*(status|system|notification|quest|level\s*up|skill\s*(acquired|gained|learned)|inventory|loot|breakthrough)\b[^\]]*\]',
    caseSensitive: false,
  );
  static final _angleLine = RegExp(
    r'(?:^|\n)\s*<[^<>\n]{1,120}>|(?:^|\n)\s*>>[^<>\n]{1,80}<<',
  );
  static final _fence = RegExp(
    r'━{2,}|═{2,}|╔|╗|╚|╝|(?:^|\n)\s*_{3,}\s*(?:\n|$)|(?:_ ?){5,}',
  );
  static final _dingCue = RegExp(
    r'(?:^|\n)\s*\[?\s*din[g]+!+\s*\]?',
    caseSensitive: false,
  );
  static final _consecutiveKv = RegExp(
    r'^[>\s]*[A-Za-z ()]{2,26}[:：].+\n[>\s]*[A-Za-z ()]{2,26}[:：]',
    multiLine: true,
  );
  static final _bracketUnit = RegExp(r'\[[^\[\]\n]*\]');
  static final _fenceChars = RegExp(r'[━═╔╗╚╝_\s]');
  static final _kvLineStart = RegExp(r'^[^:：\n]{2,30}[:：]');
  static final _systemHeaderWord = RegExp(
    r'(notification|status\s*window|quest|objective|reward|penalty|inventory|shop|lottery|skill)',
    caseSensitive: false,
  );

  bool looksBlockShaped(String paragraph) {
    final lenticularMatches = _lenticular.allMatches(paragraph).toList();
    if (lenticularMatches.length >= 2) return true;
    if (lenticularMatches.isNotEmpty && _systemKeyword.hasMatch(paragraph)) {
      return true;
    }
    if (_squareHeader.hasMatch(paragraph)) return true;
    if (_angleLine.hasMatch(paragraph)) return true;
    if (_fence.hasMatch(paragraph) &&
        paragraph.replaceAll(_fenceChars, '').trim().length >= 6) {
      // Fences only count when they wrap real content; bare scene
      // separators are never panels.
      return true;
    }
    if (_dingCue.hasMatch(paragraph)) return true;
    if (_consecutiveKv.hasMatch(paragraph)) return true;

    // Square-bracket units: chains ([X][Y][Z]) are always panels, and
    // a single unit is a panel when it covers nearly the whole
    // paragraph (system speech); prose with an inline skill name has
    // tiny coverage and stays prose.
    if (paragraph.contains('[')) {
      final units = _bracketUnit.allMatches(paragraph).length;
      var unitChars = 0;
      for (final m in _bracketUnit.allMatches(paragraph)) {
        unitChars += m.group(0)!.length;
      }
      final total = paragraph.replaceAll(RegExp(r'\s'), '').length;
      final coverage = total > 0 ? unitChars / total : 0.0;
      if (coverage >= 0.6 && (units >= 2 || coverage >= 0.85)) return true;
    }
    return false;
  }

  Future<List<ContentSpan>> process(String chapterText) async {
    final paragraphs = chapterText.split(RegExp(r'\n\s*\n'));
    final spans = <ContentSpan>[];
    var i = 0;
    while (i < paragraphs.length) {
      final trimmed = paragraphs[i].trim();
      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      if (_isFenceOnly(trimmed)) {
        final fenced = _collectFencedBlock(paragraphs, i);
        if (fenced != null) {
          // Rows after the closing fence (stat lines under a "Level
          // Up!" header window) belong to the same panel. The original
          // paragraphs (fence lines included) form the candidate so
          // fence-based rule signals still fire.
          var j = fenced.$1;
          final extra = <String>[];
          while (j < paragraphs.length && extra.length <= 24) {
            final next = paragraphs[j].trim();
            if (next.isEmpty) break;
            if (_isFenceOnly(next)) {
              extra.add(next);
              j++;
              break;
            }
            if (!_continuesPanel(next)) break;
            extra.add(next);
            j++;
          }
          final originalRows = [
            for (var k = i; k < fenced.$1; k++) paragraphs[k].trim(),
            ...extra,
          ];
          final card = await _parseCandidate(originalRows.join('\n'));
          spans.add(ContentSpan.card(card));
          i = j;
          continue;
        }
        spans.add(ContentSpan.prose(paragraphs[i]));
        i++;
        continue;
      }

      if (!looksBlockShaped(trimmed)) {
        spans.add(ContentSpan.prose(paragraphs[i]));
        i++;
        continue;
      }

      // Web sources typically emit every panel row as its own
      // paragraph. Absorb short structural rows that follow a flagged
      // opener so the whole window parses as one card.
      final buffer = <String>[trimmed];
      var j = i + 1;
      while (j < paragraphs.length && buffer.length <= 24) {
        final next = paragraphs[j].trim();
        if (next.isEmpty || !_continuesPanel(next)) break;
        buffer.add(next);
        j++;
      }
      final card = await _parseCandidate(buffer.join('\n'));
      spans.add(ContentSpan.card(card));
      i = j;
    }
    return spans;
  }

  /// Collects paragraphs between two fence-only lines as a single
  /// fenced candidate. Returns (endIndex, blockText), or null when
  /// unclosed, oversized, or contentless (a bare separator).
  (int, String)? _collectFencedBlock(List<String> paragraphs, int start) {
    final inner = <String>[];
    var j = start + 1;
    var closed = false;
    while (j < paragraphs.length && j - start <= 40) {
      final t = paragraphs[j].trim();
      if (_isFenceOnly(t)) {
        closed = true;
        j++;
        break;
      }
      inner.add(t);
      j++;
    }
    final totalLength = inner.fold<int>(0, (n, s) => n + s.length);
    if (!closed || inner.isEmpty || totalLength > 800) return null;
    return (j, inner.join('\n'));
  }

  static bool _isFenceOnly(String trimmed) =>
      _fence.hasMatch(trimmed) && trimmed.replaceAll(_fenceChars, '').isEmpty;

  /// Whether [trimmed] reads as another structural row of an open panel
  /// rather than ordinary narrative prose.
  bool _continuesPanel(String trimmed) {
    if (looksBlockShaped(trimmed)) return true;
    if (_kvLineStart.hasMatch(trimmed)) return true;
    if (_systemHeaderWord.hasMatch(trimmed)) return true;
    final terminated = RegExp(r'[.!?…][")\]」』”’]*$').hasMatch(trimmed);
    if (!terminated && trimmed.length <= 60) return true;
    if (trimmed.length <= 40 && trimmed.toUpperCase() == trimmed) return true;
    return false;
  }

  /// Non-empty lines excluding decorative border/fence rows, so
  /// border wrappers don't dilute parse confidence.
  static int _contentLineCount(String block) => block
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .where((l) => l.replaceAll(_borderChars, '').isNotEmpty)
      .length;

  static final _borderChars = RegExp(r'[━═╔╗╚╝=\-—–_\[\]【】\s]');

  Future<BlockCard> _parseCandidate(String candidate) async {
    for (final rule in rules) {
      if (!rule.signalMatches(candidate)) continue;
      final parsed = rule.parse(candidate);
      if (parsed != null && parsed.confidence >= ruleConfidenceFloor) {
        return parsed;
      }
    }

    if (aiExtractor != null) {
      final aiResult = await aiExtractor!.extract(candidate);
      if (aiResult != null) return aiResult;
    }

    return BlockCard.fallback(candidate);
  }

  /// Synchronous version that runs only the rule-based detection (no AI
  /// extractor). Use when you need spans in the same frame as content load.
  List<ContentSpan> processSync(String chapterText) {
    final paragraphs = chapterText.split(RegExp(r'\n\s*\n'));
    final spans = <ContentSpan>[];
    var i = 0;
    while (i < paragraphs.length) {
      final trimmed = paragraphs[i].trim();
      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      if (_isFenceOnly(trimmed)) {
        final fenced = _collectFencedBlock(paragraphs, i);
        if (fenced != null) {
          var j = fenced.$1;
          final extra = <String>[];
          while (j < paragraphs.length && extra.length <= 24) {
            final next = paragraphs[j].trim();
            if (next.isEmpty) break;
            if (_isFenceOnly(next)) {
              extra.add(next);
              j++;
              break;
            }
            if (!_continuesPanel(next)) break;
            extra.add(next);
            j++;
          }
          final originalRows = [
            for (var k = i; k < fenced.$1; k++) paragraphs[k].trim(),
            ...extra,
          ];
          final card = _parseCandidateSync(originalRows.join('\n'));
          spans.add(ContentSpan.card(card));
          i = j;
          continue;
        }
        spans.add(ContentSpan.prose(paragraphs[i]));
        i++;
        continue;
      }

      if (!looksBlockShaped(trimmed)) {
        spans.add(ContentSpan.prose(paragraphs[i]));
        i++;
        continue;
      }

      final buffer = <String>[trimmed];
      var j = i + 1;
      while (j < paragraphs.length && buffer.length <= 24) {
        final next = paragraphs[j].trim();
        if (next.isEmpty || !_continuesPanel(next)) break;
        buffer.add(next);
        j++;
      }
      final card = _parseCandidateSync(buffer.join('\n'));
      spans.add(ContentSpan.card(card));
      i = j;
    }
    return spans;
  }

  BlockCard _parseCandidateSync(String candidate) {
    for (final rule in rules) {
      if (!rule.signalMatches(candidate)) continue;
      final parsed = rule.parse(candidate);
      if (parsed != null && parsed.confidence >= ruleConfidenceFloor) {
        return parsed;
      }
    }
    return BlockCard.fallback(candidate);
  }
}
