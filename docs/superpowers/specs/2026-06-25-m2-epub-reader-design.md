# M2 — EPUB 阅读器设计

**版本**：2026-06-25
**里程碑**：M2（继 M0 数据层 + M1 笔记数据模型之后）
**前置依赖**：M0 + M1 已交付（58 测试通过、29 commit）
**工期估算**：6 周（含完全抽象隔离成本 + golden 测试）

---

## 1. 背景与目标

平台级 spec（`2026-06-24-ebook-platform-design.md` line 579）将 M2 定义为：
> EPUB 阅读器（解析 / 渲染 / 翻页 / 目录 / 进度）

本次 M2 在原定义上**合并了 M3 的"基础排版"**（用户决策），使读者在 M2 结束时即可获得完整可用的基础阅读体验。高亮、笔记、AI 仍在 M3。

### 1.1 目标

打开任意中文/英文 EPUB（reflowable 类型），渲染、翻页、跳目录、记忆进度、调排版，全部可用，且代码结构允许 M4 加入 PDF 时**零 UI 改造**。

### 1.2 非目标

- EPUB 3 fixed-layout（需 WebView，Windows 不稳）
- 高亮 / 笔记 / AI（M3）
- 云同步（M6）
- 中文标点避头尾完整方案（M3+，本里程碑 best-effort）

---

## 2. 范围

### 2.1 In scope

| 能力 | 备注 |
|---|---|
| EPUB 2 / EPUB 3 reflowable 解析与渲染 | 仅 reflowable；fixed-layout 触发时降级提示 |
| 双模式翻页（paged 默认 + scroll 可切换） | 用户切换持久化到 reading_state 表 |
| 目录导航 | 嵌套 spine + navMap |
| CFI 进度持久化 | 复用 M1 `LocalReadingProgressRepository` |
| 基础排版 | 字号、行距、主题（白/黄/深）、字体（系统/衬线） |

### 2.2 Out of scope（明确不做）

参见 1.2。

---

## 3. 架构

### 3.1 包结构

```
reader_engine/                      ← 纯 Dart package（无 Flutter 依赖）
  lib/
    reader_engine.dart              ← abstract interface（ReaderEngine）
    rendering/
      renderer.dart                 ← EpubRenderer abstract interface
      pagination_model.dart         ← PaginationMode enum
    navigation/
      toc.dart                      ← TableOfContents / TocEntry
    core/
      locator.dart                  ← 从 app/lib/core/ 迁移（M1 已有，M2 W1 迁入）
      typography_settings.dart      ← 从 app/lib/core/ 迁移（M1 已有，M2 W1 迁入）
      book_ref.dart                 ← BookRef 渲染引用（M2 新增）
  test/

reader_engine_epub_view/            ← Flutter package（依赖 epub_view_plus）
  lib/
    epub_view_renderer.dart         ← EpubViewPlusRenderer implements EpubRenderer
    epub_view_widget.dart           ← Flutter widget 包装 epub_view_plus.EpubView
    cfi_codec.dart                  ← 纯函数：String CFI ↔ epub_view_plus 内部对象
  test/

app/lib/features/reader/            ← UI 层
  pages/reader_page.dart            ← 路由入口
  widgets/
    reader_scaffold.dart            ← 沉浸式容器
    reader_app_bar.dart
    reader_bottom_bar.dart
    toc_drawer.dart
    typography_panel.dart
  controllers/
    reader_ui_controller.dart       ← 沉浸模式 / 抽屉开关 / 排版面板开关

app/lib/core/
  locator.dart                      ← 改为 re-export 自 reader_engine（M1 API 兼容）
  typography.dart                   ← 改为 re-export 自 reader_engine
```

**依赖方向（严格单向）**：
```
app ──→ reader_engine_epub_view ──→ reader_engine
                                  └─→ epub_view_plus（第三方）
app ──→ reader_engine（直接依赖，访问 Locator 等核心模型）
```

**三个 package 的边界**：
- `reader_engine/` 是纯 Dart，所有抽象和共享模型在此；单测无 Flutter 依赖、毫秒级；不依赖 `app/`
- `reader_engine_epub_view/` 是独立 Flutter 包，依赖 `epub_view_plus`；如果未来 pivot，新建 `reader_engine_epubx_custom/` 替换它，UI 和 engine 不动
- `app/lib/features/reader/` UI 层永远只看 `ReaderEngine` 抽象

**M1 模型迁移**：`Locator` / `TypographySettings` 在 M1 写在 `app/lib/core/`，M2 W1 迁入 `reader_engine/lib/core/`，`app/lib/core/locator.dart` 等改为 re-export 以保持 M1 测试 API 兼容（无破坏性变更）。

### 3.2 双层抽象的必要性

```
UI ──→ ReaderEngine（format-agnostic）
            │
            ├──→ EpubRenderer（EPUB 类内部契约）
            │       └── EpubViewPlusRenderer（具体实现）
            │
            └──→ PdfRenderer（M4 加入，UI 零改动）
                    └── PdfiumRenderer / PDF.js Renderer
```

`ReaderEngine` 让 UI 不知道格式；`EpubRenderer` 让 EPUB 内部多个实现可替换（spike 报告的 pivot 风险使这层抽象有据可依）。

### 3.3 与 M1 数据层的衔接

| M1 组件 | M2 用途 |
|---|---|
| `LocalReadingProgressRepository` | 读上次 CFI / 写新 CFI |
| `BooksDao` | 取 `Book` → 转 `BookRef` |
| `FileStorage` | 取 EPUB 原文件路径 |
| `Locator` sealed class（M1） | 进度复用 |
| `TypographySettings`（M1） | 渲染参数 |

**不新增 DB 表**——M2 不引入高亮/笔记，schema 不动。

---

## 4. 组件

### 4.1 ReaderEngine 接口

```dart
abstract interface class ReaderEngine {
  ReaderEngineState get state;          // unloaded / loading / ready / error
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
}
```

### 4.2 EpubRenderer 接口

```dart
abstract interface class EpubRenderer {
  Widget build(BuildContext context);
  Future<void> open(EpubBook book);
  Stream<Locator> get currentLocation$;
  Future<void> gotoLocator(Locator locator);
  Future<void> setTypography(TypographySettings settings);
  Future<void> setPaginationMode(PaginationMode mode);
  Future<void> dispose();
}
```

### 4.3 模型类

| 模型 | 位置 | 状态 |
|---|---|---|
| `Locator`（sealed）+ `EpubCfiLocator` / `PdfPageLocator` | `reader_engine/lib/core/locator.dart`（M1 在 `app/lib/core/`，M2 W1 迁入） | M1 已有 |
| `TypographySettings` | `reader_engine/lib/core/typography_settings.dart`（同上迁移） | M1 已有 |
| `TableOfContents` / `TocEntry` | `reader_engine/lib/navigation/toc.dart` | **M2 新增** |
| `PaginationMode`（paged / scroll） | `reader_engine/lib/rendering/pagination_model.dart` | **M2 新增** |
| `BookRef`（轻量引用：id + 文件路径 + 格式） | `reader_engine/lib/core/book_ref.dart` | **M2 新增** |
| `ReaderEngineState`（sealed） | `reader_engine/lib/reader_engine.dart` | **M2 新增** |

`BookRef` 设计：仅含 engine 需要的字段（id、文件路径、格式、标题），避免 engine 持有完整 Book 聚合根（后者还含阅读进度、笔记聚合等不属于渲染职责的数据）。

### 4.4 EpubViewPlusRenderer

- 包装 `epub_view_plus.EpubView` 与 `EpubViewPlusController`
- 在 `open()` 中：解析 → 注入 TypographySettings 转换的 CSS → 注册到 controller
- `currentLocation$` 来自 controller 的 CFI 流，经 `cfi_codec` 编码为 `EpubCfiLocator`
- `gotoLocator` 反向解码

`cfi_codec.dart` 是**纯函数模块**（无 Flutter 依赖），单测极快。这是 spike 报告中识别的高风险点（CFI 不稳定），独立模块化便于：
1. 单测覆盖各种 CFI 边界
2. pivot 时整文件替换

### 4.5 UI 组件

| 组件 | 职责 |
|---|---|
| `ReaderPage` | 路由入口（go_router 注册 `/book/:id`），挂载 `ReaderEngineProvider`，注入 `BookRef` |
| `ReaderScaffold` | 沉浸式容器，检测 tap 位置分发：中央 → toggle chrome；左 1/3 → 上一页；右 1/3 → 下一页 |
| `ReaderAppBar` | 顶部 chrome：返回 / 标题 / more |
| `ReaderBottomBar` | 进度条 + 章节标题 + 页码百分比 |
| `TocDrawer` | 侧滑目录，列表来自 `engine.toc` |
| `TypographyPanel` | 底部弹层：字号 / 行距 / 主题 / 字体 |

---

## 5. 数据流

### 5.1 打开书籍主流程

```
ReaderPage(bookId)
  → BookRefLoader(bookId) ──→ BookRef
  → ReaderEngineProvider.create(bookRef)
        ├── 选 EpubViewPlusRenderer（按 bookRef.format）
        ├── renderer.open(EpubBook)（异步，~200-800ms）
        │     ├── FileStorage 取文件
        │     ├── epub_view_plus 解析
        │     ├── 注入 TypographySettings CSS
        │     └── 拉取 spine / TOC
        ├── 状态：unloaded → loading → ready
        └── 启动后：LocalReadingProgressRepository 取上次 CFI
              → renderer.gotoLocator(lastCfi)
              → 订阅 currentLocation$
```

### 5.2 位置变化 → 进度持久化

```
renderer.currentLocation$
  → debounce 500ms                          ← 防抖：连续翻页不狂写
  → distinct（同 CFI 不写）                  ← 章节内同一位置不重复
  → LocalReadingProgressRepository.upsert(bookId, locator)
  → 静默失败（log warn，不阻塞 UI）          ← 进度是软数据，不能让 IO 卡阅读
```

**关键决策的理由**：
- **500ms 防抖**：用户快速翻页时只写一次。500ms 是经验值（人眼连续翻页间隔通常 < 400ms）
- **distinct**：epub_view_plus 内部位置流可能重复触发同一 CFI
- **静默失败**：磁盘满 / IO 异常不该让阅读卡住，但要在 `Logger` 留痕

### 5.3 翻页交互

```
用户 tap
  → ReaderScaffold 检测 tap 位置
       ├── 中央 → toggle chrome
       ├── 右 1/3 → PaginationMode.paged：下一页；scroll：无操作
       └── 左 1/3 → PaginationMode.paged：上一页；scroll：无操作
```

scroll 模式下 tap 左右无意义（用户在滚动），tap 中央仍切换 chrome。

### 5.4 排版变更流

```
TypographyPanel → engine.setTypography(new)
  → renderer.setTypography(new)
       → 重新生成 CSS 注入
       → 当前位置保持（通过 currentLocation$ 流读取最近一次 CFI，CSS 注入后 gotoLocator 回去）
  → TypographySettingsRepository.persist（M1 已有）
```

**风险点**：CSS 重新注入可能导致位置漂移（epub_view_plus 重新分页）。M2 W1 需要验证；若漂移 > 1 章，降级为"排版变更后跳到章节开头"。

---

## 6. 错误处理

### 6.1 错误分级

| 级别 | 场景 | 处理 |
|---|---|---|
| **Fatal** | 文件不存在 / 损坏 / 解析失败 | 显示 `ReaderErrorView`（重试 + 返回）；log |
| **Recoverable** | 单章节渲染异常 | 跳过该章 + 顶部 banner 提示；继续阅读 |
| **Soft** | 进度写库失败 | 静默 log；UI 不感知 |

### 6.2 EPUB 加载超时

`renderer.open()` 加 **15s 超时**（大书正常 800ms，15s 兜底）；超时归到 Fatal，提示"文件可能损坏"。

### 6.3 CFI 解码失败

epub_view_plus 的 CFI 实现不稳定（spike 报告关键风险）。如果 `gotoLocator(lastCfi)` 失败：
1. log warn（带原 CFI 字符串）
2. 降级到第一章开头
3. 不阻断用户继续阅读

**M2 W1 验证点**：如果失败率 > 1%，启动 pivot（epubx + 自研 widget）。

---

## 7. 测试策略

### 7.1 测试分层

| 层级 | 范围 | 工具 | 目标数 |
|---|---|---|---|
| 单元（纯 Dart） | `cfi_codec`、`toc_builder`、Locator 转换 | `package:test` | ~30 |
| 单元（Flutter 依赖） | `ReaderEngine` 状态机、进度防抖逻辑 | `flutter_test` | ~15 |
| Widget | `ReaderScaffold`、`TocDrawer`、`TypographyPanel` | `flutter_test` + Riverpod `ProviderScope` | ~12 |
| Golden | 渲染快照（不同 TypographySettings × 3 fixture EPUB） | `golden_toolkit` | ~6 |
| 集成 | 端到端：打开 → 翻页 → 退出 → 重开恢复进度 | `integration_test` | ~3 |

### 7.2 Fixture EPUB

放在 `app/test/fixtures/`（不入库，`.gitignore` 排除），README 记录下载源：

| 书 | 用途 |
|---|---|
| `page-blanche.epub`（标准英文 EPUB） | 基线渲染 |
| `kite-runner-cn.epub`（中文 reflowable） | 中文排版 baseline |
| `weicheng.epub`（带复杂 TOC + 嵌套 spine） | TOC / spine 正确性 |
| `bad-cfi.epub`（构造异常 CFI） | 错误恢复 |

### 7.3 Golden 失败策略

Golden 夆败时 `flutter test --update-goldens` 必须由**人工 review 后**才能更新；CI 拒绝 auto-update commit。Golden 文件存 `app/test/goldens/`，平台相关（Linux baseline，Windows 不强制匹配）。

### 7.4 关键单测示例

进度防抖：
```dart
test('rapid location changes only persist once after 500ms idle', () async {
  // 模拟连续翻 5 页 + 500ms 静默
  // 断言 repository.upsert 只被调用 1 次
});
```

CFI 编解码 round-trip：
```dart
test('cfi_codec encode(decode(x)) == x for valid CFIs', () {
  for (final cfi in validCfiSamples) {
    expect(codec.encode(codec.decode(cfi)), cfi);
  }
});
```

---

## 8. 关键风险

| 风险 | 缓解 |
|---|---|
| epub_view_plus CFI 不稳定 | M2 W1 跑真实中文 EPUB 验证；失败率 > 1% 则 pivot 到 epubx + 自研 widget |
| 中文标点避头尾无原生支持 | best-effort via TextPainter hook；完整方案在 M3+ |
| Golden 在 Windows 上字体差异 | CI 跑 Linux golden；本地 Windows 可忽略 |
| CSS 重新注入导致位置漂移 | M2 W1 验证；漂移 > 1 章则降级为跳到章节开头 |

---

## 9. 验收标准（M2 完成定义）

1. 能打开 EPUB 2 / EPUB 3 reflowable，渲染正确（无乱码、无错位）
2. 双模式翻页工作；模式切换持久化
3. 目录导航工作（含嵌套）
4. 退出后重开恢复到上次 CFI 位置（容差 < 100 字符）
5. 排版设置（字号 / 行距 / 主题 / 字体）即时生效
6. 全部单测 + widget + golden + 集成测试通过
7. 中文 EPUB 可读（含基本标点处理）
8. `ReaderEngine` 抽象允许 M4 PDF 加入时 UI 零改造（用 mock PdfRenderer 验证）

---

## 10. 工期估算

> ⚠️ **2026-06-26 修订**：原 6 周计划因 `epub_view_plus` 实际未发布到 pub.dev 而 pivot 到 `epubx` + 自研渲染（详见 §11 与附录 A）。工期扩到 12 周，原 W6 buffer 现已使用。

| 周 | 主任务 |
|---|---|
| W1 | ~~spike 真实 EPUB~~ + 基础架构落地（已完成 Tasks 1-6：M1 模型迁移到 `reader_engine/`、`ReaderEngine` 抽象、fixture 引入） |
| W2 | epubx 解析 + HTML 渲染（用 `flutter_widget_from_html` 把 `EpubChapter.HtmlContent` 转 Flutter widgets）+ spike 验证 |
| W3 | 自研分页算法（TextPainter 测高 + 章节切片）+ paged 翻页 |
| W4 | scroll 翻页 + TOC 提取（walk `EpubBook.Chapters` 递归）+ 进度持久化 |
| W5 | 排版注入（CSS-like 主题、字号、行距映射到 widget tree）+ 错误处理 |
| W6 | ReaderEngineProvider + 打开书籍主流程 + ReaderPage 装配 |
| W7 | Widget 测试补全（所有 UI 组件） |
| W8 | Golden 测试（6 个渲染快照，覆盖 paged/scroll × 中文/英文 × 主题） |
| W9 | 集成测试（端到端阅读流程） |
| W10 | 自研 CFI（参考 EPUB CFI 规范，自定义 `chapterIndex:charOffset` 格式，编码/解码 round-trip） |
| W11 | buffer（自研分页/CFI 边界 case、性能优化） |
| W12 | 最终全局 code review + 验收清单 |

总计 12 周。原 6 周计划的 W6 buffer 专为 pivot 预留，现已使用并扩到 W11-W12。**不允许再溢出**——再遇重大风险须 user 介入重新评估 M2 范围。

---

## 11. 与平台 spec 的偏差

| 偏差点 | 原因 | 影响 |
|---|---|---|
| M2 合并 M3 的"基础排版" | 用户决策：M2 结束即可获得完整基础阅读体验 | M3 工期缩短约 1 周 |
| 仅 reflowable，不做 fixed-layout | spike 验证：fixed-layout 需 WebView，`flutter_inappwebview` Windows 实验性不稳 | 后续若用户强需求，单独立项 |
| `vepub` 不存在（原 spec 候选库） | spike 发现 pub.dev 无此包（疑似笔误） | 改用 `epub_view_plus` |
| **`epub_view_plus` 实际未上 pub.dev**（2026-06-26 发现） | spec 假设破裂：原计划用的 `epub_view_plus` 只在 GitHub，未发布 pub.dev；备选 `epub_view` v3.2.0 在 pub.dev 但有 CFI bug 且无维护 | **pivot 到 `epubx` + 自研渲染**——工期 6 周 → 12 周（详见 §10） |
| 新增 `reader_engine_epub_view` 独立 package | 原平台 spec 倾向 monolithic，本设计强化隔离 | M4 PDF 加入时零 UI 改造 |
| M1 模型 (`Locator` / `TypographySettings`) 迁入 `reader_engine/` 包 | M2 引入独立 package，依赖方向需单向；M1 模型留在 `app/` 会形成循环依赖 | W1 多 0.5 天迁移成本，`app/lib/core/` 改为 re-export 保 M1 测试 API 兼容 |
| **自研分页 + CFI**（pivot 后新增） | `epubx` 是纯 parser，无渲染层；原计划 `epub_view_plus` 提供的 TextPainter 分页、CFI 生成全部需自建 | +5 周工期（W3 分页 + W10 CFI + W11 buffer）|

---

## 附录 A：选型记录（spike 结论摘要 + pivot 后修订）

### A.1 原选型（2026-06-25，已废弃）

通过 opus subagent 对 pub.dev 上 5 个候选 EPUB 渲染库做 hands-on 调研：

| 候选库 | 结论 |
|---|---|
| `epub_view_plus`（活跃 fork） | ~~采用~~ — **实际未发布 pub.dev**，只在 GitHub `hosseinshaya/epub_view_plus` |
| `epub_view`（原版，ScerIO） | 淘汰 — CFI bug #361/#499/#567，作者已挂出寻找新维护者 |
| `vepub` | 淘汰 — **pub.dev 不存在此包**（疑似笔误） |
| `flutter_epub_viewer` / `sakura_epub` | 淘汰 — 走 epub.js + WebView 路径，`flutter_inappwebview` Windows 实验性不稳 |
| `epubx` | ~~备选 pivot 路径~~ — **pivot 已触发，详见 A.2** |

### A.2 2026-06-26 pivot 决策

**触发**：M2 Task 7（创建 `reader_engine_epub_view` package）执行时验证发现 `epub_view_plus` 实际未发布到 pub.dev。implementer 单方面替换为 `epub_view` v3.2.0，但这是 spec 明确淘汰的包（CFI bug、无维护）。controller 升级到 user，user 选 **D 选项：立刻 pivot 到 epubx + 自研**。

**新方案**：
- **`epubx` ^4.0.0**（pub.dev）：纯 Dart parser，API `EpubReader.readBook(bytes) → EpubBook { Title, Chapters[EpubChapter{Title, HtmlContent, SubChapters}] }`，无 `dart:io` 依赖
- **`flutter_widget_from_html`**：把 `EpubChapter.HtmlContent` 转 Flutter widget 树（pending spike 验证排版质量）
- **自研分页**：基于 TextPainter 测高，按 viewport 切片章节内容
- **自研 CFI**：参考 EPUB CFI 规范，简化为 `chapterIndex:charOffset` 格式，编码/解码 round-trip 一致即可

**工期影响**：6 周 → 12 周（详见 §10）。W6 buffer 现已使用，新增 W7-W12 容纳自研分页、CFI、额外 buffer。

**为什么不用 git 依赖 `epub_view_plus`**：用户评估 git 依赖稳定性 + fork 实际是否有 CFI 修复未验证，风险大于直接 pivot。Pivot 一次到位，避免半路再 pivot。

**为什么不用 `epub_pro` 等其他 pub.dev fork**：spec §A.1 候选库调研未覆盖，重新做 spike 等于多一次不确定的赌注。`epubx` 是 spec 已识别的备选路径，路径已知。
