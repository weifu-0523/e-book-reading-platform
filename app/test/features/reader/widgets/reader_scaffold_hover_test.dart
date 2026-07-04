// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// M3b/任务1：悬停翻页箭头测试。
//
// 验证：鼠标 hover 左/右翻页 zone 时显示半透明 chevron 箭头；鼠标移出后
// 箭头消失；箭头 widget tree 含 IgnorePointer（不消费底层 tap）。
// 移动端无鼠标 → MouseRegion.onEnter 永不触发 → 箭头不显示。

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/widgets/reader_scaffold.dart';

void main() {
  // 模拟鼠标 hover 到指定坐标：创建 mouse pointer，先 add（hovered 进入），
  // 再 moveTo 目标坐标触发 MouseRegion.onEnter。
  Future<void> hoverAt(WidgetTester tester, Offset location) async {
    final gesture =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(0, 0));
    await gesture.moveTo(location);
    await tester.pumpAndSettle();
  }

  testWidgets('hover left zone shows chevron_left arrow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            marginPx: 48,
            onTapPrev: () {},
            onTapNext: () {},
          ),
        ),
      ),
    );

    // 初始无箭头。
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    // hover 左侧 zone（left zone = [0, 48]）。
    await hoverAt(tester, const Offset(24, 400));

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('hover right zone shows chevron_right arrow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            marginPx: 48,
            onTapPrev: () {},
            onTapNext: () {},
          ),
        ),
      ),
    );

    await hoverAt(tester, const Offset(776, 400)); // right zone = [752, 800]

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('hover exit hides the arrow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            marginPx: 48,
            onTapPrev: () {},
            onTapNext: () {},
          ),
        ),
      ),
    );

    // 用同一个 mouse gesture：先进 zone（显示箭头），再移到 zone 外（隐藏）。
    final gesture =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(0, 0));
    await gesture.moveTo(const Offset(24, 400)); // zone 内
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);

    await gesture.moveTo(const Offset(400, 400)); // 中央内容区，zone 外
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('hover arrow is wrapped in IgnorePointer (does not eat tap)',
      (tester) async {
    var prevTapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            marginPx: 48,
            onTapPrev: () => prevTapped = true,
            onTapNext: () {},
          ),
        ),
      ),
    );

    await hoverAt(tester, const Offset(24, 400));
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);

    // 箭头 icon 所在子树应包含 IgnorePointer（至少一个，确保不消费 tap）。
    final arrowFinder = find.byIcon(Icons.chevron_left);
    expect(
      find.ancestor(of: arrowFinder, matching: find.byType(IgnorePointer)),
      findsWidgets,
    );

    // 即使显示着箭头，点击 zone 中央仍触发翻页（IgnorePointer 放行 tap）。
    await tester.tapAt(const Offset(24, 400));
    await tester.pumpAndSettle();
    expect(prevTapped, isTrue);
  });
}
