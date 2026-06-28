/// Heuristic token estimator + budget-aware truncator.
///
/// Token estimate:
/// - CJK char (U+4E00..U+9FFF) = 1 token
/// - Other char = 0.25 token (4 chars per token)
///
/// Truncation strategy when over budget: head 1/2 + tail 1/2 of the
/// *budget* (chars), with the middle dropped and an omission marker inserted.
class TokenTruncator {
  const TokenTruncator._();

  static const int defaultBudget = 8000;

  /// Rough token count for [text].
  static int estimateTokens(String text) {
    var cjk = 0, other = 0;
    for (final code in text.runes) {
      if (_isCjk(code)) {
        cjk += 1;
      } else {
        other += 1;
      }
    }
    return cjk + (other ~/ 4);
  }

  static bool _isCjk(int code) => code >= 0x4E00 && code <= 0x9FFF;

  /// Truncate to ~maxTokens tokens by keeping the head and tail (each
  /// half of the budget in chars) and dropping the middle, replacing it
  /// with an omission marker. Returns input unchanged if already within
  /// budget.
  static String truncateToTokens(String text, int maxTokens) {
    if (estimateTokens(text) <= maxTokens) return text;

    final halfBudgetChars = maxTokens ~/ 2;
    final headEnd = halfBudgetChars.clamp(0, text.length);
    final tailStart = (text.length - halfBudgetChars).clamp(headEnd, text.length);

    final head = text.substring(0, headEnd);
    final tail = tailStart < text.length ? text.substring(tailStart) : '';
    final omitted = tailStart - headEnd;

    if (omitted > 0) {
      return '$head...（省略 $omitted 字）...$tail';
    }
    return '$head$tail';
  }
}
