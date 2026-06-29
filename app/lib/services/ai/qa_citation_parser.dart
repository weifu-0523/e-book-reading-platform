/// Segments of an LLM Q&A answer, parsed by QaCitationParser.parse in T9.
///
/// PlainSegment is raw text; CitationSegment is a [ch=N] marker
/// referencing the chapter at index chapterIndex in the book's TOC.
sealed class TextSegment {}

class PlainSegment extends TextSegment {
  PlainSegment(this.text);
  final String text;
}

class CitationSegment extends TextSegment {
  CitationSegment(this.chapterIndex, this.marker);
  final int chapterIndex;
  final String marker; // original "[ch=N]" text
}

/// Parses [ch=N] markers in LLM Q&A answers into ordered TextSegments.
/// Plain text between/around markers becomes PlainSegments; each marker
/// becomes a CitationSegment preserving its original [ch=N] text.
class QaCitationParser {
  const QaCitationParser._();

  static final RegExp _pattern = RegExp(r'\[ch=(\d+)\]');

  /// Split [llmOutput] into ordered TextSegments. Invalid markers (e.g.
  /// [ch=abc]) are not matched and remain in the surrounding PlainSegment.
  static List<TextSegment> parse(String llmOutput) {
    if (llmOutput.isEmpty) return const [];
    final result = <TextSegment>[];
    var lastEnd = 0;
    for (final match in _pattern.allMatches(llmOutput)) {
      if (match.start > lastEnd) {
        result.add(PlainSegment(llmOutput.substring(lastEnd, match.start)));
      }
      final n = int.parse(match.group(1)!);
      result.add(CitationSegment(n, match.group(0)!));
      lastEnd = match.end;
    }
    if (lastEnd < llmOutput.length) {
      result.add(PlainSegment(llmOutput.substring(lastEnd)));
    }
    return result;
  }

  /// Convenience: just the chapter indices, in order, deduped.
  static List<int> extractCitations(String llmOutput) {
    final seen = <int>{};
    final result = <int>[];
    for (final match in _pattern.allMatches(llmOutput)) {
      final n = int.parse(match.group(1)!);
      if (seen.add(n)) result.add(n);
    }
    return result;
  }
}

/// Plain Dart class returned by QaHistoryDao for UI consumption.
class QaHistoryEntry {
  const QaHistoryEntry({
    required this.id,
    required this.bookId,
    required this.question,
    required this.answer,
    required this.citations,
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final String question;
  final String answer;
  final List<int> citations; // parsed from citations_json
  final DateTime createdAt;
}
