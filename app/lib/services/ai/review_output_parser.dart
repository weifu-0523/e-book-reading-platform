import 'dart:convert';

/// Parsed review output from LLM JSON response.
class ReviewOutput {
  const ReviewOutput({required this.summary, required this.keyTakeaways});
  final String summary;
  final List<String> keyTakeaways;
}

/// Parses the LLM's review-mode JSON response.
///
/// Tolerates:
/// - Leading/trailing whitespace
/// - ```json ... ``` or ``` ... ``` fences (some LLMs ignore "no fences" instruction)
/// - Non-String elements in keyTakeaways (silently filtered)
///
/// Returns null if:
/// - JSON unparseable after fence stripping
/// - Top-level not an object
/// - `summary` field missing or not a String
/// - `keyTakeaways` missing or not a List
class ReviewOutputParser {
  const ReviewOutputParser._();

  static ReviewOutput? parse(String raw) {
    final trimmed = raw.trim();
    final unfenced = _stripFence(trimmed);
    final decoded = _tryDecode(unfenced);
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) return null;
    final summary = decoded['summary'];
    if (summary is! String) return null;
    final takeaways = decoded['keyTakeaways'];
    if (takeaways is! List) return null;
    final filtered =
        takeaways.whereType<String>().where((s) => s.isNotEmpty).toList();
    return ReviewOutput(summary: summary, keyTakeaways: filtered);
  }

  /// Strips one layer of ``` or ```json fencing if present.
  static String _stripFence(String s) {
    if (!s.startsWith('```')) return s;
    final firstNewline = s.indexOf('\n');
    if (firstNewline < 0) return s;
    var body = s.substring(firstNewline + 1);
    if (body.endsWith('```')) {
      body = body.substring(0, body.length - 3);
    }
    return body.trim();
  }

  static Object? _tryDecode(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }
}
