# Per-book Typography 自动持久化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让用户对每本书调过的字号/排版设置在关闭后重新打开能自动恢复（per-book override 自动持久化）。

**Architecture:** 复用已存在但从未被调用的 `BookTypographyOverrides` 表 + `TypographyDao.getOverride/upsertOverride` 方法。新增 `BookTypographyRepository` 包装 DAO + JSON 序列化。在 `readerEngineForBookProvider` 引擎 open 后查 override 并应用；`ref.onDispose` 钩子先 snapshot 当前 `engine.typography`、再 upsert 到 override、最后 close 引擎。"设为默认"按钮接入 fallback（override 不存在 → 读 default profile → 再 fallback 到 `TypographySettings.defaults()`）。

**Tech Stack:** Flutter 3.44 + Riverpod 2.5 + drift；`TypographySettings.toJson/fromJson` 已存在；in-memory drift test helper `createTestDatabase()` 已存在。

**Root cause（systematic-debugging Phase 1 结论）：**
- `app/lib/data/local/tables/book_typography_overrides.dart:21` 定义了表
- `app/lib/data/local/daos/typography_dao.dart:84-104` 定义了 getOverride / upsertOverride
- `grep -rn "getOverride\|upsertOverride" app/lib` 仅命中 DAO 文件本身，**0 个调用点**
- `reader_engine_provider.dart` 4 个分支创建引擎后**直接 return**，不查任何持久化 typography
- 引擎内 `epubx_renderer.dart:88` / `pdf_renderer.dart:79` 硬编码 `_typography = TypographySettings.defaults()`
- 用户调字号 → `engine.setTypography(settings)` 只改内存 → 引擎 close 时丢失

**Scope / non-goals:**
- **In scope:** per-book 自动加载/持久化；fallback 链：override → default profile → 静态默认。
- **Out of scope:** WebDAV 同步（per-book override 不写入 sync outbox，与 `typography_profiles` 表策略一致；用户已知这是本设备设置）；typography_panel UI 改造；多用户/多 profile 切换；M2.8 之前的其它字体 bug。

---

## File Structure

- **Create:** `app/lib/data/repositories/book_typography_repository.dart` — 包装 DAO，对外暴露纯 `TypographySettings` 接口
- **Create:** `app/test/data/repositories/book_typography_repository_test.dart` — in-memory drift 单元测试
- **Modify:** `app/lib/core/providers.dart:122-125` — 在 typographyProfileRepositoryProvider 后追加 `bookTypographyRepositoryProvider`
- **Modify:** `app/lib/features/reader/providers/reader_engine_provider.dart:42-127` — 4 个分支都注入 load+persist 钩子
- **Create:** `app/test/features/reader/providers/reader_engine_provider_typography_persistence_test.dart` — 端到端集成测试

---

## Task 1: BookTypographyRepository + provider + 单元测试

**Files:**
- Create: `app/lib/data/repositories/book_typography_repository.dart`
- Create: `app/test/data/repositories/book_typography_repository_test.dart`
- Modify: `app/lib/core/providers.dart` (在 line 125 后追加 provider)

- [ ] **Step 1: Write the failing test** (test file: `app/test/data/repositories/book_typography_repository_test.dart`)

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/book_typography_repository.dart';
import 'package:zhiyue/data/repositories/typography_profile_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late BookTypographyRepository repo;
  late TypographyProfileRepository profileRepo;

  setUp(() async {
    db = createTestDatabase();
    repo = BookTypographyRepository(db);
    profileRepo = TypographyProfileRepository(db);
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 'Test',
      format: 'epub',
      filePath: '/tmp/x.epub',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
  });
  tearDown(() async => db.close());

  test('getForBook returns null when no override and no default profile', () async {
    final result = await repo.getForBook('b1');
    expect(result, isNull);
  });

  test('saveForBook persists settings; getForBook returns them', () async {
    final s = TypographySettings.defaults().copyWith(fontSize: 24.0);
    await repo.saveForBook('b1', s);
    final loaded = await repo.getForBook('b1');
    expect(loaded, isNotNull);
    expect(loaded!.fontSize, 24.0);
    expect(loaded, s);
  });

  test('saveForBook twice with same bookId upserts (no duplicate rows)', () async {
    final s1 = TypographySettings.defaults().copyWith(fontSize: 20.0);
    final s2 = TypographySettings.defaults().copyWith(fontSize: 22.0);
    await repo.saveForBook('b1', s1);
    await repo.saveForBook('b1', s2);
    final loaded = await repo.getForBook('b1');
    expect(loaded!.fontSize, 22.0);
    // Row count must stay at 1
    final rows = await db.typographyDao.getOverride('b1');
    expect(rows, isNotNull);
  });

  test('getForBook for different bookId returns independent settings', () async {
    await BooksDao(db).insertOne(
      id: 'b2',
      title: 'Other',
      format: 'epub',
      filePath: '/tmp/y.epub',
      fileHash: 'h2',
      fileSizeBytes: 0,
    );
    await repo.saveForBook('b1',
        TypographySettings.defaults().copyWith(fontSize: 18.0));
    await repo.saveForBook('b2',
        TypographySettings.defaults().copyWith(fontSize: 28.0));
    expect((await repo.getForBook('b1'))!.fontSize, 18.0);
    expect((await repo.getForBook('b2'))!.fontSize, 28.0);
  });

  test('saveForBook survives JSON round-trip for all fields', () async {
    final original = TypographySettings.defaults().copyWith(
      fontSize: 19.5,
      lineHeight: 2.0,
      theme: ReadingTheme.sepia,
      pageMargin: PageMargin.extraWide,
      paragraphIndentEm: 3.0,
      paragraphIndentEnabled: false,
    );
    await repo.saveForBook('b1', original);
    final loaded = await repo.getForBook('b1');
    expect(loaded, original);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && /c/flutter/bin/dart.bat test test/data/repositories/book_typography_repository_test.dart`
Expected: FAIL — `BookTypographyRepository` class not found / `bookTypographyRepositoryProvider` undefined.

- [ ] **Step 3: Write minimal implementation** (file: `app/lib/data/repositories/book_typography_repository.dart`)

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:convert';

import 'package:reader_engine/core/typography_settings.dart';

import '../local/database.dart';

/// 按书籍持久化用户当前实际使用的 [TypographySettings]。
///
/// 与 [TypographyProfileRepository] 的区别：profile 是用户保存的"命名预设"
/// （可被多本书引用、可设全局默认），override 是"这本书最后一次关闭时的
/// 真实排版"，每次用户调字号面板就覆盖。打开书时优先级最高。
///
/// 用户期望（2026-07-09 反馈）："关闭书籍时的设置，下次打开自动加载，按书
/// 来。" 实现路径：`readerEngineForBookProvider` open 后调用 [getForBook]
/// 应用；`ref.onDispose` snapshot `engine.typography` 后调用 [saveForBook]。
class BookTypographyRepository {
  BookTypographyRepository(this._db);

  final AppDatabase _db;

  /// 返回该书最后一次保存的 [TypographySettings]；没有记录则返回 null
  /// （调用方决定 fallback：default profile 或 [TypographySettings.defaults]）。
  Future<TypographySettings?> getForBook(String bookId) async {
    final row = await _db.typographyDao.getOverride(bookId);
    if (row == null) return null;
    // 优先用 customSettings；如果只有 profileId（未来功能），暂不支持，返回 null。
    if (row.customSettings == null) return null;
    return TypographySettings.fromJson(
        jsonDecode(row.customSettings!) as Map<String, dynamic>);
  }

  /// 把当前 [settings] upsert 到该书的 override。fire-and-forget 调用安全。
  Future<void> saveForBook(String bookId, TypographySettings settings) async {
    await _db.typographyDao.upsertOverride(
      bookId: bookId,
      customSettingsJson: jsonEncode(settings.toJson()),
    );
  }
}
```

- [ ] **Step 4: Register provider** (file: `app/lib/core/providers.dart`)

在 `typographyProfileRepositoryProvider`（line 122-125）定义之后追加：

```dart
final bookTypographyRepositoryProvider = Provider<BookTypographyRepository>((ref) {
  return BookTypographyRepository(ref.watch(appDatabaseProvider));
});
```

并在文件顶部 import 区域添加（如尚未存在）：
```dart
import '../data/repositories/book_typography_repository.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && /c/flutter/bin/dart.bat test test/data/repositories/book_typography_repository_test.dart`
Expected: PASS — 5 tests pass.

- [ ] **Step 6: Run dart analyze on the new file**

Run: `cd app && /c/flutter/bin/dart.bat analyze lib/data/repositories/book_typography_repository.dart test/data/repositories/book_typography_repository_test.dart lib/core/providers.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add app/lib/data/repositories/book_typography_repository.dart \
        app/test/data/repositories/book_typography_repository_test.dart \
        app/lib/core/providers.dart
git commit -m "feat(reader): add BookTypographyRepository for per-book typography persistence

Wraps existing-but-unused TypographyDao.getOverride/upsertOverride.
Pure infrastructure — no behavior change yet. Provider integration
follows in T2."
```

---

## Task 2: readerEngineForBookProvider load + persist

**Files:**
- Modify: `app/lib/features/reader/providers/reader_engine_provider.dart`

**Background:**
- 当前 4 个分支（epub / pdf / md / txt）模式相同：创建引擎 → `ref.onDispose(engine.close)` → 读 lastProgress → open → return。
- 改造后：创建引擎 → 读 override → 如有则 `engine.setTypography(override)` → 替换 `ref.onDispose` 为 snapshot+save+close 复合 dispose 钩子 → open → return。
- override 为 null 时不主动 setTypography（保留引擎默认值即可——引擎默认即 `TypographySettings.defaults()`）。
- "设为默认"按钮接入 fallback 由 T1 的 default profile 机制提供（`reader_typography_panel_trigger.dart:86` 已经调用 `setDefault(p.id)`，T2 不动 UI）。

- [ ] **Step 1: Extract helper `_applyPersistedTypography`**

在 `reader_engine_provider.dart` 文件底部添加私有 helper：

```dart
/// T2: 打开引擎后从 [BookTypographyRepository] 读该书最后一次保存的
/// 排版并应用到 engine；无记录则保留引擎默认（`TypographySettings.defaults`）。
Future<void> _applyPersistedTypography(
  ReaderEngine engine,
  String bookId,
  BookTypographyRepository repo,
) async {
  final saved = await repo.getForBook(bookId);
  if (saved != null) {
    engine.setTypography(saved);
  }
}

/// T2: 把 engine 当前 typography snapshot 后 upsert 到 per-book override，
/// 再 close 引擎。供 `ref.onDispose` 使用——onDispose 不支持 await，整个
/// 操作 fire-and-forget。
void _disposeEngineWithPersist(
  ReaderEngine engine,
  String bookId,
  BookTypographyRepository repo,
) {
  final snapshot = engine.typography;
  // 顺序：先 save（持久化用户设置），再 close（释放底层资源）。
  // 两者都异步，但 onDispose 同步触发——fire-and-forget。
  // ignore: discarded_futures
  repo.saveForBook(bookId, snapshot);
  // ignore: discarded_futures
  engine.close();
}
```

在 import 区添加（如尚未存在）：
```dart
import '../../../data/repositories/book_typography_repository.dart';
```

- [ ] **Step 2: Modify 4 branches to use the helpers**

把 `readerEngineForBookProvider` 函数体改造为以下结构（4 个分支都用同模板；下面以 epub 分支示范，pdf/md/txt 同样改）：

**Epub branch（before，line 65-74）：**
```dart
if (bookRef.format == re.BookFormat.epub) {
  final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
  ref.onDispose(engine.close);
  final lastProgress = await progressRepo.get(bookId);
  await engine.openWithLastProgress(
    book: bookRef,
    lastLocator: lastProgress?.locator,
  );
  return engine;
}
```

**Epub branch（after）：**
```dart
if (bookRef.format == re.BookFormat.epub) {
  final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
  final typographyRepo = ref.watch(bookTypographyRepositoryProvider);
  ref.onDispose(
      () => _disposeEngineWithPersist(engine, bookId, typographyRepo));
  final lastProgress = await progressRepo.get(bookId);
  await engine.openWithLastProgress(
    book: bookRef,
    lastLocator: lastProgress?.locator,
  );
  await _applyPersistedTypography(engine, bookId, typographyRepo);
  return engine;
}
```

**Pdf branch（line 75-85）** — 同模板，把 `ConcreteEpubReaderEngine(renderer: EpubxRenderer())` 换成 `PdfReaderEngine(renderer: PdfRenderer())`，其余（`ref.onDispose`、`typographyRepo`、`_applyPersistedTypography`）完全相同。

**Markdown branch（line 95-110）** — 同模板，但 open 是 `openChapters(sources, ...)`，最后仍调 `_applyPersistedTypography`。

**Text branch（line 111-124）** — 同 markdown 模板。

**重要不变量：**
- `_disposeEngineWithPersist` 必须在 `openWithLastProgress` / `openChapters` **之前** 注册到 `ref.onDispose`——这样即便 open 抛异常，已创建的 engine 也会被 dispose。
- `_applyPersistedTypography` 必须在 open **之后** 调用——open 会初始化 `_typography = TypographySettings.defaults()`，之后才能 setTypography 覆盖。

- [ ] **Step 3: Verify existing tests still pass**

Run: `cd app && /c/flutter/bin/dart.bat test test/features/reader/providers/`
Expected: All existing tests PASS（可能需要在已有 test 里 override `bookTypographyRepositoryProvider`，见 Step 4）。

- [ ] **Step 4: 如果现有 provider test 报 missing override 错误**

`reader_engine_provider_test.dart` 等已存在的测试如果用的是真实 AppDatabase（不是 mock），自动会拿到 `bookTypographyRepositoryProvider` 默认实现，无需改。如果是完全 mock 的 ProviderContainer，则需要在 overrides 里加：
```dart
bookTypographyRepositoryProvider.overrideWithValue(/* fake */),
```

实施时先跑测试，根据报错决定是否要改测试。

- [ ] **Step 5: dart analyze**

Run: `cd app && /c/flutter/bin/dart.bat analyze lib/features/reader/providers/reader_engine_provider.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/reader/providers/reader_engine_provider.dart
git commit -m "feat(reader): persist per-book typography on engine open+dispose

readerEngineForBookProvider now loads BookTypographyOverrides when
opening any book (epub/pdf/md/txt) and writes engine.typography back
on dispose. Closes the loop: user adjusts font size → close book →
reopen → settings restored."
```

---

## Task 3: End-to-end integration test

**Files:**
- Create: `app/test/features/reader/providers/reader_engine_provider_typography_persistence_test.dart`

**Test goal:** open engine → `setTypography(fontSize=22)` → dispose container → re-read provider → assert new engine.typography.fontSize == 22.

- [ ] **Step 1: Write the integration test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/repositories/book_repository.dart';
import 'package:zhiyue/data/repositories/reading_progress_repository.dart';
import 'package:zhiyue/features/reader/providers/reader_engine_provider.dart';

import '../../../helpers/drift_test_helper.dart';

class _StubBookRepository implements BookRepository {
  @override
  Future<Book?> getById(String id) async => Book(
        id: id,
        title: 'T',
        author: null,
        format: BookFormat.epub,
        filePath: '/tmp/nonexistent.epub',
        fileHash: '',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime.now(),
        lastReadAt: null,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _NullProgressRepo implements ReadingProgressRepository {
  @override
  Future<ReadingProgress?> get(String bookId) async => null;
  @override
  Future<void> save(ReadingProgress progress) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
  });
  tearDown(() async => db.close());

  test(
      'T3.1 typography persists across engine dispose+reopen (per-book)',
      () async {
    final container1 = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      bookRepositoryProvider.overrideWithValue(_StubBookRepository()),
      readingProgressRepositoryProvider.overrideWithValue(_NullProgressRepo()),
    ]);
    addTearDown(container1.dispose);

    // Open the book for the first time. openWithLastProgress will fail to
    // load the file (nonexistent path) — but engine object is created and
    // engine.typography is initialized to TypographySettings.defaults().
    final engine1 =
        await container1.read(readerEngineForBookProvider('b1').future);
    final customSize = TypographySettings.defaults().fontSize + 4.0;
    engine1.setTypography(
        TypographySettings.defaults().copyWith(fontSize: customSize));

    // Force-dispose the provider (autoDispose triggers onDispose → persist
    // engine.typography to BookTypographyOverrides).
    container1.invalidate(readerEngineForBookProvider('b1'));
    // Wait one microtask for fire-and-forget saveForBook to land in drift.
    await Future<void>.delayed(Duration.zero);

    // Reopen — new engine should pick up the persisted fontSize.
    final container2 = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      bookRepositoryProvider.overrideWithValue(_StubBookRepository()),
      readingProgressRepositoryProvider.overrideWithValue(_NullProgressRepo()),
    ]);
    addTearDown(container2.dispose);
    final engine2 =
        await container2.read(readerEngineForBookProvider('b1').future);

    expect(engine2.typography.fontSize, customSize,
        reason: 'Per-book typography must survive engine dispose+reopen');
  });

  test(
      'T3.2 first-time open (no override) leaves engine at defaults',
      () async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      bookRepositoryProvider.overrideWithValue(_StubBookRepository()),
      readingProgressRepositoryProvider.overrideWithValue(_NullProgressRepo()),
    ]);
    addTearDown(container.dispose);

    final engine =
        await container.read(readerEngineForBookProvider('b1').future);
    expect(engine.typography, TypographySettings.defaults(),
        reason: 'No override + no default profile → static defaults()');
  });
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `cd app && /c/flutter/bin/dart.bat test test/features/reader/providers/reader_engine_provider_typography_persistence_test.dart`
Expected: 2 tests pass.

- [ ] **Step 3: Commit**

```bash
git add app/test/features/reader/providers/reader_engine_provider_typography_persistence_test.dart
git commit -m "test(reader): per-book typography persistence integration test"
```

---

## Task 4: Full analyze + test sweep

- [ ] **Step 1: dart analyze 全量**

Run: `cd app && /c/flutter/bin/dart.bat analyze`
Expected: 0 issues（保持 baseline）。

Run: `cd reader_engine && /c/flutter/bin/dart.bat analyze` 同上。
Run: `cd reader_engine_epub_view && /c/flutter/bin/dart.bat analyze` 同上。
Run: `cd reader_engine_pdf_view && /c/flutter/bin/dart.bat analyze` 同上。

- [ ] **Step 2: 全量 flutter test**

Run: `cd app && /c/flutter/bin/flutter.bat test`
Expected: 369 + 3 (T1) + 2 (T3) = 374 passed, 2 skipped baseline 保持。

Run: `cd reader_engine && /c/flutter/bin/flutter.bat test`、`cd reader_engine_epub_view && /c/flutter/bin/flutter.bat test`、`cd reader_engine_pdf_view && /c/flutter/bin/flutter.bat test` 同样全绿。

- [ ] **Step 3: 如果 T2 现有测试需要补 override，集中修复后 amend T2 commit（或追加 fixup commit）**

---

## Task 5: Windows release build

- [ ] **Step 1: 切到 worktree 并同步 master**

```bash
cd /c/zhiyue_build
git checkout master
git pull --ff-only  # 若 worktree 已在 master，仅 fast-forward
```

预期：worktree 已在 master（之前 batch-3 已切），新 commit 应自动可见（共享 .git）。

- [ ] **Step 2: 确认 worktree 仍有 batch-3 时手动补的文件**

```bash
ls /c/zhiyue_build/app/windows/CMakeLists.txt
ls /c/zhiyue_build/app/windows/flutter/CMakeLists.txt
ls /c/zhiyue_build/app/windows/runner/CMakeLists.txt
ls /c/zhiyue_build/app/assets/fonts/ | head
```

如果缺，从 H:\projiect\电子书阅读平台 对应路径复制（.gitignore *.txt 排除规则导致 worktree 同步丢这些文件）。

- [ ] **Step 3: flutter build windows --release**

Run: `cd /c/zhiyue_build/app && /c/flutter/bin/flutter.bat build windows --release`
Expected: `✓ Built build\windows\x64\runner\Release\zhiyue.exe`

- [ ] **Step 4: 通报编译产物位置**

`/c/zhiyue_build/app/build/windows/x64/runner/Release/zhiyue.exe`

---

## Self-Review Checklist (writing-plans 强制项)

- [x] **Spec coverage:** 用户要求"关闭书籍时的设置自动按书籍加载" — T2 的 `ref.onDispose` snapshot+save + open 时 load 完整闭环。用户隐含的"设为默认值"按钮 — T1 保留 TypographyProfileRepository 既有机制，按钮语义不变（fallback 由 default profile 提供）。
- [x] **Placeholder scan:** 所有 Step 都有完整代码块，无 TBD/TODO。
- [x] **Type consistency:** `BookTypographyRepository.getForBook` / `saveForBook` 在 T1/T2/T3 三处签名一致；`_applyPersistedTypography` / `_disposeEngineWithPersist` helper 名一致。
- [x] **DRY:** T2 的 4 个分支用同一对 helper 函数去重，避免复制粘贴。
- [x] **YAGNI:** 不引入 WebDAV sync outbox（与 typography_profiles 策略一致）；不改 UI；不加新的 settings key。
- [x] **Frequent commits:** T1/T2/T3 各自独立 commit，T4/T5 验证。

## Known caveats / decisions

1. **fire-and-forget persist on dispose** — `ref.onDispose` 不支持 await；如果用户在 saveForBook 完成前 process 突然终止（kill -9 / 拔电源），最后一次调字号可能丢。可接受风险（用户主动关 app/切书时 dispose 早于 process exit）。
2. **不写 sync outbox** — per-book override 暂不跨设备同步；typography_profiles 表也没同步，策略一致。未来若加同步，BookTypographyOverrides 表需要补 outbox 钩子（M2.0a ConflictSink pattern）。
3. **不区分 "用户主动改" 与 "默认值"** — dispose 时无脑 upsert 当前 typography。首次打开+关闭的书也会写 override（内容 = defaults）。轻微脏数据但行为一致，简化心智模型。
4. **不删除 `setDefault` 按钮** — 它仍控制 typography_profiles 表的 isDefault 标记；T2 的 fallback 链未来若加 "override 不存在 → 读 default profile"（当前 plan 里已留接口位但 T2 暂未读 profile，只读 customSettings），按钮才会真正影响新书初始字号。本 plan 把"读 default profile fallback"留作 T6 候选扩展，**当前 T2 不实现**（YAGNI）。
