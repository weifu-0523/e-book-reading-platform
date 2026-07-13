# v1.11.3-alpha

**发布日期**：2026-07-13
**类型**：hotfix
**上一版本**：v1.11.2-alpha

## 摘要

修复用户报告的「清空书架 + 删除坚果云 JSON 后，重新导入同一本书失败」bug：

```
导入失败 : PathAccessException: Cannot open file,
path = 'C:\Users\1\Documents\library\62777ae4e49aa03ae03ec76e62e3bc1f7701eb12.epub'
(OS Error: 拒绝访问。 , errno = 5)
```

## 根因

两层根因叠加：

### 根因 1：删书不删本地 library 文件

`LocalBookRepository.delete` / `deleteBooks` 此前只做三件事：

1. `SyncRecorder.recordBook(deleted=true)` — 写 outbox tombstone
2. `_remoteFileDeleter?(id)` — best-effort 删云端 binary
3. `_dao.deleteBookCascade(id)` — 删数据库行 + 子表

**完全没动 `library/{hash}.{ext}` 内容寻址文件**。用户清空书架后，DB 里
book 行清空，但 `C:\Users\1\Documents\library\` 下 5 个 `.epub` / `.pdf`
文件原封不动地留着——孤儿文件，永远不缩。

### 根因 2：ReadOnly attribute + Windows GENERIC_WRITE 拒绝

用户重新导入同一本书时，`BookImportService` 计算 hash = `62777ae4...`，
调 `FileStorage.storeLibraryFileFromBytes` 写
`library/62777ae4e49aa03ae03ec76e62e3bc1f7701eb12.epub`。该文件已存在
（孤儿），且其 Windows 文件 attribute 是 `ReadOnly, Archive`（来源不明，
可能是 OneDrive / 杀软 / 备份工具 / 早期版本残留——zhiyue 代码里没有写
ReadOnly 的逻辑，grep 验证）。

`File.writeAsBytes` 在 Windows 上底层调 `CreateFileW(GENERIC_WRITE)`，
对 ReadOnly attribute 的文件，Win32 API 必返回 `ERROR_ACCESS_DENIED`，
Dart 抛 `PathAccessException (errno=5)`。

异常路径：`storeLibraryFileFromBytes` → `BookImportService.importFile` →
`BookOpenBridge` / Library import 入口 → UI 显示「导入失败 : ...」。

## 修复

### 代码

**`app/lib/data/local/file_storage.dart`** — `storeLibraryFileFromBytes`
和 `deleteLibraryFile` 添加 errno=5 retry：

```dart
Future<File> storeLibraryFileFromBytes({
  required List<int> bytes,
  required String fileHash,
  required String extension,
}) async {
  final dest = File(p.join(libraryDir.path, '$fileHash.$extension'));
  try {
    await dest.writeAsBytes(bytes, flush: true);
  } on PathAccessException catch (e) {
    if (e.osError?.errorCode == 5 && await dest.exists()) {
      await _clearReadOnlyAttribute(dest);
      await dest.writeAsBytes(bytes, flush: true);
    } else {
      rethrow;
    }
  }
  return dest;
}

Future<void> _clearReadOnlyAttribute(File file) async {
  if (!Platform.isWindows) return;
  final result = await Process.run('attrib', ['-R', file.path]);
  if (result.exitCode != 0) {
    throw PathAccessException(
      file.path,
      OSError('attrib -R failed (exit ${result.exitCode}): ${result.stderr}'),
      'Cannot clear ReadOnly attribute',
    );
  }
}
```

`deleteLibraryFile` 用同样的 try/catch + retry 模式。

**`app/lib/data/repositories/local_book_repository.dart`** — `delete` /
`deleteBooks` 在删 DB row 之前 capture `fileHash + format`，之后
best-effort 删本地 library 文件：

```dart
@override
Future<void> delete(String id) async {
  // Capture BEFORE dao delete — row is gone after deleteBookCascade.
  final row = await _dao.getById(id);
  // ... existing sync recorder + remote deleter ...
  await _dao.deleteBookCascade(id);
  // T12: best-effort delete the local library binary.
  await _deleteLocalLibraryFile(row);
}

Future<void> _deleteLocalLibraryFile(db.Book? row) async {
  if (_fileStorage == null || row == null) return;
  final format = bookFormatFromDb(row.format);
  try {
    await _fileStorage.deleteLibraryFile(
      hash: row.fileHash,
      extension: format.fileExtension,
    );
  } catch (_) {
    // best-effort — orphan file may remain (space leak only).
  }
}
```

`deleteBooks` 同样改：先 capture 全部 rows，循环删 remote + 删本地。

**`app/lib/core/providers.dart`** + **`app/lib/main.dart`** — 把
`FileStorage` 实例经由 `globalFileStorage` 全局变量注入到
`bookRepositoryProvider`：

```dart
// providers.dart
FileStorage? globalFileStorage;

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocalBookRepository(
    db,
    syncRecorder: SyncRecorder(db.syncOutboxDao),
    fileStorage: globalFileStorage,
  );
});

// main.dart (during boot)
final storage = await FileStorage.create();
localFilesDirOverride = storage.libraryDir.path;
globalFileStorage = storage;
```

仿 `localFilesDirOverride` 模式（M2.8 T11）：boot 时同步 set，ProviderContainer
构造时已就绪；widget 测试 / path_provider 不可用时保持 null，repository
跳过文件删除（向后兼容）。

## 决策

### 为何不修 schema 给 library 文件加引用计数

正确做法是给 `books` 表加 `library_file_refcount` 列，多本书引用同一 hash
时引用计数 +1，删书 -1，归零才删文件。但本项目 `books.file_hash` 有
UNIQUE 约束（`idx_books_file_hash`），即 hash 已强制一本书一文件，无需引用
计数——直接 best-effort 删即可。

### 为何 `_clearReadOnlyAttribute` 用 `attrib` 而不是 Win32 API

dart:io 没有跨平台 attribute API。两个选项：

1. `Process.run('attrib', ['-R', path])` — 系统工具，Windows 内置，行为稳定
2. 通过 `package:win32` 调 `SetFileAttributesW` — 需要新依赖

选 1：避免为单点功能引入新依赖。`attrib` 在所有 Windows 版本上都可用，
exit code 0/非 0 区分明确。POSIX 平台 `Platform.isWindows` gate 直接 no-op。

### 为何 capture row 在 dao delete 之前

`_dao.deleteBookCascade(id)` 之后 `books` 表行已不存在，无法再读
`file_hash` / `format` 列。必须在删之前 query 出来。这与 `_remoteFileDeleter`
hook 的设计理由一致（M2.8 T10）。

## 测试

新增 6 个回归测试：

### `app/test/data/local/file_storage_test.dart`（2 个，Windows-only）

1. **`storeLibraryFileFromBytes clears ReadOnly on retry`** — 预置
   `{hash}.epub` 文件 + `attrib +R` 标 ReadOnly，调
   `storeLibraryFileFromBytes` 同 hash，验证内容是新 bytes + attribute
   不再含 R。
2. **`deleteLibraryFile clears ReadOnly on retry`** — 同上但走 delete 路径。

POSIX 平台用 `if (!Platform.isWindows) return;` + `testOn: 'windows'` 双重
gate，跳过测试（ReadOnly 不阻塞 POSIX 写）。

### `app/test/data/repositories/local_book_repository_test.dart`（4 个）

1. **`delete() removes the local library binary`** — 插书 + 写 library
   文件，调 `repo.delete`，验证 DB 行 + 文件都消失。
2. **`deleteBooks() removes each local library binary`** — 批量路径等价测试。
3. **`delete() with no fileStorage leaves library file (backwards compat)`**
   — 不注入 fileStorage 时，文件保留（widget 测试场景）。
4. **`delete() still succeeds when library file is ReadOnly`** — v1.11.2 +
   v1.11.3 复合回归：Windows-only，预置 ReadOnly 文件，验证 delete 不抛
   且文件被清。

## 已知限制

- **历史孤儿文件不自动清理**：本修复保证未来删书时同时删本地文件，但
  旧版本残留的孤儿文件不会自动扫描清除。用户可手动删
  `C:\Users\1\Documents\library\` 下不再被数据库引用的文件，或直接清空
  整个目录（重新导入时会重建）。
- **errno=5 非 ReadOnly 原因仍会失败**：例如文件被另一进程独占打开
  （zhiyue 自身的 reader 句柄泄漏 / 杀软实时扫描 / OneDrive 上传中），
  `attrib -R` 后再写仍会 errno=5。这种场景下异常向上传播，由 import
  调用方提示用户。未来可加 file-lock 等待重试（v1.12+）。

## 升级指引

直接覆盖安装即可。schema 无变更（仍是 v14），无需迁移。

打开 v1.11.3-alpha 后：

- **未来删书**：详情页红色 FAB 删除 → DB + library 文件 + 远程（如启用
  同步）三者一起清，不再积累孤儿。
- **重新导入同一本书**：即使目标 hash 已有 ReadOnly 文件，自动清
  attribute 后重写。
- **历史孤儿清理**（手动）：在 Windows 文件管理器或 PowerShell 中删
  `C:\Users\1\Documents\library\` 下不再需要的 `.epub` / `.pdf` 文件，
  或直接清空整个目录。
