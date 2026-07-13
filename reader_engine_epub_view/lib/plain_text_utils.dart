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

  /// Locates an HTML anchor id (e.g., `<p id="ch1">` or `<a name="ch1">`)
  /// and returns the corresponding plain-text character offset within the
  /// same coordinate system as [htmlToPlainWithOffsets].
  ///
  /// Used to resolve NCX TOC fragment anchors (e.g., Calibre's
  /// `#filepos16764`) to a charOffset for `EpubCfiLocator`.
  ///
  /// Returns `null` when the anchor id is not present in `html`. Returns `0`
  /// when the anchor is at the very start of plain text.
  ///
  /// Matching rules:
  /// - Recognizes `id="X"`, `id='X'`, `name="X"`, `name='X'` (any case for
  ///   the attribute name; X must be quoted and exactly equal to `anchor`).
  /// - Uses the position of the **opening `<` of the element containing the
  ///   attribute** as the html offset, then maps it to plain coordinates.
  /// - When multiple matches exist, uses the first occurrence.
  static int? anchorToPlainOffset(String html, String anchor) {
    final patterns = [
      RegExp("id=[\"']${RegExp.escape(anchor)}[\"']"),
      RegExp("name=[\"']${RegExp.escape(anchor)}[\"']"),
    ];
    int? attrStart;
    for (final p in patterns) {
      final m = p.firstMatch(html);
      if (m != null) {
        attrStart = m.start;
        break;
      }
    }
    if (attrStart == null) return null;

    final lt = html.lastIndexOf('<', attrStart);
    final htmlOffset = lt < 0 ? 0 : lt;

    final (_, offsets) = htmlToPlainWithOffsets(html);
    if (offsets.isEmpty) return 0;
    var lo = 0, hi = offsets.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = lo + (hi - lo) ~/ 2;
      if (offsets[mid] <= htmlOffset) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans + 1;
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
