# M2.8 跨端同步范围扩展设计

**日期**：2026-07-12
**目标版本**：v1.11.0-alpha
**前置**：v1.10.1-alpha（坚果云 baseUrl hotfix）
**作者**：weifu0523 + Claude（subagent-driven）

## 背景

v1.10.1-alpha 修复了同步功能的 P0 baseUrl bug。同步**第一次真正工作**。
用户立即提出扩展需求：

> 修改下同步内容，书籍本身，AI聊天历史，书籍标签 都需要同步。
> 我希望在电脑上看的书和聊天可以在手机上接着，同样的手机上看的书回到电脑上继续看继续聊天。

当前同步范围（v1.10.1-alpha）：book metadata, bookNote, annotation, readingProgress, bookmark, freeformNote。
**未覆盖**：书籍 binary 文件、AI 聊天会话/消息、书籍标签。

## 用户决策（2026-07-12 AskUserQuestion）

| 决策点 | 选择 | 备注 |
|---|---|---|
| Phase 3 范围 | **完整实现 Phase 2 + 3** | 今晚全做 |
| 配额策略 | **全部同步，用户自负** | 不设上限，错误从 WebDAV 507 上浮 |
| Tag UI | **顺带补 UI + sync** | BookDetailPage 加 TagEditor |

## 范围

### Phase 2：metadata-only sync（低风险，模式成熟）

- **AI 聊天会话**（`chat_sessions` 表）：双向同步
- **AI 聊天消息**（`chat_messages` 表）：双向同步，含流式追加
- **书籍标签**（`book_tags` 表）：双向同步 + 新增 UI 写入路径

### Phase 3：binary file sync（新基础设施）

- **书籍 binary 文件**（.epub / .pdf）：上传、下载、跨端可用
- 配套：缺失文件时的 UI 状态（"点击下载"占位）

## 非目标

- 跨书 AI 伴读（v1.12+）
- iOS 端（待 CI 走通）
- 配额管理 UI（用户决策：不做）
- 增量同步协议重设计（继续用 last-write-wins + per-device JSONL snapshot）

---

## Phase 2 设计

### 2.1 新 SyncRecordType

`app/lib/services/sync/sync_record.dart`：

```dart
enum SyncRecordType {
  book,
  bookNote,
  annotation,
  readingProgress,
  bookmark,
  freeformNote,
  // M2.8 新增：
  chatSession,
  chatMessage,
  bookTag,
}
```

**稳定性约束**：enum 名字是 wire format，**禁止改名**（旧 snapshot pull 会失败）。

### 2.2 复合主键编码

`book_tags` 表的 PK 是 `(bookId, tag)`，但 SyncRecord 只有单字段 `id`。约定：

```
id = '${bookId}__${tag}'
```

分隔符选 `__`（双下划线）的理由：
- tag 不允许包含 `__`（TagEditor 输入校验加这条规则）
- 与 URL/email/UUID 中常见的 `.`/`@`/`-` 不冲突

Tombstone（删除）通过 bookTag + 复合 id 触发，applier 解析出 `(bookId, tag)` 后 `DELETE FROM book_tags WHERE book_id=? AND tag=?`。

### 2.3 流式追加同步策略

**问题**：`ChatMessagesDao.appendContent` 每次 token 到达都 raw SQL `content = content || ?`。一次 AI 响应 200 token → 200 次 update。若每次都写 outbox，会产生 ~200 行 outbox bloat。

**策略**：分两层
1. `appendContent` 不写 outbox
2. 新增 `ChatRepository.completeStreamingMessage(id)`：读当前行 → bump updatedAt → 写 outbox
3. 4 个 streaming use cases（chapter_guide / recap / socratic_bootstrap / send_message）在 stream 结束后调用 `completeStreamingMessage`

**已存在的写路径**继续 emit sync record：
- `insertMessage` → emit (initial content，可能为空字符串 for AI placeholder)
- `softDelete` → emit tombstone
- `softDeleteSession` → emit session tombstone + 不 emit message tombstones（消息 cascade delete，receiver 检测到 session tombstone 后下次 listMessages 过滤即可）
- `clearSession` → emit session update (updatedAt bumped)，不 emit message tombstones

**中断恢复**：若 streaming 中途被 cancel，`completeStreamingMessage` 不会被调用。该消息不进入 outbox。用户重发 → 重新走完整流程。**接受这个 trade-off**：实现简单 + 不破坏一致性。

### 2.4 ChatRepository 改造

```dart
class ChatRepository {
  ChatRepository(this._db, {SyncRecorder? syncRecorder})
      : _syncRecorder = syncRecorder;
  final SyncRecorder? _syncRecorder;
  // ... existing methods ...
}

// 所有 mutation 方法在 DB write 成功后调用 _syncRecorder?.recordXxx()
```

**注入方式**：通过 Riverpod provider 注入。`chatRepositoryProvider` 在 `core/providers.dart` 改为：

```dart
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.watch(appDatabaseProvider),
    syncRecorder: ref.watch(syncRecorderProvider),
  );
});
```

### 2.5 RemoteRecordApplier tier 重排

当前 3 层：
- tier 0: books
- tier 1: book_notes, bookmarks, reading_progress, freeform_notes
- tier 2: annotations

**新 tier 划分**：
- tier 0: books, book_tags（book_tags 无 FK，但逻辑上是 book 的附属）
- tier 1: book_notes, bookmarks, reading_progress, freeform_notes, **chat_sessions**（FK → books）
- tier 2: annotations, **chat_messages**（FK → chat_sessions）

修改 `applyRecords` 方法的 bucket 分配逻辑。

### 2.6 各 applier 实现

#### _applyChatSession
```sql
SELECT updated_at FROM chat_sessions WHERE id = ?
-- LWW: skip if remote.mtime <= local.updated_at
-- if deleted (payload.deletedAt != null): UPDATE deleted_at + updated_at
-- else: INSERT OR REPLACE id, book_id, title, mode, created_at, updated_at, deleted_at
```

注意：deletedAt 来自 payload（不是 SyncRecord.deleted 字段）。SyncRecord.deleted 是另一层语义（彻底删除 = tombstone）。chat_sessions 的 soft-delete 走 payload.deletedAt 路径。

#### _applyChatMessage
```sql
SELECT updated_at FROM chat_messages WHERE id = ?
-- LWW: skip if remote.mtime <= local.updated_at
-- if deleted (payload.deletedAt != null): UPDATE deleted_at + updated_at
-- else: INSERT OR REPLACE id, session_id, role, content, preset_source,
--       attachment_note_id, attachment_note_snapshot, created_at, updated_at, deleted_at
```

#### _applyBookTag
```sql
-- id = "${bookId}__${tag}"
-- parse bookId + tag from id
-- if record.deleted: DELETE FROM book_tags WHERE book_id=? AND tag=?
-- else: INSERT OR IGNORE INTO book_tags(book_id, tag) VALUES(?,?)
-- no LWW needed (composite PK, idempotent insert)
```

### 2.7 BookDetailPage Tag UI

新增 `TagsSection` widget（inline，不抽到独立文件——YAGNI），位于 BookDetailPage 的 metadata 列表中。

```dart
// In _BookDetailPageState:
Future<void> _addTag(String tag) async {
  await ref.read(bookTagsRepositoryProvider).addTag(bookId: widget.bookId, tag: tag);
  setState(() {}); // refresh
}
Future<void> _removeTag(String tag) async {
  await ref.read(bookTagsRepositoryProvider).removeTag(bookId: widget.bookId, tag: tag);
  setState(() {});
}

// In build:
FutureBuilder<List<String>>(
  future: ref.read(bookTagsRepositoryProvider).tagsOfBook(widget.bookId),
  builder: (_, snap) => TagEditor(
    tags: snap.data ?? [],
    suggestions: [], // TODO: 可选填 allTags
    onChanged: (newTags) { /* diff + apply */ },
  ),
)
```

**TagEditor 输入校验**：禁止 `__` 子串（与复合主键编码冲突）+ 长度上限 32 + trim。

### 2.8 新 BookTagsRepository

新文件 `app/lib/data/repositories/book_tags_repository.dart`：

```dart
abstract class BookTagsRepository {
  Future<List<String>> tagsOfBook(String bookId);
  Future<Set<String>> allTags();
  Future<void> addTag({required String bookId, required String tag});
  Future<void> removeTag({required String bookId, required String tag});
  Future<void> replaceTagsForBook({required String bookId, required List<String> tags});
}

class LocalBookTagsRepository implements BookTagsRepository {
  LocalBookTagsRepository(this._db, {SyncRecorder? syncRecorder})
      : _syncRecorder = syncRecorder;
  // each mutation: call DAO then _syncRecorder?.recordBookTag / recordBookTagDeletion
}
```

DAO（`BookTagsDao`）保持不变；Repository 是新抽象层。

---

## Phase 3 设计

### 3.1 WebDavClient 扩展

新增方法（不修改现有 string-based API）：

```dart
class WebDavClient {
  // ... existing ...

  /// GET binary content as bytes.
  Future<Uint8List> getBytes(String path);

  /// PUT binary content. Returns ETag if server provided (for change detection).
  Future<void> putBytes(String path, List<int> bytes);

  /// PROPFIND with size info. Returns map<filename, sizeInBytes>.
  Future<Map<String, int>> listFilesWithSize(String dirPath);
}
```

实现注意：
- `getBytes` 用 `http.get` + `response.bodyBytes`
- `putBytes` 用 `http.put` + body: bytes
- `listFilesWithSize` 解析 `<D:getcontentlength>` 已在 PROPFIND body 里

### 3.2 远程路径方案

```
/zhiyue/
├── snapshots/
│   ├── <deviceId-A>.jsonl
│   └── <deviceId-B>.jsonl
└── files/
    ├── <bookId-1>.epub
    ├── <bookId-2>.pdf
    └── ...
```

**命名约定**：`<bookId>.<format>`

- `bookId` 是 UUID，无歧义
- `format` 来自 `books.format` 列（'epub' | 'pdf'）
- 接收方根据 metadata 中的 format 决定扩展名

**不变性**：bookId 是 row PK 不会变；format 在导入后不会变。所以 path 稳定。

### 3.3 上传触发

**导入时**：`BookImportService.importFile` 在 book row 插入成功后，触发异步上传（不阻塞导入 UI）。

```dart
// In BookImportService:
final bookId = await _repo.insert(...);
unawaited(_fileSync.uploadBookFile(bookId)); // fire-and-forget
```

**理由**：
- 不阻塞 UI（大文件慢）
- 失败不致命（下次 sync 周期会重试）
- 不依赖 outbox（outbox 是 metadata-only）

**重试机制**：在每次 `sync()` 开始时，扫描本地所有 books，检查哪些**未同步**（`books.file_synced_at IS NULL`），逐个上传。

### 3.4 下载触发

**当 receiver 应用一个 book metadata 时**（`_applyBook`），检查本地是否有 file：

```dart
// In RemoteRecordApplier._applyBook, after INSERT OR IGNORE:
final localPath = await _fileSync.getLocalPath(bookId);
if (!File(localPath).existsSync()) {
  // Mark as "needs download" - don't auto-download (could be expensive)
  await _db.customStatement(
    'UPDATE books SET file_path = ? WHERE id = ?',
    ['__needs_download__', bookId],
  );
}
```

**注意**：当前 `_applyBook` 把 filePath 设为字面量 `'synced'`。改为：
- 若本地文件存在 → 保留本地 path（不变）
- 若本地文件不存在 → 设为 `'__needs_download__'`

### 3.5 新 BookFileSyncService

新文件 `app/lib/services/sync/book_file_sync_service.dart`：

```dart
class BookFileSyncService {
  BookFileSyncService({
    required AppDatabase database,
    required WebDavClient webdav,
    required String localFilesDir, // applicationDocumentsPath/books/
  });

  /// Upload a single book's binary. Marks file_synced_at on success.
  Future<void> uploadBookFile(String bookId);

  /// Download a single book's binary. Updates file_path on success.
  Future<void> downloadBookFile(String bookId);

  /// Scan all books with file_synced_at IS NULL, upload them.
  Future<void> uploadPendingFiles();

  /// Get local file path for bookId. Format-aware.
  Future<String> getLocalPath(String bookId);

  /// Does the local file exist?
  Future<bool> localFileExists(String bookId);
}
```

**schema 变更**：`books` 表新增列 `file_synced_at INTEGER`（nullable）。

Migration v13 → v14:
```dart
'ALTER TABLE books ADD COLUMN file_synced_at INTEGER',
```

### 3.6 UI：缺失文件状态

**Library**：BookCell 显示 overlay 云下载图标（如果 `filePath == '__needs_download__'`）。Tap → trigger download → progress indicator → on complete, open book.

**Reader**：若用户 tap 一本 `__needs_download__` 的书，先弹 progress dialog "正在下载书籍..."，完成后正常打开。

**简化**：MVP 不做后台下载 + 通知，下载必须在 UI 前台完成。失败 → SnackBar 错误。

### 3.7 配额错误处理

WebDAV 507 Insufficient Storage → 抛 `WebDavException(507, ...)`。BookFileSyncService 捕获后：
- 标记该 bookId 为"配额错误"，不再自动重试
- 上浮到 UI（SyncButton 红色 + 冲突列表显示）
- 用户清理坚果云后可手动重试

### 3.8 删除同步

当 book 被本地删除时（`BooksDao.deleteBook`）：
1. 本地 file 删除（已实现）
2. Outbox 写入 book tombstone（已实现）
3. **M2.8 新增**：删除远程 binary 文件 `DELETE /zhiyue/files/<bookId>.<ext>`
4. **M2.8 新增**：删除远程 cover 文件（如果有）

**Receiver 端**：收到 book tombstone → 删除本地 file → 删除本地 row（已实现）。

---

## 风险与缓解

| 风险 | 缓解 |
|---|---|
| 流式 chat 在 sync 期间部分丢失 | completeStreamingMessage hook；中断重发 |
| 大书文件上传阻塞 sync 周期 | 文件上传与 metadata 独立，并行执行；metadata 不等待文件 |
| 坚果云 507 配额爆 | 错误上浮，标记不重试，UI 警告 |
| bookId + tag 复合 key 中 tag 含 `__` | TagEditor 输入校验禁止 `__` |
| migration v14 误生产数据 | ALTER TABLE ADD COLUMN 是 nullable，老数据 file_synced_at=NULL = 未同步 |
| WebDAV 不支持 Range request（断点续传） | 接受整文件重传；坚果云支持的 PROPFIND 已用 |

---

## 测试覆盖目标

- SyncRecord 新 enum 序列化（chatSession, chatMessage, bookTag）
- SyncRecorder.recordChatSession + recordChatMessage + recordBookTag
- ChatRepository mutations → outbox 行写入
- ChatRepository.completeStreamingMessage → emit + bump updatedAt
- RemoteRecordApplier._applyChatSession + LWW
- RemoteRecordApplier._applyChatMessage + LWW
- RemoteRecordApplier._applyBookTag + composite key parse + idempotent insert + tombstone delete
- BookTagsRepository + sync wiring
- WebDavClient.getBytes / putBytes / listFilesWithSize（mock HTTP）
- BookFileSyncService.uploadBookFile / downloadBookFile / uploadPendingFiles
- BookDetailPage TagEditor widget test
- Library BookCell overlay for needs-download
- Integration: 2-device cross-device chat continuation
- Integration: 2-device cross-device book file transfer

**新增测试估算**：~30 tests，目标总测试数 1293 (v1.10.0) → ~1320+。

---

## Schema 变更

仅 1 处：v13 → v14 加列 `books.file_synced_at INTEGER`（nullable）。

drift schema migration 在 `app/lib/data/local/database.dart` `MigrationStrategy.onUpgrade` 加分支：
```dart
if (from < 14) {
  await m.customStatement('ALTER TABLE books ADD COLUMN file_synced_at INTEGER');
}
```

调整 `schemaVersion = 14`。

---

## 文件清单

### 新增

- `app/lib/data/repositories/book_tags_repository.dart`
- `app/lib/services/sync/book_file_sync_service.dart`
- `app/test/data/repositories/book_tags_repository_test.dart`
- `app/test/services/sync/book_file_sync_service_test.dart`
- `app/test/features/library/widgets/book_cell_needs_download_test.dart`
- `app/test/integration/sync/cross_device_chat_continuation_test.dart`
- `app/test/integration/sync/cross_device_book_file_transfer_test.dart`

### 修改

- `app/lib/services/sync/sync_record.dart` — 加 3 个 enum 值
- `app/lib/services/sync/sync_recorder.dart` — 加 recordChatSession / recordChatMessage / recordBookTag / recordBookTagDeletion
- `app/lib/data/local/daos/chat_repository.dart` — wire SyncRecorder + completeStreamingMessage
- `app/lib/features/ai_chat/use_cases/run_chapter_guide_use_case.dart` — stream end hook
- `app/lib/features/ai_chat/use_cases/run_recap_use_case.dart` — stream end hook
- `app/lib/features/ai_chat/use_cases/run_socratic_bootstrap_use_case.dart` — stream end hook
- `app/lib/features/ai_chat/use_cases/send_message_use_case.dart` — stream end hook
- `app/lib/services/sync/remote_record_applier.dart` — 3 个 _applyXxx + tier reorder
- `app/lib/services/sync/web_dav_client.dart` — getBytes / putBytes / listFilesWithSize
- `app/lib/services/sync/web_dav_sync_engine.dart` — invoke BookFileSyncService.uploadPendingFiles in sync()
- `app/lib/data/local/database.dart` — schemaVersion 14 + migration
- `app/lib/data/local/tables/books.dart` — file_synced_at column
- `app/lib/data/local/daos/books_dao.dart` — deleteBook also delete remote file (via callback)
- `app/lib/data/repositories/local_book_repository.dart` — wire BookFileSyncService on import + delete
- `app/lib/features/library/pages/book_detail_page.dart` — TagEditor section
- `app/lib/features/library/widgets/book_cell.dart` — needs-download overlay
- `app/lib/features/library/widgets/book_list_tile.dart` — needs-download overlay
- `app/lib/core/providers.dart` — chatRepositoryProvider / bookTagsRepositoryProvider / bookFileSyncServiceProvider
- `app/lib/features/reader/pages/reader_page.dart` — needs-download gate (or before-navigation gate in library)
- `app/pubspec.yaml` — version 1.11.0-alpha
- `app/windows/installer/zhiyue.iss` — version 1.11.0-alpha
- `CHANGELOG.md` — 1.11.0-alpha section
- `README.md` — badge + status bullet

---

## 升级路径

- 桌面：覆盖安装，schema v13 → v14 自动迁移
- Android：sideload APK，schema 自动迁移
- WebDAV 服务端：第一次 sync 时 `MKCOL /zhiyue/files/` 创建目录
- 老版本（v1.10.1-alpha 及以下）：不识别 chatSession/chatMessage/bookTag SyncRecordType，**会在 fromJson 抛 enum byName 异常**——需要兜底

### 老客户端兼容

`SyncRecord.fromJson` 用 `SyncRecordType.values.byName(json['type'])`。未知 enum 值会抛。

**修复**：改为 `SyncRecordType.values.asNameMap()[json['type']]`，未知类型行 skip（不抛）。这样老客户端 pull 到 M2.8 snapshot 时不会 crash，只是忽略新类型记录。

---

## 验收标准

1. dev 机导入新书 → sync → 用户手机看到书 + tap → 下载完成 → 阅读
2. dev 机某书发起 AI 问答 → sync → 用户手机该书的 AI 抽屉看到完整对话
3. dev 机给书加 tag "AI" → sync → 用户手机该书显示 tag "AI"
4. dev 机删除书 → sync → 用户手机该书 + 文件 + 相关 chat 都消失
5. v1.10.1-alpha 老客户端 pull 到 M2.8 snapshot 不 crash（新类型记录被忽略）

---

## 后续（v1.12+）

- 配额管理 UI（如果用户反馈需要）
- 后台下载 + 通知
- iOS 端 binary 同步
- 跨书 AI 伴读
