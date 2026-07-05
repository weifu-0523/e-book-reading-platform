// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors.
//
// M4.6-fix4 PDF widget 稳定化回归测试。
//
// 修复前：build 用 FutureBuilder 包裹 PdfViewer，每次父级 rebuild 都重建
// widget tree → pdfrx 频繁 reload → 翻 N 页后内存压力 → loading 卡死。
//
// 修复后：
// - build 不再用 FutureBuilder（scanned 判定走 openFile 时启动 + setState）
// - build 顶层包 RepaintBoundary
// - PdfViewer 加 ValueKey（同书 State 复用稳定）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_pdf_view/pdf_renderer.dart';

void main() {
  group('M4.6-fix4 PdfRenderer widget 稳定性', () {
    testWidgets('build 不再使用 FutureBuilder（稳定化重构）',
        (tester) async {
      final r = PdfRenderer();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) => r.build(context)),
          ),
        ),
      );
      // M4.6-fix4：移除 FutureBuilder，scanned 判定改走 openFile + setState。
      // 验证 widget tree 中没有 FutureBuilder（哪怕 doc == null）。
      expect(find.byType(FutureBuilder), findsNothing);
      await r.dispose();
    });

    testWidgets('build 多次调用稳定（doc==null 路径幂等）', (tester) async {
      final r = PdfRenderer();
      // 模拟父级频繁 rebuild（用户滚动/翻页触发）：连续 pumpWidget 5 次。
      for (var i = 0; i < 5; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(builder: (context) => r.build(context)),
            ),
          ),
        );
      }
      // 不抛异常即通过。修复前每次 build 都 FutureBuilder + PdfViewerParams
      // 重建，频繁 rebuild 会触发 pdfrx reload。重构后 build 走同步分支。
      expect(r.doc, isNull);
      await r.dispose();
    });

    test('PdfRenderer 是普通类（StatelessWidget 风格 build），可重复 build',
        () {
      // 验证 PdfRenderer.build 是幂等的：多次调用返回 widget，不抛异常，
      // 不依赖 FutureBuilder 状态。
      final r = PdfRenderer();
      // builder 拿不到 context 时用 createElement 不现实，直接验证 doc == null
      // 分支（build 不需要 InheritedWidget 即可返回 SizedBox.shrink）。
      // 通过 widget test pump 验证（见上面 testWidgets）。
      expect(r.doc, isNull);
      expect(r.pageCount, 0);
      expect(r.isScanned, false); // _scannedCache == null ?? false == false
      expect(r.dualPageMode, false);
    });

    test('isScanned getter 在 _scannedCache 为 null 时返回 false（保守降级）',
        () {
      final r = PdfRenderer();
      // 重构后 _scannedCache 在 openFile 重置为 null，未判定完成时
      // isScanned getter 应返回 false（保守降级单页），不应抛异常。
      expect(r.isScanned, false);
    });
  });
}
