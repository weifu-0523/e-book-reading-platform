# v1.11.2-alpha

**发布日期**：2026-07-13  
**类型**：hotfix  
**上一版本**：v1.11.1-alpha

## 摘要

修复用户报告的「删书静默失败」bug：在书架点击删除、确认对话框弹出、点确认后，书未被删除，且没有任何错误提示。

## 根因

9 个子表的 FK to `books(id)` 都缺 `ON DELETE CASCADE`：

| 表 | 当前 | 文档曾声称 |
|---|---|---|
| `book_notes` | NO ACTION | — |
| `annotations` (FK→book_notes) | NO ACTION | — |
| `reading_progress_table` | NO ACTION | — |
| `book_typography_overrides` | NO ACTION | — |
| `ai_summaries` | NO ACTION | — |
| `bookmarks` | NO ACTION | 自承「走应用层删除路径」但**没走** |
| `chat_sessions` | NO ACTION | — |
| `chat_messages` (FK→chat_sessions) | NO ACTION | — |
| `freeform_notes` | NO ACTION | **谎称** CASCADE（line 26）|
| `book_tags` | ✅ CASCADE | 唯一正确 |

drift 的 `.references(Books, #id)` 不带 `customConstraint` 时生成 `REFERENCES books(id)`，SQLite 默认 `NO ACTION`。在 `PRAGMA foreign_keys = ON`（`database.dart:303`）下，`DELETE FROM books WHERE id = ?` 只要存在任一关联行就抛 `SqliteException(787): FOREIGN KEY constraint failed`。

异常路径：`BooksDao.deleteBook` → `LocalBookRepository.delete` → `libraryControllerProvider.notifier.deleteBook` → `BookDetailPage._confirmDelete`（FAB onPressed，无 try/catch）→ Flutter framework 默认错误处理器 → **静默吞掉**。用户看到的是「确认框弹出 → 点确认 → 啥都没发生」。

为什么现有测试没抓到：`local_book_repository_test.dart` setUp 只插书 + 标签（标签 CASCADE OK），从未覆盖「书有关联行」的真实场景。

## 修复

### 代码

**`app/lib/data/local/daos/books_dao.dart`** — 新增 `deleteBookCascade(String id)` 和 `deleteBooksCascade(Set<String> ids)`：

```dart
Future<void> _deleteBookCascadeUnchecked(String id) async {
  // 两层链先删 child-of-child
  await customStatement(
    'DELETE FROM annotations WHERE book_note_id IN '
    '(SELECT id FROM book_notes WHERE book_id = ?)', [id]);
  await customStatement('DELETE FROM book_notes WHERE book_id = ?', [id]);
  await customStatement(
    'DELETE FROM chat_messages WHERE session_id IN '
    '(SELECT id FROM chat_sessions WHERE book_id = ?)', [id]);
  await customStatement('DELETE FROM chat_sessions WHERE book_id = ?', [id]);
  // books 的直接子表
  await customStatement('DELETE FROM reading_progress_table WHERE book_id = ?', [id]);
  await customStatement('DELETE FROM book_typography_overrides WHERE book_id = ?', [id]);
  await customStatement('DELETE FROM ai_summaries WHERE book_id = ?', [id]);
  await customStatement('DELETE FROM bookmarks WHERE book_id = ?', [id]);
  await customStatement('DELETE FROM freeform_notes WHERE book_id = ?', [id]);
  // book_tags 有 CASCADE —— SQLite 自动处理
  // 最后删 books 行，必须用 drift DSL（不是 customStatement）才能触发
  // books 表 stream，让 Library 卡片 reactive 消失
  await (delete(books)..where((t) => t.id.equals(id))).go();
}
```

外层包 `transaction(() => ...)` 保证原子性。`deleteBooksCascade` 复用 `_deleteBookCascadeUnchecked` 在单个外层事务里循环。

**`app/lib/data/repositories/local_book_repository.dart`** — `delete()` 和 `deleteBooks()` 把 `_dao.deleteBook` / `_dao.deleteBooks` 换成 cascade 版本。sync recorder + remote deleter hook 顺序不变。

**`app/lib/features/library/pages/book_detail_page.dart`** — `_confirmDelete` 包 try/catch + SnackBar，未来任何删除失败用户能看到：

```dart
try {
  await ref.read(libraryControllerProvider.notifier).deleteBook(book.id);
  // ... navigate back ...
} catch (e, st) {
  debugPrint('[delete] failed to delete book ${book.id}: $e\n$st');
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('删除失败：$e')),
  );
}
```

### 文档

修两处文档谎言：
- `freeform_notes.dart`：原文档「FK `ON DELETE CASCADE`」改为「NO ACTION，由 BooksDao 显式 DELETE」。
- `bookmarks.dart`：原文档自相矛盾（同时声称 CASCADE 和 NO ACTION），统一为「NO ACTION，应用层删除」。

## 决策

### 为何不修 schema 加 CASCADE

正确做法是给 9 个表的 FK 加 `customConstraint('REFERENCES books(id) ON DELETE CASCADE')`（与 `book_tags` 一致）。但这需要 schema v14 → v15 迁移，SQLite 不支持 ALTER CONSTRAINT，得为每张表做 create-new-copy-drop-old-rename 四步舞。对一个 hotfix 来说风险与收益不匹配。

App-layer cascade 的代价：未来新增 books 子表时必须同步更新 `_deleteBookCascadeUnchecked`。已在代码注释里写明。schema 修整留作后续 v1.12+ 项。

### 为何最终 books DELETE 用 drift DSL

最初版本用 `customStatement('DELETE FROM books WHERE id = ?', [id])`，测试通过但 `watchAll emits on changes` 失败 —— drift 的 stream 监听机制只对 drift DSL 操作触发，raw SQL 不通知。Library 监听 books stream 来 reactive 更新卡片，必须用 DSL。子表用 raw SQL 是因为相关 UI 页（NotesPage / AiChatPage）都是 per-book，删书后用户不会停留在该书页面，stream staleness 无影响。

## 测试

新增 2 个回归测试（`app/test/data/repositories/local_book_repository_test.dart`）：

1. **`Regression 2026-07-13: delete cascades through all child tables`** — 插一本书 + 9 个子表各一行，调 `repo.delete`，验证书与所有子行都清空。
2. **`Regression 2026-07-13: deleteBooks batch cascades through child tables`** — 批量删除路径的等价测试。

完整回归：**1427 pass / 3 skip / 11 fail**（10 router/reader_page 老 baseline + 1 reader_flow_integration 10 分钟超时，均与本次改动无关，已 stash 验证）。

## 已知限制

- **数据库 schema 不变**：仍是 v14，9 个表的 FK 仍是 NO ACTION。本修复完全在应用层。
- **旧用户的孤儿行**：v1.11.1-alpha 及之前如果用户曾通过其它途径（如直接 SQL）删除过 books 行，子表里可能存在孤儿行。本修复不清理历史孤儿，仅保证未来删书正常。
- **UX 改进延后**：用户同时提的两个 UX 需求（大图模式右键 context menu、书架顶部批量处理菜单）不在本 hotfix 范围，留作 v1.12+ 迭代。

## 升级指引

直接覆盖安装即可。schema 无变更，无需迁移。打开 v1.11.2-alpha 后，之前删不掉的书现在可以从详情页红色 FAB 删除（弹确认框 → 点确认 → 真删）。
