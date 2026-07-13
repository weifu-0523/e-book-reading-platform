// SPDX-License-Identifier-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/widgets/reader_scaffold.dart';

/// v1.11.6-alpha 修复：手机竖屏（width < 600）下 chrome AppBar 按钮堆叠。
///
/// 现状：leading 4 个 IconButton（固定 leadingWidth=192）+ actions 8-9 个
/// IconButton（每个 48px），最小占 ~600px，窄屏必然溢出，用户感知「堆叠」。
///
/// 修复：compact 模式下用 `SingleChildScrollView(horizontal: true) + Row`
/// 替代 AppBar 三段布局，所有按钮排成一行可左右拖动。medium/expanded 模式
/// 保持现有 AppBar 不变。
void main() {
  testWidgets(
      'compact viewport (360dp): chrome is horizontally scrollable, '
      'last button off-screen by default and revealed after drag',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            marginPx: 32,
            onTapPrev: () {},
            onTapNext: () {},
            // 给所有按钮都接上回调，确保它们都渲染（非 null 才挂载）。
            onOpenToc: () {},
            onOpenTypography: () {},
            onOpenNotes: () {},
            onToggleAiDrawer: () {},
            onAddBookmark: () {},
            onTogglePaginationMode: () {},
            onFontDecrease: () {},
            onFontIncrease: () {},
            onOpenBookshelf: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 找到 chrome 中横向可滚动的 Scrollable。
    final scrollableFinder = find.descendant(
      of: find.byKey(const Key('reader_app_bar')),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Scrollable &&
            w.axisDirection == AxisDirection.right,
      ),
    );
    expect(scrollableFinder, findsOneWidget,
        reason: 'compact 模式下 chrome 应该用横向 SingleChildScrollView');

    // 全屏按钮（key=toggle_fullscreen）是 actions 区最后一个按钮，
    // 默认应该在视口右侧外（off-screen）。
    final fullscreenFinder = find.byKey(const Key('toggle_fullscreen'));
    expect(fullscreenFinder, findsOneWidget);

    final viewportWidth = 360.0;
    final initialRect =
        tester.getRect(fullscreenFinder);
    expect(initialRect.right, greaterThan(viewportWidth),
        reason: '全屏按钮默认应该在视口外（右侧），需要拖动才能看到');

    // 横向 drag 左滑 300px，让滚动条露出右侧按钮。
    await tester.drag(scrollableFinder, const Offset(-300, 0));
    await tester.pumpAndSettle();

    final afterDragRect = tester.getRect(fullscreenFinder);
    expect(afterDragRect.right, lessThanOrEqualTo(viewportWidth + 1),
        reason: 'drag 后全屏按钮应该完全进入视口');
  });

  testWidgets(
      'medium viewport (800dp): chrome keeps AppBar layout, no horizontal scrollable',
      (tester) async {
    // 默认 800x600 视口，属于 medium（600 ≤ width < 840）。
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            marginPx: 32,
            onTapPrev: () {},
            onTapNext: () {},
            onOpenToc: () {},
            onOpenTypography: () {},
            onOpenNotes: () {},
            onToggleAiDrawer: () {},
            onAddBookmark: () {},
            onTogglePaginationMode: () {},
            onFontDecrease: () {},
            onFontIncrease: () {},
            onOpenBookshelf: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // medium 模式应该走 AppBar 分支，不存在横向 Scrollable。
    final horizontalScrollable = find.descendant(
      of: find.byKey(const Key('reader_app_bar')),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Scrollable &&
            w.axisDirection == AxisDirection.right,
      ),
    );
    expect(horizontalScrollable, findsNothing,
        reason: 'medium/expanded 模式保持现有 AppBar，无需横向滚动');

    // 全屏按钮在 medium 模式下默认就在屏内（800dp 足够）。
    final fullscreenFinder = find.byKey(const Key('toggle_fullscreen'));
    expect(fullscreenFinder, findsOneWidget);
    final rect = tester.getRect(fullscreenFinder);
    expect(rect.right, lessThanOrEqualTo(800),
        reason: 'medium 模式下全屏按钮应该在屏内');
  });
}
