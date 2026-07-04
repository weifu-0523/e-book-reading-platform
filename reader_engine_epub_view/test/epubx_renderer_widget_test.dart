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
    'default mode (paged) renders a PageView once a chapter is available',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithSingleChapter(
        List.filled(40, '<p>${'hello world ' * 30}</p>').join(),
      );
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
      // 默认 _paginationMode == PaginationMode.paged → 应当出现 PageView。
      expect(find.byType(PageView), findsOneWidget);
      // M2.10/Bug A: paged 模式每页内容现在包在 SingleChildScrollView 里
      // （NeverScrollableScrollPhysics）以吸收 HtmlWidget 与 TextPainter 的高度
      // 误差，避免 RenderFlex bottom-overflow assertion（黄黑斑马线）。这与
      // scroll 模式的 SingleChildScrollView 区别在于：paged 的子页 physics 锁死
      // NeverScrollable，不挂 ScrollController，仅作 overflow 兜底。
      // 旧断言（findsNothing）是 M2.9 之前的契约，Bug A 修复后失效。
      final pagedScrollables = tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(pagedScrollables, isNotEmpty,
          reason: 'paged pages must be wrapped in SingleChildScrollView '
              '(M2.10/Bug A overflow absorption)');
      for (final sv in pagedScrollables) {
        expect(sv.controller, isNull,
            reason: 'paged scrollable must not bind a ScrollController '
                '(unlike scroll mode which binds _scrollController)');
      }
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

    // 默认 paged。
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
