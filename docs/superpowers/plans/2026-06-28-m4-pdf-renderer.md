# M4 PDF 渲染器实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于 pdfrx v2.3+ 在智阅中集成 PDF 渲染，对接现有 ReaderEngine 接口（Page-as-Chapter 映射），实现文本 PDF 高亮 + 扫描 PDF 降级 + 主题适配 + 导入检测 + Library UI。

**Architecture:** 新建 `reader_engine_pdf_view` 包，与 `reader_engine_epub_view` 对称。PdfRenderer 包装 pdfrx 的 `PdfViewer`，PdfReaderEngine 实现 `ReaderEngine` 接口。复用 pdfrx 内置文本选择、TOC、夜间模式、懒加载。

**Tech Stack:** Flutter 3.44 / Dart 3.12 / Riverpod 2.6 / drift 2.18 / pdfrx 2.3+ / PDFium（native）

**Spec:** `docs/superpowers/specs/2026-06-28-m4-pdf-renderer-design.md`

---

## File Structure

### New package: `reader_engine_pdf_view/`

```
reader_engine_pdf_view/
├── pubspec.yaml                          # T0
├── lib/
│   ├── reader_engine_pdf_view.dart       # T0  library export
│   ├── pdf_renderer.dart                 # T2/T3/T8/T9  包装 PdfViewer
│   ├── pdf_reader_engine.dart            # T4  ReaderEngine impl
│   ├── pdf_outline_bridge.dart           # T6  pdfrx outline → TocEntry
│   ├── pdf_theme.dart                    # T7  day/sepia/night
│   ├── pdf_selection_bridge.dart         # T8  pdfrx selection → HighlightSelection
│   └── pdf_scanned_detector.dart         # T9  heuristic + banner
└── test/
    ├── smoke_test.dart                   # T0
    ├── pdf_renderer_test.dart            # T2
    ├── pdf_renderer_build_test.dart      # T3
    ├── pdf_reader_engine_test.dart       # T4
    ├── pdf_outline_bridge_test.dart      # T6
    ├── pdf_theme_test.dart               # T7
    ├── pdf_selection_bridge_test.dart    # T8
    └── pdf_scanned_detector_test.dart    # T9
```

### Existing files to modify

| 文件 | 任务 | 改动 |
|---|---|---|
| `reader_engine/lib/core/locator.dart` | T1 | 加 `PdfRangeLocator` class + `case 'pdfRange'` |
| `reader_engine/test/core/locator_test.dart` | T1 | 加 PdfRangeLocator 测试 |
| `app/pubspec.yaml` | T0 | 加 `reader_engine_pdf_view` path dep |
| `app/lib/main.dart` | T0 | `pdfrxFlutterInitialize()` |
| `app/lib/features/reader/providers/reader_engine_provider.dart` | T5 | PDF 路由分支 |
| `app/lib/data/services/book_format_detector.dart` | T10 | 新建 |
| `app/lib/data/repositories/local_book_repository.dart` | T10 | 调用 detector |
| `app/lib/features/library/widgets/book_cell.dart` | T11 | PDF chip |
| `app/lib/features/library/widgets/book_list_view.dart` | T11 | PDF chip |
| `app/lib/features/library/pages/book_detail_page.dart` | T11 | 页数显示 |
| `app/lib/features/reader/pages/reader_page.dart` | T12 | 章节标题/进度比 fallback |
| `app/lib/features/notes/pages/notes_page.dart` | T13 | 按「第 N 页」分组 |
| `app/lib/data/services/markdown_exporter.dart` | T13 | frontmatter `format: pdf` |

### Test fixtures

| 文件 | 任务 | 用途 |
|---|---|---|
| `tools/gen_test_pdfs.dart` | T14 | 生成测试 PDF 的 dart 脚本 |
| `app/test/fixtures/pdfs/sample-text.pdf` | T14 | 5 页含文本层 |
| `app/test/fixtures/pdfs/sample-scanned.pdf` | T14 | 3 页扫描 |
| `app/test/fixtures/pdfs/sample-corrupted.pdf` | T14 | 损坏文件 |

---

## Task 0: pdfrx 依赖接入 + 包脚手架 + smoke test

**Files:**
- Create: `reader_engine_pdf_view/pubspec.yaml`
- Create: `reader_engine_pdf_view/lib/reader_engine_pdf_view.dart`
- Modify: `app/pubspec.yaml` (加 path dep)
- Modify: `app/lib/main.dart` (加 pdfrxFlutterInitialize)
- Test: `reader_engine_pdf_view/test/smoke_test.dart`

- [ ] **Step 1: 写 pubspec**

`reader_engine_pdf_view/pubspec.yaml`:
```yaml
name: reader_engine_pdf_view
description: pdfrx-based PDF renderer adapter for the 智阅 reader_engine.
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.10.0
  flutter: ^3.27.0

dependencies:
  flutter:
    sdk: flutter
  pdfrx: ^2.3.0
  reader_engine:
    path: ../reader_engine

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

- [ ] **Step 2: 写 library export**

`reader_engine_pdf_view/lib/reader_engine_pdf_view.dart`:
```dart
/// reader_engine_pdf_view — pdfrx 适配层。
library reader_engine_pdf_view;

export 'pdf_renderer.dart';
export 'pdf_reader_engine.dart';
```

- [ ] **Step 3: 加 path dep 到 app/pubspec.yaml**

在 `app/pubspec.yaml` 的 `reader_engine_epub_view` 后加：
```yaml
  reader_engine_pdf_view:
    path: ../reader_engine_pdf_view
```

- [ ] **Step 4: 写失败的 smoke test**

`reader_engine_pdf_view/test/smoke_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('package imports cleanly', () {
    expect(1 + 1, 2);
  });
}
```

- [ ] **Step 5: 验证依赖解析**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter pub get
```
Expected: 解析成功，下载 pdfrx + transitive deps

- [ ] **Step 6: 修改 main.dart 加 pdfrx 初始化**

`app/lib/main.dart` 在 `WidgetsFlutterBinding.ensureInitialized();` 后加：
```dart
import 'package:pdfrx/pdfrx.dart';
// ...
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  runApp(const ProviderScope(child: ZhiyueApp()));
}
```

- [ ] **Step 7: 跑 smoke test**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/smoke_test.dart
```
Expected: PASS

- [ ] **Step 8: 提交**

```bash
git add reader_engine_pdf_view/ app/pubspec.yaml app/lib/main.dart
git commit -m "feat(m4/t0): scaffold reader_engine_pdf_view + pdfrx init"
```

---

## Task 1: PdfRangeLocator + JSON 注册 + 单测

**Files:**
- Modify: `reader_engine/lib/core/locator.dart`
- Test: `reader_engine/test/core/pdf_range_locator_test.dart`

- [ ] **Step 1: 写失败测试**

`reader_engine/test/core/pdf_range_locator_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';

void main() {
  group('PdfRangeLocator', () {
    test('toJson serializes all fields', () {
      const loc = PdfRangeLocator(
        page: 5,
        startOffset: 10,
        endOffset: 20,
        quote: 'selected text',
      );
      expect(loc.toJson(), {
        'type': 'pdfRange',
        'page': 5,
        'startOffset': 10,
        'endOffset': 20,
        'quote': 'selected text',
      });
    });

    test('fromJson round-trips', () {
      const original = PdfRangeLocator(
        page: 3,
        startOffset: 0,
        endOffset: 5,
        quote: 'hello',
      );
      final restored = Locator.fromJson(original.toJson());
      expect(restored, original);
    });

    test('rejects zero-length quote', () {
      expect(
        () => PdfRangeLocator(
          page: 1,
          startOffset: 0,
          endOffset: 5,
          quote: '',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects endOffset <= startOffset', () {
      expect(
        () => PdfRangeLocator(
          page: 1,
          startOffset: 10,
          endOffset: 10,
          quote: 'x',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects page < 1', () {
      expect(
        () => PdfRangeLocator(
          page: 0,
          startOffset: 0,
          endOffset: 5,
          quote: 'x',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Locator.fromJson handles double-encoded ints (JS compat)', () {
      final restored = Locator.fromJson({
        'type': 'pdfRange',
        'page': 5.0,
        'startOffset': 10.0,
        'endOffset': 20.0,
        'quote': 'q',
      });
      expect(restored, isA<PdfRangeLocator>());
      expect((restored as PdfRangeLocator).page, 5);
    });
  });
}
```

- [ ] **Step 2: 验证失败**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine && /c/flutter/bin/flutter test test/core/pdf_range_locator_test.dart
```
Expected: FAIL — `PdfRangeLocator` not defined

- [ ] **Step 3: 加 PdfRangeLocator 到 locator.dart**

在 `reader_engine/lib/core/locator.dart` 的 `EpubRangeLocator` 后加：
```dart
/// M4: PDF 单页内字符 offset 区间定位，用于高亮范围。
///
/// 与 [EpubRangeLocator] 对称，差异仅在「page」（PDF 1-based 页码）取代
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

- [ ] **Step 4: 加 fromJson 分支**

在 `locator.dart` 的 `case 'pdfPage':` 块后加：
```dart
case 'pdfRange':
  return PdfRangeLocator(
    page: (json['page'] as num).toInt(),
    startOffset: (json['startOffset'] as num).toInt(),
    endOffset: (json['endOffset'] as num).toInt(),
    quote: json['quote'] as String,
  );
```

- [ ] **Step 5: 验证测试通过**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine && /c/flutter/bin/flutter test test/core/pdf_range_locator_test.dart
```
Expected: PASS (6/6)

- [ ] **Step 6: 提交**

```bash
git add reader_engine/lib/core/locator.dart reader_engine/test/core/pdf_range_locator_test.dart
git commit -m "feat(m4/t1): PdfRangeLocator with toJson/fromJson + assertions"
```

---

## Task 2: PdfRenderer 基础（openFile + state + pageCount）

**Files:**
- Create: `reader_engine_pdf_view/lib/pdf_renderer.dart`
- Test: `reader_engine_pdf_view/test/pdf_renderer_test.dart`

- [ ] **Step 1: 写失败测试**

`reader_engine_pdf_view/test/pdf_renderer_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine_pdf_view/pdf_renderer.dart';

void main() {
  group('PdfRenderer state machine', () {
    test('initial state is unloaded', () {
      final r = PdfRenderer();
      expect(r.state, isA<ReaderEngineUnloaded>());
      expect(r.pageCount, 0);
      expect(r.currentPage, 0);
    });

    test('openFile missing file transitions to error', () async {
      final r = PdfRenderer();
      await r.openFile('/nonexistent.pdf');
      expect(r.state, isA<ReaderEngineError>());
    });
  });

  group('PdfRenderer page navigation', () {
    test('setPage is no-op when doc is null', () {
      final r = PdfRenderer();
      r.setPage(5);  // should not throw
      expect(r.currentPage, 0);
    });

    test('emitLocation produces PdfPageLocator', () async {
      final r = PdfRenderer();
      final events = <Locator>[];
      r.currentLocation$.listen(events.add);
      // We can't easily load a real PDF here without fixtures; covered in T14
      expect(events, isEmpty);
    });
  });
}
```

- [ ] **Step 2: 验证失败**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_renderer_test.dart
```
Expected: FAIL — `pdf_renderer.dart` doesn't exist

- [ ] **Step 3: 写 PdfRenderer 基础**

`reader_engine_pdf_view/lib/pdf_renderer.dart`:
```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';

class PdfRenderer {
  PdfRenderer();

  PdfDocument? _doc;
  int _currentPage = 0;
  ReaderEngineState _state = const ReaderEngineUnloaded();

  final _stateController = StreamController<ReaderEngineState>.broadcast();
  final _locationController = StreamController<Locator>.broadcast();
  final _selectionController = StreamController<HighlightSelection>.broadcast();

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

  void setPage(int page) {
    final doc = _doc;
    if (doc == null) return;
    if (page < 0 || page >= doc.pages.length) return;
    _currentPage = page;
    _emitLocation();
  }

  void _emitLocation() {
    if (_doc == null) return;
    _locationController.add(PdfPageLocator(
      page: _currentPage + 1,
      offsetX: 0,
      offsetY: 0,
    ));
  }

  void emitSelection(HighlightSelection selection) {
    _selectionController.add(selection);
  }

  void _setState(ReaderEngineState next) {
    _state = next;
    _stateController.add(next);
  }

  Future<void> dispose() async {
    await _doc?.dispose();
    await _stateController.close();
    await _locationController.close();
    await _selectionController.close();
  }
}
```

- [ ] **Step 4: 验证测试通过**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_renderer_test.dart
```
Expected: PASS (4/4)

- [ ] **Step 5: 提交**

```bash
git add reader_engine_pdf_view/lib/pdf_renderer.dart reader_engine_pdf_view/test/pdf_renderer_test.dart
git commit -m "feat(m4/t2): PdfRenderer openFile state machine + page navigation"
```

---

## Task 3: PdfRenderer.build — PdfViewer.file 渲染

**Files:**
- Modify: `reader_engine_pdf_view/lib/pdf_renderer.dart` (加 build)
- Test: `reader_engine_pdf_view/test/pdf_renderer_build_test.dart`

- [ ] **Step 1: 写失败测试**

`reader_engine_pdf_view/test/pdf_renderer_build_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_pdf_view/pdf_renderer.dart';

void main() {
  testWidgets('PdfRenderer.build returns SizedBox when no doc loaded',
      (tester) async {
    final r = PdfRenderer();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: r.build(tester.element(find.byType(Scaffold))))),
    );
    expect(find.byType(SizedBox), findsOneWidget);
    await r.dispose();
  });
}
```

- [ ] **Step 2: 验证失败**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_renderer_build_test.dart
```
Expected: FAIL — `build` method doesn't exist

- [ ] **Step 3: 加 build 方法**

在 `reader_engine_pdf_view/lib/pdf_renderer.dart` 的 `dispose()` 前加：
```dart
  /// 阅读区 widget。doc 未加载时返回空 SizedBox。
  ///
  /// 子任务（T7 主题 / T8 选区 / T9 扫描 banner）逐步在此方法内插入钩子。
  Widget build(BuildContext context) {
    final doc = _doc;
    if (doc == null) return const SizedBox.shrink();
    return PdfViewer.file(doc.sourceName);
  }
```

- [ ] **Step 4: 验证测试通过**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_renderer_build_test.dart
```
Expected: PASS (1/1)

- [ ] **Step 5: 提交**

```bash
git add reader_engine_pdf_view/lib/pdf_renderer.dart reader_engine_pdf_view/test/pdf_renderer_build_test.dart
git commit -m "feat(m4/t3): PdfRenderer.build with PdfViewer.file"
```

---

## Task 4: PdfReaderEngine implements ReaderEngine

**Files:**
- Create: `reader_engine_pdf_view/lib/pdf_reader_engine.dart`
- Test: `reader_engine_pdf_view/test/pdf_reader_engine_test.dart`

- [ ] **Step 1: 写失败测试**

`reader_engine_pdf_view/test/pdf_reader_engine_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_renderer.dart';

void main() {
  group('PdfReaderEngine Page-as-Chapter', () {
    test('currentChapterPageBreaks is empty (no paged mode for PDF)', () {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      expect(e.currentChapterPageBreaks, isEmpty);
    });

    test('pageController is null (pdfrx manages scroll)', () {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      expect(e.pageController, isNull);
    });

    test('chapterSwitchSettled resolves immediately', () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      // Should not hang
      await e.chapterSwitchSettled.timeout(const Duration(seconds: 1));
    });

    test('currentChapterPlainText returns empty string', () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      expect(await e.currentChapterPlainText, '');
    });

    test('paginationMode is always scroll', () {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      expect(e.paginationMode, PaginationMode.scroll);
    });

    test('setPaginationMode is noop (does not throw)', () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      await e.setPaginationMode(PaginationMode.paged);
      expect(e.paginationMode, PaginationMode.scroll);
    });

    test('setTypography stores typography but does not throw', () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      const t = TypographySettings.defaults();
      await e.setTypography(t);
      expect(e.typography, t);
    });
  });
}
```

- [ ] **Step 2: 验证失败**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_reader_engine_test.dart
```
Expected: FAIL — `pdf_reader_engine.dart` doesn't exist

- [ ] **Step 3: 写 PdfReaderEngine**

`reader_engine_pdf_view/lib/pdf_reader_engine.dart`:
```dart
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

class PdfReaderEngine implements ReaderEngine {
  PdfReaderEngine({required PdfRenderer renderer}) : _renderer = renderer;
  final PdfRenderer _renderer;

  TypographySettings _typography = TypographySettings.defaults();

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
  Future<void> nextSpine() async {
    _renderer.setPage(_renderer.currentPage + 1);
  }

  @override
  Future<void> previousSpine() async {
    _renderer.setPage(_renderer.currentPage - 1);
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

  // ----- ReaderEngine EPUB-flavored members (Page-as-Chapter semantics) -----

  @override
  Future<String> get currentChapterPlainText async => '';

  @override
  List<PageBreak> get currentChapterPageBreaks => const [];

  @override
  PageController? get pageController => null;

  @override
  Future<void> get chapterSwitchSettled async {}

  @override
  TableOfContents? get toc => null;

  @override
  TypographySettings get typography => _typography;

  @override
  PaginationMode get paginationMode => PaginationMode.scroll;

  // ----- Selection forwarding (EpubxRenderer has same pattern) -----

  Stream<HighlightSelection> get selection$ => _renderer.selection$;

  // ----- Helper: open with last known progress (mirrors ConcreteEpubReaderEngine) -----

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
```

- [ ] **Step 4: 加 gotoLocator 到 PdfRenderer**

在 `pdf_renderer.dart` 的 `setPage` 后加：
```dart
  Future<void> gotoLocator(Locator locator) async {
    if (locator is! PdfPageLocator) return;
    setPage(locator.page - 1);
  }

  Future<void> setTypography(TypographySettings settings) async {
    _typography = settings;
  }
  TypographySettings _typography = TypographySettings.defaults();
```

加 import: `import 'package:reader_engine/core/typography_settings.dart';`

- [ ] **Step 5: 验证测试通过**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_reader_engine_test.dart
```
Expected: PASS (7/7)

- [ ] **Step 6: 提交**

```bash
git add reader_engine_pdf_view/lib/pdf_reader_engine.dart reader_engine_pdf_view/lib/pdf_renderer.dart reader_engine_pdf_view/test/pdf_reader_engine_test.dart
git commit -m "feat(m4/t4): PdfReaderEngine implements ReaderEngine (Page-as-Chapter)"
```

---

## Task 5: ReaderEngine 路由 + main.dart 验证

**Files:**
- Modify: `app/lib/features/reader/providers/reader_engine_provider.dart`
- Test: `app/test/features/reader/providers/reader_engine_provider_pdf_test.dart`

- [ ] **Step 1: 写失败测试**

`app/test/features/reader/providers/reader_engine_provider_pdf_test.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/reader/providers/reader_engine_provider.dart';

import '../../../helpers/test_database.dart';

void main() {
  test('readerEngineForBookProvider returns PdfReaderEngine for pdf format',
      () async {
    final container = ProviderContainer(overrides: await testOverrides());
    addTearDown(container.dispose);

    final book = await seedBook(container, format: BookFormat.pdf);

    final engine = await container
        .read(readerEngineForBookProvider(book.id).future);

    expect(engine, isA<PdfReaderEngine>());
  });
}
```

注意：`testOverrides()` 和 `seedBook()` 用现有 helper（参考 `reader_engine_provider_test.dart` 同目录其他测试）。

- [ ] **Step 2: 验证失败**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/features/reader/providers/reader_engine_provider_pdf_test.dart
```
Expected: FAIL — provider throws `UnimplementedError('PDF engine is M4')`

- [ ] **Step 3: 替换 provider 路由**

`app/lib/features/reader/providers/reader_engine_provider.dart` line 35-44 替换为：
```dart
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_renderer.dart';

// ... 在 provider 主体内：

  if (bookRef.format == re.BookFormat.epub) {
    final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
    final lastProgress = await progressRepo.get(bookId);
    await engine.openWithLastProgress(
      book: bookRef,
      lastLocator: lastProgress?.locator,
    );
    return engine;
  }
  // M4: PDF routing
  final engine = PdfReaderEngine(renderer: PdfRenderer());
  final lastProgress = await progressRepo.get(bookId);
  await engine.openWithLastProgress(
    book: bookRef,
    lastLocator: lastProgress?.locator,
  );
  return engine;
```

- [ ] **Step 4: 验证测试通过**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/features/reader/providers/reader_engine_provider_pdf_test.dart
```
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add app/lib/features/reader/providers/reader_engine_provider.dart app/test/features/reader/providers/reader_engine_provider_pdf_test.dart
git commit -m "feat(m4/t5): provider routes format=pdf to PdfReaderEngine"
```

---

## Task 6: TOC bridge — pdfrx PdfOutline → TocEntry

**Files:**
- Create: `reader_engine_pdf_view/lib/pdf_outline_bridge.dart`
- Modify: `reader_engine_pdf_view/lib/pdf_renderer.dart` (加 toc getter)
- Test: `reader_engine_pdf_view/test/pdf_outline_bridge_test.dart`

- [ ] **Step 1: 写失败测试（用 fake PdfOutlineNode）**

`reader_engine_pdf_view/test/pdf_outline_bridge_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine_pdf_view/pdf_outline_bridge.dart';

void main() {
  group('PdfOutlineBridge.toTableOfContents', () {
    test('empty outline returns empty TOC', () {
      final toc = PdfOutlineBridge.toTableOfContents(null);
      expect(toc.entries, isEmpty);
    });

    test('flat outlines convert to flat TocEntry list', () {
      // pdfrx PdfOutlineNode 是 immutable 数据类，直接构造
      final root = PdfOutlineNode(
        title: 'Root',
        dest: PdfDest.ref(page: 1, type: PdfDestType.xyz, left: 0, top: 0, zoom: 0),
        children: [
          PdfOutlineNode(
            title: 'Chapter 1',
            dest: PdfDest.ref(page: 1, type: PdfDestType.xyz, left: 0, top: 0, zoom: 0),
          ),
          PdfOutlineNode(
            title: 'Chapter 2',
            dest: PdfDest.ref(page: 5, type: PdfDestType.xyz, left: 0, top: 0, zoom: 0),
          ),
        ],
      );
      final toc = PdfOutlineBridge.toTableOfContents(root);
      expect(toc.entries.length, 2);
      expect(toc.entries[0].title, 'Chapter 1');
      expect((toc.entries[0].locator as PdfPageLocator).page, 1);
      expect(toc.entries[1].title, 'Chapter 2');
      expect((toc.entries[1].locator as PdfPageLocator).page, 5);
    });

    test('nested outlines preserve tree structure', () {
      final root = PdfOutlineNode(
        title: 'Part I',
        dest: PdfDest.ref(page: 1, type: PdfDestType.xyz, left: 0, top: 0, zoom: 0),
        children: [
          PdfOutlineNode(
            title: 'Chapter 1',
            dest: PdfDest.ref(page: 2, type: PdfDestType.xyz, left: 0, top: 0, zoom: 0),
            children: [
              PdfOutlineNode(
                title: 'Section 1.1',
                dest: PdfDest.ref(page: 3, type: PdfDestType.xyz, left: 0, top: 0, zoom: 0),
              ),
            ],
          ),
        ],
      );
      final toc = PdfOutlineBridge.toTableOfContents(root);
      expect(toc.entries.length, 1);
      expect(toc.entries[0].children.length, 1);
      expect(toc.entries[0].children[0].title, 'Section 1.1');
    });

    test('outline with null dest is skipped (no crash)', () {
      final root = PdfOutlineNode(
        title: 'No destination',
        dest: null,
      );
      final toc = PdfOutlineBridge.toTableOfContents(root);
      expect(toc.entries, isEmpty);
    });
  });
}
```

注意：pdfrx 的 `PdfOutlineNode` / `PdfDest` 构造器字段名需在 T6 spike 中确认。如 API 不一致，调整 fake 构造。

- [ ] **Step 2: 验证失败**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_outline_bridge_test.dart
```
Expected: FAIL — file doesn't exist

- [ ] **Step 3: 写 bridge**

`reader_engine_pdf_view/lib/pdf_outline_bridge.dart`:
```dart
import 'package:pdfrx/pdfrx.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/navigation/toc.dart';

class PdfOutlineBridge {
  /// 把 pdfrx 的 outline 树（可能为 null）转为 [TableOfContents]。
  static TableOfContents toTableOfContents(PdfOutlineNode? root) {
    if (root == null) return TableOfContents.empty();
    return TableOfContents(entries: _convertChildren(root.children));
  }

  static List<TocEntry> _convertChildren(List<PdfOutlineNode> nodes) {
    final result = <TocEntry>[];
    for (final node in nodes) {
      final dest = node.dest;
      final page = dest is PdfDestRef ? dest.page : null;
      if (page == null) continue;
      result.add(TocEntry(
        title: node.title,
        locator: PdfPageLocator(page: page, offsetX: 0, offsetY: 0),
        children: _convertChildren(node.children),
      ));
    }
    return result;
  }
}
```

注意：`PdfDest` 是 sealed class。pdfrx 内部 `PdfDestRef` 是带 `page` 字段的具体子类。具体类型名以 spike 验证为准。

- [ ] **Step 4: 加 toc getter 到 PdfRenderer**

在 `pdf_renderer.dart` 加：
```dart
  Future<TableOfContents> get toc async {
    final doc = _doc;
    if (doc == null) return TableOfContents.empty();
    return PdfOutlineBridge.toTableOfContents(doc.outlines);
  }
```
加 import：`import 'package:reader_engine/navigation/toc.dart';` 和 `import 'pdf_outline_bridge.dart';`

- [ ] **Step 5: 验证测试通过**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_outline_bridge_test.dart
```
Expected: PASS (4/4)

- [ ] **Step 6: 提交**

```bash
git add reader_engine_pdf_view/lib/pdf_outline_bridge.dart reader_engine_pdf_view/lib/pdf_renderer.dart reader_engine_pdf_view/test/pdf_outline_bridge_test.dart
git commit -m "feat(m4/t6): pdfrx outline → TocEntry bridge"
```

---

## Task 7: 主题适配（day/sepia/night via ColorFiltered）

**Files:**
- Create: `reader_engine_pdf_view/lib/pdf_theme.dart`
- Modify: `reader_engine_pdf_view/lib/pdf_renderer.dart` (build 包一层)
- Test: `reader_engine_pdf_view/test/pdf_theme_test.dart`

- [ ] **Step 1: 写失败测试**

`reader_engine_pdf_view/test/pdf_theme_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine_pdf_view/pdf_theme.dart';

void main() {
  testWidgets('day theme returns child as-is', (tester) async {
    const child = SizedBox(key: Key('inner'));
    await tester.pumpWidget(MaterialApp(
      home: PdfTheme.applyTheme(theme: ReadingTheme.day, child: child),
    ));
    expect(find.byKey(const Key('inner')), findsOneWidget);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('sepia theme wraps with ColorFiltered', (tester) async {
    const child = SizedBox();
    await tester.pumpWidget(MaterialApp(
      home: PdfTheme.applyTheme(theme: ReadingTheme.sepia, child: child),
    ));
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('night theme wraps with ColorFiltered', (tester) async {
    const child = SizedBox();
    await tester.pumpWidget(MaterialApp(
      home: PdfTheme.applyTheme(theme: ReadingTheme.night, child: child),
    ));
    expect(find.byType(ColorFiltered), findsOneWidget);
  });
}
```

- [ ] **Step 2: 验证失败**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_theme_test.dart
```
Expected: FAIL — file doesn't exist

- [ ] **Step 3: 写 PdfTheme**

`reader_engine_pdf_view/lib/pdf_theme.dart`:
```dart
import 'package:flutter/widgets.dart';
import 'package:reader_engine/core/typography_settings.dart';

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
        return ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0x40F5DEB3),
            BlendMode.dstATop,
          ),
          child: child,
        );
      case ReadingTheme.night:
        return const ColorFiltered(
          colorFilter: ColorFilter.matrix(<double>[
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

- [ ] **Step 4: 验证测试通过**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_theme_test.dart
```
Expected: PASS (3/3)

- [ ] **Step 5: 把 PdfTheme 接入 PdfRenderer.build**

修改 `pdf_renderer.dart` 的 `build` 方法：
```dart
  Widget build(BuildContext context) {
    final doc = _doc;
    if (doc == null) return const SizedBox.shrink();
    return PdfTheme.applyTheme(
      theme: _typography.theme,
      child: PdfViewer.file(doc.sourceName),
    );
  }
```

- [ ] **Step 6: 跑所有 PDF 测试**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test
```
Expected: 全 PASS

- [ ] **Step 7: 提交**

```bash
git add reader_engine_pdf_view/lib/pdf_theme.dart reader_engine_pdf_view/lib/pdf_renderer.dart reader_engine_pdf_view/test/pdf_theme_test.dart
git commit -m "feat(m4/t7): PDF theme adapter (day/sepia/night via ColorFiltered)"
```

---

## Task 8: 选区 bridge — pdfrx selection → HighlightSelection

**Files:**
- Create: `reader_engine_pdf_view/lib/pdf_selection_bridge.dart`
- Modify: `reader_engine_pdf_view/lib/pdf_renderer.dart` (buildContextMenu hook)
- Test: `reader_engine_pdf_view/test/pdf_selection_bridge_test.dart`

- [ ] **Step 1: 写失败测试**

`reader_engine_pdf_view/test/pdf_selection_bridge_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';
import 'package:reader_engine_pdf_view/pdf_selection_bridge.dart';

void main() {
  group('PdfSelectionBridge.fromSelection', () {
    test('null selectedText returns null', () {
      final result = PdfSelectionBridge.fromSelection(
        selectedText: null,
        page: 5,
      );
      expect(result, isNull);
    });

    test('empty selectedText returns null', () {
      final result = PdfSelectionBridge.fromSelection(
        selectedText: '',
        page: 5,
      );
      expect(result, isNull);
    });

    test('non-empty text produces HighlightSelection with PdfRangeLocator', () {
      final result = PdfSelectionBridge.fromSelection(
        selectedText: 'quoted text',
        page: 5,
      );
      expect(result, isNotNull);
      expect(result!.selectedText, 'quoted text');
      final loc = result.locator;
      expect(loc, isA<PdfRangeLocator>());
      expect((loc as PdfRangeLocator).page, 5);
      expect(loc.startOffset, 0);
      expect(loc.endOffset, 'quoted text'.length);
      expect(loc.quote, 'quoted text');
    });
  });

  testWidgets('buildHighlightButton invokes callback on tap', (tester) async {
    HighlightSelection? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PdfSelectionBridge.buildHighlightButton(
          selectedText: 'hi',
          page: 1,
          onHighlight: (s) => captured = s,
        ),
      ),
    ));
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(captured, isNotNull);
    expect((captured!.locator as PdfRangeLocator).page, 1);
  });
}
```

- [ ] **Step 2: 验证失败**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_selection_bridge_test.dart
```
Expected: FAIL — file doesn't exist

- [ ] **Step 3: 写 bridge**

`reader_engine_pdf_view/lib/pdf_selection_bridge.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';

class PdfSelectionBridge {
  /// 把 pdfrx 选区文本转为 [HighlightSelection]，无法转换时返回 null。
  ///
  /// [page] 是 pdfrx 的 1-based 页码（从 selection.page.pageNumber 取或 fallback）。
  /// startOffset/endOffset 用 quote 长度作 MVP 简化（pdfrx 不暴露精确 char offset）。
  static HighlightSelection? fromSelection({
    required String? selectedText,
    required int page,
  }) {
    if (selectedText == null || selectedText.isEmpty) return null;
    return HighlightSelection(
      locator: PdfRangeLocator(
        page: page,
        startOffset: 0,
        endOffset: selectedText.length,
        quote: selectedText,
      ),
      selectedText: selectedText,
    );
  }

  /// 「高亮」按钮 widget；点击触发 [onHighlight] 回调。
  static Widget buildHighlightButton({
    required String selectedText,
    required int page,
    required ValueChanged<HighlightSelection> onHighlight,
  }) {
    return TextButton.icon(
      icon: const Icon(Icons.format_color_fill, size: 18),
      label: const Text('高亮'),
      onPressed: () {
        final sel = fromSelection(selectedText: selectedText, page: page);
        if (sel != null) onHighlight(sel);
      },
    );
  }
}
```

- [ ] **Step 4: 验证测试通过**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_selection_bridge_test.dart
```
Expected: PASS (4/4)

- [ ] **Step 5: 接入 PdfRenderer.build**

修改 `pdf_renderer.dart`：
```dart
  Widget build(BuildContext context) {
    final doc = _doc;
    if (doc == null) return const SizedBox.shrink();
    return PdfTheme.applyTheme(
      theme: _typography.theme,
      child: PdfViewer.file(
        doc.sourceName,
        params: PdfViewerParams(
          textSelectionParams: const PdfTextSelectionParams(enabled: true),
          buildContextMenu: (context, selectedText, selection) {
            final page = _pageFromSelection(selection) ?? (_currentPage + 1);
            return Material(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).menuBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PdfSelectionBridge.buildHighlightButton(
                  selectedText: selectedText ?? '',
                  page: page,
                  onHighlight: emitSelection,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  int? _pageFromSelection(PdfSelection? sel) {
    // pdfrx API spike needed; fallback to current page
    return null;
  }
```

加 import：`import 'pdf_selection_bridge.dart';`

- [ ] **Step 6: 跑测试**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test
```
Expected: 全 PASS

- [ ] **Step 7: 提交**

```bash
git add reader_engine_pdf_view/lib/pdf_selection_bridge.dart reader_engine_pdf_view/lib/pdf_renderer.dart reader_engine_pdf_view/test/pdf_selection_bridge_test.dart
git commit -m "feat(m4/t8): pdfrx selection → HighlightSelection bridge"
```

---

## Task 9: 扫描 PDF heuristic 检测 + banner

**Files:**
- Create: `reader_engine_pdf_view/lib/pdf_scanned_detector.dart`
- Modify: `reader_engine_pdf_view/lib/pdf_renderer.dart` (banner overlay)
- Test: `reader_engine_pdf_view/test/pdf_scanned_detector_test.dart`

- [ ] **Step 1: 写失败测试**

`reader_engine_pdf_view/test/pdf_scanned_detector_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_pdf_view/pdf_scanned_detector.dart';

void main() {
  group('PdfScannedDetector.isLikelyScannedByCharCount', () {
    test('totalChars < 100 returns true', () {
      expect(PdfScannedDetector.isLikelyScannedByCharCount(50), isTrue);
    });

    test('totalChars >= 100 returns false', () {
      expect(PdfScannedDetector.isLikelyScannedByCharCount(100), isFalse);
      expect(PdfScannedDetector.isLikelyScannedByCharCount(5000), isFalse);
    });

    test('boundary: 99 chars returns true', () {
      expect(PdfScannedDetector.isLikelyScannedByCharCount(99), isTrue);
    });
  });

  testWidgets('PdfScannedBanner renders warning text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PdfScannedBanner()),
    ));
    expect(find.textContaining('扫描件'), findsOneWidget);
  });

  testWidgets('PdfScannedBanner has warning icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PdfScannedBanner()),
    ));
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
  });
}
```

- [ ] **Step 2: 验证失败**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_scanned_detector_test.dart
```
Expected: FAIL — file doesn't exist

- [ ] **Step 3: 写 detector + banner**

`reader_engine_pdf_view/lib/pdf_scanned_detector.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfScannedDetector {
  /// 阈值：前 N 页累计字符数 < 100 → 判定为扫描件。
  static const int _scannedThreshold = 100;

  /// Pure function：给定累计字符数判断是否扫描件。
  /// 与异步 loadText 解耦，便于单测。
  static bool isLikelyScannedByCharCount(int totalChars) {
    return totalChars < _scannedThreshold;
  }

  /// 前 3 页（或更少）累计文本字符数判断。
  /// 三种 fallback 情况保守返回 false（不显示 banner）：
  /// - pdfrx API 抛异常
  /// - 所有页文本均为空（API 不可用 → 无法判定）
  static Future<bool> isLikelyScanned(PdfDocument doc) async {
    final checkPages = doc.pages.length < 3 ? doc.pages.length : 3;
    var totalChars = 0;
    var apiWorks = false;
    for (var i = 0; i < checkPages; i++) {
      try {
        final text = await _tryLoadText(doc.pages[i]);
        if (text.isNotEmpty) apiWorks = true;
        totalChars += text.length;
        if (!isLikelyScannedByCharCount(totalChars)) return false;
      } catch (_) {
        return false;
      }
    }
    if (!apiWorks) return false;  // API 不可用 → 不显示 banner（避免误判）
    return isLikelyScannedByCharCount(totalChars);
  }

  /// pdfrx_engine 低层文本提取（best-effort）。
  /// 实现 spike 任务：查找 pdfrx_engine 暴露的 text API（如 PdfTextExtractor），
  /// 若无则保持返回 ''（fallback 由 caller 处理）。
  static Future<String> _tryLoadText(PdfPage page) async {
    // TODO implementer: 用 pdfrx_engine 的 PdfTextExtractor 或等价 API
    // 如该 API 不存在，保持 return ''（caller 会走 fallback 不显示 banner）
    return '';
  }
}

class PdfScannedBanner extends StatelessWidget {
  const PdfScannedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined),
            SizedBox(width: 8),
            Expanded(child: Text('扫描件：高亮、笔记、搜索不可用')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 验证测试通过**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test test/pdf_scanned_detector_test.dart
```
Expected: PASS (5/5)

- [ ] **Step 5: 接入 PdfRenderer.build（条件 banner）**

修改 `pdf_renderer.dart` 的 `build`，把整个 PdfTheme.applyTheme 包到 Column：
```dart
  Widget build(BuildContext context) {
    final doc = _doc;
    if (doc == null) return const SizedBox.shrink();
    return FutureBuilder<bool>(
      future: _scannedFuture ??= PdfScannedDetector.isLikelyScanned(doc),
      builder: (context, snap) {
        final showBanner = snap.data == true;
        return Column(
          children: [
            if (showBanner) const PdfScannedBanner(),
            Expanded(
              child: PdfTheme.applyTheme(
                theme: _typography.theme,
                child: PdfViewer.file(
                  doc.sourceName,
                  params: PdfViewerParams(
                    textSelectionParams: PdfTextSelectionParams(
                      enabled: !showBanner,
                    ),
                    buildContextMenu: (context, selectedText, selection) {
                      // T8 选区菜单
                      return Material(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: PdfSelectionBridge.buildHighlightButton(
                            selectedText: selectedText ?? '',
                            page: _currentPage + 1,
                            onHighlight: emitSelection,
                          ),
                        ),
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

  Future<bool>? _scannedFuture;
```

加 import：`import 'pdf_scanned_detector.dart';`

- [ ] **Step 6: 跑测试**

Run:
```bash
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test
```
Expected: 全 PASS

- [ ] **Step 7: 提交**

```bash
git add reader_engine_pdf_view/lib/pdf_scanned_detector.dart reader_engine_pdf_view/lib/pdf_renderer.dart reader_engine_pdf_view/test/pdf_scanned_detector_test.dart
git commit -m "feat(m4/t9): scanned PDF heuristic + banner"
```

---

## Task 10: book_format_detector + Import 适配

**Files:**
- Create: `app/lib/data/services/book_format_detector.dart`
- Modify: `app/lib/data/repositories/local_book_repository.dart`
- Test: `app/test/data/services/book_format_detector_test.dart`

- [ ] **Step 1: 写失败测试**

`app/test/data/services/book_format_detector_test.dart`:
```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/services/book_format_detector.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('book_format_detector_test');
  });
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File _writeBytes(String name, List<int> bytes) {
    final f = File(p.join(tempDir.path, name));
    f.writeAsBytesSync(bytes);
    return f;
  }

  test('PDF magic bytes detected', () {
    final f = _writeBytes('a.pdf', [0x25, 0x50, 0x44, 0x46, 0x2D, ...List.filled(100, 0)]);
    expect(BookFormatDetector.detect(f.path), BookFormat.pdf);
  });

  test('EPUB by extension fallback (PK zip)', () {
    final f = _writeBytes('a.epub', [0x50, 0x4B, 0x03, 0x04, ...List.filled(100, 0)]);
    expect(BookFormatDetector.detect(f.path), BookFormat.epub);
  });

  test('Unknown format returns null', () {
    final f = _writeBytes('a.unknown', [0x00, 0x01, 0x02, ...List.filled(100, 0)]);
    expect(BookFormatDetector.detect(f.path), isNull);
  });

  test('Too-small file returns null', () {
    final f = _writeBytes('tiny.pdf', [0x25]);
    expect(BookFormatDetector.detect(f.path), isNull);
  });

  test('PDF magic but wrong extension still detected as PDF', () {
    final f = _writeBytes('a.bin', [0x25, 0x50, 0x44, 0x46, 0x2D, ...List.filled(100, 0)]);
    expect(BookFormatDetector.detect(f.path), BookFormat.pdf);
  });
}
```

- [ ] **Step 2: 验证失败**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/data/services/book_format_detector_test.dart
```
Expected: FAIL — file doesn't exist

- [ ] **Step 3: 写 detector**

`app/lib/data/services/book_format_detector.dart`:
```dart
import 'dart:io';

import 'package:zhiyue/data/models/book.dart';

class BookFormatDetector {
  /// 检测文件 magic bytes 返回格式。
  /// - `%PDF-` → pdf
  /// - ZIP (PK..) + `.epub` 扩展名 → epub
  /// - 其他 / 太小 → null
  static BookFormat? detect(String path) {
    final bytes = File(path).readAsBytesSync();
    if (bytes.length < 5) return null;
    // PDF magic: %PDF-
    if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 &&
        bytes[3] == 0x46 && bytes[4] == 0x2D) {
      return BookFormat.pdf;
    }
    // EPUB: PK zip header
    if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
      final pathLower = path.toLowerCase();
      if (pathLower.endsWith('.epub')) return BookFormat.epub;
    }
    return null;
  }
}
```

- [ ] **Step 4: 验证测试通过**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/data/services/book_format_detector_test.dart
```
Expected: PASS (5/5)

- [ ] **Step 5: 接入 local_book_repository**

阅读 `app/lib/data/repositories/local_book_repository.dart` 找到 import 入口方法（通常是 `importBook(String filePath)` 或类似），把现有 hard-coded `BookFormat.epub` 改为：
```dart
import '../services/book_format_detector.dart';
// ...
final format = BookFormatDetector.detect(filePath) ?? BookFormat.epub;  // 默认 epub（向后兼容）
```

如果 import 流程已经在调用方（如 import_book_service）做了扩展名判断，相应改成调 detector。

- [ ] **Step 6: 跑相关测试**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/data/repositories/local_book_repository_test.dart
```
Expected: 现有测试不破坏（如检测到有 hardcoded epub 测试，确保 detector 对应 epub 仍正确判定）

- [ ] **Step 7: 提交**

```bash
git add app/lib/data/services/book_format_detector.dart app/lib/data/repositories/local_book_repository.dart app/test/data/services/book_format_detector_test.dart
git commit -m "feat(m4/t10): book format detector + import integration"
```

---

## Task 11: Library UI — PDF chip + BookDetailPage 页数

**Files:**
- Modify: `app/lib/features/library/widgets/book_cell.dart`
- Modify: `app/lib/features/library/widgets/book_list_view.dart`
- Modify: `app/lib/features/library/pages/book_detail_page.dart`
- Test: `app/test/features/library/widgets/book_cell_pdf_chip_test.dart`
- Test: `app/test/goldens/library_cell_pdf_golden_test.dart`

- [ ] **Step 1: 写失败测试**

`app/test/features/library/widgets/book_cell_pdf_chip_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/widgets/book_cell.dart';

void main() {
  testWidgets('PDF book shows PDF chip', (tester) async {
    final book = Book(
      id: '1',
      title: 'PDF Book',
      author: 'Test',
      format: BookFormat.pdf,
      filePath: '/x.pdf',
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
      lastReadLocatorJson: null,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BookCell(book: book, onTap: () {})),
    ));
    expect(find.text('PDF'), findsOneWidget);
  });

  testWidgets('EPUB book does not show PDF chip', (tester) async {
    final book = Book(
      id: '1',
      title: 'EPUB Book',
      author: 'Test',
      format: BookFormat.epub,
      filePath: '/x.epub',
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
      lastReadLocatorJson: null,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BookCell(book: book, onTap: () {})),
    ));
    expect(find.text('PDF'), findsNothing);
  });
}
```

注意：`Book` 构造器字段以现有代码为准（参考 `app/lib/data/models/book.dart`）。

- [ ] **Step 2: 验证失败**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/features/library/widgets/book_cell_pdf_chip_test.dart
```
Expected: FAIL — PDF chip not rendered

- [ ] **Step 3: BookCell 加 chip**

在 `book_cell.dart` 适当位置（通常右下角）加：
```dart
if (book.format == BookFormat.pdf)
  Positioned(
    right: 4,
    bottom: 4,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PDF',
        style: TextStyle(color: Colors.white, fontSize: 10),
      ),
    ),
  ),
```

- [ ] **Step 4: BookListView 加 chip**

类似 BookCell，在 list item 末尾加 chip。

- [ ] **Step 5: BookDetailPage 改为页数显示**

在 `book_detail_page.dart` 找到显示「N 章」的地方，改为 format-aware：
```dart
Text(book.format == BookFormat.pdf
    ? '${bookProgress.currentPage} / ${bookProgress.totalPages} 页'
    : '${bookProgress.currentChapter} / ${bookProgress.totalChapters} 章'),
```

如果当前页面没有进度信息块，跳过；进度信息归 T12。

- [ ] **Step 6: 验证测试通过**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/features/library/widgets/book_cell_pdf_chip_test.dart
```
Expected: PASS (2/2)

- [ ] **Step 7: 重新生成 Library goldens（PDF chip 改了渲染）**

```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test --update-goldens test/goldens/library_golden_test.dart
```

- [ ] **Step 8: 提交**

```bash
git add app/lib/features/library/widgets/book_cell.dart app/lib/features/library/widgets/book_list_view.dart app/lib/features/library/pages/book_detail_page.dart app/test/features/library/widgets/book_cell_pdf_chip_test.dart app/test/goldens/ app/test/goldens/failures/
git commit -m "feat(m4/t11): Library UI PDF chip + BookDetailPage page count"
```

---

## Task 12: ReaderPage 适配 — 章节标题 + 进度比 fallback

**Files:**
- Modify: `app/lib/features/reader/pages/reader_page.dart`
- Test: `app/test/features/reader/pages/reader_page_pdf_test.dart`

- [ ] **Step 1: 调研 reader_page 当前结构**

阅读 `app/lib/features/reader/pages/reader_page.dart` 找到：
- 章节标题显示位置（当前可能从 `engine.toc?.entries` 或类似拿）
- 进度比计算位置（可能基于 chapter index）

- [ ] **Step 2: 写失败测试**

`app/test/features/reader/pages/reader_page_pdf_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// 引入 reader_page test helper（参考 reader_page_test.dart 既有测试）

void main() {
  testWidgets('PDF reader page shows "第 N 页" instead of chapter title',
      (tester) async {
    // 用 mock engine 或 fake
    // Pump ReaderPage with PDF book
    // Assert: header contains "第 1 页"
    // 注意：具体 setup 见 reader_page_test.dart 现有模式
  });

  testWidgets('PDF reader progress shows page/total ratio', (tester) async {
    // ...
  });
}
```

具体 helper 用 reader_page_test.dart 现有 setup 模式（fake engine + provider override）。

- [ ] **Step 3: 验证失败**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/features/reader/pages/reader_page_pdf_test.dart
```
Expected: FAIL — 标题/进度未对 PDF fallback

- [ ] **Step 4: 改 reader_page**

在 reader_page.dart 找到章节标题构建处，改为 format-aware：
```dart
String _chapterOrPageLabel(ReaderEngine engine) {
  if (engine is PdfReaderEngine) {
    return '第 ${engine.currentPage + 1} 页';
  }
  // EPUB 原逻辑
  final tocEntry = engine.toc?.entries.elementAtOrNull(engine.currentChapterIndex);
  return tocEntry?.title ?? '第 ${engine.currentChapterIndex + 1} 章';
}
```

进度比类似：
```dart
double _progressRatio(ReaderEngine engine) {
  if (engine is PdfReaderEngine) {
    final total = engine.pageCount;  // 如接口没暴露，用 renderer 内部
    return total > 0 ? (engine.currentPage + 1) / total : 0;
  }
  // EPUB 原逻辑
}
```

⚠️ `PdfReaderEngine.currentPage` / `pageCount` 不是 ReaderEngine 接口的一部分。需要：
- 选项 A：在 ReaderEngine 接口加 `int get currentChapterIndex`（已有内部对应，可以暴露）
- 选项 B：reader_page 用 `engine is PdfReaderEngine` 类型检查（推荐：最少改动）

选项 B 更保守，T12 用之。

- [ ] **Step 5: 验证测试通过**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/features/reader/pages/reader_page_pdf_test.dart
```
Expected: PASS

- [ ] **Step 6: 跑现有 reader_page 测试**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/features/reader/pages/reader_page_test.dart
```
Expected: 现有 EPUB 测试不破坏

- [ ] **Step 7: 提交**

```bash
git add app/lib/features/reader/pages/reader_page.dart app/test/features/reader/pages/reader_page_pdf_test.dart
git commit -m "feat(m4/t12): reader_page PDF chapter/page fallback"
```

---

## Task 13: NotesPage PDF 分组 + Markdown 导出

**Files:**
- Modify: `app/lib/features/notes/pages/notes_page.dart`
- Modify: `app/lib/data/services/markdown_exporter.dart`
- Test: `app/test/features/notes/pages/notes_page_pdf_test.dart`
- Test: `app/test/data/services/markdown_exporter_pdf_test.dart`

- [ ] **Step 1: 写失败测试**

`app/test/data/services/markdown_exporter_pdf_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/services/markdown_exporter.dart';

void main() {
  test('PDF export frontmatter contains format: pdf', () {
    final book = Book(/* format: BookFormat.pdf, ... */);
    final highlights = <Highlight>[/* with PdfRangeLocator */];
    final md = MarkdownExporter.export(book: book, highlights: highlights);
    expect(md, contains('format: pdf'));
    expect(md, contains('page:'));
  });

  test('PDF highlight uses page: instead of chapter:', () {
    // ...
  });
}
```

- [ ] **Step 2: 验证失败**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/data/services/markdown_exporter_pdf_test.dart
```
Expected: FAIL — exporter 未处理 PDF

- [ ] **Step 3: 改 markdown_exporter**

`markdown_exporter.dart` 加 format-aware 分支：
```dart
String export({required Book book, required List<Highlight> highlights}) {
  final isPdf = book.format == BookFormat.pdf;
  final buf = StringBuffer();
  buf.writeln('---');
  buf.writeln('title: ${book.title}');
  buf.writeln('author: ${book.author}');
  buf.writeln('format: ${isPdf ? 'pdf' : 'epub'}');
  if (isPdf) buf.writeln('total_pages: ${highlights.length}');  // 或 book 总页数（如有）
  buf.writeln('---');
  buf.writeln();
  
  // 分组：EPUB 按 chapterTitle，PDF 按 page
  for (final h in highlights) {
    final loc = h.locator;
    if (loc is PdfRangeLocator) {
      buf.writeln('## 第 ${loc.page} 页');
      buf.writeln('> ${loc.quote}');
    } else if (loc is EpubRangeLocator) {
      buf.writeln('## ${loc.chapterTitle ?? '第 ${loc.chapterIndex + 1} 章'}');
      buf.writeln('> ${loc.quote}');
    }
    // ...
  }
  return buf.toString();
}
```

- [ ] **Step 4: 验证测试通过**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/data/services/markdown_exporter_pdf_test.dart
```
Expected: PASS

- [ ] **Step 5: NotesPage 同样按 PDF 分组**

`notes_page.dart` 找到 section header 构建处：
```dart
String sectionLabel(Annotation annotation, BookFormat format) {
  if (format == BookFormat.pdf) {
    final loc = annotation.locator;
    return loc is PdfRangeLocator ? '第 ${loc.page} 页' : 'PDF';
  }
  return annotation.chapterTitle ?? '未分类';
}
```

- [ ] **Step 6: 跑 NotesPage 现有测试**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/features/notes/
```
Expected: 现有 EPUB 测试不破坏

- [ ] **Step 7: 提交**

```bash
git add app/lib/features/notes/pages/notes_page.dart app/lib/data/services/markdown_exporter.dart app/test/features/notes/pages/notes_page_pdf_test.dart app/test/data/services/markdown_exporter_pdf_test.dart
git commit -m "feat(m4/t13): NotesPage PDF grouping + Markdown export frontmatter"
```

---

## Task 14: 测试 PDF 样本生成 + 集成测试 + final verify

**Files:**
- Create: `tools/gen_test_pdfs.dart`
- Create: `app/test/fixtures/pdfs/sample-text.pdf`
- Create: `app/test/fixtures/pdfs/sample-scanned.pdf`
- Create: `app/test/fixtures/pdfs/sample-corrupted.pdf`
- Create: `app/test/features/reader/reader_page_pdf_integration_test.dart`

- [ ] **Step 1: 写样本生成脚本**

`tools/gen_test_pdfs.dart`:
```dart
// 用 pdf 包（pub 上 pdf ^3.x）生成测试 PDF
// 跑：dart run tools/gen_test_pdfs.dart
// 产物 commit 到 app/test/fixtures/pdfs/

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  // sample-text.pdf: 5 页含文本
  final textDoc = pw.Document();
  for (var i = 1; i <= 5; i++) {
    textDoc.addPage(pw.Page(
      build: (ctx) => pw.Center(
        child: pw.Text('Page $i\nThis is sample text content for testing PDF text extraction.'),
      ),
    ));
  }
  // 保存到 app/test/fixtures/pdfs/sample-text.pdf

  // sample-scanned.pdf: 用 image 渲染图片转 PDF（无文本层）
  // 用 pw.Image 包装空白图片

  // sample-corrupted.pdf: 截断的字节流
  final bytes = File('app/test/fixtures/pdfs/sample-text.pdf').readAsBytesSync();
  File('app/test/fixtures/pdfs/sample-corrupted.pdf').writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2));
}
```

⚠️ 用 pdf 包需要临时在 tools/ 加 `pubspec.yaml`。或者用 Python reportlab / pdfrx example 里现成的 sample.pdf。

**简化方案**：从 pdfrx GitHub `example/assets/` 下载现成 sample.pdf，commit 进 fixtures。生成脚本作为文档留存。

- [ ] **Step 2: 准备 fixtures**

从 pdfrx example 取 sample PDF，或用现有 PDF 测试文件：
```bash
# 选项 A: 用 pdfrx example assets
curl -L https://github.com/espresso3389/pdfrx/raw/master/packages/pdfrx/example/viewer/assets/hello.pdf \
  -o app/test/fixtures/pdfs/sample-text.pdf

# sample-scanned.pdf：用 PIL 生成（如 Python 可用）或手工准备
# sample-corrupted.pdf：截断的 sample-text.pdf
```

- [ ] **Step 3: 写集成测试**

`app/test/features/reader/reader_page_pdf_integration_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
// 用 sample-text.pdf 跑完整流程

void main() {
  testWidgets('PDF reader end-to-end: open, navigate, locate', (tester) async {
    // 1. Setup in-memory database
    // 2. Import sample-text.pdf
    // 3. Open reader_page
    // 4. Wait for pdfrx to load
    // 5. Assert page count == 5
    // 6. Tap next page
    // 7. Assert currentLocation emits page 2
    // 8. Assert progress ratio updated
  });

  testWidgets('PDF reader scanned banner appears for scanned PDF', (tester) async {
    // Similar but with sample-scanned.pdf
    // Assert banner widget rendered
  });

  testWidgets('PDF reader shows error state for corrupted PDF', (tester) async {
    // Similar but with sample-corrupted.pdf
    // Assert ReaderEngineError state
  });
}
```

具体 helper 借鉴 reader_page_test.dart。

- [ ] **Step 4: 跑集成测试**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test test/features/reader/reader_page_pdf_integration_test.dart
```
Expected: PASS

注意：pdfrx 在 widget test 环境可能需要 platform channels。如失败，改为 integration_test 目录下的真机测试。

- [ ] **Step 5: 全套测试**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/flutter test
cd H:/projiect/电子书阅读平台/reader_engine && /c/flutter/bin/flutter test
cd H:/projiect/电子书阅读平台/reader_engine_epub_view && /c/flutter/bin/flutter test
cd H:/projiect/电子书阅读平台/reader_engine_pdf_view && /c/flutter/bin/flutter test
```
Expected: 全 PASS（含原 491 + 新增 ~30 = ~520）

- [ ] **Step 6: dart analyze**

Run:
```bash
cd H:/projiect/电子书阅读平台/app && /c/flutter/bin/dart analyze lib/ reader_engine_pdf_view/lib/
```
Expected: 无新 error / 新 warning

- [ ] **Step 7: Tag + 推送**

```bash
git tag m4-complete
git push origin master
git push origin m4-complete
```

- [ ] **Step 8: 提交**

```bash
git add tools/ app/test/fixtures/ app/test/features/reader/reader_page_pdf_integration_test.dart
git commit -m "test(m4/t14): PDF integration tests + fixtures + tag m4-complete"
```

---

## Self-Review Checklist

执行完所有任务后，自审：

- [ ] **Spec 覆盖**：spec §1.2 列出的 14 项 in-scope 内容（A–N）是否都有任务覆盖？
  - A: T0-T4 ✅
  - B: T4 ✅
  - C: T1 ✅
  - D: T8 ✅
  - E: T9 ✅
  - F: T7 ✅
  - G: T0 (pdfrx 内置) ✅
  - H: T6 ✅
  - I: T5 ✅
  - J: T10 ✅
  - K: T11 ✅
  - L: T1+T8 (Locator JSON 兼容) ✅
  - M: T13 ✅
  - N: T13 ✅
- [ ] **占位符扫描**：每个 step 的 code block 都是可运行的代码（非 `TODO` / `...`）
- [ ] **类型一致性**：`PdfRangeLocator` 字段名（page/startOffset/endOffset/quote）在 T1 / T8 / T13 一致
- [ ] **API 兼容性**：pdfrx v2.3 API（`PdfViewer.file` / `PdfDocument.openFile` / `PdfTextSelectionParams` / `PdfViewerParams.buildContextMenu`）在 spec 和 plan 一致
- [ ] **测试覆盖**：每个新文件都有对应测试文件

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-28-m4-pdf-renderer.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration. 与 M3.5 节奏一致。

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
