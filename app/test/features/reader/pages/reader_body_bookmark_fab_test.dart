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
import 'package:zhiyue/gen_l10n/app_localizations.dart';

/// M2.10/Bug C1 regression tests: a bookmark "add" entry point (FAB) must be
/// visible when chrome is hidden (fullscreen / user-toggled), since the only
/// other entry — the AppBar IconButton in `_buildChrome` — is gated behind
/// `ui.chromeVisible` and otherwise vanishes.
///
/// Contract:
/// - chromeVisible == false → FloatingActionButton(bookmark_add_outlined) present
/// - chromeVisible == true  → FAB absent (AppBar button takes over, no dup)
/// - tapping the FAB triggers `_onAddBookmark` → opens ReaderBookmarkDialog
///   (provided `_currentLocation` is non-null)

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

  Future<ProviderContainer> pumpBody(
    WidgetTester tester, {
    required bool chromeVisible,
  }) async {
    engine = _FakeReaderEngine();
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(_NoopRepo()),
      bookRepositoryProvider.overrideWithValue(_FakeBookRepo()),
    ]);
    // Force chrome state.
    container
        .read(readerUiControllerProvider.notifier)
        .setActiveDrawerTab(DrawerTab.toc); // no-op init touch
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
    // Apply chrome visibility after pump so the controller reflects it.
    if (chromeVisible) {
      // defaults() on desktop sets chromeVisible true, but the test host
      // platform may not be desktop. Force it explicitly:
      // toggleChrome flips the boolean; to GUARANTEE true we may need to
      // flip from the current value. Read current and flip if needed.
    } else {
      // Ensure hidden.
    }
    return container;
  }

  testWidgets(
      'bookmark FAB is present when chrome is hidden (Bug C1: no add entry)',
      (tester) async {
    final container = await pumpBody(tester, chromeVisible: false);
    // Force chrome hidden regardless of host platform default.
    // toggleChrome flips; we want chromeVisible == false. defaults() sets it
    // per-platform; on a non-desktop test host it's already false. To be
    // deterministic, set it via the notifier by toggling to false.
    final notifier = container.read(readerUiControllerProvider.notifier);
    // If currently visible, toggle off.
    if (container.read(readerUiControllerProvider).chromeVisible) {
      notifier.toggleChrome();
    }
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget,
        reason: 'M2.10/Bug C1: when chrome is hidden, the AppBar (and its '
            'bookmark IconButton) disappears, leaving no add-bookmark entry. '
            'A FAB must fill that gap.');
    expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget);
  });

  testWidgets(
      'bookmark FAB is absent when chrome is visible (no duplicate entry)',
      (tester) async {
    final container = await pumpBody(tester, chromeVisible: true);
    final notifier = container.read(readerUiControllerProvider.notifier);
    // Force chrome visible.
    if (!container.read(readerUiControllerProvider).chromeVisible) {
      notifier.toggleChrome();
    }
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing,
        reason: 'when chrome is visible, the AppBar bookmark IconButton is '
            'the entry point; the FAB must be hidden to avoid a duplicate');
  });

  testWidgets('tapping bookmark FAB opens the add-bookmark dialog',
      (tester) async {
    final container = await pumpBody(tester, chromeVisible: false);
    final notifier = container.read(readerUiControllerProvider.notifier);
    if (container.read(readerUiControllerProvider).chromeVisible) {
      notifier.toggleChrome();
    }
    // _onAddBookmark reads _currentLocation; if null it shows a SnackBar and
    // aborts. Emit a locator so the dialog path is taken.
    engine._locationController.add(const EpubCfiLocator(
      cfi: 'fake',
      chapterIndex: 0,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // ReaderBookmarkDialog contains a TextField for the label + an 'Add'
    // (添加) button. The dialog title/label field presence confirms the
    // add flow was triggered.
    expect(find.byType(AlertDialog), findsOneWidget,
        reason: 'tapping the FAB must trigger _onAddBookmark, which opens '
            'ReaderBookmarkDialog when _currentLocation is non-null');
  });
}
