/// Allocates and enforces token budgets across the prompt context layers.
///
/// Estimation is script-aware: CJK ideographs, kana, and Hangul syllables cost
/// roughly one token each on modern tokenizers, while latin text averages
/// ~4 characters per token. Truncations snap to line boundaries so prompt
/// sections never end mid-sentence unless a single line exhausts the budget.
class TokenBudgeter {
  const TokenBudgeter({
    this.totalBudget = 4096,
    this.systemBudget = 400,
    this.storyMemoryBudget = 1800,
    this.historyBudget = 1200,
    this.userQueryBudget = 400,
    this.sceneExcerptBudget = 600,
    this.relationshipBudget = 400,
  });

  final int totalBudget;
  final int systemBudget;
  final int storyMemoryBudget;
  final int historyBudget;
  final int userQueryBudget;

  /// Budget for the BM25 scene-excerpt block fed from query-relevant scenes.
  final int sceneExcerptBudget;

  /// Budget for the relationship block (spoiler-capped to the reader's chapter).
  final int relationshipBudget;

  /// Fast heuristic approximation: CJK runes cost ~1 token each, other
  /// scripts ~4 characters per token. Preserves the legacy behavior
  /// (`ceil(len / 4)`) for pure-latin text.
  int estimateTokens(String text) {
    if (text.isEmpty) return 0;
    int cjk = 0;
    final other = StringBuffer();
    for (final rune in text.runes) {
      if (_isCjkRune(rune)) {
        cjk++;
      } else {
        other.writeCharCode(rune);
      }
    }
    final otherTokens = other.isEmpty ? 0 : (other.length / 4.0).ceil();
    return cjk + otherTokens;
  }

  /// Truncates text to fit within a given token budget, preferring to cut at
  /// a line boundary. A single line longer than the budget is hard-trimmed
  /// rune-by-rune using the same CJK-aware accounting.
  String truncateToBudget(String text, int maxTokens) {
    if (maxTokens <= 0) return '';
    final maxChars = maxTokens * 4;
    if (text.length <= maxChars) return text;

    int used = 0;
    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final lineTokens = estimateTokens(lines[i]) + (i > 0 ? 1 : 0);
      if (used + lineTokens > maxTokens) {
        if (i == 0 || used == 0) {
          // Single oversized line: cut it precisely to the remaining budget.
          return _trimRunesToBudget(
            lines.sublist(0, i + 1).join('\n'),
            maxTokens - used,
          );
        }
        // Drop the trailing separator so output ends on a clean line.
        final kept = lines.sublist(0, i).join('\n');
        return kept.endsWith('\n') ? kept : '$kept\n';
      }
      used += lineTokens;
    }
    return text;
  }

  /// Trims a single rune sequence to approximately [maxTokens] tokens using
  /// CJK-aware accounting (CJK runes are counted individually).
  String _trimRunesToBudget(String text, int maxTokens) {
    if (maxTokens <= 0) return '';
    final buffer = StringBuffer();
    int cjk = 0;
    final other = StringBuffer();
    for (final rune in text.runes) {
      buffer.writeCharCode(rune);
      if (_isCjkRune(rune)) {
        cjk++;
      } else {
        other.writeCharCode(rune);
      }
      final used = cjk + (other.isEmpty ? 0 : (other.length / 4.0).ceil());
      if (used >= maxTokens) break;
    }
    return buffer.toString();
  }

  bool _isCjkRune(int rune) {
    return (rune >= 0x3040 && rune <= 0x30FF) || // Hiragana + Katakana
        (rune >= 0x3400 && rune <= 0x4DBF) || // CJK Ext A
        (rune >= 0x4E00 && rune <= 0x9FFF) || // CJK Unified Ideographs
        (rune >= 0xAC00 && rune <= 0xD7AF) || // Hangul syllables
        (rune >= 0xF900 && rune <= 0xFAFF) || // CJK Compatibility Ideographs
        (rune >= 0x20000 && rune <= 0x2A6DF); // CJK Ext B
  }
}
