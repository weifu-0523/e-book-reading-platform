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
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/widgets/reader_selection_toolbar.dart';

/// M3e/Q5：验证 ReaderSelectionToolbar 在有 selectionRect 时跟随选区定位。
///
/// 这套测试聚焦 toolbar 的定位数学（已由 M3b 的 9 cases 覆盖），M3e/Q5
/// 新增的是「selectionRect 从 null 变为真实坐标后 toolbar 位置随之改变」
/// 的契约。选区坐标的来源（SelectableRegionState.contextMenuAnchors）
/// 在 reader_body._updateSelectionRectFromAnchors 里填充，是 Flutter 框架
/// API（依赖真实选区几何），难以在 widget test 里纯净触发，故这里用
/// 注入的 selectionRect 验证 toolbar 端的契约：rect 变化 → top 跟随。
void main() {
  const sel = SelectedContent(plainText: '选中文本');

  testWidgets(
      'M3e/Q5: toolbar top follows selectionRect.top (above selection)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          ReaderSelectionToolbar(
            selection: sel,
            // 选区在 y=300，toolbar 应在其上方（300 - 48 - 8 = 244）。
            selectionRect: const Rect.fromLTWH(100, 300, 200, 40),
            stackSize: const Size(800, 600),
            onExcerpt: () {},
            onCopy: () {},
          ),
        ]),
      ),
    ));
    // toolbar 是 Positioned，断言其 top 不再是 fallback 的 80，
    // 而是跟随选区上方（244 附近）。
    final positioned = tester.widget<Positioned>(find.byType(Positioned).first);
    expect(positioned.top, isNot(80));
    expect(positioned.top, lessThan(300),
        reason: 'toolbar 应在选区上方（top < selectionRect.top）');
  });

  testWidgets(
      'M3e/Q5: toolbar flips below when selectionRect near top',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          ReaderSelectionToolbar(
            selection: sel,
            // 选区在 y=20（顶部空间不足 48+8），toolbar 翻到下方（20+40+8=68）。
            selectionRect: const Rect.fromLTWH(100, 20, 200, 40),
            stackSize: const Size(800, 600),
            onExcerpt: () {},
            onCopy: () {},
          ),
        ]),
      ),
    ));
    final positioned = tester.widget<Positioned>(find.byType(Positioned).first);
    expect(positioned.top, greaterThan(20),
        reason: '空间不足时 toolbar 翻到选区下方（top > selectionRect.top）');
  });

  testWidgets(
      'M3e/Q5: selectionRect null → fallback top=80 (no follow)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          ReaderSelectionToolbar(
            selection: sel,
            // 不传 selectionRect → 走 fallback 顶部居中（与旧行为一致）。
            onExcerpt: () {},
            onCopy: () {},
          ),
        ]),
      ),
    ));
    final positioned = tester.widget<Positioned>(find.byType(Positioned).first);
    expect(positioned.top, 80,
        reason: '无选区坐标时 toolbar 固定顶部 80（fallback）');
  });
}
