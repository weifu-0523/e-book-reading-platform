// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'plain_text_utils.dart';
import 'package:reader_engine/rendering/highlight_range.dart';

/// 把高亮区间注入 HTML。
///
/// 1. 用 [PlainUtils] 把 html → plainText + offsetMap
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
