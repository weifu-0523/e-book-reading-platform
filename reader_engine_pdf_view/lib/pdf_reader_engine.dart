import 'package:flutter/widgets.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

import 'pdf_renderer.dart';

/// 包装 [PdfRenderer] 的 [ReaderEngine] 具体实现（Page-as-Chapter 映射）。
///
/// PDF 第 N 页（pdfrx 1-based）映射到引擎 chapterIndex N-1。
/// EPUB-flavored 成员（currentChapterPageBreaks、chapterSwitchSettled、
/// pageController）返回 empty/null/no-op —— pdfrx 自管滚动与渲染。
///
/// openWithLastProgress 镜像 [ConcreteEpubReaderEngine] 的恢复模式。
class PdfReaderEngine implements ReaderEngine {
  PdfReaderEngine({required PdfRenderer renderer}) : _renderer = renderer;

  final PdfRenderer _renderer;

  TypographySettings _typography = TypographySettings.defaults();

  @override
  ReaderEngineState get state => _renderer.state;

  @override
  Stream<ReaderEngineState> get state$ => _renderer.state$;

  @override
  Stream<Locator> get currentLocation$ => _renderer.currentLocation$;

  @override
  Future<void> open(BookRef book) => _renderer.openFile(book.filePath);

  @override
  Future<void> gotoLocator(Locator locator) => _renderer.gotoLocator(locator);

  @override
  Future<void> gotoTocEntry(TocEntry entry) =>
      _renderer.gotoLocator(entry.locator);

  @override
  Future<void> nextSpine() async {
    _renderer.setPage(_renderer.currentPage + 1);
  }

  @override
  Future<void> previousSpine() async {
    _renderer.setPage(_renderer.currentPage - 1);
  }

  @override
  Future<void> setTypography(TypographySettings settings) async {
    _typography = settings;
    return _renderer.setTypography(settings);
  }

  @override
  Future<void> setPaginationMode(PaginationMode mode) async {
    // PDF 强制 scroll mode；noop
  }

  @override
  Widget build(BuildContext context) => _renderer.build(context);

  @override
  Future<void> close() => _renderer.dispose();

  // ----- ReaderEngine EPUB-flavored members (Page-as-Chapter semantics) -----

  @override
  Future<String> get currentChapterPlainText async => '';

  @override
  List<PageBreak> get currentChapterPageBreaks => const [];

  @override
  PageController? get pageController => null;

  @override
  Future<void> get chapterSwitchSettled async {}

  @override
  TableOfContents? get toc => null;

  @override
  TypographySettings get typography => _typography;

  @override
  PaginationMode get paginationMode => PaginationMode.scroll;

  // ----- Selection forwarding (EpubxRenderer pattern) -----
  //
  // 非 ReaderEngine 接口成员；上层（reader_page）按需订阅以接收选区事件。
  Stream<HighlightSelection> get selection$ => _renderer.selection$;

  // ----- Helper: open with last known progress (mirrors ConcreteEpubReaderEngine) -----

  /// 打开书籍并尝试恢复到上次位置。
  ///
  /// PDF locator 解码失败时降级到首页，不抛异常。
  Future<void> openWithLastProgress({
    required BookRef book,
    required Locator? lastLocator,
  }) async {
    await open(book);
    if (_renderer.state is ReaderEngineReady && lastLocator != null) {
      try {
        await gotoLocator(lastLocator);
      } catch (e, st) {
        debugPrint('PDF locator restore failed: $e\n$st');
      }
    }
  }
}
