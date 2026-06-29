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
