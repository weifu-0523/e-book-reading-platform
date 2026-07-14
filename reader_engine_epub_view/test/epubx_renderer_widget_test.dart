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
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

/// 构造一本只有一章假数据的书，给 [EpubxRenderer.bookForTesting] 用。
EpubBook _bookWithSingleChapter(String html) {
  return EpubBook()
    ..Title = 'Test'
    ..Chapters = [
      EpubChapter()
        ..Title = 'Ch1'
        ..HtmlContent = html,
    ];
}

void main() {
  testWidgets('build returns SizedBox.shrink before openFile', (tester) async {
    final renderer = EpubxRenderer();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: renderer.build(context),
          ),
        ),
      ),
    );
    expect(find.byType(SizedBox), findsOneWidget);
    await renderer.dispose();
  });

  testWidgets(
    'paged mode renders a PageView once a chapter is available',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithSingleChapter(
        List.filled(40, '<p>${'hello world ' * 30}</p>').join(),
      );
      // 2026-07-08 tuning: 默认改 scroll，这里显式切回 paged 验证 paged 渲染。
      await renderer.setPaginationMode(PaginationMode.paged);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: Builder(
                builder: (context) => renderer.build(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // _paginationMode == PaginationMode.paged → 应当出现 PageView。
      expect(find.byType(PageView), findsOneWidget);
      // 2026-07-08 BUG 1: paged 模式每页内容由 SelectablePageView + Text.rich 渲染
      // （外层 SelectionArea 接管 selection，让 onSelectionChanged 触发，修复
      // 用户报告的"选正文不弹工具条"BUG）。Text.rich 内部渲染为 RichText。
      expect(find.byType(RichText), findsWidgets,
          reason: 'paged pages should render Text.rich (→RichText) content');
      expect(tester.takeException(), isNull,
          reason: 'paged pages must not overflow');
      await renderer.dispose();
    },
  );

  testWidgets('scroll mode renders SingleChildScrollView', (tester) async {
    final renderer = EpubxRenderer();
    renderer.bookForTesting = _bookWithSingleChapter(
      '<p>hello world</p>',
    );
    await renderer.setPaginationMode(PaginationMode.scroll);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: Builder(
              builder: (context) => renderer.build(context),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    await renderer.dispose();
  });

  testWidgets('switching pagination mode rebuilds the tree', (tester) async {
    final renderer = EpubxRenderer();
    renderer.bookForTesting = _bookWithSingleChapter(
      List.filled(40, '<p>${'hello world ' * 30}</p>').join(),
    );

    Widget tree() => MaterialApp(
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

    // 2026-07-08 tuning: 默认改 scroll，这里显式切 paged 模拟"切换前"状态。
    await renderer.setPaginationMode(PaginationMode.paged);
    await tester.pumpWidget(tree());
    await tester.pump();
    expect(find.byType(PageView), findsOneWidget);

    // 切到 scroll —— setPaginationMode 写字段后，由父级 setState 重建 widget tree
    // （生产环境里 ReaderPage 调 setState；这里我们直接重新 pumpWidget 模拟重建）。
    await renderer.setPaginationMode(PaginationMode.scroll);
    await tester.pumpWidget(tree());
    await tester.pump();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(PageView), findsNothing);

    await renderer.dispose();
  });
}
