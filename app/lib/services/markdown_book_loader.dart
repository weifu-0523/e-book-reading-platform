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

  /// M4.6-fix7: Markdown 转 HTML，保留段内每行可见换行（源码即所见）+
  /// 移除图片语法（避免 fwfh 网络占位）。
  ///
  /// **用户需求**（fix7 重新理解）：MD 文档源码里的换行都应该是可见的
  /// 视觉换行——「一段原格式有很多行」期望每行都独立显示，不是合并成
  /// 一行。这与 CommonMark 默认（段内单换行渲染时合并为空格）相反。
  ///
  /// **历史反复**：
  /// - M4.6 (#5)：加 `_preserveLineBreaks` 强制 hard break，但跳过规则
  ///   过窄（列表/引用等结构行被误处理），排版乱。
  /// - M4.6-fix4：误以为应回归 CommonMark 标准，删除强制 break。结果
  ///   段内多行被合并成一行，违反用户期望。
  /// - M4.6-fix7（本版）：保留每行可见，但**简化**预处理——所有非空、
  ///   非结构行（标题/代码块围栏）都补两空格强制 hard break。结构行
  ///   （列表/引用/标题/HR）的内部换行由 markdown 标准库自管，不干预。
  ///
  /// **关键洞察**：M4.6 (#5) 失败不是「保留换行」错了，而是跳过规则不
  /// 完整导致结构行被破坏。fix7 简化：只对**纯文本段内行**补两空格，
  /// 不动任何 markdown 结构语法行。
  static String _markdownToHtml(String body) {
    final raw = md.markdownToHtml(_forceVisibleLineBreaks(body));
    return _stripImages(raw);
  }

  /// M4.6-fix7: 给段内每个非空非结构行的尾部补两空格，强制 markdown 视为
  /// hard break → `<br>`。
  ///
  /// 跳过规则（这些行不补两空格，由 markdown 标准库处理）：
  /// - 空行（段落分隔）
  /// - 围栏代码块内的行（` ``` ` / `~~~` 包裹区域）
  /// - 围栏代码块本身（行首 0-3 空格 + 围栏标记）
  /// - 标题行（`#` ~ `######`）
  /// - 缩进式代码块（行首 ≥4 空格）
  /// - 列表项（`- ` / `* ` / `+ ` / `1. `）
  /// - 引用块（`> `）
  /// - HTML 块（行首 `<`）
  /// - 水平分割线（`---` / `***` / `___`）
  /// - 参考式链接定义（`[id]: url`）
  /// - 已有 hard break 的行（行尾已 ≥2 空格或反斜杠）
  ///
  /// 普通段落正文行：补两空格 → markdown 视为 hard break → `<br>`。
  /// 这样「一段五行」会渲染成 5 个可见行（4 个 `<br>`），符合用户期望。
  static String _forceVisibleLineBreaks(String body) {
    final lines = body.split('\n');
    bool inFence = false;
    String? fenceMarker;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedRight = line.replaceFirst(RegExp(r'\s*$'), '');
      // 围栏代码块：检测进入/退出
      final fenceMatch =
          RegExp(r'^\s{0,3}(```|~~~)').firstMatch(trimmedRight);
      if (fenceMatch != null) {
        final marker = fenceMatch.group(1)!;
        if (!inFence) {
          inFence = true;
          fenceMarker = marker;
        } else if (marker == fenceMarker) {
          inFence = false;
          fenceMarker = null;
        }
        continue; // 围栏行本身不补空格
      }
      if (inFence) continue; // 围栏内行原样
      if (trimmedRight.isEmpty) continue; // 空行
      // 已有 hard break
      if (RegExp(r' {2,}$').hasMatch(line)) continue;
      if (trimmedRight.endsWith(r'\')) continue;
      // 结构行不补（让 markdown 标准库处理）
      if (_isStructuralLine(trimmedRight)) continue;
      // 普通段落正文行：补两空格强制 hard break
      lines[i] = '$trimmedRight  ';
    }
    return lines.join('\n');
  }

  /// M4.6-fix7: 判断是否为 markdown 结构行（不应补两空格）。
  /// 这些行的语义由 markdown 标准库解析，补两空格会破坏它们的渲染。
  static bool _isStructuralLine(String trimmedRight) {
    // 标题（# ~ ######）
    if (RegExp(r'^#{1,6}\s').hasMatch(trimmedRight)) return true;
    // 缩进式代码块（行首 ≥4 空格）
    if (RegExp(r'^    ').hasMatch(trimmedRight)) return true;
    // 列表项
    if (RegExp(r'^\s{0,3}([-*+]\s|\d+\.\s)').hasMatch(trimmedRight)) return true;
    // 引用块
    if (RegExp(r'^\s{0,3}>').hasMatch(trimmedRight)) return true;
    // HTML 块
    if (RegExp(r'^\s*<').hasMatch(trimmedRight)) return true;
    // 水平分割线
    if (RegExp(r'^\s{0,3}([-]{3,}|[*]{3,}|[_]{3,})\s*$')
        .hasMatch(trimmedRight)) {
      return true;
    }
    // 参考式链接定义
    if (RegExp(r'^\[([^\]]+)\]:\s').hasMatch(trimmedRight)) return true;
    return false;
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
