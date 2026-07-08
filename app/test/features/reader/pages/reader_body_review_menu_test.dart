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
import 'package:zhiyue/features/ai/widgets/review_preview_sheet.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/pages/reader_body.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

/// 用于测试的假 ReaderEngine。仅返回 Ready 状态以便 ReaderBody 走 data 路径。
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
  void scrollBy(double delta, {Duration duration = const Duration(milliseconds: 200)}) {}

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
  /// ReaderBody 在 build() 内会 await bookRepositoryProvider.getById(...)
  /// 然后 fire-and-forget 缓存。Tests 不依赖 _cachedBook，所以 repository 可以
  /// 用 sqlite in-memory 或 fake。这里直接 override 一个返回 null 的实例。
  Future<ProviderContainer> pumpReaderBody(
    WidgetTester tester, {
    required String bookId,
    required Book? book,
  }) async {
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(_NoopRepo()),
      bookRepositoryProvider.overrideWithValue(_FakeBookRepo(book)),
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
    // ReaderBody build 后会立即触发 ReaderEngineReady 状态。
    // 等 fire-and-forget 的 _refreshBookCache() Future 完成（_cachedBook 赋值）。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    return container;
  }

  /// Center-tap 不再触发 chrome（T5 已移除该手势）。
  /// 测试通过 provider 直接切换 chromeVisible。
  void openChrome(ProviderContainer container) {
    container.read(readerUiControllerProvider.notifier).toggleChrome();
  }

  testWidgets(
      'reader overflow menu shows "回顾本章" item once chrome is open',
      (tester) async {
    final container = await pumpReaderBody(
        tester, bookId: 'b-epub', book: _epubBook('b-epub'));

    openChrome(container);
    await tester.pumpAndSettle();

    // 打开 PopupMenuButton。
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('回顾本章'), findsOneWidget);
  });

  testWidgets('reader overflow menu "回顾本章" opens ReviewPreviewSheet',
      (tester) async {
    final container = await pumpReaderBody(
        tester, bookId: 'b-epub-2', book: _epubBook('b-epub-2'));

    openChrome(container);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('回顾本章'));
    // 不使用 pumpAndSettle：ReviewPreviewSheet 默认 _NoOpBookReviewer 立即
    // emit ReviewErrorEvent，但 ErrorView 含有动画/重试按钮可能持续重绘。
    // 这里只需要确认 sheet 被推入 widget 树即可。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // ReviewPreviewSheet 在 showModalBottomSheet 中渲染，标题走 reviewSheetTitle。
    expect(find.byType(ReviewPreviewSheet, skipOffstage: false),
        findsOneWidget);
  });

  // PDF 跳过路径：ReaderBody 把 onOpenReview=null 传给 ReaderScaffold
  // （基于 `engine is PdfReaderEngine`），所以 PDF 不渲染 PopupMenuButton。
  // 该路径由 reader_page_pdf_test.dart 体系覆盖（那里持有 PdfReaderEngine）。
}
