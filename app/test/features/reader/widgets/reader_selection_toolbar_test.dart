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
import 'package:zhiyue/features/reader/widgets/highlight_selection_controls.dart';
import 'package:zhiyue/features/reader/widgets/reader_selection_toolbar.dart';

void main() {
  group('ReaderSelectionToolbar', () {
    testWidgets('renders nothing when selection is null', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Text('underlying content'),
              ReaderSelectionToolbar(
                selection: null,
                onExcerpt: () {},
                onCopy: () {},
                onAiComment: () {},
              ),
            ],
          ),
        ),
      ));
      expect(find.byType(HighlightSelectionControls), findsNothing);
    });

    testWidgets('renders nothing when selection plainText is empty',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Text('underlying content'),
              ReaderSelectionToolbar(
                selection: const SelectedContent(plainText: ''),
                onExcerpt: () {},
                onCopy: () {},
                onAiComment: () {},
              ),
            ],
          ),
        ),
      ));
      expect(find.byType(HighlightSelectionControls), findsNothing);
    });

    testWidgets('renders HighlightSelectionControls when selection non-empty',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Stack(
              children: [
                const Text('underlying content'),
                ReaderSelectionToolbar(
                  selection: const SelectedContent(plainText: 'highlighted text'),
                  onExcerpt: () {},
                  onCopy: () {},
                  onAiComment: () {},
                ),
              ],
            ),
          ),
        ),
      ));
      expect(find.byType(HighlightSelectionControls), findsOneWidget);
    });

    testWidgets('fires onExcerpt callback when controls invoke it',
        (tester) async {
      var excerptCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Stack(
              children: [
                ReaderSelectionToolbar(
                  selection: const SelectedContent(plainText: 'text'),
                  onExcerpt: () => excerptCount++,
                  onCopy: () {},
                  onAiComment: () {},
                ),
              ],
            ),
          ),
        ),
      ));
      final controls = tester.widget<HighlightSelectionControls>(
        find.byType(HighlightSelectionControls),
      );
      controls.onExcerpt();
      expect(excerptCount, 1);
    });

    // M3b/任务9：工具条跟随选区定位。以下用直接传入 Rect 验证 Positioned
    // 逻辑（不依赖真实 selection 坐标源，符合 plan Test Strategy）。

    testWidgets(
        'M3b: with selectionRect positions toolbar ABOVE the selection',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Stack(
              children: [
                ReaderSelectionToolbar(
                  selection: const SelectedContent(plainText: 'sel'),
                  // 选区在中下部，上方空间充足 → 应放选区上方。
                  // 期望 top = 300 - 48 - 8 = 244；left = 400 - 110 = 290。
                  selectionRect: const Rect.fromLTWH(300, 300, 200, 30),
                  stackSize: const Size(800, 600),
                  onExcerpt: () {},
                  onCopy: () {},
                ),
              ],
            ),
          ),
        ),
      ));
      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(HighlightSelectionControls),
          matching: find.byType(Positioned),
        ),
      );
      expect(positioned.top, 244.0);
      expect(positioned.left, 290.0);
      expect(positioned.right, isNull); // 跟随模式用 left，不用 right
    });

    testWidgets(
        'M3b: flips toolbar BELOW selection when not enough room above',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Stack(
              children: [
                ReaderSelectionToolbar(
                  selection: const SelectedContent(plainText: 'sel'),
                  // 选区靠顶：rect.top=20 → top=20-48-8=-36 < 8 → 翻到下方。
                  // 期望 top = rect.bottom + 8 = (20+30) + 8 = 58。
                  selectionRect: const Rect.fromLTWH(300, 20, 200, 30),
                  stackSize: const Size(800, 600),
                  onExcerpt: () {},
                  onCopy: () {},
                ),
              ],
            ),
          ),
        ),
      ));
      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(HighlightSelectionControls),
          matching: find.byType(Positioned),
        ),
      );
      expect(positioned.top, 58.0);
    });

    testWidgets('M3b: clamps toolbar left within screen bounds',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Stack(
              children: [
                ReaderSelectionToolbar(
                  selection: const SelectedContent(plainText: 'sel'),
                  // 选区中心 dx = 50 → left = 50-110 = -60 → clamp 到 8。
                  selectionRect: const Rect.fromLTWH(0, 300, 100, 30),
                  stackSize: const Size(800, 600),
                  onExcerpt: () {},
                  onCopy: () {},
                ),
              ],
            ),
          ),
        ),
      ));
      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(HighlightSelectionControls),
          matching: find.byType(Positioned),
        ),
      );
      expect(positioned.left, 8.0);
    });

    testWidgets('M3b: clamps toolbar right within screen bounds',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Stack(
              children: [
                ReaderSelectionToolbar(
                  selection: const SelectedContent(plainText: 'sel'),
                  // 选区中心 dx = 790 → left = 790-110 = 680；
                  // maxLeft = 800-220-8 = 572 → clamp 到 572。
                  selectionRect: const Rect.fromLTWH(740, 300, 100, 30),
                  stackSize: const Size(800, 600),
                  onExcerpt: () {},
                  onCopy: () {},
                ),
              ],
            ),
          ),
        ),
      ));
      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(HighlightSelectionControls),
          matching: find.byType(Positioned),
        ),
      );
      expect(positioned.left, 572.0);
    });

    testWidgets(
        'M3b: null selectionRect falls back to top-center (no crash)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Stack(
              children: [
                ReaderSelectionToolbar(
                  selection: const SelectedContent(plainText: 'sel'),
                  // 不传 selectionRect → fallback 顶部居中（原行为）。
                  onExcerpt: () {},
                  onCopy: () {},
                ),
              ],
            ),
          ),
        ),
      ));
      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(HighlightSelectionControls),
          matching: find.byType(Positioned),
        ),
      );
      expect(positioned.top, 80.0);
      expect(positioned.left, 16.0);
      expect(positioned.right, 16.0); // fallback 用 left+right 居中
    });
  });
}
