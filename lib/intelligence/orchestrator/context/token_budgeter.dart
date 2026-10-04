/// Allocates and enforces token budgets across the 5 prompt context layers.
class TokenBudgeter {
  const TokenBudgeter({
    this.totalBudget = 4096,
    this.systemBudget = 400,
    this.storyMemoryBudget = 1800,
    this.historyBudget = 1200,
    this.userQueryBudget = 400,
  });

  final int totalBudget;
  final int systemBudget;
  final int storyMemoryBudget;
  final int historyBudget;
  final int userQueryBudget;

  /// Fast heuristic approximation: ~4 English/alphanumeric characters per token.
  int estimateTokens(String text) {
    if (text.isEmpty) return 0;
    return (text.length / 4.0).ceil();
  }

  /// Truncates text to fit within a given token budget.
  String truncateToBudget(String text, int maxTokens) {
    final maxChars = maxTokens * 4;
    if (text.length <= maxChars) return text;
    return text.substring(0, maxChars);
  }
}

