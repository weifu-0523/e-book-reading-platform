// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine_epub_view/paginator.dart';

/// M3e/Q8 regression: 分页后"文字多时末行不溢出页面底部"。
///
/// 根因：旧 `Paginator._paginateUncached` 测量高度时漏算了 3 项渲染层
/// 实际会产生的高度：(1) 段落 margin 0.5em × 段数、(2) 首行缩进 em-space
/// 让首行变窄多换 1 行、(3) 无安全冗余。导致测量 < 实际 → 分页塞过多内容
/// → 渲染时末行被裁。
///
/// 修复后：测量层把段间距 + 缩进前缀 + 1 行 safety margin 都计入，每页
/// 内容高度严格 ≤ 可用高度。本测试用大量长段落验证：分页数足够多、
/// 没有单页塞入超过容量。
void main() {
  const viewport = Size(400, 600);
  final typography = TypographySettings.defaults();

  double _measureTotalPlainHeight(String plainConcat, double usableWidth) {
    // 用与 Paginator 同样的 TextPainter 基准测「纯文本+缩进」总高度，
    // 作为渲染高度的近似下界（fwfh 实际高度只会 ≥ 此值，因还有段间距）。
    final style = TextStyle(fontSize: typography.fontSize, height: typography.lineHeight);
    final prefix = String.fromCharCodes(
      List.filled(typography.paragraphIndentEm.truncate(), 0x2003),
    );
    final tp = TextPainter(
      text: TextSpan(text: '$prefix$plainConcat', style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: usableWidth);
    final h = tp.height;
    tp.dispose();
    return h;
  }

  test(
    'Q8: many long paragraphs paginate into enough pages (not under-paginated)',
    () {
      // 60 段，每段约 300 字（中文长段落，典型"文字比较多"场景）。
      final buf = StringBuffer();
      for (var i = 0; i < 60; i++) {
        buf.write('<p>${'这是一段比较长的中文正文内容用于测试分页。' * 10}</p>');
      }
      final html = buf.toString();

      final result = Paginator().paginateWithText(
        chapterHtml: html,
        viewport: viewport,
        typography: typography,
        marginPx: 48, // 默认 wide margin
      );
      final breaks = result.breaks;

      // 至少分多页（旧 bug 可能页数偏少 = 每页过满）。
      expect(breaks.length, greaterThan(3),
          reason: '60 段长内容至少分 4+ 页；若 <4 说明分页过粗（单页过满）');

      // 断言连续性。
      for (var i = 0; i < breaks.length - 1; i++) {
        expect(breaks[i].endOffset, breaks[i + 1].startOffset);
      }
      expect(breaks.last.endOffset, result.plainText.length);
    },
  );

  test(
    'Q8: every page content height (text+indent) fits within usable height '
    'with margin accounted',
    () {
      // 构造 30 段，每段中等长度。
      final buf = StringBuffer();
      for (var i = 0; i < 30; i++) {
        buf.write('<p>段落 $i：${'中文正文测试。' * 15}</p>');
      }
      final html = buf.toString();
      const marginPx = 48.0;
      final usableHeight = viewport.height - 2 * marginPx;
      final usableWidth = (viewport.width - 2 * marginPx).clamp(50.0, double.infinity);

      final result = Paginator().paginateWithText(
        chapterHtml: html,
        viewport: viewport,
        typography: typography,
        marginPx: marginPx,
      );
      final plain = result.plainText;

      // 对每页，取其 plain 子串（不含缩进前缀），用与 Paginator 相同的
      // TextPainter 测量纯文本高度。渲染层实际高度 = 纯文本高度 + 段间距 +
      // 缩进首行多换的行 → 测出的纯文本高度 ≤ 实际高度。所以若纯文本高度
      // 都 ≤ usableHeight，再加上修复里补的 gap+safety，渲染层必不溢出。
      for (var i = 0; i < result.breaks.length; i++) {
        final pb = result.breaks[i];
        final pagePlain = plain.substring(
          pb.startOffset.clamp(0, plain.length),
          pb.endOffset.clamp(0, plain.length),
        );
        final h = _measureTotalPlainHeight(pagePlain, usableWidth);
        expect(
          h,
          lessThanOrEqualTo(usableHeight + 1.0),
          reason: '页 $i 纯文本高度 $h 超过可用高度 $usableHeight（page 会溢出底部）',
        );
      }
    },
  );

  test('Q8: indent disabled still paginates without overflow', () {
    final buf = StringBuffer();
    for (var i = 0; i < 40; i++) {
      buf.write('<p>${'无缩进段落正文测试。' * 12}</p>');
    }
    final html = buf.toString();
    final noIndent = typography.copyWith(paragraphIndentEnabled: false);

    final result = Paginator().paginateWithText(
      chapterHtml: html,
      viewport: viewport,
      typography: noIndent,
      marginPx: 72,
    );
    expect(result.breaks.length, greaterThan(2));
    expect(result.breaks.last.endOffset, result.plainText.length);
  });
}
