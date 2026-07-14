// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/highlight_range.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine/rendering/renderer.dart';

import 'cfi_codec.dart';
import 'epub_image_inliner.dart';
import 'plain_text_utils.dart';
import 'html_chapter_source.dart';
import 'html_highlight_injector.dart';
import 'html_slicer.dart';
import 'html_to_inline_span_converter.dart';
import 'line_metrics_paginator.dart';
import 'paginator.dart';
import 'rendered_html_measurer.dart';
import 'selectable_page_view.dart';
import 'src/chapter_end_event.dart';
import 'typography_css.dart';
import 'typography_style_injector.dart';

/// epubx + flutter_widget_from_html 实现的 [EpubRenderer]。
///
/// 持有 [EpubBook]，自管 [ReaderEngineState] 状态机。
/// 章节渲染（build）、位置流（currentLocation$）、跳转（gotoLocator）
/// 已在 Task 12 实现。
class EpubxRenderer implements EpubRenderer {
  EpubxRenderer();

  /// Scroll-mode chapter-end detection threshold (pixels from bottom).
  ///
  /// When `_scrollController.position.pixels >= maxScrollExtent -
  /// [_kChapterEndScrollThresholdPx]`, the renderer considers the reader
  /// "at chapter end" and emits a [ChapterEndEvent].
  static const double _kChapterEndScrollThresholdPx = 64;

  /// M3b/任务8：章内程序化翻页动画时长与曲线。
  ///
  /// PPT 式平移过渡：300ms easeInOutCubic 比 200ms easeOut 更顺滑，
  /// 有进出节奏。跨章 [PageController.jumpToPage] 保持瞬切（见
  /// [nextPage] 章末换章、[previousPage] 章首换章路径），动画会闪烁。
  static const Duration _pageAnimDuration = Duration(milliseconds: 300);
  static const Curve _pageAnimCurve = Curves.easeInOutCubic;

  final _stateController = StreamController<ReaderEngineState>.broadcast();
  final _locationController = StreamController<Locator>.broadcast();
  final StreamController<HighlightSelection> _selectionController =
      StreamController<HighlightSelection>.broadcast();
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  final Paginator _paginator = Paginator();

  EpubBook? _book;

  /// M4.6-fix14: EPUB 图片资源 inliner，由 [openFile] / [bookForTesting]
  /// 在 _book 赋值时同步构建。EPUB 路径专用（MD/TXT 路径走 openChapters，
  /// 不构造 inliner）。null 表示无图片资源或非 EPUB 路径。
  EpubImageInliner? _imageInliner;
  int _currentChapterIndex = 0;
  TypographySettings _typography = TypographySettings.defaults();  // ⚠️ NOT const (M1 factory)
  // 2026-07-08：默认改 scroll（用户偏好滚动阅读）。setPaginationMode 仍可切换。
  PaginationMode _paginationMode = PaginationMode.scroll;

  /// M4.5: 格式无关的章节数据源。EPUB 路径由 [openFile] 解析 epubx 后填充；
  /// Markdown/TXT 路径由 [openChapters] 直接填充（不经 epubx）。所有渲染/
  /// 分页/高亮/双页逻辑只读 [_chapters]（通过 [flatChapterHtmlAt] /
  /// [chapterCount]），不直接碰 [_book] —— 这样 EPUB 与 MD/TXT 共享同一套
  /// 渲染管道，EPUB 路径零回归（openFile 仍走 epubx，填充本字段后委托渲染）。
  List<HtmlChapterSource> _chapters = const [];

  /// Map from `EpubChapter.ContentFileName` to its deduped index in
  /// [_chapters]. Populated by [_buildDedupedChaptersAndMap]. Empty for
  /// MD/TXT path (openChapters) — those sources have no ContentFileName.
  Map<String, int> _contentFileToChapterIndex = const {};

  /// Read-only access to the current [TypographySettings].
  ///
  /// M2.6/T3: exposed so [ConcreteEpubReaderEngine.typography] can forward
  /// the renderer's live value to UI (e.g. TypographyPanel) instead of a
  /// const default. Pre-fix, panel onChanged wrote to a discarded object.
  TypographySettings get typography => _typography;

  /// 2026-07-08 review fixup: Read-only access to the current
  /// [PaginationMode]. ConcreteEpubReaderEngine.paginationMode forwards
  /// this so reader_body's `engine.paginationMode == PaginationMode.paged`
  /// checks reflect the live mode after setPaginationMode. Pre-fix the
  /// adapter hard-coded paged, so toggling scroll mode updated the field
  /// silently and reader_body kept using paged branches (m4.7b toggle UI
  /// never reflected the new mode).
  PaginationMode get paginationMode => _paginationMode;

  /// M2.9: 双页模式（书脊式左右两页）。
  ///
  /// 当 `true` 且当前章节为 paged 模式时，[_buildPaged] 渲染单 PageView，
  /// 每个 item（spread）含两个并列的 HtmlWidget（左页 + 右页）。Paginator
  /// 仍按单页宽度测量（调用方 halve viewport.width 后传入），每 break =
  /// 一列内容；spread[i] = breaks[i*2] + breaks[i*2+1]。
  ///
  /// 翻页：nextPage/previousPage 步进 1 个 spread（PageView 原生），章末
  /// 判定用 spreadCount。
  ///
  /// 切换：通过 [setDualPageMode] 设置（非直接写字段），它清空
  /// `_cachedBreaks`、reset page 到 0、emit ReaderEngineReady 触发 rebuild。
  /// reader_body 的 LayoutBuilder 在宽屏时调 setDualPageMode(true)。
  bool _dualPageMode = false;

  /// M2.9: 双页模式只读访问（测试 + reader_body 读取当前状态用）。
  bool get dualPageMode => _dualPageMode;

  /// M2.9: 切换双页模式。
  ///
  /// 必须用本方法（非直接写 `_dualPageMode`），因为切换后需：
  /// 1. 清空 `_cachedBreaks`（新宽度下 break 数变了）
  /// 2. `_pageController.jumpToPage(0)`（page 索引可能越新 itemCount 界）
  /// 3. emit ReaderEngineReady 让 reader_body rebuild → _buildPaged 用新分支
  void setDualPageMode(bool value) {
    if (_dualPageMode == value) return;
    _dualPageMode = value;
    _cachedBreaks = null;
    _pendingJumpToLastPage = false;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _beginChapterSwitch();
    _stateController.add(const ReaderEngineReady());
  }

  /// M2.9: 当前 spread 数（双页模式）或 page 数（单页模式）。
  /// paged 模式下供页码显示与章末判定用。非 paged / breaks 未算出返回 0。
  int get currentSpreadCount {
    final breaks = _cachedBreaks;
    if (breaks == null || breaks.isEmpty) return 0;
    if (!_dualPageMode) return breaks.length;
    return (breaks.length + 1) ~/ 2;
  }

  /// M2.9: 当前 spread/page 索引（0-based）。PageController 未挂载返回 0。
  int get currentSpreadIndex {
    if (!_pageController.hasClients) return 0;
    return _pageController.page?.round() ?? 0;
  }

  final List<HighlightRange> _allHighlights = [];
  /// NOTE: keyed by chapter index only. MUST be cleared on any book-switch
  /// entry point (openFile / bookForTesting) — otherwise stale entries from
  /// the previous book shadow the new one at the same index.
  final Map<int, String> _plainTextCache = {};

  /// v1.11.7-alpha+1 hotfix: per-chapter plain text length cache (PlainTextUtils
  /// coordinate system). Used by [_emitCurrentLocation] / [gotoLocator] scroll
  /// mode to compute the scroll-position ratio. Must match the coordinate
  /// system of [PlainTextUtils.anchorToPlainOffset] used by [_locatorForChapter]
  /// — otherwise TOC clicks would land at wrong scroll positions.
  ///
  /// Why a SEPARATE cache from [_plainTextCache]: that one stores the
  /// `HtmlToInlineSpanConverter` plain text (FFFC image placeholders + EM SPACE
  /// indent prefixes), which is a DIFFERENT coordinate system. PlainTextUtils
  /// does simple tag-strip + entity decode — different output, different length.
  /// See epubx_renderer.dart:472-483 for the converter vs DOM-text divergence
  /// history.
  final Map<int, int> _plainTextLengthCache = {};

  /// Cached page breaks for the current chapter in paged mode.
  /// Reset to null on chapter change / book switch / pagination mode change.
  List<PageBreak>? _cachedBreaks;

  /// M4.6-fix16: 当前章节每段实际渲染高度（由 [RenderedHtmlMeasurer] 测出）。
  /// null 表示尚未测量或已失效。LayoutBuilder 重跑时若 key 不匹配则重新测量。
  /// 重测量期间旧值不可用（drift），故清空而非渐进更新。
  ///
  /// M4.8: 当前新管道（converter → LineMetricsPaginator）不写入此字段——
  /// pure-text 章节直接用 [_lineBreaks]，image 章节用 [_paginator] 估算。
  /// 保留字段以备 Phase 6 fwfh 回退路径（image 章节 + ≥3 unsupported tags
  /// 时切回 RenderedHtmlMeasurer 实测）。
  // ignore: unused_field
  List<double>? _measuredHeights;

  /// M4.8: 新管道（converter → LineMetricsPaginator）产出。pure-text 章节走此
  /// 路径；image / fallback 章节仍走 [_measuredHeights]（fwfh 实测）。null 表示
  /// 尚未测量或已失效（章节切换 / 排版变更 / 窗口 resize）。
  ConvertedSpans? _convertedSpans;

  /// M4.8: [_convertedSpans] 对应的 page breaks（同 plainText 坐标空间）。
  /// 由 [_InlineSpanMeasurer] 报告。null 表示尚未测量。
  List<PageBreak>? _lineBreaks;

  /// M4.8-6.2: When true, the current chapter has ≥3 unsupported HTML tags
  /// and should render via the legacy [HtmlWidget] path instead of
  /// [SelectablePageView] + [SelectableText.rich]. This gives users proper
  /// rendering of complex elements (tables, SVG, video) that the inline span
  /// converter can only flatten.
  bool _fwfhFallbackForCurrentChapter = false;

  /// M4.6-fix16: 上次测量时的参数指纹（html + viewport + typography + margin）。
  /// LayoutBuilder 重跑时与当前参数比较：匹配则复用 [_measuredHeights]，
  /// 不匹配则触发重测量。避免窗口 resize / 排版变更后用 stale heights 算 breaks。
  _MeasurementKey? _measurementKey;

  /// M2.8/B2 (Bug #6 cross-chapter back-paging): 章首左翻换上一章时，应停
  /// 在上一章**末页**而不是首页（与 Kindle / 微信读书等标准阅读器一致）。
  ///
  /// 困难点：`setChapter` 调用时 `_cachedBreaks` 已被清空（新章节未分页），
  /// 不知道末页 index；必须等下一帧 LayoutBuilder 重跑、`_cachedBreaks`
  /// 被重新填充后才能 jumpToPage。本 flag 由 [previousPage] 章首分支 arm，
  /// [_maybeApplyPendingLastPageJump] 在分页填充后消费（一次后自动清零）。
  bool _pendingJumpToLastPage = false;

  /// Completer that resolves once the current chapter switch has settled.
  ///
  /// Paged-mode `_cachedBreaks` is only repopulated when the LayoutBuilder
  /// inside [build] re-runs (i.e., on the next frame after [setChapter] /
  /// cross-chapter [gotoLocator] / [bookForTesting]). Callers that need to
  /// read [currentChapterPageBreaks] for the new chapter should
  /// `await chapterSwitchSettled` instead of guessing via `endOfFrame`.
  ///
  /// `_chapterSwitchCompleter` is null while no switch is in progress; in
  /// that state [chapterSwitchSettled] returns an already-completed Future.
  /// Each call to [_beginChapterSwitch] arms a fresh completer and schedules
  /// it to complete on the next post-frame callback.
  Completer<void>? _chapterSwitchCompleter;

  /// Broadcast stream for [chapterEndEvents]. Emits at most once per chapter
  /// visit (gated by [_chapterEndFiredForCurrentChapter], which [setChapter]
  /// resets).
  final StreamController<ChapterEndEvent> _chapterEndController =
      StreamController<ChapterEndEvent>.broadcast();

  /// True after a [ChapterEndEvent] has been emitted for the current chapter
  /// visit. Reset to `false` in [setChapter] so each visit can re-emit.
  bool _chapterEndFiredForCurrentChapter = false;

  /// Emits a [ChapterEndEvent] when the reader reaches the last page of the
  /// current chapter (paged mode) or scrolls within 64px of the bottom
  /// (scroll mode). Fires at most once per chapter visit — the internal
  /// flag resets when [setChapter] runs.
  Stream<ChapterEndEvent> get chapterEndEvents => _chapterEndController.stream;

  /// Test-only entry to [_maybeEmitChapterEnd]. Lets unit tests verify the
  /// emit logic without pumping the widget tree.
  @visibleForTesting
  void maybeEmitChapterEndForTest() => _maybeEmitChapterEnd();

  /// Emit a [ChapterEndEvent] if the current view position is at the chapter
  /// end (last page in paged mode, or within 64px of bottom in scroll mode).
  /// No-op if already fired for the current chapter visit, or if no book is
  /// loaded, or if the scroll/page controllers have no clients yet.
  void _maybeEmitChapterEnd() {
    if (_chapterEndFiredForCurrentChapter) return;
    if (_chapters.isEmpty) return;

    bool isAtChapterEnd = false;
    if (_paginationMode == PaginationMode.paged) {
      // M2.9: 双页模式下 _pageController.page 是 spread 索引（PageView 的
      // itemCount = spreadCount），章末判定要用 spreadCount - 1，
      // 不是 breaks.length - 1（那是单页模式下的 page 数）。
      final spreadCount = currentSpreadCount;
      if (spreadCount > 0 && _pageController.hasClients) {
        final page = _pageController.page?.round() ?? 0;
        isAtChapterEnd = page >= spreadCount - 1;
      }
    } else {
      if (_scrollController.hasClients) {
        final pos = _scrollController.position;
        isAtChapterEnd = pos.pixels >= pos.maxScrollExtent - _kChapterEndScrollThresholdPx;
      }
    }

    if (!isAtChapterEnd) return;
    _chapterEndFiredForCurrentChapter = true;
    _chapterEndController.add(ChapterEndEvent(
      chapterIndex: _currentChapterIndex,
      isLastChapter: _currentChapterIndex >= _chapters.length - 1,
    ));
  }

  /// M2.8/B1: 翻到下一页（章内分页）；若已在章末则换到下一章首页。
  ///
  /// paged 模式下：读 `_pageController.page` 判断是否在最后一页，是则
  /// `setChapter(idx+1)`（换章会 jumpToPage(0)），否则 `nextPage()`。
  /// scroll 模式下：直接 `nextSpine()` 等价行为（scroll 没有章内分页概念，
  /// 用户用滚轮自管滚动，tap zone 在 scroll 下应换章）。
  /// 返回 true 表示发生了翻页（供调用方决定是否做额外动效）。
  bool nextPage() {
    if (_chapters.isEmpty) return false;
    if (_paginationMode == PaginationMode.scroll) {
      return _nextChapterIfPossible();
    }
    final breaks = _cachedBreaks;
    if (!_pageController.hasClients || breaks == null || breaks.isEmpty) {
      // breaks 还没算出（首次 build 前）或 controller 未挂载：fallback 换章
      return _nextChapterIfPossible();
    }
    final currentPage = _pageController.page?.round() ?? 0;
    // M2.9: 双页模式下 currentPage 是 spread 索引，章末判定用 spreadCount。
    final spreadCount = currentSpreadCount;
    if (currentPage >= spreadCount - 1) {
      // 章末：换下一章
      return _nextChapterIfPossible();
    }
    _pageController.nextPage(
      duration: _pageAnimDuration,
      curve: _pageAnimCurve,
    );
    _maybeEmitChapterEnd();
    return true;
  }

  /// M2.8/B1: 翻到上一页；若已在章首则换到上一章。
  ///
  /// M2.8/B2 (Bug #6 cross-chapter back-paging): 章首换上一章时，停在上一章
  /// **末页**（而不是首页）。已调 `setChapter(idx-1)`（它 jumpToPage(0) 把
  /// controller 放到首页）后 arm [_pendingJumpToLastPage]；下一帧
  /// `_cachedBreaks` 被填充，[_maybeApplyPendingLastPageJump] 把 controller
  /// 拉到末页。这复刻了 Kindle / 微信读书的章首左翻行为。
  bool previousPage() {
    if (_chapters.isEmpty) return false;
    if (_paginationMode == PaginationMode.scroll) {
      return _previousChapterIfPossible();
    }
    if (!_pageController.hasClients || _cachedBreaks == null || _cachedBreaks!.isEmpty) {
      return _previousChapterIfPossible();
    }
    final currentPage = _pageController.page?.round() ?? 0;
    if (currentPage <= 0) {
      // 章首：换上一章末页。
      final switched = _previousChapterIfPossible();
      if (switched) {
        // setChapter 把 controller 放到首页；arm 末页定位，等下一帧分页
        // 重算后由 [_maybeApplyPendingLastPageJump] 应用。
        _pendingJumpToLastPage = true;
      }
      return switched;
    }
    _pageController.previousPage(
      duration: _pageAnimDuration,
      curve: _pageAnimCurve,
    );
    return true;
  }

  /// M2.8/B2: 应用 pending 末页跳转。
  ///
  /// 在 `_cachedBreaks` 被重新填充后调用（典型路径：`_buildPaged` 的
  /// LayoutBuilder 重跑算出新章节的分页、写入 `_cachedBreaks` 之后立刻调用
  /// 本方法）。若 flag armed 且 controller 已挂载、breaks 非空，则 jumpToPage
  /// 到末页并清零 flag（one-shot）。
  void _maybeApplyPendingLastPageJump() {
    if (!_pendingJumpToLastPage) return;
    final breaks = _cachedBreaks;
    if (breaks == null || breaks.isEmpty) return;
    if (!_pageController.hasClients) return;
    // M2.9: 双页模式下 _pageController.page 是 spread 索引，末页 = 最后一个
    // spread（currentSpreadCount - 1）。单页模式 = breaks.length - 1。
    final lastPage = currentSpreadCount - 1;
    if (lastPage > 0) {
      _pageController.jumpToPage(lastPage);
    }
    _pendingJumpToLastPage = false;
  }

  bool _nextChapterIfPossible() {
    final nextIdx = _currentChapterIndex + 1;
    if (nextIdx < _chapters.length) {
      setChapter(nextIdx);
      return true;
    }
    return false;
  }

  bool _previousChapterIfPossible() {
    if (_currentChapterIndex > 0) {
      setChapter(_currentChapterIndex - 1);
      return true;
    }
    return false;
  }

  /// Future that completes when the current chapter switch has settled.
  ///
  /// Returns an immediately-completed Future when no switch is in progress.
  /// Not part of the [EpubRenderer] interface — exposed for
  /// [ConcreteEpubReaderEngine] to forward as [ReaderEngine.chapterSwitchSettled].
  Future<void> get chapterSwitchSettled =>
      _chapterSwitchCompleter?.future ?? Future<void>.value();

  /// Mark a chapter switch in progress and schedule it to settle on the next
  /// frame. If called again before the previous frame fires, the in-flight
  /// completer is completed early (callers awaiting the prior Future see it
  /// resolve) and a fresh one is armed for the new switch — last-write-wins.
  void _beginChapterSwitch() {
    // Complete any in-flight completer so its awaiters aren't stranded.
    final previous = _chapterSwitchCompleter;
    if (previous != null && !previous.isCompleted) {
      previous.complete();
    }
    final next = Completer<void>();
    _chapterSwitchCompleter = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!next.isCompleted) next.complete();
      if (identical(_chapterSwitchCompleter, next)) {
        _chapterSwitchCompleter = null;
      }
    });
  }

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

  /// M4.6-fix2: 是否为 MD/TXT 模式（openChapters 路径，无 epubx book）。
  /// true 表示当前内容由 [openChapters] 注入（Markdown / 纯文本），
  /// false 表示真 EPUB（[openFile] 解析 epubx book）。
  /// reader_body 据此跳过自动双页——MD/TXT 的短段落结构不适合双页 spread
  /// （段落会被错位分配到左右页，超长段还会溢出右页边界）。
  bool get isHtmlChaptersMode => _book == null;

  /// 当前章节索引 —— Task 12+ 用。
  int get currentChapterIndex => _currentChapterIndex;

  /// 当前书的扁平化章节列表（Chapters + SubChapters 递归展开）。
  ///
  /// epubx 的 EpubChapter 含 SubChapters 嵌套；UI 与 cfi 都按扁平索引访问。
  ///
  /// M4.5: 仅 EPUB 路径有意义（返回 epubx 的 EpubChapter）。MD/TXT 路径
  /// 无 epubx book，应改用格式无关的 [chapterCount] / [flatChapterHtmlAt] /
  /// [flatChapterTitleAt]。渲染核心已全部迁移到格式无关访问器。
  List<EpubChapter> get flatChapters =>
      _flattenChapters(_book?.Chapters ?? const []);

  /// M4.5: 格式无关 —— 章节总数（EPUB 的 flatChapters.length 等价）。
  int get chapterCount => _chapters.length;

  /// M4.5: 格式无关 —— 第 [index] 章的正文 HTML。
  /// 越界返回空串（与旧 `flatChapters[i].HtmlContent ?? ''` 同语义，保护 race）。
  String flatChapterHtmlAt(int index) {
    if (index < 0 || index >= _chapters.length) return '';
    return _chapters[index].html;
  }

  /// M4.5: 格式无关 —— 第 [index] 章的标题（TOC 显示用）。
  String flatChapterTitleAt(int index) {
    if (index < 0 || index >= _chapters.length) return '';
    return _chapters[index].title;
  }

  /// v1.11.7-alpha+1 hotfix: 第 [index] 章的 plain text 长度（PlainTextUtils
  /// 坐标系，与 [_locatorForChapter] 用的 anchor 解析同源）。
  ///
  /// **Bug 背景**：旧实现 `_emitCurrentLocation` 与 `gotoLocator` 都把
  /// `totalChars = html.length` 当作 plain text 长度，但 anchor 解析返回的
  /// `charOffset` 是 plain-text 偏移——HTML 含标签/属性，长度远大于 plain。
  /// 道德经：html.length=105568 / plain.length=60986（1.73x 差距），导致
  /// ratio = charOffset / html.length 被压缩 1.73x → 滚动到比预期早 1.73x
  /// 的位置（用户报告"目录13章跳到正文第八章"）。
  ///
  /// 返回值最小为 1（避免除零）。空章节 / 越界返回 1。
  /// 缓存：键为章节 index（章节切换 / 重打开时清空，见 [_plainTextLengthCache]
  /// 上方声明 + `openFile` / `openChapters` / `setChapter` / `bookForTesting`
  /// 中的 `_plainTextLengthCache.clear()`）。
  int _plainTextLengthForChapter(int index) {
    if (index < 0 || index >= _chapters.length) return 1;
    final cached = _plainTextLengthCache[index];
    if (cached != null) return cached;
    final html = flatChapterHtmlAt(index);
    if (html.isEmpty) {
      _plainTextLengthCache[index] = 1;
      return 1;
    }
    final (plain, _) = PlainTextUtils.htmlToPlainWithOffsets(html);
    final len = plain.isEmpty ? 1 : plain.length;
    _plainTextLengthCache[index] = len;
    return len;
  }

  /// 测试钩子：暴露 plain-text 长度（与 [_locatorForChapter] 同坐标系），
  /// 供回归测试断言 scroll-mode ratio 的分母是 plain 长度，不是 HTML 长度。
  @visibleForTesting
  int debugPlainTextLengthForChapter(int index) =>
      _plainTextLengthForChapter(index);

  /// 测试钩子：用与 [gotoLocator] scroll 模式相同的公式计算 ratio。
  /// 验证 charOffset / totalChars 用 plain 长度而非 HTML 长度。
  @visibleForTesting
  double debugComputeScrollRatioForTesting({
    required int chapterIndex,
    required int charOffset,
  }) {
    final totalChars = _plainTextLengthForChapter(chapterIndex);
    return (charOffset / totalChars).clamp(0.0, 1.0);
  }

  /// Plain text of the current chapter, in **converter 坐标**（与渲染层
  /// `_buildScroll`/`_buildPaged` 使用的 `HtmlToInlineSpanConverter.convert().plainText`
  /// 完全一致）。Cached per `chapterIndex` for the renderer's lifetime.
  ///
  /// 2026-07-08 BUG 2：原实现走 `HtmlTextUtils.htmlToPlainText`（DOM 文本节点
  /// 拼接），与渲染层坐标系不一致——h1 在 DOM 拼接里占完整字符数（"第N章 标题"
  /// = N 字符），在 converter 里被折成 1 字符 `￼` 占位符 + `\n\n` 分隔符 +
  /// EM SPACE 缩进前缀。`resolveSelectionLocator` 用 `indexOf` 在本字段算
  /// 选区 offset，offset 喂给 `_applyHighlights`（converter 坐标）时偏移到
  /// 选区**之后**的位置，导致高亮颜色显示在选中文字之后（用户报告"高亮
  /// 与选择不一致，会向前移动"）。修复：直接返回 converter 的 plainText，
  /// 统一坐标系。
  Future<String> get currentChapterPlainText async {
    if (_chapters.isEmpty) return '';
    // M2.8/B4 (Bug #1): 跨 book-switch race 下 _currentChapterIndex 可能
    // 暂时 >= 新 chapters.length。build 同样保护（见 build）。越界返回空串
    // 而非抛 RangeError，避免调用方（_openExcerptSheet 等）拿到红屏。
    if (_currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return '';
    }
    final cached = _plainTextCache[_currentChapterIndex];
    if (cached != null) return cached;
    final html = flatChapterHtmlAt(_currentChapterIndex);
    // 用与渲染层 (_buildScroll / _buildPaged) 完全相同的 converter 参数，
    // 保证 plainText 坐标一致。baseStyle/imageMaxHeight 不影响 plainText 输出
    // （converter 的 buf 只拼接 text + prefix + U+FFFC 占位符），但保留与渲染
    // 一致的入参，避免未来 converter 行为分化。
    final converted = HtmlToInlineSpanConverter().convert(
      html,
      baseStyle: TypographyCss.textStyleFromSettings(_typography),
      imageMaxHeight: 600 * 0.7,
      indentEm: _typography.paragraphIndentEm.toDouble(),
      indentEnabled: _typography.paragraphIndentEnabled,
      highlights: const [],
    );
    _plainTextCache[_currentChapterIndex] = converted.plainText;
    return converted.plainText;
  }

  /// Current chapter's page breaks in plainText coordinates.
  /// Returns `const []` in scroll mode or before first paged layout.
  List<PageBreak> get currentChapterPageBreaks {
    if (_paginationMode != PaginationMode.paged) return const [];
    final cached = _cachedBreaks;
    if (cached == null) return const [];
    return List.unmodifiable(cached);
  }

  /// Read-only access for app-layer scroll positioning (M3.4).
  ///
  /// The returned controller is the same one bound to the paged-mode
  /// [PageView.builder]. App layer uses it to `jumpToPage` for deep-link
  /// scroll. The controller exists for the renderer's lifetime (constructed
  /// eagerly in the field initializer); callers should still guard with
  /// `hasClients` before invoking mutations if uncertain.
  PageController? get pageController => _pageController;

  /// 仅用于测试：直接注入一本书（跳过 openFile 的文件 IO 与解析）。
  @visibleForTesting
  set bookForTesting(EpubBook? book) {
    _plainTextCache.clear();
    _plainTextLengthCache.clear();
    _cachedBreaks = null;
    _pendingJumpToLastPage = false;
    _book = book;
    _imageInliner = book == null ? null : EpubImageInliner(book);
    // M4.5: 与 openFile 同步填充 _chapters，让走 bookForTesting 的测试也覆盖
    // 格式无关数据源路径（渲染逻辑只读 _chapters）。
    _contentFileToChapterIndex = const {};
    _chapters = book == null
        ? const []
        : _buildDedupedChaptersAndMap(
            _flattenChapters(book.Chapters ?? const []),
            _imageInliner,
          );
    _currentChapterIndex = 0;
    _chapterEndFiredForCurrentChapter = false;
    _beginChapterSwitch();
  }

  /// M4.5: 测试入口 —— 直接注入格式无关章节源（MD/TXT 测试用，跳过 epubx）。
  @visibleForTesting
  set chaptersForTesting(List<HtmlChapterSource> chapters) {
    _plainTextCache.clear();
    _plainTextLengthCache.clear();
    _cachedBreaks = null;
    _pendingJumpToLastPage = false;
    _book = null;
    _chapters = List<HtmlChapterSource>.unmodifiable(chapters);
    _currentChapterIndex = 0;
    _chapterEndFiredForCurrentChapter = false;
    _beginChapterSwitch();
  }

  List<EpubChapter> _flattenChapters(List<EpubChapter> chapters) {
    final result = <EpubChapter>[];
    for (final c in chapters) {
      result.add(c);
      result.addAll(_flattenChapters(c.SubChapters ?? const []));
    }
    return result;
  }

  /// Builds the deduped [_chapters] list — one entry per unique
  /// `ContentFileName` — plus the reverse lookup map.
  ///
  /// **Why dedupe:** epubx's `EpubChapterRef.readHtmlContent` returns the
  /// entire HTML file regardless of NCX anchor fragment. When multiple
  /// navPoints share a `ContentFileName` (Calibre-generated EPUBs often
  /// put 80+ chapters as `#fileposNNNNN` anchors inside one html file),
  /// each EpubChapter ends up with a full duplicate of the same HTML.
  /// Without dedupe, [_chapters] would contain 80 entries with identical
  /// content — clicking TOC visually stays on the same content.
  ///
  /// First occurrence wins (navPoints typically appear in reading order).
  /// Subsequent duplicates are dropped from [_chapters] but still get a
  /// TOC entry via the reverse map.
  List<HtmlChapterSource> _buildDedupedChaptersAndMap(
    List<EpubChapter> flat,
    EpubImageInliner? inliner,
  ) {
    final result = <HtmlChapterSource>[];
    final map = <String, int>{};
    for (final c in flat) {
      final key = c.ContentFileName ?? '';
      // Chapters without ContentFileName cannot be deduped — treat each as
      // unique. This preserves test-fixture behavior (synthetic EpubChapter
      // objects without ContentFileName) and any future source that omits it.
      // Real EPUBs always have ContentFileName set by the epubx parser.
      if (key.isNotEmpty && map.containsKey(key)) continue;
      if (key.isNotEmpty) map[key] = result.length;
      result.add(HtmlChapterSource(
        title: c.Title ?? '',
        html: inliner?.inline(
              c.HtmlContent ?? '',
              chapterContentFileName: c.ContentFileName,
            ) ??
            c.HtmlContent ??
            '',
      ));
    }
    _contentFileToChapterIndex = Map.unmodifiable(map);
    return List.unmodifiable(result);
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
      _plainTextLengthCache.clear();
      _cachedBreaks = null;
      _pendingJumpToLastPage = false;
      _book = book;
      // M4.6-fix14: 构建 EPUB 图片资源映射，用于章节 HTML 中 <img src> 内联。
      // 见 [EpubImageInliner] —— 用户报告"EPUB 看不到任何插图"，根因是 fwfh
      // 不知道怎么解析 EPUB 内部相对路径，把 src 内联成 data URI 让 fwfh 直接解码。
      _imageInliner = EpubImageInliner(book);
      // M4.5: 同步填充格式无关数据源（扁平化 epubx 章节 → HtmlChapterSource），
      // 让渲染/分页/高亮/TOC 走统一路径。EPUB 路径 toc getter 仍读 _book 以
      // 保留嵌套 SubChapters 树（flatChapters 只展平、不丢层级信息给 TOC）。
      _chapters = _buildDedupedChaptersAndMap(
        _flattenChapters(book.Chapters ?? const []),
        _imageInliner,
      );
      _currentChapterIndex = 0;
      _chapterEndFiredForCurrentChapter = false;
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

  /// M4.5: 以预解析的格式无关章节源打开（Markdown / TXT 路径）。
  ///
  /// 与 [openFile]（EPUB 路径，走 epubx 解析）对应：调用方（reader_engine_provider
  /// 的 MD/TXT 分支）先用 MarkdownBookLoader / TextBookLoader 把文件转成
  /// `List<HtmlChapterSource>`，再调本方法。本方法不碰 epubx，[book] 保持 null
  /// —— [toc] getter 据此走扁平 TOC 分支。
  ///
  /// [title] 仅用于错误信息，不参与渲染。空 [chapters] 进入 error 状态。
  Future<void> openChapters(
    List<HtmlChapterSource> chapters, {
    String title = '',
  }) async {
    _setState(const ReaderEngineLoading());
    try {
      if (chapters.isEmpty) {
        throw StateError('openChapters: empty chapter list'
            '${title.isEmpty ? '' : ' (book: $title)'}');
      }
      _plainTextCache.clear();
      _plainTextLengthCache.clear();
      _cachedBreaks = null;
      _pendingJumpToLastPage = false;
      _book = null; // MD/TXT 路径无 epubx book；toc getter 据此走扁平分支
      _contentFileToChapterIndex = const {}; // Reset for MD/TXT path (no ContentFileName)
      _chapters = List<HtmlChapterSource>.unmodifiable(chapters);
      _currentChapterIndex = 0;
      _chapterEndFiredForCurrentChapter = false;
      _scrollController.removeListener(_onScroll);
      _scrollController.addListener(_onScroll);
      _setState(const ReaderEngineReady());
    } catch (e, st) {
      debugPrint('EpubxRenderer.openChapters failed: $title\n$e\n$st');
      _setState(ReaderEngineError(message: '$e', cause: e));
    }
  }


  // ---- 章节渲染 / 位置流 / 跳转 (Task 12) ----

  /// 切换到指定章节（chapterIndex 基于 flatChapters）。
  ///
  /// 重置 `_cachedBreaks` 并 mark 一帧 chapter switch：paged 模式的调用方
  /// `await chapterSwitchSettled` 即可安全读 [currentChapterPageBreaks]，
  /// 否则会一直返回 `const []`（layout 未重跑）。
  ///
  /// M2.8/B2 (Bug #6 regression)：必须 emit `ReaderEngineReady`，
  /// 否则 reader_body 的 `state$.listen` 不会触发 setState → build 不重跑
  /// → `_buildPaged` 的 LayoutBuilder 不重跑 → `_cachedBreaks` 维持 null、
  /// PageView 继续渲染**上一章**的页面，而 `_pageController` 已 jumpToPage(0)。
  /// 用户视觉上"回到本章首页"，下一次 nextPage 又读到 `_cachedBreaks == null`
  /// 走 fallback 换章分支，章节号被无声推进 → "跨章节乱翻"。gotoLocator 的
  /// CFI 分支（见下方 emit）早有此修复，setChapter 漏了。
  void setChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;
    _currentChapterIndex = index;
    _chapterEndFiredForCurrentChapter = false;
    _cachedBreaks = null;
    // M2.8/B2: 大多数 setChapter 调用方（TOC tap / nextPage 章末换章 /
    // gotoLocator / 书签跳转 / 笔记点击）都应停在新章节首页，不该触发末页
    // 定位。仅 [previousPage] 章首换上一章这条路径需要末页，它在调用
    // _previousChapterIfPossible→本方法返回后重新 arm 本 flag。先清零保证
    // 其它路径不残留 stale arm。
    _pendingJumpToLastPage = false;
    _beginChapterSwitch();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _emitCurrentLocation();
    _stateController.add(const ReaderEngineReady());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _emitCurrentLocation();
    _maybeEmitChapterEnd();
  }

  void _emitCurrentLocation() {
    if (_chapters.isEmpty) return;
    if (_currentChapterIndex >= _chapters.length) return;
    final totalChars = _plainTextLengthForChapter(_currentChapterIndex);
    // M2.11/问题1：paged 模式下 _scrollController 没有 client（用 PageView），
    // 旧代码用 scroll ratio 算 charOffset → 恒为 0 → 书签只记章节、跳转只回
    // 首页。修复：paged 模式用当前页/页面对应 break 的 startOffset 作为
    // charOffset，这样书签 cfi 编码了真实页位置（跳转时 gotoLocator CFI 分支
    // 用此 charOffset 反查 break → jumpToPage 落到正确页）。scroll 模式仍用
    // scroll ratio（原有逻辑不变）。
    int charOffset;
    if (_paginationMode == PaginationMode.paged) {
      final breaks = _cachedBreaks;
      final pageIdx = (_pageController.hasClients)
          ? (_pageController.page?.round() ?? 0)
          : 0;
      // 单页模式：breakIdx == pageIdx；双页模式：spread[i] 含 breaks[i*2]
      // (左) + breaks[i*2+1] (右)，取左页 break 的 startOffset 代表本 spread。
      final breakIdx = _dualPageMode ? pageIdx * 2 : pageIdx;
      charOffset = (breaks != null && breakIdx >= 0 && breakIdx < breaks.length)
          ? breaks[breakIdx].startOffset
          : 0;
    } else {
      final maxScroll = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : 0.0;
      final offset =
          _scrollController.hasClients ? _scrollController.offset : 0.0;
      final ratio =
          maxScroll == 0 ? 0.0 : (offset / maxScroll).clamp(0.0, 1.0);
      charOffset = (ratio * totalChars).round().clamp(0, totalChars);
    }
    _locationController.add(EpubCfiLocator(
      cfi: encode(_currentChapterIndex, charOffset),
      chapterIndex: _currentChapterIndex,
    ));
  }

  @override
  Future<TableOfContents> get toc async {
    // M4.5: EPUB 路径保留嵌套 TOC 树（epubx EpubChapter.SubChapters）；
    // MD/TXT 路径（_book == null，_chapters 由 openChapters 填充）用扁平 TOC。
    final book = _book;
    if (book != null) {
      return TableOfContents(entries: _chaptersToToc(book.Chapters ?? const []));
    }
    if (_chapters.isEmpty) return TableOfContents.empty();
    return TableOfContents(entries: _flatChaptersToToc());
  }

  /// M4.5: 扁平章节源（MD/TXT）→ 扁平 TocEntry 列表（无子节点）。
  /// chapterIndex 与 cfi_codec 对齐（_chapters 的 0-based 索引）。
  List<TocEntry> _flatChaptersToToc() {
    final result = <TocEntry>[];
    for (var i = 0; i < _chapters.length; i++) {
      final title = _chapters[i].title;
      result.add(TocEntry(
        title: title.isEmpty ? '(无标题)' : title,
        locator: EpubCfiLocator(cfi: encode(i, 0), chapterIndex: i),
      ));
    }
    return result;
  }

  /// 把 epubx 的 EpubChapter 树转 TocEntry 树。
  ///
  /// 每个 navPoint 的 locator 用：
  /// - chapterIndex：按 ContentFileName 在 [_chapters] 中的去重索引
  ///   （[_contentFileToChapterIndex] 查表）
  /// - charOffset：anchor 在该章 HTML 中对应的 plain-text 偏移
  ///   （[PlainTextUtils.anchorToPlainOffset]）。
  ///
  /// 这样多个 navPoint 共享同一 html 文件时，TOC 仍保留每个 navPoint
  /// 的层级与标题，但 locator 都指向唯一去重章节内的不同字符偏移——
  /// 点击 TOC 跳转到正确的位置而非章节开头。
  ///
  /// anchor 为 null 或在 html 中找不到时，charOffset 回退到 0。
  List<TocEntry> _chaptersToToc(List<EpubChapter> chapters) {
    final result = <TocEntry>[];
    for (final ch in chapters) {
      final locator = _locatorForChapter(ch);
      result.add(TocEntry(
        title: ch.Title ?? '(无标题)',
        locator: locator,
        children: _chaptersToSubEntries(ch.SubChapters ?? const []),
      ));
    }
    return result;
  }

  List<TocEntry> _chaptersToSubEntries(List<EpubChapter> subChapters) {
    final result = <TocEntry>[];
    for (final ch in subChapters) {
      final locator = _locatorForChapter(ch);
      result.add(TocEntry(
        title: ch.Title ?? '(无标题)',
        locator: locator,
        children: _chaptersToSubEntries(ch.SubChapters ?? const []),
      ));
    }
    return result;
  }

  /// 为单个 EpubChapter（可能共享 ContentFileName）构造 deduped locator。
  ///
  /// - 若 ContentFileName 在 [_contentFileToChapterIndex] 中：用 map 的
  ///   deduped index；anchor 通过 [PlainTextUtils.anchorToPlainOffset]
  ///   解析为 plain-text charOffset。
  /// - 若 ContentFileName 为空 / 不在 map 中（test fixture 或异常情况）：
  ///   回退 dedupedIdx = 0 + charOffset = 0。
  /// - anchor 为 null / 空字符串 / 在 html 中找不到：charOffset 回退到 0。
  EpubCfiLocator _locatorForChapter(EpubChapter ch) {
    final contentFile = ch.ContentFileName ?? '';
    final dedupedIdx = _contentFileToChapterIndex[contentFile] ?? 0;
    final anchor = ch.Anchor;
    var charOffset = 0;
    if (anchor != null && anchor.isNotEmpty) {
      final html = flatChapterHtmlAt(dedupedIdx);
      final resolved = PlainTextUtils.anchorToPlainOffset(html, anchor);
      if (resolved != null) charOffset = resolved;
    }
    return EpubCfiLocator(
      cfi: encode(dedupedIdx, charOffset),
      chapterIndex: dedupedIdx,
    );
  }

  int _countFlat(List<EpubChapter> chapters) {
    var n = 0;
    for (final c in chapters) {
      n += 1 + _countFlat(c.SubChapters ?? const []);
    }
    return n;
  }

  /// Navigate to [locator].
  ///
  /// **Scroll-mode behavior**: mutates `_currentChapterIndex` (when the cfi
  /// targets a different chapter), then schedules a post-frame callback that
  /// reads `maxScrollExtent` and jumps to the character-offset ratio. This
  /// method drives scroll positioning directly.
  ///
  /// **Paged-mode behavior**: this method navigates to the chapter ONLY.
  /// Paged-mode page positioning (selecting the correct page index from
  /// [currentChapterPageBreaks] and calling `pageController.jumpToPage`) is
  /// the **caller's** responsibility — typically via `ScrollToOffsetService`.
  /// When the cfi targets a different chapter, this method invalidates
  /// `_cachedBreaks` and marks a chapter switch; the caller can
  /// `await chapterSwitchSettled` so the LayoutBuilder in [build] re-runs
  /// and repopulates [currentChapterPageBreaks] for the new chapter before
  /// the caller reads it. Without that settle, `currentChapterPageBreaks`
  /// returns `const []` (not stale data).
  ///
  /// Same-chapter locators are a no-op for the chapter index; scroll mode
  /// still re-positions to the new offset.
  @override
  Future<void> gotoLocator(Locator locator) async {
    if (locator is EpubCfiLocator) {
      final decoded = decode(locator.cfi);
      if (decoded == null) {
        debugPrint('EpubxRenderer.gotoLocator: invalid cfi ${locator.cfi}');
        return;
      }
      if (decoded.chapterIndex < 0 ||
          decoded.chapterIndex >= _chapters.length) {
        return;
      }
      if (decoded.chapterIndex != _currentChapterIndex) {
        _currentChapterIndex = decoded.chapterIndex;
        _chapterEndFiredForCurrentChapter = false;
        // Invalidate stale paged-mode breaks and mark a chapter switch so
        // callers can `await chapterSwitchSettled` to know when
        // `_cachedBreaks` has been repopulated for the new chapter.
        // Without this, callers reading `currentChapterPageBreaks` after
        // this method returns would see the PREVIOUS chapter's breaks.
        _cachedBreaks = null;
        _beginChapterSwitch();
        // M2.8/B4 (Bug #1+#2): 跨章 CFI 跳转必须把 PageController 重置到
        // 首页，否则旧章的 page index 可能超出新章的 itemCount →
        // PageView 抛 'PageController.page cannot be greater than itemCount'
        // assertion 红屏。setChapter 早有此调用，CFI 分支漏了。
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
        // M2.7 (Bug #7): emit state so reader_body rebuilds with the new
        // chapter. gotoTocEntry → gotoLocator(entry.locator) typically lands
        // here (TocEntry.locator are usually EpubCfiLocator), so without
        // emission TOC taps switched _currentChapterIndex silently and the
        // visible chapter did not change. M2.6/T7 covered only the
        // EpubRangeLocator branch; this completes the fix for CFI branch.
        _stateController.add(const ReaderEngineReady());
      }
      // M2.11/问题1：paged 模式用 charOffset 反查 break 索引 → jumpToPage
      // （双页换算 spread）；scroll 模式仍用 scroll ratio 反推像素。
      // 旧实现 paged 模式只走 scroll 重定位（no-op，_scrollController 无 client）
      // → 书签跳转永远落在 jumpToPage(0) 的首页。现在 _emitCurrentLocation
      // 编码了页位置（break.startOffset），此处反查落到正确页。
      final html = flatChapterHtmlAt(decoded.chapterIndex);
      // v1.11.7-alpha+1 hotfix: totalChars 必须用 plain text 长度
      // （PlainTextUtils 坐标系），与 TOC anchor 解析返回的 charOffset 同源。
      // 旧实现用 html.length（含标签），导致 ratio = plain/html 被压缩 →
      // 滚动到比预期早的位置（道德经"目录13章跳到正文第八章"）。
      final totalChars = html.isEmpty
          ? 1
          : _plainTextLengthForChapter(decoded.chapterIndex);
      final isPaged = _paginationMode == PaginationMode.paged;
      // M2.8/B4 (Bug #1): post-frame callback 跑在调用方（_onBookmarkJump）
      // 的 try-catch 之外，任何抛出都会变成未捕获异常 → Flutter 红屏。
      // 典型触发：书签跨章跳转触发 setChapter + rebuild，rebuild 期间
      // ScrollController / PageController 可能短暂 detach。
      // 全包 try-catch，失败仅 debugPrint，绝不向上冒泡到帧调度器。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (isPaged) {
            if (!_pageController.hasClients) return;
            final breaks = _cachedBreaks;
            if (breaks == null || breaks.isEmpty) return;
            // 找第一个 endOffset > charOffset 的 break（同 _findPageForOffset）。
            int breakIdx = breaks.length - 1;
            for (var i = 0; i < breaks.length; i++) {
              if (breaks[i].endOffset > decoded.charOffset) {
                breakIdx = i;
                break;
              }
            }
            // 双页模式：breakIdx ~/ 2 = spread 索引（与 ScrollToOffsetService 同口径）。
            final spreadCount = currentSpreadCount;
            final targetPage = _dualPageMode
                ? (breakIdx ~/ 2).clamp(0, spreadCount > 0 ? spreadCount - 1 : 0)
                : breakIdx;
            _pageController.jumpToPage(targetPage);
            _emitCurrentLocation();
          } else {
            if (!_scrollController.hasClients) return;
            final ratio = (decoded.charOffset / totalChars).clamp(0.0, 1.0);
            final max = _scrollController.position.maxScrollExtent;
            _scrollController.jumpTo(max * ratio);
            _emitCurrentLocation();
          }
        } catch (e, st) {
          debugPrint('EpubxRenderer.gotoLocator post-frame reposition '
              'failed (chapter=${decoded.chapterIndex}, offset='
              '${decoded.charOffset}, paged=$isPaged): $e\n$st');
        }
      });
      return;
    }
    if (locator is EpubRangeLocator) {
      // Bug #6 fix: annotations stored as Range, not CFI.
      // Paged-mode page positioning (selecting the correct page index from
      // currentChapterPageBreaks) is the caller's responsibility via
      // ScrollToOffsetService — same contract as the CFI branch above.
      //
      // M2.6/T7 (Bug #7): emit state notification so consumer widgets
      // rebuild with the new chapter. Pre-fix, TOC tap updated
      // _currentChapterIndex but consumers (reader_body) didn't see the
      // change, so the visible chapter didn't update.
      if (locator.chapterIndex < 0 ||
          locator.chapterIndex >= _chapters.length) {
        return;
      }
      if (locator.chapterIndex != _currentChapterIndex) {
        _currentChapterIndex = locator.chapterIndex;
        _chapterEndFiredForCurrentChapter = false;
        _cachedBreaks = null;
        _beginChapterSwitch();
        // M2.8/B4 (Bug #1): 与 CFI 分支同因，跨章必须 jumpToPage(0)，
        // 否则旧 page index 超出新章 itemCount → assertion 红屏。
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
        _stateController.add(const ReaderEngineReady());
      }
      return;
    }
    // PdfPageLocator / PdfRangeLocator / unknown: silent no-op (defensive).
  }

  @override
  Future<void> setTypography(TypographySettings settings) async {
    _typography = settings;
    // M2.7 (Bug #3 + #8): emit state so reader_body (state$ → setState →
    // rebuild) picks up the new _typography. EpubxRenderer is a plain class,
    // not a widget — field mutations don't auto-trigger rebuild, so without
    // this notification the typography panel appeared non-functional (the
    // panel wrote to setTypography, the field updated in memory, but the
    // visible text style / margin never changed).
    _stateController.add(const ReaderEngineReady());
  }

  @override
  Future<void> setPaginationMode(PaginationMode mode) async {
    _paginationMode = mode;
    _cachedBreaks = null;
    // M2.7 (Bug #6 partial): same emit-state requirement as setTypography.
    // Pre-fix the paged ↔ scroll toggle updated the field silently and the
    // visible layout did not change. Pagination-mode change invalidates the
    // cache; the chapter revision is unchanged so we don't bump the chapter
    // notifier, but state$ must still fire so the widget tree rebuilds under
    // the new mode.
    _stateController.add(const ReaderEngineReady());
  }

  /// 2026-07-08 FEAT 4：scroll 模式下键盘上下键滚动入口。
  ///
  /// paged 模式调用方应使用 nextPage/previousPage；本方法仅 scroll 模式有意义
  /// （但允许在 paged 模式被调用，会 no-op，避免调用方需自行 mode-gate）。
  ///
  /// [delta] 单位像素：正数向下（看后面），负数向上（看前面）。越界由
  /// [_scrollController] 内部 clamp（position.minScrollExtent/maxScrollExtent），
  /// 不会抛异常。controller 未挂载（首次 build 前）/ 无 positions 时静默 no-op。
  void scrollBy(double delta, {Duration duration = const Duration(milliseconds: 200)}) {
    if (_paginationMode != PaginationMode.scroll) return;
    final c = _scrollController;
    if (!c.hasClients) return;
    final pos = c.position;
    final target = (pos.pixels + delta)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (target == pos.pixels) return;
    if (duration == Duration.zero) {
      c.jumpTo(target);
    } else {
      c.animateTo(target,
          duration: duration, curve: Curves.easeOutCubic);
    }
  }

  @override
  Future<void> injectHighlights(List<HighlightRange> highlights) async {
    _allHighlights
      ..clear()
      ..addAll(highlights);
    // M2.6/T5 (Bug #5b): notify consumers so widget tree rebuilds and
    // reads the new _allHighlights. Pre-fix, the field was updated but
    // no state was emitted, so highlights appeared in memory but not on
    // screen. Caller (reader_body.dart ref.listen) is a listener, not
    // inside a build phase, so emitting here is safe (no rebuild loop).
    _stateController.add(const ReaderEngineReady());
  }

  /// 仅测试用：同步版本，避免 async setup。
  @visibleForTesting
  void injectHighlightsSync(List<HighlightRange> highlights) {
    _allHighlights
      ..clear()
      ..addAll(highlights);
  }

  /// Test-only: read-only view of currently injected highlights.
  ///
  /// Used by widget tests that need to verify the bridge between
  /// `NotesState.annotations` and [injectHighlights] (e.g. reader_body).
  @visibleForTesting
  List<HighlightRange> get allHighlightsForTest =>
      List.unmodifiable(_allHighlights);

  /// Test-only: expose internal PageController for navigation tests.
  @visibleForTesting
  PageController get pageControllerForTest => _pageController;

  /// Test-only: number of cached page breaks (after first build in paged mode).
  @visibleForTesting
  int? get cachedBreakCountForTest =>
      _cachedBreaks == null ? null : _cachedBreaks!.length;

  /// 当前章节经过高亮注入后的 HTML（测试入口）。
  ///
  /// M3.2 简化：每章独立 0-based plain-text offset（不做跨章累计，spec §11 留 M3.x）。
  @visibleForTesting
  String currentHighlightedHtml() {
    if (_chapters.isEmpty) return '';
    // M2.8/B4 (Bug #1): 与 build() 同步加越界保护。
    if (_currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return '';
    }
    final rawHtml = flatChapterHtmlAt(_currentChapterIndex);
    // M2.11/问题3：只注入当前章的高亮（按 chapterIndex 过滤），避免跨章泄漏。
    final inChapter = _allHighlights
        .where((h) => h.chapterIndex == _currentChapterIndex)
        .toList();
    final highlighted = HtmlHighlightInjector.inject(rawHtml, inChapter);
    // M3a/任务2：注入段落首行缩进 CSS（scroll 模式）。HtmlWidget 渲染整章 HTML，
    // <style> 注入到头部即对全章所有 <p> 生效。
    return TypographyStyleInjector.inject(
      highlighted,
      indentEm: _typography.paragraphIndentEm,
      enabled: _typography.paragraphIndentEnabled,
    );
  }

  @override
  Stream<HighlightSelection> get selection$ => _selectionController.stream;

  /// M4.6-fix10/A4: 双页模式下每页独立 SelectionArea 的选区流。
  /// 单页模式走外层 SelectableRegion.onSelectionChanged，不经过此流。
  /// reader_body 的 EPUB paged 路径在双页模式下监听此流驱动 toolbar/摘录。
  final StreamController<SelectedContent> _pagedSelectionController =
      StreamController<SelectedContent>.broadcast();
  Stream<SelectedContent> get pagedSelection$ => _pagedSelectionController.stream;

  /// 由上层 SelectableRegion 在用户松开选区时调用。
  /// EpubxRenderer 自身不订阅 Flutter selection API（reader_engine 包不依赖 Flutter selection 框架）。
  void emitSelection(HighlightSelection selection) {
    _selectionController.add(selection);
  }

  /// M4.6-fix10/A4: 双页模式下每页 SelectionArea.onSelectionChanged 回调。
  /// 推到 _pagedSelectionController 供 reader_body 监听。
  void emitPagedSelection(SelectedContent? content) {
    if (content != null && content.plainText.isNotEmpty) {
      _pagedSelectionController.add(content);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chapters.isEmpty) return const SizedBox.shrink();
    // M2.8/B4 (Bug #1): book-switch race 下 _currentChapterIndex 可能
    // 暂时越界（openFile 把 _book 换了但 _currentChapterIndex 还没重置，
    // 或 gotoLocator 解码出一个超大 chapterIndex）。build 是 Flutter 渲染
    // 管线调用，任何抛出直接红屏。越界返回空白而非抛 RangeError。
    if (_currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return const SizedBox.shrink();
    }
    final rawHtml = flatChapterHtmlAt(_currentChapterIndex);
    final style = TypographyCss.textStyleFromSettings(_typography);
    final (fg, bg) = TypographyCss.themeColors(_typography.theme);
    final margin = _typography.pageMargin.pixelValue.toDouble();

    return ColoredBox(
      color: bg,
      child: DefaultTextStyle(
        style: style.copyWith(color: fg),
        // M2.8/B3 (Bug #5b) historical: scroll 模式曾用注入后的 HTML（rich +
        // 高亮），paged 模式按页切片 + 每页独立注入高亮。M4.8 起 scroll 与
        // paged 共享同一 HtmlToInlineSpanConverter：高亮由 converter bake 到
        // InlineSpan 的 backgroundColor，不再走 HtmlHighlightInjector。两条路
        // 径都吃 raw HTML；highlights 在各自 _build* 内部按 chapterIndex 过滤。
        child: _paginationMode == PaginationMode.scroll
            ? _buildScroll(style, fg, rawHtml, margin)
            : _buildPaged(style, fg, rawHtml, margin),
      ),
    );
  }

  /// scroll 模式：单章 SingleChildScrollView + SelectableText.rich。
  ///
  /// M4.8: 与 paged 模式共享同一 HtmlToInlineSpanConverter + SelectableText.rich
  /// 管道（差异仅在容器：scroll 用 SingleChildScrollView，paged 用 PageView）。
  /// 高亮由 converter bake 到 InlineSpan 的 backgroundColor（不再走
  /// HtmlHighlightInjector）；图片由 converter 包 WidgetSpan + ConstrainedBox
  /// （不再走 fwfh customStylesBuilder）。Scroll 模式无分页，converter 直接吃
  /// 整章 HTML。
  Widget _buildScroll(TextStyle style, Color fg, String html, double margin) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // M4.6-fix15: scroll 模式图片 max-height 限制为视高度 70%。
        // M4.8: 此上限由 converter 的 imageMaxHeight 参数传入（WidgetSpan 内
        // 包 ConstrainedBox(maxHeight: imageMaxHeight)），等价于 fwfh 旧路径的
        // customStylesBuilder({'max-height': ..., 'height': 'auto'})。
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight * 0.7
            : 600.0 * 0.7;
        // M4.8: 章节高亮在 converter 内 bake（与 paged 共用同一 InlineSpan）。
        // 调用方传 rawHtml（与 paged 一致），converter 用 highlights 参数重新
        // 着色——避免 currentHighlightedHtml() 的二次注入 + 减少 injector 调用。
        final chapterHighlights = _allHighlights
            .where((h) => h.chapterIndex == _currentChapterIndex)
            .toList();
        final converted = HtmlToInlineSpanConverter().convert(
          html,
          baseStyle: style.copyWith(color: fg),
          imageMaxHeight: maxH,
          indentEm: _typography.paragraphIndentEm.toDouble(),
          indentEnabled: _typography.paragraphIndentEnabled,
          highlights: chapterHighlights,
        );
        return SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: EdgeInsets.all(margin),
            // 2026-07-08 BUG 1 修复（运行时根因）：
            // 原实现 SelectionArea > SelectableText.rich —— SelectableText 自带
            // EditableText + 私有 SelectionRegistrar，嵌套在 SelectionArea 内时
            // 把 selection 事件吃掉，外层 SelectionArea.onSelectionChanged **不会
            // 触发**。结果 reader_body._selection 永远 null，自定义
            // ReaderSelectionToolbar（摘录/复制/提问 AI）永不显示，只剩导航条上
            // 的 Text（走外层 SelectableRegion 默认 selectionControls）会弹 Material
            // 默认工具条。
            //
            // 修复：用 Text.rich 替代 SelectableText.rich。Text.rich 自身不持有
            // selection registrar，外层 SelectionArea 会接管，onSelectionChanged
            // 正常触发，emitPagedSelection 推到 pagedSelection$ 流，reader_body
            // 订阅器调 _onSelectionChanged → _selection 设置 → toolbar 渲染。
            child: SelectionArea(
              onSelectionChanged: emitPagedSelection,
              child: Text.rich(converted.root),
            ),
          ),
        );
      },
    );
  }

  /// M3e/Q1: 给每个 `<p>` 注入统一段落间距 margin（替代被 fwfh 忽略的
  /// `<style>` 块）。fwfh 的 `customStylesBuilder` 返回的 Map 作为内联样式应用，
  /// margin 是 fwfh 支持的属性（`internal/ops/style_margin.dart`）。
  /// 首行缩进不在此处理（fwfh 不支持 text-indent），由 injector 的 em-space 完成。
  ///
  /// M4.6-fix15: 同时处理 `<img>` 的 max-height。`maxImgHeightPx` 由调用方
  /// 在 LayoutBuilder 内根据视高度算出后传入（scroll=70%, paged=60%）。
  /// fwfh 支持 max-height + height: auto（保持宽高比缩放），让大图自动缩小
  /// 不撑爆视口。返回 null 让 fwfh 走默认分支（保留原行为）。
  Map<String, String>? _elementStyles(dom.Element element, double maxImgHeightPx) {
    final tag = element.localName;
    if (tag == 'p') {
      return const <String, String>{'margin': '0 0 0.5em 0'};
    }
    if (tag == 'img') {
      return <String, String>{
        'max-height': '${maxImgHeightPx.round()}px',
        'height': 'auto',
      };
    }
    return null;
  }

  /// paged 模式：Paginator 把章节切成多页，PageView 左右翻页。
  ///
  /// M2.8/B3 (Bug #5b): 每页用 [HtmlSlicer.sliceByPlainRange] 把 plain
  /// offset 范围映射回 HTML 片段（保留 `<p>`/`<b>` 等富文本结构），再
  /// [HtmlSlicer.localizeHighlights] 把章节全局高亮转成页面本地坐标，
  /// [HtmlHighlightInjector.inject] 注入后喂 [HtmlWidget]。这样 paged 模式
  /// 同时恢复富文本 + 高亮，与 scroll 模式视觉一致。
  ///
  /// 旧实现（M2.5 简化）：`Text(plain.substring(start, end))` 丢失所有
  /// HTML 标签 + 高亮 span → Bug #5b "标记颜色后书籍内文字依旧没有变化"。
  ///
  /// break 偏移以 Paginator 输出的 plainText 坐标为准（见
  /// [Paginator.paginateWithText]）。注意：分页测量仍按 plain text 算
  /// 高度（[Paginator._paginateUncached]），与渲染层用 HtmlWidget 算出的
  /// 实际高度可能有小差异（HtmlWidget 的 line-height/字间距 与 TextPainter
  /// 测量基准不完全一致），实测在常用排版下误差 < 1 行，可接受；若 M3 需要
  /// 精确对齐，可让 Paginator 改用 HtmlWidget 渲染测量。
  Widget _buildPaged(TextStyle style, Color fg, String html, double margin) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // M2.9: 双页模式测量宽度 halve（减去书脊间距 gutter 后对半）。
        // Paginator 仍按单页宽度测量，每 break = 一列内容；spread 由
        // itemBuilder 配对两个 break 渲染。单页模式直接用全宽。
        const gutterPx = 24.0;
        final rawWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
        final rawHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 600.0;
        final measureWidth =
            _dualPageMode ? (rawWidth - gutterPx) / 2.0 : rawWidth;
        // M4.6-fix16: 不再为双页模式减 4 行容差。fix14 那个容差是为吸收
        // TextPainter/HtmlWidget drift，现在改用 RenderedHtmlMeasurer 实测高度
        // （drift 归零），measureHeight = rawHeight 即可。paginator 内部还有
        // 0.3 行 safetyMargin 防御 fwfh 跨次 layout 微漂移（<2px），足够。
        final measureHeight = rawHeight;
        final viewport = Size(measureWidth, measureHeight);
        final measurementKey = _MeasurementKey(
          html: html,
          viewport: viewport,
          typography: _typography,
          marginPx: margin,
        );
        // M4.8: 单阶段同步管道——cache miss 时同步跑 converter + paginator
        // （pure-text 走 LineMetricsPaginator，image/fallback 走 Paginator
        // 估算），cache hit 直接复用 [_convertedSpans] / [_lineBreaks]。
        //
        // 与 fix17 的两阶段（offstage measurer + post-frame callback）相比：
        // - 优点：首帧即正确（无估算→实测的切换，避免用户感知 repaginate）；
        //   SelectableText.rich 渲染与 LineMetricsPaginator 测量共享同一
        //   TextPainter → drift = 0（spec §3.2 invariant）。
        // - 缺点：首帧 heavier（converter + paginator 同步跑，~20-50ms for
        //   长章节）。但 LayoutBuilder.builder 只在 cache miss 时跑，正常翻页
        //   不触发；用户感知的卡顿来自首次进入章节，与旧路径一致。
        //
        // [_InlineSpanMeasurer] offstage widget 仍保留（Task 4.1），作为
        // Phase 6 fwfh 回退路径（image 章节 + RenderParagraph 反射提取
        // WidgetSpan 维度）的接入点；当前主路径未使用它，避免两阶段切换
        // 引起的视觉跳变。
        final lineHeight = style.fontSize! * (style.height ?? 1.0);
        final needsMeasure = _measurementKey != measurementKey ||
            _convertedSpans == null ||
            _lineBreaks == null;
        if (needsMeasure) {
          final chapterHighlights = _allHighlights
              .where((h) => h.chapterIndex == _currentChapterIndex)
              .toList();
          final converted = HtmlToInlineSpanConverter().convert(
            html,
            baseStyle: style.copyWith(color: fg),
            imageMaxHeight: measureHeight * 0.6,
            indentEm: _typography.paragraphIndentEm.toDouble(),
            indentEnabled: _typography.paragraphIndentEnabled,
            highlights: chapterHighlights,
          );
          final breaks = _paginateConverted(
            converted: converted,
            html: html,
            viewport: viewport,
            marginPx: margin,
            lineHeight: lineHeight,
          );
          _convertedSpans = converted;
          _lineBreaks = breaks;
          _measuredHeights = null; // legacy fwfh cache 不可与新管道混用
          _measurementKey = measurementKey;
          _fwfhFallbackForCurrentChapter = converted.shouldFallbackToFwfh;
        }
        final converted = _convertedSpans!;
        final breaks = _lineBreaks!;
        _cachedBreaks = breaks;
        // M2.8/B2: 新章节分页已算出，若 previousPage 章首换章 arm 了末页
        // 定位，应用之。fix17 单阶段：放到 post-frame callback，等 PageView
        // 完全 mount 后再 jumpToPage（build 阶段直接 jump 会被 Stack 子树
        // reconciliation 覆盖，旧测试"previousPage 章首跳末页"挂了）。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeApplyPendingLastPageJump();
        });
        // M4.8-6.2: Chapters with ≥3 unsupported HTML tags (table, SVG, video)
        // fall back to legacy HtmlWidget rendering. The converter flattens these
        // to text, but HtmlWidget can render them properly.
        if (_fwfhFallbackForCurrentChapter) {
          return _buildPagedFwfhFallback(
              style, fg, html, margin, breaks, rawHeight);
        }
        return SelectionArea(
          onSelectionChanged: emitPagedSelection,
          child: SelectablePageView(
            rootSpan: converted.root,
            plainText: converted.plainText,
            breaks: breaks,
            dualPageMode: _dualPageMode,
            initialPage: 0,
            controller: _pageController,
            gutterPx: gutterPx,
            onPageChanged: (_) {
              _emitCurrentLocation();
              _maybeEmitChapterEnd();
            },
          ),
        );
      },
    );
  }

  /// M4.8: Dispatch converted span to the appropriate paginator based on
  /// content type.
  ///
  /// - Pure-text chapters (`converted.images.isEmpty &&
  ///   !converted.shouldFallbackToFwfh`): use [LineMetricsPaginator.paginate]
  ///   on the converted InlineSpan. No WidgetSpans → TextPainter.layout()
  ///   succeeds and per-line metrics are exact.
  /// - Image / fallback chapters: defer to [Paginator.paginateWithText],
  ///   which measures via TextPainter on plain-text substrings (no
  ///   WidgetSpans in measurement). Rendering still uses SelectableText.rich,
  ///   so some drift is expected until Phase 6 introduces the fwfh fallback.
  List<PageBreak> _paginateConverted({
    required ConvertedSpans converted,
    required String html,
    required Size viewport,
    required double marginPx,
    required double lineHeight,
  }) {
    if (converted.images.isEmpty && !converted.shouldFallbackToFwfh) {
      return LineMetricsPaginator().paginate(
        span: converted.root,
        plainText: converted.plainText,
        viewport: viewport,
        marginPx: marginPx,
        lineHeight: lineHeight,
      );
    }
    return _paginator.paginateWithText(
      chapterHtml: html,
      viewport: viewport,
      typography: _typography,
      marginPx: marginPx,
    ).breaks;
  }

  /// M4.8-6.2: Legacy paged rendering via [HtmlWidget] for chapters with
  /// complex HTML elements (table, SVG, video) that the inline span converter
  /// cannot faithfully represent.
  ///
  /// Uses the pre-M4.8 DOM-slicing approach: parse once, pre-compute per-page
  /// HTML, render each page with [HtmlWidget]. Pagination uses the
  /// [Paginator.paginateWithText] estimator (some drift expected).
  Widget _buildPagedFwfhFallback(
    TextStyle style,
    Color fg,
    String html,
    double margin,
    List<PageBreak> breaks,
    double rawHeight,
  ) {
    const gutterPx = 24.0;
    final converted = _convertedSpans!;
    final plain = converted.plainText;

    // Parse chapter DOM once — reuses the same Document for all pages.
    final chapterDoc = html_parser.HtmlParser(html).parse();
    for (final el in chapterDoc.querySelectorAll('script, style')) {
      el.remove();
    }

    final chapterHighlights = _allHighlights
        .where((h) => h.chapterIndex == _currentChapterIndex)
        .toList();

    // Pre-compute per-page HTML (slice + highlight + indent).
    final pageHtmls = <String>[];
    for (var i = 0; i < breaks.length; i++) {
      final pb = breaks[i];
      final start = pb.startOffset.clamp(0, plain.length);
      final end = pb.endOffset.clamp(start, plain.length);
      var pageHtml = HtmlSlicer.sliceByPlainRangeDoc(
        chapterDoc,
        start,
        end,
        plainLength: plain.length,
      );
      if (chapterHighlights.isNotEmpty) {
        final local = HtmlSlicer.localizeHighlights(
          chapterHighlights,
          pb.startOffset,
          pb.endOffset,
        );
        if (local.isNotEmpty) {
          pageHtml = HtmlHighlightInjector.inject(pageHtml, local);
        }
      }
      pageHtml = TypographyStyleInjector.inject(
        pageHtml,
        indentEm: _typography.paragraphIndentEm,
        enabled: _typography.paragraphIndentEnabled,
      );
      pageHtmls.add(pageHtml);
    }

    final itemCount =
        _dualPageMode ? (breaks.length + 1) ~/ 2 : breaks.length;

    Widget buildSinglePage(int breakIdx, {double verticalMargin = double.nan}) {
      final vMargin = verticalMargin.isNaN ? margin : verticalMargin;
      return _PageVerticalAligner(
        horizontalMargin: margin,
        verticalMargin: vMargin,
        enableCentering: !_dualPageMode,
        child: HtmlWidget(
          pageHtmls[breakIdx],
          textStyle: style.copyWith(color: fg),
          customStylesBuilder: (element) =>
              _elementStyles(element, rawHeight * 0.6),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: itemCount,
      onPageChanged: (_) {
        _emitCurrentLocation();
        _maybeEmitChapterEnd();
      },
      itemBuilder: (context, i) {
        if (!_dualPageMode) {
          return buildSinglePage(i);
        }
        final leftIdx = i * 2;
        final rightIdx = leftIdx + 1;
        final hasRight = rightIdx < breaks.length;
        return _DualSpreadAligner(
          margin: margin,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectionArea(
                  onSelectionChanged: emitPagedSelection,
                  child: buildSinglePage(leftIdx, verticalMargin: 0),
                ),
              ),
              if (hasRight) ...[
                const SizedBox(width: gutterPx),
                Expanded(
                  child: SelectionArea(
                    onSelectionChanged: emitPagedSelection,
                    child: buildSinglePage(rightIdx, verticalMargin: 0),
                  ),
                ),
              ] else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        );
      },
    );
  }

  @override
  Future<void> dispose() async {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    await _chapterEndController.close();
    await _stateController.close();
    await _locationController.close();
    await _selectionController.close();
    await _pagedSelectionController.close();
  }
}

/// M3e/Q8续（上下边距对称）: 分页模式下每页内容的垂直对齐器。
///
/// top-aligned 分页的固有特性是一页放完最后一段后剩余空间全堆底部 → "上窄下宽"。
/// 本 widget 按页面**填充度**分两种对齐：
/// - **满页**（内容渲染高 ≥ 可用高度 70%）：内容在可用区内垂直居中，余量对称
///   分摊到上下，像真书版心居中（上下边距视觉一致）。
/// - **末页/孤页**（< 70%）：顶部对齐（Q2 要求——几行字居中反而像浮空）。
///
/// 为何需要两阶段（StatefulWidget）：Flutter 单次 build 无法既"测 child 高度"
/// 又"据高度选 alignment"——选 alignment 要先知道高度，知道高度要先 build 一次。
/// 用 stateful：第一帧用 OverflowBox(无限高) 让 child 自然布局并测其高度存 state，
/// setState 触发第二帧据填充度选 Align(center) 或 Align(topLeft)。两帧对用户
/// 不可见（同一 microtask 内完成 pump）。
///
/// 兜底：OverflowBox(maxHeight: double.infinity) 让 child 超 usableH 时不抛
/// RenderFlex assertion（与旧 SingleChildScrollView 吸收误差同目的）。
///
/// Q11（版心固定）: 去掉了居中逻辑（居中导致各页 top 随内容量浮动，翻页跳动），
/// 统一顶部对齐。简化为 StatelessWidget。[horizontalMargin]/[verticalMargin]
/// 分开——双页模式页内 verticalMargin=0（上下边距由 _DualSpreadAligner 统一管），
/// 单页模式两者都 = margin。[enableCentering] 保留参数仅为向后兼容（已无实际作用）。
///
/// M4.8: 当前新管道未使用本 aligner（SelectablePageView 内部自管 Padding(16)）。
/// 保留以备 Phase 6 fwfh 回退路径（image 章节仍可能需要 OverflowBox 兜底防溢出）。
// ignore_for_file: unused_element, unused_element_parameter
class _PageVerticalAligner extends StatelessWidget {
  const _PageVerticalAligner({
    required this.horizontalMargin,
    this.verticalMargin = double.nan,
    required this.child,
    this.enableCentering = true,
  });

  final double horizontalMargin;
  /// 上下 padding。NaN = 用 horizontalMargin（单页模式默认）。双页模式传 0
  /// （由 _DualSpreadAligner 在 spread 层统一管理上下边距）。
  final double verticalMargin;
  final Widget child;
  /// 已废弃（Q11 后统一顶部对齐）。保留仅为调用点向后兼容。
  final bool enableCentering;

  @override
  Widget build(BuildContext context) {
    // M3e/Q11（版心固定）: 所有页统一顶部对齐到固定版心顶（top = margin），
    // 不再按填充度居中。原因：居中会让各页 top 随内容量浮动（段落长短不均时
    // topM 在 74~110px 间跳动），翻页时文字上下窜动，视觉不稳定。固定顶部
    // 对齐后所有页首行都在同一 y 坐标，像真书版心。满页时内容近乎填满可用区
    // （Q8 后 safetyMargin 仅 0.3 行，余量小），末页顶部对齐（Q2）。
    // 溢出兜底：OverflowBox 让 child 超 usableH 时不抛 assertion。
    //
    // M4.6-fix13: 回退 fix12 的 ClipRect。fix12 用 ClipRect 防止"底部超出
    // 阅读区域"，但实际效果是 Paginator 已分配的内容超出 slot 时被**裁掉**，
    // 用户报"下半空白 + 中间丢一大段"——内容永久丢失，比"溢出可见"严重得多。
    // 原设计（OverflowBox 不裁）是有意为之：超 slot 部分画到 SizedBox 外被
    // 进度条等遮，但完整渲染，用户翻页/调字号后能看到。fix13 配合 _buildPaged
    // 中 measureHeight 减 2.5 行的保守测量，最大限度减少溢出概率。
    final vMargin = verticalMargin.isNaN ? horizontalMargin : verticalMargin;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 600.0;
        return SizedBox(
          height: maxH,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalMargin,
              vertical: vMargin,
            ),
            child: OverflowBox(
              minHeight: 0,
              maxHeight: double.infinity,
              alignment: Alignment.topLeft,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// M3e/Q11（版心固定）: 双页模式 spread 级别的垂直对齐器。
///
/// 双页模式所有 spread 统一顶部对齐（top = margin），不再居中。原因同
/// _PageVerticalAligner：居中会让各 spread 的 top 随内容量浮动，翻页跳动。
/// 固定顶部对齐后：左右页共享同一 Row，都从 top=margin 起（左右对齐 Q9），
/// 且所有 spread 的 top 一致（版心固定，翻页不跳）。页内两页 verticalMargin=0
/// （上下边距由此处统一加）。OverflowBox 兜底溢出。
///
/// M4.8: 当前新管道未使用本 aligner（SelectablePageView 自管 spread 渲染）。
/// 保留以备 Phase 6 fwfh 回退路径。
class _DualSpreadAligner extends StatelessWidget {
  const _DualSpreadAligner({required this.margin, required this.child});

  final double margin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // M4.6-fix13: 回退 fix12 的 ClipRect（同 _PageVerticalAligner）。
    // ClipRect 会裁掉 Paginator 已分配但 HtmlWidget 渲染超 slot 的内容，
    // 导致"丢一大段内容"。原 OverflowBox 不裁是有意为之。
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 600.0;
        return SizedBox(
          height: maxH,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: margin),
            child: OverflowBox(
              minHeight: 0,
              maxHeight: double.infinity,
              alignment: Alignment.topLeft,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// M4.6-fix16: 测量缓存指纹——保证 [_measuredHeights] 与"上次测量时的参数"
/// 对齐，参数变化（章节切换 / 排版变更 / 窗口 resize）自动触发重测量。
class _MeasurementKey {
  const _MeasurementKey({
    required this.html,
    required this.viewport,
    required this.typography,
    required this.marginPx,
  });

  final String html;
  final Size viewport;
  final TypographySettings typography;
  final double marginPx;

  @override
  bool operator ==(Object other) =>
      other is _MeasurementKey &&
      html == other.html &&
      viewport == other.viewport &&
      typography == other.typography &&
      marginPx == other.marginPx;

  @override
  int get hashCode => Object.hash(html, viewport, typography, marginPx);
}

// ---------------------------------------------------------------------------
// M4.8: new measurement pipeline (Phase 4 Task 4.1)
// ---------------------------------------------------------------------------

/// Offstage widget that drives the M4.8 measurement pipeline:
///
///   HTML → [HtmlToInlineSpanConverter] → [ConvertedSpans]
///        → [LineMetricsPaginator] (pure-text) or legacy [Paginator] (image /
///          fallback) → [List<PageBreak>]
///
/// Reports the converted span + page breaks back via [onMeasured].
///
/// **Path dispatch (Phase 4 R2 limitation)**:
/// - Pure-text chapters (`converted.images.isEmpty &&
///   !converted.shouldFallbackToFwfh`): use [LineMetricsPaginator.paginate] on
///   the converted InlineSpan. Since the span has no WidgetSpans,
///   `TextPainter.layout()` succeeds and `computeLineMetrics()` returns the
///   true per-line metrics. Measurement and rendering both use TextPainter
///   → drift = 0 (spec §3.2 invariant).
/// - Image / fallback chapters: defer to [Paginator.paginateWithText], which
///   measures via TextPainter on plain-text substrings (no WidgetSpans in
///   measurement). Rendering still uses `SelectableText.rich`, so some drift
///   is expected for image-heavy chapters. Phase 6 Task 6.2 will close this
///   gap with a fwfh fallback path for chapters with ≥3 unsupported tags.
///
/// The widget itself is always mounted offstage (per spec §3.3.5), even when
/// the underlying measurement is synchronous — this keeps the build-tree
/// invariant uniform and makes a future swap to fully offstage rendering
/// trivial.
class _InlineSpanMeasurer extends StatefulWidget {
  const _InlineSpanMeasurer({
    required this.html,
    required this.baseStyle,
    required this.imageMaxHeight,
    required this.indentEm,
    required this.indentEnabled,
    required this.highlights,
    required this.viewport,
    required this.marginPx,
    required this.lineHeight,
    required this.typography,
    required this.onMeasured,
  });

  /// Full chapter HTML (after script/style stripping done by converter).
  final String html;

  /// Base text style (size, color, line-height) used for conversion.
  final TextStyle baseStyle;

  /// Max image height (matches the legacy `rawHeight * 0.6` in `_buildPaged`).
  final double imageMaxHeight;

  /// First-line indent in EM units (forwarded to converter).
  final double indentEm;

  /// Whether first-line indent is enabled (forwarded to converter).
  final bool indentEnabled;

  /// Chapter-local highlights (already filtered to the current chapter by
  /// caller) to overlay on the converted span.
  final List<HighlightRange> highlights;

  /// Measurement viewport — width is post-gutter halving for dual-page mode
  /// (caller is responsible for halving).
  final Size viewport;

  /// Page margin in pixels (matches `_typography.pageMargin.pixelValue`).
  final double marginPx;

  /// Line height = `fontSize * (textStyle.height ?? 1.0)`. Forwarded to
  /// [LineMetricsPaginator] for its safety margin.
  final double lineHeight;

  /// Current typography settings. Used by the legacy fallback estimator
  /// ([Paginator.paginateWithText]) for paragraph-indent / font-size lookup.
  final TypographySettings typography;

  /// Reports the converted span + page breaks once measurement completes.
  /// Called at most once per [_InlineSpanMeasurer] mount.
  final void Function(ConvertedSpans converted, List<PageBreak> breaks)
      onMeasured;

  @override
  State<_InlineSpanMeasurer> createState() => _InlineSpanMeasurerState();
}

class _InlineSpanMeasurerState extends State<_InlineSpanMeasurer> {
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    // Defer to next frame: the conversion is O(chapter length) and can take
    // tens of ms for long chapters. Running it inline in build would block
    // the frame; post-frame keeps the chapter-switch animation smooth.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _run() {
    if (!mounted || _measured) return;
    _measured = true;

    final converted = HtmlToInlineSpanConverter().convert(
      widget.html,
      baseStyle: widget.baseStyle,
      imageMaxHeight: widget.imageMaxHeight,
      indentEm: widget.indentEm,
      indentEnabled: widget.indentEnabled,
      highlights: widget.highlights,
    );

    final List<PageBreak> breaks;
    if (converted.images.isEmpty && !converted.shouldFallbackToFwfh) {
      // Pure-text path: LineMetricsPaginator on the converted InlineSpan.
      // No WidgetSpans → TextPainter.layout() succeeds and per-line metrics
      // are exact. drift = 0 (spec §3.2 invariant).
      breaks = LineMetricsPaginator().paginate(
        span: converted.root,
        plainText: converted.plainText,
        viewport: widget.viewport,
        marginPx: widget.marginPx,
        lineHeight: widget.lineHeight,
      );
    } else {
      // Image / fallback path: defer to legacy Paginator.paginateWithText,
      // which measures via TextPainter on plain-text substrings (no
      // WidgetSpans). Rendering still uses SelectableText.rich, so some
      // drift is expected until Phase 6 introduces the fwfh fallback.
      breaks = Paginator().paginateWithText(
        chapterHtml: widget.html,
        viewport: widget.viewport,
        typography: widget.typography,
        marginPx: widget.marginPx,
      ).breaks;
    }

    if (mounted) widget.onMeasured(converted, breaks);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

