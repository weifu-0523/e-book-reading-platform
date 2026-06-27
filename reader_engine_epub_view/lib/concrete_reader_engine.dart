import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

import 'epubx_renderer.dart';

/// 包装 [EpubxRenderer] 的 [ReaderEngine] 具体实现。
///
/// 当 [BookRef.format] == epub 时由 provider 选择此实现。
class ConcreteEpubReaderEngine implements ReaderEngine {
  ConcreteEpubReaderEngine({required EpubxRenderer renderer})
      : _renderer = renderer;

  final EpubxRenderer _renderer;
  final _stateController = StreamController<ReaderEngineState>.broadcast();

  ReaderEngineState _state = const ReaderEngineUnloaded();
  TableOfContents? _toc;

  @override
  ReaderEngineState get state => _state;

  @override
  Stream<ReaderEngineState> get state$ => _stateController.stream;

  @override
  Stream<Locator> get currentLocation$ => _renderer.currentLocation$;

  @override
  Future<String> get currentChapterPlainText =>
      _renderer.currentChapterPlainText;

  @override
  List<PageBreak> get currentChapterPageBreaks =>
      _renderer.currentChapterPageBreaks;

  @override
  PageController? get pageController => _renderer.pageController;

  @override
  ValueListenable<int> get chapterRevisionNotifier =>
      _renderer.chapterRevisionNotifier;

  @override
  TableOfContents? get toc => _toc;

  @override
  TypographySettings get typography => TypographySettings.defaults();
  // 注：typography 实际由 _renderer 持有；为简洁此处返回默认。
  // M3 重构为 _renderer.typography。

  @override
  PaginationMode get paginationMode => PaginationMode.paged;

  @override
  Future<void> open(BookRef book) async {
    _setState(const ReaderEngineLoading());
    try {
      await _renderer.openFile(book.filePath);
      _toc = await _renderer.toc;
      _setState(const ReaderEngineReady());
    } catch (e, st) {
      _setState(ReaderEngineError(message: '打开书籍失败: $e', cause: e));
      debugPrint('$e\n$st');
    }
  }

  void _setState(ReaderEngineState s) {
    _state = s;
    _stateController.add(s);
  }

  @override
  Future<void> gotoLocator(Locator locator) => _renderer.gotoLocator(locator);

  /// 打开书籍并尝试恢复到上次位置（spec §6.3 CFI fallback）。
  ///
  /// CFI 解码失败时降级到第一章开头，不抛异常。
  Future<void> openWithLastProgress({
    required BookRef book,
    required Locator? lastLocator,
  }) async {
    await open(book);
    if (_state is ReaderEngineReady && lastLocator != null) {
      try {
        await gotoLocator(lastLocator);
      } catch (e, st) {
        // spec §6.3：CFI 解码失败降级到第一章
        debugPrint('CFI restore failed: $e\n$st');
      }
    }
  }

  @override
  Future<void> gotoTocEntry(TocEntry entry) =>
      _renderer.gotoLocator(entry.locator);

  @override
  Future<void> nextSpine() async {
    final renderer = _renderer;
    final currentIdx = renderer.currentChapterIndex;
    final nextIdx = currentIdx + 1;
    if (nextIdx < renderer.flatChapters.length) {
      renderer.setChapter(nextIdx);
    }
    // At end of book: no-op (could emit event later)
  }

  @override
  Future<void> previousSpine() async {
    final renderer = _renderer;
    final currentIdx = renderer.currentChapterIndex;
    if (currentIdx > 0) {
      renderer.setChapter(currentIdx - 1);
    }
    // At start of book: no-op
  }

  @override
  Future<void> setTypography(TypographySettings settings) =>
      _renderer.setTypography(settings);

  @override
  Future<void> setPaginationMode(PaginationMode mode) =>
      _renderer.setPaginationMode(mode);

  @override
  Future<void> close() async {
    await _renderer.dispose();
    await _stateController.close();
  }

  @override
  Widget build(BuildContext context) => _renderer.build(context);
}
