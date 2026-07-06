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
/// **渲染（M4.6-fix10/A2 重写）**：每章 body **不再用 markdown 标准库**，
/// 改为仿 [TextBookLoader] 的"每行独立成 `<p>`"技术逻辑——
///
/// 历史反复（fix2/3/5/7/9 共 5 次失败的共同元凶）：
/// 旧实现用 `package:markdown/markdownToHtml()` 把 body 转 HTML，fix7 加
/// `_forceVisibleLineBreaks`（每行尾补两空格）→ markdown 标准库识别为 hard
/// break → 产出 `<br>`。但 Paginator 按 plain text 字符偏移测高，`<br>` 不
/// 增加偏移却增加视觉高度 → 测出来"很矮"、实际渲染"很高" → 一页塞太多 →
/// 内容溢出页面边界、段落被切到页中。
///
/// 对照实验证据（test 跑出来的 HTML 对比）：
///   输入「第一点\n第二点\n第三点\n第四点」
///   TXT 产出：4 个独立 `<p>`（无 `<br>`）→ Paginator 测准 → 正常
///   MD 产出 ：1 个 `<p>` 内含 3 个 `<br>` → Paginator 测偏 → 溢出
///
/// 修复方案（用户决策"按 TXT 技术逻辑"）：每行 trim 后独立成 `<p>`，与 TXT
/// 完全同构。**轻量保留行内语法**：`**粗体**`→`<strong>`、`*斜体*`/`_斜体_`
/// →`<em>`、`` `代码` ``→`<code>`、`[text](url)`→`text`（剥离链接保留文本）。
/// 围栏代码块内的行不做行内替换（用 `inFence` 状态机识别 ` ``` `/`~~~ `）。
/// 标题行 `#`/`##` 已在切章阶段处理，body 内不含 → 无需特殊处理。
/// 列表项 `- `/`* `/`1. ` 原样成 `<p>`（前缀保留，视觉上仍能看出是列表）。
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
        html: _markdownBodyToHtml(single),
      )];
    }

    return chapters
        .map((c) => HtmlChapterSource(
              title: c.title.isEmpty ? '(无标题)' : c.title,
              html: _markdownBodyToHtml(c.body.toString()),
            ))
        .toList();
  }

  /// M4.6-fix10/A2: 把 MD 每章 body 转成 HTML（仿 TXT 每行成 `<p>`）。
  ///
  /// 与 [TextBookLoader.parseText] 同构：
  /// - 按 `\n` 分行 → 每行 trim → 空行跳过 → 每行独立成 `<p>...</p>`
  /// - 不同点：MD 行内轻量保留 `**粗体**` 等语法（[_inlineMarkdownToHtml]）
  /// - 围栏代码块（` ``` `/`~~~ `）内的行不做行内替换，原样转义
  ///
  /// 这样产出与 TXT 同构的 `<p>...</p><p>...</p>...`，Paginator 按 plain
  /// text 偏移测高精准，paged + 双页翻页正常。
  static String _markdownBodyToHtml(String body) {
    if (body.trim().isEmpty) return '<p></p>';

    final lines = body.split('\n');
    final buf = StringBuffer();
    bool inFence = false;
    String? fenceMarker;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue; // 空行作分隔符，跳过

      // 围栏代码块检测（``` 或 ~~~，行首允许 0-3 空格已被 trim 吃掉）
      final fenceMatch = RegExp(r'^(`{3,}|~{3,})').firstMatch(line);
      if (fenceMatch != null) {
        final marker = fenceMatch.group(1)![0]; // '`' 或 '~'
        if (!inFence) {
          inFence = true;
          fenceMarker = marker;
          // 围栏行本身作为 `<p>` 输出（视觉上保留代码块边界）
          buf.write('<p>${_escapeHtml(line)}</p>');
          continue;
        } else if (marker == fenceMarker) {
          inFence = false;
          fenceMarker = null;
          buf.write('<p>${_escapeHtml(line)}</p>');
          continue;
        }
      }

      if (inFence) {
        // 围栏内：原样转义成 `<p>`，不做行内语法替换
        buf.write('<p>${_escapeHtml(line)}</p>');
        continue;
      }

      // 普通行：先 HTML 转义，再做行内 markdown 语法替换
      final escaped = _escapeHtml(line);
      final inlined = _inlineMarkdownToHtml(escaped);
      buf.write('<p>$inlined</p>');
    }

    final result = buf.toString();
    return result.isEmpty ? '<p></p>' : result;
  }

  /// M4.6-fix10/A2: 行内 markdown 语法 → HTML（轻量保留）。
  ///
  /// 输入应为**已 HTML 转义**的字符串（`<`/`>`/`&` 已转义）。
  /// 处理顺序：先代码 span（保护内容不被后续替换），再粗体，再斜体，最后链接。
  ///
  /// 支持的语法：
  /// - `` `code` `` → `<code>code</code>`（内容不做后续替换）
  /// - `**text**` → `<strong>text</strong>`
  /// - `*text*` 或 `_text_` → `<em>text</em>`
  /// - `[text](url)` → `text`（剥离链接 URL，保留文本）
  ///
  /// 不处理：图片 `![alt](url)`（MD 文档少见；保留原样文本即可）、
  /// 删除线 `~~text~~`、引用、标题（标题在切章阶段已处理）。
  static String _inlineMarkdownToHtml(String s) {
    var result = s;

    // 1. 先处理 `code`（用占位符保护内容，避免被后续 * / ** 误伤）
    final codePlaceholders = <String>[];
    result = result.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (m) {
        final code = m.group(1)!;
        final placeholder = '\x00CODE${codePlaceholders.length}\x00';
        codePlaceholders.add(code);
        return placeholder;
      },
    );

    // 2. 粗体 **text** 或 __text__
    result = result.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*|__([^_]+)__'),
      (m) {
        final text = m.group(1) ?? m.group(2)!;
        return '<strong>$text</strong>';
      },
    );

    // 3. 斜体 *text* 或 _text_（单个 * 或 _ 包裹）
    //    注意：粗体已处理，此处 * 不会再成对出现在 ** 内
    result = result.replaceAllMapped(
      RegExp(r'\*([^*]+)\*|_([^_]+)_'),
      (m) {
        final text = m.group(1) ?? m.group(2)!;
        return '<em>$text</em>';
      },
    );

    // 4. 链接 [text](url) → text（剥离 URL）
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1)!,
    );

    // 5. 还原 code 占位符
    for (var i = 0; i < codePlaceholders.length; i++) {
      result = result.replaceAll(
        '\x00CODE$i\x00',
        '<code>${codePlaceholders[i]}</code>',
      );
    }

    return result;
  }

  static String _decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      // 非 UTF-8：降级 latin1（1 字节直映，绝不抛、不乱码占位）。
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

/// 解析过程中的临时章节缓冲（title + body 累积）。
class _MdChapter {
  _MdChapter({required this.title, required String body}) : body = StringBuffer(body);
  final String title;
  final StringBuffer body;
}

/// 匹配行首的 `# ` 或 `## `（1-2 个 # 后跟空格）。group(1) = 标题文本。
final RegExp _h1H2Prefix = RegExp(r'^#{1,2}\s+(.*)$');
