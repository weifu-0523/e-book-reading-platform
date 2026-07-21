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

/// v1.14.2-alpha 决定性验证：emptySelectionContextMenu 真的能禁用 Flutter 默认
/// selection context menu（AdaptiveTextSelectionToolbar 白色长条卡）。
///
/// v1.14.1-alpha 只改了 selectionControls 但没禁用 contextMenuBuilder，导致
/// 用户报告"卡片还在"。本测试做正反两组验证：
///  1. 默认 SelectionArea（不传 contextMenuBuilder）→ 长按选中后 AdaptiveTextSelectionToolbar 出现
///  2. 传 emptySelectionContextMenu 的 SelectionArea → 长按选中后 AdaptiveTextSelectionToolbar 不出现
///
/// 这样能在 widget 层面证明 fix 有效，避免再次"说修了没修好"。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/src/no_selection_toolbar.dart';

void main() {
  testWidgets(
      'v1.14.2-alpha: SelectionArea with emptySelectionContextMenu does NOT show AdaptiveTextSelectionToolbar',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SelectionArea(
            contextMenuBuilder: emptySelectionContextMenu,
            child: const Text('活着本身就是意义'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 长按 + 拖拽 = 选区手势（spike/selectable_region_spike_test.dart 模式）
    final richText = find.byType(RichText);
    expect(richText, findsOneWidget);
    final topLeft = tester.getTopLeft(richText);
    final start = topLeft + const Offset(20, 10);

    final gesture = await tester.startGesture(start, pointer: 7);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(150, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    // 决定性断言：默认 context menu 不应出现
    expect(
      find.byType(AdaptiveTextSelectionToolbar),
      findsNothing,
      reason: 'v1.14.2-alpha：传 emptySelectionContextMenu 后 '
          'AdaptiveTextSelectionToolbar（白色长条卡）不应显示。',
    );
    // 额外检查：TextSelectionToolbar（Material sub-widget）也不应出现
    expect(
      find.byType(TextSelectionToolbar),
      findsNothing,
      reason: 'Material 风格 TextSelectionToolbar 也不应显示。',
    );
  });

  testWidgets(
      'control group: default SelectionArea DOES show AdaptiveTextSelectionToolbar',
      (tester) async {
    // 这个对照组验证测试 harness 本身能触发 toolbar（如果 harness 错了，
    // 上面的"禁用"测试可能是 false negative）。如果未来 Flutter 框架行为
    // 变化导致默认 SelectionArea 不再弹 toolbar，这个测试会 FAIL 提醒我们
    // 重新评估 emptySelectionContextMenu 的必要性。
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SelectionArea(
            // 不传 contextMenuBuilder，用默认 _defaultContextMenuBuilder
            child: const Text('活着本身就是意义'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final richText = find.byType(RichText);
    final topLeft = tester.getTopLeft(richText);
    final start = topLeft + const Offset(20, 10);

    final gesture = await tester.startGesture(start, pointer: 7);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(150, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    // 对照组：默认行为应该弹 toolbar（如果这个 FAIL，说明 harness 不触发 toolbar，
    // 上面的禁用测试就失去了对照意义）。
    final hasAdaptiveToolbar =
        find.byType(AdaptiveTextSelectionToolbar).evaluate().isNotEmpty;
    final hasMaterialToolbar =
        find.byType(TextSelectionToolbar).evaluate().isNotEmpty;
    expect(
      hasAdaptiveToolbar || hasMaterialToolbar,
      isTrue,
      reason: '对照组：默认 SelectionArea 应该弹 toolbar。如果这个 FAIL，'
          '说明测试 harness 没有触发 toolbar，上面禁用测试可能是 false negative。',
    );
  });
}
