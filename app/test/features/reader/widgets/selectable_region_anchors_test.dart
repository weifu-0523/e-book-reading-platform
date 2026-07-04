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

/// M3e/Q5：验证 Flutter 3.44.4 的 `SelectableRegionState.contextMenuAnchors`
/// 在真实选区下返回非零全局坐标（primaryAnchor / secondaryAnchor）。
///
/// **关键事实纠正**：M3b 的 CHANGELOG/注释曾断言「Flutter 3.44.4 的
/// SelectableRegion 不暴露选区坐标，故 _selectionRect 暂时始终 null」。
/// 这是**误判** —— 源码追踪确认：
/// - SelectableRegion 接受 `GlobalKey<SelectableRegionState>`
/// - SelectableRegionState.contextMenuAnchors 返回 TextSelectionToolbarAnchors
///   （primaryAnchor = 选区上方中心全局坐标，secondaryAnchor = 下方中心）
/// - 官方 example selection_area.2.dart 第 157-201 行正是这套用法
///
/// 本测试用 SelectAllTextIntent 触发全选（Flutter 文档推荐方式，见
/// selectable_region.dart:216-220），断言 contextMenuAnchors 非零 →
/// 证明 API 可用，M3e/Q5 的 toolbar 跟随实现成立。
void main() {
  testWidgets(
      'M3e/Q5: SelectableRegion.contextMenuAnchors returns non-zero coords '
      'after select-all (proves API works on Flutter 3.44.4)', (tester) async {
    final regionKey = GlobalKey<SelectableRegionState>();
    final textKey = GlobalKey();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SelectableRegion(
            key: regionKey,
            selectionControls: materialTextSelectionControls,
            focusNode: FocusNode(),
            child: Text(
              '一段可选择的中文文本用于测试选区坐标',
              key: textKey,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    // 触发全选（Flutter 官方推荐的 test 触发方式）。
    final state = regionKey.currentState!;
    await tester.pump();
    final context = textKey.currentContext!;
    Actions.invoke(context, const SelectAllTextIntent(SelectionChangedCause.toolbar));
    await tester.pumpAndSettle();
    // finalize 选区（contextMenuAnchors 依赖 finalized 选区几何）。
    state.selectAll(SelectionChangedCause.toolbar);
    await tester.pumpAndSettle();

    // 读 contextMenuAnchors —— 不应抛异常，且 primaryAnchor 非零。
    final anchors = state.contextMenuAnchors;
    expect(anchors.primaryAnchor, isNot(Offset.zero),
        reason: 'contextMenuAnchors.primaryAnchor 在真实选区下应非零');
    // 选区在屏幕中央，primaryAnchor.y 应 > 0（文本在 viewport 上半部以下）。
    expect(anchors.primaryAnchor.dy, greaterThan(0));
    // secondaryAnchor 通常非空（多行文本时存在）。
    expect(anchors.secondaryAnchor, isNotNull);
  });
}
