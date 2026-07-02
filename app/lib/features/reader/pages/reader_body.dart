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

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/rendering/highlight_range.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_selection_bridge.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/annotation.dart';
import '../../../data/models/book.dart';
import '../../../features/ai/providers/review_controller.dart';
import '../../../features/ai/widgets/ai_guide_sheet.dart';
import '../../../features/ai/widgets/qa_ask_dialog.dart';
import '../../../features/ai/widgets/review_preview_sheet.dart';
import '../controllers/reader_ui_controller.dart';
import '../providers/notes_controller.dart';
import '../services/scroll_to_offset.dart';
import '../services/toc_title_resolver.dart';
import '../widgets/highlight_color_picker_dialog.dart';
import '../widgets/note_editor_sheet.dart';
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

  // 章节标题缓存。build 中从 engine.toc 通过 TocTitleResolver 解析得到，
  // 供高亮 locator 的 chapterTitle 字段使用。
  Map<int, String> _chapterTitlesCache = const {};

  // Book 对象缓存。QaAskDialog.submit 需要 Book；这里同步从 repository
  // 拉取后缓存，避免每次点「问答」都 await。书被删时为 null（dialog submit
  // 静默 no-op）。
  Book? _cachedBook;

  // initialLocator 已处理标志，避免 didChangeDependencies 重复触发。
  bool _initialLocatorHandled = false;

  _ReaderBodyState() : _engineState = const ReaderEngineUnloaded();

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
    // Chapter switches are now awaited via `engine.chapterSwitchSettled`
    // at call sites (see _maybeHandleInitialLocator / _onAnnotationTap).
    // No global listener required: those are the only places that need to
    // read `currentChapterPageBreaks` immediately after a chapter change.
  }

  @override
  void dispose() {
    super.dispose();
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
    // Wait for the chapter switch (if any) to settle so
    // `currentChapterPageBreaks` reflects the new chapter before
    // ScrollToOffsetService reads it. Same-chapter locators return an
    // already-completed future, so this is cheap in the common case.
    await engine.chapterSwitchSettled;
    if (!mounted) return;
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    if (loc is EpubRangeLocator) {
      await ScrollToOffsetService.scrollToCharacterOffset(
        scrollable: scrollable,
        targetOffset: loc.startOffset,
        paginationMode: engine.paginationMode,
        pageBreaks: engine.currentChapterPageBreaks,
        pageController: engine.pageController,
      );
    }
  }

  void _onSelectionChanged(SelectedContent? content) {
    setState(() => _selection = content);
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
          ));
        }
        e.injectHighlights(ranges);
      },
    );

    if (_engineState is ReaderEngineError) {
      return ReaderErrorView(
        message: (_engineState as ReaderEngineError).message,
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
        ),
        onSwitchTab: (tab) => ref
            .read(readerUiControllerProvider.notifier)
            .setActiveDrawerTab(tab),
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
                            ),
                            onSwitchTab: (tab) => ref
                                .read(readerUiControllerProvider.notifier)
                                .setActiveDrawerTab(tab),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(child: _buildReaderStack(ui)),
        ],
      ),
    );
  }

  /// 主体 Stack：SelectableRegion + ReaderScaffold + 选区 toolbar + 进度条 +
  /// typography 触发器。窄屏 / 宽屏共用，避免代码重复。
  Widget _buildReaderStack(ReaderUiState ui) {
    return Builder(
      builder: (innerContext) => Stack(
        children: [
          SelectableRegion(
            selectionControls: materialTextSelectionControls,
            onSelectionChanged: _onSelectionChanged,
            child: ReaderScaffold(
              content: engine.build(innerContext),
              title: _bookTitle(),
              onTapPrev: () => engine.previousSpine(),
              onTapNext: () => engine.nextSpine(),
              onBack: () => Navigator.of(innerContext).maybePop(),
              onOpenToc: () {
                // 宽屏路径下 sidebar 已经常驻，目录通过 sidebar 切换 tab；
                // 窄屏路径仍走 Scaffold.openDrawer()。
                if (ui.tocSidebarCollapsed ||
                    !_isWideScreen(innerContext)) {
                  ref
                      .read(readerUiControllerProvider.notifier)
                      .setActiveDrawerTab(DrawerTab.toc);
                }
                if (!_isWideScreen(innerContext)) {
                  Scaffold.of(innerContext).openDrawer();
                }
              },
              onOpenNotes: () {
                // 同 onOpenToc：窄屏 openDrawer；宽屏 sidebar 接管。
                if (ui.tocSidebarCollapsed ||
                    !_isWideScreen(innerContext)) {
                  ref
                      .read(readerUiControllerProvider.notifier)
                      .setActiveDrawerTab(DrawerTab.notes);
                }
                if (!_isWideScreen(innerContext)) {
                  Scaffold.of(innerContext).openDrawer();
                }
              },
              onOpenTypography: () => ref
                  .read(readerUiControllerProvider.notifier)
                  .openTypographyPanel(),
              onOpenAiGuide: _onOpenAiGuide,
              onOpenQa: _onOpenQa,
              onOpenReview: engine is PdfReaderEngine ? null : _onOpenReview,
            ),
          ),
          if (engine is ConcreteEpubReaderEngine)
            ReaderChapterEndPrompt(
              engine: engine as ConcreteEpubReaderEngine,
              bookId: widget.bookId,
              onReview: _onOpenReview,
              onNext: engine.nextSpine,
            ),
          ReaderSelectionToolbar(
            selection: _selection,
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
    // Wait for the chapter switch (if any) to settle so
    // `currentChapterPageBreaks` reflects the new chapter before
    // ScrollToOffsetService reads it.
    await engine.chapterSwitchSettled;
    if (!mounted) return;
    await Navigator.of(context).maybePop(); // 关闭 endDrawer
    if (!mounted) return;
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    final loc = ann.locator;
    if (loc is EpubRangeLocator) {
      await ScrollToOffsetService.scrollToCharacterOffset(
        scrollable: scrollable,
        targetOffset: loc.startOffset,
        paginationMode: engine.paginationMode,
        pageBreaks: engine.currentChapterPageBreaks,
        pageController: engine.pageController,
      );
    }
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
    await engine.chapterSwitchSettled;
  }

  void _showInvalidChapterSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无效章节号')),
    );
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
