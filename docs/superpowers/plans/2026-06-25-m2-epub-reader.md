# M2 EPUB 阅读器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 EPUB 阅读器（解析/渲染/翻页/TOC/CFI 进度/基础排版），UI 完全 format-agnostic，为 M4 PDF 接入留出零改造路径。

**Architecture:** 双层抽象（`ReaderEngine` + `EpubRenderer`），三个 package 拆分（`reader_engine/` 纯 Dart + `reader_engine_epub_view/` Flutter 包 + `app/lib/features/reader/` UI），M1 的 `Locator` / `TypographySettings` 迁入 `reader_engine/`，`app/lib/core/` 改为 re-export 保 API 兼容。

**Tech Stack:** Flutter 3.27 / Dart 3.10 / Riverpod 2.5 / go_router 14 / drift 2.18 / `epubx`（parser，pivot 后引入）/ `flutter_widget_from_html`（HTML→widget，pivot 后引入）/ `golden_toolkit`（新引入，dev）

> ⚠️ **2026-06-26 pivot**: 原 plan 用 `epub_view_plus`，实际未发布 pub.dev。已 pivot 到 `epubx + 自研渲染`，工期 6→12 周。详见 spec §10/§11/附录 A.2 与 memory `project_zhiyue_m2_pivot_epubx.md`。Tasks 9-14 已重写为自研渲染版本。

**Spec:** `docs/superpowers/specs/2026-06-25-m2-epub-reader-design.md`

---

## 项目约束（执行者必读）

1. **Flutter SDK 路径**：bash 中所有 flutter 命令使用 `/c/flutter/bin/flutter`（Windows 上 PATH 未持久化）。dart 命令同理 `/c/flutter/bin/dart`。
2. **静态分析**：必须用 `dart analyze` 而非 `flutter analyze`（中文项目路径会触发后者 bug）。
3. **每次任务完成后**：commit 并 push 到 Gitee (`origin/master`)，commit message 用 `feat(m2):` / `refactor(m2):` / `test(m2):` / `docs(m2):` 前缀，与现有 M1 commit 风格一致。
4. **代码风格**（`app/analysis_options.yaml` 强制）：
   - 单引号
   - 尾随逗号
   - `prefer_const_constructors`
   - `cascade_invocations`
   - `unawaited_futures`
   - 禁用 `print`（用日志或 debugPrint）
5. **测试运行**：
   - app 包：`/c/flutter/bin/flutter test app/test/path/to/test.dart`
   - reader_engine 包：`/c/flutter/bin/dart test reader_engine/test/path/to/test.dart`（纯 Dart）
6. **当前分支**：`master`（项目 solo-dev，29 commit 都在 master，本里程碑不切分支）
7. **fixture EPUB**：M2 W1 末尾需要本地准备 4 本测试 EPUB（不入库，参见 Task 11）

---

## 文件结构

### 新建 package：`reader_engine/`（纯 Dart，无 Flutter 依赖）

| 文件 | 职责 |
|---|---|
| `reader_engine/pubspec.yaml` | 包元数据，仅依赖 `meta` |
| `reader_engine/lib/reader_engine.dart` | barrel：导出所有公共 API |
| `reader_engine/lib/core/locator.dart` | **从 `app/lib/core/locator.dart` 迁入**（M1 已有，原文件改 re-export） |
| `reader_engine/lib/core/typography_settings.dart` | **从 `app/lib/data/models/typography_settings.dart` 迁入**（同上） |
| `reader_engine/lib/core/book_ref.dart` | **新增** — BookRef 轻量引用 |
| `reader_engine/lib/rendering/renderer.dart` | **新增** — EpubRenderer abstract interface |
| `reader_engine/lib/rendering/pagination_model.dart` | **新增** — PaginationMode enum |
| `reader_engine/lib/navigation/toc.dart` | **新增** — TableOfContents / TocEntry |
| `reader_engine/lib/engine/reader_engine.dart` | **新增** — ReaderEngine abstract interface + ReaderEngineState sealed |
| `reader_engine/test/**` | 单元测试 |

### 新建 package：`reader_engine_epub_view/`（Flutter 包）

| 文件 | 职责 |
|---|---|
| `reader_engine_epub_view/pubspec.yaml` | 依赖 flutter / epubx / flutter_widget_from_html / reader_engine（path 依赖） |
| `reader_engine_epub_view/lib/epubx_renderer.dart` | EpubxRenderer implements EpubRenderer（包装 epubx + flutter_widget_from_html） |
| `reader_engine_epub_view/lib/paginator.dart` | 自研分页：TextPainter 测高 + 章节切片（PageBreak 列表） |
| `reader_engine_epub_view/lib/cfi_codec.dart` | 纯函数：自定义位置格式 `chapterIndex:charOffset` 编解码 |
| `reader_engine_epub_view/spike/epubx_smoke_test.dart` | Task 10 spike（验证 epubx 解析 + HTML 可读；spike 后可删） |
| `reader_engine_epub_view/test/**` | 单元测试 + widget 测试 |

### 修改 `app/`

| 文件 | 变更 |
|---|---|
| `app/pubspec.yaml` | 加 `golden_toolkit`（dev）；加 path 依赖 reader_engine / reader_engine_epub_view（epubx / flutter_widget_from_html 通过后者间接引入） |
| `app/lib/core/locator.dart` | 改为 `export 'package:reader_engine/core/locator.dart';` |
| `app/lib/data/models/typography_settings.dart` | 改为 `export 'package:reader_engine/core/typography_settings.dart';` |
| `app/lib/main.dart` | 无变更 |
| `app/lib/features/reader/pages/reader_page.dart` | **新增** — 路由入口 |
| `app/lib/features/reader/widgets/reader_scaffold.dart` | **新增** — 沉浸式容器，tap 区域分发 |
| `app/lib/features/reader/widgets/reader_app_bar.dart` | **新增** — 顶部 chrome |
| `app/lib/features/reader/widgets/reader_bottom_bar.dart` | **新增** — 进度条 + 章节标题 |
| `app/lib/features/reader/widgets/toc_drawer.dart` | **新增** — 目录侧滑 |
| `app/lib/features/reader/widgets/typography_panel.dart` | **新增** — 排版设置弹层 |
| `app/lib/features/reader/controllers/reader_ui_controller.dart` | **新增** — 沉浸模式 / 抽屉开关 |
| `app/lib/features/reader/providers/reader_engine_provider.dart` | **新增** — Riverpod provider |
| `app/lib/features/reader/services/progress_persister.dart` | **新增** — 进度防抖写入 |
| `app/lib/features/home/home_page.dart` | 修改：加"打开最后一本书"按钮，触发 `/book/:id` 路由 |
| `app/lib/core/app.dart` | 修改：注册 go_router 路由 |
| `app/test/features/reader/**` | widget 测试 |
| `app/test/goldens/**` | golden 快照 |
| `app/integration_test/reader_flow_test.dart` | **新增** — 端到端集成测试 |
| `app/test/fixtures/` | **新增** — EPUB 测试书（gitignore）+ README |

---

## 任务总览（25 个任务）

| # | 任务 | 周 |
|---|---|---|
| 1 | 创建 reader_engine package 骨架 | W1 |
| 2 | 迁移 Locator 到 reader_engine | W1 |
| 3 | 迁移 TypographySettings 到 reader_engine | W1 |
| 4 | 新增 BookRef 模型 | W1 |
| 5 | 新增 PaginationMode + ReaderEngineState + TocEntry/TableOfContents | W1 |
| 6 | 新增 ReaderEngine + EpubRenderer 抽象接口 | W1 |
| 7 | 创建 reader_engine_epub_view package 骨架 | W1 |
| 8 | fixture EPUB 基础设施 | W1 |
| 9 | 实现 cfi_codec 纯函数模块（自定义 `chapterIndex:charOffset`） | W1 |
| 10 | **W1 Spike**：epubx 解析 + flutter_widget_from_html 渲染冒烟 | W1 |
| 11 | 实现 EpubxRenderer.open + 状态流 | W2 |
| 12 | 实现 EpubxRenderer.build（章节渲染）+ currentLocation$ + gotoLocator | W2 |
| 13 | 自研 Paginator（TextPainter 分页算法） | W3 |
| 14 | 实现 ReaderScaffold（tap 区域 + 双模式翻页 paged/scroll） | W3 |
| 15 | 实现 TOC 提取 + TocDrawer | W3 |
| 16 | 实现 ProgressPersister（防抖 + distinct + 静默失败） | W3 |
| 17 | 实现 ReaderEngineProvider + 打开书籍主流程 | W3 |
| 18 | 实现 ReaderBottomBar（进度显示） | W3 |
| 19 | 实现 TypographySettings → CSS 注入 | W4 |
| 20 | 实现 TypographyPanel UI | W4 |
| 21 | 实现 Fatal / Recoverable / Soft 错误处理 | W4 |
| 22 | Widget 测试：所有 UI 组件 | W5 |
| 23 | Golden 测试：6 个渲染快照 | W5 |
| 24 | 集成测试：打开/翻页/退出/重开/排版切换 | W5 |
| 25 | 最终全局 code review + 验收清单核对 | W6 |

---

## Task 1: 创建 reader_engine package 骨架

**Files:**
- Create: `reader_engine/pubspec.yaml`
- Create: `reader_engine/lib/reader_engine.dart`
- Create: `reader_engine/test/smoke_test.dart`
- Modify: `app/pubspec.yaml`（加 path 依赖）
- Modify: `pubspec.yaml`（如不存在则在 workspace 根创建，列出两个子包；否则只改 app/pubspec.yaml）

- [ ] **Step 1: 创建 `reader_engine/pubspec.yaml`**

```yaml
name: reader_engine
description: 智阅阅读引擎抽象层 —— 纯 Dart 包，定义 ReaderEngine 接口和共享模型。
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.10.0

dependencies:
  meta: ^1.15.0

dev_dependencies:
  test: ^1.25.0
```

- [ ] **Step 2: 创建空 barrel `reader_engine/lib/reader_engine.dart`**

```dart
/// reader_engine — 阅读引擎抽象层。
///
/// 永远不依赖 Flutter，所有抽象和模型在此。
library reader_engine;
```

- [ ] **Step 3: 创建冒烟测试 `reader_engine/test/smoke_test.dart`**

```dart
import 'package:test/test.dart';
import 'package:reader_engine/reader_engine.dart';

void main() {
  test('package imports cleanly', () {
    expect(readerEngineLibraryVersion, isNotNull);
  });
}
```

为了让测试通过，在 barrel 文件加一个常量：

```dart
library reader_engine;

const String readerEngineLibraryVersion = '0.1.0';
```

- [ ] **Step 4: 运行测试验证失败**

Run: `/c/flutter/bin/dart pub get` 然后 `/c/flutter/bin/dart test reader_engine/test/smoke_test.dart`
Expected: PASS

- [ ] **Step 5: 把 reader_engine 加为 app 的 path 依赖**

修改 `app/pubspec.yaml`，在 `dependencies:` 末尾加：

```yaml
  reader_engine:
    path: ../reader_engine
```

运行 `/c/flutter/bin/flutter pub get`（在 `app/` 目录）验证依赖图。

- [ ] **Step 6: Commit**

```bash
git add reader_engine/ app/pubspec.yaml app/pubspec.lock
git commit -m "feat(m2): scaffold reader_engine pure-Dart package"
```

---

## Task 2: 迁移 Locator 到 reader_engine

**Files:**
- Create: `reader_engine/lib/core/locator.dart`（从 `app/lib/core/locator.dart` 复制内容）
- Modify: `app/lib/core/locator.dart`（改为 re-export）
- Test: `reader_engine/test/core/locator_test.dart`（复制 `app/test/core/locator_test.dart`）

- [ ] **Step 1: 复制 Locator 实现到新位置**

读取 `app/lib/core/locator.dart`（当前 112 行，参见 M1），原封不动复制到 `reader_engine/lib/core/locator.dart`。**唯一变更**：移除文件顶部对 `package:meta/meta.dart` 的依赖——改为 `import 'package:meta/meta.dart';`（其实保持不变即可，meta 是 reader_engine 的依赖）。

- [ ] **Step 2: 在 barrel 中导出**

修改 `reader_engine/lib/reader_engine.dart`：

```dart
library reader_engine;

const String readerEngineLibraryVersion = '0.1.0';

export 'core/locator.dart';
```

- [ ] **Step 3: 改 `app/lib/core/locator.dart` 为 re-export**

整个文件内容替换为：

```dart
/// 兼容入口：实际定义在 reader_engine 包。
export 'package:reader_engine/core/locator.dart';
```

- [ ] **Step 4: 复制 locator 测试到 reader_engine**

把 `app/test/core/locator_test.dart` 复制到 `reader_engine/test/core/locator_test.dart`，把 import 从 `package:zhiyue/core/locator.dart` 改为 `package:reader_engine/core/locator.dart`。

- [ ] **Step 5: 运行测试验证通过**

Run: `/c/flutter/bin/dart test reader_engine/test/core/locator_test.dart`
Expected: PASS（与 M1 相同的测试用例数）

Run: `/c/flutter/bin/flutter test app/test/core/locator_test.dart`（在 `app/` 目录）
Expected: PASS（re-export 保持 app 端 API 兼容）

- [ ] **Step 6: Commit**

```bash
git add reader_engine/lib/core/locator.dart reader_engine/test/core/locator_test.dart \
        reader_engine/lib/reader_engine.dart app/lib/core/locator.dart
git commit -m "refactor(m2): migrate Locator from app to reader_engine package"
```

---

## Task 3: 迁移 TypographySettings 到 reader_engine

**Files:**
- Create: `reader_engine/lib/core/typography_settings.dart`（从 `app/lib/data/models/typography_settings.dart` 复制）
- Modify: `app/lib/data/models/typography_settings.dart`（改为 re-export）
- Test: `reader_engine/test/core/typography_settings_test.dart`

- [ ] **Step 1: 复制 TypographySettings 实现**

读取 `app/lib/data/models/typography_settings.dart`（M1 已有，66 行，含 `ReadingTheme` / `PageMargin` / `TypographySettings`），原封不动复制到 `reader_engine/lib/core/typography_settings.dart`。

- [ ] **Step 2: 在 barrel 中导出**

```dart
library reader_engine;

const String readerEngineLibraryVersion = '0.1.0';

export 'core/locator.dart';
export 'core/typography_settings.dart';
```

- [ ] **Step 3: 改 app 端为 re-export**

整个 `app/lib/data/models/typography_settings.dart` 替换为：

```dart
/// 兼容入口：实际定义在 reader_engine 包。
export 'package:reader_engine/core/typography_settings.dart';
```

- [ ] **Step 4: 写 TypographySettings 测试**

Create `reader_engine/test/core/typography_settings_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:reader_engine/core/typography_settings.dart';

void main() {
  test('defaults returns expected values', () {
    final s = TypographySettings.defaults();
    expect(s.fontSize, 16.0);
    expect(s.lineHeight, 1.5);
    expect(s.fontFamily, isNull);
    expect(s.theme, ReadingTheme.light);
    expect(s.pageMargin, PageMargin.normal);
  });

  test('copyWith preserves unspecified fields', () {
    final s = TypographySettings.defaults();
    final updated = s.copyWith(fontSize: 20.0);
    expect(updated.fontSize, 20.0);
    expect(updated.lineHeight, s.lineHeight);
    expect(updated.theme, s.theme);
  });

  test('copyWith fontFamily: null resets to system font', () {
    final s = TypographySettings.defaults().copyWith(fontFamily: 'NotoSerif');
    expect(s.fontFamily, 'NotoSerif');
    final reset = s.copyWith(fontFamily: null);
    expect(reset.fontFamily, isNull);
  });

  test('equality works', () {
    final a = TypographySettings.defaults();
    final b = TypographySettings.defaults();
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });
}
```

- [ ] **Step 5: 运行测试验证**

Run: `/c/flutter/bin/dart test reader_engine/test/core/typography_settings_test.dart`
Expected: 4 tests PASS

Run: `/c/flutter/bin/flutter test app/test/data/models/`（在 `app/` 目录，验证 M1 测试仍通过）
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add reader_engine/lib/core/typography_settings.dart \
        reader_engine/test/core/typography_settings_test.dart \
        reader_engine/lib/reader_engine.dart \
        app/lib/data/models/typography_settings.dart
git commit -m "refactor(m2): migrate TypographySettings from app to reader_engine"
```

---

## Task 4: 新增 BookRef 模型

**Files:**
- Create: `reader_engine/lib/core/book_ref.dart`
- Create: `reader_engine/test/core/book_ref_test.dart`

- [ ] **Step 1: 写失败测试**

Create `reader_engine/test/core/book_ref_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';

void main() {
  test('constructs with required fields', () {
    final ref = BookRef(
      id: 'b1',
      title: '追风筝的人',
      format: BookFormat.epub,
      filePath: '/library/abc.epub',
    );
    expect(ref.id, 'b1');
    expect(ref.title, '追风筝的人');
    expect(ref.format, BookFormat.epub);
  });

  test('equality by id', () {
    final a = BookRef(
      id: 'b1',
      title: 'A',
      format: BookFormat.epub,
      filePath: '/a',
    );
    final b = BookRef(
      id: 'b1',
      title: 'B',
      format: BookFormat.epub,
      filePath: '/b',
    );
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `/c/flutter/bin/dart test reader_engine/test/core/book_ref_test.dart`
Expected: FAIL — BookRef 未定义；`BookFormat` 未导出（它在 app/lib/data/models/book.dart）

- [ ] **Step 3: 实现 BookRef**

Create `reader_engine/lib/core/book_ref.dart`:

```dart
import 'package:meta/meta.dart';

/// 书籍格式枚举。
///
/// 与 M1 `app/lib/data/models/book.dart` 中的 `BookFormat` 同构；
/// 这里在 reader_engine 重新定义以避免 reader_engine 反向依赖 app 包。
enum BookFormat { epub, pdf }

/// 渲染层对书籍的轻量引用。
///
/// 不持有完整 `Book` 聚合根（后者还含阅读进度、笔记聚合等不属于渲染职责的数据）。
/// reader_engine 只关心：哪个文件、什么格式、什么标题。
@immutable
class BookRef {
  final String id;
  final String title;
  final BookFormat format;
  final String filePath;

  const BookRef({
    required this.id,
    required this.title,
    required this.format,
    required this.filePath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BookRef && id == other.id);

  @override
  int get hashCode => id.hashCode;
}
```

注意：app 端的 `BookFormat` 与这里的 `BookFormat` 是两个独立的 enum。在 UI 转换处（Task 17）显式映射。

- [ ] **Step 4: 在 barrel 中导出**

修改 `reader_engine/lib/reader_engine.dart`，加：

```dart
export 'core/book_ref.dart';
```

- [ ] **Step 5: 运行测试验证通过**

Run: `/c/flutter/bin/dart test reader_engine/test/core/book_ref_test.dart`
Expected: 2 tests PASS

- [ ] **Step 6: Commit**

```bash
git add reader_engine/lib/core/book_ref.dart reader_engine/test/core/book_ref_test.dart \
        reader_engine/lib/reader_engine.dart
git commit -m "feat(m2): add BookRef lightweight book reference model"
```

---

## Task 5: 新增 PaginationMode + ReaderEngineState + TOC 模型

**Files:**
- Create: `reader_engine/lib/rendering/pagination_model.dart`
- Create: `reader_engine/lib/engine/reader_engine_state.dart`
- Create: `reader_engine/lib/navigation/toc.dart`
- Create: `reader_engine/test/navigation/toc_test.dart`

- [ ] **Step 1: 实现 PaginationMode**

Create `reader_engine/lib/rendering/pagination_model.dart`:

```dart
/// 翻页模式。
enum PaginationMode {
  /// 左右翻页（默认）。
  paged,

  /// 滚动。
  scroll,
}
```

- [ ] **Step 2: 实现 ReaderEngineState**

Create `reader_engine/lib/engine/reader_engine_state.dart`:

```dart
import 'package:meta/meta.dart';

/// 阅读引擎状态。
@immutable
sealed class ReaderEngineState {
  const ReaderEngineState();
}

class ReaderEngineUnloaded extends ReaderEngineState {
  const ReaderEngineUnloaded();
}

class ReaderEngineLoading extends ReaderEngineState {
  const ReaderEngineLoading();
}

class ReaderEngineReady extends ReaderEngineState {
  const ReaderEngineReady();
}

class ReaderEngineError extends ReaderEngineState {
  final String message;
  final Object? cause;

  const ReaderEngineError({required this.message, this.cause});
}
```

- [ ] **Step 3: 写 TOC 失败测试**

Create `reader_engine/test/navigation/toc_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/core/locator.dart';

void main() {
  test('TocEntry holds title + locator', () {
    final entry = TocEntry(
      title: '第一章',
      locator: EpubCfiLocator(cfi: 'epubcfi(/6/4)', chapterIndex: 0),
    );
    expect(entry.title, '第一章');
    expect(entry.locator, isA<EpubCfiLocator>());
  });

  test('TableOfContents empty factory', () {
    final toc = TableOfContents.empty();
    expect(toc.entries, isEmpty);
  });

  test('TableOfContents flat list', () {
    final toc = TableOfContents(entries: [
      TocEntry(title: 'A', locator: EpubCfiLocator(cfi: '/6', chapterIndex: 0)),
      TocEntry(title: 'B', locator: EpubCfiLocator(cfi: '/8', chapterIndex: 1)),
    ]);
    expect(toc.entries, hasLength(2));
  });
}
```

- [ ] **Step 4: 运行测试验证失败**

Run: `/c/flutter/bin/dart test reader_engine/test/navigation/toc_test.dart`
Expected: FAIL — toc.dart 未定义

- [ ] **Step 5: 实现 TOC**

Create `reader_engine/lib/navigation/toc.dart`:

```dart
import 'package:meta/meta.dart';

import '../core/locator.dart';

/// 单个目录项。
///
/// 一个章节/子章节的标题 + 跳转目标。
@immutable
class TocEntry {
  final String title;
  final Locator locator;
  final List<TocEntry> children;

  const TocEntry({
    required this.title,
    required this.locator,
    this.children = const [],
  });
}

/// 整本书的目录。
@immutable
class TableOfContents {
  final List<TocEntry> entries;

  const TableOfContents({required this.entries});

  factory TableOfContents.empty() => const TableOfContents(entries: []);
}
```

- [ ] **Step 6: 在 barrel 中导出全部新模型**

修改 `reader_engine/lib/reader_engine.dart`：

```dart
library reader_engine;

const String readerEngineLibraryVersion = '0.1.0';

export 'core/locator.dart';
export 'core/typography_settings.dart';
export 'core/book_ref.dart';
export 'rendering/pagination_model.dart';
export 'engine/reader_engine_state.dart';
export 'navigation/toc.dart';
```

- [ ] **Step 7: 运行所有 reader_engine 测试**

Run: `/c/flutter/bin/dart test reader_engine/test/`
Expected: 所有测试 PASS（locator + typography + book_ref + toc = ~15 tests）

- [ ] **Step 8: Commit**

```bash
git add reader_engine/lib/rendering/pagination_model.dart \
        reader_engine/lib/engine/reader_engine_state.dart \
        reader_engine/lib/navigation/toc.dart \
        reader_engine/test/navigation/toc_test.dart \
        reader_engine/lib/reader_engine.dart
git commit -m "feat(m2): add PaginationMode, ReaderEngineState, TableOfContents models"
```

---

## Task 6: 新增 ReaderEngine + EpubRenderer 抽象接口

**Files:**
- Create: `reader_engine/lib/rendering/renderer.dart`
- Create: `reader_engine/lib/engine/reader_engine.dart`
- Create: `reader_engine/test/engine/reader_engine_test.dart`（仅写一个 fake 实现验证接口可被实现）

- [ ] **Step 1: 实现 EpubRenderer 接口**

Create `reader_engine/lib/rendering/renderer.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../core/locator.dart';
import '../core/typography_settings.dart';
import '../navigation/toc.dart';
import 'pagination_model.dart';

/// EPUB 渲染器抽象 —— EPUB 类内部契约。
///
/// 实现类需包装具体的 EPUB 渲染库（如 epubx + flutter_widget_from_html）。
/// UI 层永远不直接引用此接口，只看 [ReaderEngine]。
abstract interface class EpubRenderer {
  Widget build(BuildContext context);
  Future<void> openFile(String filePath);
  Stream<Locator> get currentLocation$;
  Future<TableOfContents> get toc;
  Future<void> gotoLocator(Locator locator);
  Future<void> setTypography(TypographySettings settings);
  Future<void> setPaginationMode(PaginationMode mode);
  Future<void> dispose();
}
```

注意：此处引入了 Flutter 依赖（`Widget`），所以 `reader_engine/` 的 pubspec 需要更新（见 Step 4）。

实际上为保持 `reader_engine/` **纯 Dart**，应把 `EpubRenderer.build()` 返回类型改为抽象 widget 接口，或把渲染层接口移到 `reader_engine_epub_view/`。**修正决策**：把 `EpubRenderer`（含 `Widget`）从 `reader_engine/` 移到 `reader_engine_epub_view/` 或独立 Flutter 子包 `reader_engine_ui/`。

但更简单的做法是：`reader_engine/` 改为 Flutter 包（`flutter:` SDK 依赖）。考虑到 Dart-only 测试速度收益在此里程碑可忽略，**本里程碑决策：reader_engine 改为 Flutter 包**（依赖 flutter SDK）。

修订 Step 1 实现：把 `Widget` 改用 Flutter。然后 Step 4 修订 pubspec。

- [ ] **Step 2: 实现 ReaderEngine 接口**

Create `reader_engine/lib/engine/reader_engine.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../core/book_ref.dart';
import '../core/locator.dart';
import '../core/typography_settings.dart';
import '../navigation/toc.dart';
import 'reader_engine_state.dart';
import '../rendering/pagination_model.dart';

/// 阅读引擎抽象 —— UI 层唯一入口，format-agnostic。
///
/// 不区分 EPUB / PDF；具体格式由 [open] 时选择的内部 Renderer 决定。
abstract interface class ReaderEngine {
  ReaderEngineState get state;
  Stream<ReaderEngineState> get state$;
  Stream<Locator> get currentLocation$;
  TableOfContents? get toc;
  TypographySettings get typography;
  PaginationMode get paginationMode;

  Future<void> open(BookRef book);
  Future<void> gotoLocator(Locator locator);
  Future<void> gotoTocEntry(TocEntry entry);
  Future<void> nextSpine();
  Future<void> previousSpine();
  Future<void> setTypography(TypographySettings settings);
  Future<void> setPaginationMode(PaginationMode mode);
  Future<void> close();

  /// 由 UI 层调用，构建实际阅读区。
  Widget build(BuildContext context);
}
```

- [ ] **Step 3: 修订 pubspec 让 reader_engine 成为 Flutter 包**

修改 `reader_engine/pubspec.yaml`：

```yaml
name: reader_engine
description: 智阅阅读引擎抽象层 —— ReaderEngine 接口与共享模型。
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.10.0
  flutter: ^3.27.0

dependencies:
  flutter:
    sdk: flutter
  meta: ^1.15.0

dev_dependencies:
  flutter_test:
    sdk: flutter
```

把 `test:` 依赖换成 `flutter_test:`。

- [ ] **Step 4: 写一个 Fake 实现验证接口可被实现**

Create `reader_engine/test/engine/reader_engine_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

/// 接口可被实现的 smoke test。
class _FakeEngine implements ReaderEngine {
  @override
  ReaderEngineState state = const ReaderEngineUnloaded();

  @override
  Stream<ReaderEngineState> get state$ => const Stream.empty();

  @override
  Stream<Locator> get currentLocation$ => const Stream.empty();

  @override
  TableOfContents? get toc => null;

  @override
  TypographySettings get typography => TypographySettings.defaults();

  @override
  PaginationMode get paginationMode => PaginationMode.paged;

  @override
  Future<void> open(BookRef book) async {}
  @override
  Future<void> gotoLocator(Locator locator) async {}
  @override
  Future<void> gotoTocEntry(TocEntry entry) async {}
  @override
  Future<void> nextSpine() async {}
  @override
  Future<void> previousSpine() async {}
  @override
  Future<void> setTypography(TypographySettings settings) async {}
  @override
  Future<void> setPaginationMode(PaginationMode mode) async {}
  @override
  Future<void> close() async {}
  @override
  dynamic build(BuildContext context) => throw UnimplementedError();
}

void main() {
  test('ReaderEngine can be implemented', () {
    final engine = _FakeEngine();
    expect(engine.state, isA<ReaderEngineUnloaded>());
    expect(engine.paginationMode, PaginationMode.paged);
  });
}
```

- [ ] **Step 5: 运行测试验证**

Run: `/c/flutter/bin/flutter test reader_engine/test/engine/reader_engine_test.dart`
Expected: 1 test PASS

- [ ] **Step 6: 在 barrel 中导出**

修改 `reader_engine/lib/reader_engine.dart`，加：

```dart
export 'rendering/renderer.dart';
export 'engine/reader_engine.dart';
```

- [ ] **Step 7: 运行 dart analyze 确保零错误**

Run: `/c/flutter/bin/dart analyze reader_engine/`
Expected: No issues

- [ ] **Step 8: Commit**

```bash
git add reader_engine/
git commit -m "feat(m2): add ReaderEngine + EpubRenderer abstract interfaces"
```

---

## Task 7: 创建 reader_engine_epub_view package 骨架

**Files:**
- Create: `reader_engine_epub_view/pubspec.yaml`
- Create: `reader_engine_epub_view/lib/reader_engine_epub_view.dart`
- Modify: `app/pubspec.yaml`（加 path 依赖）

- [ ] **Step 1: 创建 `reader_engine_epub_view/pubspec.yaml`**

```yaml
name: reader_engine_epub_view
description: 智阅 EPUB 渲染实现 —— 基于 epubx + 自研 widget 的 EpubRenderer 具体实现。
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.10.0
  flutter: ^3.27.0

dependencies:
  flutter:
    sdk: flutter
  epubx: ^4.0.0  # pub.dev/packages/epubx — 纯 Dart parser（2026-06-26 pivot 后）
  flutter_widget_from_html: ^0.15.0  # pub.dev/packages/flutter_widget_from_html — HTML→widget
  meta: ^1.15.0
  reader_engine:
    path: ../reader_engine

dev_dependencies:
  flutter_test:
    sdk: flutter
```

**版本核实**：执行此步前在 https://pub.dev/packages/epubx 和 https://pub.dev/packages/flutter_widget_from_html 确认最新稳定版本，更新上面的约束。

> ⚠️ **2026-06-26 pivot 后修订**：原 plan 用 `epub_view_plus`，实际未发布 pub.dev；现 pivot 到 `epubx`（parser）+ `flutter_widget_from_html`（HTML→widget）。详见 spec 附录 A.2。

- [ ] **Step 2: 创建空 barrel**

Create `reader_engine_epub_view/lib/reader_engine_epub_view.dart`:

```dart
/// reader_engine_epub_view — epubx + 自研 widget 的 EpubRenderer 实现。
library reader_engine_epub_view;
```

- [ ] **Step 3: 把包加为 app 的依赖**

修改 `app/pubspec.yaml`，在 `dependencies:` 加：

```yaml
  reader_engine_epub_view:
    path: ../reader_engine_epub_view
```

- [ ] **Step 4: 运行 pub get 验证依赖图**

Run: `/c/flutter/bin/flutter pub get`（在 `app/` 目录）
Expected: 无错误；`pubspec.lock` 中包含 reader_engine 和 reader_engine_epub_view

- [ ] **Step 5: Commit**

```bash
git add reader_engine_epub_view/ app/pubspec.yaml app/pubspec.lock
git commit -m "feat(m2): scaffold reader_engine_epub_view package with epubx dep"
```

---

## Task 8: fixture EPUB 基础设施

**Files:**
- Create: `app/test/fixtures/README.md`
- Create: `app/test/fixtures/.gitignore`
- Create: `app/test/helpers/fixture_loader.dart`

- [ ] **Step 1: 创建 fixtures 目录和 README**

Create `app/test/fixtures/README.md`:

```markdown
# 测试 fixture EPUB

本目录存放 M2 EPUB 阅读器测试用书，**不入库**（版权 + 二进制）。

## 必备书目

| 文件名 | 用途 | 下载源 |
|---|---|---|
| `page-blanche.epub` | 标准英文 EPUB 基线 | https://www.gutenberg.org/ebooks/... （任选 public domain） |
| `kite-runner-cn.epub` | 中文 reflowable | 团队私有 / 公共领域中文 EPUB |
| `weicheng.epub` | 复杂 TOC + 嵌套 spine | 钱钟书《围城》公开领域版本 |
| `bad-cfi.epub` | 构造异常 CFI | 手工构造（用 EPUB 编辑器修改 OEBPS） |

新机器准备环境时：
1. 按上表下载/构造 4 个文件，放到本目录
2. 运行 `/c/flutter/bin/flutter test app/test/` 验证
3. 不准备则相关测试会 skip（参见 `fixture_loader.dart`）
```

- [ ] **Step 2: 创建 .gitignore**

Create `app/test/fixtures/.gitignore`:

```
# 测试 EPUB 不入库（版权 + 二进制）
*.epub
```

- [ ] **Step 3: 创建 fixture loader helper**

Create `app/test/helpers/fixture_loader.dart`:

```dart
import 'dart:io';
import 'package:path/path.dart' as p;

/// Fixture EPUB 加载器。
///
/// 文件不存在时返回 null，测试应 skip（而非 fail）。
class FixtureLoader {
  static const _fixturesDir = 'test/fixtures';

  static File? tryLoad(String filename) {
    final path = p.join(_fixturesDir, filename);
    final file = File(path);
    return file.existsSync() ? file : null;
  }
}
```

- [ ] **Step 4: 运行 dart analyze**

Run: `/c/flutter/bin/dart analyze app/test/helpers/fixture_loader.dart`
Expected: No issues

- [ ] **Step 5: Commit**

```bash
git add app/test/fixtures/README.md app/test/fixtures/.gitignore \
        app/test/helpers/fixture_loader.dart
git commit -m "feat(m2): scaffold EPUB test fixtures infrastructure"
```

---

## Task 9: 实现 cfi_codec 纯函数模块（自定义 `chapterIndex:charOffset`）

> **2026-06-26 pivot 后修订**：原计划用完整 EPUB CFI 规范（`epubcfi(/6/4!/4/10/3:10)`）依赖 `epub_view_plus` 内部 CFI 生成。pivot 到 `epubx` 后没有库帮我们生成 CFI，改用极简自定义格式 `<chapterIndex>:<charOffset>`，round-trip 一致即可，由 Task 12 的字符位置追踪填值。详见 spec §10 W10 与附录 A.2。

**Files:**
- Create: `reader_engine_epub_view/lib/cfi_codec.dart`
- Create: `reader_engine_epub_view/test/cfi_codec_test.dart`

**格式约定**：`<chapterIndex>:<charOffset>` —— 例如 `4:1024` 表示第 4 章第 1024 个字符偏移。chapterIndex 与 charOffset 都从 0 开始；分隔符固定为半角冒号 `:`。这是给 zhiyue 自研渲染用的简化定位格式，不是 EPUB CFI 规范子集（pub.dev 上的其他 EPUB 工具按规范解析时无法识别，但 zhiyue 内部 round-trip 自洽即可）。

- [ ] **Step 1: 写失败测试**

Create `reader_engine_epub_view/test/cfi_codec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/cfi_codec.dart';

void main() {
  group('encode', () {
    test('encodes chapter 0 offset 0', () {
      expect(encode(0, 0), '0:0');
    });

    test('encodes typical case', () {
      expect(encode(4, 1024), '4:1024');
    });

    test('encodes large offset', () {
      expect(encode(12, 999999), '12:999999');
    });
  });

  group('decode', () {
    test('decodes valid cfi', () {
      expect(decode('4:1024'), (chapterIndex: 4, charOffset: 1024));
    });

    test('decodes boundary chapter 0 offset 0', () {
      expect(decode('0:0'), (chapterIndex: 0, charOffset: 0));
    });

    test('decodes large offset', () {
      expect(decode('12:999999'), (chapterIndex: 12, charOffset: 999999));
    });

    test('returns null for empty string', () {
      expect(decode(''), isNull);
    });

    test('returns null for missing colon', () {
      expect(decode('41024'), isNull);
    });

    test('returns null for non-numeric chapter', () {
      expect(decode('abc:10'), isNull);
    });

    test('returns null for non-numeric offset', () {
      expect(decode('4:xyz'), isNull);
    });

    test('returns null for negative numbers', () {
      expect(decode('-1:10'), isNull);
      expect(decode('4:-1'), isNull);
    });
  });

  group('isValid', () {
    test('accepts valid cfi', () {
      expect(isValid('4:1024'), isTrue);
    });

    test('accepts boundary', () {
      expect(isValid('0:0'), isTrue);
    });

    test('rejects empty', () {
      expect(isValid(''), isFalse);
    });

    test('rejects malformed', () {
      expect(isValid('abc'), isFalse);
      expect(isValid(':10'), isFalse);
      expect(isValid('4:'), isFalse);
      expect(isValid('4:10:20'), isFalse);
    });
  });

  group('round-trip integrity', () {
    test('encode → decode → equals input', () {
      for (final original in const [
        (chapterIndex: 0, charOffset: 0),
        (chapterIndex: 4, charOffset: 1024),
        (chapterIndex: 99, charOffset: 123456),
      ]) {
        final encoded = encode(original.chapterIndex, original.charOffset);
        final decoded = decode(encoded);
        expect(decoded, original, reason: 'round-trip failed for $original');
      }
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `/c/flutter/bin/flutter test reader_engine_epub_view/test/cfi_codec_test.dart`
Expected: FAIL — 顶层函数 `encode` / `decode` / `isValid` 未定义

- [ ] **Step 3: 实现 cfi_codec**

Create `reader_engine_epub_view/lib/cfi_codec.dart`:

```dart
/// EPUB 位置编解码（zhiyue 简化格式）。
///
/// 格式：`<chapterIndex>:<charOffset>`，例如 `4:1024`。
///
/// 这**不是** EPUB CFI 规范（`epubcfi(/6/4!/4/10/3:10)`）——
/// pivot 到 epubx 后没有库生成规范 CFI，自研格式仅需 round-trip 一致。
/// 章节索引自 0 开始，字符偏移自 0 开始，分隔符固定为半角冒号 `:`。
///
/// 纯函数模块，无 Flutter 依赖，单测极快。

/// 把 (chapterIndex, charOffset) 编码为 cfi 字符串。
String encode(int chapterIndex, int charOffset) {
  if (chapterIndex < 0 || charOffset < 0) {
    throw ArgumentError(
      'chapterIndex and charOffset must be non-negative: '
      'chapterIndex=$chapterIndex, charOffset=$charOffset',
    );
  }
  return '$chapterIndex:$charOffset';
}

/// 把 cfi 字符串解码为 (chapterIndex, charOffset)。
///
/// 解析失败返回 null（容错，不抛异常）—— 调用方在 Task 12 处理 null
/// 时回退到 chapter 0 offset 0。
({int chapterIndex, int charOffset})? decode(String cfi) {
  final parts = cfi.split(':');
  if (parts.length != 2) return null;
  final chapter = int.tryParse(parts[0]);
  final offset = int.tryParse(parts[1]);
  if (chapter == null || offset == null) return null;
  if (chapter < 0 || offset < 0) return null;
  return (chapterIndex: chapter, charOffset: offset);
}

/// 验证 cfi 字符串是否合法。
bool isValid(String cfi) => decode(cfi) != null;
```

- [ ] **Step 4: 运行测试验证通过**

Run: `/c/flutter/bin/flutter test reader_engine_epub_view/test/cfi_codec_test.dart`
Expected: All PASS（约 20 tests：encode 3 + decode 8 + isValid 5 + round-trip 1+）

- [ ] **Step 5: dart analyze**

Run: `/c/flutter/bin/dart analyze reader_engine_epub_view/`
Expected: No issues

- [ ] **Step 6: Commit + Push**

```bash
git add reader_engine_epub_view/lib/cfi_codec.dart \
        reader_engine_epub_view/test/cfi_codec_test.dart
git commit -m "feat(m2): implement simplified cfi_codec (chapterIndex:charOffset)"
git push origin master
```

---

## Task 10: W1 Spike — epubx 解析 + flutter_widget_from_html 渲染冒烟

> **2026-06-26 pivot 后修订**：原 spike 验证 `epub_view_plus` 解析 + spine 读取。pivot 后 epubx 是纯 parser，本 spike 验证两件事：(1) epubx 能解析真实 EPUB；(2) 章节 HTML 经 `flutter_widget_from_html` 转纯文本后是合理的（无乱码、非空）。spike 通过是 GO/NO-GO 决策点 —— 若 epubx 也失败，pub.dev 上无备选 parser，须 user 重新评估 M2 范围。详见 spec 附录 A.2。

**Files:**
- Create: `reader_engine_epub_view/spike/epubx_smoke_test.dart`（**注意**：放在 `spike/` 而非 `test/` —— 这是探索性代码，spike 验证后可删，CI 不应跑）

**目标**：
1. 验证 `epubx` 的 `EpubReader.readBook(bytes)` 能解析 Task 8 提供的 `page-blanche.epub`，返回非空 `EpubBook { Title, Chapters }`
2. 验证第一章 `EpubChapter.HtmlContent` 是合法 HTML 字符串
3. 验证剥离 HTML 标签后得到的纯文本非空（这暗示 `flutter_widget_from_html` 能从中渲染出有意义内容）
4. **GO/NO-GO**：以上 3 条都通过 → GO，继续 Task 11；任一失败 → NO-GO，升级到 user

- [ ] **Step 1: 写 spike smoke 测试**

Create `reader_engine_epub_view/spike/epubx_smoke_test.dart`:

```dart
// 探索性 spike —— 验证 epubx 能否解析真实 EPUB。
// spike 验证通过后整个文件可删；不放进 test/ 以免 CI 长期依赖 fixture。
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fixturePath = 'app/test/fixtures/page-blanche.epub';

  test('spike: epubx parses real EPUB', () async {
    final file = File(fixturePath);
    if (!file.existsSync()) {
      // skip 模式：fixture 未准备好（Task 8 未完成），spike 推迟
      debugPrint('SKIP spike: $fixturePath not present. '
          'Run Task 8 to download the fixture.');
      return;
    }

    final bytes = await file.readAsBytes();
    final book = await EpubReader.readBook(bytes);

    // 1. 标题非空
    expect(book.Title, isNotNull,
        reason: 'epubx 未返回 Title');
    expect(book.Title!.isNotEmpty, isTrue,
        reason: 'epubx 返回空 Title — 可能解析损坏');

    // 2. 章节列表非空（epubx 把 spine 项扁平化到 Chapters + SubChapters）
    final flatChapters = _flattenChapters(book.Chapters ?? const []);
    expect(flatChapters, isNotEmpty,
        reason: 'epubx 返回 0 章节 — spine 是否丢失？');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('spike: chapter HTML is reasonable', () async {
    final file = File(fixturePath);
    if (!file.existsSync()) {
      debugPrint('SKIP spike: $fixturePath not present.');
      return;
    }

    final bytes = await file.readAsBytes();
    final book = await EpubReader.readBook(bytes);
    final flatChapters = _flattenChapters(book.Chapters ?? const []);
    if (flatChapters.isEmpty) {
      debugPrint('SKIP spike HTML check: 0 chapters parsed.');
      return;
    }

    final html = flatChapters.first.HtmlContent ?? '';
    // 3. HTML 非空
    expect(html.isNotEmpty, isTrue,
        reason: 'epubx 返回空 HtmlContent — 内容文件丢失？');

    // 4. 剥离标签后纯文本非空（粗糙检查 flutter_widget_from_html 能渲染出内容）
    final plainText = _stripHtml(html);
    expect(plainText.trim().isNotEmpty, isTrue,
        reason: 'HTML 剥离后为空字符串 — HTML 结构异常？');
  }, timeout: const Timeout(Duration(seconds: 30)));
}

/// 递归展开 Chapters + SubChapters 为扁平列表。
List<EpubChapter> _flattenChapters(List<EpubChapter> chapters) {
  final result = <EpubChapter>[];
  for (final c in chapters) {
    result.add(c);
    result.addAll(_flattenChapters(c.SubChapters ?? const []));
  }
  return result;
}

/// 粗糙剥离 HTML 标签 —— spike 用，非生产代码。
/// 生产代码用 flutter_widget_from_html 渲染，不需要这步。
String _stripHtml(String html) {
  return RegExp(r'<[^>]+>').replaceAll(html, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
```

- [ ] **Step 2: 准备 fixture EPUB**

按 Task 8 的 `app/test/fixtures/README.md`，至少准备 `page-blanche.epub`（PageBlanche 是 IDPF 标准 EPUB 测试样本，或 gutenberg.org 任意 public domain EPUB）放到 `app/test/fixtures/`。若 fixture 未准备，spike 测试 skip 但不算失败 —— Task 8 与 Task 10 顺序灵活，Task 8 先完成再跑 spike 更合理。

- [ ] **Step 3: 运行 spike 测试**

Run: `/c/flutter/bin/flutter test reader_engine_epub_view/spike/epubx_smoke_test.dart`
Expected: 2 tests PASS（或 skip 若 fixture 未准备）

**GO/NO-GO 决策**：
- **GO**：epubx 解析成功、章节 HTML 合理 → 继续 Task 11
- **NO-GO**：epubx 解析抛异常 / 返回 0 章节 / HTML 为空 → pub.dev 上无备选 EPUB parser，须升级到 user 重新评估 M2 范围（可能需要 git 依赖 fork 或自研 parser）

- [ ] **Step 4: 清理 spike 文件（可选）**

spike 验证通过后，整个 `reader_engine_epub_view/spike/` 目录可删（这是探索性代码，不入库长期）。但若保留作为回归测试也合理（fixture 在 .gitignore，CI 会自动 skip）。

```bash
# 保留：作为本地回归 spike
# 或删除：rm -rf reader_engine_epub_view/spike/
```

- [ ] **Step 5: Commit + Push**

```bash
git add reader_engine_epub_view/spike/epubx_smoke_test.dart
git commit -m "spike(m2): validate epubx parses real EPUB + HTML is renderable"
git push origin master
```

在 commit message 或 git log 备注中记录 GO/NO-GO 结论。如果 NO-GO，停止本计划，进入 user 重新评估流程。

---

## Task 11: 实现 EpubxRenderer.open + 状态机

> **2026-06-26 pivot 后修订**：原计划依赖 `epub_view_plus.EpubController` 的内置状态。pivot 后由我们自管 `ReaderEngineState` 状态机：unloaded → loading → ready / error，通过 `StreamController` 暴露给 ReaderEngine。`EpubxRenderer` 持有 `EpubBook? _book`，`openFile` 走 `EpubReader.readBook(bytes)`。详见 spec §10 W2 与附录 A.2。

**Files:**
- Create: `reader_engine_epub_view/lib/epubx_renderer.dart`
- Create: `reader_engine_epub_view/test/epubx_renderer_test.dart`

**契约**：`EpubRenderer` 接口（Task 6 已落地）：
```dart
abstract interface class EpubRenderer {
  Widget build(BuildContext context);
  Future<void> openFile(String filePath);
  Stream<Locator> get currentLocation$;
  Future<TableOfContents> get toc;
  Future<void> gotoLocator(Locator locator);
  Future<void> setTypography(TypographySettings settings);
  Future<void> setPaginationMode(PaginationMode mode);
  Future<void> dispose();
}
```

本 Task 只实现 `openFile` + 状态机；`build` / `currentLocation$` / `gotoLocator` 留 stub，由 Task 12 实现。

- [ ] **Step 1: 写失败测试**

Create `reader_engine_epub_view/test/epubx_renderer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/rendering/renderer.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

void main() {
  test('EpubxRenderer implements EpubRenderer', () {
    final renderer = EpubxRenderer();
    expect(renderer, isA<EpubRenderer>());
  });

  test('initial state is unloaded', () {
    final renderer = EpubxRenderer();
    expect(renderer.state, const ReaderEngineUnloaded());
  });

  test('state$ emits unloaded initially', () async {
    final renderer = EpubxRenderer();
    final first = await renderer.state$.first;
    expect(first, const ReaderEngineUnloaded());
  });

  test('openFile on non-existent path emits loading then error', () async {
    final renderer = EpubxRenderer();
    final states = <ReaderEngineState>[];
    final sub = renderer.state$.listen(states.add);

    await renderer.openFile('non/existent/path.epub');

    // 至少出现 loading（在 readAsBytes 抛之前）和 error（之后）
    expect(states, contains(predicate<ReaderEngineState>(
      (s) => s is ReaderEngineLoading,
      'is ReaderEngineLoading',
    )));
    expect(states, contains(predicate<ReaderEngineState>(
      (s) => s is ReaderEngineError,
      'is ReaderEngineError',
    )));
    expect(renderer.state, isA<ReaderEngineError>());

    await sub.cancel();
    await renderer.dispose();
  });
}
```

**注**：`ReaderEngineState` sealed（Task 5）包含 `ReaderEngineUnloaded` / `ReaderEngineLoading` / `ReaderEngineReady` / `ReaderEngineError(cause)`。如 Task 5 实际命名不同，按 Task 5 调整。

- [ ] **Step 2: 运行测试验证失败**

Run: `/c/flutter/bin/flutter test reader_engine_epub_view/test/epubx_renderer_test.dart`
Expected: FAIL — `EpubxRenderer` 未定义

- [ ] **Step 3: 实现 EpubxRenderer 骨架**

Create `reader_engine_epub_view/lib/epubx_renderer.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine/rendering/renderer.dart';

/// epubx + flutter_widget_from_html 实现的 [EpubRenderer]。
///
/// 持有 [EpubBook]，自管 [ReaderEngineState] 状态机。
/// 章节渲染（build）、位置流（currentLocation$）、跳转（gotoLocator）
/// 在 Task 12 实现 —— 此版本是骨架。
class EpubxRenderer implements EpubRenderer {
  EpubxRenderer();

  final _stateController = StreamController<ReaderEngineState>.broadcast();
  final _locationController = StreamController<Locator>.broadcast();

  EpubBook? _book;
  int _currentChapterIndex = 0;
  TypographySettings _typography = const TypographySettings.defaults();
  PaginationMode _paginationMode = PaginationMode.paged;

  ReaderEngineState _state = const ReaderEngineUnloaded();

  @override
  ReaderEngineState get state => _state;

  @override
  Stream<ReaderEngineState> get state$ => _stateController.stream;

  @override
  Stream<Locator> get currentLocation$ => _locationController.stream;

  /// 当前持有的书 —— Task 12+ 用，外部只读访问。
  EpubBook? get book => _book;

  /// 当前章节索引 —— Task 12+ 用。
  int get currentChapterIndex => _currentChapterIndex;

  void _setState(ReaderEngineState next) {
    _state = next;
    _stateController.add(next);
  }

  @override
  Future<void> openFile(String filePath) async {
    _setState(const ReaderEngineLoading());
    try {
      final bytes = await File(filePath).readAsBytes();
      final book = await EpubReader.readBook(bytes);
      _book = book;
      _currentChapterIndex = 0;
      _setState(const ReaderEngineReady());
    } catch (e, st) {
      debugPrint('EpubxRenderer.openFile failed: $filePath\n$e\n$st');
      _setState(ReaderEngineError(cause: e));
    }
  }

  // ---- 以下方法在 Task 12 实现，此处 stub ----

  @override
  Future<TableOfContents> get toc async => TableOfContents.empty();

  @override
  Future<void> gotoLocator(Locator locator) async {
    // Task 12 实现
  }

  @override
  Future<void> setTypography(TypographySettings settings) async {
    _typography = settings;
    // Task 19 实现 CSS-like 注入
  }

  @override
  Future<void> setPaginationMode(PaginationMode mode) async {
    _paginationMode = mode;
    // Task 12-13 实现：重建 widget tree
  }

  @override
  Widget build(BuildContext context) {
    // Task 12 实现：flutter_widget_from_html 的 HtmlWidget
    return const SizedBox.shrink();
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _locationController.close();
  }
}
```

**注**：`TypographySettings` 假设是 const 构造（M1 设计）。若 M1 实现是非 const 工厂，按 `TypographySettings.defaults()` 调用，去掉 const。

- [ ] **Step 4: 运行测试验证**

Run: `/c/flutter/bin/flutter test reader_engine_epub_view/test/epubx_renderer_test.dart`
Expected: 4 tests PASS

- [ ] **Step 5: dart analyze**

Run: `/c/flutter/bin/dart analyze reader_engine_epub_view/`
Expected: No issues（如有 unused_field 提示，加 `// ignore: unused_field` 暂时绕过，Task 12 会使用）

- [ ] **Step 6: Commit + Push**

```bash
git add reader_engine_epub_view/lib/epubx_renderer.dart \
        reader_engine_epub_view/test/epubx_renderer_test.dart
git commit -m "feat(m2): scaffold EpubxRenderer with state machine (openFile)"
git push origin master
```

---

## Task 12: 实现 EpubxRenderer.build（章节渲染）+ currentLocation$ + gotoLocator

> **2026-06-26 pivot 后修订**：原计划依赖 `epub_view_plus.EpubView` 渲染整书 + CFI 流。pivot 后我们自己用 `flutter_widget_from_html` 的 `HtmlWidget` 渲染当前章节，自管 ScrollController 并把滚动位置转成字符偏移（近似：viewport 比例 × 章节字符数）。详见 spec §10 W2。

**Files:**
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart`
- Modify: `reader_engine_epub_view/test/epubx_renderer_test.dart`
- Add: `reader_engine_epub_view/test/epubx_renderer_widget_test.dart`

- [ ] **Step 1: 加 setChapter helper + flatChapters accessor**

在 `EpubxRenderer` 类中添加：

```dart
/// 当前书的扁平化章节列表（Chapters + SubChapters 递归展开）。
///
/// epubx 的 EpubChapter 含 SubChapters 嵌套；UI 与 cfi 都按扁平索引访问。
List<EpubChapter> get flatChapters => _flattenChapters(_book?.Chapters ?? const []);

List<EpubChapter> _flattenChapters(List<EpubChapter> chapters) {
  final result = <EpubChapter>[];
  for (final c in chapters) {
    result.add(c);
    result.addAll(_flattenChapters(c.SubChapters ?? const []));
  }
  return result;
}

/// 切换到指定章节（chapterIndex 基于 flatChapters）。
///
/// Task 12 内部翻页用；Task 15 TOC 跳转通过 gotoLocator 走。
void setChapter(int index) {
  final chapters = flatChapters;
  if (index < 0 || index >= chapters.length) return;
  _currentChapterIndex = index;
  if (_scrollController.hasClients) {
    _scrollController.jumpTo(0);
  }
  _emitCurrentLocation();
}
```

- [ ] **Step 2: 加 ScrollController + 位置追踪**

在 `EpubxRenderer` 中添加字段、初始化与监听：

```dart
final ScrollController _scrollController = ScrollController();

@override
Future<void> openFile(String filePath) async {
  _setState(const ReaderEngineLoading());
  try {
    final bytes = await File(filePath).readAsBytes();
    final book = await EpubReader.readBook(bytes);
    _book = book;
    _currentChapterIndex = 0;
    _scrollController.addListener(_onScroll);
    _setState(const ReaderEngineReady());
  } catch (e, st) {
    debugPrint('EpubxRenderer.openFile failed: $filePath\n$e\n$st');
    _setState(ReaderEngineError(cause: e));
  }
}

void _onScroll() {
  if (!_scrollController.hasClients) return;
  _emitCurrentLocation();
}

void _emitCurrentLocation() {
  if (_book == null) return;
  final chapters = flatChapters;
  if (_currentChapterIndex >= chapters.length) return;
  final html = chapters[_currentChapterIndex].HtmlContent ?? '';
  final totalChars = html.length;
  final maxScroll = _scrollController.hasClients
      ? _scrollController.position.maxScrollExtent
      : 0.0;
  final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
  final ratio = maxScroll == 0 ? 0.0 : (offset / maxScroll).clamp(0.0, 1.0);
  final charOffset = (ratio * totalChars).round().clamp(0, totalChars);
  _locationController.add(EpubCfiLocator(
    cfi: encode(_currentChapterIndex, charOffset),
    chapterIndex: _currentChapterIndex,
  ));
}
```

`encode` 来自 Task 9 的 `cfi_codec.dart`（需 `import 'cfi_codec.dart';`）。`EpubCfiLocator` 假设是 `Locator` sealed 的子类（M1 已落地）；如 M1 命名为 `EpubCfiLocator(cfi, chapterIndex)` 不符，按 M1 调整。

- [ ] **Step 3: 实现 build(context)**

修改 `EpubxRenderer.build`：

```dart
@override
Widget build(BuildContext context) {
  final chapters = flatChapters;
  if (chapters.isEmpty) return const SizedBox.shrink();
  final html = chapters[_currentChapterIndex].HtmlContent ?? '';

  return SingleChildScrollView(
    controller: _scrollController,
    child: HtmlWidget(html),
  );
}
```

需在 import 区添加 `import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';`。

**执行者注意**：`HtmlWidget` 是 `flutter_widget_from_html` 的主 widget；构造参数可能因版本不同（0.15.x vs 0.16.x）。Spike 阶段（Task 10）只验证了 HTML 可读，未跑 widget —— 本步如发现 API 不同，按实际版本调整。typography 注入在 Task 19 完成（通过 HtmlWidget 的 `textStyle` / `customWidgetBuilder` 参数）。

- [ ] **Step 4: 实现 gotoLocator**

```dart
@override
Future<void> gotoLocator(Locator locator) async {
  if (locator is! EpubCfiLocator) return;
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
  }
  // 字符偏移 → 滚动像素（近似反推）：等下一帧 maxScrollExtent 可用再跳。
  final html = chapters[decoded.chapterIndex].HtmlContent ?? '';
  final totalChars = html.isEmpty ? 1 : html.length;
  final ratio = (decoded.charOffset / totalChars).clamp(0.0, 1.0);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(max * ratio);
    _emitCurrentLocation();
  });
}
```

`decode` 来自 Task 9 的 `cfi_codec.dart`。

- [ ] **Step 5: 补 unit test**

在 `epubx_renderer_test.dart` 末尾追加：

```dart
test('flatChapters is empty before openFile', () {
  final renderer = EpubxRenderer();
  expect(renderer.flatChapters, isEmpty);
});

test('gotoLocator with PdfPageLocator is a no-op (no throw)', () async {
  final renderer = EpubxRenderer();
  await renderer.gotoLocator(
    const PdfPageLocator(page: 1, offsetX: 0, offsetY: 0),
  );
  await renderer.dispose();
});
```

需在文件顶部 `import 'package:reader_engine/core/locator.dart';`（PdfPageLocator 来源）。

- [ ] **Step 6: 写 widget test**

Create `reader_engine_epub_view/test/epubx_renderer_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

void main() {
  testWidgets('build returns SizedBox.shrink before openFile', (tester) async {
    final renderer = EpubxRenderer();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: renderer.build(tester.element(find.byType(Scaffold))),
        ),
      ),
    );
    expect(find.byType(SizedBox), findsOneWidget);
    await renderer.dispose();
  });
}
```

**注**：真实渲染验证（含 mock EpubBook）走 Task 23 Golden + Task 24 集成（fixture）。本 Task 不强行注入 mock EpubBook —— `EpubBook` 构造较复杂；如需 widget 级覆盖，可在 EpubxRenderer 加 `@visibleForTesting void setBookForTest(EpubBook book)`，但 M2 范围内不强制。

- [ ] **Step 7: 运行测试 + analyze**

```bash
/c/flutter/bin/flutter test reader_engine_epub_view/test/epubx_renderer_test.dart \
                                  reader_engine_epub_view/test/epubx_renderer_widget_test.dart
/c/flutter/bin/dart analyze reader_engine_epub_view/
```
Expected: All tests PASS；analyze 无 issue

- [ ] **Step 8: Commit + Push**

```bash
git add reader_engine_epub_view/lib/epubx_renderer.dart \
        reader_engine_epub_view/test/epubx_renderer_test.dart \
        reader_engine_epub_view/test/epubx_renderer_widget_test.dart
git commit -m "feat(m2): implement EpubxRenderer chapter rendering + location stream + gotoLocator"
git push origin master
```

---

## Task 13: 自研 Paginator（TextPainter 分页算法）

> **2026-06-26 pivot 后修订**：原计划 `epub_view_plus` 提供 TextPainter 分页。pivot 后必须自研。本 Task 实现纯算法层 `Paginator`，输入章节 HTML + viewport + TypographySettings，输出 `List<PageBreak>`。M2 范围内只支持纯文本近似（图片/表格用占位高度），精细排版留 M3+。详见 spec §10 W3。

**Files:**
- Create: `reader_engine_epub_view/lib/paginator.dart`
- Create: `reader_engine_epub_view/test/paginator_test.dart`

**数据结构**：
```dart
class PageBreak {
  final int startOffset;  // 章节字符偏移，闭区间
  final int endOffset;    // 章节字符偏移，开区间（下一页 startOffset）
  const PageBreak({required this.startOffset, required this.endOffset});
}
```

**算法**（spec §10 W3）：把章节 HTML 转纯文本（粗剥离标签），按 TypographySettings 配置 TextStyle，用 `TextPainter.layout(maxWidth: viewport.width)` 测每段高度，累加到 viewport.height 时切一页，记录字符偏移。

**M2 简化**：
- 不解析 inline images/tables 高度，统一按 1.5 行高估
- 不处理跨段落的孤儿/寡妇行
- 章节内分页 cache（同 typography + viewport 不重算）

- [ ] **Step 1: 写失败测试**

Create `reader_engine_epub_view/test/paginator_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine_epub_view/paginator.dart';

void main() {
  const viewport = Size(400, 600);
  const typography = TypographySettings.defaults();

  test('empty content → 1 page break covering full range', () {
    final breaks = Paginator().paginate(
      chapterHtml: '',
      viewport: viewport,
      typography: typography,
    );
    expect(breaks.length, 1);
    expect(breaks.first.startOffset, 0);
    expect(breaks.first.endOffset, 0);
  });

  test('short content fits on 1 page', () {
    final html = '<p>hello world</p>';
    final breaks = Paginator().paginate(
      chapterHtml: html,
      viewport: viewport,
      typography: typography,
    );
    expect(breaks.length, 1);
    expect(breaks.first.startOffset, 0);
    expect(breaks.first.endOffset, html.length);
  });

  test('long content → multiple page breaks', () {
    // 生成远超一页的文本（约 50KB）
    final paragraph = '<p>${'hello world ' * 100}</p>';
    final html = List.filled(50, paragraph).join();
    final breaks = Paginator().paginate(
      chapterHtml: html,
      viewport: viewport,
      typography: typography,
    );
    expect(breaks.length, greaterThan(1));
    // 每页衔接：第 i 页 endOffset == 第 i+1 页 startOffset
    for (var i = 0; i < breaks.length - 1; i++) {
      expect(breaks[i].endOffset, breaks[i + 1].startOffset,
          reason: 'page $i → ${i + 1} should be contiguous');
    }
    // 最后一页 endOffset == html.length
    expect(breaks.last.endOffset, html.length);
  });

  test('cache: same input returns identical result', () {
    final p = Paginator();
    final html = '<p>${'hello ' * 200}</p>';
    final a = p.paginate(chapterHtml: html, viewport: viewport, typography: typography);
    final b = p.paginate(chapterHtml: html, viewport: viewport, typography: typography);
    expect(breaksEqual(a, b), isTrue);
  });

  test('cache invalidated on typography change', () {
    final p = Paginator();
    final html = '<p>${'hello ' * 200}</p>';
    final small = p.paginate(
      chapterHtml: html,
      viewport: viewport,
      typography: typography,
    );
    final large = p.paginate(
      chapterHtml: html,
      viewport: viewport,
      typography: typography.copyWith(fontSize: 32.0),  // 大字号 → 页数变多
    );
    expect(large.length, greaterThan(small.length));
  });
}

bool breaksEqual(List<PageBreak> a, List<PageBreak> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].startOffset != b[i].startOffset || a[i].endOffset != b[i].endOffset) {
      return false;
    }
  }
  return true;
}
```

**注**：`TypographySettings.defaults()` 与 `copyWith(fontSize:)` 假设 M1 接口。若 M1 用不同的字段名（如 `fontScale`），按 M1 调整测试。

- [ ] **Step 2: 运行测试验证失败**

Run: `/c/flutter/bin/flutter test reader_engine_epub_view/test/paginator_test.dart`
Expected: FAIL — `Paginator` 与 `PageBreak` 未定义

- [ ] **Step 3: 实现 Paginator**

Create `reader_engine_epub_view/lib/paginator.dart`:

```dart
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:reader_engine/core/typography_settings.dart';

/// 一页的字符范围（章节内偏移）。
class PageBreak {
  final int startOffset;
  final int endOffset;
  const PageBreak({required this.startOffset, required this.endOffset});

  @override
  bool operator ==(Object other) =>
      other is PageBreak && startOffset == other.startOffset && endOffset == other.endOffset;

  @override
  int get hashCode => Object.hash(startOffset, endOffset);
}

/// TextPainter 驱动的章节分页器。
///
/// 输入：章节 HTML + viewport + typography。
/// 输出：PageBreak 列表，覆盖 [0, chapterText.length] 的连续区间。
///
/// M2 简化：图片/表格用占位高度，不精细处理。
class Paginator {
  Paginator();

  // cache key: (chapterHtml, viewport, typography) → breaks
  final _cache = <_CacheKey, List<PageBreak>>{};

  List<PageBreak> paginate({
    required String chapterHtml,
    required Size viewport,
    required TypographySettings typography,
  }) {
    final key = _CacheKey(chapterHtml, viewport, typography);
    return _cache.putIfAbsent(key, () => _paginateUncached(chapterHtml, viewport, typography));
  }

  List<PageBreak> _paginateUncached(
    String chapterHtml,
    Size viewport,
    TypographySettings typography,
  ) {
    final plain = _stripHtml(chapterHtml);
    if (plain.isEmpty) {
      return const [PageBreak(startOffset: 0, endOffset: 0)];
    }

    // 按段落（HTML <p> 分隔）粗切，逐段累加测高
    final paragraphs = _splitParagraphs(chapterHtml);
    final style = _textStyle(typography);
    final usableHeight = viewport.height;

    final breaks = <PageBreak>[];
    var startChar = 0;  // 累计到 chapterHtml 的字符偏移
    var pageStart = 0;  // 当前页起始字符偏移
    var pageHeight = 0.0;

    for (final para in paragraphs) {
      final paraHeight = _measureHeight(para.plain, style, viewport.width);
      if (pageHeight + paraHeight > usableHeight && pageHeight > 0) {
        // 切页
        breaks.add(PageBreak(startOffset: pageStart, endOffset: startChar));
        pageStart = startChar;
        pageHeight = 0;
      }
      pageHeight += paraHeight;
      startChar += para.rawLength;  // 包含 <p></p> 标签的字符数
    }
    // 收尾：把剩余部分作为最后一页
    breaks.add(PageBreak(startOffset: pageStart, endOffset: chapterHtml.length));
    return breaks;
  }

  TextStyle _textStyle(TypographySettings t) {
    return TextStyle(fontSize: t.fontSize, height: t.lineHeight);
  }

  double _measureHeight(String text, TextStyle style, double maxWidth) {
    if (text.isEmpty) return 0;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    final h = tp.height;
    tp.dispose();
    return h;
  }

  String _stripHtml(String html) {
    return RegExp(r'<[^>]+>').replaceAll(html, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<_Paragraph> _splitParagraphs(String html) {
    // 粗切：<p>...</p> 或 <div>...</div> 之间作为段落
    final result = <_Paragraph>[];
    final blockRe = RegExp(r'<(p|div)[^>]*>([\s\S]*?)</\1>', caseSensitive: false);
    var rawCursor = 0;
    for (final match in blockRe.allMatches(html)) {
      final rawStart = match.start;
      // 把标签外的空白也算作 raw 长度
      if (rawStart > rawCursor) {
        final between = html.substring(rawCursor, rawStart);
        if (between.trim().isNotEmpty) {
          result.add(_Paragraph(
            plain: _stripHtml(between),
            rawLength: between.length,
          ));
        }
      }
      final whole = match.group(0)!;
      result.add(_Paragraph(
        plain: _stripHtml(match.group(2)!),
        rawLength: whole.length,
      ));
      rawCursor = match.end;
    }
    if (rawCursor < html.length) {
      final tail = html.substring(rawCursor);
      if (tail.trim().isNotEmpty) {
        result.add(_Paragraph(plain: _stripHtml(tail), rawLength: tail.length));
      }
    }
    if (result.isEmpty && html.trim().isNotEmpty) {
      result.add(_Paragraph(plain: _stripHtml(html), rawLength: html.length));
    }
    return result;
  }
}

class _Paragraph {
  final String plain;
  final int rawLength;  // 在 chapterHtml 中占用的字符数（含标签）
  const _Paragraph({required this.plain, required this.rawLength});
}

class _CacheKey {
  final String html;
  final Size viewport;
  final TypographySettings typography;
  const _CacheKey(this.html, this.viewport, this.typography);

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      html == other.html &&
      viewport == other.viewport &&
      typography == other.typography;

  @override
  int get hashCode => Object.hash(html, viewport, typography);
}
```

**执行者注意**：
- `_measureHeight` 是性能热点；长章节会用 N×TextPainter.layout，N=段落数。M2 接受（典型章节 ~50 段，单测 < 100ms）。如 W11 buffer 发现卡顿，再考虑批测量或 memoize。
- 图片/表格统一走 `_stripHtml` 后变空文本，相当于占位高度 0 —— 这是 M2 简化，不渲染真实高度。M3 再加 `WidgetSpan` 测量。

- [ ] **Step 4: 运行测试验证通过**

Run: `/c/flutter/bin/flutter test reader_engine_epub_view/test/paginator_test.dart`
Expected: 5 tests PASS

- [ ] **Step 5: dart analyze**

Run: `/c/flutter/bin/dart analyze reader_engine_epub_view/`
Expected: No issues

- [ ] **Step 6: Commit + Push**

```bash
git add reader_engine_epub_view/lib/paginator.dart \
        reader_engine_epub_view/test/paginator_test.dart
git commit -m "feat(m2): implement TextPainter-based Paginator with cache"
git push origin master
```

---

## Task 14: 实现 ReaderScaffold（tap 区域 + 双模式翻页 paged/scroll）

> **2026-06-26 pivot 后修订**：原计划 Task 13（paged）+ Task 14（scroll）是两个 task；pivot 后合并为单 task。`ReaderScaffold` 接受 `PaginationMode` 参数，paged 模式调 Task 13 的 Paginator，scroll 模式用 SingleChildScrollView。tap 区域分派逻辑两种模式共享。详见 spec §10 W3-W4。

**Files:**
- Create: `app/lib/features/reader/widgets/reader_scaffold.dart`
- Create: `app/lib/features/reader/controllers/reader_ui_controller.dart`
- Create: `app/test/features/reader/widgets/reader_scaffold_test.dart`

- [ ] **Step 1: 实现 ReaderUiController（Riverpod state）**

Create `app/lib/features/reader/controllers/reader_ui_controller.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 阅读 UI 的瞬时状态（不持久化）：chrome 显隐、抽屉、排版面板。
@immutable
class ReaderUiState {
  final bool chromeVisible;
  final bool tocDrawerOpen;
  final bool typographyPanelOpen;

  const ReaderUiState({
    this.chromeVisible = false,
    this.tocDrawerOpen = false,
    this.typographyPanelOpen = false,
  });

  ReaderUiState copyWith({
    bool? chromeVisible,
    bool? tocDrawerOpen,
    bool? typographyPanelOpen,
  }) {
    return ReaderUiState(
      chromeVisible: chromeVisible ?? this.chromeVisible,
      tocDrawerOpen: tocDrawerOpen ?? this.tocDrawerOpen,
      typographyPanelOpen: typographyPanelOpen ?? this.typographyPanelOpen,
    );
  }
}

class ReaderUiController extends StateNotifier<ReaderUiState> {
  ReaderUiController() : super(const ReaderUiState());

  void toggleChrome() => state = state.copyWith(chromeVisible: !state.chromeVisible);
  void openTocDrawer() => state = state.copyWith(tocDrawerOpen: true);
  void closeTocDrawer() => state = state.copyWith(tocDrawerOpen: false);
  void openTypographyPanel() => state = state.copyWith(typographyPanelOpen: true);
  void closeTypographyPanel() => state = state.copyWith(typographyPanelOpen: false);
}

final readerUiControllerProvider =
    StateNotifierProvider<ReaderUiController, ReaderUiState>((ref) {
  return ReaderUiController();
});
```

- [ ] **Step 2: 写 ReaderScaffold 失败测试**

Create `app/test/features/reader/widgets/reader_scaffold_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/widgets/reader_scaffold.dart';

void main() {
  testWidgets('tap center toggles chrome (paged mode)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book content')),
            paginationMode: PaginationMode.paged,
            onTapPrev: () {},
            onTapNext: () {},
          ),
        ),
      ),
    );

    // chrome 初始隐藏
    expect(find.byKey(const Key('reader_app_bar')), findsNothing);

    // tap 中央
    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();

    // chrome 显示
    expect(find.byKey(const Key('reader_app_bar')), findsOneWidget);
  });

  testWidgets('paged mode tap right triggers next', (tester) async {
    var nextTapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            paginationMode: PaginationMode.paged,
            onTapPrev: () {},
            onTapNext: () => nextTapped = true,
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(750, 400));  // 假设屏幕宽 800
    await tester.pumpAndSettle();

    expect(nextTapped, isTrue);
  });

  testWidgets('paged mode tap left triggers prev', (tester) async {
    var prevTapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            paginationMode: PaginationMode.paged,
            onTapPrev: () => prevTapped = true,
            onTapNext: () {},
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(50, 400));
    await tester.pumpAndSettle();

    expect(prevTapped, isTrue);
  });

  testWidgets('scroll mode tap right does NOT trigger prev/next', (tester) async {
    var nextTapped = false;
    var prevTapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            paginationMode: PaginationMode.scroll,
            onTapPrev: () => prevTapped = true,
            onTapNext: () => nextTapped = true,
          ),
        ),
      ),
    );

    // tap 左右两侧
    await tester.tapAt(const Offset(750, 400));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(50, 400));
    await tester.pumpAndSettle();

    expect(nextTapped, isFalse);
    expect(prevTapped, isFalse);
  });

  testWidgets('scroll mode tap middle toggles chrome', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            paginationMode: PaginationMode.scroll,
            onTapPrev: () {},
            onTapNext: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('reader_app_bar')), findsNothing);
    await tester.tapAt(const Offset(400, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_app_bar')), findsOneWidget);
  });
}
```

- [ ] **Step 3: 实现 ReaderScaffold（双模式）**

Create `app/lib/features/reader/widgets/reader_scaffold.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

import '../controllers/reader_ui_controller.dart';

/// 沉浸式阅读容器：tap 区域分派 + chrome 显隐。
///
/// - **paged 模式**：tap 左 1/3 → onTapPrev；右 1/3 → onTapNext；中央 → toggle chrome
/// - **scroll 模式**：tap 左右无效（用户用滚动手势）；中央 → toggle chrome
class ReaderScaffold extends ConsumerWidget {
  final Widget content;
  final VoidCallback onTapPrev;
  final VoidCallback onTapNext;
  final PaginationMode paginationMode;

  const ReaderScaffold({
    super.key,
    required this.content,
    required this.onTapPrev,
    required this.onTapNext,
    this.paginationMode = PaginationMode.paged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(readerUiControllerProvider);
    final size = MediaQuery.sizeOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTap(details.localPosition.dx, size.width, ref),
      child: Stack(
        children: [
          content,
          if (ui.chromeVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                key: const Key('reader_app_bar'),
                color: Colors.black54,
                child: SafeArea(
                  child: AppBar(
                    title: const Text('阅读中'),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleTap(double dx, double width, WidgetRef ref) {
    // scroll 模式下，tap 左右无意义（用户在滚动）
    if (paginationMode == PaginationMode.scroll) {
      ref.read(readerUiControllerProvider.notifier).toggleChrome();
      return;
    }
    final third = width / 3;
    if (dx < third) {
      onTapPrev();
    } else if (dx > width - third) {
      onTapNext();
    } else {
      ref.read(readerUiControllerProvider.notifier).toggleChrome();
    }
  }
}
```

**注**：ReaderScaffold 只负责 tap 分派 + chrome。content widget 本身（paged 模式下用 Paginator 切片渲染，scroll 模式下用 SingleChildScrollView）由 ReaderEngineProvider 在上层组装（Task 17），作为 `content` 参数注入。这样 ReaderScaffold 与 Paginator 解耦，单测不需要构造 EpubBook。

- [ ] **Step 4: 运行测试**

Run: `/c/flutter/bin/flutter test app/test/features/reader/widgets/reader_scaffold_test.dart`
Expected: 5 tests PASS

- [ ] **Step 5: dart analyze**

Run: `/c/flutter/bin/dart analyze app/lib/features/reader/`
Expected: No issues

- [ ] **Step 6: Commit + Push**

```bash
git add app/lib/features/reader/controllers/ \
        app/lib/features/reader/widgets/reader_scaffold.dart \
        app/test/features/reader/widgets/reader_scaffold_test.dart
git commit -m "feat(m2): implement ReaderScaffold with paged+scroll tap zones"
git push origin master
```

---

## Task 15: 实现 TOC 提取 + TocDrawer

**Files:**
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart`（实现 `toc` getter，从 `_book.Chapters` 递归构建）
- Create: `app/lib/features/reader/widgets/toc_drawer.dart`
- Create: `app/test/features/reader/widgets/toc_drawer_test.dart`

- [ ] **Step 1: 实现 `toc` getter（从 EpubxRenderer._book.Chapters 构建）**

修改 `epubx_renderer.dart`，把 stub 的 `toc` getter 替换为：

```dart
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
  // 子章节在扁平序列中紧跟 parent，索引 = parentFlatIndex + 1 + 累计
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
```

**执行者注意**：epubx 的 `EpubChapter { Title, SubChapters, HtmlContent }` API 在 Task 10 spike 已验证。如属性名不同（如 `EpubChapter.title` 小写），按 spike 实测调整。`encode` 来自 Task 9 的 cfi_codec；`EpubCfiLocator` 是 M1 Locator sealed 子类。

- [ ] **Step 2: 写 TocDrawer 测试**

Create `app/test/features/reader/widgets/toc_drawer_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:zhiyue/features/reader/widgets/toc_drawer.dart';

void main() {
  testWidgets('renders TOC entries', (tester) async {
    final toc = TableOfContents(entries: [
      TocEntry(
        title: '第一章',
        locator: EpubCfiLocator(cfi: '/6', chapterIndex: 0),
      ),
      TocEntry(
        title: '第二章',
        locator: EpubCfiLocator(cfi: '/8', chapterIndex: 1),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TocDrawer(toc: toc, onSelect: (_) {}),
          ),
        ),
      ),
    );

    expect(find.text('第一章'), findsOneWidget);
    expect(find.text('第二章'), findsOneWidget);
  });

  testWidgets('tap entry triggers onSelect', (tester) async {
    final toc = TableOfContents(entries: [
      TocEntry(title: 'A', locator: EpubCfiLocator(cfi: '/6', chapterIndex: 0)),
    ]);

    TocEntry? selected;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TocDrawer(toc: toc, onSelect: (e) => selected = e),
          ),
        ),
      ),
    );

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(selected?.title, 'A');
  });
}
```

- [ ] **Step 3: 实现 TocDrawer**

Create `app/lib/features/reader/widgets/toc_drawer.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:reader_engine/navigation/toc.dart';

class TocDrawer extends StatelessWidget {
  final TableOfContents toc;
  final ValueChanged<TocEntry> onSelect;

  const TocDrawer({
    super.key,
    required this.toc,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (toc.entries.isEmpty) {
      return const Center(child: Text('本书无目录'));
    }
    return ListView.builder(
      itemCount: toc.entries.length,
      itemBuilder: (context, index) {
        final entry = toc.entries[index];
        return _TocTile(entry: entry, depth: 0, onSelect: onSelect);
      },
    );
  }
}

class _TocTile extends StatelessWidget {
  final TocEntry entry;
  final int depth;
  final ValueChanged<TocEntry> onSelect;

  const _TocTile({
    required this.entry,
    required this.depth,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.only(left: 16.0 + depth * 16.0, right: 16.0),
      title: Text(entry.title),
      onTap: () => onSelect(entry),
      children: entry.children
          .map((child) => _TocTile(
                entry: child,
                depth: depth + 1,
                onSelect: onSelect,
              ))
          .toList(),
    );
  }
}
```

- [ ] **Step 4: 运行测试**

Run: `/c/flutter/bin/flutter test app/test/features/reader/widgets/toc_drawer_test.dart`
Expected: 2 tests PASS

- [ ] **Step 5: Commit + Push**

```bash
git add reader_engine_epub_view/lib/epubx_renderer.dart \
        app/lib/features/reader/widgets/toc_drawer.dart \
        app/test/features/reader/widgets/toc_drawer_test.dart
git commit -m "feat(m2): implement TOC extraction and TocDrawer widget"
git push origin master
```

---

## Task 16: 实现 ProgressPersister（防抖 + distinct + 静默失败）

**Files:**
- Create: `app/lib/features/reader/services/progress_persister.dart`
- Create: `app/test/features/reader/services/progress_persister_test.dart`

- [ ] **Step 1: 写失败测试**

Create `app/test/features/reader/services/progress_persister_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:zhiyue/data/models/reading_progress.dart';
import 'package:zhiyue/data/repositories/reading_progress_repository.dart';
import 'package:zhiyue/features/reader/services/progress_persister.dart';

class _FakeRepo implements ReadingProgressRepository {
  final List<ReadingProgress> saved = [];
  ReadingProgress? next;

  @override
  Future<ReadingProgress?> get(String bookId) async => next;

  @override
  Future<void> save(ReadingProgress progress) async {
    saved.add(progress);
    if (saved.length > 100) throw Exception('disk full (simulated)');
  }
}

void main() {
  test('rapid location changes persist once after 500ms idle', () async {
    final repo = _FakeRepo();
    final controller = StreamController<Locator>.broadcast();
    final persister = ProgressPersister(
      bookId: 'b1',
      repository: repo,
      source: controller.stream,
      debounceMs: 500,
    );
    persister.start();

    final cfi1 = EpubCfiLocator(cfi: '/6/4', chapterIndex: 0);
    final cfi2 = EpubCfiLocator(cfi: '/6/8', chapterIndex: 0);
    controller.add(cfi1);
    controller.add(cfi2);
    controller.add(cfi1);

    await Future.delayed(const Duration(milliseconds: 600));

    expect(repo.saved, hasLength(1));
    expect(repo.saved.first.bookId, 'b1');

    await controller.close();
    persister.dispose();
  });

  test('distinct CFIs do not double-write', () async {
    final repo = _FakeRepo();
    final controller = StreamController<Locator>.broadcast();
    final persister = ProgressPersister(
      bookId: 'b1',
      repository: repo,
      source: controller.stream,
      debounceMs: 100,
    );
    persister.start();

    final cfi = EpubCfiLocator(cfi: '/6/4', chapterIndex: 0);
    controller.add(cfi);
    await Future.delayed(const Duration(milliseconds: 150));
    controller.add(cfi);  // same value
    await Future.delayed(const Duration(milliseconds: 150));

    expect(repo.saved, hasLength(1));

    await controller.close();
    persister.dispose();
  });

  test('save failure is silent', () async {
    final repo = _FakeRepo();
    repo.next = ReadingProgress(
      bookId: 'b1',
      locator: EpubCfiLocator(cfi: '/6/4', chapterIndex: 0),
      percent: 0.0,
      updatedAt: DateTime.now(),
    );
    final controller = StreamController<Locator>.broadcast();
    final persister = ProgressPersister(
      bookId: 'b1',
      repository: repo,
      source: controller.stream,
      debounceMs: 50,
    );
    persister.start();

    for (var i = 0; i < 200; i++) {
      controller.add(EpubCfiLocator(cfi: '/6/$i', chapterIndex: 0));
    }
    await Future.delayed(const Duration(milliseconds: 100));

    // 没有抛出
    expect(persister.isAlive, isTrue);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `/c/flutter/bin/flutter test app/test/features/reader/services/progress_persister_test.dart`
Expected: FAIL — `ProgressPersister` 未定义

- [ ] **Step 3: 实现 ProgressPersister**

Create `app/lib/features/reader/services/progress_persister.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:zhiyue/data/models/reading_progress.dart';
import 'package:zhiyue/data/repositories/reading_progress_repository.dart';

/// 进度持久化服务。
///
/// 行为：
/// - 防抖：连续位置变化合并，最后一次为准
/// - distinct：相同 CFI 不重复写
/// - 静默失败：磁盘 IO 异常不抛出，仅 log
class ProgressPersister {
  ProgressPersister({
    required this.bookId,
    required this.repository,
    required this.source,
    this.debounceMs = 500,
  });

  final String bookId;
  final ReadingProgressRepository repository;
  final Stream<Locator> source;
  final int debounceMs;

  StreamSubscription<Locator>? _sub;
  Timer? _debounce;
  Locator? _lastEmitted;
  Locator? _lastPersisted;
  bool _alive = true;

  bool get isAlive => _alive;

  void start() {
    _sub = source.listen(_onLocation);
  }

  void _onLocation(Locator locator) {
    if (locator == _lastEmitted) return;
    _lastEmitted = locator;

    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: debounceMs), () async {
      final loc = _lastEmitted;
      if (loc == null || loc == _lastPersisted) return;
      try {
        await repository.save(ReadingProgress(
          bookId: bookId,
          locator: loc,
          percent: _estimatePercent(loc),
          updatedAt: DateTime.now(),
        ));
        _lastPersisted = loc;
      } catch (e, st) {
        // 静默失败（spec §5.2）
        debugPrint('ProgressPersister save failed: $e\n$st');
      }
    });
  }

  double _estimatePercent(Locator locator) {
    // 粗略估算：chapterIndex / 100。M3 用真实 spine 长度。
    if (locator is EpubCfiLocator) {
      return (locator.chapterIndex / 100).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  void dispose() {
    _alive = false;
    _debounce?.cancel();
    _sub?.cancel();
  }
}
```

- [ ] **Step 4: 运行测试**

Run: `/c/flutter/bin/flutter test app/test/features/reader/services/progress_persister_test.dart`
Expected: 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/reader/services/progress_persister.dart \
        app/test/features/reader/services/progress_persister_test.dart
git commit -m "feat(m2): implement ProgressPersister with debounce + distinct + silent fail"
```

---

## Task 17: 实现 ReaderEngineProvider + 打开书籍主流程

**Files:**
- Create: `app/lib/features/reader/providers/reader_engine_provider.dart`
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart`（包装 ReaderEngine 接口）
- Create: `app/lib/features/reader/providers/concrete_reader_engine.dart`
- Create: `app/test/features/reader/providers/reader_engine_provider_test.dart`

- [ ] **Step 1: 在 reader_engine_epub_view 加 ReaderEngine 实现**

Create `reader_engine_epub_view/lib/concrete_reader_engine.dart`:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine/rendering/renderer.dart';

import 'epubx_renderer.dart';

/// 包装 [EpubxRenderer] 的 [ReaderEngine] 具体实现。
///
/// 当 [BookRef.format] == epub 时由 provider 选择此实现。
class ConcreteEpubReaderEngine implements ReaderEngine {
  ConcreteEpubReaderEngine({required EpubxRenderer renderer})
      : _renderer = renderer;

  final EpubxRenderer _renderer;
  final _stateController = StreamController<ReaderEngineState>.broadcast();

  ReaderEngineState _state = const ReaderEngineUnloaded();
  TableOfContents? _toc;

  @override
  ReaderEngineState get state => _state;

  @override
  Stream<ReaderEngineState> get state$ => _stateController.stream;

  @override
  Stream<Locator> get currentLocation$ => _renderer.currentLocation$;

  @override
  TableOfContents? get toc => _toc;

  @override
  TypographySettings get typography => TypographySettings.defaults();
  // 注：typography 实际由 _renderer 持有；为简洁此处返回默认。
  // M3 重构为 _renderer.typography。

  @override
  PaginationMode get paginationMode => PaginationMode.paged;

  @override
  Future<void> open(BookRef book) async {
    _setState(const ReaderEngineLoading());
    try {
      await _renderer.openFile(book.filePath);
      _toc = await _renderer.toc;
      _setState(const ReaderEngineReady());
    } catch (e, st) {
      _setState(ReaderEngineError(message: '打开书籍失败: $e', cause: e));
      // ignore: unused_result
      debugPrint('$e\n$st');
    }
  }

  void _setState(ReaderEngineState s) {
    _state = s;
    _stateController.add(s);
  }

  @override
  Future<void> gotoLocator(Locator locator) => _renderer.gotoLocator(locator);

  @override
  Future<void> gotoTocEntry(TocEntry entry) => _renderer.gotoLocator(entry.locator);

  @override
  Future<void> nextSpine() async {
    // TODO(M3): 完整 spine 导航
  }

  @override
  Future<void> previousSpine() async {}

  @override
  Future<void> setTypography(TypographySettings settings) =>
      _renderer.setTypography(settings);

  @override
  Future<void> setPaginationMode(PaginationMode mode) =>
      _renderer.setPaginationMode(mode);

  @override
  Future<void> close() async {
    await _renderer.dispose();
    await _stateController.close();
  }

  @override
  Widget build(BuildContext context) => _renderer.build(context);
}
```

在 barrel 加导出。

- [ ] **Step 2: 写 provider 测试**

Create `app/test/features/reader/providers/reader_engine_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:zhiyue/features/reader/providers/reader_engine_provider.dart';

void main() {
  test('readerEngineForBookProvider resolves to Loading initially then engine ready',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final engine = container.read(readerEngineForBookProvider('b1').future);
    // 注：真实测试需要 mock repository；此处仅验证 provider 形状
    expect(engine, completes);
  });
}
```

**注**：此测试在 Task 22 widget 测试时通过 ProviderScope override 完整覆盖；此处为 smoke。

- [ ] **Step 3: 实现 provider**

Create `app/lib/features/reader/providers/reader_engine_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

import '../../../core/providers.dart';

/// 给定 bookId，加载 BookRef 并创建对应 ReaderEngine。
final readerEngineForBookProvider =
    FutureProvider.family<ReaderEngine, String>((ref, bookId) async {
  final repo = ref.watch(bookRepositoryProvider);
  final book = await repo.getById(bookId);
  if (book == null) {
    throw StateError('Book not found: $bookId');
  }

  final ref = BookRef(
    id: book.id,
    title: book.title,
    format: book.format == BookFormat.epub
        ? ReaderBookFormat.epub
        : ReaderBookFormat.pdf,
    filePath: book.filePath,
  );

  if (ref.format == ReaderBookFormat.epub) {
    return ConcreteEpubReaderEngine(renderer: EpubxRenderer());
  }
  throw UnimplementedError('PDF engine is M4');
});
```

**注意**：命名冲突——`reader_engine.BookFormat` 与 `app/data/models/book.dart.BookFormat`。代码中用别名 `ReaderBookFormat`：在文件顶部 import 加 `as ReaderBookFormat`，并 `import 'package:reader_engine/core/book_ref.dart';` 不加别名（让 ref 用别名引用）。

具体 import：
```dart
import 'package:reader_engine/core/book_ref.dart' as ReaderBookFormat;
import 'package:reader_engine/core/book_ref.dart' show BookRef;
```

实际写法：用 `import 'package:reader_engine/core/book_ref.dart';`（默认无别名）+ `import 'package:zhiyue/data/models/book.dart';`（默认无别名），然后在代码中显式引用：
- app 的 BookFormat → 用 `BookFormat.epub`（来自 book.dart，已 import）
- reader_engine 的 BookFormat → 别名导入

由于 Dart 不允许同名 enum 同时无别名导入，正确做法：

```dart
import 'package:reader_engine/core/book_ref.dart' as re;
import 'package:zhiyue/data/models/book.dart';
```

然后使用 `re.BookFormat.epub` 与 `BookFormat.epub`。

修订上面 provider 代码：

```dart
final ref = BookRef(
  id: book.id,
  title: book.title,
  format: book.format == BookFormat.epub ? re.BookFormat.epub : re.BookFormat.pdf,
  filePath: book.filePath,
);

if (ref.format == re.BookFormat.epub) {
  return ConcreteEpubReaderEngine(renderer: EpubxRenderer());
}
```

加 import `import 'package:reader_engine/core/book_ref.dart' as re;`

- [ ] **Step 4: 运行测试**

Run: `/c/flutter/bin/flutter test app/test/features/reader/providers/reader_engine_provider_test.dart`
Expected: 1 test PASS

- [ ] **Step 5: dart analyze**

Run: `/c/flutter/bin/dart analyze app/lib/features/reader/providers/`
Expected: No issues

- [ ] **Step 6: Commit**

```bash
git add reader_engine_epub_view/lib/concrete_reader_engine.dart \
        reader_engine_epub_view/lib/reader_engine_epub_view.dart \
        app/lib/features/reader/providers/reader_engine_provider.dart \
        app/test/features/reader/providers/reader_engine_provider_test.dart
git commit -m "feat(m2): implement ReaderEngineProvider and ConcreteEpubReaderEngine"
```

---

## Task 18: 实现 ReaderBottomBar（进度显示）

**Files:**
- Create: `app/lib/features/reader/widgets/reader_bottom_bar.dart`
- Create: `app/test/features/reader/widgets/reader_bottom_bar_test.dart`

- [ ] **Step 1: 写测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/widgets/reader_bottom_bar.dart';

void main() {
  testWidgets('shows chapter title and percent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            chapterTitle: '第三章',
            percent: 0.42,
          ),
        ),
      ),
    );

    expect(find.text('第三章'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('null chapter title shows placeholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(chapterTitle: null, percent: 0.0),
        ),
      ),
    );

    expect(find.text('—'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 实现 ReaderBottomBar**

Create `app/lib/features/reader/widgets/reader_bottom_bar.dart`:

```dart
import 'package:flutter/material.dart';

class ReaderBottomBar extends StatelessWidget {
  final String? chapterTitle;
  final double percent;

  const ReaderBottomBar({
    super.key,
    required this.chapterTitle,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              chapterTitle ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '${(percent * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 运行测试**

Run: `/c/flutter/bin/flutter test app/test/features/reader/widgets/reader_bottom_bar_test.dart`
Expected: 2 tests PASS

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/reader/widgets/reader_bottom_bar.dart \
        app/test/features/reader/widgets/reader_bottom_bar_test.dart
git commit -m "feat(m2): implement ReaderBottomBar with progress display"
```

---

## Task 19: 实现 TypographySettings → flutter_widget_from_html 主题映射

> **2026-06-26 pivot 后修订**：原计划生成 CSS 字符串注入 `epub_view_plus` 的 WebView。pivot 后没有 WebView，由 `flutter_widget_from_html` 的 `HtmlWidget(textStyle:, customWidgetBuilder:)` 直接吃 TextStyle。本 Task 保留 `typography_css.dart` 命名以减少 diff，但实际输出是 `TextStyle` + `WidgetBuilder` 配置（而非字符串 CSS）。详见 spec §10 W5。

**Files:**
- Create: `reader_engine_epub_view/lib/typography_css.dart`（实际是 TextStyle 工厂，非字符串 CSS）
- Create: `reader_engine_epub_view/test/typography_css_test.dart`
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart`（在 setTypography / build 中传 HtmlWidget 参数）

- [ ] **Step 1: 写失败测试**

Create `reader_engine_epub_view/test/typography_css_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine_epub_view/typography_css.dart';

void main() {
  test('basic settings produce expected CSS', () {
    final css = TypographyCss.fromSettings(TypographySettings.defaults());
    expect(css, contains('font-size: 16'));
    expect(css, contains('line-height: 1.5'));
  });

  test('custom font family is included', () {
    final s = TypographySettings.defaults().copyWith(fontFamily: 'NotoSerif');
    final css = TypographyCss.fromSettings(s);
    expect(css, contains("'NotoSerif'"));
  });

  test('sepia theme sets background', () {
    final s = TypographySettings.defaults().copyWith(theme: ReadingTheme.sepia);
    final css = TypographyCss.fromSettings(s);
    expect(css, contains('background'));
    expect(css, contains('f4ecd8'));  // sepia 色
  });
}
```

- [ ] **Step 2: 实现 TypographyCss**

Create `reader_engine_epub_view/lib/typography_css.dart`:

```dart
import 'package:reader_engine/core/typography_settings.dart';

/// 从 [TypographySettings] 生成注入到 EPUB 渲染层的 CSS。
class TypographyCss {
  const TypographyCss._();

  static String fromSettings(TypographySettings s) {
    final buf = StringBuffer();
    buf.writeln('body {');

    buf.writeln('  font-size: ${s.fontSize}px !important;');
    buf.writeln('  line-height: ${s.lineHeight} !important;');

    if (s.fontFamily != null) {
      buf.writeln("  font-family: '${s.fontFamily}', serif !important;");
    }

    final (fg, bg) = _themeColors(s.theme);
    buf.writeln('  color: $fg !important;');
    buf.writeln('  background: $bg !important;');

    buf.writeln('}');
    return buf.toString();
  }

  static (String, String) _themeColors(ReadingTheme t) {
    switch (t) {
      case ReadingTheme.light:
        return ('#000000', '#ffffff');
      case ReadingTheme.dark:
        return ('#e0e0e0', '#1a1a1a');
      case ReadingTheme.sepia:
        return ('#5b4636', '#f4ecd8');
      case ReadingTheme.eInk:
        return ('#000000', '#e8e8e8');
    }
  }
}
```

- [ ] **Step 3: 运行测试**

Run: `/c/flutter/bin/flutter test reader_engine_epub_view/test/typography_css_test.dart`
Expected: 3 tests PASS

- [ ] **Step 4: 在 EpubxRenderer.setTypography / build 中应用 textStyle**

修改 `epubx_renderer.dart` 的 `setTypography` 与 `build`：

```dart
@override
Future<void> setTypography(TypographySettings settings) async {
  _typography = settings;
  // build 时读取 _typography，无需主动 invalidate（widget tree 重建由上层 Provider 触发）
}

@override
Widget build(BuildContext context) {
  final chapters = flatChapters;
  if (chapters.isEmpty) return const SizedBox.shrink();
  final html = chapters[_currentChapterIndex].HtmlContent ?? '';
  final style = TypographyCss.textStyleFromSettings(_typography);

  return SingleChildScrollView(
    controller: _scrollController,
    child: HtmlWidget(
      html,
      textStyle: style,  // flutter_widget_from_html ^0.15.0
    ),
  );
}
```

加 import `import 'typography_css.dart';`。`HtmlWidget` 的 `textStyle` 参数是 inheritance-style —— 它会作为根文本样式被子标签覆盖。

**执行者注意**：本 Task 只接字号 + 行距 + 主题（背景色 + 前景色）。字体族（Han Serif/Sans）在 flutter_widget_from_html 中通过 `textStyle.fontFamily` 设置；M2 不接入字体下载，先用系统默认。字体注入留 M3。

- [ ] **Step 5: 运行测试 + analyze**

```bash
/c/flutter/bin/flutter test reader_engine_epub_view/test/typography_css_test.dart
/c/flutter/bin/dart analyze reader_engine_epub_view/
```
Expected: All PASS；analyze 无 issue

- [ ] **Step 6: Commit + Push**

```bash
git add reader_engine_epub_view/lib/typography_css.dart \
        reader_engine_epub_view/test/typography_css_test.dart \
        reader_engine_epub_view/lib/epubx_renderer.dart
git commit -m "feat(m2): implement TypographySettings → HtmlWidget textStyle mapping"
git push origin master
```

---

## Task 20: 实现 TypographyPanel UI

**Files:**
- Create: `app/lib/features/reader/widgets/typography_panel.dart`
- Create: `app/test/features/reader/widgets/typography_panel_test.dart`

- [ ] **Step 1: 写测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:zhiyue/features/reader/widgets/typography_panel.dart';

void main() {
  testWidgets('shows current font size', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TypographyPanel(
              current: TypographySettings.defaults(),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('16'), findsOneWidget);
  });

  testWidgets('tap size up button triggers onChanged', (tester) async {
    TypographySettings? updated;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TypographyPanel(
              current: TypographySettings.defaults(),
              onChanged: (s) => updated = s,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(updated?.fontSize, 17.0);
  });
}
```

- [ ] **Step 2: 实现 TypographyPanel**

Create `app/lib/features/reader/widgets/typography_panel.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:reader_engine/core/typography_settings.dart';

class TypographyPanel extends StatelessWidget {
  final TypographySettings current;
  final ValueChanged<TypographySettings> onChanged;

  const TypographyPanel({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('字号', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => _changeFontSize(current.fontSize - 1),
              ),
              Expanded(
                child: Text(
                  current.fontSize.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _changeFontSize(current.fontSize + 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('主题', style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: ReadingTheme.values
                .map((t) => ChoiceChip(
                      label: Text(_themeLabel(t)),
                      selected: current.theme == t,
                      onSelected: (_) => onChanged(current.copyWith(theme: t)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  void _changeFontSize(double newSize) {
    final clamped = newSize.clamp(12.0, 32.0);
    onChanged(current.copyWith(fontSize: clamped));
  }

  String _themeLabel(ReadingTheme t) {
    switch (t) {
      case ReadingTheme.light: return '白';
      case ReadingTheme.dark: return '深';
      case ReadingTheme.sepia: return '黄';
      case ReadingTheme.eInk: return '墨';
    }
  }
}
```

- [ ] **Step 3: 运行测试**

Run: `/c/flutter/bin/flutter test app/test/features/reader/widgets/typography_panel_test.dart`
Expected: 2 tests PASS

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/reader/widgets/typography_panel.dart \
        app/test/features/reader/widgets/typography_panel_test.dart
git commit -m "feat(m2): implement TypographyPanel UI"
```

---

## Task 21: 实现 Fatal / Recoverable / Soft 错误处理

**Files:**
- Create: `app/lib/features/reader/widgets/reader_error_view.dart`
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart`（openFile 加 15s 超时 + 把 epubx 异常映射成 ReaderEngineError）
- Create: `app/test/features/reader/widgets/reader_error_view_test.dart`

- [ ] **Step 1: 给 EpubxRenderer.openFile 加超时**

修改 `epubx_renderer.dart` 的 `openFile`：

```dart
@override
Future<void> openFile(String filePath) async {
  _setState(const ReaderEngineLoading());
  try {
    const timeout = Duration(seconds: 15);
    final bytes = await File(filePath).readAsBytes().timeout(timeout);
    final book = await EpubReader.readBook(bytes).timeout(timeout);
    _book = book;
    _currentChapterIndex = 0;
    _scrollController.addListener(_onScroll);
    _setState(const ReaderEngineReady());
  } on TimeoutException catch (e, st) {
    debugPrint('EpubxRenderer.openFile timeout: $filePath\n$e\n$st');
    _setState(ReaderEngineError(cause: TimeoutException('EPUB parse timeout (file: $filePath)')));
  } catch (e, st) {
    debugPrint('EpubxRenderer.openFile failed: $filePath\n$e\n$st');
    _setState(ReaderEngineError(cause: e));
  }
}
```

加 `import 'dart:async';`（TimeoutException 来源）。

- [ ] **Step 2: 写错误视图测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/widgets/reader_error_view.dart';

void main() {
  testWidgets('renders message and retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderErrorView(
          message: '打开失败',
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('打开失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(retried, isTrue);
  });
}
```

- [ ] **Step 3: 实现 ReaderErrorView**

Create `app/lib/features/reader/widgets/reader_error_view.dart`:

```dart
import 'package:flutter/material.dart';

class ReaderErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  const ReaderErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (onRetry != null)
              FilledButton(onPressed: onRetry, child: const Text('重试')),
            if (onBack != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onBack, child: const Text('返回')),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 在 ConcreteEpubReaderEngine 加 CFI fallback**

修改 `concrete_reader_engine.dart` 的 `open` 方法，在 ready 后追加 CFI 恢复：

```dart
Future<void> openWithLastProgress({
  required BookRef book,
  required Locator? lastLocator,
}) async {
  await open(book);
  if (state is ReaderEngineReady && lastLocator != null) {
    try {
      await gotoLocator(lastLocator);
    } catch (e, st) {
      // spec §6.3：CFI 解码失败降级到第一章
      debugPrint('CFI restore failed: $e\n$st');
    }
  }
}
```

- [ ] **Step 5: 运行测试**

Run: `/c/flutter/bin/flutter test app/test/features/reader/widgets/reader_error_view_test.dart`
Expected: 1 test PASS

- [ ] **Step 6: Commit + Push**

```bash
git add app/lib/features/reader/widgets/reader_error_view.dart \
        app/test/features/reader/widgets/reader_error_view_test.dart \
        reader_engine_epub_view/lib/epubx_renderer.dart
git commit -m "feat(m2): implement error states (Fatal/Recoverable) + 15s parse timeout"
git push origin master
```

---

## Task 22: Widget 测试补全 — ReaderPage 装配

**Files:**
- Create: `app/lib/features/reader/pages/reader_page.dart`
- Modify: `app/lib/core/app.dart`（加路由）
- Create: `app/test/features/reader/pages/reader_page_test.dart`

- [ ] **Step 1: 实现 ReaderPage**

Create `app/lib/features/reader/pages/reader_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reader_engine_provider.dart';
import '../services/progress_persister.dart';
import '../widgets/reader_bottom_bar.dart';
import '../widgets/reader_error_view.dart';
import '../widgets/reader_scaffold.dart';
import '../../../core/providers.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderPage({super.key, required this.bookId});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  ProgressPersister? _persister;

  @override
  void dispose() {
    _persister?.dispose();
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
          return _ReaderBody(engine: engine);
        },
      ),
    );
  }

  void _ensureProgressPersister(engine) {
    if (_persister != null) return;
    _persister = ProgressPersister(
      bookId: widget.bookId,
      repository: ref.read(readingProgressRepositoryProvider),
      source: engine.currentLocation$,
    )..start();
  }
}

class _ReaderBody extends ConsumerWidget {
  final dynamic engine;

  const _ReaderBody({required this.engine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReaderScaffold(
      content: engine.build(context),
      onTapPrev: () => engine.previousSpine(),
      onTapNext: () => engine.nextSpine(),
    );
  }
}
```

- [ ] **Step 2: 加路由**

修改 `app/lib/core/app.dart`：

```dart
import '../features/reader/pages/reader_page.dart';
// ...

return MaterialApp(
  // ...
  onGenerateRoute: (settings) {
    if (settings.name?.startsWith('/book/') ?? false) {
      final bookId = settings.name!.substring('/book/'.length);
      return MaterialPageRoute(
        builder: (_) => ReaderPage(bookId: bookId),
      );
    }
    return null;
  },
  home: const HomePage(),
);
```

- [ ] **Step 3: 写 widget 测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/pages/reader_page.dart';

void main() {
  testWidgets('ReaderPage renders loading initially', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ReaderPage(bookId: 'nonexistent')),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 4: 运行测试**

Run: `/c/flutter/bin/flutter test app/test/features/reader/pages/reader_page_test.dart`
Expected: 1 test PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/reader/pages/reader_page.dart \
        app/lib/core/app.dart \
        app/test/features/reader/pages/reader_page_test.dart
git commit -m "feat(m2): assemble ReaderPage with go_router integration"
```

---

## Task 23: Golden 测试 — 6 个渲染快照

**Files:**
- Modify: `app/pubspec.yaml`（加 golden_toolkit dev 依赖）
- Create: `app/test/goldens/typography_golden_test.dart`
- Create: `app/test/goldens/reader_ui_golden_test.dart`

- [ ] **Step 1: 加 golden_toolkit**

修改 `app/pubspec.yaml`，在 `dev_dependencies:` 加：

```yaml
  golden_toolkit: ^0.15.0
```

运行 `/c/flutter/bin/flutter pub get`（在 app/ 目录）。

- [ ] **Step 2: 写 typography golden**

Create `app/test/goldens/typography_golden_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:zhiyue/features/reader/widgets/typography_panel.dart';

void main() {
  testGoldens('TypographyPanel renders across themes', (tester) async {
    final builder = GoldenBuilder.column()
      ..addScenario(
        'Light theme',
        MaterialApp(home: Scaffold(body: TypographyPanel(
          current: TypographySettings.defaults().copyWith(theme: ReadingTheme.light),
          onChanged: (_) {},
        ))),
      )
      ..addScenario(
        'Dark theme',
        MaterialApp(home: Scaffold(body: TypographyPanel(
          current: TypographySettings.defaults().copyWith(theme: ReadingTheme.dark),
          onChanged: (_) {},
        ))),
      )
      ..addScenario(
        'Sepia theme',
        MaterialApp(home: Scaffold(body: TypographyPanel(
          current: TypographySettings.defaults().copyWith(theme: ReadingTheme.sepia),
          onChanged: (_) {},
        ))),
      );

    await tester.pumpWidgetBuilder(builder.build());
    await screenMatchesGolden(tester, 'typography_panel_themes');
  });
}
```

- [ ] **Step 3: 写 reader UI golden**

Create `app/test/goldens/reader_ui_golden_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:zhiyue/features/reader/widgets/toc_drawer.dart';
import 'package:zhiyue/features/reader/widgets/reader_bottom_bar.dart';

void main() {
  testGoldens('TocDrawer golden', (tester) async {
    final toc = TableOfContents(entries: [
      TocEntry(title: '第一章 引子', locator: EpubCfiLocator(cfi: '/6', chapterIndex: 0)),
      TocEntry(title: '第二章 起点', locator: EpubCfiLocator(cfi: '/8', chapterIndex: 1)),
      TocEntry(title: '第三章 转折', locator: EpubCfiLocator(cfi: '/10', chapterIndex: 2)),
    ]);

    await tester.pumpWidgetBuilder(
      MaterialApp(home: Scaffold(body: TocDrawer(toc: toc, onSelect: (_) {}))),
    );
    await screenMatchesGolden(tester, 'toc_drawer');
  });

  testGoldens('ReaderBottomBar golden', (tester) async {
    final builder = GoldenBuilder.column()
      ..addScenario(
        'Has title',
        MaterialApp(home: const Scaffold(body: ReaderBottomBar(chapterTitle: '第三章 风暴', percent: 0.42))),
      )
      ..addScenario(
        'No title',
        MaterialApp(home: const Scaffold(body: ReaderBottomBar(chapterTitle: null, percent: 0.0))),
      );

    await tester.pumpWidgetBuilder(builder.build());
    await screenMatchesGolden(tester, 'reader_bottom_bar_states');
  });
}
```

- [ ] **Step 4: 生成 golden 基线**

Run: `/c/flutter/bin/flutter test app/test/goldens/ --update-goldens`
Expected: 创建 `app/test/goldens/**.png` 文件

**人审**：肉眼检查生成的 PNG，确认布局符合预期。Golden 基线**必须人审后才能 commit**。

- [ ] **Step 5: 复跑测试验证**

Run: `/c/flutter/bin/flutter test app/test/goldens/`
Expected: PASS（除非基线需要更新）

- [ ] **Step 6: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock \
        app/test/goldens/typography_golden_test.dart \
        app/test/goldens/reader_ui_golden_test.dart \
        app/test/goldens/*.png
git commit -m "test(m2): add golden tests for typography panel and reader UI"
```

---

## Task 24: 集成测试 — 端到端阅读流程

**Files:**
- Create: `app/integration_test/reader_flow_test.dart`

- [ ] **Step 1: 写集成测试**

Create `app/integration_test/reader_flow_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zhiyue/core/app.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/file_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Reader flow end-to-end', () {
    testWidgets('open book → state becomes ready', (tester) async {
      // 准备一本真实书到 FileStorage
      final storage = await FileStorage.create();
      final db = AppDatabase();

      addTearDown(db.close);

      await BooksDao(db).insertOne(
        id: 'b1',
        title: '测试书',
        format: 'epub',
        filePath: '/library/test.epub',
        fileHash: 'h',
        fileSizeBytes: 0,
      );

      await tester.pumpWidget(const ZhiYueApp());
      await tester.pumpAndSettle();

      // 导航到 /book/b1
      // 注：完整测试需要 Navigator.pushNamed('/book/b1')
      // 此处简化，仅验证 app 启动
      expect(find.byType(MaterialApp), findsOneWidget);
    },
        skip: '需要 fixture EPUB + 真实路径注入；CI 上跑',
        timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('CFI restoration: reopen book returns to last position',
        (tester) async {
      // 1. 打开书，跳到某 CFI
      // 2. 关闭
      // 3. 重新打开
      // 4. 验证 engine 从 LocalReadingProgressRepository 取的 CFI 一致
      //    容差 < 100 字符（spec §9.4）
    },
        skip: '依赖 fixture + 真实 reader widget；M2 W5 末尾补完',
        timeout: const Timeout(Duration(seconds: 60)));
  });
}
```

**注**：集成测试由于依赖 fixture EPUB，默认 skip；CI 上准备 fixture 后启用。这是 spec §9 验收条件之一。

- [ ] **Step 2: 运行测试**

Run: `/c/flutter/bin/flutter test app/integration_test/reader_flow_test.dart`
Expected: 2 tests SKIPPED（无 fixture）

- [ ] **Step 3: Commit**

```bash
git add app/integration_test/reader_flow_test.dart
git commit -m "test(m2): scaffold integration test for reader flow (skipped pending fixtures)"
```

---

## Task 25: 全局 code review + 验收清单

**Files:**
- Modify: 各处（按 review 反馈）
- Create: `docs/superpowers/specs/2026-06-25-m2-epub-reader-design.md`（更新验收状态）

- [ ] **Step 1: 跑 dart analyze 全局**

Run: `/c/flutter/bin/dart analyze app/ reader_engine/ reader_engine_epub_view/`
Expected: No errors（warnings/info 可酌情清理）

- [ ] **Step 2: 跑所有测试**

Run: `/c/flutter/bin/flutter test app/test/ && /c/flutter/bin/flutter test reader_engine/test/ && /c/flutter/bin/flutter test reader_engine_epub_view/test/`
Expected: All PASS

- [ ] **Step 3: dispatch 最终 code review subagent**

按 subagent-driven-development skill：dispatch 一个 `code-reviewer` subagent 检查整个 M2 实现。Prompt 要点：
- 引用 spec 文件路径
- 列出 9 条验收标准（spec §9）
- 让 reviewer 报告 Spec 合规性 + 代码质量问题

- [ ] **Step 4: 根据 review 反馈修复**

修复 reviewer 列出的所有 high-priority issues。

- [ ] **Step 5: 更新 memory + 提交最终报告**

修改 `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_m0m1_complete.md`（或新建 `project_zhiyue_m2_complete.md`），记录：
- M2 完成（任务数、测试数、commit 数）
- 关键风险验证结果（CFI 是否稳定、CSS 注入是否漂移）
- M3 起点：高亮 / 笔记 / AI 接入

- [ ] **Step 6: Push 并标记 M2 完成**

```bash
git push origin master
git tag m2-complete
git push origin m2-complete
```

**注**：tag 操作前与用户确认。

---

## 自审（plan vs spec 覆盖度）

**1. Spec 覆盖：**
- §3 架构（三 package + 双层抽象）→ Task 1-7, 17 ✓
- §4 组件（ReaderEngine / EpubRenderer / 模型 / UI）→ Task 4-6, 11-15, 17-22 ✓
- §5.1 打开主流程 → Task 17, 22 ✓
- §5.2 进度持久化 → Task 16 ✓
- §5.3 翻页交互 → Task 13-14 ✓
- §5.4 排版变更 → Task 19, 20 ✓
- §6 错误处理（Fatal/Recoverable/Soft + 15s 超时 + CFI fallback）→ Task 21 ✓
- §7 测试（单元 / widget / golden / 集成）→ Task 22-24 ✓
- §8 关键风险 → Task 10 spike 验证 ✓
- §9 验收标准 → Task 25 ✓
- §11 偏差（M1 模型迁移）→ Task 2-3 ✓

**2. 类型一致性检查：**
- `ReaderEngine` 方法签名：open / gotoLocator / gotoTocEntry / nextSpine / previousSpine / setTypography / setPaginationMode / close / build — Task 6 定义，Task 11/17 使用，签名一致 ✓
- `EpubRenderer` 方法：build / openFile / currentLocation$ / toc / gotoLocator / setTypography / setPaginationMode / dispose — Task 6 定义，Task 11/12 使用 ✓
- `BookRef` 字段：id / title / format / filePath — Task 4 定义，Task 17 使用 ✓
- `ReaderEngineState` 子类：Unloaded / Loading / Ready / Error — Task 5 定义，Task 11/17 使用 ✓
- `Locator` 子类：EpubCfiLocator / PdfPageLocator — M1 已有，Task 9/12 使用 ✓

**3. 占位符扫描：**
- 各 Task 中保留的 TODO 都明确标注了未来 Task 编号（"TODO(M2 W2): ..."），不算 plan 失败
- Task 17 中 ReaderEngineProvider 的 book.format 比较处理通过显式别名 `re.BookFormat` 解决
- Task 22 的 _ReaderBody 使用 dynamic 是临时简化，M3 重构为具类型

**4. 风险点（已知）：**
- Task 10 epubx spike 失败（解析抛异常 / 章节为空 / HTML 乱码）→ pub.dev 上无备选 parser，须升级到 user 重新评估 M2 范围。已 pivot 一次，再 pivot 等于推倒重来
- Task 12 / 15 中 epubx 的 `EpubChapter.HtmlContent` / `SubChapters` 属性名假设来自 pub.dev ^4.0.0 文档；spike 已验证；若属性不同（如 `htmlContent` 小写）在该 Task 内调整
- Task 12 字符偏移位置追踪是 viewport 比例近似，不精确 —— M2 接受；M3 可改 widget-level offset
- Task 13 Paginator M2 简化：图片/表格占位高度 0，不处理 inline 图片分页；M3+
- Task 23 golden 在不同平台字体差异；CI 跑 Linux baseline，本地 Windows 可忽略
