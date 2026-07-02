# M2.5 — Reader UX Overhaul Design

> **状态**：Draft（待用户 review）
> **版本目标**：v1.5.0-alpha（双 tag `m2.5-complete` + `v1.5.0-alpha`）
> **工期估计**：3-4 周（~15 个 task）

## 1. Goal

修复用户实测发现的 2 个 P0 bug，并交付 8 项阅读器 UX 改进/新功能，让基础阅读体验达到成熟阅读器水准（Kindle / Apple Books 桌面端基线）。

**交付后用户可见变化**：
- ✅ EPUB 高亮真的会变色
- ✅ 笔记列表点击真的能跳回原处
- ✅ 键盘 ←/→/↑/↓、鼠标滚轮、触摸滑动、单击左右侧 4 种翻页方式都能用
- ✅ AppBar 默认常驻（不再隐藏），全屏模式由用户主动进入
- ✅ 一键加书签 + 书签备注 + 多入口查看
- ✅ 宽屏自动启用左侧常驻 TOC sidebar（可折叠）
- ✅ 默认边距调大，新档位 ExtraWide=40
- ✅ 合并「高亮」+「笔记」按钮为单一「摘录」
- ✅ 宽屏 + paged 模式 → 双页布局（EPUB + PDF 都支持）

---

## 2. Scope

### 2.1 包含

| # | 项 | 类型 | 复杂度 |
|---|---|---|---|
| 1 | PDF 加载 | ✅ 已修（commit `a435048`，M2.4 之外） | — |
| 2 | 4 种翻页输入 | 增强 | M |
| 3 | chrome 默认显示 + 全屏模式 | 增强 | M-L |
| 4 | EPUB 高亮渲染（bug） | bug | S |
| 5 | 合并高亮/笔记按钮 | cleanup | S |
| 6 | 笔记点击回原处（bug） | bug | S |
| 7 | 书签（schema + sync + UI） | 新功能 | L |
| 8 | TOC sidebar 折叠/展开 | 增强 | M |
| 9 | 内容边距调档 | 增强 | S |
| 10 | 双页布局（EPUB + PDF） | 新功能 | L |

### 2.2 不包含

- iOS / macOS 端适配（仍仅 Windows + Android）
- 跨书 AI 伴读（v1.6+）
- 性能 baseline 测量（仍延后到 v1.6）
- 209 个测试文件的 AGPLv3 头补齐（独立 hygiene task）
- drift v1→v9 migration e2e 测试（独立 hygiene task）

---

## 3. Architecture Decisions

### 3.1 State 扩展

`ReaderUiState` 新增字段（`app/lib/features/reader/controllers/reader_ui_controller.dart`）：

```dart
class ReaderUiState {
  final bool chromeVisible;          // 现有（默认值改 true）
  final bool isFullscreen;           // 新增：全屏模式（默认 desktop=false, mobile=true）
  final bool tocSidebarCollapsed;    // 新增：宽屏 sidebar 折叠状态
  final DrawerTab activeDrawerTab;   // 新增：drawer 当前 tab（toc/bookmarks/notes）
  // ... 其他字段不变
}

enum DrawerTab { toc, bookmarks, notes }
```

**默认值平台分支**：
- Windows / macOS desktop：`chromeVisible=true, isFullscreen=false, activeDrawerTab=toc`
- Android / iOS：`chromeVisible=false, isFullscreen=true, activeDrawerTab=toc`

平台分支判断：`defaultTargetPlatform.isMobile`（不引入新依赖）。

### 3.2 Drawer 重构

**当前**：左 drawer = TOC，右 endDrawer = Notes。

**新设计**：左侧 drawer 单一容器，内含 `TabBar`（目录 / 书签 / 笔记），右 endDrawer 删除。`activeDrawerTab` state 控制当前显示哪个 tab。

宽屏（>= 1100px）：drawer 行为切换为「常驻 sidebar」（不滑出，不遮挡）：
- 未折叠：宽 280px，含 TabBar + 当前 tab 内容
- 折叠：宽 40px，仅显示一个"展开"图标按钮（垂直居中）

窄屏（< 1100px）：保持当前 Drawer 行为（点图标弹 drawer）。

`LayoutBuilder` 在 `reader_scaffold.dart` 顶层判断宽度，切换两种渲染模式。

### 3.3 翻页输入（4 种）统一架构

在 `ReaderBody` 顶层包一个 `Stack`：
1. 最底层：实际渲染区（EPUB / PDF）
2. 中层：`GestureDetector`（tap + horizontal drag）
3. 最上层：`KeyboardListener`（键盘）+ `Listener`（滚轮）

**手势分发**：
- `onTapUp`：根据 tap 位置 x 坐标分三段
  - x < width * 0.33 → `engine.goPrevPage()`
  - x > width * 0.66 → `engine.goNextPage()`
  - 中间 1/3 → no-op（chrome 不再 toggle，由 #3 接管）
- `onHorizontalDragEnd`：判断 velocity
  - 向左拖（velocity > 200）→ `goNextPage()`
  - 向右拖（velocity < -200）→ `goPrevPage()`

**键盘**（`KeyboardListener` + `FocusNode`）：
- ← / PgUp → `goPrevPage()`
- → / PgDn → `goNextPage()`
- ↑ → scroll up（scroll 模式）/ `goPrevPage()`（paged 模式）
- ↓ → scroll down（scroll 模式）/ `goNextPage()`（paged 模式）
- Escape → exit fullscreen（若在全屏模式）
- F11 → toggle fullscreen

**滚轮**（`Listener.onPointerSignal`，仅 paged 模式生效）：
- scroll up → `goPrevPage()`
- scroll down → `goNextPage()`
- scroll 模式由 EPUB `ListView` 自带的滚轮处理（不拦截）

### 3.4 全屏模式

**进入全屏**：
- 点 AppBar 右上角 `fullscreen` 图标 → `setIsFullscreen(true)`
- 桌面键盘 F11

**全屏内行为**：
- `chromeVisible` 强制 false，AppBar 不渲染
- 移动端：`SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` 隐藏 status bar
- 桌面：`windowManager.setFullScreen(true)`（需加 `window_manager` 依赖；或退而求其次用 `SystemChrome.setEnabledSystemUIMode`，但 Windows 桌面端效果有限——见 §10 Risks）

**退出全屏**：
- 桌面 Esc 键 / F11 / 鼠标移到屏幕顶部 1px 触发区显示「退出全屏」按钮
- 移动端系统返回键（`PopScope` 拦截） / 双击屏幕中心召唤 chrome 后点 fullscreen_exit 图标

**双击中心召唤 chrome（仅全屏时）**：
- 全屏模式下双击屏幕中心 1/3 区域 → 临时显示 AppBar + bottom controls（5 秒后自动隐藏，或用户再次双击）

### 3.5 书签数据模型

新增 drift 表（`app/lib/data/local/tables/bookmarks.dart`）：

```dart
@DataClassName('BookmarkEntry')
class Bookmarks extends Table {
  TextColumn get id => text()();                              // ULID
  TextColumn get bookId => text().customConstraint('NOT NULL REFERENCES books(id) ON DELETE CASCADE')();
  TextColumn get locatorJson => text()();                     // JSON-encoded Locator
  TextColumn get label => text()();                           // 用户输入的标题（默认"第 N 页"或章节名 + offset）
  TextColumn get note => text().nullable()();                 // 可选备注
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  
  @override Set<Column> get primaryKey => {id};
}
```

drift schema v10 migration（`app/lib/data/local/database.dart`）：新增表 + 索引。

### 3.6 Sync 扩展

`app/lib/sync/` 的 entity map 加入 `bookmarks`：
- push：本地 bookmarks 全量推送到 WebDAV（与 annotations 同策略）
- pull：远端 bookmarks 合并（last-write-wins on `updatedAt`）
- conflict：与 annotations 同样走 `ConflictSink` 日志

文件命名约定：`bookmarks/{bookId}.json`（与 `annotations/{bookId}.json` 平行）。

### 3.7 双页布局策略

**触发条件（三者 AND）**：
- 窗口宽度 >= 1200px（`LayoutBuilder` 判断）
- 当前为 paged 模式（`PaginationMode.paged`）
- 用户已启用「双页浏览」（默认 true，桌面端可关）

**PDF 实现**：
- 替换单 `PdfViewer` 为并排两个（`Row` 内两个 `PdfViewer`）
- 左：page N（偶数页，左书页）
- 右：page N+1
- 翻页：一次跳 2 页（`goNextPage` → `_currentPage += 2`）
- 起始页特殊处理：cover（page 1）单独显示，从 page 2 开始双页

**EPUB 实现**（更复杂）：
- `EpubxRenderer` 的 paged 分页算法改造：将原本"一页"的内容翻倍，按宽度 50% 切两半
- 实际渲染：`Row` 内两个 `Column`，每个 `Column` 是一个虚拟"书页"
- `PaginationBreaks` 缓存：双页模式下重新计算（每两个屏幕宽 = 1 个 PaginationBreak）
- 翻页：一次跳双页（2 个虚拟页 = 1 次物理翻页）

**LayoutBuilder 响应**：
- 窗口宽度变化时（拖拽边界），自动切换单/双页
- 切换时保留当前 locator（重新分页后 scroll 到对应位置）

### 3.8 高亮渲染 bug 修复

**根因**：`reader_body.dart` 缺少 `ref.listen<NotesState>` 把 annotations 推给 `engine.injectHighlights()`。

**修复**：在 `_ReaderBodyState.build()` 加：
```dart
ref.listen<AsyncValue<NotesState>>(notesControllerProvider, (_, async) {
  final s = async.valueOrNull;
  if (s == null) return;
  final ranges = s.annotations.map(_annotationToHighlightRange).toList();
  engine.injectHighlights(ranges);
});
```

`_annotationToHighlightRange`：从 `Annotation.locator`（`EpubRangeLocator`）+ `Annotation.colorRgba` 映射到 `HighlightRange`。

**过滤**：renderer 当前 `currentHighlightedHtml()` 是 chapter-agnostic（不按章节过滤），意味着所有章节的高亮都会注入到当前渲染的 HTML。这是性能问题但不是正确性问题（CSS 选择器只匹配对应文本）。修复时不改这个行为。

### 3.9 笔记跳转 bug 修复

**根因**：`EpubxRenderer.gotoLocator` 只处理 `EpubCfiLocator`，annotations 存的是 `EpubRangeLocator`。

**修复**（`reader_engine_epub_view/lib/epubx_renderer.dart:404-405`）：
```dart
Future<void> gotoLocator(Locator locator) async {
  if (locator is EpubCfiLocator) {
    // 现有 CFI 分支
  } else if (locator is EpubRangeLocator) {
    // 新增：直接用 chapterIndex 切章，跳过 CFI 解析
    if (locator.chapterIndex != _currentChapterIndex) {
      _currentChapterIndex = locator.chapterIndex;
      _cachedBreaks = null;
      _beginChapterSwitch();
    }
    // 精确 scroll 由调用方（reader_body 的 ScrollToOffsetService）处理
  }
  // PdfPageLocator / PdfRangeLocator 等：no-op（不应到达这里）
}
```

PDF 路径已正确（`PdfRenderer.gotoLocator` 已处理 `PdfPageLocator`），不动。

---

## 4. Data Model Changes

### 4.1 新增

- `Bookmarks` 表（§3.5）
- `ReaderUiState.isFullscreen`、`tocSidebarCollapsed`、`activeDrawerTab`
- `TypographySettings.dualPageMode: bool`（per-book override 表 `BookTypographyOverrides` 的 JSON 加此字段）
- `TypographySettings.pageMargin` 新增 ExtraWide=40 档位（enum 扩展）

### 4.2 迁移

- drift schema v9 → v10：`CREATE TABLE bookmarks (...)` + 索引
- 现有 `TypographySettings` JSON 反序列化兼容：未含 `dualPageMode` 字段时默认 false
- 现有 `pageMargin` 字段值（0/1/2）保持含义不变（Compact/Normal/Wide），新增 3 = ExtraWide
- `ReaderUiState` 的默认值变更不影响存储（state 是 in-memory，每次启动重置）

### 4.3 不变

- `Annotation` 表无变化（#5 仅 UI 层合并按钮）
- `books` 表无变化
- sync entity `annotations` 协议不变

---

## 5. UI / UX Specifications

### 5.1 AppBar（reader_scaffold.dart）新增图标

非全屏模式下 AppBar 从左到右：
1. ← 返回
2. TOC（开 drawer）
3. 排版（弹 typography panel）
4. 笔记（开 drawer，activeDrawerTab=notes）
5. **新增：书签**（开 drawer，activeDrawerTab=bookmarks；长按 → 快速加书签到当前页）
6. **新增：全屏**（fullscreen 图标）
7. AI 导读 / Q&A（保留）

全屏模式下 AppBar 不渲染。

### 5.2 摘录底部 sheet（合并高亮/笔记）

替换当前 toolbar 的「高亮」+「笔记」按钮为单一「摘录」按钮，点击弹底部 sheet：

```
┌──────────────────────────────────┐
│  摘录                             │
├──────────────────────────────────┤
│  ⬤ ⬤ ⬤ ⬤ ⬤   ← 5 色选择        │
│  (默认选中第 3 个黄色)            │
├──────────────────────────────────┤
│  备注（可选）                     │
│  ┌──────────────────────────────┐│
│  │ 多行输入框                   ││
│  └──────────────────────────────┘│
├──────────────────────────────────┤
│      [取消]      [保存]           │
└──────────────────────────────────┘
```

保存动作：写入 `Annotation(colorRgba, locator, note?)`，关闭 sheet，notesController 流自动通知 drawer + reader_body 高亮重渲染（bug #4 修完后）。

### 5.3 书签 dialog

点 AppBar 书签图标，若当前页已有书签 → 弹「编辑书签」dialog（预填）；若无 → 弹「新增书签」dialog：

```
┌──────────────────────────────────┐
│  新增书签                         │
├──────────────────────────────────┤
│  标题                             │
│  ┌──────────────────────────────┐│
│  │ 第 N 页 / 章节名             ││  ← 默认值，可改
│  └──────────────────────────────┘│
│  备注（可选）                     │
│  ┌──────────────────────────────┐│
│  │                              ││
│  └──────────────────────────────┘│
├──────────────────────────────────┤
│      [取消]      [添加]           │
└──────────────────────────────────┘
```

AppBar 书签图标状态：当前页已有书签 → 实心 (`bookmark_filled`)；无 → 空心 (`bookmark_outline`)。

### 5.4 Drawer 三 tab

```
┌──────────────────────────────────┐
│  [目录] [书签] [笔记]   ← TabBar   │  ← 宽 280px
├──────────────────────────────────┤
│                                  │
│  当前 tab 内容                    │
│  （目录：章节树 / 书签：列表 /    │
│   笔记：annotation 列表）         │
│                                  │
│                                  │
└──────────────────────────────────┘
```

宽屏常驻模式：drawer 永远显示；窄屏模式：点 TOC/笔记/书签图标弹 drawer 并切到对应 tab。

### 5.5 TOC sidebar 折叠按钮（仅宽屏）

宽屏 sidebar 顶部右侧加小图标按钮：
- 展开状态：点击 → 折叠为 40px 细条（仅一个 → 图标）
- 折叠状态：点击 → 展开回 280px

折叠状态时整个 reader 横向空间扩大，仅顶部 AppBar + 右侧 40px 细条占用宽度。

---

## 6. Test Strategy

### 6.1 单元测试

- `BookmarkController` test：add/list/delete/编辑
- drift migration v9→v10 test：建表 + 索引 + 回滚
- `EpubxRenderer.gotoLocator` 多 locator 类型 test（CFI / Range / 其他）
- `HighlightRange` mapping test（Annotation → HighlightRange）
- `TypographySettings.dualPageMode` 序列化兼容 test

### 6.2 Widget 测试

- `ReaderScaffold` 三 tab drawer 渲染 + 切换
- `ReaderSelectionSheet`（合并 sheet）色选 + 备注输入 + 保存
- `ReaderBookmarkDialog` 新增 + 编辑
- `ReaderBookmarkList` 渲染 + 点击跳转
- 双页布局 `LayoutBuilder` 响应（宽屏双页 / 窄屏单页切换）
- 全屏模式进入/退出（Esc / F11）
- TOC sidebar 折叠/展开（宽屏专属）
- 键盘翻页（←/→/↑/↓/PgUp/PgDn/F11/Esc）
- 鼠标滚轮翻页（paged 模式）
- 触摸滑动翻页（horizontal drag）
- 单击左/中/右三分翻页

### 6.3 Bug 回归测试

- **#4 highlight**：write annotation → `engine.injectHighlights()` 被调用 → `_allHighlights` 非空 → `currentHighlightedHtml()` 含 `<span style="background-color:...">`
- **#6 deep-link**：NotesPage tap → `engine.gotoLocator(EpubRangeLocator)` → `_currentChapterIndex` 更新 → 非 no-op

### 6.4 Sync 测试

- bookmark push/pull round-trip
- bookmark conflict（同 bookId 同 id 不同 updatedAt）→ last-write-wins + conflict log

### 6.5 集成测试

- EPUB 高亮 → 关 app → 重开 → 高亮仍在 + 渲染正确
- 书签添加 → 关 app → 重开 → 书签列表正确
- NotesPage tap → reader 跳转 → scroll 到精确位置
- 桌面端宽屏 → 双页自动启用 → 拖拽窗口缩小到 1100px → 单页切换

---

## 7. Backwards Compatibility

- v1.4.0-alpha 用户的本地 DB 升级到 v10 自动建 bookmarks 表
- 现有 TypographySettings JSON 不含 dualPageMode → 默认 false（用户主动开启）
- 现有 Annotation 数据无变化，notes drawer / NotesPage 行为不变（除了点击能跳转了）
- sync 协议向后兼容：旧客户端不识别 bookmarks 文件，但 annotations/progress/etc 不受影响
- 双页布局默认开启不影响单页用户——窗口 < 1200px 时强制单页

---

## 8. Risks & Mitigations

| 风险 | 影响 | 缓解 |
|---|---|---|
| Windows 桌面 `SystemChrome.setEnabledSystemUIMode` 效果有限（不像 mobile 真全屏） | 全屏体验打折 | 优先用 `window_manager` 包真原生全屏；fallback：仅隐藏 AppBar + 系统栏 |
| EPUB 双页分页算法改造复杂，可能引入分页错位 bug | 严重 | 单独立 T11 子任务，先 EPUB 单页保持稳定，双页用 feature flag 隔离；写分页算法单元测试覆盖 |
| drawer 重构（左 endDrawer 删除）破坏现有 navigation 测试 | 中 | 同步更新所有 widget 测试；旧 endDrawer key 移到新 drawer 的 notes tab |
| `EpubxRenderer.gotoLocator` 加新分支后，chapterSwitchSettled 时序变化 | 中 | 加 widget 测试覆盖「跨章节 + scroll」组合；现有 `reader_body_test.dart` 全跑过 |
| drift v10 migration 在大 DB 上慢 | 低 | bookmarks 表新表空 migration，O(1) 操作 |
| window_manager 依赖可能与现有 mutex/deep-link 冲突 | 低 | 先在独立分支 spike，确认无冲突再合并 |

---

## 9. Out of Scope

- iOS / macOS 端（仍仅 Windows + Android）
- 跨书 AI 伴读（v1.6+）
- 性能 baseline 测量
- AGPLv3 头补齐 209 个测试文件（独立 hygiene task）
- drift v1→v9 migration e2e 测试
- 阅读进度条（已有，不变）
- TTS 朗读
- 阅读统计 / 阅读时长追踪
- PDF 大纲跳转动画

---

## 10. Acceptance Criteria

**M2.5 完成的硬标准**：

1. **#4 修复**：用户在 EPUB 选中文字 → 摘录 → 选色 → 文字背景立即变色（截图证明）
2. **#6 修复**：从 NotesPage 任意条目点击 → reader 跳转到正确章节 + scroll 到精确位置（截图证明前后对应）
3. **#2 翻页**：4 种输入方式（键盘 / 滚轮 / 触摸滑动 / 单击左右）每种都有 widget 测试通过 + 现场验证可用
4. **#3 全屏**：桌面端 F11 / AppBar 全屏按钮 → 进入全屏 → Esc 退出 → 全部工作；移动端默认全屏 + 双击召唤 chrome
5. **#5 合并按钮**：toolbar 只有一个「摘录」按钮，旧「高亮」「笔记」按钮删除
6. **#7 书签**：AppBar 加书签 → drawer 书签 tab 看见 → 独立书签页看见 → tap 跳转 → 同步推送到第二台机器
7. **#8 TOC sidebar**：宽屏（>1100px）默认常驻 sidebar，可折叠为 40px 细条，可展开回 280px
8. **#9 边距**：默认 Normal=24px（原 16），新增 ExtraWide=40px；现有用户已选档位不变
9. **#10 双页**：宽屏（>=1200px）+ paged 模式 + 启用 → EPUB 双页 + PDF 双页都工作；窄屏或 scroll 模式自动单页
10. **测试**：全量 `flutter test --concurrency=1` 通过；新增 widget/unit 测试 >= 30 个
11. **静态分析**：`dart analyze` 在 4 个包（reader_engine / reader_engine_epub_view / reader_engine_pdf_view / app）全 0 errors / 0 warnings / 0 info
12. **sync 兼容**：v1.4.0-alpha 客户端能忽略 v1.5.0-alpha 推送的 bookmarks 文件而不报错
13. **双 tag**：`m2.5-complete` + `v1.5.0-alpha` 推送到 Gitee
14. **CHANGELOG**：补 `[1.5.0-alpha]` 段落
15. **README**：同步新功能 + 截图占位（截图实际捕获延后到 T8）

---

## 11. Open Questions

无重大未决问题。次要细节由 plan 阶段决定：
- `window_manager` vs `SystemChrome` for desktop fullscreen — 在 T（fullscreen）task 里 spike 后定
- EPUB 双页分页算法的具体实现细节 — 在 T（dual-page EPUB）task 里决定
- 书签 label 自动生成策略（"第 N 页" vs "章节名 + 段落序号"）— 在 T（bookmark）task 里决定

---

## 12. References

- 用户原始需求：本 session 2026-07-02 11 条 UX 反馈
- Bug #4 调查报告：本 session subagent output（agent #1）
- Bug #6 调查报告：本 session subagent output（agent #2）
- M2.4 完成 memory：`project_zhiyue_2026_07_02_review_fixups.md`
- 路线图：`docs/superpowers/specs/2026-06-28-phase2-roadmap-design.md`
- 项目级 Review：`docs/reviews/2026-07-01-project-review.md`
