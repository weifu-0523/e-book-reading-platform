import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

/// Verify the abstract API surface exists by writing a fake impl.
class _FakeEngine implements ReaderEngine {
  @override
  Future<String> get currentChapterPlainText => Future.value('hello world');

  @override
  List<PageBreak> get currentChapterPageBreaks => const [
        PageBreak(startOffset: 0, endOffset: 11),
      ];

  @override
  PageController? get pageController => null;

  @override
  Future<void> get chapterSwitchSettled => Future<void>.value();

  @override
  ReaderEngineState get state => throw UnimplementedError();

  @override
  Stream<ReaderEngineState> get state$ => throw UnimplementedError();

  @override
  Stream<Locator> get currentLocation$ => throw UnimplementedError();

  @override
  TableOfContents? get toc => throw UnimplementedError();

  @override
  TypographySettings get typography => throw UnimplementedError();

  @override
  PaginationMode get paginationMode => throw UnimplementedError();

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
  Future<void> setTypography(TypographySettings settings) async {}

  @override
  Future<void> setPaginationMode(PaginationMode mode) async {}

  @override
  Future<void> close() async {}

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

void main() {
  test('ReaderEngine exposes currentChapterPlainText', () async {
    final engine = _FakeEngine();
    expect(await engine.currentChapterPlainText, 'hello world');
  });

  test('ReaderEngine exposes currentChapterPageBreaks', () {
    final engine = _FakeEngine();
    expect(engine.currentChapterPageBreaks, hasLength(1));
    expect(
      engine.currentChapterPageBreaks.first,
      const PageBreak(startOffset: 0, endOffset: 11),
    );
  });
}
