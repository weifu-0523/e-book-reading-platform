/// One chunked passage produced by BookChunker (T4) and persisted by
/// BookPassagesDao.insertMany. Plain Dart class — no drift annotations.
class PassageChunk {
  const PassageChunk({
    required this.chapterIndex,
    required this.charOffset,
    required this.charLength,
    required this.contentText,
    required this.tokenEstimate,
  });

  final int chapterIndex;
  final int charOffset;
  final int charLength;
  final String contentText;
  final int tokenEstimate;
}
