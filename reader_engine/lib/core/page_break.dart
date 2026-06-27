/// A character range identifying one page within a paginated chapter.
///
/// Offsets are in the same coordinate space as
/// `ReaderEngine.currentChapterPlainText` (post-T0 unification).
class PageBreak {
  final int startOffset;
  final int endOffset;

  const PageBreak({required this.startOffset, required this.endOffset});

  @override
  bool operator ==(Object other) =>
      other is PageBreak &&
      startOffset == other.startOffset &&
      endOffset == other.endOffset;

  @override
  int get hashCode => Object.hash(startOffset, endOffset);

  @override
  String toString() => 'PageBreak($startOffset..$endOffset)';
}
