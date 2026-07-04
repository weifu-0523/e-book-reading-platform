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
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
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
import 'html_slicer.dart';
import 'paginator.dart';
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
  int _currentChapterIndex = 0;
  TypographySettings _typography = TypographySettings.defaults();  // ⚠️ NOT const (M1 factory)
  PaginationMode _paginationMode = PaginationMode.paged;

  /// Read-only access to the current [TypographySettings].
  ///
  /// M2.6/T3: exposed so [ConcreteEpubReaderEngine.typography] can forward
  /// the renderer's live value to UI (e.g. TypographyPanel) instead of a
  /// const default. Pre-fix, panel onChanged wrote to a discarded object.
  TypographySettings get typography => _typography;

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

  /// Cached page breaks for the current chapter in paged mode.
  /// Reset to null on chapter change / book switch / pagination mode change.
  List<PageBreak>? _cachedBreaks;

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
    if (_book == null) return;

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
    final chapters = flatChapters;
    _chapterEndController.add(ChapterEndEvent(
      chapterIndex: _currentChapterIndex,
      isLastChapter: _currentChapterIndex >= chapters.length - 1,
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
    if (_book == null) return false;
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
    if (_book == null) return false;
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
    if (nextIdx < flatChapters.length) {
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
    // M2.8/B4 (Bug #1): 跨 book-switch race 下 _currentChapterIndex 可能
    // 暂时 >= 新 chapters.length。build 同样保护（见 build）。越界返回空串
    // 而非抛 RangeError，避免调用方（_openExcerptSheet 等）拿到红屏。
    if (_currentChapterIndex < 0 ||
        _currentChapterIndex >= chapters.length) {
      return '';
    }
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
    _cachedBreaks = null;
    _pendingJumpToLastPage = false;
    _book = book;
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
      _pendingJumpToLastPage = false;
      _book = book;
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
    final chapters = flatChapters;
    if (index < 0 || index >= chapters.length) return;
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
    if (_book == null) return;
    final chapters = flatChapters;
    if (_currentChapterIndex >= chapters.length) return;
    final html = chapters[_currentChapterIndex].HtmlContent ?? '';
    final totalChars = html.length;
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
      final chapters = flatChapters;
      if (decoded.chapterIndex < 0 || decoded.chapterIndex >= chapters.length) {
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
      final html = chapters[decoded.chapterIndex].HtmlContent ?? '';
      final totalChars = html.isEmpty ? 1 : html.length;
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
      final chapters = flatChapters;
      if (locator.chapterIndex < 0 || locator.chapterIndex >= chapters.length) {
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
    final chapters = flatChapters;
    if (chapters.isEmpty) return '';
    // M2.8/B4 (Bug #1): 与 build() 同步加越界保护。
    if (_currentChapterIndex < 0 ||
        _currentChapterIndex >= chapters.length) {
      return '';
    }
    final rawHtml = chapters[_currentChapterIndex].HtmlContent ?? '';
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

  /// 由上层 SelectableRegion 在用户松开选区时调用。
  /// EpubxRenderer 自身不订阅 Flutter selection API（reader_engine 包不依赖 Flutter selection 框架）。
  void emitSelection(HighlightSelection selection) {
    _selectionController.add(selection);
  }

  @override
  Widget build(BuildContext context) {
    final chapters = flatChapters;
    if (chapters.isEmpty) return const SizedBox.shrink();
    // M2.8/B4 (Bug #1): book-switch race 下 _currentChapterIndex 可能
    // 暂时越界（openFile 把 _book 换了但 _currentChapterIndex 还没重置，
    // 或 gotoLocator 解码出一个超大 chapterIndex）。build 是 Flutter 渲染
    // 管线调用，任何抛出直接红屏。越界返回空白而非抛 RangeError。
    if (_currentChapterIndex < 0 ||
        _currentChapterIndex >= chapters.length) {
      return const SizedBox.shrink();
    }
    final rawHtml = chapters[_currentChapterIndex].HtmlContent ?? '';
    final style = TypographyCss.textStyleFromSettings(_typography);
    final (fg, bg) = TypographyCss.themeColors(_typography.theme);
    final margin = _typography.pageMargin.pixelValue.toDouble();

    return ColoredBox(
      color: bg,
      child: DefaultTextStyle(
        style: style.copyWith(color: fg),
        // M2.8/B3 (Bug #5b): scroll 模式整章渲染，用注入后的 HTML（rich +
        // 高亮）。paged 模式改为按页切片 + 每页独立注入高亮，传入 raw HTML。
        // 旧实现 paged 也用 currentHighlightedHtml()，但 _buildPaged 只取
        // plain substring 喂 Text()，丢掉了所有 span → 高亮不显示。
        child: _paginationMode == PaginationMode.scroll
            ? _buildScroll(style, fg, currentHighlightedHtml(), margin)
            : _buildPaged(style, fg, rawHtml, margin),
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
          // M3e/Q1: 段落统一 margin（fwfh 支持 margin，见 style_margin.dart）。
          // 首行缩进由 TypographyStyleInjector 在 HTML 层用 em-space 注入
          // （fwfh 不支持 text-indent，详见 injector 文档）。
          customStylesBuilder: _paragraphMarginBuilder,
        ),
      ),
    );
  }

  /// M3e/Q1: 给每个 `<p>` 注入统一段落间距 margin（替代被 fwfh 忽略的
  /// `<style>` 块）。fwfh 的 `customStylesBuilder` 返回的 Map 作为内联样式应用，
  /// margin 是 fwfh 支持的属性（`internal/ops/style_margin.dart`）。
  /// 首行缩进不在此处理（fwfh 不支持 text-indent），由 injector 的 em-space 完成。
  Map<String, String>? _paragraphMarginBuilder(dom.Element element) {
    if (element.localName != 'p') return null;
    return const <String, String>{
      'margin': '0 0 0.5em 0',
    };
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
        final viewport = Size(measureWidth, rawHeight);
        final result = _paginator.paginateWithText(
          chapterHtml: html,
          viewport: viewport,
          typography: _typography,
          // M2.8/B1: 把 margin 传给 Paginator，让它在测量时扣除上下/左右
          // padding，使分页边界与实际渲染区域一致（修复 Bug #8 文字溢出）。
          marginPx: margin,
        );
        final plain = result.plainText;
        final breaks = result.breaks;
        _cachedBreaks = breaks;
        // M2.8/B2: 新章节分页已算出，若 previousPage 章首换章 arm 了末页
        // 定位，此刻应用（LayoutBuilder 重跑的同一帧，PageView 尚未渲染）。
        _maybeApplyPendingLastPageJump();
        // M2.8/B3: 预先把章节全局高亮按页面分组，避免 itemBuilder 每帧
        // 对所有高亮做 localize（highlights 数量通常很小，但仍省一次拷贝）。
        //
        // M2.11/问题3：必须先按 chapterIndex 过滤到**当前章**的高亮，否则
        // 全书高亮用各自的章内 0-based offset 去 match 当前章的页范围，offset
        // 范围恰好重叠的页会冒出"幽灵高亮"（属于别的章）。每章 offset 独立 0-based。
        final pageHighlights = <int, List<HighlightRange>>{};
        final chapterHighlights = _allHighlights
            .where((h) => h.chapterIndex == _currentChapterIndex)
            .toList();
        if (chapterHighlights.isNotEmpty) {
          for (var i = 0; i < breaks.length; i++) {
            final pb = breaks[i];
            final local = HtmlSlicer.localizeHighlights(
              chapterHighlights,
              pb.startOffset,
              pb.endOffset,
            );
            if (local.isNotEmpty) pageHighlights[i] = local;
          }
        }
        // M2.9: 双页模式 PageView 的 itemCount = spread 数（每 spread 含
        // 2 breaks）；单页模式 = breaks.length。
        final itemCount =
            _dualPageMode ? (breaks.length + 1) ~/ 2 : breaks.length;

        Widget buildSinglePage(int breakIdx) {
          // breakIdx 越界（双页孤页）由调用方判断，这里假定合法。
          final pb = breaks[breakIdx];
          final start = pb.startOffset.clamp(0, plain.length);
          final end = pb.endOffset.clamp(start, plain.length);
          var pageHtml = HtmlSlicer.sliceByPlainRange(
            html,
            start,
            end,
            plainLength: plain.length,
          );
          final localHl = pageHighlights[breakIdx];
          if (localHl != null) {
            pageHtml = HtmlHighlightInjector.inject(pageHtml, localHl);
          }
          // M3e/Q1（重写 M3a/任务2）：注入段落首行缩进。injector 现在用 HTML
          // 预处理（em-space），不再用被 fwfh 忽略的 `<style>`。highlight inject
          // 后、HtmlWidget 前调用，em-space 前缀对本页所有 <p> 生效。
          pageHtml = TypographyStyleInjector.inject(
            pageHtml,
            indentEm: _typography.paragraphIndentEm,
            enabled: _typography.paragraphIndentEnabled,
          );
          // M2.10/Bug A: 页内容包 SingleChildScrollView(NeverScrollable) 吸收
          // HtmlWidget 与 TextPainter 的高度误差。每个 PageView 页面被赋予固定
          // 高度（= viewport 高度），而 HtmlWidget 渲染出的实际高度与 Paginator
          // 的 TextPainter 测量存在系统性误差（line-height / font-metrics 偏差，
          // 代码已自认误差 < 1 行）。双页模式宽度 halve 放大换行误差，某页真实
          // 高度 > slot 固定高度 → RenderFlex cross-axis 溢出 → 黄黑斑马线 +
          // "bottom overflowed by N pixels"。可滚动容器让误差自然吸收（不溢出
          // 即不滚，溢出可竖向微滚），绝不抛 assertion。
          // NeverScrollableScrollPhysics 确保子页滚动不干扰 PageView 翻页手势。
          // 与 _buildScroll（scroll 模式已用 SingleChildScrollView）模式一致。
          //
          // M3e/Q2（修正 M3a/任务4 误判）：M3a 曾在此包 Align(topCenter) 作为
          // "末页顶部对齐双保险"，但 **Align 在 SingleChildScrollView 内部是
          // no-op** —— scroll view 给子 widget 无限高度约束，Align 没有多余空间
          // 可对齐，被强制收缩成子大小，对齐逻辑完全不生效（等于没写）。
          // SingleChildScrollView 默认 child 从顶部排（scrollOffset=0），短内容
          // （末页）天然顶部对齐，无需额外 Align。删除无效 Align 后行为不变
          // （M3a 之前就是这个结构且本就顶部对齐）。
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(margin),
              child: HtmlWidget(
                pageHtml,
                textStyle: style.copyWith(color: fg),
                // M3e/Q1: 段落统一 margin（fwfh 支持 margin）。缩进走 injector。
                customStylesBuilder: _paragraphMarginBuilder,
              ),
            ),
          );
        }

        return PageView.builder(
          controller: _pageController,
          itemCount: itemCount,
          // M2.9 (页码实时更新): 翻页时除了章末检测，还要 emit 当前位置，
          // 让 ReaderProgressBar 的 currentLocation$ 订阅者收到页码变化。
          // 旧实现只调 _maybeEmitChapterEnd → 翻页时页码不刷新。
          onPageChanged: (_) {
            _emitCurrentLocation();
            _maybeEmitChapterEnd();
          },
          itemBuilder: (context, i) {
            if (!_dualPageMode) {
              return buildSinglePage(i);
            }
            // 双页模式：spread[i] = breaks[i*2] (左) + breaks[i*2+1] (右)。
            final leftIdx = i * 2;
            final rightIdx = leftIdx + 1;
            final hasRight = rightIdx < breaks.length;
            // M3e/Q2（真正根因）: Row 的 crossAxisAlignment 默认 center，会把
            // 高度小于 slot 的子页（末页/孤页只有几行）**垂直居中**在 slot 内，
            // 视觉上"几行字浮在屏幕中间"。实测：默认 center 时右页短内容 top≈49%，
            // 改 start 后 top≈2%（顶部对齐）。这是用户反复反馈"末页居中"的真因
            // ——不在 buildSinglePage（单页模式本就顶部对齐），而在双页 Row 的
            // cross-axis 对齐。强制 start 让左右两页都从顶部排起，像真书。
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: buildSinglePage(leftIdx)),
                SizedBox(width: gutterPx),
                Expanded(
                  child: hasRight
                      ? buildSinglePage(rightIdx)
                      : const SizedBox.shrink(),
                ),
              ],
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
    await _chapterEndController.close();
    await _stateController.close();
    await _locationController.close();
    await _selectionController.close();
  }
}
