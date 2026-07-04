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
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/widgets/reader_drawer_builders.dart';

/// M2.10/Bug B2 regression test: `ReaderTocDrawerWrapper.onSelect` must
/// `await engine.chapterSwitchSettled` AFTER `gotoTocEntry` and BEFORE
/// `closeDrawer`.
///
/// Root cause being guarded: in dual-page mode, `gotoTocEntry` → `gotoLocator`
/// (CFI branch) emits state → rebuild → `_buildPaged`'s LayoutBuilder re-runs
/// to recompute page breaks for the new chapter. If the drawer is closed
/// before that settles, the PageView hasn't finished laying out the new
/// chapter and the TOC jump appears to "stick" on the old chapter or throws
/// a spread-index out-of-bounds assertion.
///
/// Test strategy: a fake engine whose `chapterSwitchSettled` only completes
/// when explicitly signaled. After tapping a TOC entry, the drawer must
/// remain open (closeDrawer not yet called) until the settle future resolves.
/// We track open/close via Scaffold.onDrawerChanged.

class _RecordingEngine implements ReaderEngine {
  _RecordingEngine({required this.chapterSwitchCompleter});

  final Completer<void> chapterSwitchCompleter;

  int gotoTocEntryCallCount = 0;
  TocEntry? lastTocEntry;

  @override
  ReaderEngineState get state => const ReaderEngineReady();
  @override
  Stream<ReaderEngineState> get state$ => Stream.value(const ReaderEngineReady());
  @override
  TableOfContents? get toc => const TableOfContents(entries: [
          TocEntry(title: '第一章', locator: EpubCfiLocator(cfi: 'c', chapterIndex: 0)),
        ]);
  @override
  Future<void> get chapterSwitchSettled => chapterSwitchCompleter.future;

  @override
  Future<void> gotoTocEntry(TocEntry entry) async {
    gotoTocEntryCallCount++;
    lastTocEntry = entry;
  }

  // ---- Stubs not exercised ----
  @override
  TypographySettings get typography => TypographySettings.defaults();
  @override
  Stream<Locator> get currentLocation$ => const Stream<Locator>.empty();
  @override
  Future<String> get currentChapterPlainText => Future.value('');
  @override
  List<PageBreak> get currentChapterPageBreaks => const [];
  @override
  PageController? get pageController => null;
  @override
  PaginationMode get paginationMode => PaginationMode.paged;
  @override
  bool get dualPageMode => false;
  @override
  int get currentSpreadCount => 0;
  @override
  int get currentSpreadIndex => 0;
  @override
  Future<void> open(BookRef book) async {}
  @override
  Future<void> gotoLocator(Locator locator) async {}
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
  Future<void> close() async {}
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets(
      'onSelect awaits chapterSwitchSettled before closing drawer',
      (tester) async {
    final completer = Completer<void>();
    final engine = _RecordingEngine(chapterSwitchCompleter: completer);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Track drawer open/close via onDrawerChanged.
    bool drawerIsOpen = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            key: const Key('scaffold'),
            drawer: ReaderTocDrawerWrapper(engine: engine, bookId: 'b1'),
            onDrawerChanged: (open) => drawerIsOpen = open,
            body: const Center(child: Text('reader body')),
          ),
        ),
      ),
    );
    // Open the drawer so the wrapper mounts and the TOC tile is tappable.
    tester.state<ScaffoldState>(find.byKey(const Key('scaffold'))).openDrawer();
    await tester.pumpAndSettle();
    expect(drawerIsOpen, isTrue);

    // Tap the TOC entry. onSelect is async: it awaits gotoTocEntry, then
    // awaits chapterSwitchSettled (blocked on `completer`), then closeDrawer.
    await tester.tap(find.text('第一章'));
    await tester.pump();
    // Let the microtask queue drain so gotoTocEntry + the await on
    // chapterSwitchSettled have run up to the blocking point.
    await tester.pump(const Duration(milliseconds: 10));

    // gotoTocEntry must have run (it's awaited first).
    expect(engine.gotoTocEntryCallCount, 1,
        reason: 'onSelect must call gotoTocEntry first');
    expect(engine.lastTocEntry!.title, '第一章');

    // The drawer must STILL be open: chapterSwitchSettled hasn't resolved
    // (completer not completed), so closeDrawer hasn't fired yet.
    expect(drawerIsOpen, isTrue,
        reason: 'drawer must stay open until chapterSwitchSettled resolves; '
            'pre-fix onSelect closed it immediately after gotoTocEntry');

    // Now resolve chapterSwitchSettled — onSelect proceeds to closeDrawer.
    completer.complete();
    await tester.pumpAndSettle();

    expect(drawerIsOpen, isFalse,
        reason: 'after chapterSwitchSettled resolves, onSelect must call '
            'closeDrawer');
  });
}
