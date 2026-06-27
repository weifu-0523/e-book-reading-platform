import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';

import '../../../core/providers.dart';
import '../../../data/models/annotation.dart';
import '../../../features/settings/providers/font_library_provider.dart';
import '../controllers/reader_ui_controller.dart';
import '../providers/notes_controller.dart';
import '../providers/reader_engine_provider.dart';
import '../services/progress_persister.dart';
import '../services/scroll_to_offset.dart';
import '../services/toc_title_resolver.dart';
import '../widgets/highlight_color_picker_dialog.dart';
import '../widgets/highlight_selection_controls.dart';
import '../widgets/note_editor_sheet.dart';
import '../widgets/notes_drawer.dart';
import '../widgets/reader_bottom_bar.dart';
import '../widgets/reader_error_view.dart';
import '../widgets/reader_scaffold.dart';
import '../widgets/toc_drawer.dart';
import '../widgets/typography_panel.dart';

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

/// 阅读器主页面。
///
/// 装配链：[ReaderEngineProvider] → [ReaderPage] → [ReaderScaffold] → HtmlWidget。
///
/// 路由：`/book/:id`，由 `core/app.dart` 的 `onGenerateRoute` 派发。
class ReaderPage extends ConsumerStatefulWidget {
  final String bookId;
  final Locator? initialLocator;

  const ReaderPage({super.key, required this.bookId, this.initialLocator});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  ProgressPersister? _persister;
  ReaderEngine? _engine;

  @override
  void dispose() {
    _persister?.dispose();
    _engine?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engineAsync = ref.watch(readerEngineForBookProvider(widget.bookId));

    return Scaffold(
      body: engineAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ReaderErrorView(
          message: '无法打开书籍: $e',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        data: (engine) {
          _ensureProgressPersister(engine);
          // 用本地 ProviderScope 覆盖 currentBookIdProvider，让 NotesController
          // 拿到当前 bookId（仅作用于本书的子树）。
          // notesControllerProvider 是 autoDispose — 同作用域覆盖依赖时必须
          // 同步覆盖消费方 provider，否则 riverpod 抛 "dependency overridden"
          // 断言。
          return ProviderScope(
            overrides: [
              currentBookIdProvider.overrideWith((_) => widget.bookId),
              notesControllerProvider.overrideWith(
                (ref) => NotesController(
                  bookId: widget.bookId,
                  repository: ref.watch(notesRepositoryProvider),
                ),
              ),
            ],
            child: _ReaderBody(
              engine: engine,
              initialLocator: widget.initialLocator,
            ),
          );
        },
      ),
    );
  }

  void _ensureProgressPersister(ReaderEngine engine) {
    if (_persister != null) return;
    _engine = engine;
    _persister = ProgressPersister(
      bookId: widget.bookId,
      repository: ref.read(readingProgressRepositoryProvider),
      source: engine.currentLocation$,
    )..start();
  }
}

class _ReaderBody extends ConsumerStatefulWidget {
  final ReaderEngine engine;
  final Locator? initialLocator;

  const _ReaderBody({required this.engine, this.initialLocator});

  @override
  ConsumerState<_ReaderBody> createState() => _ReaderBodyState();
}

class _ReaderBodyState extends ConsumerState<_ReaderBody> {
  ReaderEngine get engine => widget.engine;
  ReaderEngineState _engineState;

  // 当前选区。toolbar overlay 与高亮/笔记/复制 handlers 共用。
  SelectedContent? _selection;
  Locator? _currentLocation;

  // 章节标题缓存。build 中从 engine.toc 通过 TocTitleResolver 解析得到，
  // 供高亮 locator 的 chapterTitle 字段使用。
  Map<int, String> _chapterTitlesCache = const {};

  // initialLocator 已处理标志，避免 didChangeDependencies 重复触发。
  bool _initialLocatorHandled = false;

  // 章节切换监听器（M3.4）：engine 切章时 bump `chapterRevisionNotifier`，
  // 我们 setState 触发 rebuild，让 LayoutBuilder 在 _buildPaged 中重跑、
  // 重新填充 `_cachedBreaks`，否则 `currentChapterPageBreaks` 返回 stale
  // 或空（与 paged-mode 的 ScrollToOffsetService 调用链冲突）。
  // 监听在 dispose 移除，避免泄露。
  void _onChapterRevisionChanged() {
    if (mounted) setState(() {});
  }

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
    engine.chapterRevisionNotifier.addListener(_onChapterRevisionChanged);
  }

  @override
  void dispose() {
    engine.chapterRevisionNotifier.removeListener(_onChapterRevisionChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeHandleInitialLocator();
  }

  /// 处理来自路由 extra 的 initialLocator：跳转到 locator 后，
  /// 等待 endOfFrame 让 scrollable 完成布局，再调用
  /// [ScrollToOffsetService] 滚动到字符 offset。
  ///
  /// 仅在引擎已 Ready 时触发；Ready 状态由 build 的 state$.listen 同步。
  Future<void> _maybeHandleInitialLocator() async {
    final loc = widget.initialLocator;
    if (loc == null || _initialLocatorHandled) return;
    _initialLocatorHandled = true;
    await engine.gotoLocator(loc);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    if (loc is EpubRangeLocator) {
      // Paged-mode paged break scroll (M3.4): gotoLocator navigates to the
      // correct chapter; `endOfFrame` above lets `_cachedBreaks` refresh
      // before ScrollToOffsetService reads `currentChapterPageBreaks`.
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
    if (_engineState is ReaderEngineError) {
      return ReaderErrorView(
        message: (_engineState as ReaderEngineError).message,
        onBack: () => Navigator.of(context).maybePop(),
      );
    }
    if (_engineState is! ReaderEngineReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final ui = ref.watch(readerUiControllerProvider);

    // 刷新章节标题缓存：toc 可用即解析。
    final toc = engine.toc;
    if (toc != null) {
      _chapterTitlesCache = TocTitleResolver.resolve(toc);
    }

    // typographyPanelOpen 由 _TypographyPanelTrigger 监听并弹出/收起 bottom sheet。
    return Scaffold(
      // 抽屉（左滑或图标触发）：TocDrawer。
      drawer: _buildTocDrawer(context),
      onDrawerChanged: (open) {
        // 用户从外部滑出/收起抽屉时同步 UI 状态。
        final notifier = ref.read(readerUiControllerProvider.notifier);
        if (open) {
          notifier.openTocDrawer();
        } else if (ui.tocDrawerOpen) {
          notifier.closeTocDrawer();
        }
      },
      endDrawer: _buildNotesDrawer(context),
      body: Builder(
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
                onOpenToc: () => Scaffold.of(innerContext).openDrawer(),
                onOpenNotes: () => Scaffold.of(innerContext).openEndDrawer(),
                onOpenTypography: () => ref
                    .read(readerUiControllerProvider.notifier)
                    .openTypographyPanel(),
              ),
            ),
            // 选区 toolbar overlay。仅在有非空 selection 时显示。
            if (_selection != null && _selection!.plainText.isNotEmpty)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: Center(
                  child: HighlightSelectionControls(
                    onHighlight: _onToolbarHighlight,
                    onNote: _onToolbarNote,
                    onCopy: _onCopySelection,
                  ),
                ),
              ),
            // 底栏始终可见，显示阅读进度。
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ReaderProgressBar(engine: engine),
            ),
            // typography 面板的触发器（不可见 listener）。
            _TypographyPanelTrigger(engine: engine),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesDrawer(BuildContext context) {
    final notesAsync = ref.watch(notesControllerProvider);
    return notesAsync.when(
      data: (s) => NotesDrawer(
        annotations: s.annotations,
        chapterTitles: _chapterTitlesCache,
        onTap: (id) => _onAnnotationTap(id),
        onLongPress: (id) => _onAnnotationLongPress(id),
        onClose: () => Navigator.of(context).maybePop(),
      ),
      loading: () =>
          const Drawer(child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Drawer(child: Center(child: Text('$e'))),
    );
  }

  Future<void> _onAnnotationTap(String id) async {
    final notesState = ref.read(notesControllerProvider).valueOrNull;
    final ann = notesState?.annotations
        .cast<Annotation?>()
        .firstWhere((a) => a?.id == id, orElse: () => null);
    if (ann == null) return;
    await engine.gotoLocator(ann.locator);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await Navigator.of(context).maybePop(); // 关闭 endDrawer
    if (!mounted) return;
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    final loc = ann.locator;
    if (loc is EpubRangeLocator) {
      // Paged-mode paged break scroll (M3.4): gotoLocator navigates to the
      // correct chapter; `endOfFrame` above lets `_cachedBreaks` refresh
      // before ScrollToOffsetService reads `currentChapterPageBreaks`.
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

  /// toolbar 「高亮」：选颜色 → addHighlight → 清选区。
  Future<void> _onToolbarHighlight() async {
    final sel = _selection;
    if (sel == null) return;
    final color = await showDialog<HighlightColor>(
      context: context,
      builder: (_) => const HighlightColorPickerDialog(),
    );
    if (color == null || !mounted) return;
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
    await ref
        .read(notesControllerProvider.notifier)
        .addHighlight(locator, color, text);
    if (mounted) setState(() => _selection = null);
  }

  /// toolbar 「笔记」：与「高亮」共用 flow；颜色选好后写入高亮，
  /// 用户在 drawer 长按该条目再编辑 note。M3.2 简化，避免在 toolbar
  /// 里串行弹出 color picker + NoteEditorSheet 造成 UX 摩擦。
  Future<void> _onToolbarNote() => _onToolbarHighlight();

  void _onCopySelection() {
    final sel = _selection;
    if (sel == null) return;
    Clipboard.setData(ClipboardData(text: sel.plainText));
    if (mounted) setState(() => _selection = null);
  }

  Widget _buildTocDrawer(BuildContext context) {
    final toc = engine.toc;
    if (toc == null) {
      return const Drawer(child: Center(child: Text('目录加载中…')));
    }
    return Drawer(
      child: TocDrawer(
        toc: toc,
        onSelect: (entry) async {
          await engine.gotoTocEntry(entry);
          // 跳转后关闭抽屉。
          if (context.mounted) {
            Scaffold.of(context).closeDrawer();
          }
        },
      ),
    );
  }

  /// 简化处理：暂未从 Book 元数据取得标题，显示统一占位。
  /// M2.5-2 接入 CFI restore 时，可在此传入对应的书名。
  String _bookTitle() => '阅读中';
}

/// 监听 [ReaderUiState.typographyPanelOpen] 并弹出/收起 TypographyPanel 的
/// 不可见 listener widget。
class _TypographyPanelTrigger extends ConsumerStatefulWidget {
  final ReaderEngine engine;

  const _TypographyPanelTrigger({required this.engine});

  @override
  ConsumerState<_TypographyPanelTrigger> createState() =>
      _TypographyPanelTriggerState();
}

class _TypographyPanelTriggerState
    extends ConsumerState<_TypographyPanelTrigger> {
  bool _sheetShown = false;

  void _handleStateChange(bool open) {
    if (open && !_sheetShown) {
      _sheetShown = true;
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => Consumer(
          builder: (ctx, ref, _) {
            final profilesAsync = ref.watch(typographyProfileProvider);
            final fontsAsync = ref.watch(fontLibraryProvider);
            final profiles = profilesAsync.valueOrNull ?? const [];
            final userFonts = fontsAsync.valueOrNull ?? const [];
            final currentProfile = profiles.isEmpty
                ? null
                : profiles.firstWhere(
                    (p) => p.settings == widget.engine.typography,
                    orElse: () => profiles.first,
                  );
            return TypographyPanel(
              current: widget.engine.typography,
              onChanged: (settings) => widget.engine.setTypography(settings),
              profiles: profiles,
              currentProfile: currentProfile,
              onSelectProfile: (p) {
                widget.engine.setTypography(p.settings);
                ref.read(typographyProfileRepositoryProvider).setDefault(p.id);
              },
              onSaveAsProfile:
                  ({required settings, required overwrite, newName}) async {
                final repo =
                    ref.read(typographyProfileRepositoryProvider);
                if (overwrite) {
                  final def = await repo.getDefault();
                  if (def != null) {
                    await repo.update(def.id, settings: settings);
                  }
                } else {
                  await repo.insert(
                      name: newName ?? '新预设',
                      settings: settings,
                      isDefault: false);
                }
                ref.invalidate(typographyProfileProvider);
              },
              userFonts: userFonts,
            );
          },
        ),
      ).whenComplete(() {
        // 用户通过下滑或点击外部关闭 sheet 时，同步 UI 状态。
        _sheetShown = false;
        ref.read(readerUiControllerProvider.notifier).closeTypographyPanel();
      });
    } else if (!open && _sheetShown) {
      _sheetShown = false;
      if (context.mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(readerUiControllerProvider,
        (previous, next) => _handleStateChange(next.typographyPanelOpen));
    return const SizedBox.shrink();
  }
}

/// 监听 [ReaderEngine.currentLocation$] 的 ReaderBottomBar 包装。
class _ReaderProgressBar extends StatefulWidget {
  final ReaderEngine engine;

  const _ReaderProgressBar({required this.engine});

  @override
  State<_ReaderProgressBar> createState() => _ReaderProgressBarState();
}

class _ReaderProgressBarState extends State<_ReaderProgressBar> {
  Locator? _current;

  @override
  void initState() {
    super.initState();
    widget.engine.currentLocation$.listen((loc) {
      if (mounted) setState(() => _current = loc);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ReaderBottomBar(
      chapterTitle: _chapterTitle(_current),
      percent: _estimatePercent(_current),
    );
  }

  String? _chapterTitle(Locator? loc) {
    if (loc is EpubCfiLocator) return loc.chapterTitle;
    return null;
  }

  double _estimatePercent(Locator? loc) {
    if (loc is EpubCfiLocator) {
      return (loc.chapterIndex / 100).clamp(0.0, 1.0);
    }
    return 0.0;
  }
}
