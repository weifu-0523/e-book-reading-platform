/// Result of parsing a chapter-mode AI output into summary + bullet list.
class ChapterBulletParseResult {
  const ChapterBulletParseResult({
    required this.summary,
    required this.bullets,
  });
  final String summary;
  final List<String> bullets;
}

/// Splits chapter-mode AI output into (summary, bullets).
///
/// Algorithm:
/// 1. Split into lines.
/// 2. Lines matching the bullet regex (`- x` or `* x`) are bullets.
/// 3. Non-empty non-bullet lines are joined (with space) into the summary.
/// 4. Empty input → empty result.
class ChapterBulletParser {
  const ChapterBulletParser._();

  static final _bulletRegex = RegExp(r'^\s*[-*]\s+(.+?)\s*$');

  static ChapterBulletParseResult parse(String text) {
    if (text.trim().isEmpty) {
      return const ChapterBulletParseResult(summary: '', bullets: []);
    }
    final lines = text.split('\n');
    final summaryBuf = <String>[];
    final bullets = <String>[];
    for (final line in lines) {
      final m = _bulletRegex.firstMatch(line);
      if (m != null) {
        bullets.add(m.group(1)!.trim());
      } else if (line.trim().isNotEmpty) {
        summaryBuf.add(line.trim());
      }
    }
    final summary = summaryBuf.join(' ').trim();
    return ChapterBulletParseResult(summary: summary, bullets: bullets);
  }
}
