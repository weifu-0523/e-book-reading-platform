import 'dart:async';
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine/rendering/renderer.dart';

import 'cfi_codec.dart';

/// epubx + flutter_widget_from_html 实现的 [EpubRenderer]。
///
/// 持有 [EpubBook]，自管 [ReaderEngineState] 状态机。
/// 章节渲染（build）、位置流（currentLocation$）、跳转（gotoLocator）
/// 已在 Task 12 实现。
class EpubxRenderer implements EpubRenderer {
  EpubxRenderer();

  final _stateController = StreamController<ReaderEngineState>.broadcast();
  final _locationController = StreamController<Locator>.broadcast();
  final ScrollController _scrollController = ScrollController();

  EpubBook? _book;
  int _currentChapterIndex = 0;
  TypographySettings _typography = TypographySettings.defaults();  // ⚠️ NOT const (M1 factory)
  PaginationMode _paginationMode = PaginationMode.paged;

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
      final bytes = await File(filePath).readAsBytes();
      final book = await EpubReader.readBook(bytes);
      _book = book;
      _currentChapterIndex = 0;
      _scrollController.removeListener(_onScroll);  // prevent duplicate on repeated calls
      _scrollController.addListener(_onScroll);
      _setState(const ReaderEngineReady());
    } catch (e, st) {
      debugPrint('EpubxRenderer.openFile failed: $filePath\n$e\n$st');
      _setState(ReaderEngineError(
        message: '$e',
        cause: e,
      ));  // ⚠️ plan said `cause: e` only — but message is required
    }
  }

  // ---- 章节渲染 / 位置流 / 跳转 (Task 12) ----

  /// 切换到指定章节（chapterIndex 基于 flatChapters）。
  void setChapter(int index) {
    final chapters = flatChapters;
    if (index < 0 || index >= chapters.length) return;
    _currentChapterIndex = index;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
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
    // Task 19 实现 CSS-like 注入
  }

  @override
  Future<void> setPaginationMode(PaginationMode mode) async {
    _paginationMode = mode;
    // Task 12-13 实现：重建 widget tree
  }

  @override
  Widget build(BuildContext context) {
    final chapters = flatChapters;
    if (chapters.isEmpty) return const SizedBox.shrink();
    final html = chapters[_currentChapterIndex].HtmlContent ?? '';

    return SingleChildScrollView(
      controller: _scrollController,
      child: HtmlWidget(html),
    );
  }

  @override
  Future<void> dispose() async {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    await _stateController.close();
    await _locationController.close();
  }
}
