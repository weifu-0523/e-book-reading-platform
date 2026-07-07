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

/// M4.6-fix6: 文件日志辅助（[PDF-DIAG] 同时写到 stdout + %TEMP%\zhiyue_pdf.log）。
///
/// 用户从 PowerShell 启动 exe 时 Dart debugPrint 输出可能不显示在终端
/// （Flutter GUI app 的 stdout 在某些启动方式下被重定向）。改用文件日志
/// 让用户能直接贴文件内容回来，定位"PDF 翻 N 页卡死"的真因。
///
/// 日志文件路径：`%TEMP%\zhiyue_pdf.log`（与 zhiyue_runner.log 同目录）。
IOSink? _pdfLogSink;
late final String _pdfLogPath =
    '${Directory.systemTemp.path}${Platform.pathSeparator}zhiyue_pdf.log';

void pdfDiagLog(String msg) {
  final line = '[PDF-DIAG] $msg';
  debugPrint(line);
  try {
    _pdfLogSink ??=
        File(_pdfLogPath).openWrite(mode: FileMode.append);
    _pdfLogSink!.writeln('${DateTime.now().toIso8601String()} $line');
  } catch (e) {
    // 文件写失败不影响主流程
  }
}

/// 强制 flush 日志（用于关键事件如 setPage / goToPage 后）。
void _pdfDiagFlush() {
  try {
    _pdfLogSink?.flush();
  } catch (_) {}
}

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
    pdfDiagLog('dualPageMode set: $_dualPageMode → $value');
    if (_dualPageMode == value) return;
    _dualPageMode = value;
    if (value) setPage(_currentPage);
  }

  /// M4.6-fix5: build 计数 + 内存采样 Timer（诊断 PDF 翻 N 页卡死用）。
  /// build 频率反映 widget tree 是否被频繁重建（pdfrx 频繁 reload 嫌疑）。
  /// Timer 周期采样进程私有内存，定位是否内存累积导致 PDFium 阻塞。
  int _buildCount = 0;
  Timer? _memMonitor;

  /// 启动周期内存采样（每 3 秒一次）。openFile 成功后调。
  void _startMemMonitor() {
    _memMonitor?.cancel();
    _memMonitor = Timer.periodic(const Duration(seconds: 3), (_) {
      final rss = ProcessInfo.currentRss;
      final maxRss = ProcessInfo.maxRss;
      pdfDiagLog('mem sample: rss=${_mb(rss)}MB '
          'maxRss=${_mb(maxRss)}MB builds=$_buildCount');
    });
  }

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  /// T13: 缓存 [_scannedFuture] 的最新解析结果，供 reader_body 同步判断
  /// `isScanned` 用（决定是否启用 dualPageMode）。null 表示尚未解析过。
  bool? _scannedCache;

  /// M4.6-fix: 单页模式的 controller。PdfViewer 首次 onViewerReady 时赋值，
  /// 之后用它在 setPage（缩略图跳转/翻页）时 goToPage 滚动 viewer。
  /// 不作为 PdfViewer.data 的 controller 参数传入——那样会让 controller
  /// 跨书/跨 widget 重建复用，导致新文档加载时 controller 还附着旧 state，
  /// 表现为"阅读区不加载"。改为让 PdfViewer 自管 controller，ready 时回调
  /// 把引用交给我们，既能跳转又不干扰加载。
  PdfViewerController? _mainController;

  /// M4.6-fix9: 双页模式的左右 controller。
  ///
  /// **方案 A''（用户确认）**：双 PdfViewer + **相同 sourceName** → pdfrx
  /// CanonicalizedMap（pdf_document_ref.dart 第 18/78/92-97 行）共享同一份
  /// PdfDocument。这是 fix4~fix8 死锁的根治方案。
  ///
  /// 旧实现死锁链：
  /// 1. 旧实现 sourceName 加 `#L`/`#R` 后缀 → pdfrx 视为两份文档
  /// 2. 两份 PdfDocument 各 29MB → 内存翻倍
  /// 3. dispose 时序混乱 + pdfium 渲染线程未完成 → FPDF_CloseDocument 死锁
  /// 4. 进程不退出 → 持有 named mutex → exe 二次启动失败
  ///
  /// fix9：相同 sourceName → 共享 → 只一份 PdfDocument → dispose 干净。
  /// 翻页用 ValueKey 含 leftIdx 触发 widget 重建到新 initialPageNumber，
  /// 配合 NeverScrollableScrollPhysics 锁定到各自页，避免滚动错位。
  //
  // M4.6-fix10/A1: 双页彻底移除。fix9 共享 sourceName 方案在用户实测仍卡死，
  // 按用户决策锁死单页。以下字段（_dualLeftController/_dualRightController）
  // 与方法（_buildDualPage/_buildDualParams）已删除。dualPageMode setter 保留
  // 但永远不接受 true（reader_body 强制传 false）。

  /// 缓存最近一次成功读取的 PDF 字节，供 [PdfViewer.data] 复用。
  ///
  /// pdfrx 在 Windows Debug build 下用 [PdfViewer.file] 重新打开同一文件时
  /// 偶发触发 `FPDF_LoadDocument` 失败并误报为密码错误（参见
  /// espresso3389/pdfrx#166）。改成 [PdfViewer.data] 直接走
  /// `FPDF_LoadMemDocument` 内存加载路径，绕过文件路径/句柄相关问题。
  Uint8List? _bytes;

  /// M4.6-fix19: 每次 [openFile] 生成**唯一**的 sourceName（含时间戳），
  /// 强制 pdfrx 内部 `_listenables` 全局 cache miss。
  ///
  /// **M4.6-fix21 补充**：fix21 把 `openFile` 从 [PdfDocument.openData] 改到
  /// [PdfDocument.openCustom]，但 sourceName 仍是 pdfrx cache key（两者底层
  /// 都进 `PdfDocumentRefKey(sourceName)`），所以 fix19 的唯一性策略**完全
  /// 保留**——见 [openFile] 的 `pdfDiagLog('openFile unique sourceName: ...')`
  /// 日志在 fix21 后仍会出现。
  ///
  /// **根因（PDF-1 系列的真因）**：旧实现不传 sourceName → pdfrx 用
  /// `_sourceNameFromData(data)` = `'data%${sha256(data)}'` 作 cache key
  /// （见 pdfrx_engine lib/src/native/pdfrx_pdfium.dart:645-647）。
  /// 同一 PDF 文件字节不变 → SHA-256 不变 → **sourceName 跨会话稳定**。
  ///
  /// pdfrx `_listenables`（pdf_document_ref.dart:92）是**进程级 static
  /// CanonicalizedMap**，按 sourceName 缓存 PdfDocumentListenable。一旦某次
  /// openData 卡死（dispose 不完整 / pdfium native 异步释放未完成），
  /// broken listenable 残留在 cache，之后任何同 sourceName 的 openData 都
  /// 命中 broken entry → FPDF_LoadMemDocument 永不返回 → 30s 超时。
  ///
  /// 这就是为何"昨天能开，今天不能开"——昨天第一次 cache 空，今天 cache
  /// 里有昨天卡死留下的 broken entry。fix18 试"不调 dispose"反而更糟
  /// （pdfrx 内部 state 半活跃），fix13 的 dispose+timeout 缓解但治标不治本。
  ///
  /// **本修复**（fix19 一行治本）：每次 openFile 用
  /// `'zhiyue-pdf-${DateTime.now().microsecondsSinceEpoch}'` 作 sourceName。
  /// - 每次进书 → 新 key → cache miss → 全新 listenable → pdfium 全新 FPDF doc
  /// - 退出再进 → 又是新 key → 永不命中旧 broken cache
  /// - 同进程开不同 PDF → key 不同 → 互不干扰
  /// - 进程退出（main.dart exit(0)）→ static cache 自然清空
  ///
  /// 代价：失去跨 PdfViewer 共享文档的内存优化。但智阅是单 PDF 单实例
  /// 阅读，不存在多 viewer 共享场景，代价为零。
  ///
  /// **注意**：fix19 解决的是 cache pollution；fix21 解决的是另一个独立的
  /// `FPDF_LoadCustomDocument` 条件变量死锁（见 [openFile] dartdoc 与 spec
  /// 2026-07-07-m4.6-fix21）。两者互补，不冲突。
  String? _uniqueSourceName;

  /// M4.6-fix4: 缓存的「扫描件判定」Future + 同步缓存。
  ///
  /// 重构前：每次 [build] 用 `FutureBuilder(future: _scannedFuture)`，导致
  /// 父级 rebuild 时 FutureBuilder 重建 → Column 重建 → PdfViewer 重建 →
  /// pdfrx 频繁 reload，翻 N 页后内存压力导致 loading 卡死。
  ///
  /// 重构后：[openFile] 启动 scanned 判定 Future，完成回调里写 [_scannedCache]
  /// + setState 让 [build] 用同步路径走 [_buildMain] / [_buildDualPage]。
  /// Future 仅触发一次 setState，之后 build 走同步分支，PdfViewer widget
  /// tree 不再被 FutureBuilder 包裹反复重建。
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
  /// 实现走「先 readAsBytes 再 [PdfDocument.openCustom]」路径。
  ///
  /// **M4.6-fix21（本方法的当前实现）**：改用 [PdfDocument.openCustom] 并显式
  /// 传 `maxSizeToCacheOnMemory: bytes.length`，**强制 pdfrx 走
  /// `FPDF_LoadMemDocument`（小文件路径）**，绕开 `FPDF_LoadCustomDocument`
  /// + 条件变量死锁路径。
  ///
  /// **根因（详见 spec 2026-07-07-m4.6-fix21）**：fix19 之后用 [PdfDocument.openData]
  /// 走 pdfrx 内部 `_openData` → `openCustom`，但 `openData` 把
  /// `maxSizeToCacheOnMemory` **硬编码为 null**（pdfrx_pdfium.dart:638）→
  /// 默认 1MB → 任何 >1MB 的 PDF 走 `FPDF_LoadCustomDocument` + 条件变量路径。
  /// 该路径在重复 open/close cycle 后**死锁**（espresso3389/pdfrx PR #622，
  /// jam7 2026-03-22 提交未合并，原文 "this path deadlocks after repeated
  /// open/close cycles"）。智阅实测 PDF 7/29/41MB 全部 >1MB，全走死锁路径，
  /// 表现为 ~40% 间歇性卡死（fix19 的唯一 sourceName 对此无效，因为死锁在
  /// native 条件变量层，不在 cache 层）。
  ///
  /// **三层防御（spec Architecture Decisions A1/A2/A3）**：
  /// - **L1 主路径**（本方法）：openCustom + maxSizeToCacheOnMemory=bytes.length
  ///   → pdfrx `if (fileSize <= maxSizeToCacheOnMemory)` 走 LoadMemDocument
  /// - **L2 引擎重置**（本方法开头）：调 [PdfrxEntryFunctions.instance.stopBackgroundWorker]
  ///   清零上一本书累积的 isolate 状态（pdfium 非线程安全，单例 isolate 重复
  ///   用可能边缘死锁）
  /// - **L3 进程兜底**（[dispose]）：退出书时再调一次 stopBackgroundWorker
  ///
  /// **大文件回退（>200MB）**：pdfium LoadMemDocument 一次性载入 native 堆，
  /// >200MB 可能让堆压力过大（jam7 提到 ojpro 的 caveat）。回退到旧 openData
  /// 路径（可能卡死但概率低，且 >200MB PDF 在电子书场景极罕见）。
  ///
  /// M4.6-fix4：扫描件判定 Future 在此启动（而非 build 时 ??=），完成回调
  /// 写 [_scannedCache] + setState。build 走同步路径，避免 FutureBuilder
  /// 包裹 PdfViewer 导致频繁重建。
  Future<void> openFile(String path) async {
    pdfDiagLog('=== openFile start: $path ===');
    pdfDiagLog('log file path: $_pdfLogPath');
    _pdfDiagFlush();
    _setState(const ReaderEngineLoading());
    try {
      _bytes = await File(path).readAsBytes();
      pdfDiagLog('openFile bytes read: ${_bytes!.length} bytes');
      // M4.6-fix21/L2: 读 bytes 成功后才重置 pdfrx 引擎（避免文件不存在等
      // early-fail 路径白白触发 native 调用）。重置必须在 openCustom/openData
      // 之前，确保新文档跑在干净 isolate 上，清零上一本书累积的死锁状态。
      await _resetPdfrxEngine();
      // M4.6-fix19: 唯一 sourceName 强制 pdfrx _listenables cache miss（根治
      // cache pollution，详见 _uniqueSourceName 注释）。fix21 改用 openCustom
      // 后 sourceName 仍是 cache key，唯一性保留。
      _uniqueSourceName =
          'zhiyue-pdf-${DateTime.now().microsecondsSinceEpoch}';
      // 局部非空别名：openCustom/openData 的 sourceName 形参是非空 String，
      // 而 _uniqueSourceName 是可空字段（Dart 对字段不做 promotion），用局部
      // final 捕获刚赋的值，既类型安全又便于阅读。
      final sourceName = _uniqueSourceName!;
      pdfDiagLog('openFile unique sourceName: $sourceName');
      // M4.6-fix11→fix12: 30MB PDF 秒开是常态，30s 仍打不开 = pdfium 不兼容
      // 或文件加密/损坏。fix11 把 timeout 拉到 90s 反而让用户多等一倍——
      // 用户原话"30MB 文件加载不可能这么长时间"。fix12 回到 30s budget，
      // 错误信息明确指引日志路径，让用户能贴 zhiyue_pdf.log 回馈诊断。
      // 真实根因（加密 / WPS 导出 / Office 转 PDF 等 pdfium 已知不兼容）
      // 在错误信息和日志里指明，无法在代码层面绕过——只能换库（pdfx 等）
      // 或建议用户用 Adobe Reader 重新另存为 PDF/A。
      //
      // M4.6-fix21/L1: 改用 [PdfDocument.openCustom] 强制走 FPDF_LoadMemDocument。
      // 见本方法 dartdoc 与 spec A1。大文件（>200MB）回退 openData 旧路径。
      const largeFileThreshold = 200 * 1024 * 1024; // 200MB
      if (_bytes!.length > largeFileThreshold) {
        pdfDiagLog('openFile path=openData (FALLBACK for >200MB; '
            'LoadMemDocument 堆压力风险), fileSize=${_bytes!.length}');
        _doc = await PdfDocument.openData(
          _bytes!,
          sourceName: sourceName,
        ).timeout(const Duration(seconds: 30));
      } else {
        pdfDiagLog('openFile path=openCustom (LoadMemDocument), '
            'fileSize=${_bytes!.length}');
        _doc = await PdfDocument.openCustom(
          read: _readFromBytes,
          fileSize: _bytes!.length,
          sourceName: sourceName,
          // 关键：把 maxSizeToCacheOnMemory 设为 bytes.length，
          // 强制 pdfrx 走 `if (fileSize <= maxSizeToCacheOnMemory)` 分支
          // → FPDF_LoadMemDocument（一次性载入 pdfium 堆，无条件变量、
          // 无 BackgroundWorker 串行化依赖），绕开 FPDF_LoadCustomDocument
          // + 条件变量死锁路径（PR #622 根因）。
          maxSizeToCacheOnMemory: _bytes!.length,
        ).timeout(const Duration(seconds: 30));
      }
      pdfDiagLog('openFile success: pages=${_doc!.pages.length}, '
          'sourceName=${_doc!.sourceName}');
      _currentPage = 0;
      _scannedCache = null; // 切书清空，重新判定
      _startScannedDetection();
      _startMemMonitor(); // M4.6-fix5: 诊断 PDF 卡死
      _setState(const ReaderEngineReady());
    } on TimeoutException catch (e) {
      pdfDiagLog('openFile TIMEOUT: $path ($e)');
      // M4.6-fix21 后，主路径走 LoadMemDocument + 每次 openFile 前
      // stopBackgroundWorker 重置引擎。若仍 timeout，几乎可以确定是文件
      // 本身问题：加密、WPS 导出、Office 转 PDF 等 pdfium 已知不兼容格式。
      // 错误信息指引日志路径 + 建议用 Adobe Reader 重新另存为 PDF/A。
      _setState(ReaderEngineError(
        message: 'PDF 打开超时（30秒）。已尝试 LoadMemDocument 路径 + '
            'stopBackgroundWorker 重置引擎仍超时，该 PDF 可能使用了 pdfium '
            '不兼容的格式（加密 / WPS 导出 / Office 转 PDF 等）。'
            '请尝试用 Adobe Reader 或 Edge 打开确认文件正常，'
            '或在 Adobe Reader 里"另存为"转成标准 PDF/A 后重试。'
            '详见日志：$_pdfLogPath',
        cause: TimeoutException('PDF open timeout: $path'),
      ));
    } catch (e, st) {
      pdfDiagLog('openFile ERROR: $path\n  $e\n$st');
      _setState(ReaderEngineError(message: '$e', cause: e));
    }
  }

  /// M4.6-fix21/L1: openCustom 的 read 回调 —— 从 [_bytes] 拷贝到 pdfrx 提供
  /// 的 native buffer。
  ///
  /// 仿 pdfrx 内部 `_openData` 实现（pdfrx_engine pdfrx_pdfium.dart:679-688）：
  /// pdfrx 在 BackgroundWorker isolate 里调此回调，传入 native buffer 地址、
  /// 读取起始位置、期望读取字节数；回调把 [_bytes] 对应区间拷过去，返回实际
  /// 拷贝的字节数（或 -1 表示越界）。
  ///
  /// 此回调与 pdfrx `openData` 内部走的 read 闭包**逻辑完全一致**（pdfrx
  /// `_openData` 就是这么构造 read 闭包再调 openCustom 的），我们只是把构造
  /// 提到外层、并显式传 maxSizeToCacheOnMemory 让 pdfrx 选 LoadMemDocument
  /// 路径。不存在新风险。
  int _readFromBytes(Uint8List buffer, int position, int size) {
    final data = _bytes;
    if (data == null) return -1;
    if (position + size > data.length) {
      size = data.length - position;
      if (size < 0) return -1;
    }
    for (var i = 0; i < size; i++) {
      buffer[i] = data[position + i];
    }
    return size;
  }

  /// M4.6-fix21/L2: 重置 pdfrx 引擎 —— kill BackgroundWorker isolate +
  /// FPDF_DestroyLibrary，下次 [PdfDocument.openCustom] 会自动 _ensureInit
  /// 重建干净 isolate。
  ///
  /// **为什么需要**：pdfrx `BackgroundWorker._instance` 是单例 isolate
  /// （worker.dart:17），所有 pdfium 调用串行化在里面。pdfium **非线程安全**
  /// （espresso3389/pdfrx#474 maintainer 原话），重复 open/close cycle 后
  /// isolate 状态可能进入边缘死锁。本方法在每次 openFile 前调，把上一本书
  /// 累积的状态清零。
  ///
  /// **为何不能单独依赖 L2**：stopBackgroundWorker 内部调
  /// `BackgroundWorker.compute(FPDF_DestroyLibrary)`，如果 isolate 已经
  /// 死锁，这个 compute 也会卡。所以加 5s timeout + try/catch，失败仅日志
  /// 不阻塞 —— L1 主路径绕开死锁才是治本。
  ///
  /// **API**：[PdfrxEntryFunctions.instance.stopBackgroundWorker]
  /// （pdfrx_engine 0.4.3 公开 API，pdfrx_entry_functions.dart:61）。espresso3389
  /// 在 issue #184/#430 官方推荐用于"释放 pdfium 堆 + 重置引擎状态"。
  Future<void> _resetPdfrxEngine() async {
    try {
      pdfDiagLog('stopBackgroundWorker: start');
      await PdfrxEntryFunctions.instance.stopBackgroundWorker()
          .timeout(const Duration(seconds: 5));
      pdfDiagLog('stopBackgroundWorker: done');
    } on TimeoutException {
      pdfDiagLog('stopBackgroundWorker: TIMEOUT (5s) — isolate 可能已死锁，'
          '继续 openFile 让 _ensureInit 重建');
    } catch (e, st) {
      pdfDiagLog('stopBackgroundWorker: THREW (ignored, continue): $e\n$st');
    }
  }

  /// M4.6-fix4: 启动扫描件判定，完成后 setState 让 build 走同步路径。
  ///
  /// 移除了 build 中的 FutureBuilder，因此必须通过 setState 通知 widget tree
  /// scanned 判定完成。本方法只在 [openFile] 调用一次（_scannedFuture 已在
  /// openFile 重置为 null 前清空），完成后 _scannedFuture 仍保留引用避免
  /// 重复触发。
  void _startScannedDetection() {
    final doc = _doc;
    if (doc == null) return;
    _scannedFuture = PdfScannedDetector.isLikelyScanned(doc);
    _scannedFuture!.then((result) {
      _scannedCache = result;
      _setState(const ReaderEngineReady());
    }).catchError((e) {
      debugPrint('PdfRenderer scanned detection failed: $e');
      _scannedCache = false; // 失败保守降级为非扫描件
      _setState(const ReaderEngineReady());
    });
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
    if (doc == null) {
      pdfDiagLog('setPage($page) no-op: doc null');
      return;
    }
    // M4.6-fix10/A1: dualPageMode 永远为 false（reader_body 强制锁死单页）。
    // 此分支仅为防御性兜底——若未来误把 dualPageMode 设回 true，记录警告并降级单页。
    if (dualPageMode) {
      pdfDiagLog('setPage($page) WARNING: dualPageMode unexpectedly true, '
          'falling back to single page (M4.6-fix10 locked single page)');
    }
    if (page < 0 || page >= doc.pages.length) {
      pdfDiagLog('setPage($page) out of range 0..${doc.pages.length - 1}');
      return;
    }
    _currentPage = page;
    _emitLocation();
    _goToMainPage(page);
  }

  /// M4.6-fix: 单页模式滚动 _mainController 到指定 0-based 页。
  void _goToMainPage(int page0) {
    final pn = page0 + 1;
    final c = _mainController;
    final ready = c?.isReady ?? false;
    pdfDiagLog('_goToMainPage($page0) → pn=$pn, '
        'controller=${c == null ? "null" : "set"}, ready=$ready');
    _pdfDiagFlush();
    // M4.6-fix3: controller 在 onViewerReady 才赋值，未 ready 时跳过
    // （下次 viewer ready 会用 initialPageNumber 跳到正确页）。
    if (c != null && ready) {
      try {
        c.goToPage(pageNumber: pn);
      } catch (e, st) {
        pdfDiagLog('_goToMainPage goToPage THREW: $e\n$st');
        _pdfDiagFlush();
      }
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
  /// M4.6-fix4 稳定化重构：
  /// - 移除 FutureBuilder（scanned 判定结果已由 [openFile] 异步写入
  ///   [_scannedCache] 后 setState，build 走同步路径）。父级 rebuild 不再
  ///   触发 PdfViewer 重建链。
  /// - 加 [RepaintBoundary] 把 PDF 阅读区与父级 reader_body 隔离，避免
  ///   跨区域 paint 影响引发 pdfrx reload。
  /// - PdfViewer 加 [ValueKey]（按 sourceName）：同书 State 复用稳定，
  ///   切书 sourceName 变 → 干净重建。
  Widget build(BuildContext context) {
    _buildCount++;
    final doc = _doc;
    final bytes = _bytes;
    if (doc == null || bytes == null) {
      pdfDiagLog('build #$_buildCount: doc/bytes null → SizedBox.shrink');
      return const SizedBox.shrink();
    }
    final showBanner = _scannedCache == true;
    // M4.6-fix10/A1: dualPageMode 永远 false，只走 main 分支。
    pdfDiagLog('build #$_buildCount: branch=main (dual locked off), '
        'page=${_currentPage + 1}/${doc.pages.length}, '
        'scanned=$showBanner, mainControllerReady=${_mainController?.isReady ?? false}');
    return RepaintBoundary(
      child: _buildMain(doc, bytes, showBanner: showBanner),
    );
  }

  /// M4.6-fix4: 单页模式渲染分支（从 build 抽出，去 FutureBuilder）。
  Widget _buildMain(PdfDocument doc, Uint8List bytes,
      {required bool showBanner}) {
    // M4.6-fix19: sourceName 用 openFile 时生成的唯一值（_uniqueSourceName），
    // 不用 doc.sourceName —— doc.sourceName 来自 openData，已是同一值，
    // 但语义上这里要保证与 PdfDocumentRefData cache key 完全一致。
    final sourceName = _uniqueSourceName ?? doc.sourceName;
    return Column(
      children: [
        if (showBanner) const PdfScannedBanner(),
        Expanded(
          child: PdfTheme.applyTheme(
            theme: _typography.theme,
            child: PdfViewer.data(
              bytes,
              key: ValueKey('pdf-main-$sourceName'),
              sourceName: sourceName,
              // M4.6-fix3: 用 initialPageNumber 设初始页（恢复进度），
              // 不传 controller（让 PdfViewer 自管，避免跨书复用导致加载失败）。
              // onViewerReady 只存 controller 引用供 setPage 跳转用，不调
              // goToPage（避免 rebuild 循环）。
              initialPageNumber: _currentPage + 1,
              params: _buildMainParams(showBanner: showBanner),
            ),
          ),
        ),
      ],
    );
  }

  /// M4.6-fix4: 单页模式 PdfViewerParams 构造。
  ///
  /// 单独抽出便于未来按需 cache（当前每次 build 调用都 new 一个 PdfViewerParams
  /// 实例，但 pdfrx `doChangesRequireReload` 对函数字段比对为引用相等，相同
  /// 闭包不触发 reload；此处 showBanner 变化时 textSelectionParams.enabled
  /// 变化是预期的 reload 触发点）。
  PdfViewerParams _buildMainParams({required bool showBanner}) {
    return PdfViewerParams(
      textSelectionParams: PdfTextSelectionParams(
        enabled: !showBanner,
      ),
      errorBannerBuilder: (context, error, _, __) {
        pdfDiagLog('pdfrx errorBanner: $error');
        return PdfErrorBanner(error: error);
      },
      onViewerReady: (pdfDoc, controller) {
        pdfDiagLog('onViewerReady(main): pages=${pdfDoc.pages.length}, '
            'controllerReady=${controller.isReady}, currentPage=${controller.pageNumber}');
        // M4.6-fix3: 存 controller 引用，setPage 用它 goToPage。
        _mainController = controller;
      },
      onDocumentChanged: (pdfDoc) {
        pdfDiagLog('onDocumentChanged: ${pdfDoc?.pages.length ?? 0} pages');
      },
      buildContextMenu: (context, params) {
        if (!params.isTextSelectionEnabled) return null;
        return _PdfHighlightMenuButton(
          params: params,
          onHighlight: emitSelection,
          // M4.6-fix4: fallback 用 pdfrx 自带的 anchor pageNumber（context
          // menu 触发时必有 anchor）；这里仅极端边界 fallback 用 1。
          fallbackPage: params.a?.page.pageNumber ?? 1,
        );
      },
    );
  }

  /// 释放 pdfrx 文档与所有 StreamController。
  ///
  /// **M4.6-fix21 三层防御的 L3（进程兜底）**：在 `_doc?.dispose()` 之后追加
  /// `stopBackgroundWorker`，退出书时主动 kill isolate + FPDF_DestroyLibrary，
  /// 给下一本书（如果同进程再开）一个干净起点。
  ///
  /// **三层防御回顾**（spec Architecture Decisions A1/A2/A3）：
  /// - L1 主路径：openCustom + maxSizeToCacheOnMemory=bytes.length（绕开死锁）
  /// - L2 引擎重置：openFile 前 stopBackgroundWorker（清零累积状态）
  /// - **L3 进程兜底**：本方法 dispose 时 stopBackgroundWorker（主动清理）
  ///
  /// 任一层失效仍有兜底：L1 失效（极端 native bug）→ L2 重置兜底；L2 也失效
  /// → L3 清理 + 用户重启进程（与现状相同）。
  ///
  /// **L3 仅在 _doc 非 null 时触发**：从未加载过文档时 pdfrx 引擎未启动，
  /// 调 stopBackgroundWorker 会 spawn isolate 但在 widget 测试 FakeAsync 里
  /// 无法推进 → 挂死。生产环境 dispose 必在 openFile 之后，此 guard 不影响
  /// 生产行为，只是让 [PdfRenderer] 在未加载状态下 dispose 也安全（用于单测）。
  ///
  /// M4.6-fix19 后，pdfium cache pollution 已根治（每次 openFile 用唯一
  /// sourceName 强制 cache miss）。dispose 仍保留 timeout + 1.5s buffer
  /// 作为防御性兜底。
  ///
  /// 历史（fix9→fix13→fix18→fix19→fix21）：见 [_uniqueSourceName] 字段注释。
  ///
  /// T13: PdfViewerController 自身不持有 native 资源（pdfrx 文档由
  /// PdfViewer 管理生命周期），无需 dispose；这里仅关闭文档与流。
  Future<void> dispose() async {
    pdfDiagLog('dispose start: doc=${_doc != null}, '
        'mainController=${_mainController != null}, '
        'sourceName=$_uniqueSourceName');
    _memMonitor?.cancel();
    _memMonitor = null;
    // M4.6-fix21: doc-dispose + 1.5s buffer + stopBackgroundWorker（L3）都仅在
    // _doc 非 null 时执行。三者都依赖真实 pdfium 异步释放，在 widget 测试的
    // FakeAsync 里 Future.delayed / isolate spawn 无法推进 → 挂死。生产环境
    // dispose 必在 openFile 之后（_doc 非 null），此 guard 不影响生产行为，
    // 只是让 PdfRenderer 在未加载状态下 dispose 也安全（用于单测）。
    //
    // 这也顺手修了 fix11~18（commit 9c6ffad）引入的 1.5s buffer 让
    // pdf_renderer_build_test 在 FakeAsync 里挂死的 pre-existing 问题。
    if (_doc != null) {
      try {
        await _doc!.dispose().timeout(const Duration(seconds: 10));
        // 保留 1.5s buffer：pdfium native 异步释放，给 FPDF_CloseDocument
        // 充分时间（防御性，fix19 后理论上不再必要，但不删以免其他 corner case）。
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      } on TimeoutException {
        pdfDiagLog('dispose doc.dispose TIMEOUT (10s) — pdfium native stuck; '
            'cache miss 策略已防下次失败，但建议重启 exe 释放 native 内存');
      } catch (e, st) {
        pdfDiagLog('dispose doc.dispose THREW: $e\n$st');
      }
      // M4.6-fix21/L3: 主动重置 pdfrx 引擎，给同进程下一次 openFile 一个干净
      // 起点（isolate + pdfium 堆都重建）。失败仅日志，不影响 stream 关闭。
      try {
        pdfDiagLog('dispose stopBackgroundWorker: start');
        await PdfrxEntryFunctions.instance.stopBackgroundWorker()
            .timeout(const Duration(seconds: 5));
        pdfDiagLog('dispose stopBackgroundWorker: done');
      } on TimeoutException {
        pdfDiagLog('dispose stopBackgroundWorker: TIMEOUT (5s) — ignored');
      } catch (e, st) {
        pdfDiagLog('dispose stopBackgroundWorker: THREW (ignored): $e\n$st');
      }
    } else {
      pdfDiagLog('dispose: no doc was loaded, skipping pdfrx cleanup');
    }
    await _stateController.close();
    await _locationController.close();
    await _selectionController.close();
    pdfDiagLog('dispose done');
    _pdfDiagFlush();
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
