# 智阅（Zhi Yue）电子书阅读平台 - 设计文档

> **项目代号**：智阅（Zhi Yue）—— 智慧阅读（暂定，可调整）
> **文档版本**：1.0
> **创建日期**：2026-06-24
> **协议**：AGPLv3
> **状态**：MVP 1.0 设计已定稿，待实现

---

## 1. 项目定位

### 1.1 一句话定位

面向**深度阅读/学习者**的开源 Flutter 电子书阅读平台，先做极致本地阅读体验，逐步叠加 AI 陪伴式学习与跨端同步。

### 1.2 项目约束（已与用户确认）

| 维度 | 决策 |
|---|---|
| **目标用户** | 深度阅读/学习者（非休闲读者） |
| **平台优先级** | Windows + Android（Mac 后期） |
| **技术栈** | Flutter（一套代码跨端） |
| **MVP 优先级** | 阅读体验 > AI 陪伴 > 同步 |
| **格式支持** | EPUB 完整 + PDF 文本基础 + PDF 扫描仅阅读 |
| **AI 能力（1.5+）** | AI 导读 / 伴随式问答 / 章节学习回顾 + 知识点提炼 |
| **AI 接入** | BYOK，先期仅适配 DeepSeek（API 兼容 OpenAI 格式） |
| **同步方案（2.0+）** | 坚果云 WebDAV（不自建后端） |
| **知识库** | App 内读书笔记库 + Markdown 导出（Obsidian 兼容） |
| **商业模式** | 免费开源 |
| **协议** | AGPLv3 |
| **仓库** | 单仓库，托管到 Gitee（weifu0523/e-book-reading-platform） |
| **本地化** | 中英双语（默认中文） |
| **资源** | 单人 + AI 辅助 |

### 1.3 分阶段路线图

| 阶段 | 范围 | 工期估算 |
|---|---|---|
| **MVP 1.0** | Flutter 阅读器（EPUB 完整 + PDF 阅读）+ 本地高亮/笔记 + 读书笔记库 + Markdown 导出 | ~18 周（4-5 个月） |
| **MVP 1.5** | AI 导读 + 伴随式问答（DeepSeek BYOK） | 后续规划 |
| **MVP 2.0** | 章节学习回顾 + 知识点提炼 + 坚果云 WebDAV 同步 | 后续规划 |
| **MVP 3.0+** | Zotero/Obsidian 双向同步、知识图谱、Mac 端等 | 长期 |

> **本文档聚焦 MVP 1.0 的设计**。后续阶段在大方向已定，细节留待各阶段开始前再规划。

---

## 2. 整体架构

### 2.1 分层架构

```
┌─────────────────────────────────────────────────────────────┐
│                   Flutter UI 层 (Material 3)                 │
│  书架 / 阅读器视图 / 笔记库 / 设置                              │
└────────────┬────────────────────────────────────────────┬───┘
             │                                            │
┌────────────▼─────────────────────────┐   ┌──────────────▼──────────────┐
│      阅读引擎层                        │   │      知识库层                │
│  ReaderEngine (抽象接口)               │   │  NotesRepository            │
│   ├─ EpubRenderer                     │   │   ├─ BookNote (一书一笔记)   │
│   └─ PdfRenderer                      │   │   ├─ Highlights             │
│  · 解析/渲染/分页/排版                  │   │   ├─ Annotations           │
│  · 高亮/笔记/书签/进度                  │   │   └─ MarkdownExporter     │
└────────────┬─────────────────────────┘   └──────────────┬──────────────┘
             │                                            │
┌────────────▼────────────────────────────────────────────▼─┐
│                  数据访问层 (Repository)                     │
│   BookRepository  (书籍元数据 + 文件)                        │
│   ReadingProgressRepository (进度)                          │
│   SettingsRepository (排版/字体/主题)                        │
└────────────────────────────┬───────────────────────────────┘
                             │
             ┌───────────────▼───────────────┐
             │      本地存储层                  │
             │  SQLite (drift) + 文件系统       │
             │  · 应用数据库                    │
             │  · 书库目录                      │
             │  · 缓存                          │
             └───────────────────────────────┘
```

### 2.2 核心设计原则

1. **本地优先（Local-First）**：所有数据本地 SQLite，App 完全离线可用。同步是后期叠加层，MVP 1.0 不出现。
2. **Repository 抽象**：所有数据访问走 Repository 接口。MVP 1.0 实现是本地 SQLite，接口设计成未来可替换为同步版 Repository（同步放 MVP 2.0，零重构）。
3. **ReaderEngine 抽象**：EPUB 和 PDF 走同一套 `ReaderEngine` 接口（打开/翻页/高亮/笔记/进度），UI 层不感知格式差异。新增格式（未来 MOBI/TXT）只需新增 Renderer 实现。
4. **隔离 + 单一职责**：UI / 引擎 / 数据 / 存储四层分离，每层可独立测试。`MarkdownExporter` 是独立模块，不耦合 UI。
5. **i18n 默认双语**：所有用户可见字符串走 `arb` 文件，默认中文，结构上预留英文。

### 2.3 仓库结构（单仓库）

```
e-book-reading-platform/
├── app/                      # Flutter 主项目
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/             # 跨模块共用 (主题/路由/i18n/错误)
│   │   ├── data/             # Repository 实现 + SQLite/文件 IO
│   │   ├── reader_engine/    # ReaderEngine 抽象 + EPUB/PDF Renderer
│   │   ├── features/         # 按功能模块组织 (书架/阅读器/笔记库/设置)
│   │   └── l10n/             # 中英双语 arb 文件
│   ├── assets/               # 内置字体/图标/默认主题
│   ├── test/                 # 单元测试
│   ├── integration_test/     # 集成测试
│   ├── pubspec.yaml
│   └── analysis_options.yaml
├── docs/                     # 项目文档（含本设计文档）
├── scripts/                  # 构建/打包脚本
├── LICENSE                   # AGPLv3
├── README.md
└── .gitignore
```

---

## 3. 阅读引擎层

MVP 1.0 工程量最大、最关键的部分。

### 3.1 ReaderEngine 抽象接口

```dart
abstract class ReaderEngine {
  /// 打开书籍，返回 BookInstance（含目录/元数据/上次进度）
  Future<BookInstance> open(BookSource source);

  /// 渲染到指定位置（页码 / CFI / 章节锚点）
  Future<void> navigateTo(Locator locator);

  /// 当前位置
  Locator get currentLocator;

  /// 进度回调（百分比、章节、CFI）
  Stream<ReadingProgress> get progressStream;

  /// 高亮操作
  Future<Highlight> addHighlight(Range range, HighlightStyle style);
  Future<void> removeHighlight(String highlightId);
  Stream<List<Highlight>> get highlightsStream;

  /// 笔记（挂载在高亮或位置上）
  Future<Annotation> addAnnotation(Locator anchor, String content);
  Future<void> updateAnnotation(String id, String content);

  /// 全文搜索
  Future<List<SearchResult>> search(String query);

  /// 排版设置（字号/行距/字体/主题/页边距）
  void applyTypography(TypographySettings settings);

  /// 释放资源
  Future<void> dispose();
}
```

### 3.2 EpubRenderer

- **底层**：基于 `epubx`（解析）+ 自研 widget 渲染（起步阶段评估 `epub_view` / `vepub`，不满足预期则 fork）。
- **支持**：分页、CSS 渲染、图片/字体资源、目录导航、CFI 定位（用于跨端同步的精度）。
- **高亮机制**：基于文本 Range + DOM 节点引用，持久化到 SQLite。
- **MVP 重点**：中文排版优化（标点避头尾、行高、字体）；夜间模式；字号无极调节。

### 3.3 PdfRenderer

- **底层**：基于 `pdfx` 或 `syncfusion_flutter_pdfviewer`（起步评估）。
- **文本版 PDF**：阅读 + 文本选择高亮 + 文本笔记（基于坐标 + 文本层）。
- **扫描版 PDF**：MVP 仅支持渲染翻页，**不做** OCR/选择/高亮。UI 上对扫描件明确提示"扫描件支持有限"。
- **重点**：大文件分块加载（避免 OOM）、缩放手势、跳页。

### 3.4 排版系统

调研报告强调"动态排版、响应式阅读体验"，单人 MVP 难以全做。MVP 1.0 收敛为：

| 维度 | MVP 1.0 | 后期 |
|---|---|---|
| 字号 | 5 档预设 + 自定义滑块 | 阅读速度自适应 |
| 字体 | 系统字体 + 内置 2-3 款中文衬线/无衬线 | 用户自定义导入 |
| 行距/字距 | 3 档预设 | 精细自定义 |
| 主题 | 日间 / 夜间 / 护眼（米黄）3 套 + 墨水屏（仅 Android）1 套 | 色温动态调节、自定义主题 |
| 页边距 | 紧凑 / 标准 / 宽松 3 档 | 响应窗口尺寸 |
| 全屏沉浸 | 一键隐藏所有 UI（含状态栏） | 番茄钟集成 |

排版设置存储粒度：**全局默认 + 单书覆盖**。

### 3.5 进度与定位系统

跨端同步的精度依赖于统一的 Locator 体系。MVP 1.0 即使不做同步，也要用：
- **EPUB CFI**（Canonical Fragment Identifier）作为 EPUB 的 Locator
- **PDF 用页码 + 坐标**作为 Locator

这样 MVP 2.0 加同步时无需迁移。

### 3.6 状态机

```
[未打开] → opening → [已打开/阅读中] 
                       ↓
                   [阅读中] ↔ [全文搜索]
                       ↓
                   [高亮/笔记编辑]
                       ↓
                   dispose → [已关闭]
```

---

## 4. 知识库层

### 4.1 数据模型

```
BookNote (一书一笔记，是知识库的主入口)
├── id: String (UUID)
├── bookId: String (FK → Book)
├── title: String (默认 = 书名 + "读书笔记")
├── summary: String (用户手写或后期 AI 生成)
├── keyTakeaways: List<String> (核心知识点，后期 AI 协助提炼)
├── createdAt / updatedAt: DateTime
└── annotations: List<Annotation>

Annotation (单条笔记/高亮)
├── id: String
├── bookNoteId: String (FK → BookNote)
├── locator: Locator (CFI 或 页码+坐标)
├── quote: String (原文摘录)
├── note: String? (用户笔记，可空)
├── color: HighlightColor (黄/绿/蓝/红/紫 5 色)
├── tags: List<String>
├── createdAt / updatedAt: DateTime
└── source: AnnotationSource (手写 / AI 辅助)
```

**设计要点**：
- `BookNote` 与 `Book` 是 1:1 关系，但分开存储——书可以删除而笔记保留（用户后悔药）。
- `Annotation` 同时承载"纯高亮"和"高亮 + 笔记"两种形态，`note` 可空。
- `color` 5 色对应不同语义（如黄色 = 重要、绿色 = 认同、红色 = 反对），用户可自定义语义映射。
- `tags` 自由文本标签，跨书搜索用。

### 4.2 知识库 UI

```
书架 (Home)
  └── 点击书 → 进入阅读器
  └── 长按书 → "查看读书笔记" → 进入 BookNote 编辑页

笔记库 Tab (Library 的二级 Tab)
  ├── 全部笔记 (按书分组)
  ├── 全部高亮 (跨书聚合，按时间/标签/颜色筛选)
  └── 搜索 (全文 + 标签)
```

### 4.3 Markdown 导出

**单书导出**（BookNote → 一个 .md 文件）：

```markdown
# 《书名》读书笔记

> 阅读时间：2026-03-01 ~ 2026-06-24
> 本书评分：⭐⭐⭐⭐ (可选)

## 核心摘要
（summary 内容）

## 核心知识点
- 知识点 1
- 知识点 2

## 高亮与笔记

### 第一章 · 章节名
> **(p.12)** 原文引用内容...
- 🟡 我的笔记：xxxx

### 第二章 · 章节名
> **(p.45)** 原文引用内容...
- 🔴 我的笔记：xxxx

## 标签
#心理学 #认知科学
```

**导出位置**：用户选择目录（Windows 用文件选择器，Android 用 SAF / `media_store`）。

**批量导出**：MVP 1.0 仅支持单书导出。批量（整个书架 → 一个 Obsidian vault）放 MVP 2.0。

**为 Obsidian 集成预留**：
- 导出格式严格使用 Obsidian 兼容的 Markdown（`[[wiki link]]` 风格标签、frontmatter 元数据）。
- 高亮颜色用 emoji 前缀（🟡🟢🔵🔴🟣）保证跨平台可见。
- 后期 MVP 2.0 加 Obsidian 集成时，仅需加"导出到指定 Vault 目录"选项。

### 4.4 搜索

- **范围**：书名 / 笔记正文 / 高亮原文 / 标签。
- **实现**：MVP 用 SQLite FTS5 全文索引（drift 支持）。性能足够 MVP 阶段使用。
- **筛选**：按书、按颜色、按标签、按时间范围。

---

## 5. 数据访问层与本地存储

### 5.1 SQLite 表结构（drift ORM）

```
books                       # 书籍元数据
  id (PK), title, author, cover_path, file_path, 
  format (epub/pdf), file_hash, file_size,
  added_at, last_read_at, reading_progress

book_notes                 # 读书笔记主表
  id (PK), book_id (FK), title, summary, 
  key_takeaways (JSON), created_at, updated_at

annotations                # 高亮与笔记
  id (PK), book_note_id (FK), locator (TEXT, JSON),
  quote, note, color, tags (JSON), source,
  created_at, updated_at
  -- FTS5 虚拟表 annotations_fts 同步索引 quote/note

reading_progress           # 阅读进度（独立于 book.reading_progress，更精细）
  book_id (PK), locator (TEXT), percent, 
  chapter_index, updated_at

typography_profiles        # 排版预设
  id (PK), name, settings (JSON), is_default

book_typography_overrides  # 单书排版覆盖
  book_id (PK), profile_id (FK), custom_settings (JSON)

settings                   # 全局设置（键值对）
  key (PK), value (TEXT, JSON-encoded)
```

**关键设计**：
- `locator` 统一用 JSON 文本存储（CFI 或 PDF 坐标），便于跨格式处理。
- `tags` / `key_takeaways` / `settings` 都用 JSON 字段，避免表过多。MVP 阶段够用，未来若查询压力大可拆表。
- FTS5 虚拟表通过 drift 的触发器机制保持同步。

### 5.2 文件系统布局

```
应用文档目录 (getApplicationDocumentsDirectory)
├── library/                          # 书库
│   ├── {file_hash}.epub              # 用 hash 去重存储
│   └── {file_hash}.pdf
├── covers/                           # 封面缓存
│   └── {book_id}.png
├── cache/                            # 渲染缓存（可清除）
│   └── {book_id}/
└── app.db                            # SQLite 数据库
```

**为什么用 file_hash 命名**：用户可能从不同路径导入同一本书，hash 去重避免重复占用空间。

### 5.3 Repository 接口

```dart
abstract class BookRepository {
  Future<List<Book>> getAll();
  Future<Book?> getById(String id);
  Future<Book> importFromFile(File file);  // 触发解析 + 入库
  Future<void> delete(String id);
  Stream<List<Book>> watchAll();  // 书架变化通知
}

abstract class ReadingProgressRepository {
  Future<ReadingProgress?> get(String bookId);
  Future<void> save(ReadingProgress progress);
  Stream<ReadingProgress> watch(String bookId);
}

abstract class NotesRepository {
  Future<BookNote?> getNoteByBook(String bookId);
  Future<void> saveNote(BookNote note);
  Future<List<Annotation>> getAnnotations(String noteId);
  Future<void> addAnnotation(Annotation a);
  Future<void> updateAnnotation(Annotation a);
  Future<void> deleteAnnotation(String id);
  Future<List<Annotation>> searchAnnotations(String query, {List<String>? tags});
}

abstract class SettingsRepository {
  T get<T>(String key, T defaultValue);
  Future<void> set<T>(String key, T value);
  Stream<T> watch<T>(String key);
}
```

**为什么用抽象接口而不是直接调 drift**：MVP 2.0 加 WebDAV 同步时，会写一个 `SyncedNotesRepository` 包装 `LocalNotesRepository`，UI 层零改动。

### 5.4 导入流程

```
用户选择文件 (Windows: 文件选择器 / Android: SAF)
  ↓
计算 file_hash
  ↓
检查是否已入库 (避免重复)
  ↓
解析元数据 (书名/作者/封面/目录)
  ↓
复制到 library/{file_hash}.{ext}
  ↓
插入 books 表 + 初始化空 BookNote
  ↓
通知 UI 刷新书架
```

---

## 6. UI 层与信息架构

### 6.1 信息架构（Tab 结构）

```
智阅
├── 📚 书架 (Home)
│   ├── 网格/列表切换
│   ├── 长按书 → 上下文菜单 (打开 / 笔记 / 详情 / 删除)
│   └── + 按钮 → 导入书籍
│
├── 📖 阅读器 (Reader)  ← 不在 Tab，从书架进入
│   ├── 顶部 AppBar (书名 / 章节名 / 进度)  [可隐藏]
│   ├── 阅读区 (全屏沉浸)
│   ├── 底部控制条 (翻页 / 目录 / 排版 / AI[1.5+] / 笔记)  [可隐藏]
│   ├── 排版设置抽屉 (字号/字体/行距/主题/页边距)
│   ├── 目录抽屉
│   └── 笔记侧栏 (本书所有高亮/笔记)
│
├── 📝 笔记库 (Notes)
│   ├── Tab 1: 我的书笔记 (按书分组)
│   ├── Tab 2: 全部高亮 (跨书聚合)
│   ├── Tab 3: 搜索
│   └── 单书笔记页 (BookNote 编辑器)
│
└── ⚙️ 设置 (Settings)
    ├── 阅读 (默认排版 / 字体管理 / 主题)
    ├── 数据 (导出全部 Markdown / 备份 / 清理缓存)
    ├── AI [1.5+ 显现] (DeepSeek API Key 配置)
    ├── 同步 [2.0 显现] (坚果云 WebDAV 配置)
    ├── 关于 (版本 / 开源协议 / Gitee 链接)
    └── 反馈
```

### 6.2 关键 UX 原则

1. **沉浸优先**：阅读器进入即默认全屏（隐藏 AppBar 和底部条），点击屏幕中部唤出。
2. **零干扰阅读**：Android 用 `IMMERSIVE_FLAG` 隐藏系统栏；Windows 通过 `setAsFrameless` + 全屏模式屏蔽窗口装饰；系统通知屏蔽能力依赖系统级"勿扰"设置，App 内仅做引导提示。
3. **手势优先**：翻页/亮度/进度全部支持手势，按钮是辅助。
4. **快捷键** (Windows)：
   - `←/→` 翻页
   - `F11` 全屏
   - `Ctrl+B` 书签
   - `Ctrl+F` 搜索
   - `Ctrl+,` 设置
   - `Esc` 退出全屏
5. **Android 沉浸式状态栏**：透明状态栏 + 阅读区延伸到状态栏下。
6. **Material 3** 设计语言，色板可定制（夜间模式、护眼米黄）。

### 6.3 关键交互流程

**流程 1：导入并阅读新书**

```
书架点 + → 文件选择 → 导入进度条 → 入库
  → 书架出现新书 → 点击进入阅读器
```

**流程 2：高亮 + 写笔记**

```
阅读中长按选中文本 → 弹出操作浮窗 (高亮 / 笔记 / 复制 / 搜索 / AI[1.5+])
  → 选"高亮" → 选颜色 → 自动保存
  → 选"笔记" → 选颜色 → 弹出笔记编辑器 → 输入 → 保存
```

**流程 3：查看 / 导出读书笔记**

```
阅读器侧栏 或 笔记库 Tab → 进入 BookNote
  → 编辑 summary / keyTakeaways
  → 点右上"导出" → 选择 Markdown → 文件选择器选保存位置 → 完成
```

**流程 4：搜索全部高亮**

```
笔记库 Tab → 搜索 → 输入关键词 + 筛选条件 (书/颜色/标签)
  → 结果列表 (点击跳转到原书位置)
```

### 6.4 主题系统

| 主题 | 背景 | 文字 | 用途 |
|---|---|---|---|
| 日间 | #FFFFFF | #1A1A1A | 默认 |
| 护眼 | #F4ECD8 | #5C4B33 | 长时间阅读 |
| 夜间 | #1A1A1A | #C8C8C8 | 低光环境 |
| 墨水屏 [Android] | #E8E8E8 | #202020 | E-Ink 设备 |

### 6.5 路由

`go_router` 管理，深链 (deep link) 支持跳到指定书指定位置：

- `zhiyue://book/{id}` 打开书
- `zhiyue://book/{id}?locator=...` 打开书到指定位置
- 文件关联：双击 `.epub` 自动打开智阅（Windows 后期、Android 通过 Intent Filter）

---

## 7. 技术栈、测试、CI/CD

### 7.1 技术栈

| 层 | 技术 | 版本/说明 |
|---|---|---|
| **框架** | Flutter | Stable 通道，最新稳定版（>= 3.27） |
| **语言** | Dart | >= 3.5（records/patterns） |
| **状态管理** | Riverpod | 类型安全，适合中大型项目 |
| **路由** | go_router | 官方推荐 |
| **数据库** | drift (SQLite) | 类型安全 ORM，支持 FTS5 |
| **EPUB 解析** | epubx | 评估后可能 fork |
| **EPUB 渲染** | 起步用 `epub_view`/`vepub` 评估 | 不满足则 fork |
| **PDF 渲染** | 起步用 `pdfx` / syncfusion 社区版 | 评估后定 |
| **文件选择** | file_picker (Win) + saf_util (Android) | |
| **Markdown 导出** | markdown 包 + 自研模板 | |
| **i18n** | flutter_localizations + arb | 中英双语 |
| **打包** | Flutter build windows / build apk | |
| **CI** | GitHub Actions（Gitee 镜像同步） | 提交时跑测试 + 构建 |

**为什么 Riverpod**：
- 类型安全（编译期检查依赖图）。
- Provider 可被覆盖，方便测试。
- 单人项目比 Bloc 模板代码更少。

### 7.2 测试策略

| 层 | 测试类型 | 工具 |
|---|---|---|
| ReaderEngine | 单元 + 集成 | flutter_test + 准备 5 本测试 EPUB/PDF |
| Repository | 单元（内存 SQLite） | drift 测试模式 |
| Markdown 导出 | 单元（快照测试） | 黄金文件对比 |
| UI | Widget 测试 | flutter_test |
| 关键流程 | 集成测试 | integration_test |
| 真机 | 手动（Windows + Android 各 1 台） | 每个里程碑 |

**MVP 1.0 测试覆盖率目标**：核心数据层 / 导出层 ≥ 70%；UI 层 ≥ 30%（不强求）。

### 7.3 错误处理

- **导入失败**（损坏的 EPUB/PDF）：友好的错误提示，删除半成品数据。
- **存储空间不足**：导入前检查可用空间。
- **数据库迁移**：drift 自带 schema 迁移；每次 schema 变更写 migration test。
- **PDF 渲染 OOM**：大 PDF 分块加载，限制最大页数提示。
- **崩溃**：MVP 不接入 Sentry（避免外部依赖），日志写本地文件，用户可手动反馈。

### 7.4 CI/CD

每次推送到 Gitee master 时：

1. 跑 `flutter analyze`（lint 零警告）。
2. 跑单元测试。
3. 构建 Windows exe（artifact 上传到 release）。
4. 构建 Android apk（artifact 上传到 release）。
5. Tag 时自动发 Release。

**Gitee 镜像**：通过 Gitee 的"从 GitHub 导入"或 `git remote` 双推实现，主仓库在 Gitee。

---

## 8. 项目里程碑（MVP 1.0 细分）

| 里程碑 | 内容 | 工期估算（单人） |
|---|---|---|
| **M0** | 项目脚手架 + CI + 仓库结构 + AGPLv3 + README | 0.5 周 |
| **M1** | 数据层 + Repository + drift schema | 1.5 周 |
| **M2** | EPUB 阅读器（解析/渲染/翻页/目录/进度）—— **关键 go/no-go 决策点**：早期评估 `epub_view`/`vepub`，不满足则 fork 或自研，工期可能 +4~6 周 | 4 周（最坏 8-10 周） |
| **M3** | EPUB 高亮 + 笔记 + 排版设置 | 2 周 |
| **M4** | PDF 渲染（文本 + 扫描） | 2 周 |
| **M5** | 书架 UI + 导入流程 + 主题 | 1.5 周 |
| **M6** | 笔记库 UI + Markdown 导出 + 搜索 | 2.5 周 |
| **M7** | 设置页 + i18n + Windows/Android 适配 | 1.5 周 |
| **M8** | 测试补全 + 性能优化 + Release 1.0 | 2.5 周 |
| **合计 MVP 1.0** | | **~18 周（4-5 个月）** |

---

## 9. 关键风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| EPUB 渲染库不满足需求 | 中 | 高 | M2 早期评估 2-3 个库；不满足则 fork；最坏情况自研渲染（增加 4-6 周） |
| PDF 文本提取准确率 | 中 | 中 | MVP 不强求 OCR；扫描件降级为仅阅读 |
| 单人项目工期超期 | 高 | 中 | M2/M3 是关键路径；如超期则先发布仅 EPUB 的 0.9 版本 |
| 中文排版（标点避头尾） | 中 | 中 | EPUB 渲染库若已支持则免费；否则降级 |
| Windows 系统集成（深链/文件关联） | 低 | 低 | MVP 不强求，放 1.5 |

---

## 10. 非目标（明确不做 - MVP 1.0）

- ❌ iOS / Mac / Web 端
- ❌ 任何形式的云后端 / 账户体系
- ❌ AI 功能（属 MVP 1.5）
- ❌ 跨端同步（属 MVP 2.0）
- ❌ Zotero / Obsidian 双向同步（属 MVP 2.0+）
- ❌ TTS 朗读
- ❌ 知识图谱可视化
- ❌ 社交/书评/分享
- ❌ OCR（扫描版 PDF 的 OCR 识别）

---

## 11. 后续阶段预告（仅作方向参考，细节留待规划）

### 11.1 MVP 1.5：AI 陪伴式学习伙伴

- **AI 导读**：打开书未读先看，AI 基于目录/前言生成导读卡片。
- **伴随式问答**：阅读中针对当前章节/全书提问，AI 回答必须附原文定位（避免幻觉）。
- **接入**：DeepSeek BYOK，用户在设置中填入 API Key。
- **设计原则**：严格遵循"增强而非替代"，所有 AI 输出可点击跳回原文。

### 11.2 MVP 2.0：章节回顾 + 知识库 + 同步

- **章节学习回顾**：读完一章后，AI 协助用户回顾、提炼知识点、生成结构化笔记写入 BookNote 的 `keyTakeaways`。
- **坚果云 WebDAV 同步**：进度、笔记、高亮、知识库跨端同步。利用 Repository 抽象，包装 `Synced*Repository` 实现。
- **Markdown 批量导出**：整个书架导出为 Obsidian vault 结构。

### 11.3 MVP 3.0+：生态整合

- Zotero / Obsidian 双向同步
- 知识图谱可视化（实体链接、跨书关联）
- Mac 端（Flutter 同代码库）
- TTS 朗读、阅读统计、阅读目标

---

## 附录 A：术语表

- **EPUB CFI**：Canonical Fragment Identifier，EPUB 标准的精确定位协议，用于跨端同步阅读进度。
- **WebDAV**：坚果云等支持的文件同步协议。
- **BYOK**：Bring Your Own Key，用户自带 API Key。
- **FTS5**：SQLite 的全文搜索引擎。
- **SAF**：Storage Access Framework，Android 文件访问框架。
- **Locator**：智阅内部统一的"位置"抽象（CFI 或 PDF 坐标）。

## 附录 B：参考竞品

- **Readest**：Flutter 开源 EPUB 阅读器，跨端同步。
- **Neat Reader**：商业化跨端阅读器，同步稳定性差。
- **Moon+ Reader / KOReader**：Android 老牌阅读器，功能强但配置复杂。
- **BookFusion**：Calibre 生态整合方案。
- **Obsidian**：参考其 Markdown 笔记格式与 vault 结构。
