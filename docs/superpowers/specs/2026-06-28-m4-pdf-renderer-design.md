# M4: PDF 渲染器设计文档

> **创建日期**：2026-06-28
> **关联里程碑**：M4（MVP 1.0 路线图最后一个未交付的大块）
> **依赖**：M3.5（设置/字体/i18n/多预设排版 + chapterSwitchSettled）已完成，tag `m3.5-complete`
> **协议**：AGPLv3

---

## 1. 目标与范围

### 1.1 一句话目标

把智阅从「仅 EPUB 阅读器」扩展为「EPUB + PDF 双格式阅读器」：用户能导入 PDF、按页浏览、跳目录、看进度；文本 PDF 支持选区高亮和笔记；扫描 PDF 渲染并提示功能受限。基于 pdfrx 现成能力做适配层，不自研底层渲染。

### 1.2 范围（in scope）

| 主线 | 内容 |
|---|---|
| **A. PDF 渲染引擎** | 基于 `pdfrx`（v2.3+，MIT，AGPLv3 兼容）实现 `PdfReaderEngine` + `PdfRenderer`，对接现有 `ReaderEngine` 接口 |
| **B. Page-as-Chapter 映射** | PDF 第 N 页（1-based 在 pdfrx 内部）映射到 Engine 的 chapterIndex = N-1（0-based）。复用 `currentChapterPlainText`、`currentChapterPageBreaks`（返回空，PDF 强制 scroll）、`chapterSwitchSettled`（已完成 Future） |
| **C. PdfRangeLocator** | 新增高亮定位类型（page + startOffset + endOffset + quote），与 `EpubRangeLocator` 对称。注册到 `Locator.fromJson` |
| **D. 文本 PDF 高亮** | 复用 pdfrx 内置文本选择 → bridge 到 `HighlightSelection` → 存 `PdfRangeLocator` |
| **E. 扫描 PDF 降级** | pdfrx 文本选择默认开启但扫描页无文本 → 用户尝试选择时无 emit；UI 上做 heuristic 检测（前 3 页文本长度阈值）+ banner「扫描件：高亮/笔记不可用」 |
| **F. 主题适配** | 复用 pdfrx 内置夜间模式（`PdfViewerParams`）；sepia 用 `ColorFiltered` 叠加层（pdfrx 没有 sepia） |
| **G. 大文件分块** | pdfrx 内置分页渲染 + LRU 缓存，无需额外工作。`PdfViewer` 自带 |
| **H. TOC（书签）** | pdfrx 内置 outline → bridge 到 `TocEntry` 树，叶子 locator = `PdfPageLocator(page, 0, 0)` |
| **I. ReaderEngine 路由** | `readerEngineForBookProvider` 在 `bookRef.format == pdf` 时返回 `PdfReaderEngine`（已预留 line 44 slot） |
| **J. 导入适配** | 新增 `book_format_detector.dart`：检测 `%PDF-` magic bytes → `BookFormat.pdf`；PK + mimetype → EPUB |
| **K. Library UI** | BookCell / BookListView 显示「PDF」chip 区分格式；BookDetailPage 显示「N 页」而非「N 章」 |
| **L. 数据层兼容** | Highlight / Note / ReadingProgress 表的 `locatorJson` 字段已支持任意 Locator 子类 JSON，自动兼容 |
| **M. NotesPage 适配** | PDF 书的 NotesPage 按「第 N 页」分组 |
| **N. Markdown 导出** | PDF 高亮/笔记导出时 frontmatter 含 `format: pdf` + `total_pages:` + `page:` 字段 |

### 1.3 非目标（out of scope）

- ❌ PDF 表单填写 / 注释 / 签名 / 编辑
- ❌ OCR（扫描 PDF 文字识别）
- ❌ PDF 内嵌图片提取 / 合并 / 拆分 / 打印
- ❌ Paged-mode 横向翻页（PDF 仅垂直 scroll 模式，pdfrx 默认行为）
- ❌ PDF 文字层 reflow（保留原始版式）
- ❌ iOS / Mac / Web 端适配（M7+）
- ❌ PDF 缩略图条（pdfrx 支持，但非 MVP 必需）
- ❌ 自定义文本选择 UI（用 pdfrx 默认选择 + context menu）

### 1.4 关键决策摘要

| # | 决策 | 选项 | 选择 | 理由 |
|---|---|---|---|---|
| 1 | PDF 渲染库 | pdfrx / pdfx / syncfusion | **pdfrx v2.3+** | MIT 协议 AGPLv3 兼容；活跃维护；自带文本选择 + TOC + 夜间模式 + 懒加载；几乎不需要自研 UI 组件 |
| 2 | 迭代范围 | 一次性 / M4.1+M4.2 / 最小验证 | **一次性** | 用户已确认；M4 是 MVP 1.0 最后大块，闭环交付降低集成返工 |
| 3 | ReaderEngine 融合 | Page-as-Chapter / 子接口 / 完全重构 | **Page-as-Chapter** | 用户已确认；改动最小；现有接口直接复用 |

---

## 2. 选型与约束

### 2.1 pdfrx API 关键面（v2.3.0）

| API | 用途 |
|---|---|
| `pdfrxFlutterInitialize()` | 应用启动时调用一次（main 函数）。访问 document API 前必须 |
| `PdfViewer.file(path, params: ...)` | 主阅读 widget；自带缩放、滚动、分页、懒加载 |
| `PdfViewer.asset(path)` / `.data(bytes)` / `.uri(url)` | 其他来源 |
| `PdfDocument.openFile(path)` | 直接拿 `PdfDocument`（用于读 pageCount / outlines，不渲染） |
| `doc.pages.length` | 总页数 |
| `PdfViewerParams` | 配置：scrollPhysics / textSelectionParams / buildContextMenu / pageOverlaysBuilder / ...
| `PdfTextSelectionParams(enabled: true)` | 文本选择总开关；默认开 |
| `PdfViewerParams.buildContextMenu` | 钩子：选区右键菜单（用于「高亮」按钮） |
| `PdfViewerParams.viewerOverlayBuilder` | 钩子：在 viewer 上叠加 widget（用于扫描 banner） |
| `PdfViewerParams.pageOverlaysBuilder` | 钩子：每页叠加 widget（用于页码 / 高亮 span） |
| pdfrx 内置 outline viewer | 不直接用，自己 bridge 到 TocEntry |
| pdfrx 内置夜间模式 | 不直接用，自己控制（保持与 EPUB 主题切换一致） |

**License**：MIT（pdfrx 本身）；transitive deps 也 MIT/Apache。AGPLv3 兼容。

**平台支持**：Android / iOS / Windows / macOS / Linux / Web。

### 2.2 Windows 平台特别要求

⚠️ **Windows 开发者模式必须开启**。pdfrx 在 Windows 构建时使用 symbolic links，未开启会构建失败。机器当前是 Windows 11，需要：

1. 设置 → 隐私和安全性 → 开发者选项 → 开启「开发人员模式」
2. 一次开启永久有效，不影响 release build

**Release 构建**：可执行 `dart run pdfrx:remove_wasm_modules` 移除 WASM 二进制减小 app 体积。

### 2.3 性能特性（pdfrx 自带）

- PDFium 渲染（Windows/Android/Linux Dart native assets；iOS/macOS XCFramework）
- 异步分页渲染，不阻塞 UI
- LRU 缓存（pdfrx 内部维护）
- 大文件流式打开（不全量载入内存）

---

## 3. 整体架构

```
┌─────────────────────────────────────────────────────────┐
│  app/lib/features/reader/pages/reader_page.dart         │  UI 层
│  （format-agnostic，靠 ReaderEngine 接口调度）          │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  reader_engine/lib/engine/reader_engine.dart            │  抽象接口
│  abstract interface class ReaderEngine                  │
└─────────────────────────────────────────────────────────┘
                          ↓
        ┌─────────────────┴─────────────────┐
        ↓                                   ↓
┌──────────────────────┐       ┌──────────────────────────┐
│ ConcreteEpubReader   │       │ PdfReaderEngine (NEW)    │
│ Engine               │       │ reader_engine_pdf_view/  │
│ reader_engine_epub_  │       │ lib/pdf_reader_engine.   │
│ view/lib/            │       │ dart                     │
└──────────────────────┘       └──────────────────────────┘
        ↓                                   ↓
┌──────────────────────┐       ┌──────────────────────────┐
│ EpubxRenderer        │       │ PdfRenderer (NEW)        │
│ (epubx + fwfh)       │       │ lib/pdf_renderer.dart    │
└──────────────────────┘       └──────────────────────────┘
                                         ↓
                                ┌─────────────────────┐
                                │ pdfrx (3rd party)   │
                                │ PdfViewer / PdfDoc  │
                                └─────────────────────┘
```

**新包**：`reader_engine_pdf_view/`，与 `reader_engine_epub_view/` 对称。

### 3.1 包结构

```
reader_engine_pdf_view/
├── pubspec.yaml             # 依赖 pdfrx + reader_engine
├── lib/
│   ├── pdf_renderer.dart       # 内部 PdfRenderer（包装 pdfrx PdfViewer）
│   ├── pdf_reader_engine.dart  # PdfReaderEngine implements ReaderEngine
│   ├── pdf_outline_bridge.dart # pdfrx PdfOutline → TocEntry 转换
│   ├── pdf_selection_bridge.dart # pdfrx 文本选择 → HighlightSelection
│   ├── pdf_theme.dart          # 主题适配（day/sepia/night）
│   └── pdf_scanned_detector.dart # 扫描页 heuristic 检测
└── test/
    ├── pdf_range_locator_test.dart        # (在 reader_engine 包内)
    ├── pdf_outline_bridge_test.dart
    ├── pdf_selection_bridge_test.dart
    ├── pdf_theme_test.dart
    ├── pdf_scanned_detector_test.dart
    ├── pdf_renderer_test.dart
    └── pdf_reader_engine_test.dart
```

---

## 4. PdfRenderer 实现

`reader_engine_pdf_view/lib/pdf_renderer.dart`：

```dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

import 'pdf_outline_bridge.dart';
import 'pdf_scanned_detector.dart';
import 'pdf_selection_bridge.dart';
import 'pdf_theme.dart';

class PdfRenderer {
  PdfRenderer();

  PdfDocument? _doc;
  int _currentPage = 0;  // 0-based internal index
  TypographySettings _typography = TypographySettings.defaults();
  final _stateController = StreamController<ReaderEngineState>.broadcast();
  final _locationController = StreamController<Locator>.broadcast();
  final _selectionController = StreamController<HighlightSelection>.broadcast();

  ReaderEngineState _state = const ReaderEngineUnloaded();

  ReaderEngineState get state => _state;
  Stream<ReaderEngineState> get state$ async* {
    yield _state;
    yield* _stateController.stream;
  }
  Stream<Locator> get currentLocation$ => _locationController.stream;
  Stream<HighlightSelection> get selection$ => _selectionController.stream;

  PdfDocument? get doc => _doc;
  int get currentPage => _currentPage;
  int get pageCount => _doc?.pages.length ?? 0;

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
    } catch (e, st) {
      debugPrint('PdfRenderer.openFile failed: $path\n$e\n$st');
      _setState(ReaderEngineError(message: '$e', cause: e));
    }
  }

  /// 切换到指定页（0-based 内部索引）。
  /// 通过 PdfViewer 的 scroll controller 跳转。
  void setPage(int page) {
    if (_doc == null) return;
    if (page < 0 || page >= _doc!.pages.length) return;
    _currentPage = page;
    _emitLocation();
    // 实际 scroll 由 PdfViewer 内部基于 _currentPage state 触发（详见 build）
  }

  void _emitLocation() {
    if (_doc == null) return;
    _locationController.add(PdfPageLocator(
      page: _currentPage + 1,  // pdfrx 1-based
      offsetX: 0,
      offsetY: 0,
    ));
  }

  Future<TableOfContents> get toc async {
    final doc = _doc;
    if (doc == null) return TableOfContents.empty();
    return PdfOutlineBridge.toTableOfContents(doc.outlines);
  }

  Future<void> gotoLocator(Locator locator) async {
    if (locator is! PdfPageLocator) return;
    setPage(locator.page - 1);  // 1-based → 0-based
  }

  void emitSelection(HighlightSelection selection) {
    _selectionController.add(selection);
  }

  /// build：核心是 PdfViewer，所有交互（缩放/选择/翻页）由 pdfrx 自管。
  /// 我们只在 PdfViewerParams 钩子里做 bridge：
  /// - onViewerReady: 拿到 ScrollController 用于 setPage
  /// - buildContextMenu: 选区右键菜单加「高亮」按钮 → emitSelection
  /// - pageOverlaysBuilder: 每页底部页码标签
  /// - viewerOverlayBuilder: 扫描 banner（顶部固定）
  Widget build(BuildContext context) {
    if (_doc == null) return const SizedBox.shrink();
    return PdfTheme.applyTheme(
      theme: _typography.theme,
      child: PdfViewer.file(
        _doc!.sourceName,  // 文件路径（pdfrx 内部 ref）
        params: PdfViewerParams(
          textSelectionParams: const PdfTextSelectionParams(enabled: true),
          buildContextMenu: (context, selectedText, selection) =>
              PdfSelectionBridge.buildContextMenu(
            context: context,
            selectedText: selectedText,
            onPage: _currentPage,
            onHighlight: emitSelection,
          ),
          pageOverlaysBuilder: (context, page, pageRect) =>
              PdfPageNumberOverlay(pageNumber: page.pageNumber),
          viewerOverlayBuilder: (context, viewer) =>
              PdfScannedBannerDetector.buildIfScanned(
            doc: _doc!,
            child: viewer,
          ),
        ),
      ),
    );
  }

  Future<void> setTypography(TypographySettings settings) async {
    _typography = settings;
  }

  Future<void> dispose() async {
    await _doc?.dispose();
    await _stateController.close();
    await _locationController.close();
    await _selectionController.close();
  }

  void _setState(ReaderEngineState next) {
    _state = next;
    _stateController.add(next);
  }
}
```

### 4.1 状态机

| 状态 | 触发 | ReaderEngineState |
|---|---|---|
| unloaded | 初始 | `ReaderEngineUnloaded()` |
| loading | openFile 调用 | `ReaderEngineLoading()` |
| ready | _doc 赋值完成 | `ReaderEngineReady()` |
| error | openFile 异常 / PDF 损坏 / 超时 | `ReaderEngineError(message, cause)` |

### 4.2 PageController 策略

- `ReaderEngine.pageController` 接口返回 `PageController?`
- PDF 不用 PageController（用 pdfrx 内部的 scroll）
- PdfReaderEngine 返回 `null`
- 现有 `reader_page` 已对 null 做了 null-check（paged-mode 流程跳过）

---

## 5. PdfReaderEngine 实现

`reader_engine_pdf_view/lib/pdf_reader_engine.dart`：

```dart
class PdfReaderEngine implements ReaderEngine {
  PdfReaderEngine({required PdfRenderer renderer}) : _renderer = renderer;
  final PdfRenderer _renderer;

  @override
  ReaderEngineState get state => _renderer.state;
  @override
  Stream<ReaderEngineState> get state$ => _renderer.state$;
  @override
  Stream<Locator> get currentLocation$ => _renderer.currentLocation$;
  @override
  Future<void> open(BookRef book) => _renderer.openFile(book.filePath);
  @override
  Future<void> gotoLocator(Locator locator) => _renderer.gotoLocator(locator);
  @override
  Future<void> gotoTocEntry(TocEntry entry) => _renderer.gotoLocator(entry.locator);
  @override
  Widget build(BuildContext context) => _renderer.build(context);

  /// 同 ConcreteEpubReaderEngine.openWithLastProgress 的模式：
  /// open 后尝试 gotoLocator，失败降级到第 1 页。
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

  // Page-as-Chapter: page index = chapter index
  @override
  Future<String> get currentChapterPlainText async {
    // PDF 不需要 plainText（pdfrx 自管选区）；返回空字符串占位
    return '';
  }

  @override
  List<PageBreak> get currentChapterPageBreaks => const [];

  @override
  PageController? get pageController => null;

  @override
  Future<void> get chapterSwitchSettled async {
    // PDF 翻页 pdfrx 自管，不需要等待 LayoutBuilder
    return;
  }

  @override
  TypographySettings get typography => _typography;
  TypographySettings _typography = TypographySettings.defaults();

  @override
  PaginationMode get paginationMode => PaginationMode.scroll;

  @override
  Future<void> setTypography(TypographySettings s) async {
    _typography = s;
    return _renderer.setTypography(s);
  }

  @override
  Future<void> setPaginationMode(PaginationMode m) async {
    // PDF 强制 scroll mode；noop
  }

  @override
  Stream<HighlightSelection> get selection$ => _renderer.selection$;

  /// 推送高亮列表（PDF 高亮渲染由 pdfrx 内部 pageOverlaysBuilder 处理）。
  Future<void> injectHighlights(List<HighlightRange> highlights) async {
    // TODO M4.1: 在 pageOverlaysBuilder 内根据 PdfRangeLocator 绘制黄色 span
    // MVP 先不渲染已有高亮（pdfrx 不原生支持），仅存储。读取时仍可跳转。
  }

  @override
  Future<void> close() => _renderer.dispose();
}
```

**关键设计**：
- `currentChapterPageBreaks` 返回 `const []`（PDF 不走 paged mode）
- `chapterSwitchSettled` 永远立即完成（pdfrx 翻页无 LayoutBuilder 重排）
- `currentChapterPlainText` 返回空字符串（pdfrx 自管选区，无需上层提供文本）
- `pageController` 返回 null（pdfrx 内部管理 scroll）
- `setTypography` 仅 `theme` 字段生效，其余 noop
- `injectHighlights` MVP 不渲染已有高亮（pdfrx 不原生支持），仅存储。这是已知降级，**M4.1 增强**

### 5.1 ReaderEngine 接口契约

`ReaderEngine` 抽象接口当前已声明全部上述成员，**无需修改接口**。

---

## 6. 定位系统扩展（PdfRangeLocator）

`reader_engine/lib/core/locator.dart` 新增（与 `EpubRangeLocator` 对称）：

```dart
/// M4: PDF 单页内字符 offset 区间定位，用于高亮范围。
///
/// 与 [EpubRangeLocator] 对称，差异仅在「page」（PDF 页码）取代
/// EpubRangeLocator 的 chapterIndex（章索引）。两者都用于高亮存储；
/// 导航用 [PdfPageLocator]。
class PdfRangeLocator extends Locator {
  final int page;
  final int startOffset;
  final int endOffset;
  final String quote;

  const PdfRangeLocator({
    required this.page,
    required this.startOffset,
    required this.endOffset,
    required this.quote,
  })  : assert(page >= 1),
        assert(startOffset >= 0),
        assert(endOffset > startOffset),
        assert(quote.length > 0);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'pdfRange',
    'page': page,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'quote': quote,
  };

  @override
  String toJsonString() => 'p$page:$startOffset-$endOffset';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfRangeLocator &&
          page == other.page &&
          startOffset == other.startOffset &&
          endOffset == other.endOffset &&
          quote == other.quote;

  @override
  int get hashCode => Object.hash(page, startOffset, endOffset, quote);
}
```

`Locator.fromJson` 在 `case 'pdfPage':` 后插入 `case 'pdfRange':`：

```dart
case 'pdfRange':
  return PdfRangeLocator(
    page: (json['page'] as num).toInt(),
    startOffset: (json['startOffset'] as num).toInt(),
    endOffset: (json['endOffset'] as num).toInt(),
    quote: json['quote'] as String,
  );
```

---

## 7. 文本 PDF 高亮机制（pdfrx bridge）

### 7.1 选区事件流

pdfrx 的 `PdfViewerParams.buildContextMenu` 在用户选中文本后右键时被调用，参数包含 `selectedText` 和 `selection`（含 page + offset 信息）。

`reader_engine_pdf_view/lib/pdf_selection_bridge.dart`：

```dart
class PdfSelectionBridge {
  /// 构建选区右键菜单：复制 + 高亮。
  static Widget buildContextMenu({
    required BuildContext context,
    required String? selectedText,
    required PdfSelection? selection,  // pdfrx 内部类型
    required int onPage,  // 当前页（fallback，pdfrx 的 selection 自带页码）
    required ValueChanged<HighlightSelection> onHighlight,
  }) {
    if (selectedText == null || selectedText.isEmpty) return const SizedBox.shrink();
    return Material(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).menuBackgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.format_color_fill, size: 18),
              label: const Text('高亮'),
              onPressed: () {
                final page = selection?.page?.pageNumber ?? onPage + 1;
                final startOffset = selection?.startTextIndex ?? 0;
                final endOffset = selection?.endTextIndex ?? selectedText.length;
                onHighlight(HighlightSelection(
                  locator: PdfRangeLocator(
                    page: page,
                    startOffset: startOffset,
                    endOffset: endOffset,
                    quote: selectedText,
                  ),
                  selectedText: selectedText,
                ));
                // 关闭菜单
                Navigator.of(context).pop();
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('复制'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: selectedText));
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

**注意**：`PdfSelection.startTextIndex` / `endTextIndex` / `page` 是 pdfrx 暴露的字段名（需在 T0 spike 验证；如有差异按实际 API 调整）。fallback 用 `onPage` + 全 quote 长度保证功能可用。

### 7.2 高亮存储

- Highlight 表 schema 不变（`locatorJson` 已是 TEXT 字段）
- `EpubRangeLocator` JSON → EPUB 高亮；`PdfRangeLocator` JSON → PDF 高亮
- 注释层（reader_page）按 Locator 类型分发：`EpubRangeLocator` 走 HtmlHighlightInjector；`PdfRangeLocator` 走 pdfrx 内部（MVP 不渲染已有，仅存储）

---

## 8. 扫描 PDF 降级处理

### 8.1 检测（heuristic）

pdfrx 不直接暴露「这页有/无文本」API，但可以通过尝试访问 page 文本（pdfrx_engine 低层 API）判断。MVP 用 heuristic：

`reader_engine_pdf_view/lib/pdf_scanned_detector.dart`：

```dart
class PdfScannedBannerDetector {
  /// 前 3 页文本总长度 < 100 字符 → 判定为扫描件。
  /// cached：同一 doc 只检测一次。
  static Future<bool> isLikelyScanned(PdfDocument doc) async {
    final checkPages = doc.pages.length < 3 ? doc.pages.length : 3;
    var totalChars = 0;
    for (var i = 0; i < checkPages; i++) {
      // pdfrx_engine 低层 API；如不可用，用 PdfTextExtractor（pdfrx 内部）
      final text = await _tryLoadText(doc.pages[i]);
      totalChars += text.length;
      if (totalChars >= 100) return false;  // 早退
    }
    return totalChars < 100;
  }

  /// build banner widget（条件渲染）。
  static Widget buildIfScanned({required PdfDocument doc, required Widget child}) {
    return FutureBuilder<bool>(
      future: isLikelyScanned(doc),
      builder: (context, snap) {
        if (snap.data != true) return child;
        return Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_outlined),
                    SizedBox(width: 8),
                    Expanded(child: Text('扫描件：高亮、笔记、搜索不可用')),
                  ],
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
```

### 8.2 降级 UX

- 整本扫描（前 3 页累计文本 < 100 字符）：顶部固定 banner
- 部分扫描：pdfrx 自身的 text selection 会在无文本的页上无效（用户尝试选无效果），无需特殊处理
- 仍可：翻页、缩放、跳目录、看进度
- 不可：选区、高亮、笔记（用户尝试选区无 emit）

---

## 9. 主题适配

### 9.1 适用与不适用

| TypographySettings 字段 | 对 PDF 适用 | 说明 |
|---|---|---|
| `theme` (day/night/sepia) | ✅ | 见 §9.2 |
| `fontFamily` | ❌ | PDF 是固定版式 |
| `fontSize` | ❌ | 同上 |
| `lineHeight` | ❌ | 同上 |
| `pageMargin` | ❌ | PDF 自带页边距 |
| `letterSpacing` | ❌ | 同上 |

### 9.2 主题实现

`reader_engine_pdf_view/lib/pdf_theme.dart`：

```dart
class PdfTheme {
  /// 把 PdfViewer 包装在主题适配层内。
  static Widget applyTheme({
    required ReadingTheme theme,
    required Widget child,
  }) {
    switch (theme) {
      case ReadingTheme.day:
        return child;
      case ReadingTheme.sepia:
        // pdfrx 没有 sepia 模式，用 ColorFiltered 叠加米黄半透明
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            const Color(0x40F5DEB3),  // 米黄半透明
            BlendMode.dstATop,
          ),
          child: child,
        );
      case ReadingTheme.night:
        // pdfrx 自带 invert（PdfViewerParams 选项），但为保持 EPUB 一致也用 ColorFiltered
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            -1, 0, 0, 0, 255,
            0, -1, 0, 0, 255,
            0, 0, -1, 0, 255,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
    }
  }
}
```

### 9.3 TypographyPanel 行为

PDF 书打开时，排版面板仍可打开。建议 UX：
- 仅主题切换器（day/night/sepia）可操作
- 字号/字体/行距 slider 显示但禁用（greyed out）
- 旁边小字提示「PDF 为固定版式，仅支持主题切换」

MVP 实现：所有控件照常显示，setTypography 调用时 PDF 静默忽略非主题字段。UI 上禁用非主题控件是 M4.1 增强。

---

## 10. 大文件分块加载

pdfrx 内置分页渲染 + LRU 缓存 + 异步加载。**无需额外工作**。

### 10.1 性能基准（验证用）

- 100 页 PDF（约 10MB）：正常浏览，翻页延迟 < 200ms
- 1000 页 PDF（约 100MB）：流式打开，浏览正常
- 滚动 60fps（pdfrx 原生 PDFium 渲染）

测试样本：见 §14.4。

---

## 11. UI 集成

### 11.1 ReaderEngine 路由

`app/lib/features/reader/providers/reader_engine_provider.dart` line 35-44 替换：

```dart
if (bookRef.format == re.BookFormat.epub) {
  final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
  final lastProgress = await progressRepo.get(bookId);
  await engine.openWithLastProgress(
    book: bookRef,
    lastLocator: lastProgress?.locator,
  );
  return engine;
}
// M4: PDF 路由
final engine = PdfReaderEngine(renderer: PdfRenderer());
final lastProgress = await progressRepo.get(bookId);
await engine.openWithLastProgress(
  book: bookRef,
  lastLocator: lastProgress?.locator,
);
return engine;
```

import 加：
```dart
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_renderer.dart';
```

### 11.2 ReaderPage 适配

现有 `reader_page.dart` 大部分代码 format-agnostic。需检查 / 改的点：

- ✅ `_maybeHandleInitialLocator`：通用 gotoLocator（PdfPageLocator 自带解码）
- ✅ `_onAnnotationTap`：通用 gotoLocator
- ⚠️ 章节标题显示：当前读 `engine.chapterTitleAt(idx)`（如有）；PDF 需 fallback 到「第 N 页」
- ⚠️ 进度条：EPUB 用 chapter index，PDF 用 page / totalPages。需检测 `bookRef.format` 分支或暴露统一 `progressRatio` getter
- ⚠️ Selection subscription：EPUB 用 EpubxRenderer 的 `selection$`；PDF 用 PdfReaderEngine 的 `selection$`（已转发）—— 接口一致 ✅

### 11.3 Library UI

- BookCell（grid）：右下角加 PDF chip（小标签，仅 PDF 显示）
- BookListView：title 行末尾加 PDF chip
- BookDetailPage：进度信息块显示「已读 N / 总 M 页」而非「已读 N / 总 M 章」

实现：在 BookCell / BookListView widget 内检查 `book.format == BookFormat.pdf`，条件渲染 `Chip(label: Text('PDF'))`。

### 11.4 Import 适配

新增 `app/lib/data/services/book_format_detector.dart`：

```dart
class BookFormatDetector {
  /// 检测文件 magic bytes 返回格式。
  /// - `%PDF-` (5 bytes) → pdf
  /// - PK + mimetype application/epub+zip → epub
  /// - 其他 → null（不支持）
  static BookFormat? detect(String path) {
    final bytes = File(path).readAsBytesSync();
    if (bytes.length < 5) return null;
    // PDF magic
    if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 &&
        bytes[3] == 0x46 && bytes[4] == 0x2D) {
      return BookFormat.pdf;
    }
    // EPUB: PK zip + mimetype 文件
    if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
      // 简化判断：ZIP 文件且扩展名是 .epub → EPUB
      // 严格判断需解压看 mimetype，留给后续
      final pathLower = path.toLowerCase();
      if (pathLower.endsWith('.epub')) return BookFormat.epub;
    }
    return null;
  }
}
```

现有 import flow（`local_book_repository.dart`）调用此 detector 决定 `BookFormat`。

### 11.5 main.dart 初始化

`app/lib/main.dart` 加 pdfrx 初始化：

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();  // M4: pdfrx 引擎初始化
  runApp(const ProviderScope(child: ZhiyueApp()));
}
```

---

## 12. 数据层适配

### 12.1 Highlight 表

Schema 不变。`locatorJson` 字段存储任意 Locator JSON。新增 `pdfRange` 类型自动支持。

### 12.2 Note 表

Schema 不变。

### 12.3 FTS5 索引

现有 `notes_fts` / `highlights_fts` 表。PDF 高亮/笔记的 `chapterTitle` 字段填「第 N 页」。FTS5 查询自动跨书搜索，无需改动。

### 12.4 ReadingProgress 表

`locatorJson` 字段存储 `PdfPageLocator` JSON，自动支持。

### 12.5 drift schema 版本

**不需要 bump**：无新表 / 无新列。仅是 Locator 子类多了一个变体。

---

## 13. 搜索与导出

### 13.1 全文搜索（FTS5）

跨书搜索结果点击 → gotoLocator（PdfPageLocator）。reader_page 已用通用 Locator 接口，无需改动。

### 13.2 Markdown 导出

PdfReaderEngine 的书导出 Markdown：
- frontmatter 含 `format: pdf`、`total_pages: N`
- 每个高亮 / 笔记含 `page: K` 字段（取代 EPUB 的 `chapter:` 字段）
- 章节分组改为「第 K 页」分组

实现：`MarkdownExporter` 内部按 `book.format` 分支。

---

## 14. 测试策略

### 14.1 单元测试

| 文件 | 内容 |
|---|---|
| `reader_engine/test/core/pdf_range_locator_test.dart` | toJson / fromJson / equality / assertion errors |
| `app/test/data/services/book_format_detector_test.dart` | magic bytes 检测准确（含损坏文件、.epub 扩展名 fallback） |
| `pdf_outline_bridge_test.dart` | pdfrx PdfOutline → TocEntry 转换（含嵌套） |
| `pdf_theme_test.dart` | 三种 theme 的 widget 树正确 |
| `pdf_scanned_detector_test.dart` | heuristic 阈值（< 100 字符判定） |

### 14.2 组件测试

| 文件 | 内容 |
|---|---|
| `pdf_renderer_test.dart` | openFile 状态机（loading → ready / error）；pageCount 正确 |
| `pdf_reader_engine_test.dart` | Page-as-Chapter 映射；gotoLocator；setTypography noop |
| `reader_engine_provider_pdf_test.dart` | provider 在 format=pdf 时返回 PdfReaderEngine |

### 14.3 集成测试

| 文件 | 内容 |
|---|---|
| `reader_page_pdf_test.dart` | 打开 PDF → 翻页 → 进度更新 → 跳 TOC → 选区高亮 → 笔记 |

### 14.4 测试 PDF 样本

放 `app/test/fixtures/pdfs/`：
- `sample-text.pdf`（5 页，含文本层）—— 用 reportlab 生成，commit 进 git（小文件 ~10KB）
- `sample-scanned.pdf`（3 页，无文本层）—— 用 PIL 渲染图片转 PDF
- `sample-mixed.pdf`（5 页，部分扫描）—— 文本+扫描混合
- `sample-corrupted.pdf`（损坏，状态机测试）—— 截断的字节流

样本生成脚本：`tools/gen_test_pdfs.dart`（dart 脚本，运行后产物 commit）。

### 14.5 Golden 测试

- `library_cell_pdf_chip_golden_test.dart`（PDF chip 渲染）

---

## 15. 任务拆分概览（plan 阶段细化）

| # | 任务 | 工期估 |
|---|---|---|
| T0 | pdfrx 依赖接入 + reader_engine_pdf_view 包脚手架 + pdfrxFlutterInitialize + smoke test（打开样本 PDF 看页数） | 0.5 天 |
| T1 | PdfRangeLocator + JSON 注册 + 单测 | 0.5 天 |
| T2 | PdfRenderer 基础（openFile + state + pageCount + setPage + emitLocation） | 0.5 天 |
| T3 | PdfRenderer.build：PdfViewer.file + 基础 params（无选区钩子，无主题） | 0.5 天 |
| T4 | PdfReaderEngine implements ReaderEngine（Page-as-Chapter + openWithLastProgress） | 0.5 天 |
| T5 | ReaderEngine 路由：provider 分发 format=pdf + main.dart 初始化 | 0.5 天 |
| T6 | TOC bridge：pdfrx PdfOutline → TocEntry + 单测 | 0.5 天 |
| T7 | 主题适配：day/sepia/night via ColorFiltered + 单测 | 0.5 天 |
| T8 | 选区 bridge：pdfrx PdfSelection → HighlightSelection + PdfRangeLocator | 1 天 |
| T9 | 扫描 PDF heuristic 检测 + banner | 0.5 天 |
| T10 | book_format_detector + Import 适配 | 0.5 天 |
| T11 | Library UI：BookCell + BookListView PDF chip + BookDetailPage 页数显示 | 0.5 天 |
| T12 | ReaderPage 适配：章节标题 fallback「第 N 页」+ 进度比 page/total | 0.5 天 |
| T13 | NotesPage PDF 分组 + Markdown 导出 frontmatter | 0.5 天 |
| T14 | 测试 PDF 样本生成脚本 + 集成测试 reader_page_pdf_test | 1 天 |
| T15 | Golden 测试（PDF chip）+ dart analyze 全绿 + tag m4-complete | 0.5 天 |

**合计**：~8.5 天（含调试 buffer，实际可能 7-10 天）。

---

## 16. 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| Windows 开发者模式未开启 → build 失败 | 中 | 高 | T0 spike 立即验证；开启方法写入 README 和 dev_env_quirks memory |
| pdfrx 在中文路径下崩溃 | 低 | 高 | 测试 `H:\projiect\电子书阅读平台\test\fixtures\` 下文件；如有问题先复制到 temp 目录 |
| pdfrx `PdfSelection` 字段名与 spec 假设不符 | 中 | 中 | T0 spike 用 print 验证字段；spec 内已有 fallback |
| pdfrx `page.loadText()` 不可用 → 扫描检测失败 | 中 | 中 | 改用 UI heuristic（用户尝试选区无 emit → 提示）；或回退到「永远不显示 banner」 |
| pdfrx v2.3 vs v1.x API 差异 | 低 | 低 | spec pin `pdfrx: ^2.3.0`；如有更稳定版本，pin 具体 minor |
| ColorFiltered 性能（1000 页 PDF） | 低 | 低 | PDFium 渲染快，ColorFiltered 在 Flutter 合成层；profile 100 页样本 |
| 测试 PDF 样本无法 commit（太大） | 低 | 低 | 用 reportlab 生成最小样本（< 50KB）；CI 不依赖大文件 |

---

## 17. 后续阶段（M4 完成后）

M4 完成后，MVP 1.0 仅剩：
- **M7**：Windows/Android 平台适配（build 配置 + 应用图标 + 权限申请）
- **M8**：Release 1.0（测试补全 + 性能 + 发布）

然后进入 MVP 1.5（AI 陪伴）/ 2.0（同步）。

### 17.1 M4.1 增强（M4 完成后可选）

- 已有 PDF 高亮渲染（pdfrx `pageOverlaysBuilder` 内根据 PdfRangeLocator 绘制黄色 span）
- TypographyPanel 控件禁用（非主题控件 greyed out）
- PDF 缩略图条（pdfrx 支持，非 MVP）
- PDF 文本搜索（pdfrx 内置，但 UI 入口需要集成到 search page）

---

## 附录 A：与现有代码的精确对接点

| 文件 | 行 | 改动 |
|---|---|---|
| `reader_engine/lib/core/locator.dart` | line 24-29 后 | 插入 `case 'pdfRange':` 分支 |
| `reader_engine/lib/core/locator.dart` | 文件末 | 加 `class PdfRangeLocator extends Locator` |
| `app/lib/features/reader/providers/reader_engine_provider.dart` | line 44 | 替换 `throw UnimplementedError` 为 PdfReaderEngine 实例化 |
| `app/lib/main.dart` | main() | 加 `pdfrxFlutterInitialize()` |
| `app/pubspec.yaml` | dependencies | 加 `reader_engine_pdf_view: path: ../reader_engine_pdf_view` |
| `reader_engine_pdf_view/pubspec.yaml` | 新文件 | 依赖 `pdfrx: ^2.3.0` + `reader_engine: path: ../reader_engine` |
| `app/lib/data/services/book_format_detector.dart` | 新文件 | magic bytes 检测 |
| `app/lib/data/repositories/local_book_repository.dart` | import flow | 调用 detector |
| `app/lib/features/library/widgets/book_cell.dart` | 末尾 | 条件渲染 PDF chip |
| `app/lib/features/library/widgets/book_list_view.dart` | title 行末尾 | 条件渲染 PDF chip |
| `app/lib/features/library/pages/book_detail_page.dart` | 进度信息块 | PDF 显示页数 |
| `app/lib/features/reader/pages/reader_page.dart` | 章节标题 / 进度比 | format-aware fallback |
| `app/lib/features/notes/pages/notes_page.dart` | section header | PDF 用「第 N 页」 |
| `app/lib/data/services/markdown_exporter.dart` | frontmatter | PDF 用 `format: pdf` + `page:` |

---

## 附录 B：参考链接

- [pdfrx on pub.dev](https://pub.dev/packages/pdfrx)
- [pdfrx GitHub](https://github.com/espresso3389/pdfrx)
- [pdfrx API docs](https://espresso3389.github.io/pdfrx/)
- [pdfrx example viewer](https://github.com/espresso3389/pdfrx/blob/master/packages/pdfrx/example/viewer/lib/main.dart)
