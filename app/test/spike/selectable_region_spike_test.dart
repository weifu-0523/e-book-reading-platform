// T1 spike: 验证 SelectableRegion 包裹 HtmlWidget 后能拿到 SelectedContent。
//
// 已知陷阱（本测试解决）：
// 1) HtmlWidget 渲染为单个 RichText，没有 Text widget 子节点 → 不能用 find.text('活')。
// 2) SelectedContent 字段在 Flutter 3.27 SDK 中叫 plainText（不是 plainContent）。
// 3) timedDrag 是单次 pan，不会触发长按选择；必须用 startGesture + 长 hold + moveBy。
// 4) gesture 起点必须落在 RichText 首字符 hit-box 内（用 topLeft + 小偏移）。
//
// 结果：PASS → M3.2 高亮方案 A（SelectableRegion + HtmlWidget）可行。

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

void main() {
  testWidgets('SelectableRegion wraps HtmlWidget and yields SelectedContent',
      (tester) async {
    // 固定视口，避免 RichText 仅 20px 高度时 getCenter 落在边界外。
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SelectedContent? captured;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SelectableRegion(
            selectionControls: materialTextSelectionControls,
            onSelectionChanged: (c) => captured = c,
            child: const HtmlWidget('<p>活着本身就是意义</p>'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // HtmlWidget 渲染为单个 RichText；用 RichText 锚定手势起点。
    final richText = find.byType(RichText);
    expect(richText, findsOneWidget);
    // 起点 = RichText 左上角 + 小偏移，确保落在首字符 hit-box 内（center 在某些
    // 行高下落到字符间空白导致 hit-test 不触发 selection）。
    final topLeft = tester.getTopLeft(richText);
    final start = topLeft + const Offset(20, 10);

    // 长按 + 拖拽 = 选区手势（timedDrag 不触发长按选择，需手动 hold）。
    final gesture = await tester.startGesture(start, pointer: 7);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(150, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    // 验证 captured 不为 null 且 plainText 含选中片段
    expect(captured, isNotNull,
        reason: 'SelectableRegion 必须能从 HtmlWidget 收到选区');
    expect(captured!.plainText, isNotEmpty, reason: 'plainText 非空');
  });
}
