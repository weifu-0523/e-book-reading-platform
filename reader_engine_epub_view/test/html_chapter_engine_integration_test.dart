// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors.
//
// M4.5 集成测试：验证 Markdown / TXT 经 HtmlChapterSource →
// ConcreteEpubReaderEngine.openChapters → build 的完整渲染链路。
//
// 这条链路覆盖用户打开 .md/.txt 书后的真实路径：加载器把文件转章节源，
// 引擎复用 EPUB 的 Paginator/HtmlSlicer/HtmlWidget 管道渲染。测试确认
// MD/TXT 能复用 EPUB 全部能力（状态机、TOC、章节切换、纯文本提取）。
//
// 注：build 渲染的精确文本匹配依赖 fwfh 内部行为（RichText 包裹），故
// build 测试只验证「不抛异常 + 渲染出 RichText」，不匹配具体文本。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';
import 'package:reader_engine_epub_view/html_chapter_source.dart';

void main() {
  Widget tree(Widget child) => MaterialApp(
        home: Scaffold(body: child),
      );

  group('M4.5: ConcreteEpubReaderEngine.openChapters (MD/TXT 路径)', () {
    test('openChapters 后状态机进入 Ready', () async {
      final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
      await engine.openChapters(
        const [HtmlChapterSource(title: '测试章', html: '<p>内容</p>')],
        title: 'test',
      );
      expect(engine.state, isA<ReaderEngineReady>());
      await engine.close();
    });

    test('空章节列表进入 Error 状态（不抛给调用方）', () async {
      final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
      await engine.openChapters(const [], title: 'empty');
      expect(engine.state, isA<ReaderEngineError>());
      await engine.close();
    });

    test('MD 多章节：TOC 含全部章节（扁平，无子节点）', () async {
      final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
      await engine.openChapters(
        const [
          HtmlChapterSource(title: '第一章', html: '<p>第一章正文</p>'),
          HtmlChapterSource(title: '第二章', html: '<p>第二章正文</p>'),
          HtmlChapterSource(title: '第三章', html: '<p>第三章正文</p>'),
        ],
        title: 'md-book',
      );
      final toc = await engine.toc;
      expect(toc, isNotNull);
      expect(toc!.entries.length, 3);
      expect(toc.entries[0].title, '第一章');
      expect(toc.entries[1].title, '第二章');
      expect(toc.entries[2].title, '第三章');
      await engine.close();
    });

    testWidgets('MD 章节：build 渲染不抛异常 + 产出 RichText', (tester) async {
      final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
      await engine.openChapters(
        const [
          HtmlChapterSource(title: 'T', html: '<p>富<b>文本</b>内容</p>'),
        ],
        title: 'md',
      );
      await tester.pumpWidget(tree(Builder(builder: engine.build)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // fwfh 把 HTML 渲染成 RichText（不是 Text），故用 byType。
      expect(find.byType(RichText), findsWidgets);
      expect(tester.takeException(), isNull);
      // 不调 close()：close() 内 controller.close() + sub.cancel() 在测试
      // binding 下与 broadcast stream 时序有冲突会悬挂；引擎随测试销毁即可。
    });

    test('TXT 单章：nextSpine 不抛异常', () async {
      final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
      await engine.openChapters(
        const [HtmlChapterSource(title: '全文', html: '<p>整篇内容</p>')],
        title: 'txt-book',
      );
      // 单章 nextSpine 应是 no-op（不抛 RangeError）。不 await 章节相关
      // postFrame（测试无 widget 帧调度，会悬挂）；只验证不抛。
      expect(() => engine.nextSpine(), returnsNormally);
    });

    test('MD 章节：currentChapterPlainText 返回纯文本（HTML 标签已剥离）',
        () async {
      final r = EpubxRenderer();
      await r.openChapters(
        const [
          HtmlChapterSource(title: 'T', html: '<p>富<b>文本</b>内容</p>'),
        ],
        title: 'md',
      );
      // 直接测 renderer 的 currentChapterPlainText（不经 engine 的 stream 桥接，
      // 避免测试 binding 下 broadcast 时序悬挂）。
      final plain = await r.currentChapterPlainText;
      expect(plain, contains('富'));
      expect(plain, contains('文本'));
      expect(plain, contains('内容'));
      expect(plain, isNot(contains('<b>')));
      expect(plain, isNot(contains('</p>')));
      await r.dispose();
    });
  });

  group('M4.5: EpubxRenderer 直接 openChapters', () {
    test('openChapters 填充 _chapters，book 保持 null（TOC 走扁平分支）',
        () async {
      final r = EpubxRenderer();
      await r.openChapters(
        const [
          HtmlChapterSource(title: 'C1', html: '<p>x</p>'),
          HtmlChapterSource(title: 'C2', html: '<p>y</p>'),
        ],
        title: 't',
      );
      expect(r.state, isA<ReaderEngineReady>());
      expect(r.book, isNull); // MD/TXT 路径无 epubx book
      expect(r.chapterCount, 2);
      expect(r.flatChapterTitleAt(0), 'C1');
      expect(r.flatChapterHtmlAt(1), '<p>y</p>');
      // TOC 走扁平分支（_book == null）
      final toc = await r.toc;
      expect(toc, isNotNull);
      expect(toc!.entries.length, 2);
      await r.dispose();
    });
  });
}
