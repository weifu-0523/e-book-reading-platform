# v1.11.8-alpha

**发布日期**：2026-07-14
**类型**：hotfix（用户报告 bug）
**上一版本**：v1.11.7-alpha

## 摘要

修复用户报告的两个 bug：

1. **Bug 1：EPUB 目录跳转位置偏移**——《道德经》点击目录第 13 章实际
   滚到第八章。根因：scroll-mode `gotoLocator` 用 HTML 字节数当章节
   总长度，但 `charOffset` 是 plain-text 偏移——两个坐标系混用导致
   ratio 压缩 1.73×。
2. **Bug 2：同步规则不友好**——用户「加书签后 5 分钟内关机」会永远
   丢失同步窗口。三层修复：Layer A outbox 触发 3s debounce push +
   Layer B 关闭前 flush + Layer C 冷启动 pull。

**覆盖所有 9 种 record type**：annotation / bookNote / readingProgress /
book（书籍上架）/ bookmark / freeformNote（笔记）/ chatSession +
chatMessage（AI 对话）/ bookTag——Layer A/B/C 全部 type-agnostic。

测试数：**1504 pass + 14 skip + 1 pre-existing flake**（reader_flow
integration test 10 分钟 timeout，与本版本无关，b831eca 之前也失败）。

---

## Bug 1：EPUB 目录跳转位置偏移

### 用户报告

> 部分电子书调整修复有问题，点击目录跳转的位置不对。比如道德经这本书，
> 目录 13 章，跳转到正文第八章。

### 根因

`epubx_renderer.dart` 的 scroll-mode `_emitCurrentLocation` 和
`gotoLocator` 用 `html.length`（HTML 字节数）作为章节总长度：

```dart
// 旧代码（错）：
final ratio = charOffset / html.length;
```

但 `charOffset` 来自 `PlainTextUtils.anchorToPlainOffset`，是
**plain-text 字符偏移**（剥掉所有 HTML 标签后的字符数）。两个坐标系
混用导致 ratio 被压缩。

`道德经` 这本书：
- HTML 长度：105568 字节
- plain 长度：60986 字符
- 压缩比：1.73×

`第十三章` 的 plain offset 是 18381，正确 ratio = 18381/60986 ≈ 30.1%。
但旧代码算 18381/105568 ≈ 17.4%，对应 scroll position 10619，落在
「第八章」（10393-12650）的区间内 → 用户看到跳到第八章。

### 修复

新增 `_plainTextLengthForChapter(index)` 方法，用
`PlainTextUtils.htmlToPlainWithOffsets` 缓存每章 plain 长度。
`gotoLocator` 和 `_emitCurrentLocation` 都用它替代 `html.length`。

```dart
// 新代码（对）：
final totalChars = _plainTextLengthForChapter(decoded.chapterIndex);
final ratio = charOffset / totalChars;
```

结果：`第十三章` 偏移 18381 / plain 总长 60986 ≈ 30.1%，正确滚到
第十三章区间。

### 测试

3 个新测试（`reader_engine_epub_view/test/epubx_renderer_anchor_toc_test.dart`）：

1. **plain text length helper returns plain length, not HTML length**
   ——验证 `_plainTextLengthForChapter` 返回 3 不是 45（HTML 长度）。
2. **scroll-mode ratio for anchor at offset 2 (out of 3) lands near 67%**
   ——验证 ratio = 2/3 ≈ 67%，不是 2/45 ≈ 4.4%。
3. **plain text length cache cleared alongside plain text cache**——验证
   `_plainTextLengthCache.clear()` 与 4 处 `_plainTextCache.clear()`
   同步调用。

---

## Bug 2：同步规则三层完善

### 用户报告

> 同步的规则需要思考来进行修改，目前是程序运行过程中每五分钟同步，
> 但如果用户有操作，然后关闭了应用同步就没有执行，比如用户书看累了，
> 添加了书签然后关闭应用去休息了，但回到电脑前打开应用就没有同步到
> 需要的书签。

### 设计

用户在 AskUserQuestion 选择「**三层全做（推荐）**」。

| Layer | 触发时机 | 行为 | 覆盖场景 |
|---|---|---|---|
| A | 任何 outbox 写 | 3s debounce 后 push | 用户加书签 / 笔记 / 高亮 / 导书 / AI 对话后短时间内的写操作 |
| B | 桌面关闭窗口 | flushForExit await ≤3s | 用户加书签 → 关机休息（用户原 bug 例子） |
| C | app 冷启动 | scheduler.resume() | 用户在手机加了书签，打开桌面立即看到 |

### Layer A：outbox 触发 3s debounce push

`SyncOutboxDao.watchPending()` 用 drift `.watch()` 监听表变更。
`SyncController._initOutboxWatch()` 订阅，每次非空 snapshot 启
`Timer` 3 秒后调 `_backgroundTick`。

```dart
void _initOutboxWatch() {
  _outboxWatchSub = database.syncOutboxDao.watchPending().listen((pending) {
    if (pending.isEmpty) return;  // markPushedMany 后的空 snapshot 不触发
    _pushDebounce?.cancel();
    _pushDebounce = Timer(_pushDebounceWindow, _backgroundTick);
  });
}
```

rapid writes（多选高亮 / 批量笔记编辑 / AI 流式消息批量记录）合并为
一次同步。

### Layer B：关闭前 best-effort flush

新增 public method `flushForExit(timeout: 3s)`：

```dart
Future<void> flushForExit({Duration timeout = const Duration(seconds: 3)}) async {
  final inFlight = _lastSyncFuture;
  if (inFlight != null) {
    // case 1: sync already running — await it
    await inFlight.timeout(timeout);
    return;
  }
  final pending = await database.syncOutboxDao.getPending();
  if (pending.isEmpty) return;  // case 3: no work
  // case 2: kick a fresh sync
  await syncNow().timeout(timeout);
}
```

`_WindowCloseHandler.onWindowClose` 在 `exit(0)` 前调它。Handler
构造挪进 `runZonedGuarded` 内（要访问 ProviderContainer）。

**Honors memory rule "no dispose-time fire-and-forget"** — 显式
`await` 后 exit 是允许的，rule 只禁 unsaved futures on isolated exit。

### Layer C：冷启动即时同步

Production constructor 的 `_initInterval()` 末尾加：

```dart
await _scheduler.resume();  // immediate tick + restart periodic timer
```

开 app 立即 pull 跨设备变更（手机加的书签打开桌面就看到）。
`forTesting` constructor 不调 `_initInterval`，保护现有 call-count
断言。

### Reentry 设计（非显然）

原 `syncNow` 用 `bool _isSyncing` 短路——第二个并发 caller 立即返回
不 await 第一个。这是 P0-3 regression test 的契约：

```dart
final first = controller.syncNow();  // starts, blocks in gated.sync()
await controller.syncNow();  // must short-circuit, NOT await first
expect(gated.calls, 1);  // only one engine.sync() called
```

如果改用 in-flight Future 替换 `_isSyncing`，第二个 caller 会 await
第一个 → block forever（gated never completes）→ test timeout。

**Resolution**：保留 `_isSyncing` bool 短路 + 新增独立 `_lastSyncFuture`
字段供 Layer B 的 `flushForExit` await。两字段两职责。代码注释明确
记录这个 split 的理由，防未来重构混淆。

### 覆盖所有 9 种 record type

用户反馈 2026-07-14：

> 不当当是书签同步问题，书籍上架，AI对话记录，笔记。都需要根据用户
> 可能都操作习惯进行优化。

Layer A 监听 `watchPending()` 不区分 recordType，所以以下所有写操作
都走同一条 3s debounce → push 路径，Layer B/C 同样不区分：

| recordType | 含义 | 用户场景 |
|---|---|---|
| `annotation` | 高亮 / 章节笔记 annotation | 阅读时选中文字 → 选颜色 |
| `bookNote` | 章节学习回顾 | AI 用本章正文 + 高亮生成总结 |
| `readingProgress` | 阅读进度 | 翻页自动记录 |
| **`book`** | **书籍上架** | library 导入 epub/pdf（含 binary 上传） |
| **`bookmark`** | **书签** | reader 顶栏 bookmark icon |
| **`freeformNote`** | **自由笔记** | library drawer / NotesPage FAB |
| **`chatSession`** | **AI 对话会话** | AI 抽屉 `/new` 新建会话 |
| **`chatMessage`** | **AI 对话消息** | 流式 SSE 完成后批量记录 |
| `bookTag` | 书籍标签 add/remove | library 长书标签编辑 |

书籍上架的 binary 文件上传在 `WebDavSyncEngine.sync()` 内通过
`bookFileSync.uploadPendingFiles()` 自动覆盖——Layer A 触发的 sync
会一并把新书的 binary 推到 WebDAV。

测试 `type-agnostic: book / chatMessage / freeformNote all trigger
push` 明确验证三种用户最关心的类型都触发 Layer A，guard 未来重构
不破坏 type-agnostic 不变量。

### 测试

12 个新测试，全部通过：

- **Layer A (3)**：outbox 写触发 / rapid 写合并 / type-agnostic（book +
  chatMessage + freeformNote 三种类型）
- **Layer B (3)**：空 outbox 快速返回 / pending 触发 sync / await
  in-flight sync
- **Layer C (1)**：coldStartSync 触发一次 scheduler tick
- **DAO (3)**：watchPending initial empty / new row emit / markPushed
  shrinking emit
- **Bug 1 (3)**：见上

---

## 变更文件

| 文件 | 变更 |
|---|---|
| `reader_engine_epub_view/lib/epubx_renderer.dart` | +`_plainTextLengthCache` +`_plainTextLengthForChapter(index)` +debug helpers；4 处 `_plainTextCache.clear()` 旁同步加 `_plainTextLengthCache.clear()` |
| `app/lib/data/local/daos/sync_outbox_dao.dart` | +`watchPending()` stream（drift select.watch） |
| `app/lib/features/sync/providers/sync_controller.dart` | +Layer A/B/C 实现 +dual-field reentry（`_isSyncing` + `_lastSyncFuture`），+78 行 |
| `app/lib/main.dart` | `_WindowCloseHandler` 构造挪入 zone + 接收 container；onWindowClose await flushForExit |
| `reader_engine_epub_view/test/epubx_renderer_anchor_toc_test.dart` | +3 测试 |
| `app/test/data/local/daos/sync_outbox_dao_test.dart` | +3 测试 |
| `app/test/features/sync/providers/sync_controller_test.dart` | +12 测试 |

5 个 commit：`5f6ef1f`（Bug 1）→ `2bd7f07`（DAO watchPending）→
`38bc147`（SyncController Layer A/B/C）→ `6d8055f`（main.dart wiring）→
`e885054`（type-agnostic test）。

---

## 已知限制

1. **Layer B 仅桌面**（window_manager）。移动端走 `AppLifecycleState`
   （SyncController 已观察），但 `paused` 时只 pause scheduler 不主动
   flush——移动进程被 OS 随时 kill，flush 不可靠，依赖 Layer A 的 3s
   debounce 把绝大多数写操作及时送出。Mobile flush 留 follow-up。
2. **Layer C cold-start 同步**在没网 / 没凭据时 `_syncNowInner` 短路，
   不影响启动。
3. **flushForExit 3s timeout**：网络极慢时可能超时，但本地 DB +
   outbox 已落盘（drift WAL），下次打开本机 Layer A 立即重试。
4. **reader_flow_integration_test** 10 分钟 timeout（pre-existing flake，
   b831eca 之前也失败，与本版本无关）。

---

## 验证

### 单元/集成测试

```
$ flutter test test/features/sync/ test/data/local/daos/sync_outbox_dao_test.dart \
              test/services/sync/
210 sync-related tests pass.
```

```
$ flutter test test/features/sync/providers/sync_controller_test.dart
12/12 pass (5 existing + 7 new for v1.11.8-alpha).
```

### 手工验证（建议用户在 desktop + mobile 双端跑）

1. **Layer A**：在 desktop 加一个书签 → 3s 内观察 SyncButton 转动 →
   在 mobile 端打开 reader 看到该书签。
2. **Layer B**：在 desktop 加一个书签 → 立刻关闭窗口（不等 3s）→
   在 mobile 端打开看到该书签。
3. **Layer C**：在 mobile 加一个高亮 → 关闭 mobile app → 在 desktop
   （已开着）打开同书 → 由于 desktop 还没 cold-start，可以重启 desktop
   app → 立即看到该高亮。
4. **Type-agnostic**：导入新书 / 发 AI 消息 / 写笔记后关 desktop →
   在 mobile 端打开看到对应内容。
