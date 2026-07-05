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

import 'package:markdown/markdown.dart' as md;
import 'package:reader_engine_epub_view/html_chapter_source.dart';

/// M4.5: 把 Markdown 文件转成 [HtmlChapterSource] 列表，喂给
/// [ConcreteEpubReaderEngine.openChapters]（复用 EPUB HTML 渲染管道）。
///
/// **切章规则**：按 `^#{1,2}\s` 标题切章（`#` 与 `##` 都是切章点；`###` 及
/// 以下不切，归入当前章正文）。第一个标题前的内容若有实质文本，归入
/// title="前言" 的首章；无则丢弃。无任何 `#`/`##` 标题：整篇单章，
/// title=[title]（文件名去扩展名）。
///
/// **编码**：默认 UTF-8，解码失败降级 latin1（保证不乱码、不崩溃）。
///
/// **渲染**：每章 body 用 `markdown.markdownToHtml()` 转 HTML，由 fwfh 的
/// HtmlWidget 渲染（与 EPUB 一致）。
class MarkdownBookLoader {
  const MarkdownBookLoader._();

  /// 从文件路径加载。返回章节数 ≥ 1（空文件也返回单空章，不抛）。
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
    return parseMarkdown(text, fallbackTitle: title);
  }

  /// 解析 Markdown 文本为章节列表（纯逻辑，供测试直接调）。
  static List<HtmlChapterSource> parseMarkdown(
    String text, {
    required String fallbackTitle,
  }) {
    // 按 # / ## 标题行切章。空文件或纯空白 → 单章。
    final lines = text.split('\n');
    final chapters = <_MdChapter>[];
    final preface = StringBuffer();

    for (final line in lines) {
      final m = _h1H2Prefix.firstMatch(line);
      if (m != null) {
        // 命中标题：开启新章。标题前的内容（若有实质文本）作为前言章。
        if (chapters.isEmpty && preface.toString().trim().isNotEmpty) {
          chapters.add(_MdChapter(title: '前言', body: preface.toString()));
        }
        preface.clear();
        chapters.add(_MdChapter(
          title: m.group(1)!.trim(),
          body: '$line\n',
        ));
      } else {
        // 标题之前的行进 preface；之后的行进当前章 body。
        if (chapters.isEmpty) {
          preface.writeln(line);
        } else {
          chapters.last.body.write('$line\n');
        }
      }
    }

    if (chapters.isEmpty) {
      // 无任何标题：整篇单章。
      final single = text.trim().isEmpty ? '' : text;
      return [HtmlChapterSource(
        title: fallbackTitle.isEmpty ? '正文' : fallbackTitle,
        html: _markdownToHtml(single),
      )];
    }

    return chapters
        .map((c) => HtmlChapterSource(
              title: c.title.isEmpty ? '(无标题)' : c.title,
              html: _markdownToHtml(c.body.toString()),
            ))
        .toList();
  }

  /// M4.6-fix4: Markdown 转 HTML，按 CommonMark 标准合并段内换行 +
  /// 移除图片语法（避免 fwfh 网络占位）。
  ///
  /// **历史**：M4.6 (#5) 曾用 `_preserveLineBreaks` 给每行尾部强制补两空格
  /// 让 markdown 视为 hard break → `<br>`。这违反 CommonMark 语义（段内
  /// 单换行渲染时应合并为同段连续流），导致 fwfh 把段落切成断行堆叠 →
  /// 用户看到"第一段在左上、第二段在右下、超出边界"。
  ///
  /// **修复**：直接走 `markdown.markdownToHtml`，让标准库按 CommonMark 处理：
  /// - 段内单换行 → 合并（源码可读性，渲染合并）
  /// - 行尾两空格 / 反斜杠 → hard break（用户显式意图，标准库识别）
  /// - 空行 → 段落分隔
  /// - 标题/列表/引用/代码块 → 结构正确渲染
  ///
  /// 图片移除：fwfh HtmlWidget 默认渲染 `<img>`，但 MD 无 base URL 时 src
  /// 当网络 URL，会显示 loading 占位/异常图标（用户报告"第二章标题变图片"）。
  /// MD 阅读场景无网络/相对路径解析能力，移除 `<img>` 保留 alt 文本是合理
  /// trade-off（让读者知道这里有图但不尝试加载）。
  static String _markdownToHtml(String body) {
    final raw = md.markdownToHtml(body);
    return _stripImages(raw);
  }

  /// M4.6-fix4: 移除 HTML 中所有 `<img>` 标签，保留 alt 文本作为占位。
  ///
  /// markdown 标准库生成的 `<img alt="xxx" src="..." />` 形式固定，
  /// 用正则匹配 `alt="..."` 提取 alt 文本，整张图替换为 `[alt]` 纯文本。
  /// 无 alt（`alt=""`）则替换为空串（不留下占位符干扰排版）。
  ///
  /// 用正则而非 html parser：app 包不直接依赖 `html` 包（仅
  /// flutter_widget_from_html 间接引入），加直接依赖仅为移除 img 太重；
  /// markdown 标准库的 img 输出格式稳定，正则足够。
  static String _stripImages(String html) {
    // 匹配 <img ... alt="xxx" ... /> 或 <img ... />（HTML5 自闭合/非自闭合均覆盖）
    // alt 属性值用 [^"]* 匹配（不处理转义引号，markdown 生成的 alt 不含"）
    return html.replaceAllMapped(
      RegExp(r'<img\b[^>]*?\balt="([^"]*)"[^>]*>'),
      (m) {
        final alt = m.group(1) ?? '';
        return alt.isEmpty ? '' : '[$alt]';
      },
    );
  }

  static String _decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      // 非 UTF-8：降级 latin1（1 字节直映，绝不抛、不乱码占位）。
      return latin1.decode(bytes);
    }
  }
}

/// 解析过程中的临时章节缓冲（title + body 累积）。
class _MdChapter {
  _MdChapter({required this.title, required String body}) : body = StringBuffer(body);
  final String title;
  final StringBuffer body;
}

/// 匹配行首的 `# ` 或 `## `（1-2 个 # 后跟空格）。group(1) = 标题文本。
final RegExp _h1H2Prefix = RegExp(r'^#{1,2}\s+(.*)$');
