# Typography Persistence Survives exit(0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per-book typography settings persist when user closes the app via the window X button, which triggers `exit(0)` in `main.dart:148` and currently truncates the fire-and-forget `saveForBook` Future in `reader_engine_provider.dart:165`.

**Architecture:** Replace dispose-time fire-and-forget save with a stream-subscription + debounce-500ms immediate save, mirroring the existing `ProgressPersister` pattern (`app/lib/features/reader/services/progress_persister.dart`). The new `TypographyPersister` subscribes to `engine.state$` (which `epubx_renderer.dart:958` proves emits on every `setTypography` call), extracts `engine.typography` from the getter, distinct-compares against the last persisted value, and writes to `BookTypographyRepository` immediately. The `ref.onDispose` hook in `readerEngineForBookProvider` is stripped down to just `engine.close()` — no more fire-and-forget save.

**Tech Stack:** Dart 3.12, Riverpod 2.5 (autoDispose family + ref.onDispose), drift (existing `BookTypographyRepository`), dart:async (`StreamSubscription`, `Timer`).

---

### File Structure

- **Create** `app/lib/features/reader/services/typography_persister.dart` — `TypographyPersister` class, mirrors `ProgressPersister` shape.
- **Create** `app/test/features/reader/services/typography_persister_test.dart` — unit tests for debounce, distinct, dispose, silent-failure.
- **Modify** `app/lib/features/reader/pages/reader_page.dart` — add `_typographyPersister` field, `_ensureTypographyPersister(engine)`, dispose hook.
- **Modify** `app/lib/features/reader/providers/reader_engine_provider.dart` — delete `_disposeEngineWithPersist` helper, replace 4 `ref.onDispose(...)` calls with `ref.onDispose(engine.close)`, keep `_applyPersistedTypography` (load path unchanged).

---

### Task 1: TypographyPersister class + unit tests

**Files:**
- Create: `app/lib/features/reader/services/typography_persister.dart`
- Test: `app/test/features/reader/services/typography_persister_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `app/test/features/reader/services/typography_persister_test.dart` with this full content:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:zhiyue/data/repositories/book_typography_repository.dart';

import 'package:zhiyue/features/reader/services/typography_persister.dart';

/// In-memory fake repository. Records every saveForBook call.
class _RecordingRepo implements BookTypographyRepository {
  final List<({String bookId, TypographySettings settings})> saves = [];

  @override
  Future<TypographySettings?> getForBook(String bookId) async => null;

  @override
  Future<void> saveForBook(String bookId, TypographySettings settings) async {
    saves.add((bookId: bookId, settings: settings));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  group('TypographyPersister', () {
    test('T1.1 debounces rapid changes — only last value persisted',
        () async {
      final repo = _RecordingRepo();
      final controller = StreamController<ReaderEngineState>();
      final persister = TypographyPersister(
        bookId: 'b1',
        repository: repo,
        stateSource: controller.stream,
        typographyGetter: () => TypographySettings.defaults(),
        debounceMs: 50,
      )..start();

      // Emit 3 state changes in rapid succession (within debounce window).
      controller.add(const ReaderEngineReady());
      controller.add(const ReaderEngineReady());
      controller.add(const ReaderEngineReady());

      // Wait beyond debounce window.
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(repo.saves, hasLength(1));
      expect(repo.saves.first.bookId, 'b1');
      expect(repo.saves.first.settings, TypographySettings.defaults());

      persister.dispose();
      await controller.close();
    });

    test('T1.2 distinct — same typography skipped, no save', () async {
      final repo = _RecordingRepo();
      final controller = StreamController<ReaderEngineState>();
      final settings = TypographySettings.defaults();
      final persister = TypographyPersister(
        bookId: 'b1',
        repository: repo,
        stateSource: controller.stream,
        typographyGetter: () => settings,
        debounceMs: 50,
      )..start();

      // First emit → save.
      controller.add(const ReaderEngineReady());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.saves, hasLength(1));

      // Second emit with same typography value → no save.
      controller.add(const ReaderEngineReady());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.saves, hasLength(1));

      persister.dispose();
      await controller.close();
    });

    test('T1.3 changing typography value triggers save', () async {
      final repo = _RecordingRepo();
      final controller = StreamController<ReaderEngineState>();
      var current = TypographySettings.defaults();
      final persister = TypographyPersister(
        bookId: 'b1',
        repository: repo,
        stateSource: controller.stream,
        typographyGetter: () => current,
        debounceMs: 50,
      )..start();

      // First emit → save defaults.
      controller.add(const ReaderEngineReady());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.saves, hasLength(1));
      expect(repo.saves.first.settings.fontSize, 18.0);

      // Change typography and emit again.
      current = current.copyWith(fontSize: 24.0);
      controller.add(const ReaderEngineReady());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.saves, hasLength(2));
      expect(repo.saves.last.settings.fontSize, 24.0);

      persister.dispose();
      await controller.close();
    });

    test('T1.4 dispose cancels pending debounce — no save after dispose',
        () async {
      final repo = _RecordingRepo();
      final controller = StreamController<ReaderEngineState>();
      final persister = TypographyPersister(
        bookId: 'b1',
        repository: repo,
        stateSource: controller.stream,
        typographyGetter: () => TypographySettings.defaults(),
        debounceMs: 50,
      )..start();

      // Emit then immediately dispose (before debounce window elapses).
      controller.add(const ReaderEngineReady());
      persister.dispose();

      // Wait beyond debounce window.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.saves, isEmpty);

      await controller.close();
    });

    test('T1.5 silent failure — repository exception does not throw',
        () async {
      final controller = StreamController<ReaderEngineState>();
      final failingRepo = BookTypographyRepository(_FailingDb());
      final persister = TypographyPersister(
        bookId: 'b1',
        repository: failingRepo,
        stateSource: controller.stream,
        typographyGetter: () => TypographySettings.defaults(),
        debounceMs: 50,
      )..start();

      // Should not throw.
      controller.add(const ReaderEngineReady());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      persister.dispose();
      await controller.close();
    });
  });
}

/// Drift-less stub that throws on every call. Used only to verify
/// TypographyPersister swallows repository exceptions.
class _FailingDb implements dynamic {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('fake db failure');
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```
/c/flutter/bin/dart.bat test app/test/features/reader/services/typography_persister_test.dart
```
Expected: FAIL with "TypographyPersister is not defined" / "target file does not exist" (the import will fail because the implementation file doesn't exist yet).

- [ ] **Step 3: Write minimal implementation**

Create `app/lib/features/reader/services/typography_persister.dart` with this full content:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:zhiyue/data/repositories/book_typography_repository.dart';

/// 排版即时持久化服务。
///
/// 行为（参照 [ProgressPersister]）：
/// - 即时落盘：用户每次调字号/行距/字体等，500ms 后写入 [BookTypographyRepository]，
///   不依赖 ref.onDispose 或进程退出时的清理钩子。
/// - 防抖：连续变化合并，最后一次为准。
/// - distinct：相同 [TypographySettings] 不重复写（[TypographySettings] 已重写 ==）。
/// - 静默失败：磁盘 IO 异常不抛出，仅 log。
///
/// 背景：main.dart 的 _WindowCloseHandler.onWindowClose 调 exit(0) 同步终止
/// Dart isolate，会跳过所有 dispose 回调 + 截断所有 pending Future。原来在
/// reader_engine_provider.ref.onDispose 里 fire-and-forget 的 saveForBook 因此
/// 必然在关窗时丢失。改为订阅 engine.state$（setTypography 会触发 emit，见
/// epubx_renderer.dart:958），即时落盘避免依赖 dispose。
class TypographyPersister {
  TypographyPersister({
    required this.bookId,
    required this.repository,
    required this.stateSource,
    required this.typographyGetter,
    this.debounceMs = 500,
  });

  final String bookId;
  final BookTypographyRepository repository;
  final Stream<ReaderEngineState> stateSource;
  final TypographySettings Function() typographyGetter;
  final int debounceMs;

  StreamSubscription<ReaderEngineState>? _sub;
  Timer? _debounce;
  TypographySettings? _lastEmitted;
  TypographySettings? _lastPersisted;
  bool _alive = true;

  bool get isAlive => _alive;

  void start() {
    _sub = stateSource.listen(_onState);
  }

  void _onState(ReaderEngineState state) {
    if (!_alive) return;
    final current = typographyGetter();
    if (current == _lastEmitted) return;
    _lastEmitted = current;

    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: debounceMs), () async {
      final settings = _lastEmitted;
      if (settings == null || settings == _lastPersisted) return;
      try {
        await repository.saveForBook(bookId, settings);
        _lastPersisted = settings;
      } catch (e, st) {
        debugPrint('TypographyPersister save failed: $e\n$st');
      }
    });
  }

  void dispose() {
    _alive = false;
    _debounce?.cancel();
    _sub?.cancel();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```
/c/flutter/bin/dart.bat test app/test/features/reader/services/typography_persister_test.dart
```
Expected: PASS — all 5 tests green.

Also run analyze on the new files:
```
/c/flutter/bin/dart.bat analyze app/lib/features/reader/services/typography_persister.dart app/test/features/reader/services/typography_persister_test.dart
```
Expected: "No issues found".

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/reader/services/typography_persister.dart app/test/features/reader/services/typography_persister_test.dart
git commit -m "$(cat <<'EOF'
fix(reader): add TypographyPersister for immediate per-book save

Replaces the dispose-time fire-and-forget saveForBook (which exit(0)
in main.dart:148 truncates whenever user closes the window) with a
stream-subscription + debounce-500ms immediate save, mirroring
ProgressPersister. T1 of 3 for the typography-persistence-exit-crash
fix.
EOF
)"
```

---

### Task 2: Integrate TypographyPersister into reader_page

**Files:**
- Modify: `app/lib/features/reader/pages/reader_page.dart`

- [ ] **Step 1: Add the field and lifecycle hooks**

In `app/lib/features/reader/pages/reader_page.dart`, the existing `_ReaderPageState` class already has:

```dart
class _ReaderPageState extends ConsumerState<ReaderPage> {
  ProgressPersister? _persister;

  @override
  void dispose() {
    _persister?.dispose();
    super.dispose();
  }
```

Replace the field declaration block (lines around 56-63) with:

```dart
class _ReaderPageState extends ConsumerState<ReaderPage> {
  ProgressPersister? _persister;
  TypographyPersister? _typographyPersister;

  @override
  void dispose() {
    _persister?.dispose();
    _typographyPersister?.dispose();
    super.dispose();
  }
```

Then in the `data:` callback of the `engineAsync.when` call (around line 77), after `_ensureProgressPersister(engine);`, add a call to ensure the typography persister too:

```dart
        data: (engine) {
          _ensureProgressPersister(engine);
          _ensureTypographyPersister(engine);
          // ... rest unchanged
```

Finally, add the new `_ensureTypographyPersister` method right after `_ensureProgressPersister` (around line 122):

```dart
  void _ensureTypographyPersister(ReaderEngine engine) {
    if (_typographyPersister != null) return;
    _typographyPersister = TypographyPersister(
      bookId: widget.bookId,
      repository: ref.read(bookTypographyRepositoryProvider),
      stateSource: engine.state$,
      typographyGetter: () => engine.typography,
    )..start();
  }
```

And add the import at the top of the file with the other reader-service imports:

```dart
import '../services/progress_persister.dart';
import '../services/typography_persister.dart';
```

Plus the providers import if not already present (it is present — `core/providers.dart` is already imported by reader_page.dart per existing code, since `readingProgressRepositoryProvider` is used).

- [ ] **Step 2: Run existing reader_page tests to verify nothing breaks**

Run:
```
/c/flutter/bin/dart.bat test app/test/features/reader/pages/
```
Expected: All existing tests still pass.

Also run analyze:
```
/c/flutter/bin/dart.bat analyze app/lib/features/reader/pages/reader_page.dart
```
Expected: "No issues found".

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/reader/pages/reader_page.dart
git commit -m "$(cat <<'EOF'
fix(reader): wire TypographyPersister into reader_page lifecycle

Subscribes to engine.state$ on engine ready; dispose cancels the
subscription. This makes per-book typography persistence independent
of process-exit cleanup. T2 of 3.
EOF
)"
```

---

### Task 3: Remove fire-and-forget save from reader_engine_provider

**Files:**
- Modify: `app/lib/features/reader/providers/reader_engine_provider.dart`

- [ ] **Step 1: Replace the 4 ref.onDispose calls + delete the helper**

In `app/lib/features/reader/providers/reader_engine_provider.dart`, each of the 4 branches (epub / pdf / markdown / text) currently has:

```dart
final typographyRepo = ref.watch(bookTypographyRepositoryProvider);
ref.onDispose(() => _disposeEngineWithPersist(engine, bookId, typographyRepo));
```

Replace those 2 lines in all 4 branches with:

```dart
ref.onDispose(engine.close);
```

(The `typographyRepo` local becomes unused inside the provider body, but it's still needed for `_applyPersistedTypography` — keep the `ref.watch(bookTypographyRepositoryProvider)` line and the `_applyPersistedTypography(engine, bookId, typographyRepo)` call.)

Then delete the entire `_disposeEngineWithPersist` function at the bottom of the file (lines 159-167):

```dart
/// T2: snapshot engine.typography → upsert 到 per-book override → close 引擎。
/// `ref.onDispose` 不支持 await，整个操作 fire-and-forget。
void _disposeEngineWithPersist(
  ReaderEngine engine,
  String bookId,
  BookTypographyRepository repo,
) {
  final snapshot = engine.typography;
  repo.saveForBook(bookId, snapshot);
  engine.close();
}
```

Keep `_applyPersistedTypography` (the load path) unchanged.

- [ ] **Step 2: Run existing provider tests to verify nothing breaks**

Run:
```
/c/flutter/bin/dart.bat test app/test/features/reader/providers/
```
Expected: All existing tests still pass.

Specifically, the test file `app/test/features/reader/providers/reader_engine_provider_typography_persistence_test.dart` has a T3.1 test that asserts `saveForBook` is called on dispose. **This test will now FAIL** because we removed the dispose-time save. Update it:

- Rename T3.1 to assert the **opposite**: dispose does NOT call `saveForBook` (because we removed that path; persistence is now via TypographyPersister).
- Or delete T3.1 entirely if it no longer reflects the design.

The simpler choice: delete T3.1, keep T3.2 (first-time open uses defaults — still valid). Open `app/test/features/reader/providers/reader_engine_provider_typography_persistence_test.dart` and:

1. Delete the entire `test('T3.1 provider dispose calls saveForBook with current typography', ...)` block (lines ~79-105).
2. Update the group description from `'T3 - per-book typography persistence'` to `'T3 - per-book typography load on open'` to reflect the narrower scope.
3. Update the file header comment if it references the dispose-save behavior.

If T3.2 still references `_RecordingBookTypographyRepository` for save tracking, leave the fake class in place (it's harmless — getForBook is still used by `_applyPersistedTypography`).

- [ ] **Step 3: Run tests again to verify the updated suite passes**

Run:
```
/c/flutter/bin/dart.bat test app/test/features/reader/providers/reader_engine_provider_typography_persistence_test.dart
```
Expected: PASS (T3.2 only).

```
/c/flutter/bin/dart.bat test app/test/features/reader/providers/
```
Expected: All pass.

Analyze:
```
/c/flutter/bin/dart.bat analyze app/lib/features/reader/providers/reader_engine_provider.dart app/test/features/reader/providers/reader_engine_provider_typography_persistence_test.dart
```
Expected: "No issues found".

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/reader/providers/reader_engine_provider.dart app/test/features/reader/providers/reader_engine_provider_typography_persistence_test.dart
git commit -m "$(cat <<'EOF'
fix(reader): remove fire-and-forget saveForBook from engine provider

ref.onDispose now only calls engine.close(); persistence is handled
by TypographyPersister subscribed to engine.state$ in reader_page.
Updates T3.1 test (which asserted dispose-time save) — that behavior
is gone by design. T3 of 3.
EOF
)"
```

---

### Task 4: Full regression + manual smoke test

- [ ] **Step 1: Run the full reader test suite**

Run:
```
/c/flutter/bin/dart.bat test app/test/features/reader/
```
Expected: All tests pass. Pre-existing failures from prior session (typography_golden_test, book_open_bridge_test) are out of scope — note but do not fix.

- [ ] **Step 2: Run analyze on all touched files**

Run:
```
/c/flutter/bin/dart.bat analyze app/lib/features/reader/services/typography_persister.dart app/lib/features/reader/pages/reader_page.dart app/lib/features/reader/providers/reader_engine_provider.dart app/test/features/reader/services/typography_persister_test.dart app/test/features/reader/providers/reader_engine_provider_typography_persistence_test.dart
```
Expected: "No issues found".

- [ ] **Step 3: Manual smoke test (Windows build)**

This step requires building and running on Windows. Skip if not in a build-capable environment; otherwise:

```
cd C:\zhiyue_build\app
/c/flutter/bin/flutter.bat run -d windows --release
```

Manual scenario:
1. Open a book.
2. Open typography panel, change font size to 24.
3. Wait 1 second (debounce).
4. Close the app via window X button.
5. Reopen the app, open the same book.
6. Verify font size is 24 (not the default 18).

If the manual test passes, the fix is complete. If not, escalate to systematic-debugging Phase 1 with the new evidence.

- [ ] **Step 4: Push to Gitee (user authorized on 2026-07-09)**

```bash
git push origin master
```

---

## Self-Review

**1. Spec coverage:**
- User's bug: "调整字体后退出软件再打开书，字体恢复预设" → Fixed by T1+T2 (immediate save via persister) + T3 (remove broken dispose path). ✓
- "按书籍来" requirement → preserved (per-book save via `BookTypographyRepository.saveForBook(bookId, settings)`). ✓
- "按纪律修复" → subagent-driven-development execution. ✓

**2. Placeholder scan:**
- All code blocks contain complete implementation. No "TODO", "TBD", "implement later", "add appropriate error handling".
- All file paths are exact.
- All commands include expected output.

**3. Type consistency:**
- `TypographyPersister` constructor signature is identical in T1 (definition) and T2 (instantiation): `bookId`, `repository`, `stateSource`, `typographyGetter`, `debounceMs`.
- `BookTypographyRepository.saveForBook(String bookId, TypographySettings settings)` — matches existing signature in `app/lib/data/repositories/book_typography_repository.dart`.
- `engine.state$` and `engine.typography` getter — confirmed in `reader_engine.dart:67-70`.
- `ReaderEngineState` emit on `setTypography` — confirmed in `epubx_renderer.dart:958`.

**4. Risks:**
- PDF path: `PdfReaderEngine.setTypography` is assumed to emit state$ (M4 PDF path mirrors EPUB). If it doesn't, the persister won't fire for PDFs — manual test step (T4.3) covers this scenario and will surface the issue if present.
- The T3.1 test deletion is intentional; its assertion (dispose calls saveForBook) is now false by design.
