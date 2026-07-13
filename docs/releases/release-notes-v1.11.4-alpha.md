# v1.11.4-alpha

**发布日期**：2026-07-13
**类型**：hotfix
**上一版本**：v1.11.3-alpha

## 摘要

修复用户在手机端测试 v1.11.3-alpha 同步时报告的两个 bug：

1. **同步书架云图标不消失 + 每次点书都重新下载**（drift stream 通知
   缺失）
2. **跨设备同步的书籍封面缺失**（PC 绝对路径 + 漏掉封面 binary 同步）

附带修复：删书不删本地封面文件（v1.11.3-alpha 修了 library binary，
本次补上 cover binary）。

## 根因

### 根因 1：drift stream 通知路径未触发

drift 数据库默认不启用 `streamSqlUpdates`（本项目 database connection
未开）。StreamQueryStore 的通知机制完全依赖 **DSL 写**（`into(t).insert`
/ `update(t)..where().write()` / `delete(t)..where().go()`）。

但 `RemoteRecordApplier._applyBook` 用 `customInsert('INSERT OR IGNORE
INTO books(...) VALUES(...)')`、`BookFileSyncService.uploadBookFile` /
`downloadBookFile` 用 `customStatement('UPDATE books SET ...')`——绕过
DSL，stream 不知道 DB 已变。

结果：用户在手机端拉取元数据后，`select(books).watch()` stream 不 emit，
library UI 仍显示陈旧状态。必须重启 app 才能看到新书。**同一根因也导致
每次点同步书都重新下载**——downloadBookFile 完成后 `file_path` 已变为
本地路径，但 stream 不通知，widget 看到的还是 `__needs_download__`
sentinel，再次 tap 又触发完整 binary 下载，**浪费 WebDAV 流量**。

### 根因 2：封面 PC 绝对路径跨端无效 + 漏掉 binary 同步

`SyncRecorder.recordBook` 此前把 `books.cover_path`（PC 绝对路径如
`C:\Users\1\Documents\covers\{bookId}.png`）原样写入 sync payload。

接收端：
- `cover_path` 指向发送方机器上不存在的路径
- `coverLoaderProvider` 的 `File(path).existsSync()` 始终 false
- UI 回退到纯色背景 + 书名第一字占位图

M2.8 的 binary 同步体系（`/zhiyue/files/{bookId}.{format}`）只覆盖书籍
本体，**完全漏掉封面**。

## 修复

### 代码改造（按任务粒度）

| 任务 | 范围 | 关键文件 |
|---|---|---|
| T1 | drift DSL books 表写流式通知 | `remote_record_applier.dart` + `book_file_sync_service.dart` |
| T2 | BookFileSyncService 封面同步扩展 | `book_file_sync_service.dart` |
| T3 | recordBook payload 契约 hasCover | `sync_recorder.dart` + `remote_record_applier.dart` |
| T4 | coverLoaderProvider + SyncController.downloadCoverFile | `cover_loader_provider.dart` + `sync_controller.dart` |
| T5 | 删书联动 cover 文件 | `local_book_repository.dart` |
| T6 | boot + provider wiring | `providers.dart` + `app_providers.dart` + `main.dart` |

### T1：drift DSL 改造（3 个位点 + DELETE 分支）

`_applyBook` INSERT + 2 个 DELETE 分支 → DSL：
```dart
await (_db.into(_db.books).insert(
  BooksCompanion.insert(...),
  mode: InsertMode.insertOrIgnore,
));
await (_db.delete(_db.books)..where((t) => t.id.equals(record.id))).go();
```

`uploadBookFile` / `downloadBookFile` 的 `customStatement('UPDATE ...')`
→ DSL：
```dart
await (_db.update(_db.books)
      ..where((t) => t.id.equals(bookId)))
    .write(BooksCompanion(fileSyncedAt: Value(now)));
```

DSL 写会自动触发 StreamQueryStore 通知，`select(books).watch()` stream
emit，widget 立即看到 DB 变化。

### T2：封面 binary 同步（平行于书籍 binary）

**新常量**：
```dart
static const String remoteCoversDir = '/zhiyue/covers';
static const String needsCoverDownloadSentinel = '__needs_cover_download__';
static const String _coverExtension = 'png';
```

**新构造器参数**：`String? coversDir`（null = 封面同步禁用，widget 测试
保持兼容）。

**新方法**：
- `uploadCoverFile(bookId)`：读 `cover_path`；null/sentinel 跳过；读
  bytes → PUT `/zhiyue/covers/{id}.png`（先 ensureAncestors）。
- `downloadCoverFile(bookId)`：检查本地已存在则幂等跳过；GET bytes →
  写文件 → DSL UPDATE `cover_path = localPath`；**404 时清空
  `cover_path = NULL`** 避免无限重试。
- `deleteCoverFile(bookId)`：DELETE `/zhiyue/covers/{id}.png`（404
  swallow）。

**piggyback**：
- `uploadBookFile` binary PUT 成功 + stamp `file_synced_at` 后，调
  `_uploadCoverBestEffort(bookId)`——best-effort，cover 失败不阻塞。
- `deleteRemoteFile` binary DELETE 后追加 `deleteCoverFile`——best-effort。

### T3：recordBook payload 契约

删除 `String? coverPath` 参数，加 `required bool hasCover`：

```dart
Future<void> recordBook({
  required String id,
  ...
  required bool hasCover,  // 替代 coverPath
  ...
})
```

payload：`'hasCover': hasCover`（不再传 `coverPath`）。

`_applyBook` 解析：
```dart
final hasCover =
    (p['hasCover'] as bool?) ?? _sanitizeLegacyCoverPath(p['coverPath']);
final coverPathToWrite = hasCover
    ? BookFileSyncService.needsCoverDownloadSentinel
    : null;
```

**向后兼容**：`_sanitizeLegacyCoverPath` 处理旧 snapshot——非空字符串
视为 `hasCover=true`，**绝对路径被丢弃**，绝不写入本地行。

### T4：coverLoaderProvider + SyncController.downloadCoverFile

`coverLoaderProvider` 改为 `FutureProvider.autoDispose.family`：
- autoDispose：library_page + bookshelf_dialog 是仅有的订阅方，关闭时
  自动释放 Riverpod cache。
- family：按 bookId 分桶，并发 widget 共享同一 Future（Riverpod dedup）。
- sentinel 触发：`cover_path == needsCoverDownloadSentinel` 时调
  `SyncController.downloadCoverFile`；用 `ref.keepAlive()` 防止
  autoDispose 在 await 期间取消 Future；成功后重读 book 拿到本地路径。

`SyncController` 加 `coversDir` 字段 + `downloadCoverFile` 公共方法
（mirror `downloadBookFile`）。

### T5：删书联动 cover 文件

`LocalBookRepository.delete` / `deleteBooks` 加 `_deleteLocalCoverFile`
helper（mirror v1.11.3-alpha 的 `_deleteLocalLibraryFile`）：
- 检查 `cover_path` 非 null 且非 sentinel 才删
- best-effort swallow 异常
- 复用 `FileStorage.deleteCoverFile`（M2.8 已存在）

### T6：boot + provider wiring

- `providers.dart` 加 `globalCoversDirOverride` + `coversDirProvider`
  （mirror `localFilesDirOverride` 模式）
- `main.dart` boot 时 `globalCoversDirOverride = storage.coversDir.path`
- `app_providers.dart` SyncController 构造传
  `coversDir: ref.watch(coversDirProvider)`

## 决策

### 为何用 sentinel 而非 NULL 表示「待下载」

`books.cover_path` 有三种状态：
1. NULL：明确无封面（PDF / 旧版本拉取后 404）
2. sentinel `__needs_cover_download__`：远端有封面，本地未下载
3. 本地绝对路径：已下载

如果只用 NULL，无法区分「PDF 无封面」和「EPUB 待下载」——后者需要触发
懒下载。sentinel 让 `coverLoaderProvider` 明确知道何时触发。

### 为何 piggyback 而非独立 upload

封面是装饰性，不影响阅读功能。如果独立扫描上传，需要新增
`cover_synced_at` 列做去重（schema 迁移 v14→v15）。piggyback 在 binary
上传生命周期上，零 schema 变更，零额外扫描。

代价：如果 binary PUT 507（配额满）但 cover PUT 也想试，会被 binary
失败提前中止——但 binary 失败本来就要重试，cover 跟着重试即可。

### 为何 downloadCoverFile 404 时清空 NULL 而非保留 sentinel

sentinel 保留会导致每次 widget 渲染都触发 downloadCoverFile → GET
404 → return false → 下次渲染再触发——死循环（虽然 Riverpod cache
有 dedup，但 autoDispose 后会重新触发）。

清空 NULL 明确表示「尝试过，没有」，`coverLoaderProvider` 直接返回 null
显示占位图，不再重试。

### 为何 wire format 用 hasCover 而非保留 coverPath

PC 绝对路径在接收方：
1. **无意义**：不同 OS（Windows `C:\` vs Android `/storage/`）、不同
   用户目录（`1` vs `weifu0523`）——路径不可用
2. **泄露隐私**：发送方用户名 + 目录结构暴露给所有同步设备
3. **冗余**：M2.8 已有 binary 同步体系，路径无意义

`hasCover: bool` 是接收方需要的全部信息——知道有封面就触发懒下载。

## 测试

新增 28 个测试（T1-T5）+ 2 个 helper 扩展（FakeBookRepository
updateCoverPath + cross_device stub ensureAncestors/delete）：

| 任务 | 新测试数 | 文件 |
|---|---|---|
| T1 drift stream emit | 4 | book_file_sync_service_test + remote_record_applier_book_test |
| T2 cover 同步 | 12 | book_file_sync_service_test |
| T3 cover 契约 | 4 | remote_record_applier_book_test |
| T4 coverLoaderProvider sentinel | 3 | cover_loader_provider_test |
| T5 删书联动 cover | 5 | local_book_repository_test |

**总测试**：1473（1449 pass + 14 skip + 10 baseline fail）。

baseline fail 全部 pre-existing，与本次改动无关：
- `router_test: router /book/:id navigates to ReaderPage`
- `book_import_service_test: importFile for EPUB writes coverPath`（fixture 缺）
- `reader_page_test` x 5（pre-existing chrome 控件问题）
- 3 个 reader widget 测试编译错误（pre-existing）：
  - `reader_page_pdf_integration_test.dart:60`
  - `reader_ai_drawer_integration_test.dart:43`
  - `reader_drawer_test.dart:198`

## 已知限制

- **历史孤儿封面不自动清理**：本修复保证未来删书时同时删本地封面，但
  旧版本残留的孤儿封面（`<coversDir>/*.png`）不会自动扫描清除。用户可
  手动删 `<coversDir>/` 下不再被数据库引用的文件。
- **配额满时封面 best-effort**：若坚果云配额已满，binary PUT 成功但
  cover PUT 507 时，书籍可用但封面缺（显示占位图）。
- **legacy snapshot 兼容**：旧版本推送的 snapshot 含绝对 `coverPath`
  字符串，本版本通过 `_sanitizeLegacyCoverPath` 兼容——非空字符串视为
  `hasCover=true`，路径被丢弃。如果发送方未真正上传过封面 binary（旧
  版本无 T2 piggyback），接收方下载 404 后 cover_path 设为 NULL，UI
  显示占位图（"装饰性"语义）。

## 升级指引

直接覆盖安装即可。schema 无变更（仍 v14），无需迁移。

打开 v1.11.4-alpha 后：

- **跨设备同步的书籍封面正常显示**：电脑端导入 epub → 同步 → 手机端
  书架出现 + 封面自动下载后显示真实图（不再纯色 + 第一字）。
- **同步书架立即刷新**：拉取元数据后无需重启，drift DSL 写触发 stream
  通知，widget 立即看到新书 / 删书 / file_path 更新。
- **不再每次重新下载**：第一次点同步书下载 binary 后，drift DSL 写
  `file_path = localPath`，stream 通知 widget，第二次点直接打开（不再
  弹下载框），节省 WebDAV 流量。
- **删书联动 cover 文件**：未来删书时同时删本地 library binary + 本地
  cover binary，不再积累孤儿。
