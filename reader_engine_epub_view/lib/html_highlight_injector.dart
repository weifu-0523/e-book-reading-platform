import 'plain_text_utils.dart';
import 'package:meta/meta.dart';

/// 高亮区间数据（plain text 坐标）。
/// 注：本类在 T5 会移到 reader_engine 包，本任务内本地定义。
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

/// 把高亮区间注入 HTML。
///
/// 1. 用 [PlainTextUtils] 把 html → plainText + offsetMap
/// 2. 对每个 HighlightRange，反查 html start/end offset
/// 3. 在 html 对应位置插 `<span style="...">...</span>`
/// 4. 多个高亮重叠时：按 startOffset 升序处理，已注入区间内的后续高亮被截断
class HtmlHighlightInjector {
  const HtmlHighlightInjector._();

  static String inject(String html, List<HighlightRange> highlights) {
    if (highlights.isEmpty) return html;
    final (plain, offsetMap) = PlainTextUtils.htmlToPlainWithOffsets(html);
    final sorted = [...highlights]
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    final buf = StringBuffer();
    var cursor = 0;
    final covered = <List<int>>[];

    for (final h in sorted) {
      if (h.startOffset < 0 || h.endOffset > plain.length) continue;
      if (h.endOffset <= h.startOffset) continue;
      var effStart = h.startOffset;
      var effEnd = h.endOffset;
      for (final c in covered) {
        if (effStart < c[1]) {
          effStart = c[1];
        }
      }
      if (effStart >= effEnd) continue;

      final htmlStart = offsetMap[effStart];
      final htmlEnd = offsetMap[effEnd - 1] + 1;

      buf.write(html.substring(cursor, htmlStart));
      final style = _buildStyle(h.colorRgba, h.hasNote);
      buf.write('<span style="$style">');
      buf.write(html.substring(htmlStart, htmlEnd));
      buf.write('</span>');
      cursor = htmlEnd;
      covered.add([effStart, effEnd]);
    }
    buf.write(html.substring(cursor));
    return buf.toString();
  }

  static String _buildStyle(String rgba, bool hasNote) {
    final bg = 'background-color: $rgba';
    if (hasNote) return '$bg; border-bottom: 2px solid $rgba';
    return bg;
  }
}
