import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';

import 'pdf_outline_bridge.dart';
import 'pdf_selection_bridge.dart';
import 'pdf_theme.dart';

/// pdfrx 适配层 —— PDF 等价于 [EpubxRenderer]。
///
/// 持有 [PdfDocument]，自管 [ReaderEngineState] 状态机。
/// 位置流（currentLocation$）发射 [PdfPageLocator]，
/// 选区流（selection$）转发上层 SelectableRegion 输出。
///
/// M4 T2 仅实现 openFile + state + pageCount + setPage + emitLocation；
/// 真正的 widget build / toc / gotoLocator 在后续任务。
class PdfRenderer {
  PdfRenderer();

  PdfDocument? _doc;
  int _currentPage = 0;
  ReaderEngineState _state = const ReaderEngineUnloaded();
  TypographySettings _typography = TypographySettings.defaults();

  final _stateController = StreamController<ReaderEngineState>.broadcast();
  final _locationController = StreamController<Locator>.broadcast();
  final _selectionController = StreamController<HighlightSelection>.broadcast();

  ReaderEngineState get state => _state;

  /// 订阅即立即发射当前 state，再转发后续变化（与 EpubxRenderer 对齐）。
  Stream<ReaderEngineState> get state$ async* {
    yield _state;
    yield* _stateController.stream;
  }

  Stream<Locator> get currentLocation$ => _locationController.stream;
  Stream<HighlightSelection> get selection$ => _selectionController.stream;

  /// 当前持有的 pdfrx 文档（只读）。
  PdfDocument? get doc => _doc;

  /// 内部 0-based 页索引；对外通过 [PdfPageLocator] 转 1-based 页码。
  int get currentPage => _currentPage;

  /// 总页数；未打开返回 0。
  int get pageCount => _doc?.pages.length ?? 0;

  /// 加载 PDF 书签（pdfrx outline）并转换为 reader_engine [TableOfContents]。
  ///
  /// pdfrx v2.4.4：`PdfDocument.loadOutline()` 返回顶级 outline 节点列表
  /// （`Future<List<PdfOutlineNode>>`），由 [PdfOutlineBridge] 递归转换为
  /// reader_engine 的 TocEntry 树；`dest == null` 的节点被跳过。
  /// 未打开 / 失败时返回空 TOC，不抛异常（保持与 EPUB toc getter 同语义）。
  Future<TableOfContents> get toc async {
    final doc = _doc;
    if (doc == null) return TableOfContents.empty();
    try {
      final nodes = await doc.loadOutline();
      return PdfOutlineBridge.toTableOfContents(nodes);
    } catch (e, st) {
      debugPrint('PdfRenderer.toc loadOutline failed: $e\n$st');
      return TableOfContents.empty();
    }
  }

  /// 打开 PDF 文件路径，更新状态机（loading → ready / error）。
  Future<void> openFile(String path) async {
    _setState(const ReaderEngineLoading());
    try {
      _doc = await PdfDocument.openFile(path)
          .timeout(const Duration(seconds: 30));
      _currentPage = 0;
      _setState(const ReaderEngineReady());
    } on TimeoutException catch (e) {
      _setState(ReaderEngineError(
        message: 'PDF 打开超时（30秒），文件可能损坏',
        cause: TimeoutException('PDF open timeout: $path'),
      ));
      debugPrint('PdfRenderer.openFile timeout: $path\n$e');
    } catch (e, st) {
      debugPrint('PdfRenderer.openFile failed: $path\n$e\n$st');
      _setState(ReaderEngineError(message: '$e', cause: e));
    }
  }

  /// 切到指定页（0-based）。未打开 / 越界时静默 no-op。
  /// 成功时通过 [currentLocation$] 发射 [PdfPageLocator]（1-based）。
  void setPage(int page) {
    final doc = _doc;
    if (doc == null) return;
    if (page < 0 || page >= doc.pages.length) return;
    _currentPage = page;
    _emitLocation();
  }

  /// 由 [PdfReaderEngine.gotoLocator] 调用，跳转到 [PdfPageLocator] 指定页。
  /// 非 PdfPageLocator 静默 no-op（PDF 不支持 CFI/range locator）。
  Future<void> gotoLocator(Locator locator) async {
    if (locator is! PdfPageLocator) return;
    setPage(locator.page - 1);
  }

  /// 记录排版设置（PDF 实际渲染由 pdfrx 内部决定，此方法仅供 API 兼容）。
  Future<void> setTypography(TypographySettings settings) async {
    _typography = settings;
  }

  /// 当前排版设置（API 兼容；PDF 不实际使用）。
  TypographySettings get typography => _typography;

  void _emitLocation() {
    if (_doc == null) return;
    _locationController.add(PdfPageLocator(
      page: _currentPage + 1, // 0-based internal → 1-based pdfrx
      offsetX: 0,
      offsetY: 0,
    ));
  }

  /// 由上层 SelectableRegion 在用户松开选区时调用。
  void emitSelection(HighlightSelection selection) {
    _selectionController.add(selection);
  }

  void _setState(ReaderEngineState next) {
    _state = next;
    _stateController.add(next);
  }

  /// 阅读区 widget。doc 未加载时返回 SizedBox.shrink。
  ///
  /// T7：根据 [_typography.theme] 用 [PdfTheme.applyTheme] 包装 PdfViewer，
  /// 实现 sepia / night / eInk 主题适配（pdfrx 原生不支持）。
  ///
  /// T8：在 [PdfViewerParams] 挂 `buildContextMenu` 钩子；用户拖选文本后
  /// pdfrx 调起该 builder，里面异步取选中文本 + 从 anchor 拿页码，
  /// 通过 [_PdfHighlightMenuButton] 渲染「高亮」按钮；点击调
  /// [emitSelection]，把 [HighlightSelection] 推到 [selection$] 流。
  /// 后续任务（T9 扫描 banner）会在此方法内继续插入钩子。
  Widget build(BuildContext context) {
    final doc = _doc;
    if (doc == null) return const SizedBox.shrink();
    return PdfTheme.applyTheme(
      theme: _typography.theme,
      child: PdfViewer.file(
        doc.sourceName,
        params: PdfViewerParams(
          textSelectionParams: const PdfTextSelectionParams(enabled: true),
          buildContextMenu: (context, params) {
            if (!params.isTextSelectionEnabled) return null;
            return _PdfHighlightMenuButton(
              params: params,
              onHighlight: emitSelection,
              fallbackPage: _currentPage + 1,
            );
          },
        ),
      ),
    );
  }

  /// 释放 pdfrx 文档与所有 StreamController。
  Future<void> dispose() async {
    await _doc?.dispose();
    await _stateController.close();
    await _locationController.close();
    await _selectionController.close();
  }
}

/// 上下文菜单里的「高亮」按钮包装。
///
/// pdfrx 的 `PdfViewerContextMenuBuilderParams.textSelectionDelegate.getSelectedText()`
/// 是 `Future<String>`，但 `buildContextMenu` 同步返回 `Widget`，
/// 所以用 [StatefulWidget] + [State.initState] 异步取文本再 setState 渲染按钮。
///
/// 页码取自 `params.a?.page.pageNumber`（pdfrx 1-based）；若 anchor 缺失
/// （如全选清空等边界场景），用 [fallbackPage] 兜底。
class _PdfHighlightMenuButton extends StatefulWidget {
  const _PdfHighlightMenuButton({
    required this.params,
    required this.onHighlight,
    required this.fallbackPage,
  });

  final PdfViewerContextMenuBuilderParams params;
  final ValueChanged<HighlightSelection> onHighlight;
  final int fallbackPage;

  @override
  State<_PdfHighlightMenuButton> createState() =>
      _PdfHighlightMenuButtonState();
}

class _PdfHighlightMenuButtonState extends State<_PdfHighlightMenuButton> {
  String? _selectedText;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedText();
  }

  Future<void> _loadSelectedText() async {
    String? text;
    try {
      final raw = await widget.params.textSelectionDelegate.getSelectedText();
      text = raw.isEmpty ? null : raw;
    } catch (e) {
      debugPrint('PdfRenderer._PdfHighlightMenuButton getSelectedText: $e');
    }
    if (!mounted) return;
    setState(() {
      _selectedText = text;
      _loaded = true;
    });
  }

  int get _page =>
      widget.params.a?.page.pageNumber ?? widget.fallbackPage;

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: PdfSelectionBridge.buildHighlightButton(
        selectedText: _selectedText,
        page: _page,
        onHighlight: (sel) {
          widget.onHighlight(sel);
          // 高亮提交后关掉菜单（与 EPUB 行为对齐：松开手 → 菜单消失）。
          widget.params.dismissContextMenu();
        },
      ),
    );
  }
}
