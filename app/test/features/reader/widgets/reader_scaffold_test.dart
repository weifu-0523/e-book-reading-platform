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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/widgets/reader_clock.dart';
import 'package:zhiyue/features/reader/widgets/reader_scaffold.dart';

void main() {
  testWidgets('paged mode tap right triggers next', (tester) async {
    var nextTapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            // M2.6/T9: explicit margin so tap at 750 falls inside right zone
            // (right zone = [800 - 48, 800] = [752, 800]).
            marginPx: 48,
            onTapPrev: () {},
            onTapNext: () => nextTapped = true,
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(770, 400));
    await tester.pumpAndSettle();

    expect(nextTapped, isTrue);
  });

  testWidgets('paged mode tap left triggers prev', (tester) async {
    var prevTapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            // M2.6/T9: explicit margin so tap at 30 falls inside left zone
            // (left zone = [0, 48]).
            marginPx: 48,
            onTapPrev: () => prevTapped = true,
            onTapNext: () {},
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(30, 400));
    await tester.pumpAndSettle();

    expect(prevTapped, isTrue);
  });

  testWidgets('scroll mode tap in zones still triggers page (M2.6/T9)',
      (tester) async {
    // M2.6/T9: tap zones are mode-independent. Scroll mode also pages on
    // margin taps (only wheel-scroll is gated to paged mode now).
    var nextTapped = false;
    var prevTapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.scroll,
            marginPx: 48,
            onTapPrev: () => prevTapped = true,
            onTapNext: () => nextTapped = true,
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(770, 400));
    await tester.pumpAndSettle();
    expect(nextTapped, isTrue);

    await tester.tapAt(const Offset(30, 400));
    await tester.pumpAndSettle();
    expect(prevTapped, isTrue);
  });

  testWidgets('chrome is revealed by toggling readerUiControllerProvider',
      (tester) async {
    // Center-tap no longer reveals chrome (T5 removed it; T6/T9 own chrome UI).
    // Verify the canonical way to reveal chrome in tests is via the provider.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ReaderScaffold(
            content: Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: nil,
            onTapNext: nil,
          ),
        ),
      ),
    );

    // UX-B (Task 4): provider now defaults chromeVisible=true on all platforms.
    // Establish known hidden state before testing toggle (hidden → visible).
    container.read(readerUiControllerProvider.notifier).hideChrome();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_app_bar')), findsNothing);
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_app_bar')), findsOneWidget);
  });

  // ── M3c：顶栏时钟 + 字号± + 书架按钮 ───────────────────────────────

  testWidgets('title is a ReaderClock when chrome is visible', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ReaderScaffold(
            content: Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: nil,
            onTapNext: nil,
          ),
        ),
      ),
    );
    // UX-B (Task 4): default chromeVisible=true; hide first, then toggle to reveal.
    container.read(readerUiControllerProvider.notifier).hideChrome();
    await tester.pumpAndSettle();
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();

    expect(find.byType(ReaderClock), findsOneWidget);
  });

  testWidgets('renders font decrease / increase icons (M3c/任务6a)',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: nil,
            onTapNext: nil,
            onFontDecrease: () {},
            onFontIncrease: () {},
          ),
        ),
      ),
    );
    // UX-B (Task 4): default chromeVisible=true; hide first, then toggle to reveal.
    container.read(readerUiControllerProvider.notifier).hideChrome();
    await tester.pumpAndSettle();
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader_font_decrease')), findsOneWidget);
    expect(find.byKey(const Key('reader_font_increase')), findsOneWidget);
    expect(find.byIcon(Icons.text_decrease), findsOneWidget);
    expect(find.byIcon(Icons.text_increase), findsOneWidget);
  });

  testWidgets('font increase tap invokes callback (M3c/任务6a)',
      (tester) async {
    var increased = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: nil,
            onTapNext: nil,
            onFontIncrease: () => increased = true,
          ),
        ),
      ),
    );
    // UX-B (Task 4): default chromeVisible=true; hide first, then toggle to reveal.
    container.read(readerUiControllerProvider.notifier).hideChrome();
    await tester.pumpAndSettle();
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reader_font_increase')));
    await tester.pumpAndSettle();

    expect(increased, isTrue);
  });

  testWidgets('font decrease tap invokes callback (M3c/任务6a)',
      (tester) async {
    var decreased = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: nil,
            onTapNext: nil,
            onFontDecrease: () => decreased = true,
          ),
        ),
      ),
    );
    // UX-B (Task 4): default chromeVisible=true; hide first, then toggle to reveal.
    container.read(readerUiControllerProvider.notifier).hideChrome();
    await tester.pumpAndSettle();
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reader_font_decrease')));
    await tester.pumpAndSettle();

    expect(decreased, isTrue);
  });

  testWidgets('renders and triggers the bookshelf button (M3c/任务6b)',
      (tester) async {
    var bookshelfOpened = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: nil,
            onTapNext: nil,
            onOpenBookshelf: () => bookshelfOpened = true,
          ),
        ),
      ),
    );
    // UX-B (Task 4): default chromeVisible=true; hide first, then toggle to reveal.
    container.read(readerUiControllerProvider.notifier).hideChrome();
    await tester.pumpAndSettle();
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader_open_bookshelf')), findsOneWidget);
    expect(find.byIcon(Icons.collections_bookmark_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader_open_bookshelf')));
    await tester.pumpAndSettle();

    expect(bookshelfOpened, isTrue);
  });

  testWidgets(
      'M3e/Q4: bookshelf + font± buttons are in the AppBar leading region '
      '(left of clock)', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: nil,
            onTapNext: nil,
            onOpenBookshelf: () {},
            onFontDecrease: () {},
            onFontIncrease: () {},
          ),
        ),
      ),
    );
    // UX-B (Task 4): default chromeVisible=true; hide first, then toggle to reveal.
    container.read(readerUiControllerProvider.notifier).hideChrome();
    await tester.pumpAndSettle();
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    // leading 不再是单个 IconButton，而是含 4 个按钮的 Row。
    expect(appBar.leading, isA<Row>(),
        reason: 'M3e/Q4: leading 应为 Row（返回 + 书架 + 字号±）');
    final leadingRow = appBar.leading! as Row;
    expect(leadingRow.children.length, 4,
        reason: 'leading Row 含 4 个 IconButton');
    // 3 个关键按钮（书架/字号-/字号+）确实在 leading Row 内。
    final leadingKeys = leadingRow.children
        .whereType<IconButton>()
        .map((b) => b.key)
        .toSet();
    expect(leadingKeys, contains(const Key('reader_open_bookshelf')));
    expect(leadingKeys, contains(const Key('reader_font_decrease')));
    expect(leadingKeys, contains(const Key('reader_font_increase')));
    // leadingWidth 放宽到容纳 4 按钮。
    expect(appBar.leadingWidth, greaterThanOrEqualTo(160));
    // 时钟仍在 title。
    expect(find.byType(ReaderClock), findsOneWidget);
  });

  // v1.11.9-alpha Bug 1：compact chrome 透明度问题。
  //
  // 用户报告：「导航条改为可左右滑动后，目前设置为了透明状态，但没有透明度
  // 的设置，导致浅色方案下，移动端导航条看不清，和背景文字重叠显示」。
  //
  // 根因：`_buildChrome` 用 `Material(color: Colors.black54)` 硬编码黑色 54%
  // 透明背景。浅色方案下 IconTheme 是深色（黑/灰），叠在黑底上对比度极低
  // → 用户视觉上「透明」+ 看不清。修复：背景色用 `Theme.colorScheme.surface`
  // 自适应主题（浅色方案给浅底，深色方案给深底）+ iconTheme 强制 onSurface 色。
  group('v1.11.9-alpha Bug 1: chrome background theme-adaptive', () {
    Finder _chromeMaterial() => find.byKey(const Key('reader_app_bar'));

    testWidgets('light theme: chrome bg is NOT fixed Colors.black54',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
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
      await tester.pumpAndSettle();

      expect(_chromeMaterial(), findsOneWidget);
      final material = tester.widget<Material>(_chromeMaterial());
      expect(material.color, isNot(equals(Colors.black54)),
          reason: '浅色主题下 chrome 用 Colors.black54 会导致黑底+深色图标'
              '对比度极低，用户报告「看不清，与背景文字重叠」。应使用 theme '
              'surface 色自适应。');
    });

    testWidgets('dark theme: chrome bg also uses theme surface (not black54)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
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
      await tester.pumpAndSettle();

      expect(_chromeMaterial(), findsOneWidget);
      final material = tester.widget<Material>(_chromeMaterial());
      expect(material.color, isNot(equals(Colors.black54)),
          reason: '深色主题也应通过 theme surface 自适应（深灰），而非硬编码 '
              'Colors.black54。');
    });

    testWidgets('light theme: chrome icons use onSurface (visible on light bg)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
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
      await tester.pumpAndSettle();

      // 找任意一个 chrome 内的 Icon，断言其颜色 != white（白色图标在浅底上看不清）。
      final iconFinder = find.descendant(
        of: find.byKey(const Key('reader_app_bar')),
        matching: find.byType(Icon),
      );
      expect(iconFinder, findsWidgets);
      final icon = tester.widget<Icon>(iconFinder.first);
      final iconColor = icon.color ?? IconTheme.of(tester.element(iconFinder.first)).color;
      expect(iconColor, isNot(equals(Colors.white)),
          reason: '浅色主题下图标不应是白色（白底白字看不清）。应继承 theme '
              'onSurface（深色）。');
    });
  });
}

void nil() {}
