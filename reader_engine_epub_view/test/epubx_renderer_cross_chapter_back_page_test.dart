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

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

/// M2.8/B2 regression (Bug #6 cross-chapter back-paging).
///
/// Pins the Kindle / 微信读书 contract: 章首左翻换上一章时停在上一章**末页**，
/// 而不是首页。Pre-fix 的 `previousPage()` 直接 `_previousChapterIfPossible()`
/// → `setChapter(idx-1)` → `jumpToPage(0)`，用户视觉上"左翻直接跳到上一章
/// 首页"，与右翻（章末换下一章首页）不对称、与主流阅读器不一致。
///
/// 实现要点：[EpubxRenderer.previousPage] 在调 `_previousChapterIfPossible`
/// 后 arm `_pendingJumpToLastPage`；下一帧 `_buildPaged` 的 LayoutBuilder 重跑
/// 算出新章节分页、写入 `_cachedBreaks` 后立刻调
/// `_maybeApplyPendingLastPageJump`，把 PageController 拉到末页（one-shot）。
EpubBook _bookWithTwoLongChapters() {
  return EpubBook()
    ..Title = 'Test'
    ..Chapters = [
      EpubChapter()
        ..Title = 'Ch1'
        ..HtmlContent = List.filled(40, '<p>${'chapter one ' * 30}</p>').join(),
      EpubChapter()
        ..Title = 'Ch2'
        ..HtmlContent = List.filled(40, '<p>${'chapter two ' * 30}</p>').join(),
    ];
}

Widget _tree(EpubxRenderer renderer) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: Builder(
            builder: (context) => renderer.build(context),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'previousPage at chapter-start jumps to previous chapter LAST page',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithTwoLongChapters();
      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      // Sanity: chapter 0 has multiple pages.
      final chapter0Breaks = renderer.currentChapterPageBreaks;
      expect(chapter0Breaks.length, greaterThan(1),
          reason: 'test fixture: chapter 0 must produce >1 page');
      final lastPageCh0 = chapter0Breaks.length - 1;

      // Move to chapter 1, page 0 (simulates chapter-end forward paging).
      renderer.setChapter(1);
      await tester.pumpWidget(_tree(renderer));
      await tester.pump();
      expect(renderer.currentChapterIndex, 1);
      expect(renderer.pageController!.page!.round(), 0);

      // THE CONTRACT: previousPage at chapter-1 page 0 → chapter 0 LAST page.
      final switched = renderer.previousPage();
      expect(switched, isTrue, reason: 'previousPage must report a switch');
      expect(renderer.currentChapterIndex, 0,
          reason: 'previousPage must switch back to chapter 0');
      // Re-pump to let LayoutBuilder re-paginate chapter 0 and apply the
      // pending last-page jump.
      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      expect(
        renderer.pageController!.page!.round(),
        lastPageCh0,
        reason: 'M2.8/B2: chapter-start back-page must land on the previous '
            'chapter\'s LAST page ($lastPageCh0), not page 0. Pre-fix it jumped '
            'to page 0, leaving the user "back at the chapter start" — '
            'asymmetric with forward paging and inconsistent with Kindle / '
            '微信读书.',
      );

      await renderer.dispose();
    },
  );

  testWidgets(
    'forward nextPage at chapter-end does NOT arm last-page jump (lands on next chapter page 0)',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithTwoLongChapters();
      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      // Jump chapter 0 to its last page, then forward-page to chapter 1.
      final lastPageCh0 = renderer.currentChapterPageBreaks.length - 1;
      renderer.pageController!.jumpToPage(lastPageCh0);
      await tester.pump();

      final switched = renderer.nextPage();
      expect(switched, isTrue);
      expect(renderer.currentChapterIndex, 1);
      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      // Forward paging must land on chapter 1 page 0 (NOT its last page).
      expect(renderer.pageController!.page!.round(), 0,
          reason: 'forward chapter-end paging must not arm the last-page '
              'jump — only previousPage does. If this fails, the '
              '_pendingJumpToLastPage flag is leaking across nextPage.');

      await renderer.dispose();
    },
  );

  testWidgets(
    'setChapter (TOC tap / bookmark jump) does NOT arm last-page jump',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithTwoLongChapters();
      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      // Direct setChapter simulates TOC tap / bookmark jump / annotation tap.
      renderer.setChapter(1);
      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      expect(renderer.pageController!.page!.round(), 0,
          reason: 'setChapter called from non-previousPage paths must land on '
              'page 0. The pending-jump flag is armed only by previousPage; '
              'setChapter clears it to prevent stale arms from other paths.');

      await renderer.dispose();
    },
  );
}
