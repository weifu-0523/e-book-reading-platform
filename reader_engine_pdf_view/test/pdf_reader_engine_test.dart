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

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/book_ref.dart' as re;
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_renderer.dart';

void main() {
  group('PdfReaderEngine Page-as-Chapter', () {
    test('currentChapterPageBreaks is empty (no paged mode for PDF)', () {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      expect(e.currentChapterPageBreaks, isEmpty);
    });

    test('pageController is null (pdfrx manages scroll)', () {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      expect(e.pageController, isNull);
    });

    test('chapterSwitchSettled resolves immediately', () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      await e.chapterSwitchSettled.timeout(const Duration(seconds: 1));
    });

    test('currentChapterPlainText returns empty string', () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      expect(await e.currentChapterPlainText, '');
    });

    test('paginationMode is always scroll', () {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      expect(e.paginationMode, PaginationMode.scroll);
    });

    test('setPaginationMode is noop (does not throw)', () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      await e.setPaginationMode(PaginationMode.paged);
      expect(e.paginationMode, PaginationMode.scroll);
    });

    test('setTypography stores typography but does not throw', () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      final t = TypographySettings.defaults();
      await e.setTypography(t);
      expect(e.typography, t);
    });

    test('nextSpine / previousSpine are no-ops without doc (do not throw)',
        () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      await e.nextSpine();
      await e.previousSpine();
      // No assertion — just verifying no exception
    });
  });

  // M4/Q-TOC: 目录永远转圈 bug 的回归测试。
  //
  // 根因：PdfReaderEngine.toc 旧实现 `get toc => null` 永远返回 null，
  // 而 reader_drawer_builders.dart 用 `if (toc == null) LoadingView()`
  // 同步判定 —— PDF 目录 tab 因此永久转圈。PdfRenderer.toc（异步、真正
  // 调 loadOutline）从未被调用。修复：open() 里 await _renderer.toc 并
  // 缓存到 _toc，getter 返回 _toc。
  group('PdfReaderEngine.toc (目录转圈 bug 回归)', () {
    test('未 open 时 toc 为 null（UI 显示 LoadingView 转圈）', () {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      expect(e.toc, isNull,
          reason: 'open 之前 _toc 未填充，应为 null（驱动 LoadingView）');
    });

    test(
        'open 完成（即便失败）后 toc 非 null —— 永不卡在转圈状态',
        () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      // 用不存在的文件路径：openFile 会进 ReaderEngineError，但 PdfRenderer.toc
      // 在 doc==null 时返回 TableOfContents.empty()（非 null）。关键断言：
      // 不管 open 成功还是失败，_toc 必须被赋一个非 null 值。
      await e.open(re.BookRef(
        id: 'test',
        title: 'missing',
        format: re.BookFormat.pdf,
        filePath: '/nonexistent/missing.pdf',
      ));
      expect(e.state, isA<ReaderEngineError>(),
          reason: '不存在的文件应进入 error 状态');
      expect(e.toc, isNotNull,
          reason: '修复前：toc getter 永远返回 null → 目录 tab 永久转圈。'
              '修复后：open 后 _toc 必非 null（即便 loadOutline 失败也是 empty TOC）');
      expect(e.toc, isA<TableOfContents>());
      expect(e.toc!.entries, isEmpty,
          reason: '失败/无书签的 PDF 应为空 TOC → UI 显示「本书无目录」而非转圈');
      await e.close();
    });
  });
}

