import 'package:meta/meta.dart';

/// 用户选区事件（由 EpubxRenderer 在选区结束时 emit）。
@immutable
class HighlightSelection {
  final String text;
  final int chapterIndex;
  final int startOffset;
  final int endOffset;

  const HighlightSelection({
    required this.text,
    required this.chapterIndex,
    required this.startOffset,
    required this.endOffset,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightSelection &&
          text == other.text &&
          chapterIndex == other.chapterIndex &&
          startOffset == other.startOffset &&
          endOffset == other.endOffset;

  @override
  int get hashCode => Object.hash(text, chapterIndex, startOffset, endOffset);
}
