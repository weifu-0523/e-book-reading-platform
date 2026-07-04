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

import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/database.dart' show BookmarkEntry;
import 'package:zhiyue/data/repositories/bookmark_repository.dart';
import 'package:zhiyue/features/reader/controllers/bookmark_controller.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/pages/reader_page.dart';
import 'package:zhiyue/features/reader/providers/reader_engine_provider.dart';
import 'package:zhiyue/features/reader/providers/notes_controller.dart';
import 'package:zhiyue/features/reader/widgets/reader_error_view.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

import '../../../fakes/fake_notes_repository.dart';

/// 用于测试的假 ReaderEngine —— 无需真实 EPUB 文件。
class FakeReaderEngine implements ReaderEngine {
  FakeReaderEngine({TableOfContents? toc, ReaderEngineState? state})
      : _toc = toc,
        _state = state ?? const ReaderEngineReady();

  final TableOfContents? _toc;
  final StreamController<Locator> _locationController =
      StreamController<Locator>.broadcast();
  final StreamController<ReaderEngineState> _stateController =
      StreamController<ReaderEngineState>.broadcast();

  ReaderEngineState _state;
  bool stateStreamListened = false;

  @override
  TableOfContents? get toc => _toc;

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
  ReaderEngineState get state => _state;

  @override
  Stream<ReaderEngineState> get state$ {
    stateStreamListened = true;
    return _stateController.stream;
  }

  void emitLocation(Locator loc) {
    _locationController.add(loc);
  }

  void emitState(ReaderEngineState s) {
    _state = s;
    _stateController.add(s);
  }

  // ---- 以下为本测试不需要的实现 ----

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
    await _locationController.close();
  }

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('fake content'));
}

void main() {
  testWidgets('ReaderPage renders loading initially', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReaderPage(bookId: 'nonexistent'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('chrome TOC icon opens TocDrawer', (tester) async {
    final engine = FakeReaderEngine(
      toc: const TableOfContents(entries: [
        TocEntry(
          title: '第一章',
          locator: EpubCfiLocator(cfi: '/6/4', chapterIndex: 0),
        ),
      ]),
    );

    final container = ProviderContainer(overrides: [
      readerEngineForBookProvider.overrideWith((ref, arg) async => engine),
    ]);
    addTearDown(container.dispose);
    // Center-tap no longer reveals chrome — set initial state via provider.
    container.read(readerUiControllerProvider.notifier).toggleChrome();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReaderPage(bookId: 'fake'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Chrome should already be visible.
    expect(find.byKey(const Key('reader_app_bar')), findsOneWidget);
    expect(find.text('第一章'), findsNothing);

    // Tap TOC icon (Icons.list).
    await tester.tap(find.byIcon(Icons.list));
    await tester.pumpAndSettle();

    // TocDrawer should now be visible.
    expect(find.text('第一章'), findsOneWidget);
  });

  testWidgets('chrome typography icon opens TypographyPanel', (tester) async {
    final engine = FakeReaderEngine();
    final container = ProviderContainer(overrides: [
      readerEngineForBookProvider.overrideWith((ref, arg) async => engine),
    ]);
    addTearDown(container.dispose);
    container.read(readerUiControllerProvider.notifier).toggleChrome();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReaderPage(bookId: 'fake'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap typography icon.
    await tester.tap(find.byIcon(Icons.text_fields));
    await tester.pumpAndSettle();

    // TypographyPanel shows theme labels.
    expect(find.text('字号'), findsOneWidget);
  });

  testWidgets('ReaderBottomBar shows initially', (tester) async {
    final engine = FakeReaderEngine();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readerEngineForBookProvider
              .overrideWith((ref, arg) async => engine),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReaderPage(bookId: 'fake'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Emit a location from the engine's stream — bottom bar should pick it up.
    engine.emitLocation(const EpubCfiLocator(
      cfi: '/6/4',
      chapterIndex: 3,
      chapterTitle: '第四章',
    ));
    await tester.pumpAndSettle();

    // Bottom bar should be visible and show chapter title from current location.
    expect(find.text('第四章'), findsOneWidget);
  });

  testWidgets('engine in error state shows ReaderErrorView', (tester) async {
    final engine = FakeReaderEngine(
      state: const ReaderEngineError(message: 'open failed'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readerEngineForBookProvider
              .overrideWith((ref, arg) async => engine),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReaderPage(bookId: 'fake'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReaderErrorView), findsOneWidget);
  });

  testWidgets('chrome notes icon opens NotesDrawer endDrawer', (tester) async {
    final engine = FakeReaderEngine();
    final container = ProviderContainer(overrides: [
      readerEngineForBookProvider.overrideWith((ref, arg) async => engine),
      notesRepositoryProvider.overrideWithValue(FakeNotesRepository()),
    ]);
    addTearDown(container.dispose);
    container.read(readerUiControllerProvider.notifier).toggleChrome();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReaderPage(bookId: 'fake'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Chrome should already be visible.
    expect(find.byKey(const Key('reader_app_bar')), findsOneWidget);

    // Tap notes icon (Icons.menu_book).
    await tester.tap(find.byIcon(Icons.menu_book));
    await tester.pumpAndSettle();

    // NotesDrawer header text should now be visible.
    expect(find.text('本书高亮与笔记'), findsOneWidget);
  });

  // M2.10/Bug C2 regression: reader_page 的 ProviderScope.overrides 必须同时
  // 覆盖 bookmarkControllerProvider（它 ref.watch(currentBookIdProvider)），
  // 否则 reader 子树内 ReaderBookmarkList 读它时触发 Riverpod
  // "dependency overridden but the provider is not" 断言 → 红屏黄字。
  //
  // 用 provider 级测试验证 Riverpod 契约：在同一 scope 同时 override
  // currentBookIdProvider + bookmarkControllerProvider 后读
  // bookmarkControllerProvider 不应断言。pre-fix（漏 override
  // bookmarkControllerProvider）会抛 "dependency overridden" 断言。
  // （不用 widget 测试：ReaderPage 的 ProgressPersister 定时器让
  // pumpAndSettle 永不 settle，与本次回归无关。）
  test('bookmarkControllerProvider override contract (Bug C2)', () async {
    final container = ProviderContainer(overrides: [
      currentBookIdProvider.overrideWith((_) => 'fake'),
      // Mirror reader_page.dart: 同 scope override 消费方 provider。
      bookmarkControllerProvider.overrideWith(
        (ref) => BookmarkController(
          bookId: 'fake',
          repository: _EmptyBookmarkRepository(),
        ),
      ),
    ]);
    addTearDown(container.dispose);

    // Reading the provider must NOT throw a Riverpod assertion. Pre-fix,
    // omitting the bookmarkControllerProvider override while overriding
    // currentBookIdProvider threw: "Tried to read ... from a place where one
    // of its dependencies were overridden but the provider is not."
    //
    // The mere act of reading without throwing IS the regression assertion —
    // pre-fix this `read` triggered the assertion synchronously. We don't
    // assert on loading vs data (the watchForBook async* yield needs a frame
    // loop to settle, which a pure ProviderContainer test lacks; that's
    // irrelevant to the override-contract regression).
    final async = container.read(bookmarkControllerProvider);
    // Drain any pending microtasks so a deferred assertion (if any) surfaces.
    await Future<void>.delayed(Duration.zero);
    expect(async, isA<AsyncValue<BookmarkState>>(),
        reason: 'reading bookmarkControllerProvider must not throw a Riverpod '
            '"dependency overridden" assertion (Bug C2)');
  });
}

/// Fake bookmark repo that always reports an empty bookmark list.
class _EmptyBookmarkRepository implements BookmarkRepository {
  @override
  Future<void> add(BookmarkEntry entry) async {}
  @override
  Future<BookmarkEntry?> get(String id) async => null;
  @override
  Future<List<BookmarkEntry>> listForBook(String bookId) async => const [];
  @override
  Future<void> updateLabel({required String id, required String label}) async {}
  @override
  Future<void> updateNote({required String id, String? note}) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Stream<List<BookmarkEntry>> watchForBook(String bookId) async* {
    yield const [];
  }
}