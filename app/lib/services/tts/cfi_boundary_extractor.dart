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
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:reader_engine_epub_view/cfi_codec.dart';
import 'sentence_segmenter.dart';

/// 章节段落 CFI 边界提取器（T12）。
///
/// 给定一章的纯文本（来自 [ReaderEngine.currentChapterPlainText]）与
/// 章节索引，计算每个段落的 CFI 范围 + 字符 offset 范围，供
/// [SentenceSegmenter.split] 给每句打上「所属段落的 CFI」标签。
///
/// 上游约定（HtmlToInlineSpanConverter）：
/// 章节纯文本的段落之间由 `\n\n` 分隔。但 TXT/Markdown 加载器（与未来
/// 可能接入的纯文本流）只保证 `\n` 分隔。为与 [SentenceSegmenter] 的
/// 游标扫描（把任意 `\n` 当段落边界）保持一致，本提取器把任意 `\n+`
/// 视为单一段落分隔符，并过滤空段（与 segmenter 跳过空白段落对齐）。
///
/// 输出坐标系：与传入的 `chapterPlainText` 完全一致，可直接喂给
/// [SentenceSegmenter.split] 的 `paragraphCharSpans` 参数。
///
/// CFI 格式：本项目的简化 CFI `<chapterIndex>:<charOffset>`（见
/// `reader_engine_epub_view/lib/cfi_codec.dart`），并非 EPUB CFI 规范。
/// 调用方（T13 高亮覆盖层、T15 自动翻页）拿到 CFI 后通过
/// `engine.gotoLocator(EpubCfiLocator(cfi: ..., chapterIndex: ...))` 跳转。
///
/// 纯函数 + 无 Flutter 依赖 → 单测极快、可直接在 widget/integration test
/// 中调用。
class CFIBoundaryExtractor {
  const CFIBoundaryExtractor._();

  /// 提取段落 CFI 范围与字符 offset 范围。
  ///
  /// - [chapterPlainText]：当前章节的纯文本（与
  ///   `ReaderEngine.currentChapterPlainText` 同源）。
  /// - [chapterIndex]：当前章节索引（与 `EpubCfiLocator.chapterIndex` 同源）。
  ///   必须非负；上游若不能保证（如 reader_engine 跨 book-switch race 时
  ///   `_currentChapterIndex` 短暂为 -1），调用方应跳过本次提取而非传 -1。
  ///
  /// 返回 [ParagraphBoundaries]：`cfiRanges[i]` 与 `charSpans[i]` 一一对应。
  /// 空文本 / 全空白文本 → 两个 list 都为空。
  static ParagraphBoundaries extract({
    required String chapterPlainText,
    required int chapterIndex,
  }) {
    if (chapterIndex < 0) {
      throw ArgumentError(
        'chapterIndex must be non-negative: $chapterIndex. '
        'Caller should skip extraction when index is unknown.',
      );
    }

    if (chapterPlainText.isEmpty) {
      return const ParagraphBoundaries(cfiRanges: [], charSpans: []);
    }

    final cfiRanges = <ParagraphCfiRange>[];
    final charSpans = <ParagraphCharSpan>[];

    var i = 0;
    final n = chapterPlainText.length;
    while (i < n) {
      // 跳过分隔符（任意 `\n`，对齐 segmenter 游标行为）。
      while (i < n && chapterPlainText.codeUnitAt(i) == 0x0A /* \n */) {
        i++;
      }
      if (i >= n) break;

      final start = i;
      // 推进到下一个 `\n`（段落末尾，不包含）。
      while (i < n && chapterPlainText.codeUnitAt(i) != 0x0A) {
        i++;
      }
      final end = i;

      // 过滤空白段（与 segmenter 跳过空白对齐；converter 不会产生空白段，
      // 但 TXT 加载器或防御性输入可能含）。
      var hasNonWhitespace = false;
      for (var j = start; j < end; j++) {
        final cu = chapterPlainText.codeUnitAt(j);
        if (cu != 0x20 /* space */ &&
            cu != 0x09 /* \t */ &&
            cu != 0x0D /* \r */) {
          hasNonWhitespace = true;
          break;
        }
      }
      if (!hasNonWhitespace) continue;

      charSpans.add((start: start, end: end));
      cfiRanges.add((
        startCfi: encode(chapterIndex, start),
        endCfi: encode(chapterIndex, end),
      ));
    }

    return ParagraphBoundaries(cfiRanges: cfiRanges, charSpans: charSpans);
  }
}

/// [CFIBoundaryExtractor.extract] 的返回包。
///
/// `cfiRanges[i]` 与 `charSpans[i]` 一一对应：第 i 个段落的 CFI 范围与
/// 字符 offset 范围。两个 list 长度恒等（含 0）。
class ParagraphBoundaries {
  final List<ParagraphCfiRange> cfiRanges;
  final List<ParagraphCharSpan> charSpans;

  const ParagraphBoundaries({
    required this.cfiRanges,
    required this.charSpans,
  });
}
