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
import 'package:zhiyue/features/reader/pages/reader_page.dart';
import 'package:zhiyue/features/reader/providers/reader_engine_provider.dart';
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

    // Initially no drawer, no chrome.
    expect(find.byKey(const Key('reader_app_bar')), findsNothing);
    expect(find.text('第一章'), findsNothing);

    // Tap center to reveal chrome app bar.
    await tester.tapAt(const Offset(400, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_app_bar')), findsOneWidget);

    // Tap TOC icon (Icons.list).
    await tester.tap(find.byIcon(Icons.list));
    await tester.pumpAndSettle();

    // TocDrawer should now be visible.
    expect(find.text('第一章'), findsOneWidget);
  });

  testWidgets('chrome typography icon opens TypographyPanel', (tester) async {
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

    // Tap center to reveal chrome.
    await tester.tapAt(const Offset(400, 400));
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readerEngineForBookProvider
              .overrideWith((ref, arg) async => engine),
          notesRepositoryProvider.overrideWithValue(FakeNotesRepository()),
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

    // Reveal chrome app bar.
    await tester.tapAt(const Offset(400, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_app_bar')), findsOneWidget);

    // Tap notes icon (Icons.menu_book).
    await tester.tap(find.byIcon(Icons.menu_book));
    await tester.pumpAndSettle();

    // NotesDrawer header text should now be visible.
    expect(find.text('本书高亮与笔记'), findsOneWidget);
  });
}