import 'dart:async';
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/highlight_range.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';
import 'package:reader_engine/rendering/html_text_utils.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine/rendering/renderer.dart';

import 'cfi_codec.dart';
import 'html_highlight_injector.dart';
import 'paginator.dart';
import 'typography_css.dart';

/// epubx + flutter_widget_from_html 实现的 [EpubRenderer]。
///
/// 持有 [EpubBook]，自管 [ReaderEngineState] 状态机。
/// 章节渲染（build）、位置流（currentLocation$）、跳转（gotoLocator）
/// 已在 Task 12 实现。
class EpubxRenderer implements EpubRenderer {
  EpubxRenderer();

  final _stateController = StreamController<ReaderEngineState>.broadcast();
  final _locationController = StreamController<Locator>.broadcast();
  final StreamController<HighlightSelection> _selectionController =
      StreamController<HighlightSelection>.broadcast();
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  final Paginator _paginator = Paginator();

  EpubBook? _book;
  int _currentChapterIndex = 0;
  TypographySettings _typography = TypographySettings.defaults();  // ⚠️ NOT const (M1 factory)
  PaginationMode _paginationMode = PaginationMode.paged;
  final List<HighlightRange> _allHighlights = [];
  /// NOTE: keyed by chapter index only. MUST be cleared on any book-switch
  /// entry point (openFile / bookForTesting) — otherwise stale entries from
  /// the previous book shadow the new one at the same index.
  final Map<int, String> _plainTextCache = {};

  /// Cached page breaks for the current chapter in paged mode.
  /// Reset to null on chapter change / book switch / pagination mode change.
  List<PageBreak>? _cachedBreaks;

  ReaderEngineState _state = const ReaderEngineUnloaded();

  ReaderEngineState get state => _state;

  Stream<ReaderEngineState> get state$ async* {
    yield _state;  // emit current state immediately to new subscriber
    yield* _stateController.stream;  // forward future emissions
  }

  @override
  Stream<Locator> get currentLocation$ => _locationController.stream;

  /// 当前持有的书 —— Task 12+ 用，外部只读访问。
  EpubBook? get book => _book;

  /// 当前章节索引 —— Task 12+ 用。
  int get currentChapterIndex => _currentChapterIndex;

  /// 当前书的扁平化章节列表（Chapters + SubChapters 递归展开）。
  ///
  /// epubx 的 EpubChapter 含 SubChapters 嵌套；UI 与 cfi 都按扁平索引访问。
  List<EpubChapter> get flatChapters =>
      _flattenChapters(_book?.Chapters ?? const []);

  /// Plain text of the current chapter, parsed from
  /// `flatChapters[_currentChapterIndex].HtmlContent`.
  /// Cached per `chapterIndex` for the renderer's lifetime.
  Future<String> get currentChapterPlainText async {
    final chapters = flatChapters;
    if (chapters.isEmpty) return '';
    final cached = _plainTextCache[_currentChapterIndex];
    if (cached != null) return cached;
    final html = chapters[_currentChapterIndex].HtmlContent ?? '';
    final plain = HtmlTextUtils.htmlToPlainText(html);
    _plainTextCache[_currentChapterIndex] = plain;
    return plain;
  }

  /// Current chapter's page breaks in plainText coordinates.
  /// Returns `const []` in scroll mode or before first paged layout.
  List<PageBreak> get currentChapterPageBreaks {
    if (_paginationMode != PaginationMode.paged) return const [];
    final cached = _cachedBreaks;
    if (cached == null) return const [];
    return List.unmodifiable(cached);
  }

  /// 仅用于测试：直接注入一本书（跳过 openFile 的文件 IO 与解析）。
  @visibleForTesting
  set bookForTesting(EpubBook? book) {
    _plainTextCache.clear();
    _cachedBreaks = null;
    _book = book;
    _currentChapterIndex = 0;
  }

  List<EpubChapter> _flattenChapters(List<EpubChapter> chapters) {
    final result = <EpubChapter>[];
    for (final c in chapters) {
      result.add(c);
      result.addAll(_flattenChapters(c.SubChapters ?? const []));
    }
    return result;
  }

  void _setState(ReaderEngineState next) {
    _state = next;
    _stateController.add(next);
  }

  @override
  Future<void> openFile(String filePath) async {
    _setState(const ReaderEngineLoading());
    try {
      const timeout = Duration(seconds: 15);
      final bytes = await File(filePath).readAsBytes().timeout(timeout);
      final book = await EpubReader.readBook(bytes).timeout(timeout);
      _plainTextCache.clear();
      _cachedBreaks = null;
      _book = book;
      _currentChapterIndex = 0;
      _scrollController.removeListener(_onScroll);  // prevent duplicate on repeated calls
      _scrollController.addListener(_onScroll);
      _setState(const ReaderEngineReady());
    } on TimeoutException catch (e, st) {
      debugPrint('EpubxRenderer.openFile timeout: $filePath\n$e\n$st');
      _setState(ReaderEngineError(
        message: 'EPUB 解析超时（15秒），文件可能损坏',
        cause: TimeoutException('EPUB parse timeout (file: $filePath)'),
      ));
    } catch (e, st) {
      debugPrint('EpubxRenderer.openFile failed: $filePath\n$e\n$st');
      _setState(ReaderEngineError(message: '$e', cause: e));
    }
  }

  // ---- 章节渲染 / 位置流 / 跳转 (Task 12) ----

  /// 切换到指定章节（chapterIndex 基于 flatChapters）。
  void setChapter(int index) {
    final chapters = flatChapters;
    if (index < 0 || index >= chapters.length) return;
    _currentChapterIndex = index;
    _cachedBreaks = null;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _emitCurrentLocation();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _emitCurrentLocation();
  }

  void _emitCurrentLocation() {
    if (_book == null) return;
    final chapters = flatChapters;
    if (_currentChapterIndex >= chapters.length) return;
    final html = chapters[_currentChapterIndex].HtmlContent ?? '';
    final totalChars = html.length;
    final maxScroll = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final ratio =
        maxScroll == 0 ? 0.0 : (offset / maxScroll).clamp(0.0, 1.0);
    final charOffset = (ratio * totalChars).round().clamp(0, totalChars);
    _locationController.add(EpubCfiLocator(
      cfi: encode(_currentChapterIndex, charOffset),
      chapterIndex: _currentChapterIndex,
    ));
  }

  @override
  Future<TableOfContents> get toc async {
    final book = _book;
    if (book == null) return TableOfContents.empty();
    return TableOfContents(entries: _chaptersToToc(book.Chapters ?? const [], 0));
  }

  /// 把 epubx 的 EpubChapter 树转 TocEntry 树。
  ///
  /// chapterIndex 走 flatChapters 的扁平索引（与 cfi_codec 对齐）。
  /// startIndex 是当前 subtree 在扁平序列中的起始偏移。
  List<TocEntry> _chaptersToToc(List<EpubChapter> chapters, int startIndex) {
    final result = <TocEntry>[];
    var flatIndex = startIndex;
    for (final ch in chapters) {
      final selfIndex = flatIndex;
      result.add(TocEntry(
        title: ch.Title ?? '(无标题)',
        locator: EpubCfiLocator(
          cfi: encode(selfIndex, 0),
          chapterIndex: selfIndex,
        ),
        children: _chaptersToSubEntries(ch.SubChapters ?? const [], selfIndex),
      ));
      flatIndex += 1 + _countFlat(ch.SubChapters ?? const []);
    }
    return result;
  }

  List<TocEntry> _chaptersToSubEntries(List<EpubChapter> subChapters, int parentFlatIndex) {
    final result = <TocEntry>[];
    var flatIndex = parentFlatIndex + 1;
    for (final ch in subChapters) {
      final selfIndex = flatIndex;
      result.add(TocEntry(
        title: ch.Title ?? '(无标题)',
        locator: EpubCfiLocator(
          cfi: encode(selfIndex, 0),
          chapterIndex: selfIndex,
        ),
        children: _chaptersToSubEntries(ch.SubChapters ?? const [], selfIndex),
      ));
      flatIndex += 1 + _countFlat(ch.SubChapters ?? const []);
    }
    return result;
  }

  int _countFlat(List<EpubChapter> chapters) {
    var n = 0;
    for (final c in chapters) {
      n += 1 + _countFlat(c.SubChapters ?? const []);
    }
    return n;
  }

  @override
  Future<void> gotoLocator(Locator locator) async {
    if (locator is! EpubCfiLocator) return;
    final decoded = decode(locator.cfi);
    if (decoded == null) {
      debugPrint('EpubxRenderer.gotoLocator: invalid cfi ${locator.cfi}');
      return;
    }
    final chapters = flatChapters;
    if (decoded.chapterIndex < 0 || decoded.chapterIndex >= chapters.length) {
      return;
    }
    if (decoded.chapterIndex != _currentChapterIndex) {
      _currentChapterIndex = decoded.chapterIndex;
    }
    // 字符偏移 → 滚动像素（近似反推）：等下一帧 maxScrollExtent 可用再跳。
    final html = chapters[decoded.chapterIndex].HtmlContent ?? '';
    final totalChars = html.isEmpty ? 1 : html.length;
    final ratio = (decoded.charOffset / totalChars).clamp(0.0, 1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(max * ratio);
      _emitCurrentLocation();
    });
  }

  @override
  Future<void> setTypography(TypographySettings settings) async {
    _typography = settings;
    // Task 19: build() 直接读 _typography → TextStyle，无需手动重建 widget tree。
  }

  @override
  Future<void> setPaginationMode(PaginationMode mode) async {
    _paginationMode = mode;
    _cachedBreaks = null;
    // Task 12-13 实现：重建 widget tree
  }

  @override
  Future<void> injectHighlights(List<HighlightRange> highlights) async {
    _allHighlights
      ..clear()
      ..addAll(highlights);
  }

  /// 仅测试用：同步版本，避免 async setup。
  @visibleForTesting
  void injectHighlightsSync(List<HighlightRange> highlights) {
    _allHighlights
      ..clear()
      ..addAll(highlights);
  }

  /// 当前章节经过高亮注入后的 HTML（测试入口）。
  ///
  /// M3.2 简化：每章独立 0-based plain-text offset（不做跨章累计，spec §11 留 M3.x）。
  @visibleForTesting
  String currentHighlightedHtml() {
    final chapters = flatChapters;
    if (chapters.isEmpty) return '';
    final rawHtml = chapters[_currentChapterIndex].HtmlContent ?? '';
    final inChapter = _allHighlights.toList();
    return HtmlHighlightInjector.inject(rawHtml, inChapter);
  }

  @override
  Stream<HighlightSelection> get selection$ => _selectionController.stream;

  /// 由上层 SelectableRegion 在用户松开选区时调用。
  /// EpubxRenderer 自身不订阅 Flutter selection API（reader_engine 包不依赖 Flutter selection 框架）。
  void emitSelection(HighlightSelection selection) {
    _selectionController.add(selection);
  }

  @override
  Widget build(BuildContext context) {
    final chapters = flatChapters;
    if (chapters.isEmpty) return const SizedBox.shrink();
    final html = currentHighlightedHtml();
    final style = TypographyCss.textStyleFromSettings(_typography);
    final (fg, bg) = TypographyCss.themeColors(_typography.theme);
    final margin = _marginValue(_typography.pageMargin);

    return ColoredBox(
      color: bg,
      child: DefaultTextStyle(
        style: style.copyWith(color: fg),
        child: _paginationMode == PaginationMode.scroll
            ? _buildScroll(style, fg, html, margin)
            : _buildPaged(style, fg, html, margin),
      ),
    );
  }

  /// scroll 模式：单章 SingleChildScrollView + 富文本 HtmlWidget。
  Widget _buildScroll(TextStyle style, Color fg, String html, double margin) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Padding(
        padding: EdgeInsets.all(margin),
        child: HtmlWidget(
          html,
          textStyle: style.copyWith(color: fg),
        ),
      ),
    );
  }

  /// 把 [PageMargin] 映射为像素值，供渲染时 Padding 使用。
  double _marginValue(PageMargin m) {
    switch (m) {
      case PageMargin.compact:
        return 8.0;
      case PageMargin.normal:
        return 16.0;
      case PageMargin.wide:
        return 24.0;
    }
  }

  /// paged 模式：Paginator 把章节切成多页，PageView 左右翻页。
  ///
  /// M2.5 简化：paged 模式渲染**纯文本**（与 Paginator 的测量基准一致），
  /// 丢失 HtmlWidget 的富文本格式。富文本 + 真分页留到 M3。
  /// break 偏移以 Paginator 输出的 plainText 坐标为准（见 [Paginator.paginateWithText]）。
  Widget _buildPaged(TextStyle style, Color fg, String html, double margin) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 400,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 600,
        );
        final result = _paginator.paginateWithText(
          chapterHtml: html,
          viewport: viewport,
          typography: _typography,
        );
        final plain = result.plainText;
        final breaks = result.breaks;
        _cachedBreaks = breaks;
        return PageView.builder(
          controller: _pageController,
          itemCount: breaks.length,
          itemBuilder: (context, i) {
            final start = breaks[i].startOffset.clamp(0, plain.length);
            final end = breaks[i].endOffset.clamp(start, plain.length);
            final pageText = plain.substring(start, end);
            return Padding(
              padding: EdgeInsets.all(margin),
              child: Text(pageText, style: style.copyWith(color: fg)),
            );
          },
        );
      },
    );
  }

  @override
  Future<void> dispose() async {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    await _stateController.close();
    await _locationController.close();
    await _selectionController.close();
  }
}
