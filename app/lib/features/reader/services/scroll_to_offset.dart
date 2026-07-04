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

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

/// Scrolls a [Scrollable] to make the character at [targetOffset] visible.
///
/// Two modes:
/// - **scroll**: single [SingleChildScrollView] holding the whole chapter.
///   Collect all [RenderParagraph]s, accumulate text lengths to find owner,
///   compute caret via `getOffsetForCaret`, animate to that y.
/// - **paged**: [PageView] where each page is one viewport-sized [Text].
///   Find the page whose break range contains [targetOffset] and jumpToPage.
///   No in-page scroll (page IS viewport; target is naturally visible).
///
/// [targetOffset] is in the same plainText coordinate space as
/// `ReaderEngine.currentChapterPlainText` (post-T0 unification).
class ScrollToOffsetService {
  static Future<void> scrollToCharacterOffset({
    // M2.10/Bug B1（真根因）：paged 分支只用 pageController + pageBreaks，
    // 根本不读 scrollable。scrollable 只在 scroll 分支（_scrollInScrollView）
    // 需要。原 `required` 签名迫使调用方传一个非空 ScrollableState，但
    // reader_body 的 context 拿不到 PageView/SingleChildScrollView 的
    // Scrollable（它们是 engine.build() 内的后代，Scrollable.maybeOf 往上
    // 找祖先返回 null）→ 旧调用方 `if (scrollable == null) return;` 总提前
    // 退出 → 跳转从未执行。改为可选：paged 模式可不传；scroll 模式必须传。
    required int targetOffset,
    required PaginationMode paginationMode,
    ScrollableState? scrollable,
    List<PageBreak> pageBreaks = const [],
    PageController? pageController,
    // M2.10/Bug B1: 双页模式下 PageController.page 是 spread 索引（PageView
    // 的 itemCount = (breaks.length + 1) ~/ 2），而 _findPageForOffset 返回的
    // 是 break 索引（单页模式下 = 页号）。不换算则 jumpToPage(breakIdx) 在
    // breakIdx >= spreadCount 时抛 'PageController.page cannot be greater than
    // itemCount' assertion → 笔记/摘录跳转崩溃，即使不越界也会跳错 spread。
    // 调用方从 engine.dualPageMode 读取传入。默认 false 保持旧契约不破。
    bool dualPageMode = false,
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    if (paginationMode == PaginationMode.scroll) {
      // scroll 分支必须传 scrollable。
      if (scrollable == null) {
        throw ArgumentError(
            'scrollable is required when paginationMode is scroll');
      }
      await _scrollInScrollView(
        scrollable: scrollable,
        targetOffset: targetOffset,
        duration: duration,
      );
      return;
    }

    // paged mode
    if (pageController == null) {
      throw ArgumentError(
          'pageController is required when paginationMode is paged');
    }
    if (pageBreaks.isEmpty) return;

    final breakIdx = _findPageForOffset(pageBreaks, targetOffset);
    // M2.10/Bug B1: 双页模式下 spread[i] = breaks[i*2] (左) + breaks[i*2+1] (右)，
    // 反推 spread 索引 = breakIdx ~/ 2。单页模式 spread 索引 = breakIdx 本身。
    final targetPage = dualPageMode ? breakIdx ~/ 2 : breakIdx;
    pageController.jumpToPage(targetPage);
  }

  static int _findPageForOffset(List<PageBreak> breaks, int offset) {
    for (var i = 0; i < breaks.length; i++) {
      if (breaks[i].endOffset > offset) return i;
    }
    return breaks.length - 1;
  }

  static Future<void> _scrollInScrollView({
    required ScrollableState scrollable,
    required int targetOffset,
    required Duration duration,
  }) async {
    final scrollRenderObj = scrollable.context.findRenderObject();
    if (scrollRenderObj == null) return;

    final paragraphs = _collectRenderParagraphs(scrollRenderObj);
    if (paragraphs.isEmpty) return;

    int cumulative = 0;
    RenderParagraph? owner;
    int localOffset = 0;
    for (final p in paragraphs) {
      final len = p.text.toPlainText().length;
      if (cumulative + len > targetOffset) {
        owner = p;
        localOffset = targetOffset - cumulative;
        break;
      }
      cumulative += len;
    }
    if (owner == null) return;

    final caretLocal = owner.getOffsetForCaret(
      TextPosition(offset: localOffset),
      Rect.zero,
    );
    final transform = owner.getTransformTo(scrollRenderObj);
    final caretInScroll = MatrixUtils.transformPoint(transform, caretLocal);

    await scrollable.position.animateTo(
      caretInScroll.dy,
      duration: duration,
      curve: Curves.easeInOut,
    );
  }

  static List<RenderParagraph> _collectRenderParagraphs(RenderObject root) {
    final result = <RenderParagraph>[];
    void visit(RenderObject obj) {
      if (obj is RenderParagraph) result.add(obj);
      obj.visitChildren(visit);
    }
    visit(root);
    return result;
  }
}
