// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
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

  testWidgets('arrow keys do NOT paginate when EditableText is focused',
      (tester) async {
    // T6 (2026-07-09): 阅读区方向键翻页通过 HardwareKeyboard 全局监听，
    // 但 EditableText 聚焦时应让出方向键给文本编辑（移动光标）。
    int prevCalls = 0;
    int nextCalls = 0;
    final textFieldFocusNode = FocusNode();
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: Scaffold(
        body: ReaderScaffold(
          content: TextField(focusNode: textFieldFocusNode),
          onTapPrev: () => prevCalls++,
          onTapNext: () => nextCalls++,
          title: 't',
        ),
      ),
    )));
    // 先 pump 让 ReaderScaffold 的 PostFrameCallback 跑完（初始获焦）。
    await tester.pump();
    // 再显式让 TextField 获焦（模拟用户点输入框）。
    textFieldFocusNode.requestFocus();
    await tester.pump();
    // sanity: TextField 拿到焦点（primaryFocus 应在 EditableText 内部）。
    final primary = FocusManager.instance.primaryFocus;
    expect(
      primary?.context?.findAncestorWidgetOfExactType<EditableText>(),
      isNotNull,
      reason: 'TextField should be focused for this test',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(prevCalls, 0, reason: 'EditableText focused → 不应触发 prev');
    expect(nextCalls, 0, reason: 'EditableText focused → 不应触发 next');
  });

  testWidgets('arrow keys DO paginate when no EditableText focused',
      (tester) async {
    // 对照组：非 EditableText 聚焦时，方向键仍翻页（M2.8/B1-fix 行为）。
    // UX-B (Task 4): default chromeVisible=true makes the AppBar render and
    // overflow this narrow test viewport. Hide chrome first to isolate the
    // keyboard paging behavior under test.
    int prevCalls = 0;
    int nextCalls = 0;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(readerUiControllerProvider.notifier).hideChrome();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: ReaderScaffold(
            content: const Text('reader content'),
            onTapPrev: () => prevCalls++,
            onTapNext: () => nextCalls++,
            title: 't',
          ),
        ),
      ),
    ));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(nextCalls, greaterThan(0), reason: 'arrowRight 应翻页');
    expect(prevCalls, greaterThan(0), reason: 'arrowLeft 应翻页');
  });
}
