import 'package:meta/meta.dart';

/// 高亮区间数据（plain text 坐标）。
/// 由 EpubxRenderer 把 Annotation 适配为此类型，传给 HtmlHighlightInjector。
@immutable
class HighlightRange {
  final int startOffset;
  final int endOffset;
  final String colorRgba;
  final bool hasNote;
  const HighlightRange(
    this.startOffset,
    this.endOffset,
    this.colorRgba, {
    this.hasNote = false,
  });
}
