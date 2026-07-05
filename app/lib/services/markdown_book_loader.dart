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

  /// M4.6 (#5): Markdown 转 HTML，保留段落内可见换行。
  ///
  /// **根因**：markdown 包（7.3.1）按 CommonMark 规范，段落内单个 `\n`（soft
  /// break）渲染时折叠成空格（不是 `<br>`），导致连续行堆叠成一行。只有
  /// 行尾两个空格或反斜杠才是 hard break → `<br>`。
  ///
  /// **修复**：调 `markdownToHtml` 前预处理——给每个非空、非代码块、非已有
  /// hard break 的行尾补两个空格，强制 markdown 视为 hard break。代码块
  /// （` ``` `/`~~~` 围栏）内行原样保留，避免破坏代码格式。
  ///
  /// `LineSplitExtension` 在 markdown 7.x 不存在（已核对 export），故用
  /// 预处理方案。
  static String _markdownToHtml(String body) {
    return md.markdownToHtml(_preserveLineBreaks(body));
  }

  /// 给 body 的每行尾部补两空格，强制 hard break。跳过：
  /// - 空行（保留原样）
  /// - 围栏代码块内的行（` ``` ` 或 `~~~` 包裹区域）
  /// - 缩进式代码块（行首 ≥4 空格）
  /// - 已有 hard break 的行（行尾已有 ≥2 空格或反斜杠）
  /// - 标题行（`#` ~ `######`）
  /// - 列表项（`- ` / `* ` / `+ ` / `1. `）
  /// - 引用块（`> `）
  /// - HTML 块（行首 `<`）
  /// - 水平分割线（`---` / `***` / `___`）
  ///
  /// M4.6-fix (#3)：原跳过规则过窄，列表项/引用块等结构行被补两空格后，
  /// markdown 在 `<li>`/`<blockquote>` 内生成多余 `<br>`，破坏排版。
  static String _preserveLineBreaks(String body) {
    final lines = body.split('\n');
    bool inFence = false;
    String? fenceMarker;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedRight = line.replaceFirst(RegExp(r'\s*$'), '');
      // 围栏检测：行首（允许最多 3 空格缩进）后跟 ``` 或 ~~~
      final fenceMatch = RegExp(r'^\s{0,3}(```|~~~)').firstMatch(trimmedRight);
      if (fenceMatch != null) {
        final marker = fenceMatch.group(1)!;
        if (!inFence) {
          inFence = true;
          fenceMarker = marker;
        } else if (marker == fenceMarker) {
          inFence = false;
          fenceMarker = null;
        }
        // 围栏行本身不加空格
        continue;
      }
      if (inFence) continue; // 围栏代码块内行原样
      if (trimmedRight.isEmpty) continue; // 空行
      // 已有 hard break（≥2 尾空格 或 反斜杠结尾）
      if (RegExp(r' {2,}$').hasMatch(line)) continue;
      if (trimmedRight.endsWith(r'\')) continue;
      // M4.6-fix: 跳过所有 markdown 结构行（补两空格会破坏它们的渲染）
      if (_isStructuralLine(trimmedRight)) continue;
      // 补两空格（仅普通段落正文行）
      lines[i] = '$trimmedRight  ';
    }
    return lines.join('\n');
  }

  /// M4.6-fix (#3): 判断是否为 markdown 结构行（不应补两空格）。
  /// 这些行的 inline 内容补两空格后，markdown 会在 `<li>`/`<blockquote>`
  /// 等容器内生成多余 `<br>`，破坏排版。
  static bool _isStructuralLine(String trimmedRight) {
    // 标题（# ~ ######）
    if (RegExp(r'^#{1,6}\s').hasMatch(trimmedRight)) return true;
    // 缩进式代码块（行首 ≥4 空格）
    if (RegExp(r'^    ').hasMatch(trimmedRight)) return true;
    // 列表项：`- ` / `* ` / `+ ` / `1. `（允许最多 3 空格缩进）
    if (RegExp(r'^\s{0,3}([-*+]\s|\d+\.\s)').hasMatch(trimmedRight)) return true;
    // 引用块：`> ` / `>`（允许最多 3 空格缩进）
    if (RegExp(r'^\s{0,3}>').hasMatch(trimmedRight)) return true;
    // HTML 块（行首 <，如 <div> <img> <!--）
    if (RegExp(r'^\s*<').hasMatch(trimmedRight)) return true;
    // 水平分割线：`---` / `***` / `___`（≥3 个相同字符，允许最多 3 空格缩进）
    if (RegExp(r'^\s{0,3}([-]{3,}|[*]{3,}|[_]{3,})\s*$').hasMatch(trimmedRight)) {
      return true;
    }
    // 参考式链接定义：`[id]: url`
    if (RegExp(r'^\[([^\]]+)\]:\s').hasMatch(trimmedRight)) return true;
    return false;
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
