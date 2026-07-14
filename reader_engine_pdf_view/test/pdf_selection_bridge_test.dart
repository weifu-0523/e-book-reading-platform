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
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';
import 'package:reader_engine_pdf_view/pdf_selection_bridge.dart';

void main() {
  group('PdfSelectionBridge.fromSelection', () {
    test('null selectedText returns null', () {
      final result = PdfSelectionBridge.fromSelection(
        selectedText: null,
        page: 5,
      );
      expect(result, isNull);
    });

    test('empty selectedText returns null', () {
      final result = PdfSelectionBridge.fromSelection(
        selectedText: '',
        page: 5,
      );
      expect(result, isNull);
    });

    test('non-empty text produces HighlightSelection; chapterIndex == page', () {
      final result = PdfSelectionBridge.fromSelection(
        selectedText: 'quoted text',
        page: 5,
      );
      expect(result, isNotNull);
      expect(result!.text, 'quoted text');
      // PDF 没有 chapter 概念，复用 chapterIndex 字段存 1-based 页码（与
      // PdfPageLocator 一致），上层 highlight 持久化时使用 toPdfRangeLocator 转换。
      expect(result.chapterIndex, 5);
      expect(result.startOffset, 0);
      expect(result.endOffset, 'quoted text'.length);
    });

    test('startOffset/endOffset reflect selectedText length', () {
      final result = PdfSelectionBridge.fromSelection(
        selectedText: 'abc',
        page: 2,
      );
      expect(result, isNotNull);
      expect(result!.startOffset, 0);
      expect(result.endOffset, 3);
    });
  });

  group('PdfSelectionBridge.toPdfRangeLocator', () {
    test('converts HighlightSelection with same page/quote', () {
      final sel = PdfSelectionBridge.fromSelection(
        selectedText: 'hello',
        page: 7,
      )!;
      final loc = PdfSelectionBridge.toPdfRangeLocator(sel);
      expect(loc, isA<PdfRangeLocator>());
      expect(loc.page, 7);
      expect(loc.startOffset, 0);
      expect(loc.endOffset, 5);
      expect(loc.quote, 'hello');
    });

    test('PdfRangeLocator asserts page >= 1', () {
      // fromSelection 不校验 page，但 PdfRangeLocator 构造器会断言；
      // 这是 caller 责任，bridge 仅保证 quote/offset 一致。
      final sel = HighlightSelection(
        text: 'x',
        chapterIndex: 0,
        startOffset: 0,
        endOffset: 1,
      );
      expect(
        () => PdfSelectionBridge.toPdfRangeLocator(sel),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  testWidgets('buildHighlightButton invokes callback on tap', (tester) async {
    HighlightSelection? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfSelectionBridge.buildHighlightButton(
            selectedText: 'hi',
            page: 3,
            onHighlight: (s) => captured = s,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.text, 'hi');
    expect(captured!.chapterIndex, 3);
  });

  testWidgets('buildHighlightButton null selectedText disables the button',
      (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfSelectionBridge.buildHighlightButton(
            selectedText: null,
            page: 1,
            onHighlight: (_) => tapCount++,
          ),
        ),
      ),
    );
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
  });
}
