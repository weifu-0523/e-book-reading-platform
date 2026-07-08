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
import 'package:zhiyue/data/repositories/notes_repository.dart';
import 'package:zhiyue/features/library/providers/library_controller.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/pages/reader_body.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

import '../../../fakes/fake_book_repository.dart';
import '../../../fakes/fake_book_tags_lookup.dart';
import '../../../fakes/fake_settings_repository.dart';

/// M3c/任务 6a：字号 ± 按钮回调内 setTypography 调用 + clamp 边界（12/32）。
///
/// 用一个可记录 setTypography 调用、可变 typography 的 fake engine，
/// 验证点击顶栏字号 ± 按钮会把 clamp 后的字号传给 engine.setTypography。

class _RecordingFakeEngine implements ReaderEngine {
  _RecordingFakeEngine({this.initialFontSize = 18.0});

  final double initialFontSize;
  final StreamController<ReaderEngineState> _stateController =
      StreamController<ReaderEngineState>.broadcast();

  /// 最近一次 setTypography 接收到的设置（null 表示未调用）。
  TypographySettings? lastSetTypography;

  /// 当前排版设置。初始为 defaults + 自定义字号；setTypography 会更新它，
  /// 使 reader_body 的回调能读到「当前 fontSize」并计算 ±1。
  TypographySettings _typography =
      TypographySettings.defaults().copyWith(fontSize: 18.0);

  void reset({double? fontSize}) {
    final fs = fontSize ?? initialFontSize;
    _typography = TypographySettings.defaults().copyWith(fontSize: fs);
    lastSetTypography = null;
  }

  @override
  ReaderEngineState get state => const ReaderEngineReady();
  @override
  Stream<ReaderEngineState> get state$ => _stateController.stream;
  @override
  TableOfContents? get toc => null;
  @override
  TypographySettings get typography => _typography;
  @override
  Stream<Locator> get currentLocation$ => const Stream<Locator>.empty();
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
  void scrollBy(double delta, {Duration duration = const Duration(milliseconds: 200)}) {}
  @override
  Future<void> setTypography(TypographySettings settings) async {
    lastSetTypography = settings;
    _typography = settings;
  }
  @override
  Future<void> close() async {
    await _stateController.close();
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

void main() {
  late _RecordingFakeEngine engine;

  Future<ProviderContainer> pumpBody(
    WidgetTester tester, {
    List<Book> bookshelfBooks = const [],
  }) async {
    final bookRepo = FakeBookRepository();
    for (final b in bookshelfBooks) {
      bookRepo.addBook(b);
    }
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(_NoopRepo()),
      bookRepositoryProvider.overrideWith((ref) => bookRepo),
      libraryControllerProvider.overrideWith((ref) => LibraryController(
            bookRepository: bookRepo,
            bookTagsLookup: FakeBookTagsLookup(),
            settingsRepository: FakeSettingsRepository(),
          )),
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
    // Force chrome visible so the AppBar font buttons are rendered.
    if (!container.read(readerUiControllerProvider).chromeVisible) {
      container.read(readerUiControllerProvider.notifier).toggleChrome();
    }
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('font increase bumps fontSize by 1 (18 -> 19)', (tester) async {
    engine = _RecordingFakeEngine(initialFontSize: 18.0)..reset(fontSize: 18.0);
    await pumpBody(tester);

    await tester.tap(find.byKey(const Key('reader_font_increase')));
    await tester.pumpAndSettle();

    expect(engine.lastSetTypography, isNotNull);
    expect(engine.lastSetTypography!.fontSize, 19.0);
  });

  testWidgets('font decrease lowers fontSize by 1 (18 -> 17)', (tester) async {
    engine = _RecordingFakeEngine(initialFontSize: 18.0)..reset(fontSize: 18.0);
    await pumpBody(tester);

    await tester.tap(find.byKey(const Key('reader_font_decrease')));
    await tester.pumpAndSettle();

    expect(engine.lastSetTypography, isNotNull);
    expect(engine.lastSetTypography!.fontSize, 17.0);
  });

  testWidgets('font increase clamps at upper bound 32', (tester) async {
    engine = _RecordingFakeEngine(initialFontSize: 32.0)..reset(fontSize: 32.0);
    await pumpBody(tester);

    await tester.tap(find.byKey(const Key('reader_font_increase')));
    await tester.pumpAndSettle();

    expect(engine.lastSetTypography, isNotNull);
    expect(engine.lastSetTypography!.fontSize, 32.0);
  });

  testWidgets('font decrease clamps at lower bound 12', (tester) async {
    engine = _RecordingFakeEngine(initialFontSize: 12.0)..reset(fontSize: 12.0);
    await pumpBody(tester);

    await tester.tap(find.byKey(const Key('reader_font_decrease')));
    await tester.pumpAndSettle();

    expect(engine.lastSetTypography, isNotNull);
    expect(engine.lastSetTypography!.fontSize, 12.0);
  });

  testWidgets('bookshelf button opens the BookshelfDialog', (tester) async {
    engine = _RecordingFakeEngine(initialFontSize: 18.0)..reset(fontSize: 18.0);
    await pumpBody(tester, bookshelfBooks: [
      Book(
        id: 'b1',
        title: '甲书',
        author: null,
        format: BookFormat.epub,
        filePath: '/b1.epub',
        fileHash: 'h1',
        fileSizeBytes: 1,
        coverPath: null,
        addedAt: DateTime(2026, 1, 1),
        lastReadAt: null,
      ),
    ]);

    await tester.tap(find.byKey(const Key('reader_open_bookshelf')));
    await tester.pumpAndSettle();

    // The dialog renders a '书架' AppBar title and the current book title.
    expect(find.text('书架'), findsOneWidget);
    expect(find.text('甲书'), findsOneWidget);
  });
}
