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
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderBox, SelectedContent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/rendering/highlight_range.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_selection_bridge.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/local/database.dart' show BookmarkEntry;
import '../../../data/models/annotation.dart';
import '../../notes/services/markdown_exporter.dart';
import '../../notes/services/note_file_writer.dart';
import '../../notes/widgets/annotation_context_sheet.dart';
import '../../../data/models/book.dart';
import '../../../features/ai/providers/review_controller.dart';
import '../../../features/ai/widgets/ai_guide_sheet.dart';
import '../../../features/ai/widgets/qa_ask_dialog.dart';
import '../../../features/ai/widgets/review_preview_sheet.dart';
// M2.7/T21: AI drawer widget (chat panel) wired into narrow Scaffold.endDrawer
// + wide Row conditional panel.
import '../../../features/ai_chat/widgets/ai_drawer_widget.dart';
import '../controllers/bookmark_controller.dart';
import '../controllers/reader_ui_controller.dart';
import '../providers/notes_controller.dart';
import '../providers/reader_engine_provider.dart';
import '../services/scroll_to_offset.dart';
import '../services/toc_title_resolver.dart';
import '../widgets/highlight_color_picker_dialog.dart';
import '../widgets/bookshelf_dialog.dart';
import '../widgets/note_editor_sheet.dart';
import '../widgets/reader_bookmark_dialog.dart';
import '../widgets/reader_chapter_end_prompt.dart';
import '../widgets/reader_drawer.dart';
import '../widgets/reader_drawer_builders.dart';
import '../widgets/reader_error_view.dart';
import '../widgets/reader_scaffold.dart';
import '../widgets/reader_selection_sheet.dart';
import '../widgets/reader_selection_toolbar.dart';
import '../widgets/toc_drawer.dart' show defaultTocChapterIndex;
import '../../../services/ai/ai_guide.dart';
import 'reader_progress_bar.dart';
import 'reader_typography_panel_trigger.dart';

/// Resolve user-selected plain text to an [EpubRangeLocator] carrying
/// real character offsets within the chapter plain text.
///
/// Algorithm: indexOf the selected text within [chapterPlainText].
/// Returns null if selectedText is empty or not found.
///
/// Multi-match: indexOf returns first hit (M3.3 MVP disambiguation).
/// M3.4 may upgrade to anchor-based disambiguation.
Future<EpubRangeLocator?> resolveSelectionLocator({
  required String selectedText,
  required int chapterIndex,
  required String chapterPlainText,
  String? chapterTitle,
}) async {
  if (selectedText.isEmpty) return null;
  final startOffset = chapterPlainText.indexOf(selectedText);
  if (startOffset < 0) return null;
  return EpubRangeLocator(
    chapterIndex: chapterIndex,
    chapterTitle: chapterTitle,
    startOffset: startOffset,
    endOffset: startOffset + selectedText.length,
    quote: selectedText,
  );
}

/// Extracted from reader_page.dart on T8 (2026-06-30).
///
/// ReaderPage 的 body composition：scaffold + 抽屉（TOC / Notes）+ 选区 toolbar
/// overlay + 底栏进度条 + typography 触发器。由 [ReaderPage] 在
/// `engineAsync.when(data:_)` 路径下实例化。
///
/// 抽成顶层 widget 让 reader_page.dart 只负责 page-level shell；本类持有
/// body 级 state（选区、章节缓存、Book 缓存、initialLocator 跳转）。
/// 零行为变化（原 `_ReaderBody` + `_ReaderBodyState` 平移过来）。
class ReaderBody extends ConsumerStatefulWidget {
  final ReaderEngine engine;
  final String bookId;
  final Locator? initialLocator;

  const ReaderBody({
    super.key,
    required this.engine,
    required this.bookId,
    this.initialLocator,
  });

  @override
  ConsumerState<ReaderBody> createState() => _ReaderBodyState();
}

class _ReaderBodyState extends ConsumerState<ReaderBody> {
  ReaderEngine get engine => widget.engine;
  ReaderEngineState _engineState;

  // 当前选区。toolbar overlay 与高亮/笔记/复制 handlers 共用。
  //
  // EPUB：来自 SelectableRegion 的 SelectedContent（含 plainText）。
  // PDF：来自 PdfReaderEngine.selection$ 的 HighlightSelection（pdfrx 自管
  // 选区 UI，不经过 Flutter SelectableRegion），由 initState 注册的 listener
  // 直接 dispatch 给 _onPdfHighlight，不缓存到本字段。
  SelectedContent? _selection;
  Locator? _currentLocation;

  // M3e/Q5：选区在 reader stack 局部坐标系内的 Rect，用于驱动摘录工具条
  // 跟随选区定位（不再固定顶部居中）。由 _onSelectionChanged 在选区确定后
  // 通过 SelectableRegionState.contextMenuAnchors（全局坐标）+ stackKey
  // RenderBox.globalToLocal 转换填充。Flutter 3.44.4 实测该 API 可用。
  Rect? _selectionRect;

  // M3e/Q5：reader 主 Stack 的 GlobalKey，供选区坐标全局→局部转换
  // （RenderBox.globalToLocal）+ 读取 Stack 实际尺寸（替代 MediaQuery.sizeOf）。
  final GlobalKey _stackKey = GlobalKey();

  // M3e/Q5：SelectableRegion 的 GlobalKey，访问 currentState.contextMenuAnchors
  // 拿选区上下界全局坐标点（primaryAnchor = 选区上方中心，secondaryAnchor = 下方）。
  final GlobalKey<SelectableRegionState> _selectableRegionKey =
      GlobalKey<SelectableRegionState>();

  // 章节标题缓存。build 中从 engine.toc 通过 TocTitleResolver 解析得到，
  // 供高亮 locator 的 chapterTitle 字段使用。
  Map<int, String> _chapterTitlesCache = const {};

  // Book 对象缓存。QaAskDialog.submit 需要 Book；这里同步从 repository
  // 拉取后缓存，避免每次点「问答」都 await。书被删时为 null（dialog submit
  // 静默 no-op）。
  Book? _cachedBook;

  // initialLocator 已处理标志，避免 didChangeDependencies 重复触发。
  bool _initialLocatorHandled = false;

  // M2.7/T21: 宽屏右侧 AI 面板开关。窄屏通过 Scaffold.endDrawer 切换，
  // 宽屏用此 bool 决定是否在 Row 末尾追加 SizedBox(width:380) panel。
  // 默认 false（不占用宽屏阅读区域）；用户在 AppBar 通过 toggle 切换。
  bool _aiPanelOpen = false;

  _ReaderBodyState() : _engineState = const ReaderEngineUnloaded();

  /// M2.7/T21: 切换宽屏右侧 AI 面板的展开/收起。
  /// 同时驱动窄屏 endDrawer 的开关（窄屏 endDrawer 由 AppBar 直接 open，
  /// 此处仅切换宽屏 inline panel 的可见性）。
  ///
  /// 当前调用方：T22 会在 ReaderScaffold AppBar 注入 onToggleAiDrawer 回调
  /// 指向此方法。在 T22 落地前暂时触发 unused_element，预期 T22 移除忽略。
  // ignore: unused_element
  void _toggleAiDrawer() {
    setState(() => _aiPanelOpen = !_aiPanelOpen);
  }

  @override
  void initState() {
    super.initState();
    _engineState = engine.state;
    engine.state$.listen((s) {
      if (mounted) setState(() => _engineState = s);
    });
    engine.currentLocation$.listen((loc) {
      if (mounted) _currentLocation = loc;
    });
    // PDF 选区订阅：pdfrx 内部 buildContextMenu 的「高亮」按钮点击后，
    // 通过 PdfRenderer.emitSelection → PdfReaderEngine.selection$ 流推送
    // HighlightSelection。这里订阅并缓存，PDF 选区直接走 _onPdfHighlight
    // （不走 toolbar overlay 的 _openExcerptSheet）。
    if (engine is PdfReaderEngine) {
      (engine as PdfReaderEngine).selection$.listen((sel) {
        if (!mounted) return;
        _onPdfHighlight(sel);
      });
    }
    // M4.6-fix10/A4: EPUB paged 双页模式下，每页独立 SelectionArea 的选区流。
    // 双页模式外层 SelectableRegion 收不到子树 SelectionArea 的 onSelectionChanged
    // （局部 registrar 隔离），所以双页选区通过 pagedSelection$ 推过来，走与
    // 单页相同的 _onSelectionChanged 处理。单页模式不经过此流（外层 region 直推）。
    if (engine is ConcreteEpubReaderEngine) {
      (engine as ConcreteEpubReaderEngine)
          .rendererRef
          .pagedSelection$
          .listen((content) {
        if (!mounted) return;
        _onSelectionChanged(content);
      });
    }
    // Chapter switches are now awaited via `engine.chapterSwitchSettled`
    // at call sites (see _maybeHandleInitialLocator / _onAnnotationTap).
    // No global listener required: those are the only places that need to
    // read `currentChapterPageBreaks` immediately after a chapter change.
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// M2.7/T21: bookId 切换时（路由层复用 ReaderBody 实例换书），
  /// post-frame 关闭已打开的 endDrawer，避免 AI 抽屉还停留在旧书的会话上。
  /// 现实路径里 reader_page 大概率直接重建新 ReaderBody（route extra 变化），
  /// 此处作为防御性兜底，零回归。
  @override
  void didUpdateWidget(covariant ReaderBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final messenger = Scaffold.maybeOf(context);
        if (messenger != null && messenger.hasEndDrawer) {
          messenger.closeEndDrawer();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeHandleInitialLocator();
  }

  /// 处理来自路由 extra 的 initialLocator：跳转到 locator 后，
  /// 等待 chapter switch settle 让 paged-mode LayoutBuilder 重跑、
  /// 重新计算 `_cachedBreaks`，再调用 [ScrollToOffsetService] 滚动到字符 offset。
  ///
  /// 仅在引擎已 Ready 时触发；Ready 状态由 build 的 state$.listen 同步。
  Future<void> _maybeHandleInitialLocator() async {
    final loc = widget.initialLocator;
    if (loc == null || _initialLocatorHandled) return;
    _initialLocatorHandled = true;
    await engine.gotoLocator(loc);
    // M2.8/B4 (Bug #2): 等章节切换 + 多一帧让 PageView 完成布局后再读
    // pageBreaks / jumpToPage，消除「跳转延迟/跳错页」。
    await _awaitChapterSettledAndLayout();
    if (!mounted) return;
    if (loc is! EpubRangeLocator) return;
    final isPaged = engine.paginationMode == PaginationMode.paged;
    // M2.10/Bug B1（真根因）：Scrollable.maybeOf(context) 从 ReaderBody context
    // 往上找祖先，但 PageView（paged）/ SingleChildScrollView（scroll）都在
    // engine.build() 里、是 ReaderBody 的**后代**，所以永远返回 null → 旧代码
    // `if (scrollable == null) return;` 总提前退出 → 跳转从未执行（用户看到
    // "没反应" 或停在首页）。paged 分支只用 pageController + pageBreaks（不用
    // scrollable），所以 paged 模式直接跳过 scrollable 查找；只在 scroll
    // 模式（真正需要 SingleChildScrollView 的 Scrollable）才查找。
    ScrollableState? scrollable;
    if (!isPaged) {
      scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) return;
    }
    await ScrollToOffsetService.scrollToCharacterOffset(
      scrollable: scrollable,
      targetOffset: loc.startOffset,
      paginationMode: engine.paginationMode,
      pageBreaks: engine.currentChapterPageBreaks,
      pageController: engine.pageController,
      // M2.10/Bug B1: 双页模式下 PageController.page 是 spread 索引，
      // service 内部需 ~/2 换算，否则 jumpToPage 越界 assertion 崩溃。
      dualPageMode: engine is ConcreteEpubReaderEngine && engine.dualPageMode,
    );
  }

  /// M2.8/B4 (Bug #2): 跳转到 locator 后，等待章节切换 + 多一帧让
  /// `_cachedBreaks` 被重新填充、PageView 重新挂载。
  ///
  /// **为何需要多一帧**：`chapterSwitchSettled` 的 completer 在「下一帧
  /// post-frame callback」里 resolve。但同一帧里 `_buildPaged` 的
  /// LayoutBuilder 虽然重跑了、写入了 `_cachedBreaks`，PageView 也 rebuild
  /// 了——可是 PageView 的 PageController 此时可能还没真正「挂载新页」，
  /// `ScrollToOffsetService` 紧接着读 `currentChapterPageBreaks` 会拿到
  /// 刚填充的 breaks（OK），但 `pageController.jumpToPage` 在 PageView 尚未
  /// 完成布局时调用会被吞或跳错页 → 用户看到「点击笔记要等一会才跳」。
  /// 额外 `endOfFrame` 让 PageView 完成布局后再 jumpToPage，消除延迟。
  /// 同章 locator（chapterSwitchSettled 立即 resolve）也只多一帧，可接受。
  Future<void> _awaitChapterSettledAndLayout() async {
    await engine.chapterSwitchSettled;
    // 多等一帧让 PageView/SingleChildScrollView 完成布局。
    await WidgetsBinding.instance.endOfFrame;
  }

  void _onSelectionChanged(SelectedContent? content) {
    setState(() {
      _selection = content;
      // 选区清空时同步清掉定位 Rect（让 toolbar 消失）。
      if (content == null || content.plainText.isEmpty) {
        _selectionRect = null;
      }
    });
    // M3e/Q5：选区非空时，在下一帧（选区几何已 settle）读 contextMenuAnchors
    // 转换为 Stack 局部坐标，驱动 toolbar 跟随选区定位。
    if (content != null && content.plainText.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateSelectionRectFromAnchors();
      });
    }
  }

  /// M3e/Q5：从 SelectableRegionState.contextMenuAnchors 取选区上下界全局坐标，
  /// 经 Stack RenderBox.globalToLocal 转成局部坐标，合成 _selectionRect。
  /// toolbar 据此定位（选区上方优先，空间不足转下方）。
  void _updateSelectionRectFromAnchors() {
    final regionState = _selectableRegionKey.currentState;
    final stackCtx = _stackKey.currentContext;
    if (regionState == null || stackCtx == null) return;
    final stackBox = stackCtx.findRenderObject();
    if (stackBox is! RenderBox || !stackBox.hasSize) return;

    TextSelectionToolbarAnchors anchors;
    try {
      anchors = regionState.contextMenuAnchors;
    } catch (_) {
      // contextMenuAnchors 在选区不完整（无 start/end point）时可能 throw
      // （assert）。捕获后保持现状（toolbar 走 fallback）。
      return;
    }
    final primary = anchors.primaryAnchor;
    final secondary = anchors.secondaryAnchor;
    // 合成 Rect：top = primaryAnchor.y（选区上沿），bottom = secondaryAnchor.y
    // （选区下沿），水平中心 = primaryAnchor.x。toolbar 据此上下翻转定位。
    final top = stackBox.globalToLocal(primary).dy;
    final bottom = secondary == null ? top : stackBox.globalToLocal(secondary).dy;
    final centerX = stackBox.globalToLocal(primary).dx;
    // 用 Stack 宽度做水平 clamp 基准（比 primaryAnchor.x 更适合居中 toolbar）。
    final stackWidth = stackBox.size.width;
    final half = stackWidth / 2;
    setState(() {
      _selectionRect = Rect.fromLTRB(
        centerX - half,
        top,
        centerX + half,
        bottom,
      );
    });
  }

  /// M3e/Q5：返回 reader 主 Stack 的实际尺寸（供 toolbar 水平 clamp）。
  /// Stack 未布局时退回屏幕尺寸（fallback，与旧行为一致）。
  Size _stackSize() {
    final ctx = _stackKey.currentContext;
    if (ctx != null) {
      final box = ctx.findRenderObject();
      if (box is RenderBox && box.hasSize) return box.size;
    }
    // context 在 build 内可用（_buildReaderStack 的 Builder 上下文）。
    return MediaQuery.maybeSizeOf(context) ?? const Size(800, 600);
  }

  @override
  Widget build(BuildContext context) {
    // Bug #4 fix: bridge NotesState.annotations → engine.injectHighlights.
    //
    // Placed BEFORE the engine-state early returns so the listener registers
    // regardless of whether the engine is Ready yet. Without this bridge the
    // toolbar writes the annotation to the DB and the notes drawer shows it,
    // but the visible EPUB text never re-renders with the highlight color
    // (renderer._allHighlights stays empty). PDF engines have no
    // `injectHighlights` (pdfrx renders highlights natively), so the
    // type-check `engine is ConcreteEpubReaderEngine` skips them.
    ref.listen<AsyncValue<NotesState>>(
      notesControllerProvider,
      (_, async) {
        final s = async.valueOrNull;
        if (s == null) return;
        final e = engine;
        if (e is! ConcreteEpubReaderEngine) return;
        final ranges = <HighlightRange>[];
        for (final a in s.annotations) {
          final loc = a.locator;
          if (loc is! EpubRangeLocator) continue; // skip PdfRangeLocator etc.
          ranges.add(HighlightRange(
            loc.startOffset,
            loc.endOffset,
            _highlightColorToRgba(a.color),
            hasNote: a.hasNote,
            // M2.11/问题3：标明所属章，engine 渲染当前章时按 chapterIndex 过滤，
            // 避免别的章的高亮用相同 0-based offset 误染到当前章（幽灵高亮）。
            chapterIndex: loc.chapterIndex,
          ));
        }
        e.injectHighlights(ranges);
      },
    );

    if (_engineState is ReaderEngineError) {
      return ReaderErrorView(
        message: (_engineState as ReaderEngineError).message,
        // M4.6-fix15: 加重试按钮。pdfium native 状态污染下，第一次 openFile
        // 可能 30s 超时；用户点重试让 provider 重新跑（旧 PdfDocument 实例
        // 被 GC，新 PdfReaderEngine 重新 openFile）。retry 未必每次都成功
        // （pdfium 上游 bug），但给用户一个不退出 exe 的尝试选项。
        onRetry: () {
          ref.invalidate(readerEngineForBookProvider(widget.bookId));
        },
        onBack: () => Navigator.of(context).maybePop(),
      );
    }
    if (_engineState is! ReaderEngineReady) {
      return const LoadingView();
    }
    final ui = ref.watch(readerUiControllerProvider);

    // 刷新章节标题缓存：toc 可用即解析。
    final toc = engine.toc;
    if (toc != null) {
      _chapterTitlesCache = TocTitleResolver.resolve(toc);
    }
    // 同步刷新 Book 缓存（QaAskDialog 需要 Book 才能提交）。Repository 的
    // getById 返回 Future，所以走 fire-and-forget：第一次 build 后再 tap
    // 时值已就绪。书被删则 _cachedBook 维持 null。
    _refreshBookCache();

    // typographyPanelOpen 由 ReaderTypographyPanelTrigger 监听并弹出/收起 bottom sheet。
    //
    // T8：宽屏（>=1100px）显示永久 sidebar（280px ↔ 40px 折叠），
    // 窄屏维持原 Scaffold + Drawer slide-over。LayoutBuilder 让 build 在
    // 窗口尺寸变化时即时切换分支。
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        // M2.9 (Bug #4 EPUB 双页): EPUB paged 模式 + 宽屏 → 自动启用双页
        // （书脊式左右两页）。窄屏或 scroll 模式 → 单页。setDualPageMode 内部
        // 会去重（值不变直接 return），所以每次 rebuild 调用是廉价的。
        // M4.6 (#1): PDF 也加入此路径——宽屏自动双页，对齐 EPUB 行为。
        final e = engine;
        if (e is ConcreteEpubReaderEngine &&
            e.paginationMode == PaginationMode.paged) {
          // M4.6-fix10/A2: EPUB / TXT / MD 三者都走 paged 模式，宽屏启用双页。
          // MD 在 fix10 改为仿 TXT 每行成 `<p>`（无 `<br>`），Paginator 测高
          // 精准，与 TXT/EPUB 同构，可正常双页。
          e.setDualPageMode(isWide);
        }
        // M4.6-fix10/A1: PDF 强制单页。fix9 的"双 PdfViewer 共享 sourceName"
        // 方案在用户实测中仍卡死（pdfrx 双 PdfViewer 竞态未根治），按用户
        // 决策彻底锁死单页，移除宽屏自动双页 + 手动 toggle 按钮，保稳定。
        // PDF 双页留给后续 milestone 重写（改用 PageView + PdfPage.render 自绘）。
        if (e is PdfReaderEngine) {
          e.dualPageMode = false;
        }
        if (isWide) {
          return _buildWideReaderTree(ui);
        }
        return _buildNarrowReaderTree(ui);
      },
    );
  }

  /// 窄屏 reader tree：T8 之前的标准 Scaffold + Drawer slide-over 行为，
  /// byte-for-byte 不变（默认测试视口 800x600 即走此路径，避免回归）。
  Widget _buildNarrowReaderTree(ReaderUiState ui) {
    return Scaffold(
      // T7 (M2.5) 起抽屉统一为 3-tab 容器（目录 / 书签 / 笔记），
      // 替代旧的 Scaffold.drawer (TOC) + Scaffold.endDrawer (Notes) 分体结构。
      drawer: ReaderDrawer(
        bookId: widget.bookId,
        tocBuilder: (_) => ReaderTocDrawerWrapper(
          engine: engine,
          bookId: widget.bookId,
          onReviewChapter:
              engine is PdfReaderEngine ? null : _onOpenReview,
        ),
        notesBuilder: (_) => ReaderNotesDrawerWrapper(
          chapterTitles: _chapterTitlesCache,
          onAnnotationTap: (id) => _onAnnotationTap(id),
          onAnnotationLongPress: (id) => _onAnnotationLongPress(id),
          // M3e/Q7：抽屉摘录右键 + 可见操作按钮。
          onAnnotationSecondaryTapDown: _onAnnotationSecondaryTapDown,
          onAnnotationEdit: _onAnnotationEdit,
          onAnnotationExport: _onAnnotationExport,
          onAnnotationDelete: _onAnnotationDelete,
        ),
        onSwitchTab: (tab) => ref
            .read(readerUiControllerProvider.notifier)
            .setActiveDrawerTab(tab),
        onBookmarkJump: _onBookmarkJump,
      ),
      onDrawerChanged: (open) {
        // 用户从外部滑出/收起抽屉时同步 UI 状态。
        final notifier = ref.read(readerUiControllerProvider.notifier);
        if (open) {
          notifier.openTocDrawer();
        } else if (ui.tocDrawerOpen) {
          notifier.closeTocDrawer();
        }
      },
      // M2.7/T21: 窄屏 AI 抽屉。3-tab 容器（目录/书签/笔记）保留为左侧
      // Scaffold.drawer，AI 抽屉挂在右侧 endDrawer。Drawer widget 默认宽度
      // 304，AI 面板内容自适应。
      endDrawer: Drawer(
        child: AiDrawerWidget(
          bookId: widget.bookId,
          chapterIndex: _currentChapterIndex(),
          wide: false,
        ),
      ),
      body: _buildReaderStack(ui),
    );
  }

  /// 宽屏 reader tree：左侧 sidebar（280px / 40px）+ 右侧 reader stack。
  /// Sidebar 内嵌 ReaderDrawer(standalone: true) —— 不包 Drawer widget，
  /// 由本方法提供 Material 容器。
  Widget _buildWideReaderTree(ReaderUiState ui) {
    final collapsed = ui.tocSidebarCollapsed;
    return Scaffold(
      // 宽屏不再使用 Scaffold.drawer slot —— sidebar 直接放在 body 里。
      body: Row(
        children: [
          AnimatedContainer(
            key: const Key('sidebar_root'),
            duration: const Duration(milliseconds: 200),
            width: collapsed ? 40 : 280,
            child: collapsed
                ? Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: IconButton(
                        key: const Key('expand_sidebar'),
                        icon: const Icon(Icons.chevron_right),
                        tooltip: '展开侧栏',
                        onPressed: () => ref
                            .read(readerUiControllerProvider.notifier)
                            .toggleSidebarCollapsed(),
                      ),
                    ),
                  )
                : Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            key: const Key('collapse_sidebar'),
                            icon: const Icon(Icons.chevron_left),
                            tooltip: '折叠侧栏',
                            onPressed: () => ref
                                .read(readerUiControllerProvider.notifier)
                                .toggleSidebarCollapsed(),
                          ),
                        ),
                        Expanded(
                          child: ReaderDrawer(
                            bookId: widget.bookId,
                            standalone: true,
                            tocBuilder: (_) => ReaderTocDrawerWrapper(
                              engine: engine,
                              bookId: widget.bookId,
                              onReviewChapter: engine is PdfReaderEngine
                                  ? null
                                  : _onOpenReview,
                            ),
                            notesBuilder: (_) => ReaderNotesDrawerWrapper(
                              chapterTitles: _chapterTitlesCache,
                              onAnnotationTap: (id) => _onAnnotationTap(id),
                              onAnnotationLongPress: (id) =>
                                  _onAnnotationLongPress(id),
                              // M3e/Q7：抽屉摘录右键 + 可见操作按钮（宽屏路径）。
                              onAnnotationSecondaryTapDown:
                                  _onAnnotationSecondaryTapDown,
                              onAnnotationEdit: _onAnnotationEdit,
                              onAnnotationExport: _onAnnotationExport,
                              onAnnotationDelete: _onAnnotationDelete,
                            ),
                            onSwitchTab: (tab) => ref
                                .read(readerUiControllerProvider.notifier)
                                .setActiveDrawerTab(tab),
                            onBookmarkJump: _onBookmarkJump,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(child: _buildReaderStack(ui)),
          // M2.7/T21: 宽屏右侧 AI 面板（条件渲染）。默认收起（_aiPanelOpen=false）
          // 不占阅读区域；用户在 AppBar 通过 _toggleAiDrawer() 展开后追加 380px
          // 列。AiDrawerWidget 内部不强制宽度（wide:true 期望外层 SizedBox 撑定），
          // 此处显式 SizedBox 锁 380px。
          if (_aiPanelOpen)
            SizedBox(
              width: 380,
              child: AiDrawerWidget(
                bookId: widget.bookId,
                chapterIndex: _currentChapterIndex(),
                wide: true,
              ),
            ),
        ],
      ),
    );
  }

  /// 主体 Stack：SelectableRegion + ReaderScaffold + 选区 toolbar + 进度条 +
  /// typography 触发器。窄屏 / 宽屏共用，避免代码重复。
  Widget _buildReaderStack(ReaderUiState ui) {
    return Builder(
      builder: (innerContext) => Stack(
        key: _stackKey,
        children: [
          // M2.11 回归修复：ReaderProgressBar 自 M2.11 起在 Stack 顶层
          // Positioned(bottom: 0) 始终可见，但 EPUB Paginator 用 Stack 完整
          // 高度切页 → 底部 ~32px 文字被 progress bar 不透明背景遮住。
          // 给 SelectableRegion 包 Padding 让出底栏高度，EPUB LayoutBuilder
          // 收到的 constraints.maxHeight 就是扣除 progress bar 的剩余高度，
          // Paginator 分页正确，文字不再被遮。PDF 走 pdfrx 整页缩放，剩余
          // 高度减小只会让页略缩小，不会被遮挡，反而更准确。
          Padding(
            padding: const EdgeInsets.only(bottom: kReaderProgressBarHeight),
            child: SelectableRegion(
              key: _selectableRegionKey,
              selectionControls: materialTextSelectionControls,
              onSelectionChanged: _onSelectionChanged,
              child: ReaderScaffold(
                content: engine.build(innerContext),
              paginationMode: engine.paginationMode,
              title: _bookTitle(),
              // M2.8/B1: paged 模式走 nextPage（章内翻页，章末才换章），
              // scroll 模式走 nextSpine（scroll 无章内分页，tap 即换章）。
              // 修复 Bug #6: 原 tap zone 无条件换章 → "点一下直接跳章"。
              onTapPrev: () {
                if (engine.paginationMode == PaginationMode.paged) {
                  engine.previousPage();
                } else {
                  engine.previousSpine();
                }
              },
              onTapNext: () {
                if (engine.paginationMode == PaginationMode.paged) {
                  engine.nextPage();
                } else {
                  engine.nextSpine();
                }
              },
              // M2.6/T9: 边距像素值同时作为翻页 tap zone 宽度。
              marginPx: engine.typography.pageMargin.pixelValue,
              // M4.6-fix10/A1: PDF 双页 toggle 移除（彻底锁死单页）。
              // onToggleDualPage 传 null → ReaderScaffold 不渲染按钮。
              onToggleDualPage: null,
              isDualPageMode: false,
              onBack: () => Navigator.of(innerContext).maybePop(),
              onOpenToc: () {
                // Tab 切换是幂等且廉价的，无论宽窄屏都执行；
                // 宽屏路径下若 sidebar 折叠则自动展开，让用户看到结果。
                // 仅 Scaffold.openDrawer() 需要宽屏 gate（宽屏没有 Scaffold drawer）。
                ref
                    .read(readerUiControllerProvider.notifier)
                    .setActiveDrawerTab(DrawerTab.toc);
                if (ui.tocSidebarCollapsed) {
                  ref
                      .read(readerUiControllerProvider.notifier)
                      .toggleSidebarCollapsed();
                }
                if (!_isWideScreen(innerContext)) {
                  Scaffold.of(innerContext).openDrawer();
                }
              },
              onOpenNotes: () {
                // 同 onOpenToc：tab 切换无条件执行，sidebar 折叠则展开，
                // 仅 openDrawer 受宽屏 gate。
                ref
                    .read(readerUiControllerProvider.notifier)
                    .setActiveDrawerTab(DrawerTab.notes);
                if (ui.tocSidebarCollapsed) {
                  ref
                      .read(readerUiControllerProvider.notifier)
                      .toggleSidebarCollapsed();
                }
                if (!_isWideScreen(innerContext)) {
                  Scaffold.of(innerContext).openDrawer();
                }
              },
              onOpenTypography: () => ref
                  .read(readerUiControllerProvider.notifier)
                  .openTypographyPanel(),
              // M3c/任务 6a：字号 ± 快捷键。直接改 engine.typography 内存值
              // （与排版面板一致，不写预设/DB），clamp 复用排版面板的 12-32 范围。
              onFontDecrease: () {
                final t = engine.typography;
                unawaited(engine.setTypography(
                    t.copyWith(fontSize: (t.fontSize - 1).clamp(12.0, 32.0))));
              },
              onFontIncrease: () {
                final t = engine.typography;
                unawaited(engine.setTypography(
                    t.copyWith(fontSize: (t.fontSize + 1).clamp(12.0, 32.0))));
              },
              onOpenAiGuide: _onOpenAiGuide,
              onOpenQa: _onOpenQa,
              onOpenReview: engine is PdfReaderEngine ? null : _onOpenReview,
              onAddBookmark: _onAddBookmark,
              // M3c/任务 6b：弹出书架对话框选书切换。
              onOpenBookshelf: () => showBookshelfDialog(
                innerContext,
                currentBookId: widget.bookId,
              ),
              // M4.7b: 翻页/滚动模式切换。
              onTogglePaginationMode: () {
                final next = engine.paginationMode == PaginationMode.paged
                    ? PaginationMode.scroll
                    : PaginationMode.paged;
                unawaited(engine.setPaginationMode(next));
              },
            ),
          ),
          ), // Padding close (M2.11 回归修复)
          if (engine is ConcreteEpubReaderEngine)
            ReaderChapterEndPrompt(
              engine: engine as ConcreteEpubReaderEngine,
              bookId: widget.bookId,
              onReview: _onOpenReview,
              onNext: engine.nextSpine,
            ),
          ReaderSelectionToolbar(
            selection: _selection,
            selectionRect: _selectionRect,
            // M3e/Q5：用 Stack 实际尺寸（而非 MediaQuery 屏幕尺寸）做水平 clamp，
            // toolbar 边缘对齐 Stack 而非整屏。
            stackSize: _stackSize(),
            onExcerpt: _openExcerptSheet,
            onCopy: _onCopySelection,
            onAiComment: _onAiComment,
          ),
          // 底栏始终可见，显示阅读进度。
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ReaderProgressBar(engine: engine),
          ),
          // M2.10/Bug C1: chrome 隐藏（全屏 / 用户切换）时 AppBar 消失，添加
          // 书签的唯一入口（AppBar 里的 IconButton）也消失，用户找不到添加入口。
          // 补一个右下 FAB，仅 !chromeVisible 时显示（chrome 可见时不渲染，
          // 避免与 AppBar 按钮重复）。复用 _onAddBookmark。FAB 放在
          // _buildReaderStack 的 Stack（窄宽屏共用），宽屏路径下落在 Expanded
          // 内的右下，不跨 sidebar。
          if (!ui.chromeVisible)
            Positioned(
              bottom: 56, // 避让底部进度条（~36px）+ 间距
              right: 16,
              child: FloatingActionButton(
                heroTag: 'readerAddBookmark',
                onPressed: _onAddBookmark,
                tooltip: '添加书签',
                child: const Icon(Icons.bookmark_add_outlined),
              ),
            ),
          // typography 面板的触发器（不可见 listener）。
          ReaderTypographyPanelTrigger(engine: engine),
        ],
      ),
    );
  }

  /// 读取当前可用宽度，>=1100 视为宽屏。
  bool _isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1100;
  }

  Future<void> _onAnnotationTap(String id) async {
    final notesState = ref.read(notesControllerProvider).valueOrNull;
    final ann = notesState?.annotations
        .cast<Annotation?>()
        .firstWhere((a) => a?.id == id, orElse: () => null);
    if (ann == null) return;
    await engine.gotoLocator(ann.locator);
    // M2.8/B4 (Bug #2): 等章节切换 + 多一帧让 PageView 完成布局，再读
    // pageBreaks / jumpToPage。原仅 await chapterSwitchSettled，PageView
    // 在同帧刚 rebuild 但未完成布局，jumpToPage 被吞或跳错页 →
    // 用户感觉「点击笔记要等一会才跳」。
    await _awaitChapterSettledAndLayout();
    if (!mounted) return;
    // M2.5/T7 重构后抽屉是 Scaffold.drawer，不再是 endDrawer。
    // 窄屏 maybePop() 会 pop 整个 reader route（Bug #2），必须只在窄屏调。
    // 与 _onBookmarkJump:809 同模式。
    if (!_isWideScreen(context)) {
      unawaited(Navigator.of(context).maybePop());
    }
    if (!mounted) return;
    final loc = ann.locator;
    if (loc is! EpubRangeLocator) return;
    final isPaged = engine.paginationMode == PaginationMode.paged;
    // M2.10/Bug B1（真根因）：Scrollable.maybeOf(context) 从 ReaderBody context
    // 往上找祖先，但 PageView（paged）/ SingleChildScrollView（scroll）都在
    // engine.build() 里、是 ReaderBody 的**后代**，所以永远返回 null → 旧代码
    // `if (scrollable == null) return;` 总提前退出 → 笔记跳转从未执行（用户
    // "没反应" 或停在换章后的首页）。paged 分支只用 pageController + pageBreaks，
    // 直接跳过 scrollable 查找；与 _maybeHandleInitialLocator 同修法。
    ScrollableState? scrollable;
    if (!isPaged) {
      scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) return;
    }
    await ScrollToOffsetService.scrollToCharacterOffset(
      scrollable: scrollable,
      targetOffset: loc.startOffset,
      paginationMode: engine.paginationMode,
      pageBreaks: engine.currentChapterPageBreaks,
      pageController: engine.pageController,
      // M2.10/Bug B1: 双页模式下 PageController.page 是 spread 索引，
      // service 内部需 ~/2 换算，否则 jumpToPage 越界 assertion 崩溃。
      dualPageMode: engine is ConcreteEpubReaderEngine && engine.dualPageMode,
    );
  }

  Future<void> _onAnnotationLongPress(String id) async {
    final notesState = ref.read(notesControllerProvider).valueOrNull;
    final ann = notesState?.annotations
        .cast<Annotation?>()
        .firstWhere((a) => a?.id == id, orElse: () => null);
    if (ann == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: NoteEditorSheet(
          annotation: ann,
          suggestions: const [],
          onSave: (note, color) async {
            await ref.read(notesControllerProvider.notifier).updateAnnotation(
                  ann.copyWith(note: note, color: color),
                );
          },
          onDelete: () async {
            await ref
                .read(notesControllerProvider.notifier)
                .deleteAnnotation(ann.id);
          },
        ),
      ),
    );
  }

  /// M3e/Q7：抽屉摘录右键 → 弹桌面原生右键菜单（编辑/删除/复制摘录/
  /// 复制 Markdown/导出），与 notes_page 桌面右键同款（共用
  /// showAnnotationContextMenu）。按 id 反查 annotation（与 tap/longPress 同模式）。
  Future<void> _onAnnotationSecondaryTapDown(
      String id, Offset globalPosition) async {
    final ann = _annotationById(id);
    if (ann == null || !mounted) return;
    final action =
        await showAnnotationContextMenu(context, globalPosition);
    if (action == null || !mounted) return;
    await _dispatchAnnotationAction(action, ann);
  }

  /// M3e/Q7：抽屉摘录「编辑」可见按钮 → 复用 NoteEditorSheet（与长按同）。
  Future<void> _onAnnotationEdit(String id) async {
    final ann = _annotationById(id);
    if (ann == null || !mounted) return;
    await _showNoteEditor(ann);
  }

  /// M3e/Q7：抽屉摘录「导出」可见按钮 → 单条 Markdown 存文件。
  Future<void> _onAnnotationExport(String id) async {
    final ann = _annotationById(id);
    if (ann == null || !mounted) return;
    await _exportAnnotation(ann);
  }

  /// M3e/Q7：抽屉摘录「删除」可见按钮 → 弹确认对话框，确认后删。
  Future<void> _onAnnotationDelete(String id) async {
    final ann = _annotationById(id);
    if (ann == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除摘录'),
        content: Text('确定删除这条摘录吗？此操作不可撤销。\n\n'
            '「${ann.quote.length > 40 ? '${ann.quote.substring(0, 40)}…' : ann.quote}」'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(notesControllerProvider.notifier).deleteAnnotation(ann.id);
  }

  /// M3e/Q7：从 notesController 反查 annotation（tap/longPress/右键/可见按钮共用）。
  Annotation? _annotationById(String id) {
    final notesState = ref.read(notesControllerProvider).valueOrNull;
    return notesState?.annotations
        .cast<Annotation?>()
        .firstWhere((a) => a?.id == id, orElse: () => null);
  }

  /// M3e/Q7：右键菜单 action 分发（编辑/删除/复制摘录/复制 Markdown/导出）。
  Future<void> _dispatchAnnotationAction(
      AnnotationContextAction action, Annotation ann) async {
    switch (action) {
      case AnnotationContextAction.edit:
        await _showNoteEditor(ann);
        break;
      case AnnotationContextAction.delete:
        // 右键删除：直接删（右键本身是明确二次操作）。可见按钮走确认。
        await ref.read(notesControllerProvider.notifier).deleteAnnotation(ann.id);
        break;
      case AnnotationContextAction.copyQuote:
        await _copyText(ann.quote, '已复制');
        break;
      case AnnotationContextAction.copyMarkdown:
        await _copyText(MarkdownExporter.exportSingle(ann), '已复制 Markdown 片段');
        break;
      case AnnotationContextAction.export:
        await _exportAnnotation(ann);
        break;
    }
  }

  /// M3e/Q7：弹 NoteEditorSheet 编辑（抽屉长按 / 右键编辑 / 可见编辑按钮共用）。
  Future<void> _showNoteEditor(Annotation ann) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: NoteEditorSheet(
          annotation: ann,
          suggestions: const [],
          onSave: (note, color) async {
            await ref.read(notesControllerProvider.notifier).updateAnnotation(
                  ann.copyWith(note: note, color: color),
                );
          },
          onDelete: () async {
            await ref
                .read(notesControllerProvider.notifier)
                .deleteAnnotation(ann.id);
          },
        ),
      ),
    );
  }

  /// M3e/Q7：复制到剪贴板 + SnackBar。
  Future<void> _copyText(String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
  }

  /// M3e/Q7：单条摘录导出为 Markdown 文件。
  Future<void> _exportAnnotation(Annotation ann) async {
    final markdown = MarkdownExporter.exportSingle(ann);
    final name = NoteFileWriter.sanitizeForFilename(ann.quote);
    try {
      final path = await NoteFileWriter.saveMarkdownFile(
        content: markdown,
        suggestedName: name,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存：$path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
  }

  int _currentChapterIndex() {
    final loc = _currentLocation;
    if (loc is EpubCfiLocator) return loc.chapterIndex;
    return 0;
  }

  /// toolbar 「摘录」：打开 [ReaderSelectionSheet]（5 色选择 + 可选备注）
  /// → `addHighlight(locator, color, text, note: note)` → 清选区。
  ///
  /// 替换了 M2.5 之前的「高亮」+「笔记」两个按钮（旧版两者行为完全相同：
  /// 都调用颜色 dialog + addHighlight，没有备注入口）。合并为单按钮 + sheet
  /// 后，用户在一次操作内就能完成颜色选择 + 备注录入。
  ///
  /// Sheet 通过 `Navigator.pop` 返回 [ExcerptSheetResult] 而不是直接调用
  /// `onSave`，由此 widget tree 不会跨 async DB 边界（避免 use-after-unmount：
  /// 旧实现里 sheet 在 `addHighlight` 进行中就已 dismiss，若用户在写入中途
  /// 退出 reader page，会触发在已卸载的 widget 上访问 `ref`）。
  Future<void> _openExcerptSheet() async {
    final sel = _selection;
    if (sel == null) return;
    final text = sel.plainText;
    final plainText = await engine.currentChapterPlainText;
    if (!mounted) return;
    final chapterIdx = _currentChapterIndex();
    final chapterTitle = _chapterTitlesCache[chapterIdx];
    final locator = await resolveSelectionLocator(
      selectedText: text,
      chapterIndex: chapterIdx,
      chapterPlainText: plainText,
      chapterTitle: chapterTitle,
    );
    if (locator == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法定位选区，请重试')),
      );
      return;
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<ExcerptSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: const ReaderSelectionSheet(),
      ),
    );
    if (!mounted) return;
    if (result == null) return; // user cancelled
    final (color, note) = result;
    await ref.read(notesControllerProvider.notifier).addHighlight(
          locator,
          color,
          text,
          note: note,
        );
    if (mounted) setState(() => _selection = null);
  }

  /// PDF 高亮提交路径：pdfrx 自管选区 + 上下文菜单，用户点「高亮」按钮后
  /// 由 [PdfSelectionBridge.fromSelection] 构造 [HighlightSelection] 推到
  /// [PdfReaderEngine.selection$] 流；此方法把 selection 转为 [PdfRangeLocator]
  /// 写入数据库。颜色由用户从 [HighlightColorPickerDialog] 选择。
  ///
  /// 与 [_openExcerptSheet] 的差异：PDF 路径不需要「先选区再点 toolbar」，
  /// 选区已经携带 page + offset（pdfrx 直接给出），无需 `indexOf` 回查。
  Future<void> _onPdfHighlight(HighlightSelection sel) async {
    final color = await showDialog<HighlightColor>(
      context: context,
      builder: (_) => const HighlightColorPickerDialog(),
    );
    if (color == null || !mounted) return;
    final locator = PdfSelectionBridge.toPdfRangeLocator(sel);
    await ref
        .read(notesControllerProvider.notifier)
        .addHighlight(locator, color, sel.text);
  }

  void _onCopySelection() {
    final sel = _selection;
    if (sel == null) return;
    Clipboard.setData(ClipboardData(text: sel.plainText));
    if (mounted) setState(() => _selection = null);
  }

  /// AppBar「AI 导读」按钮：以当前章节为上下文弹出 AiGuideSheet（章节模式）。
  /// 取 book = repository.getById(widget.bookId)；取不到（书被删）则静默退出。
  Future<void> _onOpenAiGuide() async {
    final book = await ref
        .read(bookRepositoryProvider)
        .getById(widget.bookId);
    if (book == null || !mounted) return;
    final chapterIdx = _currentChapterIndex();
    final chapterTitle = _chapterTitlesCache[chapterIdx];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => AiGuideSheet(
        book: book,
        initialMode: AiGuideMode.chapter,
        chapterIndex: chapterIdx,
        chapterTitle: chapterTitle,
      ),
    );
  }

  /// AppBar 溢出菜单「回顾本章」：触发 [ReviewController.start] 后弹出
  /// [ReviewPreviewSheet]。sheet 关闭时若 review 已完成，把 summary +
  /// keyTakeaways 持久化到 [NotesRepository.applyChapterReview]。
  ///
  /// PDF 路径不走本方法（ReaderScaffold 不渲染溢出菜单）。书被删（_cachedBook
  /// 为 null）时静默退出。
  ///
  /// [chapterIndex] 可选参数：TOC 抽屉点击时传入明确章节索引，AppBar 溢出菜单
  /// 使用当前章节索引。
  Future<void> _onOpenReview([int? chapterIndex]) async {
    final book = _cachedBook;
    if (book == null || book.format == BookFormat.pdf) return;
    if (!mounted) return;
    final idx = chapterIndex ?? _currentChapterIndex();
    final chapterTitle = _chapterTitlesCache[idx];
    ref.read(reviewControllerProvider(book.id).notifier).start(
          book: book,
          chapterIndex: idx,
        );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => ReviewPreviewSheet(
        bookId: book.id,
        chapterIndex: idx,
        chapterTitle: chapterTitle,
        onSaved: () async {
          final state = ref.read(reviewControllerProvider(book.id));
          if (state.summary == null) return;
          await ref.read(notesRepositoryProvider).applyChapterReview(
                bookId: book.id,
                bookTitle: book.title,
                chapterIndex: idx,
                chapterTitle: chapterTitle,
                summary: state.summary!,
                keyTakeaways: state.keyTakeaways,
              );
        },
      ),
    );
  }

  /// AppBar「问答」按钮：弹出 QaAskDialog。citation 点击回调接到章节号后，
  /// 在扁平化 TOC 中找到对应 [EpubCfiLocator]（与 [defaultTocChapterIndex]
  /// 的解析口径一致），调用 [engine.gotoTocEntry] 并等待
  /// [engine.chapterSwitchSettled]，让 paged-mode LayoutBuilder 重跑、
  /// 重新计算 `_cachedBreaks`。
  /// 引用对应章节号在扁平化 TOC 中找不到时（例如 toc 为 null、PDF 书、
  /// 或索引越界）弹 SnackBar 提示。
  void _onOpenQa() {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => QaAskDialog(
        bookId: widget.bookId,
        book: _cachedBook,
        onCitationTap: _jumpToChapter,
      ),
    );
  }

  Future<void> _jumpToChapter(int chapterIndex) async {
    final toc = engine.toc;
    if (toc == null || !mounted) {
      _showInvalidChapterSnackBar();
      return;
    }
    final flat = flattenTocEntries(toc.entries);
    // citation chapterIndex 来自 [ch=N] 标记，对应书的章节序号；
    // 与 defaultTocChapterIndex 同口径（EpubCfiLocator.chapterIndex）。
    final target = flat
        .where((e) => defaultTocChapterIndex(e) == chapterIndex)
        .firstOrNull;
    if (target == null) {
      _showInvalidChapterSnackBar();
      return;
    }
    await engine.gotoTocEntry(target);
    // M2.8/B4 (Bug #2): 同 _onAnnotationTap / _onBookmarkJump，多等一帧。
    await _awaitChapterSettledAndLayout();
  }

  void _showInvalidChapterSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无效章节号')),
    );
  }

  /// AppBar「添加书签」回调（M2.5/T12）。
  ///
  /// 在当前 `_currentLocation` 处弹 [ReaderBookmarkDialog]，用户确认后
  /// 把 [BookmarkEntry] 写入数据库。`_currentLocation` 来自
  /// `engine.currentLocation$` 流（initState 订阅）；引擎未上报过位置时
  /// 静默退出（与高亮/笔记路径一致：避免在未知位置写入书签）。
  Future<void> _onAddBookmark() async {
    final locator = _currentLocation;
    if (locator == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在加载，请稍后再试')),
      );
      return;
    }
    final entry = await showDialog<BookmarkEntry>(
      context: context,
      builder: (_) => ReaderBookmarkDialog(
        bookId: widget.bookId,
        defaultLabel: _defaultBookmarkLabel(locator),
        locator: locator,
      ),
    );
    if (entry == null || !mounted) return;
    await ref.read(bookmarkControllerProvider.notifier).add(
          label: entry.label,
          locator: locator,
          note: entry.note,
        );
  }

  /// Drawer / 书签页 jump 回调（M2.5/T12）。
  ///
  /// 反序列化 [BookmarkEntry.locatorJson] 为 [Locator]，调用
  /// `engine.gotoLocator`，然后关闭抽屉（窄屏）/ 折叠 sidebar 不变（宽屏）。
  /// 关闭后等待 chapter switch settle，与 [_onAnnotationTap] 路径对齐。
  Future<void> _onBookmarkJump(BookmarkEntry entry) async {
    Locator? locator;
    try {
      final decoded = jsonDecode(entry.locatorJson);
      if (decoded is Map<String, dynamic>) {
        locator = Locator.fromJson(decoded);
      }
    } catch (_) {
      // 静默忽略损坏的 locator。
    }
    if (locator == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法跳转到该书签')),
      );
      return;
    }
    // M2.6/T8 (Bug #1 修复)：gotoLocator 可能因 locator 类型不匹配、
    // flatChapters 越界、engine 未 ready 等原因抛异常，导致 Flutter 红屏。
    // 防御性 try-catch + SnackBar 防止 UX 灾难。M2.8/B4 进一步把
    // gotoLocator 内部的 post-frame callback 也包了 try-catch（epubx_renderer
    // 里），双重保险。
    try {
      await engine.gotoLocator(locator);
      // M2.8/B4 (Bug #2): 与 _onAnnotationTap 同模式，等章节切换 + 多一帧
      // 让 PageView 完成布局。书签通常是 EpubCfiLocator（跨章跳转常见），
      // gotoLocator CFI 分支只改 _currentChapterIndex + emit state，不调
      // setChapter（不会 jumpToPage(0)）。若 PageView 仍停在旧章的某页，
      // rebuild 后 itemCount 变了但 controller.page 可能越界 → 多等一帧
      // 让 PageView 自然 clamp 到合法页。
      await _awaitChapterSettledAndLayout();
    } catch (e, st) {
      debugPrint('Bookmark jump failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('跳转失败：$e')),
      );
      return;
    }
    if (!mounted) return;
    // 关闭 Drawer（窄屏）。宽屏下抽屉是常驻 sidebar，maybePop 会关闭整页，
    // 因此仅在窄屏调用。判断逻辑：与 onOpenToc 一致使用 _isWideScreen。
    if (!_isWideScreen(context)) {
      unawaited(Navigator.of(context).maybePop());
    }
  }

  /// 根据 locator 类型推导默认书签 label。
  ///
  /// M2.11/问题1：EPUB paged 模式加页码（「第 N 章 · 第 M 页」），让书签像
  /// Kindle 一样精确定位到页，而非只到章。页号来自 engine 的 currentSpreadIndex
  /// （1-based 显示）。scroll 模式无分页，只显示章。
  String _defaultBookmarkLabel(Locator locator) {
    if (locator is EpubCfiLocator) {
      final idx = locator.chapterIndex + 1;
      final pagePart = _epubPagedLabel();
      return pagePart == null ? '第 $idx 章' : '第 $idx 章 · $pagePart';
    }
    if (locator is EpubRangeLocator) {
      final idx = locator.chapterIndex + 1;
      final pagePart = _epubPagedLabel();
      return pagePart == null ? '第 $idx 章' : '第 $idx 章 · $pagePart';
    }
    if (locator is PdfPageLocator) {
      return '第 ${locator.page} 页';
    }
    if (locator is PdfRangeLocator) {
      return '第 ${locator.page} 页';
    }
    return '当前位置';
  }

  /// M2.11/问题1：EPUB paged 模式的页号片段（如「第 3 页」），供书签 label 拼接。
  /// 非 EPUB paged 模式（scroll / PDF）返回 null（只显示章或 PDF 页）。
  String? _epubPagedLabel() {
    final e = engine;
    if (e is! ConcreteEpubReaderEngine) return null;
    if (e.paginationMode != PaginationMode.paged) return null;
    final total = e.currentSpreadCount;
    if (total <= 0) return null;
    final page = (e.currentSpreadIndex + 1).clamp(1, total);
    return '第 $page 页';
  }

  /// 异步刷新 [_cachedBook]。每次 build 触发一次 fire-and-forget 拉取，
  /// 拿到值后赋给 _cachedBook。QaAskDialog.submit 直接读 _cachedBook，
  /// 避免在 showDialog 内 await（让 dialog 立刻显示）。
  void _refreshBookCache() {
    ref.read(bookRepositoryProvider).getById(widget.bookId).then((b) {
      if (mounted && b != null) _cachedBook = b;
    });
  }

  /// 选区 toolbar「AI 点评」按钮：以选中文本为 source 弹出 AiGuideSheet
  /// （selection 模式 + modeLocked，禁止切到其它模式以避免上下文缺失）。
  /// 关闭后清空 selection，与 copy 行为一致。
  Future<void> _onAiComment() async {
    final sel = _selection;
    if (sel == null) return;
    final book = await ref
        .read(bookRepositoryProvider)
        .getById(widget.bookId);
    if (book == null || !mounted) return;
    final chapterIdx = _currentChapterIndex();
    final chapterTitle = _chapterTitlesCache[chapterIdx];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => AiGuideSheet(
        book: book,
        initialMode: AiGuideMode.selection,
        selection: sel.plainText,
        chapterIndex: chapterIdx,
        chapterTitle: chapterTitle,
        modeLocked: true,
      ),
    );
    if (mounted) setState(() => _selection = null);
  }

  /// 简化处理：暂未从 Book 元数据取得标题，显示统一占位。
  /// M2.5-2 接入 CFI restore 时，可在此传入对应的书名。
  String _bookTitle() => '阅读中';

  /// 把 [HighlightColor] 枚举映射为 CSS rgba 字符串。
  ///
  /// 颜色取值与 `HtmlHighlightInjector` 的测试 fixture（
  /// `reader_engine_epub_view/test/html_highlight_injector_test.dart`）
  /// 以及 `HighlightColorPickerDialog` 的 swatch 对齐，保证渲染管线
  /// 上下游一致。
  static const Map<HighlightColor, String> _highlightColorRgba = {
    HighlightColor.yellow: 'rgba(255, 235, 59, 0.4)',
    HighlightColor.green: 'rgba(76, 175, 80, 0.4)',
    HighlightColor.blue: 'rgba(33, 150, 243, 0.4)',
    HighlightColor.red: 'rgba(244, 67, 54, 0.4)',
    HighlightColor.purple: 'rgba(156, 39, 176, 0.4)',
  };

  String _highlightColorToRgba(HighlightColor c) => _highlightColorRgba[c]!;
}
