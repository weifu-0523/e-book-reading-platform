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
import 'package:zhiyue/features/ai_chat/widgets/ai_drawer_widget.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/pages/reader_body.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

/// Regression (2026-07-11 user report): on mobile (narrow viewport), tapping
/// the AppBar AI icon did nothing because `_toggleAiDrawer` only flipped
/// `_aiPanelOpen`, which controls the wide-screen inline panel only. The
/// narrow path requires `Scaffold.of(context).openEndDrawer()`.
///
/// Companion fix: the bottom-right FAB (previously "add bookmark", shown only
/// when chrome is hidden) is repurposed as an AI drawer entry — bookmark FAB
/// required chrome to be visible to use the AppBar button, but with chrome
/// auto-hide on mobile the user has no quick AI entry. AI is the more
/// frequently-needed action; bookmark remains in the AppBar when chrome is
/// visible.

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
  bool get dualPageMode => false;
  @override
  int get currentSpreadCount => 0;
  @override
  int get currentSpreadIndex => 0;
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
  bool nextPage() => false;
  @override
  bool previousPage() => false;
  @override
  Future<void> setPaginationMode(PaginationMode mode) async {}
  @override
  void scrollBy(double delta,
      {Duration duration = const Duration(milliseconds: 200)}) {}
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
  @override
  Future<Book?> getById(String id) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeReaderEngine engine;

  Future<ProviderContainer> pumpNarrowBody(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    engine = _FakeReaderEngine();
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(_NoopRepo()),
      bookRepositoryProvider.overrideWithValue(_FakeBookRepo()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReaderBody(engine: engine, bookId: 'b1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    return container;
  }

  testWidgets(
      'Bug 2a: tapping AppBar AI icon opens endDrawer on narrow viewport',
      (tester) async {
    final container = await pumpNarrowBody(tester);
    // Force chrome visible so the AppBar (and its AI icon) is tappable.
    final notifier = container.read(readerUiControllerProvider.notifier);
    if (!container.read(readerUiControllerProvider).chromeVisible) {
      notifier.toggleChrome();
    }
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('toggle_ai_drawer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle_ai_drawer')));
    await tester.pumpAndSettle();

    final scaffoldState =
        tester.state<ScaffoldState>(find.byType(Scaffold).first);
    expect(scaffoldState.isEndDrawerOpen, isTrue,
        reason: 'Bug 2a: on narrow viewport, AppBar AI icon must call '
            'Scaffold.of(context).openEndDrawer(), not flip _aiPanelOpen '
            '(which only affects the wide-screen inline panel).');
  });

  testWidgets(
      'Bug 2b: when chrome hidden on narrow viewport, FAB is AI (not bookmark)',
      (tester) async {
    final container = await pumpNarrowBody(tester);
    final notifier = container.read(readerUiControllerProvider.notifier);
    if (container.read(readerUiControllerProvider).chromeVisible) {
      notifier.toggleChrome();
    }
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget,
        reason: 'Bug 2b: FAB is repurposed from bookmark to AI drawer entry');
    expect(find.byIcon(Icons.bookmark_add_outlined), findsNothing,
        reason: 'Bug 2b: bookmark FAB replaced — bookmark is AppBar-only now');
  });

  testWidgets(
      'Bug 2b: AI FAB is absent when chrome is visible (AppBar is the entry)',
      (tester) async {
    final container = await pumpNarrowBody(tester);
    final notifier = container.read(readerUiControllerProvider.notifier);
    if (!container.read(readerUiControllerProvider).chromeVisible) {
      notifier.toggleChrome();
    }
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing,
        reason: 'when chrome is visible, the AppBar AI IconButton is the '
            'entry point; the FAB must be hidden to avoid a duplicate.');
  });

  testWidgets(
      'Bug 2b: tapping the AI FAB opens endDrawer on narrow viewport',
      (tester) async {
    final container = await pumpNarrowBody(tester);
    final notifier = container.read(readerUiControllerProvider.notifier);
    if (container.read(readerUiControllerProvider).chromeVisible) {
      notifier.toggleChrome();
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final scaffoldState =
        tester.state<ScaffoldState>(find.byType(Scaffold).first);
    expect(scaffoldState.isEndDrawerOpen, isTrue,
        reason: 'Bug 2b: FAB tap must open the AI drawer (replaces the old '
            'bookmark-add FAB action).');
  });

  testWidgets(
      'Bug 4: AI endDrawer wraps content in SafeArea for status bar avoidance',
      (tester) async {
    final container = await pumpNarrowBody(tester);
    // Force chrome visible so AppBar AI icon is tappable, then open endDrawer.
    final notifier = container.read(readerUiControllerProvider.notifier);
    if (!container.read(readerUiControllerProvider).chromeVisible) {
      notifier.toggleChrome();
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('toggle_ai_drawer')));
    await tester.pumpAndSettle();

    // AiDrawerWidget must have a SafeArea ancestor so its content respects
    // the system status bar / dynamic island on iPhones and notches on Android.
    final safeAreaAncestor = find.ancestor(
      of: find.byType(AiDrawerWidget),
      matching: find.byType(SafeArea),
    );
    expect(safeAreaAncestor, findsOneWidget,
        reason: 'Bug 4: AiDrawerWidget must have a SafeArea ancestor (within '
            'the Drawer) so its content respects the system status bar / '
            'dynamic island on iPhones and notches on Android.');
  });

  testWidgets('Bug 5: AI endDrawer width is 98% of screen on narrow viewport',
      (tester) async {
    // 390px wide (iPhone 14). 0.98 * 390 = 382.2.
    final container = await pumpNarrowBody(tester, size: const Size(390, 844));
    final notifier = container.read(readerUiControllerProvider.notifier);
    if (!container.read(readerUiControllerProvider).chromeVisible) {
      notifier.toggleChrome();
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('toggle_ai_drawer')));
    await tester.pumpAndSettle();

    final aiDrawer = tester.widget<Drawer>(find.ancestor(
      of: find.byType(AiDrawerWidget),
      matching: find.byType(Drawer),
    ));
    expect(aiDrawer.width, closeTo(390 * 0.98, 0.5),
        reason: 'Bug 5: AI endDrawer must occupy ~98% of screen width on '
            'mobile so chat is usable; the previous default (~304 / 78%) '
            'left the book barely readable behind the drawer.');
  });
}
