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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/book_ref.dart' as re show BookRef;
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/repositories/book_repository.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/pages/reader_body.dart';
import 'package:zhiyue/features/reader/widgets/reader_drawer.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

/// 假 ReaderEngine —— 与 reader_body_review_menu_test.dart 同源。
class _FakeReaderEngine implements ReaderEngine {
  _FakeReaderEngine();

  final StreamController<ReaderEngineState> _stateController =
      StreamController<ReaderEngineState>.broadcast();
  final StreamController<Locator> _locationController =
      StreamController<Locator>.broadcast();

  @override
  ReaderEngineState get state => const ReaderEngineReady();

  @override
  Stream<ReaderEngineState> get state$ => _stateController.stream;

  @override
  TableOfContents? get toc => null;

  @override
  TypographySettings get typography => TypographySettings.defaults();

  @override
  Stream<Locator> get currentLocation$ => _locationController.stream;

  @override
  Future<String> get currentChapterPlainText => Future.value('');

  @override
  List<PageBreak> get currentChapterPageBreaks => const [];

  @override
  PageController? get pageController => null;

  @override
  Future<void> get chapterSwitchSettled => Future<void>.value();

  @override
  PaginationMode get paginationMode => PaginationMode.paged;

  @override
  Future<void> open(re.BookRef book) async {}

  @override
  Future<void> gotoLocator(Locator locator) async {}

  @override
  Future<void> gotoTocEntry(TocEntry entry) async {}

  @override
  Future<void> nextSpine() async {}

  @override
  Future<void> previousSpine() async {}

  @override
  Future<void> setPaginationMode(PaginationMode mode) async {}

  @override
  Future<void> setTypography(TypographySettings settings) async {}

  @override
  Future<void> close() async {
    await _stateController.close();
    await _locationController.close();
  }

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('fake content'));
}

class _NoopRepo implements NotesRepository {
  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) =>
      Stream.value(const []);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBookRepo implements BookRepository {
  final Book? _book;
  _FakeBookRepo(this._book);

  @override
  Future<Book?> getById(String id) async => _book;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Book _epubBook(String id) => Book(
      id: id,
      title: '测试 EPUB',
      author: null,
      coverPath: null,
      filePath: 'test.epub',
      format: BookFormat.epub,
      fileHash: 'hash-$id',
      fileSizeBytes: 1024,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );

void main() {
  Future<ProviderContainer> pumpReaderBody(
    WidgetTester tester, {
    required String bookId,
    required Size logicalSize,
  }) async {
    // Flutter test default viewport = 800x600 logical. Override to simulate
    // wide / narrow layouts. tester.view exposes FakeFlutterView setters.
    final dpr = tester.view.devicePixelRatio;
    tester.view.physicalSize =
        Size(logicalSize.width * dpr, logicalSize.height * dpr);
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(_NoopRepo()),
      bookRepositoryProvider.overrideWithValue(_FakeBookRepo(_epubBook(bookId))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReaderBody(engine: _FakeReaderEngine(), bookId: bookId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    return container;
  }

  group('ReaderBody wide-screen sidebar (T8)', () {
    testWidgets('wide (>=1100px) shows permanent sidebar with collapse button',
        (tester) async {
      await pumpReaderBody(tester,
          bookId: 'b-wide-1', logicalSize: const Size(1600, 900));

      // Permanent sidebar is present.
      final sidebarFinder = find.byKey(const Key('sidebar_root'));
      expect(sidebarFinder, findsOneWidget);

      // Expanded (280px) by default.
      final sidebarSize = tester.getSize(sidebarFinder);
      expect(sidebarSize.width, 280);

      // Collapse button present.
      expect(find.byKey(const Key('collapse_sidebar')), findsOneWidget);
      // Expand button absent in expanded state.
      expect(find.byKey(const Key('expand_sidebar')), findsNothing);

      // ReaderDrawer mounted inside the sidebar column.
      expect(find.descendant(of: sidebarFinder, matching: find.byType(ReaderDrawer)),
          findsOneWidget);

      // The Scaffold's sliding drawer should NOT be open.
      final scaffoldState = tester.state(find.byType(Scaffold).first)
          as ScaffoldState;
      expect(scaffoldState.isDrawerOpen, isFalse);
    });

    testWidgets('tapping collapse shrinks sidebar to 40px', (tester) async {
      await pumpReaderBody(tester,
          bookId: 'b-wide-2', logicalSize: const Size(1600, 900));

      final sidebarFinder = find.byKey(const Key('sidebar_root'));
      expect(tester.getSize(sidebarFinder).width, 280);

      await tester.tap(find.byKey(const Key('collapse_sidebar')));
      // 用 pump(duration) 而非 pumpAndSettle：后者在 ReaderDrawer 重新挂载
      // 时可能被 NotesRepository 的 watchAnnotations stream 周期触发阻塞。
      // AnimatedContainer duration=200ms，pump 250ms 后动画完成。
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.getSize(sidebarFinder).width, 40);
      // After collapse, expand button visible, collapse button hidden.
      expect(find.byKey(const Key('expand_sidebar')), findsOneWidget);
      expect(find.byKey(const Key('collapse_sidebar')), findsNothing);
    });

    testWidgets('tapping expand restores sidebar to 280px', (tester) async {
      await pumpReaderBody(tester,
          bookId: 'b-wide-3', logicalSize: const Size(1600, 900));

      // Collapse first.
      await tester.tap(find.byKey(const Key('collapse_sidebar')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getSize(find.byKey(const Key('sidebar_root'))).width, 40);

      // Then expand.
      await tester.tap(find.byKey(const Key('expand_sidebar')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getSize(find.byKey(const Key('sidebar_root'))).width, 280);
      expect(find.byKey(const Key('collapse_sidebar')), findsOneWidget);
    });

    testWidgets('narrow (<1100px) has no permanent sidebar; uses Scaffold drawer',
        (tester) async {
      await pumpReaderBody(tester,
          bookId: 'b-narrow-1', logicalSize: const Size(800, 900));

      // No permanent sidebar.
      expect(find.byKey(const Key('sidebar_root')), findsNothing);

      // ReaderDrawer still wired to Scaffold.drawer slot.
      // 在窄屏路径下 Scaffold.drawer 接受 ReaderDrawer，但 Drawer widget 在
      // 关闭时是 offstage 的；用 widget tree 深搜确认挂载。
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.drawer, isA<ReaderDrawer>());
    });

    // Regression: 宽屏 + sidebar 已展开 + 当前在 Notes tab，用户点 AppBar 的
    // TOC 图标，期望切到 TOC tab。原 bug 把 setActiveDrawerTab 包在
    // `ui.tocSidebarCollapsed || !_isWideScreen` 守卫里，导致宽屏展开态点击
    // 是静默 no-op。守卫应只 gate openDrawer，tab 切换必须无条件执行。
    testWidgets(
        'wide screen: tapping TOC icon switches to TOC tab when sidebar expanded',
        (tester) async {
      final container = await pumpReaderBody(tester,
          bookId: 'b-wide-toc', logicalSize: const Size(1600, 900));

      // 模拟用户此前已在 Notes tab（通过控制器直接设置初始态）。
      container
          .read(readerUiControllerProvider.notifier)
          .setActiveDrawerTab(DrawerTab.notes);
      // 测试环境默认 platform 非 desktop，chrome 默认隐藏；显式开启以便点击 AppBar。
      container.read(readerUiControllerProvider.notifier).toggleChrome();
      await tester.pump();
      expect(container.read(readerUiControllerProvider).activeDrawerTab,
          DrawerTab.notes,
          reason: 'precondition: should start on Notes tab');

      // Sidebar 已展开是默认状态（280px），无需切换。
      expect(find.byKey(const Key('sidebar_root')), findsOneWidget);

      // 在 chrome AppBar 上找到 TOC 图标（tooltip=目录）并点击。
      final tocIcon = find.byTooltip('目录');
      expect(tocIcon, findsOneWidget,
          reason: 'TOC icon should be visible in chrome AppBar on wide screen');
      await tester.tap(tocIcon);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      // 修复后：tab 应切到 TOC。
      expect(container.read(readerUiControllerProvider).activeDrawerTab,
          DrawerTab.toc,
          reason: 'after fix: tapping TOC icon must switch active tab');
    });
  });
}
