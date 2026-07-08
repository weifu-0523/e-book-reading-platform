// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/widgets/reader_scaffold.dart';

/// 2026-07-08 FEAT 4：scroll 模式下键盘上下键调用 onScrollBy 回调。
/// paged 模式下方向键仍走 onTapPrev/onTapNext。
void main() {
  testWidgets(
      'scroll mode: ArrowDown → onScrollBy(+0.8*viewport), ArrowUp → onScrollBy(-0.8*viewport)',
      (tester) async {
    double? lastDelta;
    int prevTaps = 0;
    int nextTaps = 0;

    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ReaderScaffold(
            content: const SizedBox.expand(),
            title: 'test',
            paginationMode: PaginationMode.scroll,
            onTapPrev: () => prevTaps++,
            onTapNext: () => nextTaps++,
            onScrollBy: (delta) => lastDelta = delta,
          ),
        ),
      ),
    )));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(lastDelta, isNotNull);
    expect(lastDelta! > 0, isTrue, reason: 'ArrowDown should scroll down (+delta)');
    expect(nextTaps, 0, reason: 'paged-only callback should NOT fire in scroll mode');
    expect(prevTaps, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(lastDelta! < 0, isTrue, reason: 'ArrowUp should scroll up (-delta)');
    expect(prevTaps, 0);
    expect(nextTaps, 0);

    // PageDown / PageUp 同样映射到 scroll（与 paged 模式行为不同：paged 模式下
    // PgDn/PgUp 翻页，scroll 模式下走 scrollBy）。
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    expect(lastDelta! > 0, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    expect(lastDelta! < 0, isTrue);
  });

  testWidgets('paged mode: ArrowDown → onTapNext (FEAT 4 不改变 paged 行为)',
      (tester) async {
    double? lastDelta;
    int prevTaps = 0;
    int nextTaps = 0;

    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ReaderScaffold(
            content: const SizedBox.expand(),
            title: 'test',
            paginationMode: PaginationMode.paged,
            onTapPrev: () => prevTaps++,
            onTapNext: () => nextTaps++,
            onScrollBy: (delta) => lastDelta = delta,
          ),
        ),
      ),
    )));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(nextTaps, 1, reason: 'paged mode ArrowDown → onTapNext');
    expect(lastDelta, isNull, reason: 'scroll callback should NOT fire in paged mode');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(prevTaps, 1);
  });

  testWidgets('scroll mode without onScrollBy: 方向键不抛异常', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ReaderScaffold(
            content: const SizedBox.expand(),
            title: 'test',
            paginationMode: PaginationMode.scroll,
            onTapPrev: () {},
            onTapNext: () {},
            // onScrollBy 故意不传
          ),
        ),
      ),
    )));
    await tester.pump();
    // 上下键不抛
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(tester.takeException(), isNull);
  });
}
