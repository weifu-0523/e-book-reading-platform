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
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';
import 'package:reader_engine_pdf_view/pdf_selection_bridge.dart';
import 'package:zhiyue/features/reader/pages/reader_page.dart';

/// T12: reader_page PDF fallback 单测。
///
/// widget test 成本高（需要 PdfReaderEngine + 真实 PDF 文件 + pdfrx 渲染），
/// 这里只测抽出来的纯函数 [chapterOrPageLabel] / [estimateProgressPercent]
/// 以及 [PdfSelectionBridge.toPdfRangeLocator] 的端到端协作。
/// 完整 reader_page → PDF 集成测试留到 T14（用真实 PDF fixtures）。
void main() {
  group('chapterOrPageLabel', () {
    test('PDF: returns "第 N 页" from PdfPageLocator (1-based)', () {
      const loc = PdfPageLocator(page: 5, offsetX: 0, offsetY: 0);
      expect(chapterOrPageLabel(loc), '第 5 页');
    });

    test('PDF: page 1 returns "第 1 页"', () {
      const loc = PdfPageLocator(page: 1, offsetX: 0, offsetY: 0);
      expect(chapterOrPageLabel(loc), '第 1 页');
    });

    test('EPUB: returns chapterTitle from EpubCfiLocator when present', () {
      const loc = EpubCfiLocator(
        cfi: '/6/4',
        chapterIndex: 2,
        chapterTitle: '第三章 春',
      );
      expect(chapterOrPageLabel(loc), '第三章 春');
    });

    test('EPUB: returns null when chapterTitle is null', () {
      const loc = EpubCfiLocator(cfi: '/6/4', chapterIndex: 0);
      expect(chapterOrPageLabel(loc), isNull);
    });

    test('null locator returns null', () {
      expect(chapterOrPageLabel(null), isNull);
    });
  });

  group('estimateProgressPercent', () {
    test('PDF: page/total clamp to [0,1]', () {
      const loc = PdfPageLocator(page: 5, offsetX: 0, offsetY: 0);
      expect(estimateProgressPercent(loc, pdfPageCount: 20), closeTo(0.25, 1e-9));
    });

    test('PDF: first page returns 1/total', () {
      const loc = PdfPageLocator(page: 1, offsetX: 0, offsetY: 0);
      expect(estimateProgressPercent(loc, pdfPageCount: 10), closeTo(0.1, 1e-9));
    });

    test('PDF: last page returns 1.0', () {
      const loc = PdfPageLocator(page: 10, offsetX: 0, offsetY: 0);
      expect(estimateProgressPercent(loc, pdfPageCount: 10), 1.0);
    });

    test('PDF: pageCount missing returns 0 (avoid divide-by-zero)', () {
      const loc = PdfPageLocator(page: 5, offsetX: 0, offsetY: 0);
      expect(estimateProgressPercent(loc), 0.0);
      expect(estimateProgressPercent(loc, pdfPageCount: 0), 0.0);
      expect(estimateProgressPercent(loc, pdfPageCount: null), 0.0);
    });

    test('EPUB: chapterIndex/100 clamp', () {
      const loc = EpubCfiLocator(cfi: '/6/4', chapterIndex: 3);
      expect(estimateProgressPercent(loc), closeTo(0.03, 1e-9));
    });

    test('EPUB: ignores pdfPageCount parameter', () {
      const loc = EpubCfiLocator(cfi: '/6/4', chapterIndex: 5);
      expect(estimateProgressPercent(loc, pdfPageCount: 999),
          closeTo(0.05, 1e-9));
    });

    test('null locator returns 0', () {
      expect(estimateProgressPercent(null), 0.0);
    });
  });

  group('PDF selection → PdfRangeLocator pipeline', () {
    test('HighlightSelection round-trips through toPdfRangeLocator', () {
      // 模拟 PdfSelectionBridge.fromSelection 构造的 selection：
      // chapterIndex 字段被复用为 pdfrx 1-based page。
      const sel = HighlightSelection(
        text: '选中文本',
        chapterIndex: 7,
        startOffset: 0,
        endOffset: 4,
      );
      final loc = PdfSelectionBridge.toPdfRangeLocator(sel);
      expect(loc.page, 7);
      expect(loc.startOffset, 0);
      expect(loc.endOffset, 4);
      expect(loc.quote, '选中文本');
    });

    test('toPdfRangeLocator preserves page semantics for reader_page storage',
        () {
      // 端到端：模拟 reader_page._onPdfHighlight 调用顺序。
      const sel = HighlightSelection(
        text: 'PDF 高亮文本',
        chapterIndex: 3,
        startOffset: 0,
        endOffset: 6,
      );
      final locator = PdfSelectionBridge.toPdfRangeLocator(sel);
      // NotesController.addHighlight 现在接受任意 Locator；PdfRangeLocator
      // 是 Locator 子类，可以无障碍传入。
      expect(locator, isA<Locator>());
      expect(locator.toJson()['type'], 'pdfRange');
    });
  });
}
