import 'package:meta/meta.dart';

/// HTML 处理工具：plain text 提取 + plain→HTML offset 映射。
/// 供 [HtmlHighlightInjector] 与选区反查共用，保证坐标系一致。
@immutable
class PlainTextUtils {
  const PlainTextUtils._();

  /// 把 HTML 转为 (plainText, htmlOffsets)。
  ///
  /// - plainText：去除所有标签、解码 HTML 实体后的纯文本
  /// - htmlOffsets[i]：plainText 第 i 个字符在原 HTML 中的起始 offset
  ///
  /// 已知边界：
  /// - 属性值含 `<`（`<a title="a<b">`）：按 tag-skip 处理，可能误判；EPUB 罕见
  /// - 字符引用 `&#nn;` 数字形式支持；命名实体仅 &amp; &lt; &gt; &quot; &apos; &nbsp;
  static (String, List<int>) htmlToPlainWithOffsets(String html) {
    final plain = StringBuffer();
    final offsets = <int>[];
    var i = 0;
    while (i < html.length) {
      final ch = html[i];
      if (ch == '<') {
        // tag-skip 直到 '>'
        final end = html.indexOf('>', i);
        if (end < 0) break;
        i = end + 1;
        continue;
      }
      if (ch == '&') {
        // entity 解码
        final semi = html.indexOf(';', i);
        if (semi > 0 && semi - i <= 6) {
          final entity = html.substring(i + 1, semi);
          final decoded = _decodeEntity(entity);
          if (decoded != null) {
            for (var j = 0; j < decoded.length; j++) {
              plain.write(decoded[j]);
              offsets.add(i); // 每个 decoded 字符的 HTML 起点 = '&' 位置
            }
            i = semi + 1;
            continue;
          }
        }
      }
      plain.write(ch);
      offsets.add(i);
      i++;
    }
    return (plain.toString(), offsets);
  }

  static String? _decodeEntity(String entity) {
    switch (entity) {
      case 'amp':
        return '&';
      case 'lt':
        return '<';
      case 'gt':
        return '>';
      case 'quot':
        return '"';
      case 'apos':
        return "'";
      case 'nbsp':
        return ' ';
    }
    if (entity.startsWith('#')) {
      final code = int.tryParse(entity.substring(1));
      if (code != null) return String.fromCharCode(code);
    }
    return null;
  }
}
