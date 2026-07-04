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

  /// 目录缓存。初始 null → UI 显示 LoadingView；[open] 完成 loadOutline 后
  /// 赋值（成功 = 实际 TOC，失败 = empty TOC），后者显示「本书无目录」而非
  /// 永久转圈。对齐 [ConcreteEpubReaderEngine._toc] 模式。
  ///
  /// 背景：[ReaderEngine.toc] 是同步 getter（`TableOfContents?`），但 pdfrx
  /// 的 outline 加载是异步的（`PdfDocument.loadOutline()` 返回 Future）。
  /// 旧实现 `get toc => null` 永远返回 null，导致 PDF 目录 tab 一直转圈
  /// （reader_drawer_builders.dart:50 `if (toc == null) LoadingView()`）。
  TableOfContents? _toc;

  @override
  ReaderEngineState get state => _renderer.state;

  @override
  Stream<ReaderEngineState> get state$ => _renderer.state$;

  @override
  Stream<Locator> get currentLocation$ => _renderer.currentLocation$;

  @override
  Future<void> open(BookRef book) async {
    await _renderer.openFile(book.filePath);
    // openFile 成功后才加载 outline（doc 未打开时 loadOutline 无意义）。
    // PdfRenderer.toc 内部已 catch 异常并降级为 empty TOC，这里不再额外
    // 包裹 try/catch —— 任何情况都给 _toc 赋一个非 null 值，确保 UI 不会
    // 因 toc==null 永久停在 LoadingView（转圈）。
    _toc = await _renderer.toc;
  }

  @override
  Future<void> gotoLocator(Locator locator) => _renderer.gotoLocator(locator);

  @override
  Future<void> gotoTocEntry(TocEntry entry) =>
      _renderer.gotoLocator(entry.locator);

  @override
  Future<void> nextSpine() async {
    // T13: 双页布局下前进 / 后退按 2 步。setPage 内部已经 snap 到偶数，
    // 所以 +1 / +2 在 dual 模式下行为一致（都到下一对左页）；显式 +2 让
    // 意图清晰、避免依赖 snap 兜底。
    final step = _renderer.dualPageMode ? 2 : 1;
    _renderer.setPage(_renderer.currentPage + step);
  }

  @override
  Future<void> previousSpine() async {
    final step = _renderer.dualPageMode ? 2 : 1;
    _renderer.setPage(_renderer.currentPage - step);
  }

  // M2.8/B1: PDF 是 scroll mode + Page-as-Chapter，没有"章内分页"概念，
  // nextPage/previousPage 等价于 nextSpine/previousSpine（翻页即翻 PDF 页）。
  @override
  bool nextPage() {
    nextSpine();
    return true;
  }

  @override
  bool previousPage() {
    previousSpine();
    return true;
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

  // ----- PDF-specific getters (not on ReaderEngine interface) -----
  //
  // reader_page 进度条/章节标题 fallback 用：pdfrx 内部 currentPage 是 0-based，
  // pageCount 取自 PdfDocument.pages.length。不通过 ReaderEngine 接口暴露（接口
  // 是 EPUB+PDF 共用，EPUB 无 pageCount 概念）。

  /// 当前 pdfrx 0-based 页索引（外部展示时 +1 转 1-based）。
  int get currentPage => _renderer.currentPage;

  /// PDF 总页数；未打开返回 0。
  int get pageCount => _renderer.pageCount;

  /// T13: 暴露内部 [PdfRenderer] 引用，供 reader_body 在 LayoutBuilder 里
  /// 同步设置 `dualPageMode` 与读取 `isScanned`。
  PdfRenderer get rendererRef => _renderer;

  /// M2.6/T2 (Bug #4): 把 dualPageMode 暴露为引擎级独立 toggle。
  ///
  /// 历史背景：M2.5/T13 把触发条件耦合到 LayoutBuilder 宽度（>=1200px），
  /// 但用户报告"全屏下没有分为左右两页"——window_manager 切换全屏后的
  /// LayoutBuilder rebuild 时序与 isScanned FutureBuilder 解析存在 race。
  /// 现在改为用户-driven：默认 false，AppBar 按钮显式切换。
  ///
  /// v1.5.1 简化：不持久化（每次启动默认 false）；持久化留 v1.5.2。
  bool get dualPageMode => _renderer.dualPageMode;

  /// 同步 setter，直接转发到 [PdfRenderer]。renderer 内部 setter 会在
  /// 进入 dual 模式时 snap 到偶数页（避免左右页错位）。
  set dualPageMode(bool value) {
    _renderer.dualPageMode = value;
  }

  // ----- ReaderEngine EPUB-flavored members (Page-as-Chapter semantics) -----

  @override
  Future<String> get currentChapterPlainText async => '';

  @override
  List<PageBreak> get currentChapterPageBreaks => const [];

  @override
  PageController? get pageController => null;

  @override
  Future<void> get chapterSwitchSettled async {}

  /// 由 [open] 在 loadOutline 完成后填充。open 期间为 null → UI 转圈；
  /// open 完成后必为非 null（即使 PDF 无书签也是 empty TOC，显示「本书无目录」）。
  @override
  TableOfContents? get toc => _toc;

  @override
  TypographySettings get typography => _typography;

  @override
  PaginationMode get paginationMode => PaginationMode.scroll;

  /// M2.9: PDF 自有 dualPageMode（用户 toggle）。scroll 模式下 spread 计数
  /// 不适用（PDF 用 pageCount / currentPage 自管页码），返回 0 让
  /// ReaderProgressBar 走 PDF 自己的「第 N 页」分支。
  @override
  int get currentSpreadCount => 0;

  @override
  int get currentSpreadIndex => 0;

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
