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

import 'dart:convert';
import 'dart:io';

import 'package:reader_engine_epub_view/html_chapter_source.dart';

/// M4.5: 把纯文本 (TXT) 文件转成 [HtmlChapterSource] 列表（单章），喂给
/// [ConcreteEpubReaderEngine.openChapters]（复用 EPUB HTML 渲染管道）。
///
/// **切章规则**：整篇作为单章（用户已确认 M4.5 范围）。长 TXT 靠分页翻页
/// 阅读，目录 tab 显示单条「全文」。
///
/// **分段（M4.6 启发式）**：每行独立成 `<p>`（兼容中文小说"每行一段"
/// 格式 + 有空行分隔的正常文本）。空行作分隔符跳过。HTML 实体转义。
///
/// **编码**：默认 UTF-8，解码失败降级 latin1。
///
/// **HTML 转义**：plain text 的 `<`/`>`/`&` 转义为实体，避免被当 HTML 标签。
class TextBookLoader {
  const TextBookLoader._();

  /// 从文件路径加载。返回单元素列表（空文件也返回单空章，不抛）。
  static Future<List<HtmlChapterSource>> loadFile(
    String path, {
    String title = '',
  }) async {
    final bytes = await File(path).readAsBytes();
    return load(bytes, title: title);
  }

  /// 从内存字节加载（供测试与 provider 直接调用）。
  static List<HtmlChapterSource> load(
    List<int> bytes, {
    String title = '',
  }) {
    final text = _decodeText(bytes);
    return [HtmlChapterSource(
      title: title.isEmpty ? '全文' : title,
      html: parseText(text),
    )];
  }

  /// 把纯文本转成 HTML（M4.6 启发式分段）。
  ///
  /// M4.6 (#6) 修复：原实现按 `\n\s*\n` 空行切分，中文小说常见连续行无空行
  /// 时整篇当一个 `<p>`，导致 Paginator 退化、内容溢出屏幕。
  ///
  /// 新规则（spec A5）：
  /// - 空行作分隔符，跳过不输出 `<p>`
  /// - 长行 / 短行每行独立成 `<p>`（杜绝超长单段，保证 Paginator 正常分页）
  ///
  /// 公开供测试直接调。
  static String parseText(String text) {
    if (text.trim().isEmpty) return '<p></p>';

    final lines = text.split('\n');
    final buf = StringBuffer();

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue; // 空行作分隔符
      // 每行独立成 <p>（中文小说每行一段事实标准；杜绝超长单段）
      buf.write('<p>${_escapeHtml(line)}</p>');
    }

    final result = buf.toString();
    return result.isEmpty ? '<p></p>' : result;
  }

  static String _decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static String _escapeHtml(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
