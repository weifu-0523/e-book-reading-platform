import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

/// 接口可被实现的 smoke test。
class _FakeEngine implements ReaderEngine {
  @override
  ReaderEngineState state = const ReaderEngineUnloaded();

  @override
  Stream<ReaderEngineState> get state$ => const Stream.empty();

  @override
  Stream<Locator> get currentLocation$ => const Stream.empty();

  @override
  Future<String> get currentChapterPlainText => Future.value('');

  @override
  List<PageBreak> get currentChapterPageBreaks => const [];

  @override
  PageController? get pageController => null;

  @override
  TableOfContents? get toc => null;

  @override
  TypographySettings get typography => TypographySettings.defaults();

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
  Future<void> setTypography(TypographySettings settings) async {}
  @override
  Future<void> setPaginationMode(PaginationMode mode) async {}
  @override
  Future<void> close() async {}
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

void main() {
  test('ReaderEngine can be implemented', () {
    final engine = _FakeEngine();
    expect(engine.state, isA<ReaderEngineUnloaded>());
    expect(engine.paginationMode, PaginationMode.paged);
  });
}
