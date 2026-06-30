# 智阅 M2.1 — 章节学习回顾 + Markdown 批量导出 设计文档

> **版本**：1.0
> **创建日期**：2026-06-30
> **前置**：v1.0.0 GA（tag `v1.0.0`，commit `edde312`）
> **后续 tag**：`m2.1-complete` + `v1.1.0-alpha`
> **协议**：AGPLv3
> **状态**：设计已与用户确认，待写实施 plan

---

## 1. 背景

设计文档 §11.2 把 MVP 2.0 列为「章节学习回顾 + 知识点提炼 + 坚果云 WebDAV 同步」。同步已在 M2.0a/M2.0b 交付，本 milestone 完成剩余两项中的核心：

- **章节学习回顾**：用户读完一章后，AI 协助回顾、提炼知识点、写入 `BookNote.keyTakeaways`
- **Markdown 批量导出**：整个书架导出为 Obsidian vault 结构（多 `.md` + `index.md`）

合并到一个 milestone 的原因：两者都属于 MVP 2.0 知识库深化方向，章节回顾产出的 `keyTakeaways` 通过批量导出才能在 Obsidian vault 中释放价值，共享同一份 milestone spec/plan 节省流程开销。

## 2. 范围与非目标

### 2.1 范围

- 章节回顾：手动触发（TOC 抽屉按章节 + 阅读器溢出菜单"回顾本章"），AI 流式生成 → 模态预览 → 保存/取消
- 批量导出：库 AppBar 溢出菜单 → 文件夹选择 → 多 `.md` + `index.md`

### 2.2 非目标（明确不做）

- 模态内编辑 summary/takeaways（用户已确认）
- 章节结束的自动提示回顾（用户选了"手动按钮"）
- "历史回顾列表" UI（不做 per-chapter review 历史）
- 导出范围筛选（按 tag / 按时间 / 按 progress）
- `.zip` 压缩产出
- review 的"语气风格"选项
- index.md 的"按标签分组"段落（只做按书名字母序）
- "AI 配置"页新增 review 相关项（温度、token 上限）—— 用 BookPreprocessor 既定配置
- review 失败的"逐章重试" UI
- PDF 书的回顾入口（按 M4 Page-as-Chapter，PDF "章"就是页，回顾单页意义不大；UI 上禁用）
- Mac 端验证

## 3. 总体架构

两个新功能，两个新独立服务，互不耦合。两者都**完全复用**现有的 `MarkdownExporter` / `NotesRepository` / `ai_summaries` 缓存机制 / `ApiKeyStore`，**零数据库 schema 迁移、零同步逻辑改动**。

### 3.1 章节回顾数据流

```
[TOC 抽屉图标 / 阅读器溢出菜单]
        ↓ click
ReviewController.start(bookId, chapterIndex)
        ↓
BookReviewer.run(book, chapterIndex)        ← 新服务，stream events
   ├─ 读 ChapterTextProvider 拿本章文本
   ├─ 读 NotesRepository 拿本章高亮
   ├─ 构造 PromptBuilder.review() prompt
   ├─ sha256(text + highlights) 查 ai_summaries(mode='review') 缓存
   │     ├─ 命中 → 直接 emit ReviewCompleteEvent(解析缓存 JSON)
   │     └─ miss → 调用 OpenAiCompatibleClient stream
   └─ 流式 emit ReviewChunkEvent → ReviewCompleteEvent(JSON) / ReviewErrorEvent
        ↓
ReviewPreviewSheet (模态)
   ├─ streaming: 显示 raw 文本（让用户看到 AI 在干活）
   ├─ done: 解析 JSON → 显示 summary + keyTakeaways 卡片
   └─ error: 显示 ErrorView + 重试
        ↓ [保存]
NotesRepository.applyChapterReview(bookId, chapterIndex, summary, takeaways)
   ├─ 删除 book_notes 中所有 【第N章】 前缀的旧条目（keyTakeaways）+ ## 第N章 段落（summary）
   ├─ 追加新内容（带前缀）
   └─ 触发 sync_outbox 自动记录（已有逻辑）
```

### 3.2 批量导出数据流

```
[库 AppBar 溢出菜单 → "导出为 Markdown"]
        ↓
确认对话框（"将导出 N 本书的读书笔记"）
        ↓ [确定]
file_picker.getDirectoryPath()        ← 系统原生文件夹选择
        ↓
BatchExportDialog (模态进度)
   ↓
VaultExporter.export(books, notesByBookId, targetDir, now, onProgress)
   ├─ 过滤：保留有 BookNote 且内容非空的书
   ├─ 排序：按 title 字母序
   ├─ 对每本：MarkdownExporter.export → 写 <sanitized>.md
   ├─ 收集所有 tags → 写 index.md
   └─ 返回 VaultExportResult(stats + failures)
        ↓
Snack: "已导出 N 本到 <path>" + [打开文件夹]
```

## 4. 章节回顾详细设计

### 4.1 Prompt 模板

写入 `lib/services/ai/prompt_builder.dart`，新增 `review` 模式：

```text
你是一位学习导师，帮读者回顾刚读完的章节。

## 本章信息
书名：《{bookTitle}》
章节：第{chapterOrdinal}章 · {chapterTitle}

## 本章正文（节选）
{truncatedChapterText}

## 读者在本章的高亮与笔记
{highlightsBlock}

## 任务
1. 写一段 100-200 字的本章核心摘要，聚焦读者通过高亮关注的部分
2. 提炼 3-5 条可执行/可记忆的要点，每条一句话

## 输出格式（严格遵守，输出纯 JSON，不要 Markdown 围栏）
{
  "summary": "...",
  "keyTakeaways": ["...", "..."]
}
```

`highlightsBlock` 构造规则：
- 本章有高亮：逐条列出 `> {quote}` + 若 hasNote 则换行 `  💬 {note}`
- 本章无高亮：替换为字符串 `"（读者未做高亮，请基于本章正文做通用回顾）"`

`chapterOrdinal`：1-based，阿拉伯数字（不做中文数字转换；UI 上展示时再转，prompt 里保持简单）。

### 4.2 AI 输入来源

| 字段 | 来源 | 已有 API |
|---|---|---|
| `bookTitle` | `Book.title` | model 字段 |
| `chapterOrdinal` | `chapterIndex + 1` | 调用方传入 |
| `chapterTitle` | `ChapterTextProvider.title(filePath, chapterIndex)` | 已有 |
| `truncatedChapterText` | `ChapterTextProvider.get(filePath, chapterIndex)` → `TokenTruncator.truncateToTokens(text, defaultBudget)` | 已有 |
| `highlightsBlock` | `NotesRepository.listAnnotations(noteId)` 内存过滤 `_chapterIndexOf(a) == chapterIndex` | 已有；若 `BookNote` 不存在则视为空列表 |

PDF 章节：本 milestone 不开放入口（见 §2.2），但若调用方传入 PDF，按 `_chapterIndexOf` 的 `PdfRangeLocator.page` 行为正常工作。

### 4.3 缓存策略

复用 `ai_summaries` 表（已有列，**零迁移**）：

| 列 | 值 |
|---|---|
| `book_id` | `book.id` |
| `mode` | `'review'` |
| `source_hash` | `sha256(truncatedText + "::" + highlightsSignature)` |
| `summary_text` | AI 返回的原始 JSON 字符串 |
| `model_name` | `OpenAiCompatibleClient` 当前 model |
| `base_url` | 用户配置的 baseUrl |
| `prompt_version` | `PromptBuilder.promptVersion`（实施时 bump +1） |

**highlightsSignature 计算**：把本章所有高亮的 `quote` 字段按 `createdAt` 升序拼接（`\n` 分隔），再 sha256。**目的**：用户新增/删除高亮后，hash 变化 → 缓存 miss → 触发新 LLM 调用，保证回顾反映最新阅读状态。

**命中规则**：4 列全等（bookId + mode + source_hash + prompt_version）。

**命中即跳过 LLM**：直接 parse `summary_text` JSON，emit `ReviewCompleteEvent`。

### 4.4 服务接口

新建 `lib/services/ai/book_reviewer.dart`：

```dart
enum ReviewError { authFailed, rateLimited, parseError, serverError }

sealed class ReviewEvent {}

class ReviewChunkEvent extends ReviewEvent {
  ReviewChunkEvent(this.chunk);
  final String chunk;
}

class ReviewCompleteEvent extends ReviewEvent {
  ReviewCompleteEvent({required this.summary, required this.keyTakeaways});
  final String summary;
  final List<String> keyTakeaways;
}

class ReviewErrorEvent extends ReviewEvent {
  ReviewErrorEvent(this.error);
  final ReviewError error;
}

abstract class BookReviewerLike {
  Stream<ReviewEvent> run({required Book book, required int chapterIndex});
}

class BookReviewer implements BookReviewerLike {
  BookReviewer({
    required this.chapterTextProviderFor,
    required this.notesRepository,
    required this.aiGuide,            // 复用 AiGuide（M1.5a 已有），通过 mode=review 调用
    required this.apiKeys,
    required this.aiSummariesDao,
  });

  final ChapterTextProvider Function(Book) chapterTextProviderFor;
  final NotesRepository notesRepository;
  final AiGuide aiGuide;              // 已有的 LLM 调用封装（BookPreprocessor 同款）
  final ApiKeyStoreLike apiKeys;
  final AiSummariesDao aiSummariesDao;

  @override
  Stream<ReviewEvent> run({required Book book, required int chapterIndex}) async* { ... }
}
```

**行为契约**：

- 进入 `run`：
  1. `apiKeys.load()` → 若 null → `yield ReviewErrorEvent(authFailed)` → return
  2. 拉 chapter text + 高亮 → 构造 prompt + sourceHash
  3. 查缓存 → 命中：parse JSON；parse 失败 → `ReviewErrorEvent(parseError)`；成功 → `ReviewCompleteEvent` → return
  4. miss：调 `aiGuide.run(book, mode: AiGuideMode.review, chapterIndex, chapterTitle)` → 监听 `AiGuideEvent` 流；`AiChunkEvent` 转发为 `ReviewChunkEvent`；累积 raw 文本
  5. 流结束（`AiDoneEvent` 或 `onDone`）：parse 累积 JSON；失败 → `ReviewErrorEvent(parseError)`；成功 → 写 `ai_summaries` + `ReviewCompleteEvent`
- API 错误（`AiErrorEvent(authFailed / rateLimited / serverError)`）→ 对应 `ReviewErrorEvent`
- **不抛异常**：所有错误通过 event 流出，方便 controller 统一处理

**AiGuide 扩展点**：当前 `AiGuideMode = { full, chapter, selection }`，本 milestone 加 `review`。`AiGuide` 内部已有按 mode 分发 prompt 的逻辑（`PromptBuilder.run(mode:...)`），新增 mode 时同步在 `PromptBuilder` 加 `review` 模板（§4.1）。`AiGuide` 的 streaming chunk event 已是 `AiChunkEvent`，复用即可。

**JSON 解析**：新建 `lib/services/ai/review_output_parser.dart`：

```dart
class ReviewOutput {
  const ReviewOutput({required this.summary, required this.keyTakeaways});
  final String summary;
  final List<String> keyTakeaways;
}

class ReviewOutputParser {
  /// 返回 null 表示解析失败（调用方转 parseError）。
  /// 容忍前后空白 + 容忍意外的 ```json 围栏（部分 LLM 不遵守指令）。
  static ReviewOutput? parse(String raw) { ... }
}
```

解析规则：
- `jsonDecode(raw)` 失败 → 尝试剥离 ```` ```json ... ``` ```` 围栏后重试
- 顶层必须是对象，含 `summary`(String) + `keyTakeaways`(List)
- `keyTakeaways` 元素强制 `whereType<String>()` 过滤（防 LLM 返回 null/数字）
- `summary` 空字符串 + `keyTakeaways` 空数组 → 仍视为成功（AI 判断本章无 takeaway）

### 4.5 Riverpod Controller

新建 `lib/features/ai/providers/review_controller.dart`：

```dart
enum ReviewStatus { idle, loading, streaming, done, error }

class ReviewState {
  const ReviewState({
    this.status = ReviewStatus.idle,
    this.rawText = '',
    this.summary,
    this.keyTakeaways = const [],
    this.error,
  });

  final ReviewStatus status;
  final String rawText;          // streaming 时累积
  final String? summary;          // done 时解析得到
  final List<String> keyTakeaways; // done 时解析得到
  final ReviewError? error;
  // copyWith 略
}

class ReviewController extends StateNotifier<ReviewState> {
  ReviewController(this._reviewer) : super(const ReviewState());

  final BookReviewerLike _reviewer;
  StreamSubscription<ReviewEvent>? _sub;

  void start({required Book book, required int chapterIndex}) { ... }
  void reset() { ... }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }
}

final reviewControllerProvider = StateNotifierProvider.autoDispose
    .family<ReviewController, ReviewState, String>((ref, bookId) {
  return ReviewController(_NoOpBookReviewer());  // 镜像 QaController NoOp 模式
});
```

**状态机**：

```
idle ──start──▶ loading ──ReviewChunkEvent──▶ streaming ──ReviewCompleteEvent──▶ done
                    │                              │
                    └─ReviewErrorEvent──▶ error◀───┘
                                            │
                                            └──start(重试)──▶ loading
```

- `loading`：包括缓存查询 + 首个 token 等待
- `streaming`：每 chunk 累加到 `rawText`，UI 显示流式文本
- `done`：解析后填 `summary` + `keyTakeaways`
- `error`：填 `error` 字段，UI 给具体提示 + 重试按钮（重试就是再调 `start`）

**NoOp 默认**：未挂载生产配置时，`_NoOpBookReviewer.run` 立即 yield `ReviewErrorEvent(serverError)`，与 `QaController` 的 NoOp 行为一致。

### 4.6 模态预览 UI

新建 `lib/features/ai/widgets/review_preview_sheet.dart`：

```
┌────────────────────────────────────────┐
│  回顾：第 3 章 · 量子态叠加            │  AppBar
├────────────────────────────────────────┤
│  [状态分支]                             │
│  loading:     LoadingView("AI 思考中") │
│  streaming:   rawText 流式 + 骨架      │
│  done:        summary 段 + takeaways   │
│               列表（每条带【第N章】前缀预览）│
│  error:       ErrorView + 重试按钮     │
├────────────────────────────────────────┤
│              [取消]  [保存到读书笔记]   │  底部按钮（done 状态才启用保存）
└────────────────────────────────────────┘
```

- 顶部 AppBar 标题：`l10n.reviewSheetTitle(chapterOrdinal, chapterTitle)`
- `streaming` 状态：底部按钮禁用
- `done` 状态：底部"保存"启用
- `error` 状态：底部按钮换成"重试" + "取消"
- 关闭模态（点外区/ESC）= 取消，不保存

`showModalBottomSheet` 推出，`isDismissible: false`（streaming 中防止误关），完成后 `isDismissible: true`。

### 4.7 保存语义（幂等写入）

新建方法 `NotesRepository.applyChapterReview`：

```dart
abstract class NotesRepository {
  // ...existing...

  /// 用新的 AI 回顾结果替换该章节的旧回顾内容。
  /// - keyTakeaways 中 【第N章】 前缀的旧条目先删后加
  /// - summary 中 ## 第 N 章 · 标题 段落先删后加
  /// - BookNote 不存在则先 createEmptyNote
  Future<void> applyChapterReview({
    required String bookId,
    required String bookTitle,
    required int chapterIndex,
    required String? chapterTitle,
    required String summary,
    required List<String> keyTakeaways,
  });
}
```

**前缀约定**：

- keyTakeaway 条目：`【第{chapterOrdinal}章】 {原始内容}`
- summary 段落：

  ```markdown
  ## 第 {chapterOrdinal} 章 · {chapterTitle}

  {AI 生成的 summary 文本}

  ```

**替换算法**（`LocalNotesRepository.applyChapterReview` 实现）：

1. `getNoteByBook(bookId)` → 若 null，`createEmptyNote`
2. 在 `note.keyTakeaways` 中：
   - 找出所有以 `【第{chapterOrdinal}章】` 开头的旧条目 → 删除
   - 把本次 `keyTakeaways` 每条加 `【第{chapterOrdinal}章】 ` 前缀后追加
3. 在 `note.summary` 中：
   - 找出 `## 第 {chapterOrdinal} 章` 起到下一个 `## ` 或字符串末尾的段落 → 删除
   - 把本次 `summary` 包装为上述 markdown 段落格式追加（两段之间空行）
4. `updateNote(note)` → 已有逻辑会写 sync_outbox

**chapterOrdinal 1-based**：与 prompt 一致。**chapterTitle 为空字符串/null 时**：keyTakeaways 前缀仍用 `【第N章】`；summary 段落标题用 `## 第 N 章`（无 `·`）。

### 4.8 入口接入

#### TOC 抽屉（`lib/features/reader/widgets/toc_drawer.dart`）

每条章节 `TocEntry` 渲染时，trailing 区加一个 `IconButton`：

```dart
IconButton(
  icon: const Icon(Icons.rate_review_outlined, size: 20),
  tooltip: l10n.reviewButtonLabel,
  onPressed: entry.isPreprocessed ? () => _openReview(entry.chapterIndex) : null,
)
```

**`isPreprocessed` 判定**：通过 `bookPreprocessControllerProvider` 的 `summarizedChapters` 集合是否含 `chapterIndex` 判断。未预处理章节禁用按钮，tooltip 显示 `l10n.reviewDisabledNotPreprocessedHint`（如"需先预处理本书"）。

PDF 书（`book.format == BookFormat.pdf`）：整个 TOC 不渲染回顾按钮（与 §2.2 一致）。

#### 阅读器顶栏溢出菜单（`lib/features/reader/pages/reader_body.dart`）

在现有 `PopupMenuButton` 的 items 列表追加一项：

```dart
PopupMenuItem<String>(
  value: 'review_current',
  child: Row(children: [
    Icon(Icons.rate_review_outlined),
    SizedBox(width: 8),
    Text(l10n.reviewCurrentChapterMenuLabel),
  ]),
),
```

点击时：

- 取当前 `engine.currentChapterIndex`
- 同样调 `_openReview(chapterIndex)`
- PDF 书：菜单项不渲染

两个入口共用同一个 `_openReview` 方法（在 `ReaderBodyState` 或 `toc_drawer.dart` 里）：

```dart
void _openReview(int chapterIndex) {
  final book = /* from widget/bookProvider */;
  if (book.format == BookFormat.pdf) return;
  ref.read(reviewControllerProvider(book.id).notifier).start(
        book: book,
        chapterIndex: chapterIndex,
      );
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => ReviewPreviewSheet(bookId: book.id, chapterIndex: chapterIndex),
  );
}
```

## 5. Markdown 批量导出详细设计

### 5.1 服务接口

新建 `lib/features/notes/services/vault_exporter.dart`：

```dart
class VaultExportResult {
  const VaultExportResult({
    required this.booksExported,
    required this.totalHighlights,
    required this.totalNotes,
    required this.writtenFiles,
    required this.failures,
  });

  final int booksExported;
  final int totalHighlights;
  final int totalNotes;
  final List<String> writtenFiles;     // 相对 targetDir 的路径
  final List<VaultExportFailure> failures;
}

class VaultExportFailure {
  const VaultExportFailure({required this.bookId, required this.bookTitle, required this.error});
  final String bookId;
  final String bookTitle;
  final Object error;
}

class VaultExporter {
  /// 同步算法 + 异步 I/O。
  /// 调用方负责预加载 notesByBookId。
  /// onProgress 在每本书写完后回调（1-based current）。
  static Future<VaultExportResult> export({
    required List<Book> books,
    required Map<String, BookNote> notesByBookId,
    required Directory targetDir,
    required DateTime now,
    void Function(int current, int total, String bookTitle)? onProgress,
  }) async { ... }
}
```

### 5.2 算法

```
1. 过滤 books：
   - 保留 notesByBookId 含 BookNote 的
   - 且该 BookNote 满足：annotations 非空 OR summary 非空 OR keyTakeaways 非空
   
2. 按 book.title 排序（locale-aware 比较）

3. 对每本书（index i, 1-based）：
   try:
     markdown = MarkdownExporter.export(book: book, bookNote: note, now: now)
     filename = "${sanitizeForFilename(book.title)} - 读书笔记.md"
     targetFile = targetDir/filename
     targetFile.writeAsString(markdown)        # 覆盖
     记录 writtenFiles.add(filename)
     累计 totalHighlights += note.annotations.length
     累计 totalNotes += note.annotations.where(hasNote).length
     累计该书的 tags
   catch err:
     failures.add(VaultExportFailure(bookId, title, err))
   finally:
     onProgress(i, total, book.title)

4. 生成 index.md：
   - frontmatter: type=zhiyue-vault-index, exported_at, book_count, total_highlights, total_notes
   - 标题段 + 概要行
   - 书目列表（[[wiki-link|alias]] — N 高亮 / M 笔记 · #tag #tag）
   - 标签云（合并所有 tags，去重排序）

5. 写 targetDir/index.md（覆盖）
   writtenFiles.add("index.md")

6. return VaultExportResult(...)
```

**`sanitizeForFilename`**：复用现有 `NoteFileWriter.sanitizeForFilename`（M3.4 已有）。替换 `/\:*?"<>|` + 控制字符为 `_`，trim 空白，限长 100 字符。

### 5.3 `index.md` 模板

```markdown
---
type: zhiyue-vault-index
exported_at: 2026-06-30T14:32:00
book_count: 12
total_highlights: 234
total_notes: 56
---

# 我的智阅书架

> 共 12 本书 · 234 条高亮 · 56 条笔记
> 导出时间：2026-06-30

## 书目

- [[《深入浅出量子力学》 - 读书笔记|《深入浅出量子力学》]] — 23 高亮 / 5 笔记 · #物理 #科普
- [[《代码大全》 - 读书笔记|《代码大全》]] — 41 高亮 / 12 笔记 · #技术 #工程
- [[《纯粹理性批判》 - 读书笔记|《纯粹理性批判》]] — 0 高亮 / 0 笔记 · （仅含 AI 回顾）
...

## 标签云

#物理 #科普 #技术 #工程 #哲学 #历史
```

**关键格式点**：

- `[[xxx|yyy]]`：Obsidian wiki-link 别名语法。`xxx` 是不带 `.md` 后缀的文件路径，`yyy` 是显示文本（含《》）
- frontmatter 的 `type: zhiyue-vault-index`：让 Dataview 插件可查询
- 书目条目尾部 stats：`N 高亮 / M 笔记`（无高亮无笔记的书也列出，标记"仅含 AI 回顾"）
- 标签云：所有书的 tags 去重并集，按字母序

**空 tags 处理**：若所有书都没 tag，省略"## 标签云"段落。

### 5.4 文件夹选择 + 进度 UX

新建 `lib/features/library/widgets/batch_export_dialog.dart`：

```
[用户点"导出为 Markdown" 菜单项]
        ↓
Future.wait([bookRepo.getAll(), count of booksWithNotes])
        ↓
if (booksWithNotes == 0):
   showDialog: "还没有读书笔记可以导出" + [确定]
   return
        ↓
showDialog 确认: "将导出 N 本书的读书笔记到指定文件夹。继续？" + [取消] [选择文件夹]
        ↓ [选择文件夹]
path = await FilePicker.platform.getDirectoryPath()
        ↓ 用户取消 (path == null)
silent return
        ↓ 选了
showDialog<...>(barrierDismissible: false, BatchExportDialog):
   ┌─────────────────────────────────────┐
   │  正在导出读书笔记...                │
   │  ━━━━━━━━━━━━━━━━━━━░░░░░  9/12    │  LinearProgressIndicator
   │  当前：《代码大全》                  │  Text
   │                            [取消]   │  TextButton
   └─────────────────────────────────────┘
        ↓ VaultExporter.export 完成
Navigator.pop(dialogContext, result)
        ↓
ScaffoldMessenger.showSnackBar:
   若 failures.isEmpty:
     "已导出 12 本书到 D:\Obsidian\Vault\" + [打开文件夹]
   否则:
     "已导出 11/12，1 本失败" + [打开文件夹] + [详情]
        ↓ [打开文件夹]
Process.run('explorer', [path])  或  open / xdg-open（已有 _openFolder 逻辑可复用）
```

**`BatchExportDialog` 是 `StatefulWidget`**：

- `initState` 启动导出 `Future`
- `Future` 持有 `cancelFlag`（`bool` 数组或 `Completer`）
- 用户点"取消"：`cancelFlag = true`；下一次 `onProgress` 回调前检查
- `VaultExporter.export` 在循环开头检查 `cancelFlag`（通过 closure）→ 抛 `_CancelledException` → catch 后正常返回部分结果

**取消语义**：取消后已写入的文件**保留**（不回滚），snack 显示"已取消，导出 i/total"。

### 5.5 入口接入

`lib/features/library/pages/library_page.dart` 的 `LibraryAppBar`：

- 现有 `actions:` 中加 `PopupMenuButton<String>`（若已存在则追加 `PopupMenuItem`）
- 新增 item value `'batch_export'`，label `l10n.batchExportMenuLabel`
- `onSelected` 路由到 `_startBatchExport()` 方法

**条件渲染**：当 `booksWithNotes == 0`（基于 `libraryController` 现有 state 推断）时不显示该 `PopupMenuItem`。简化做法：始终显示，点击后弹"还没有笔记"信息框（避免每次切换菜单需要重算 booksWithNotes）—— **选这个简化做法**。

### 5.6 依赖

`pubspec.yaml` 新增：

```yaml
dependencies:
  file_picker: ^8.0.0    # 跨平台文件夹选择
```

`file_picker` 已在 pub.dev 稳定发布，Windows/macOS/Linux 均支持。

## 6. 跨切关注

### 6.1 安全性（与项目约束一致）

- **API key 处理**：Reviewer 复用 `ApiKeyStore`（与 BookPreprocessor 共享），不引入新 key 路径
- **日志**：Reviewer 错误信息只暴露 `authFailed / rateLimited / parseError / serverError`，**不打印**原始 LLM 响应体、API key、用户高亮内容
- **VaultExporter**：完全离线，零网络调用；写入路径来自 `file_picker`，不接受外部输入

### 6.2 i18n（约 25 个新 key）

```
// 章节回顾 (15)
reviewButtonLabel                              "回顾本章"
reviewCurrentChapterMenuLabel                  "回顾本章"
reviewDisabledNotPreprocessedHint              "需先预处理本书"
reviewSheetTitle                               "回顾：第 {n} 章 · {title}"
reviewSummarySection                           "核心摘要"
reviewTakeawaysSection                         "核心要点"
reviewSaveButton                               "保存到读书笔记"
reviewCancelButton                             "取消"
reviewRetryButton                              "重试"
reviewStatusLoading                            "AI 思考中…"
reviewStatusStreaming                          "AI 正在生成…"
reviewEmptyHighlightsHint                      "（本章无高亮，AI 将基于正文做通用回顾）"
reviewErrorAuthFailed                          "API 密钥无效，请检查设置"
reviewErrorParseFailed                         "AI 输出格式异常，请重试"
reviewErrorServer                              "网络或服务异常，请重试"

// 批量导出 (10)
batchExportMenuLabel                           "导出为 Markdown"
batchExportConfirmTitle                        "导出读书笔记"
batchExportConfirmMessage                      "将导出 {count} 本书的读书笔记到指定文件夹。"
batchExportNoNotesTitle                        "暂无可导出内容"
batchExportNoNotesMessage                      "还没有任何读书笔记。先做一些高亮或笔记再导出。"
batchExportProgress                            "正在导出 {current}/{total}：{title}"
batchExportSuccess                             "已导出 {count} 本书到 {path}"
batchExportPartialFailure                      "已导出 {success}/{total}，{failed} 本失败"
batchExportCancelled                           "已取消，导出 {success}/{total}"
batchExportOpenFolder                          "打开文件夹"
```

中英 `.arb` 同步生成；`gen_l10n` 跑一次。

### 6.3 测试目标

| 模块 | 新测试数（估） |
|---|---|
| `ReviewOutputParser` | 6（valid JSON / fenced JSON / 缺字段 / 非对象 / 空数组 / 元素非 String） |
| `BookReviewer`（含缓存命中 + miss + 三种 error） | 8 |
| `ReviewController`（状态机转换） | 5 |
| `ReviewPreviewSheet` widget test | 4（loading / streaming / done / error） |
| `applyChapterReview` 幂等性 | 5（首次 / 重复同章 / 不同章 / BookNote 不存在 / chapterTitle 为空） |
| `VaultExporter` 纯逻辑 | 8（过滤 / 排序 / index.md / 覆盖 / failure / cancel / empty / 多 tag） |
| `sanitizeForFilename`（已有，可能加边界） | 1-2 |
| `BatchExportDialog` widget test | 3 |
| 入口接入（TOC 抽屉按钮 + reader 菜单 + library 菜单） | 3 |
| **合计** | **43-46** |

总测试数预计从 716 → ~760。

### 6.4 性能

- Reviewer 单次回顾 ~5-10s（取决于章节长度 + LLM 速度），与 Q&A 单问同量级
- VaultExporter：纯文件 I/O，100 本书 < 1s（无 LLM）
- 缓存命中：Reviewer < 100ms（无 LLM 调用）

## 7. 验收标准

### 7.1 功能验收（13 项）

1. TOC 抽屉每章标题右侧出现回顾图标（未预处理章节禁用 + tooltip 提示）
2. 阅读器顶栏溢出菜单含"回顾本章"项（PDF 书不渲染）
3. 点击后模态打开，先显示 `loading`，进入 `streaming` 时实时显示 raw 文本
4. AI 完成后模态显示解析后的 summary + takeaways 列表（每条预览带【第N章】前缀）
5. 保存后读书笔记页（NotesPage）的 summary 段更新 + keyTakeaways 含新条目（带 `【第N章】` 前缀）
6. 重复回顾同一章（高亮未变）→ 旧 `【第N章】` 条目被替换，无重复
7. 第二次回顾同章且高亮未变 → 命中 `ai_summaries` 缓存，无 LLM 调用（mock 验证）
8. 新增高亮后回顾同章 → 缓存 miss，触发新 LLM 调用
9. AI 返回畸形 JSON → 模态显示 parseError + 重试按钮，读书笔记不被修改
10. 库 AppBar 溢出菜单含"导出为 Markdown"
11. 选定文件夹后，导出 N+1 个 `.md` 文件（N 本书 + 1 个 index.md）
12. 导出过程中点"取消"立即停止，已写入文件保留
13. 至少一本书导出失败 → snack 显示"导出 X/Y，Z 失败"，其他成功文件保留

### 7.2 质量验收

- `dart analyze`：0 warnings / 0 errors（info 可有）
- 全测试套件通过（新增约 43-46 个测试，目标 760+ 通过）
- subagent 两阶段评审（spec compliance + code quality）全绿
- v1.1.0-alpha tag + Gitee push + memory 文件归档

## 8. 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| AI 返回 JSON 不规范（缺字段、有围栏、截断） | 中 | 中 | PromptBuilder 严格化 + ReviewOutputParser 容忍围栏 + 失败兜底 parseError + 重试 |
| `file_picker` 在 Windows 中文路径下行为异常 | 低 | 中 | runbook §3 已记录中文路径 workaround；测试用 ASCII 路径；实施者验证 |
| 缓存 hash 算错（永远 miss 或永远 hit） | 中 | 中 | `PreprocessorCacheHash` 同款模式 + 单测覆盖 highlightsSignature 边界（新增/删除高亮） |
| 模态 streaming 中用户误关造成状态不一致 | 低 | 低 | streaming 状态 `isDismissible: false`，完成后才允许 dismiss |
| 用户期望"自动回顾"但 MVP 没做 | 低 | 低 | runbook 记录"v1.2+ 可考虑自动提示"，spec §2.2 明确列为非目标 |
| 取消导出后文件残留造成用户困惑 | 低 | 低 | 取消语义在 snack 中明确（"已取消，导出 i/total"，已写入的保留） |

## 9. 文件清单

### 9.1 新建（11 个 lib + 对应 test）

```
lib/services/ai/
├── book_reviewer.dart                          (BookReviewer + BookReviewerLike + ReviewEvent sealed class + ReviewError enum)
└── review_output_parser.dart                   (ReviewOutput + ReviewOutputParser)

lib/features/ai/providers/
└── review_controller.dart                      (ReviewController + ReviewState + ReviewStatus + reviewControllerProvider)

lib/features/ai/widgets/
└── review_preview_sheet.dart                   (ReviewPreviewSheet + 内部 _AppBar/_Body/_BottomBar)

lib/features/notes/services/
└── vault_exporter.dart                         (VaultExporter + VaultExportResult + VaultExportFailure)

lib/features/library/widgets/
└── batch_export_dialog.dart                    (BatchExportDialog stateful widget)

lib/core/widgets/
└── folder_saver.dart                           (FolderSaver.pickDirectory() 封装 file_picker)

test/  对应 11 个 _test.dart 文件
```

### 9.2 修改（约 10 处，.arb 算 1 处）

| 文件 | 改动 |
|---|---|
| `pubspec.yaml` | 加 `file_picker: ^8.0.0` |
| `lib/services/ai/prompt_builder.dart` | 加 `review` 模板 + `bump promptVersion` |
| `lib/services/ai/ai_guide.dart` | `AiGuideMode` 加 `review` 分支（转发到 PromptBuilder + 同款 streaming） |
| `lib/data/repositories/notes_repository.dart` | 加 `applyChapterReview` 抽象方法 |
| `lib/data/repositories/local_notes_repository.dart` | 实现 `applyChapterReview` |
| `lib/features/reader/widgets/toc_drawer.dart` | 每行加回顾 IconButton |
| `lib/features/reader/pages/reader_body.dart` | 顶栏溢出菜单加"回顾本章" + `_openReview` 方法 |
| `lib/features/library/pages/library_page.dart` | AppBar 溢出菜单加"导出为 Markdown" + `_startBatchExport` 方法 |
| `lib/main.dart` 或 `app_providers.dart` | 把生产 `BookReviewer` 注入 `reviewControllerProvider` overrides |
| `lib/gen_l10n/app_localizations*.arb` (3 个文件) | 加约 25 个 key + regen |

### 9.3 不动

- ❌ 数据库 schema（无新表、无新列、无迁移）
- ❌ 同步逻辑（`sync_outbox` / `sync_recorder` / `remote_record_applier`）
- ❌ `MarkdownExporter`（单书导出原样复用）
- ❌ `BookPreprocessor` / `QaController` / `BookQaService`（独立链路）

## 10. 工期估算

| 模块 | 工期 |
|---|---|
| T1-T3: `ReviewOutputParser` + `BookReviewer` + 单测 | 1.5 天 |
| T4-T5: `ReviewController` + `ReviewPreviewSheet` widget + 测试 | 1 天 |
| T6: `NotesRepository.applyChapterReview` + 幂等性测试 | 0.5 天 |
| T7-T8: TOC 抽屉 + reader 菜单接入 + 入口测试 | 0.5 天 |
| T9-T10: `VaultExporter` + 单测 | 1 天 |
| T11: `BatchExportDialog` + `FolderSaver` + 接入 + 测试 | 1 天 |
| T12: i18n keys + regen + 集成调整 | 0.5 天 |
| T13: 全套测试 + `dart analyze` + subagent 两阶段评审 | 1.5 天 |
| T14: 文档（runbook 增补） + tag + push + memory | 0.5 天 |
| **合计** | **8 个工作日** |

预留 2 天 buffer → **总计 10 个工作日（2 周）**。

## 11. 后续 milestone 预告（仅作方向）

- **M2.2**：章节结束的自动回顾提示（被 §2.2 排除的本期项）
- **M2.3**：批量导出范围筛选（按 tag / 时间 / progress）
- **M3.0+**：Zotero / Obsidian 双向同步、知识图谱可视化、Mac 端

---

## 附录 A：决策记录

| 决策 | 选择 | 备选 | 理由 |
|---|---|---|---|
| 触发方式 | 手动按钮 | 自动提示 / 批量 | YAGNI；不破坏阅读流程；最小入口 |
| 输出存储 | 复用 `book_notes` | 新 `chapter_reviews` 表 | 零迁移；零同步改动；前缀约定解决幂等 |
| AI 输入 | ch-text + highlights | summary + highlights / 模板拼装 | 全量个性化质量最高 |
| 模态流程 | 预览 → 保存/取消 | 自动保存 + toast / 模态可编辑 | AI 输出有 fallible，预览给用户控制权；不做编辑省表单控件 |
| 入口 | TOC 抽屉 + 阅读器溢出菜单 | 仅其中之一 / 加 BookDetail | 两入口服务不同心智（"回顾本章" vs "回顾我正在读的"） |
| 批量导出形状 | 文件夹 + 多 `.md` + `index.md` | `.zip` / 设置页节流 | Obsidian vault 直拖即用；最少依赖 |
| 服务架构 | 双新独立服务 | 扩展现有 QaService/MarkdownExporter | 单一职责；现有"纯函数/流式"契约不被破坏 |

## 附录 B：术语表

- **章节回顾（Chapter Review）**：用户读完一章后调 AI 生成 summary + keyTakeaways，写入该书 `BookNote`
- **批量导出（Batch Export / Vault Export）**：把整个书架的读书笔记导出为 Obsidian vault 结构
- **【第N章】前缀约定**：keyTakeaways 条目落库时附加的章节归属标记，用于幂等替换
- **wiki-link**：Obsidian 的 `[[文件名|显示名]]` 内链语法
- **highlightsSignature**：本章所有高亮 quote 拼接后的 sha256，用于 review 缓存 hash，确保高亮变化触发重算
