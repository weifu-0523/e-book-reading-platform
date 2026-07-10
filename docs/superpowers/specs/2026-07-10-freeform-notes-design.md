# Freeform Notes 设计（Bug #3）

> **状态**：draft, awaiting user review
> **日期**：2026-07-10
> **来源**：用户测试反馈（2026-07-10）
> **范围**：M2.8 / v1.9.0-alpha

## 上下文

用户报告（2026-07-10）：

> 在左侧抽屉笔记页面，需要允许用户自建笔记。用来存放 AI 生成的有意义的内容或者用户自己的感悟。

现有"笔记"概念全部依附于书中具体文字位置（`annotations` 表，5 色高亮 + note 字段）。用户缺少一种**不依附于书中位置**的笔记——可能来自 AI 对话里某段想保留的内容，也可能是阅读时突然产生的想法。

## 目标

新增 freeform note（自由笔记）：

1. **Per-book**：每本书有自己的 freeform notes，与现有高亮/笔记同处一个抽屉
2. **Global**：跨书汇总视图，所有书的 freeform notes 都能聚合到一处
3. **Markdown 内容**：支持标题、列表、加粗（与 AI 消息渲染相同的 `flutter_markdown`）
4. **手动创建**：用户从"+"按钮新建，自己输入或从 AI 对话复制粘贴（AI 消息一键导出留下一版本）
5. **跨端同步**：与高亮/笔记/书签一致的 last-write-wins + outbox 流水线

## 非目标（YAGNI）

- AI 对话消息"导出到笔记"按钮 — 下一版本（用户已确认）
- 富文本 WYSIWYG 编辑器 — 用纯 TextField + Markdown 预览切换即可
- 全文搜索接入 `annotations_fts` — freeform notes 体量小，单独 SQLite LIKE 查询够用
- 笔记内附件（图片/文件）— 纯文本先走通
- 标签 / 分类 — 暂用书名作为天然分组

## 数据模型

### 新表 `freeform_notes`（drift schema bump 12 → 13）

```dart
class FreeformNotes extends Table {
  TextColumn get id => text()();                              // uuid
  TextColumn get bookId => text().nullable().customConstraint( // null = global
      'REFERENCES books(id) ON DELETE CASCADE')();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get content => text()();                          // Markdown
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();                // LWW tiebreaker
  IntColumn get color => int().withDefault(const Constant(0))(); // 0=默认, 1-5 与高亮色对齐

  @override
  List<Set<Column>> get uniqueKeys => const [];
}
```

索引：
- `idx_freeform_notes_book ON freeform_notes(book_id, updated_at DESC)` — per-book 列表
- `idx_freeform_notes_updated ON freeform_notes(updated_at DESC)` — global 列表

迁移（`onUpgrade` from < 13）：`m.createTable(freeformNotes)` + 两个索引。无数据回填。

### SyncRecord 扩展

```dart
enum SyncRecordType {
  book,
  bookNote,
  annotation,
  readingProgress,
  bookmark,
  freeformNote,  // 新增
}
```

JSON payload：
```json
{
  "id": "uuid",
  "type": "freeformNote",
  "mtime": "2026-07-10T12:00:00Z",
  "deleted": false,
  "payload": {
    "bookId": "uuid-or-null",
    "title": "...",
    "content": "# 标题\n正文...",
    "createdAt": "2026-07-10T12:00:00Z",
    "color": 0
  }
}
```

### RemoteRecordApplier tier

加到 **tier 1**（midTier，与 book_notes/bookmarks/reading_progress 同层）：

```dart
case SyncRecordType.bookNote:
case SyncRecordType.bookmark:
case SyncRecordType.readingProgress:
case SyncRecordType.freeformNote:   // 新增
  midTier.add(r);
```

理由：`book_id` 是 nullable（全局笔记不需要 book），per-book 笔记依赖 books 表已存在（tier 0 已确保）。即使全局笔记在 tier 0 / 1 都行，归到 tier 1 与同性质（有可选 book_id 引用）的 bookmark 一致。

新增 `_applyFreeformNote(record)` 方法（模式同 `_applyBookmark`：SELECT updated_at → 比较 → INSERT OR REPLACE / DELETE）。

## DAO

`lib/data/local/daos/freeform_notes_dao.dart`：

```dart
class FreeformNotesDao {
  Future<String> create({String? bookId, required String title, required String content, int color = 0});
  Future<void> update({required String id, String? title, String? content, int? color});
  Future<void> softDelete(String id);  // DELETE row + enqueue tombstone
  Future<List<FreeformNote>> listByBook(String bookId);   // updated_at DESC
  Future<List<FreeformNote>> listAll();                   // 全部（含 bookId=null）
  Future<FreeformNote?> getById(String id);
}
```

每个 mutate 方法 **同步** 写 `sync_outbox`（参照 `BookmarksDao` 现有模式），保证：

```dart
await db.transaction(() async {
  await db.customInsert('INSERT OR REPLACE INTO freeform_notes ...');
  await outbox.enqueue(recordId: id, recordType: 'freeformNote', payloadJson: ...);
});
```

## UI

### 1. NoteEditPage（新建/编辑）

`lib/features/notes/pages/note_edit_page.dart`：

- AppBar：title（编辑模式显示笔记 title，新建模式显示"新笔记"）+ 保存 IconButton + 溢出菜单（删除/颜色）
- Body：Column
  - Title TextField（顶部固定，single line）
  - 切换按钮（编辑 / 预览）
  - 编辑模式：Content TextField（multiline, maxLines=null）
  - 预览模式：`flutter_markdown.MarkdownBody(data: content)`
- 保存即 write-through（每次 onChanged debounce 500ms 落盘，与 TypographyPersister 同模式 — 避免 exit(0) 截断 dispose Future）

路由：`/notes/new?bookId=...` 或 `/notes/:id`

### 2. Reader 抽屉 notes tab（per-book）

修改 `notes_drawer.dart` 的 `NotesDrawerContent`：

- Header 行尾加 `IconButton(Icons.add)` → push `/notes/new?bookId=...`
- 现有 `annotations` 列表上方加 "自由笔记" section（仅当该书有 freeform notes 时显示）
  - 每条 ListTile：title（笔记 title）+ subtitle（content 前 60 字符 preview）
  - tap → push `/notes/:id`
  - 该 section 在"本书高亮与笔记" section 上方

### 3. NotesPage（per-book 全屏页面）

`lib/features/notes/pages/notes_page.dart` 已存在（M3.4 交付）。加同样的 freeform section + "+" FAB。

### 4. 全局读书笔记库入口

修改 `_LibraryNavigationDrawer`（`library_page.dart:482`）：

```dart
ListTile(
  leading: const Icon(Icons.menu_book),
  title: const Text('读书笔记库'),
  onTap: () {
    Navigator.pop(context);
    context.push('/notes-library');  // 新路由
  },
),
```

新增 `GlobalFreeformNotesPage`：列出所有 freeform notes（按 updated_at DESC），按 book title 分组（null book 归到"通用"分组）。tap 进 NoteEditPage。

### 5. 响应式

- compact：单栏（list → detail push 路由）
- medium/expanded：双栏（MasterDetail 用现有 `ResponsiveLayoutBuilder`）— 第一版可全部用单栏 + push 路由，双栏留 v1.9.1（参照 S1 T13/T15 plan 内的逃生通道）

## 测试策略

| 层 | 测试 |
|---|---|
| DAO | create/update/softDelete 写 outbox + 表行；listByBook/listAll 排序；FK cascade（删 book → freeform notes 自动删） |
| Sync | `_applyFreeformNote` last-write-wins；tombstone 删除；tier 1 排序正确 |
| Widget | NoteEditPage save→debounce→落盘；NotesDrawerContent "+" 按钮 + freeform section；GlobalFreeformNotesPage 分组 |
| 集成 | 端到端：push freeformNote → 另一设备 pull → 应用 → 验证 |

## 范围估算

| Task | 内容 |
|---|---|
| T1 | drift schema 加 FreeformNotes 表 + 迁移 v12→v13 + 索引 |
| T2 | FreeformNotesDao（CRUD + outbox hook + DAO 单测） |
| T3 | SyncRecordType.freeformNote + JSON 序列化 + DAO tombstone |
| T4 | RemoteRecordApplier `_applyFreeformNote` + tier 调整 + 测试 |
| T5 | NoteEditPage（编辑/预览切换 + write-through debounce） |
| T6 | Reader drawer freeform section + "+" 按钮 + 改 NotesDrawerContent |
| T7 | NotesPage freeform section + "+" FAB |
| T8 | GlobalFreeformNotesPage + 路由 + drawer 入口 |
| T9 | 集成测试：端到端 sync freeformNote |
| T10 | CHANGELOG / README / release-notes-v1.9.0-alpha.md |

约 10 个 task，~3-5 小时（含 review）。

## 风险

1. **schema bump 失败风险**：现有用户从 v12 升 v13，迁移必须幂等。drift schema migration 已有规范，按现有 onUpgrade 模式（`if (from < 13) { m.createTable(freeformNotes); ... }`）即可。
2. **FK cascade 误删**：`bookId` FK `ON DELETE CASCADE` 意味着删 book 时所有 per-book freeform notes 也删。这是期望行为（与 bookmarks/annotations 一致）。但同步流程里 book 的 tombstone 可能晚于 freeformNote 应用，导致 orphan。**决策**：freeformNote 的 _apply 在 bookId != null 且 book 不存在时，emit conflict（不静默丢弃，与现有 annotations 同模式）。
3. **同步顺序**：book 的 tombstone 早于 freeformNote 时，FK cascade 会连带删 freeformNote。这是正确行为。
4. **Markdown XSS**：`flutter_markdown` 默认不渲染 inline HTML，无 XSS 风险。但 code block 可能包含恶意代码 — 仅显示，不执行，安全。

## 用户决策点（需确认）

1. **版本号**：v1.9.0-alpha（含 Bug 1+2 修复 + freeform notes）？还是 v1.8.1-alpha（仅 Bug 1+2）+ v1.9.0-alpha（freeform notes）分两次发版？
2. **路由命名**：`/notes-library` vs `/freeform-notes` vs `/thoughts`？
3. **是否需要"全部笔记" / "通用笔记"（bookId=null）的支持**？或者第一版只做 per-book（去掉 global 入口）？
