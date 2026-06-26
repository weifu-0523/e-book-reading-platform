import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/pages/reader_page.dart';
import 'package:zhiyue/features/reader/providers/reader_engine_provider.dart';

/// 用于测试的假 ReaderEngine —— 无需真实 EPUB 文件。
class FakeReaderEngine implements ReaderEngine {
  FakeReaderEngine({TableOfContents? toc}) : _toc = toc;

  final TableOfContents? _toc;
  final StreamController<Locator> _locationController =
      StreamController<Locator>.broadcast();

  TypographySettings _typography = TypographySettings.defaults();

  @override
  TableOfContents? get toc => _toc;

  @override
  TypographySettings get typography => _typography;

  @override
  Stream<Locator> get currentLocation$ => _locationController.stream;

  void emitLocation(Locator loc) {
    _locationController.add(loc);
  }

  @override
  Future<void> setTypography(TypographySettings settings) async {
    _typography = settings;
  }

  // ---- 以下为本测试不需要的实现 ----

  @override
  ReaderEngineState get state => const ReaderEngineReady();

  @override
  Stream<ReaderEngineState> get state$ => const Stream.empty();

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
        child: MaterialApp(home: ReaderPage(bookId: 'nonexistent')),
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
        child: const MaterialApp(home: ReaderPage(bookId: 'fake')),
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
        child: const MaterialApp(home: ReaderPage(bookId: 'fake')),
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
        child: const MaterialApp(home: ReaderPage(bookId: 'fake')),
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
}
