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
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';

import 'pdf_error_banner.dart';
import 'pdf_outline_bridge.dart';
import 'pdf_scanned_detector.dart';
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

  /// T13: 双页布局开关。由 reader_body 通过 LayoutBuilder 在每次 build 前
  /// 根据 `constraints.maxWidth >= 1200 && !isScanned` 设置（PDF 引擎的
  /// `paginationMode` 始终是 scroll，pdfrx 本身按页固定布局，因此触发条件
  /// 实质只看宽度 + 非 扫描件）。默认 false —— 窄屏 / 扫描件维持单页渲染。
  ///
  /// 文本选区上下文菜单在双页模式下被禁用（页面归属歧义）。需要做高亮的
  /// 用户可以缩窄窗口切回单页模式。此 trade-off 在 commit message 中记录。
  ///
  /// Setter 在进入双页模式时调 [setPage] 重新 snap [_currentPage] 到偶数，
  /// 避免 toggle 瞬间 `_currentPage` 仍为奇数导致 `currentLocation$` 发射
  /// 错误页码（page indicator 显示 N+1 而实际可见 spread 起始于 N）。
  bool _dualPageMode = false;
  bool get dualPageMode => _dualPageMode;
  set dualPageMode(bool value) {
    if (_dualPageMode == value) return;
    _dualPageMode = value;
    if (value) setPage(_currentPage);
  }

  /// T13: 缓存 [_scannedFuture] 的最新解析结果，供 reader_body 同步判断
  /// `isScanned` 用（决定是否启用 dualPageMode）。null 表示尚未解析过。
  bool? _scannedCache;

  /// T13: 双页布局下两侧 PdfViewer 的 controller，用于在 onViewerReady
  /// 回调里 `goToPage` 到目标页。同一 PdfRenderer 实例下复用，避免每次
  /// build 都创建新 controller 导致 pdfrx 状态丢失。
  final PdfViewerController _leftController = PdfViewerController();
  final PdfViewerController _rightController = PdfViewerController();

  /// M4.6-fix: 单页模式的 controller。setPage 后用它 goToPage 滚动，
  /// 否则 PdfViewer 不知道 _currentPage 变了（缩略图跳转/翻页都失效）。
  final PdfViewerController _mainController = PdfViewerController();

  /// 缓存最近一次成功读取的 PDF 字节，供 [PdfViewer.data] 复用。
  ///
  /// pdfrx 在 Windows Debug build 下用 [PdfViewer.file] 重新打开同一文件时
  /// 偶发触发 `FPDF_LoadDocument` 失败并误报为密码错误（参见
  /// espresso3389/pdfrx#166）。改成 [PdfViewer.data] 直接走
  /// `FPDF_LoadMemDocument` 内存加载路径，绕过文件路径/句柄相关问题。
  Uint8List? _bytes;

  /// 缓存的「扫描件判定」Future。每次 [openFile] 切书时清空，重新计算。
  /// 避免每次 [build] 都跑 3 次 pdfrx loadText（昂贵且异步）。
  Future<bool>? _scannedFuture;

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

  /// T13: 是否为扫描件。同步返回 [_scannedCache] 的最新值；未解析完成时
  /// 返回 false（保守降级到单页，避免阻塞首屏）。reader_body 据此判断
  /// 是否启用双页布局。
  bool get isScanned => _scannedCache ?? false;

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
  ///
  /// 实现走「先 readAsBytes 再 [PdfDocument.openData]」路径而非
  /// [PdfDocument.openFile]，以绕过 pdfrx 在 Windows Debug build 上的
  /// `FPDF_LoadDocument` 兼容性问题（espresso3389/pdfrx#166）。读字节
  /// 失败（文件不存在/权限问题）会被外层 catch 捕获并转 [ReaderEngineError]。
  Future<void> openFile(String path) async {
    _setState(const ReaderEngineLoading());
    try {
      _bytes = await File(path).readAsBytes();
      _doc = await PdfDocument.openData(_bytes!)
          .timeout(const Duration(seconds: 30));
      _currentPage = 0;
      _scannedFuture = null; // 切书清空缓存，下次 build 重新判定
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
  ///
  /// T13：[dualPageMode] 为 true 时把目标页 snap 到偶数（左页），并 clamp
  /// 到 `pages.length - 2`（保证左右页都存在；末页若是单独一页直接保留
  /// 单页呈现，由 build 兜底 SizedBox.shrink 右半边）。
  ///
  /// M4.6-fix (#1/#2)：setPage 后调 controller.goToPage 滚动 PdfViewer。
  /// 修复前单页 PdfViewer 无 controller，缩略图点击只改 _currentPage 不滚动；
  /// 双页 onViewerReady 只在首次 init 触发，翻页/跳转后 viewer 不更新。
  void setPage(int page) {
    final doc = _doc;
    if (doc == null) return;
    if (dualPageMode) {
      int target = page;
      if (target.isOdd) target -= 1;
      if (target < 0) target = 0;
      if (target >= doc.pages.length) target = doc.pages.length - 1;
      _currentPage = target;
      _emitLocation();
      _goToDualPageSpread(target);
      return;
    }
    if (page < 0 || page >= doc.pages.length) return;
    _currentPage = page;
    _emitLocation();
    _goToMainPage(page);
  }

  /// M4.6-fix: 单页模式滚动 _mainController 到指定 0-based 页。
  void _goToMainPage(int page0) {
    final pn = page0 + 1;
    if (_mainController.isReady) {
      _mainController.goToPage(pageNumber: pn);
    }
  }

  /// M4.6-fix: 双页模式滚动左右 controller 到 spread（leftIdx 0-based 偶数）。
  void _goToDualPageSpread(int leftIdx) {
    final leftPn = leftIdx + 1;
    final rightPn = leftIdx + 2;
    if (_leftController.isReady) {
      _leftController.goToPage(pageNumber: leftPn);
    }
    if (_rightController.isReady) {
      _rightController.goToPage(pageNumber: rightPn);
    }
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
  ///
  /// T9：在 reader 顶部条件渲染 [PdfScannedBanner]。判定走
  /// [PdfScannedDetector.isLikelyScanned]（前 3 页累计文本字符数 < 100），
  /// 结果缓存在 [_scannedFuture]（openFile 时重置），用 [FutureBuilder]
  /// 异步驱动，避免阻塞首次 build。扫描件场景同时显式禁用文本选区
  /// （pdfrx 内部本就不工作，显式禁更清晰，避免空选区错误上下文）。
  Widget build(BuildContext context) {
    final doc = _doc;
    final bytes = _bytes;
    if (doc == null || bytes == null) return const SizedBox.shrink();
    _scannedFuture ??= PdfScannedDetector.isLikelyScanned(doc);
    return FutureBuilder<bool>(
      future: _scannedFuture,
      builder: (context, snap) {
        // T13: 缓存解析结果，让 reader_body 同步读到 isScanned 决定是否
        // 启用 dualPageMode。snap.data == null 表示 loading，沿用上次值。
        if (snap.hasData) _scannedCache = snap.data;
        final showBanner = _scannedCache == true;
        if (dualPageMode && !showBanner) {
          return _buildDualPage(doc, bytes, showBanner: false);
        }
        return Column(
          children: [
            if (showBanner) const PdfScannedBanner(),
            Expanded(
              child: PdfTheme.applyTheme(
                theme: _typography.theme,
                child: PdfViewer.data(
                  bytes,
                  sourceName: doc.sourceName,
                  controller: _mainController,
                  params: PdfViewerParams(
                    textSelectionParams: PdfTextSelectionParams(
                      enabled: !showBanner,
                    ),
                    errorBannerBuilder: (context, error, _, __) =>
                        PdfErrorBanner(error: error),
                    onViewerReady: (pdfDoc, controller) {
                      // M4.6-fix: viewer ready 后跳到当前页（缩略图跳转/恢复进度）。
                      controller.goToPage(pageNumber: _currentPage + 1);
                    },
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
              ),
            ),
          ],
        );
      },
    );
  }

  /// T13: 双页布局渲染。左侧永远是偶数（0-based）索引页，右侧是奇数索引页。
  /// 末页若为孤页（索引等于 pageCount - 1 且为偶数），右侧用 SizedBox.shrink。
  ///
  /// 不挂 `buildContextMenu` —— 双页模式下选区命中具体哪一页存在歧义，
  /// 用户需要切到窄屏单页模式做高亮。Text selection 也因此被禁用。
  Widget _buildDualPage(PdfDocument doc, Uint8List bytes,
      {required bool showBanner}) {
    final leftIdx = _currentPage.isEven ? _currentPage : _currentPage - 1;
    if (leftIdx < 0) return const SizedBox.shrink();
    final rightIdx = leftIdx + 1;
    final hasRight = rightIdx < doc.pages.length;
    // M4.6-fix: 左右 PdfViewer 必须用不同 sourceName，否则 pdfrx 按
    // PdfDocumentRefKey(sourceName) 复用同一个 PdfDocumentListenable，
    // 导致两个 _PdfViewerState 的 _attach 竞态、controller 互相覆盖，
    // 表现为左右显示同页或错位。加 #L/#R 后缀让两侧独立加载。
    final leftSourceName = '${doc.sourceName}#L';
    final rightSourceName = '${doc.sourceName}#R';
    return Row(
      children: [
        Expanded(
          child: PdfTheme.applyTheme(
            theme: _typography.theme,
            child: PdfViewer.data(
              bytes,
              sourceName: leftSourceName,
              controller: _leftController,
              params: PdfViewerParams(
                textSelectionParams:
                    PdfTextSelectionParams(enabled: !showBanner),
                errorBannerBuilder: (context, error, _, __) =>
                    PdfErrorBanner(error: error),
                onViewerReady: (pdfDoc, controller) {
                  controller.goToPage(pageNumber: leftIdx + 1);
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: hasRight
              ? PdfTheme.applyTheme(
                  theme: _typography.theme,
                  child: PdfViewer.data(
                    bytes,
                    sourceName: rightSourceName,
                    controller: _rightController,
                    params: PdfViewerParams(
                      textSelectionParams:
                          PdfTextSelectionParams(enabled: !showBanner),
                      errorBannerBuilder: (context, error, _, __) =>
                          PdfErrorBanner(error: error),
                      onViewerReady: (pdfDoc, controller) {
                        controller.goToPage(pageNumber: rightIdx + 1);
                      },
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// 释放 pdfrx 文档与所有 StreamController。
  ///
  /// T13: PdfViewerController 自身不持有 native 资源（pdfrx 文档由
  /// PdfViewer 管理生命周期），无需 dispose；这里仅关闭文档与流。
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
