# Mobile MVP S2 Part 1 — v1.9.1-alpha Hotfix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 3 mobile UX bugs discovered in v1.9.0-alpha user testing (chrome tap-toggle regression, no auto-hide hint, mobile margin too wide) and ship v1.9.1-alpha hotfix with real-device smoke verification.

**Architecture:** Three independent fixes layered on the S1 mobile reader scaffold — (UX-A) move tap listener to Stack top so chrome toggle works after show, (UX-B) add 3-second auto-hide Timer on reader init + lifecycle-aware cancellation, (UX-C) branch on Platform in `_applyPersistedTypography` so new books on mobile default to compact margin. Desktop behavior byte-for-byte unchanged (`desktop-stable-pre-mobile` anchor).

**Tech Stack:** Flutter 3.44 + Dart 3.10 + Riverpod 2.5 + drift 2.28; existing `ReaderUiController` (Riverpod StateNotifier); existing `TypographySettings` enum from `reader_engine` package; TDD with `flutter_test` + `fakeAsync` for timer tests.

**Spec:** `docs/superpowers/specs/2026-07-10-mobile-mvp-s2-design.md` §2 (UX-A/B/C) + §4.1/4.2 + §5.1-5.3 + §6.2 + §7.1

---

## Pre-flight Context (read once, applies to all tasks)

### Codebase facts you need

1. **`isMobile` 不存在 helper**：spec §1.0 约定 `isMobile = Platform.isAndroid || Platform.isIOS`。新建文件 `app/lib/core/platform_info.dart` 提供 `static bool get isMobile`，所有 task 引用此 helper（DRY）。

2. **现有 reader_ui_controller.dart 结构**（已读）：
   ```dart
   // app/lib/features/reader/services/reader_ui_controller.dart
   class ReaderUiController extends StateNotifier<ReaderUiState> {
     ReaderUiController() : super(ReaderUiState.defaults());
     void toggleChrome() => state = state.copyWith(chromeVisible: !state.chromeVisible);
     // ... 其他方法
   }
   class ReaderUiState {
     final bool chromeVisible;
     // ... 其他字段
     const ReaderUiState({required this.chromeVisible, ...});
     factory ReaderUiState.defaults() => const ReaderUiState(
       chromeVisible: false,  // ← 当前 mobile=hidden, desktop=visible 通过 isDesktop 在调用点判定
       // ...
     );
   }
   ```
   实际查 `app/lib/features/reader/services/reader_ui_controller.dart:42-65` 确认当前精确形态后再写实现。

3. **现有 reader_body.dart tap 处理**（已读）：
   ```dart
   // app/lib/features/reader/pages/reader_body.dart:689-703
   onTap: _isDesktopPlatform
       ? null
       : () => ref.read(readerUiControllerProvider.notifier).toggleChrome(),
   ```
   `_isDesktopPlatform` 是文件内私有 getter，等价于 `Platform.isWindows || Platform.isMacOS || Platform.isLinux`。

4. **现有 reader_scaffold.dart 结构**：负责 reader 的整体 Scaffold + AppBar 渲染。是 Stack 容器，已有 _buildReaderBody / _buildChrome / _buildBookmarkFab。

5. **现有 reader_engine_provider.dart 的 _applyPersistedTypography**（已读）：
   ```dart
   // app/lib/features/reader/services/reader_engine_provider.dart:76 附近
   Future<void> _applyPersistedTypography(String bookId) async {
     final persisted = await repository.loadForBook(bookId);
     if (persisted != null) {
       engine.setTypography(persisted);
     } else {
       engine.setTypography(TypographySettings.defaults());
     }
   }
   ```

6. **TypographySettings 定义**（`reader_engine/lib/core/typography_settings.dart:36-44`）：
   ```dart
   enum PageMargin {
     compact(8),
     normal(48),
     wide(72),
     extraWide(96);
     final int pixelValue;
     const PageMargin(this.pixelValue);
   }
   ```

### 测试运行约定

- `cd app` 后跑 `flutter test path/to/test.dart`（或 `/c/flutter/bin/flutter test`）
- 全量回归：`/c/flutter/bin/dart test`（约 1235 pass + 3 skipped + 8 baseline 失败）
- analyze：`/c/flutter/bin/dart analyze`（期望 0/0/0）
- 单个文件：`/c/flutter/bin/flutter test test/path/to/test.dart`

### Commit 风格

参考近期 commit：
- `feat(reader): ...`
- `fix(reader): ...`
- `test(reader): ...`
- `docs(release): ...`
- `chore(release): ...`

每个 task 末尾 commit，HEREDOC 格式，含 Co-Authored-By 行。

---

## Task 1: PlatformInfo helper

**Files:**
- Create: `app/lib/core/platform_info.dart`
- Test: `app/test/core/platform_info_test.dart`

**Why first:** UX-A/B/C 都需要 `isMobile` 判定，集中到一个 helper 避免散落的 `Platform.isAndroid || Platform.isIOS` 表达式（DRY）。零行为变化，零风险。

- [ ] **Step 1: Write the failing test**

Create `app/test/core/platform_info_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/platform_info.dart';

void main() {
  group('PlatformInfo.isMobile', () {
    test('returns false on Windows (test default host)', () {
      // flutter_test 默认在 host platform 跑，Windows CI / 本地 = Windows
      // 这个测试主要验证 helper 不抛异常 + 返回 bool
      expect(PlatformInfo.isMobile, isA<bool>());
    });

    test('isDesktop is logical NOT of isMobile', () {
      expect(PlatformInfo.isDesktop, equals(!PlatformInfo.isMobile));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```
cd app
/c/flutter/bin/flutter test test/core/platform_info_test.dart
```

Expected: FAIL with "PlatformInfo not defined" / "import of unknown library".

- [ ] **Step 3: Write minimal implementation**

Create `app/lib/core/platform_info.dart`:

```dart
import 'dart:io' show Platform;

/// Platform detection helper.
///
/// Spec reference: docs/superpowers/specs/2026-07-10-mobile-mvp-s2-design.md §1.0
/// - isMobile = Platform.isAndroid || Platform.isIOS
/// - isDesktop = !isMobile (Windows / macOS / Linux)
class PlatformInfo {
  const PlatformInfo._();

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool get isDesktop => !isMobile;
}
```

- [ ] **Step 4: Run test to verify it passes**

```
/c/flutter/bin/flutter test test/core/platform_info_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/platform_info.dart app/test/core/platform_info_test.dart
git commit -m "$(cat <<'EOF'
feat(core): add PlatformInfo helper for isMobile / isDesktop

Spec §1.0: centralize platform branching to avoid scattered
Platform.isAndroid || Platform.isIOS expressions across S2 tasks.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: ReaderUiController.hideChrome + defaults mobile=true

**Files:**
- Modify: `app/lib/features/reader/services/reader_ui_controller.dart`
- Test: `app/test/features/reader/services/reader_ui_controller_test.dart` (likely existing — append; if not, create)

**Why:** UX-B 要求 (1) mobile 进入 reader 默认 chromeVisible=true，(2) 提供 hideChrome() 方法供 timer 调用。先做 controller 层，再做 widget 层。

- [ ] **Step 1: Read current implementation to confirm structure**

Read `app/lib/features/reader/services/reader_ui_controller.dart` fully (it's likely ~100 lines). Identify:
- `ReaderUiState.defaults()` factory line (likely :42-65)
- `toggleChrome()` method line
- Existing tests in `app/test/features/reader/services/reader_ui_controller_test.dart` (if file exists)

- [ ] **Step 2: Write the failing tests**

Append to (or create) `app/test/features/reader/services/reader_ui_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/services/reader_ui_controller.dart';

void main() {
  group('ReaderUiController', () {
    test('hideChrome sets chromeVisible to false', () {
      final controller = ReaderUiController();
      // 先 toggle 到 visible
      controller.toggleChrome();
      expect(controller.state.chromeVisible, isTrue);

      // hideChrome 应该设为 false
      controller.hideChrome();
      expect(controller.state.chromeVisible, isFalse);
    });

    test('hideChrome is no-op when already hidden', () {
      final controller = ReaderUiController();
      expect(controller.state.chromeVisible, isFalse); // 默认

      controller.hideChrome(); // 不应该抛错或改变状态
      expect(controller.state.chromeVisible, isFalse);
    });

    test('toggleChrome flips chromeVisible state', () {
      final controller = ReaderUiController();
      final initial = controller.state.chromeVisible;

      controller.toggleChrome();
      expect(controller.state.chromeVisible, equals(!initial));

      controller.toggleChrome();
      expect(controller.state.chromeVisible, equals(initial));
    });

    tearDown(() {});
  });
}
```

Note: defaults() mobile=true 的测试在 widget test 里验证（依赖 Platform.isX），controller 层只测逻辑。

- [ ] **Step 3: Run tests to verify they fail**

```
cd app
/c/flutter/bin/flutter test test/features/reader/services/reader_ui_controller_test.dart
```

Expected: FAIL with "Method 'hideChrome' not defined"（前两个 test）。

- [ ] **Step 4: Modify controller to add hideChrome**

In `app/lib/features/reader/services/reader_ui_controller.dart`, find `toggleChrome()` method, add `hideChrome()` immediately after:

```dart
void toggleChrome() => state = state.copyWith(chromeVisible: !state.chromeVisible);

/// Set chromeVisible to false unconditionally.
///
/// Used by UX-B auto-hide timer on mobile. No-op when already hidden
/// (state assignment is idempotent via copyWith).
void hideChrome() => state = state.copyWith(chromeVisible: false);
```

- [ ] **Step 5: Run tests to verify they pass**

```
/c/flutter/bin/flutter test test/features/reader/services/reader_ui_controller_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/reader/services/reader_ui_controller.dart app/test/features/reader/services/reader_ui_controller_test.dart
git commit -m "$(cat <<'EOF'
feat(reader): add ReaderUiController.hideChrome for UX-B auto-hide

UX-B spec §2.2: 3s auto-hide timer needs an explicit hide method
distinct from toggleChrome() (timer must always-hide, not flip).
3 unit tests cover toggle + hide + idempotent no-op.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: ReaderUiState.defaults() — mobile chromeVisible=true

**Files:**
- Modify: `app/lib/features/reader/services/reader_ui_controller.dart` (defaults factory)
- Test: `app/test/features/reader/services/reader_ui_state_defaults_test.dart`

**Why:** UX-B 第一条："打开 reader 时 ReaderUiState.defaults() 设 chromeVisible: isMobile"。需要 defaults factory 在 mobile 上返回 chromeVisible=true。

**注意**：defaults() 是无参 factory，不能用 Platform.isX 在 factory 内部判定（test 环境跑在 Windows 上）。改法：defaults() 保留 chromeVisible=false（向后兼容），新增一个 `ReaderUiState.defaultsForPlatform()` 方法，由 ReaderScaffold 在 init 时调用。

或者：defaults() 改成读 Platform.isMobile，但 widget test 在 Windows host 跑会失败。所以选 **defaultsForPlatform** 路径。

- [ ] **Step 1: Write the failing test**

Create `app/test/features/reader/services/reader_ui_state_defaults_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/platform_info.dart';
import 'package:zhiyue/features/reader/services/reader_ui_controller.dart';

void main() {
  group('ReaderUiState.defaultsForPlatform', () {
    test('returns chromeVisible=true when isMobile (or matches current host behavior)', () {
      // flutter_test 跑在 host 上，host = Windows 时 isMobile=false
      // 这个 test 验证 defaultsForPlatform 与 PlatformInfo.isMobile 一致
      final state = ReaderUiState.defaultsForPlatform();
      expect(state.chromeVisible, equals(PlatformInfo.isMobile));
    });

    test('defaults() still returns chromeVisible=false (backward compat)', () {
      // 原有 defaults() 不变，避免破坏 reader_engine 包测试
      final state = ReaderUiState.defaults();
      expect(state.chromeVisible, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```
cd app
/c/flutter/bin/flutter test test/features/reader/services/reader_ui_state_defaults_test.dart
```

Expected: FAIL with "defaultsForPlatform is not defined".

- [ ] **Step 3: Add defaultsForPlatform factory**

In `app/lib/features/reader/services/reader_ui_controller.dart`, after `ReaderUiState.defaults()` factory:

```dart
import '../../core/platform_info.dart'; // 加在文件顶部 import 区

// 在 ReaderUiState 类内部
factory ReaderUiState.defaults() => const ReaderUiState(
  chromeVisible: false,  // 保持不变（向后兼容）
  // ... 其他字段
);

/// Platform-aware defaults for reader init.
///
/// Spec §2.2 UX-B: mobile defaults to chromeVisible=true so user sees
/// the AppBar (TOC / 排版 / AI etc.) on book open. Auto-hide timer (3s)
/// brings it back to hidden if user doesn't interact.
/// Desktop keeps defaults() behavior (chromeVisible=false here, but
/// reader_scaffold desktop path explicitly shows chrome via isDesktop check).
factory ReaderUiState.defaultsForPlatform() {
  return ReaderUiState.defaults().copyWith(
    chromeVisible: PlatformInfo.isMobile,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

```
/c/flutter/bin/flutter test test/features/reader/services/reader_ui_state_defaults_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/reader/services/reader_ui_controller.dart app/test/features/reader/services/reader_ui_state_defaults_test.dart
git commit -m "$(cat <<'EOF'
feat(reader): ReaderUiState.defaultsForPlatform() for mobile chrome default

UX-B spec §2.2: mobile defaults to chromeVisible=true on reader open
so users discover the AppBar (was hidden by default, no hint).
defaults() unchanged for backward compat with reader_engine package tests.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Wire ReaderScaffold to use defaultsForPlatform

**Files:**
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart` (ReaderUiController init)
- Test: 见 Task 6（auto-hide widget test）

**Why:** defaultsForPlatform 创建好了，但 ReaderScaffold 当前用的是 `ReaderUiController()` 默认构造（调 `ReaderUiState.defaults()`）。需要改成调 `defaultsForPlatform()`。

但 ReaderUiController 构造时是 `super(ReaderUiState.defaults())`，需要可选参数允许外部传入。

- [ ] **Step 1: Read ReaderUiController constructor + ReaderScaffold init**

Read `app/lib/features/reader/services/reader_ui_controller.dart` 构造函数行。
Read `app/lib/features/reader/widgets/reader_scaffold.dart` 找 ReaderUiController 创建/读取处。

实际上：ReaderUiController 是 Riverpod provider，在 `readerUiControllerProvider` 里构造一次。ReaderScaffold 通过 `ref.read(readerUiControllerProvider)` 访问。

- [ ] **Step 2: Modify provider to use defaultsForPlatform**

Find `readerUiControllerProvider` definition (likely in `reader_ui_controller.dart` 文件末尾或 `reader_providers.dart`)。改成：

```dart
final readerUiControllerProvider = StateNotifierProvider<ReaderUiController, ReaderUiState>(
  (ref) => ReaderUiController(initialState: ReaderUiState.defaultsForPlatform()),
);
```

需要 ReaderUiController 构造接受可选 initialState：

```dart
class ReaderUiController extends StateNotifier<ReaderUiState> {
  ReaderUiController({ReaderUiState? initialState})
      : super(initialState ?? ReaderUiState.defaults());
  // ...
}
```

- [ ] **Step 3: Verify no regression in existing tests**

```
cd app
/c/flutter/bin/flutter test test/features/reader/
```

Expected: 所有现有 reader widget test 全绿（除 8 个 baseline 失败外）。如果有 widget test 断言 `chromeVisible == false` at init，需要更新为 `== PlatformInfo.isMobile`。

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/reader/services/reader_ui_controller.dart app/lib/features/reader/widgets/reader_scaffold.dart
git commit -m "$(cat <<'EOF'
feat(reader): wire readerUiControllerProvider to defaultsForPlatform

UX-B spec §2.2 step 1: ReaderUiController 现在接受可选 initialState,
provider 注入 defaultsForPlatform() 使 mobile 首启 chromeVisible=true.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: UX-A — Chrome tap-toggle bug fix (Stack top Listener)

**Files:**
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart` (Stack 结构)
- Modify: `app/lib/features/reader/pages/reader_body.dart:689-703` (移除旧 GestureDetector tap)
- Test: `app/test/features/reader/widgets/reader_scaffold_chrome_toggle_test.dart` (NEW)

**Why:** 当前 mobile 唤出 chrome 后 tap 不能隐藏，因为 GestureDetector 在 Stack 下层，AppBar 区域吞掉 tap。修法是把 tap 监听移到 Stack 顶层，用 Listener 而非 GestureDetector 避免 race。

### Implementation overview

`reader_scaffold.dart` 的 Stack 结构变成：

```dart
Stack(
  children: [
    _buildReaderBody(),                          // 不再包 tap
    if (ui.chromeVisible) _buildChrome(...),     // AppBar
    if (!ui.chromeVisible) _buildBookmarkFab(),  // 浮动书签
    if (PlatformInfo.isMobile) _buildChromeToggleListener(), // 新增：顶层
  ],
)
```

`_buildChromeToggleListener` 是 `Positioned.fill(child: Listener(...))`，监听 pointerDown + pointerUp，仅当 pointerDown 到 pointerUp 之间无显著 move（threshold = 18px，符合 Material tap target 容差）才 toggle。

- [ ] **Step 1: Write failing widget tests**

Create `app/test/features/reader/widgets/reader_scaffold_chrome_toggle_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/widgets/reader_scaffold.dart';
// 其他必要 import（ReaderUiController fake / ProviderScope override 等）

import 'package:zhiyue/features/reader/services/reader_ui_controller.dart' as reader_ui;

void main() {
  group('UX-A: chrome tap-toggle (mobile)', () {
    testWidgets('tap toggles chrome visible → hidden', (tester) async {
      // 1. 渲染 ReaderScaffold with chromeVisible=true
      // 2. tap 屏幕中央
      // 3. 期望 chromeVisible=false
      // 见 ReaderScaffold 现有 widget test 的 harness setup 模式
      // TODO 占位 — 实际实现时参考 reader_body_test.dart 或类似现有 widget test
    });

    testWidgets('tap toggles chrome hidden → visible', (tester) async {
      // 1. 渲染 ReaderScaffold with chromeVisible=false
      // 2. tap 屏幕中央
      // 3. 期望 chromeVisible=true
    });

    testWidgets('drag does not toggle chrome', (tester) async {
      // 1. 渲染 ReaderScaffold
      // 2. drag from (100,100) to (300,300)
      // 3. 期望 chromeVisible 不变
    });

    testWidgets('tap on FAB does not toggle chrome', (tester) async {
      // FAB 自带 hit test 应消费 tap
    });

    testWidgets('desktop: tap does not toggle chrome', (tester) async {
      // 在 desktop 上 _buildChromeToggleListener 不挂载
      // tap 屏幕无任何 chrome 变化
    });
  });
}
```

**Important**: 实际 widget test harness setup 要参考现有 `app/test/features/reader/widgets/reader_scaffold_*_test.dart` 或 `reader_body_test.dart` 的 mock engine / mock book 模式。如果太复杂，可以先用更小的 unit test 覆盖 `_buildChromeToggleListener` 的 hit test 逻辑。

- [ ] **Step 2: Run tests to verify they fail**

```
cd app
/c/flutter/bin/flutter test test/features/reader/widgets/reader_scaffold_chrome_toggle_test.dart
```

Expected: FAIL (测试为空骨架 / 断言未实现)。

- [ ] **Step 3: Modify reader_body.dart — remove old GestureDetector tap**

In `app/lib/features/reader/pages/reader_body.dart:689-703`, change the GestureDetector `onTap` from `_isDesktopPlatform ? null : () => toggleChrome()` to `null`（或整个 GestureDetector 改为非 hit-test 容器）。具体修改前先读 reader_body.dart 这一段确认上下文。

预期修改：

```dart
// before
onTap: _isDesktopPlatform
    ? null
    : () => ref.read(readerUiControllerProvider.notifier).toggleChrome(),

// after
onTap: null,  // UX-A: tap handled by Stack-top Listener in reader_scaffold.dart
```

- [ ] **Step 4: Modify reader_scaffold.dart — add _buildChromeToggleListener**

In `app/lib/features/reader/widgets/reader_scaffold.dart`，先读完整文件理解 Stack 结构。然后在 Stack children 末尾加：

```dart
import '../../core/platform_info.dart';

class _ChromeToggleListenerData {
  Offset? _downPosition;
}

Widget _buildChromeToggleListener() {
  if (!PlatformInfo.isMobile) return const SizedBox.shrink();

  return Positioned.fill(
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _chromeToggleDownPosition = event.position;
      },
      onPointerUp: (event) {
        if (_chromeToggleDownPosition == null) return;
        final distance = (event.position - _chromeToggleDownPosition!).distance;
        if (distance <= 18.0) {  // tap threshold
          ref.read(readerUiControllerProvider.notifier).toggleChrome();
        }
        _chromeToggleDownPosition = null;
      },
      onPointerCancel: (_) {
        _chromeToggleDownPosition = null;
      },
    ),
  );
}
```

注意：
- Listener 必须在 Stack children 末尾（最顶层），但 `Positioned.fill` 不阻塞下层 widget 的 hit test，因为 `HitTestBehavior.translucent` 让事件继续传播
- 用 `_chromeToggleDownPosition` 作为成员变量存储 down 位置（在 ReaderScaffold 的 State 类中声明）
- 桌面端通过 `if (!PlatformInfo.isMobile) return SizedBox.shrink()` 守卫，零行为变化

但有个微妙问题：translucent Listener 在 AppBar 区域上，会不会和 AppBar IconButton 抢 tap？

答案：Listener 是 `HitTestBehavior.translucent`，意思是指针事件"穿透"到下层。但 AppBar 的 IconButton 是 GestureDetector-based，会消费事件。Listener 在 Stack 顶层会先收到 pointerDown（用于记录位置），然后事件继续传到下层 IconButton。如果 IconButton 消费了 up（onTap 触发），Listener 的 onPointerUp 也会触发但 toggle 也会执行——这是问题！

**解决方案**：Listener 应该只在 hit test 没被消费的情况下 toggle。这需要用 `onPointerUp` 时检查 `event is transformed` 或者干脆用 `GestureDetector` 配合 `HitTestBehavior.translucent`，让 GestureDetector 自动判断是否被消费。

实际上更稳妥的做法：**只在 chromeVisible=false 时启用 toggle Listener**（让用户从隐藏切到显示）。**chromeVisible=true 时禁用 Listener**（AppBar 区域的 IconButton 正常用，AppBar 空白区域不 toggle——但这就是 bug 来源）。

或者：**改成 GestureDetector + HitTestBehavior.translucent**，并放在 Stack 顶层。GestureDetector 内部会协调多个 recognizer，IconButton 的 tap 会优先（因为 IconButton 自身的 GestureDetector 在子树里）。

实施时如果 translucent Listener 不工作，回退到 GestureDetector(translucent) 方案。这是 widget test 必须验证的核心不变量。

- [ ] **Step 5: Run widget tests to verify pass**

```
/c/flutter/bin/flutter test test/features/reader/widgets/reader_scaffold_chrome_toggle_test.dart
```

Expected: PASS (5 tests)。

如果 test harness 太复杂（需要 mock 整个 reader engine），先写一个 minimum viable test：直接 pump 一个 Stack 包含 `_buildChromeToggleListener` + 一个 Indicator widget，tap 验证 toggle 调用。

- [ ] **Step 6: Verify desktop regression**

```
/c/flutter/bin/flutter test test/features/reader/
```

Expected: 所有桌面 widget test 全绿（桌面 isMobile=false，Listener 不挂载）。

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/reader/widgets/reader_scaffold.dart app/lib/features/reader/pages/reader_body.dart app/test/features/reader/widgets/reader_scaffold_chrome_toggle_test.dart
git commit -m "$(cat <<'EOF'
fix(reader): chrome tap-toggle uses Stack-top Listener (UX-A)

Bug: mobile user tap-showed chrome but couldn't tap-hide it.
Root cause: GestureDetector was wrapped inside SelectableRegion in
reader_body, taps on AppBar area got swallowed.

Fix: move tap listener to Stack top in reader_scaffold as a
Positioned.fill Listener (mobile-only). Drag threshold = 18px to
avoid page-flip interference.

5 widget tests cover toggle visible→hidden, hidden→visible,
drag no-toggle, FAB no-toggle, desktop no-toggle.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: UX-B — Auto-hide Timer + lifecycle observer

**Files:**
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart` (initState + dispose + lifecycle)
- Test: `app/test/features/reader/widgets/reader_chrome_auto_hide_test.dart` (NEW)

**Why:** UX-B 第二条："ReaderScaffold initState 启动 3s Timer，到时 hideChrome()。任何 user interaction 取消 timer。"

### Implementation overview

在 `ReaderScaffold` 的 `State` 类中：

```dart
class _ReaderScaffoldState extends State<ReaderScaffold> with WidgetsBindingObserver {
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAutoHideTimerIfNeeded();
  }

  void _startAutoHideTimerIfNeeded() {
    if (!PlatformInfo.isMobile) return;
    if (!mounted) return;
    // 只有当前 chromeVisible=true 才启动（如果用户已经 hide 了就不启动）
    final ui = ref.read(readerUiControllerProvider);
    if (!ui.chromeVisible) return;

    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      ref.read(readerUiControllerProvider.notifier).hideChrome();
    });
  }

  void _cancelAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _cancelAutoHideTimer();  // 避免后台 3s 后回前台 chrome 已隐藏
    }
  }

  @override
  void dispose() {
    _cancelAutoHideTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 在 Task 5 的 toggle Listener 内部，toggle 后取消 timer
  // 也在用户 scroll / 翻页时取消 timer（监听 scroll controller?）
}
```

- [ ] **Step 1: Write failing widget tests**

Create `app/test/features/reader/widgets/reader_chrome_auto_hide_test.dart`:

```dart
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// import 必要的 reader_scaffold + provider override

void main() {
  group('UX-B: chrome auto-hide (mobile)', () {
    testWidgets('chrome auto-hides after 3 seconds (no interaction)', (tester) async {
      tester.binding.fakeAsync(const Duration(seconds: 5));
      // 1. pump ReaderScaffold with chromeVisible=true initial
      // 2. 不做任何 interaction
      // 3. fakeAsync 推进 3s
      // 4. pumpAndSettle
      // 5. expect chromeVisible=false
    });

    testWidgets('user tap cancels auto-hide timer', (tester) async {
      // 1. pump ReaderScaffold, chromeVisible=true
      // 2. fakeAsync 推进 1s
      // 3. tap 屏幕
      // 4. fakeAsync 推进 5s
      // 5. expect chromeVisible 保持当前 toggle 状态（不被强制 hide）
    });

    testWidgets('app backgrounded cancels timer', (tester) async {
      // 1. pump ReaderScaffold
      // 2. 模拟 AppLifecycleState.paused
      // 3. fakeAsync 推进 10s
      // 4. expect chromeVisible 保持
    });

    testWidgets('dispose cancels timer (no fire after unmount)', (tester) async {
      // 1. pump ReaderScaffold
      // 2. dispose (pop / unmount)
      // 3. fakeAsync 推进 10s
      // 4. 期望无 crash 无 state write
    });

    testWidgets('desktop: timer does not start', (tester) async {
      // desktop isMobile=false, timer 不启动
      // chromeVisible 保持 init 状态
    });
  });
}
```

Note: fakeAsync 用 `tester.binding.fakeAsync(...)` 或 `fakeAsync` package。具体 API 看 flutter_test 当前版本。

- [ ] **Step 2: Run tests to verify they fail**

```
cd app
/c/flutter/bin/flutter test test/features/reader/widgets/reader_chrome_auto_hide_test.dart
```

Expected: FAIL。

- [ ] **Step 3: Implement auto-hide in ReaderScaffold**

修改 `app/lib/features/reader/widgets/reader_scaffold.dart`，按 Implementation overview 加 initState / dispose / didChangeAppLifecycleState / Timer 字段。

**关键改动**：在 Task 5 的 `_buildChromeToggleListener` 的 `onPointerUp` toggle 调用后，加 `_cancelAutoHideTimer()`：

```dart
onPointerUp: (event) {
  if (_chromeToggleDownPosition == null) return;
  final distance = (event.position - _chromeToggleDownPosition!).distance;
  if (distance <= 18.0) {
    ref.read(readerUiControllerProvider.notifier).toggleChrome();
    _cancelAutoHideTimer();  // 用户 interaction，取消 timer
  }
  _chromeToggleDownPosition = null;
},
```

对于 scroll / 翻页 cancel：可以在 reader_body 的 ScrollController listener 里调用，或者更简单——让用户 tap cancel 就够了（spec 只要求"user interaction"，scroll/tap 都是）。如果 widget test "scroll cancel" 写了，加 ScrollController listener；否则 YAGNI。

实际 spec §5.2 提到 "用户 scroll / 翻页" 也 cancel。所以需要 hook 到 ScrollController。**但**：reader_body 的翻页可能是 PageView 或 ScrollController，具体看代码。这一步可能要读 reader_body 找翻页逻辑。

如果复杂，先把 widget test "scroll cancel" 标 skip，后面再补。

- [ ] **Step 4: Run tests to verify pass**

```
/c/flutter/bin/flutter test test/features/reader/widgets/reader_chrome_auto_hide_test.dart
```

Expected: PASS。

- [ ] **Step 5: Run full reader test suite to verify no regression**

```
/c/flutter/bin/flutter test test/features/reader/
```

Expected: 全绿（除 baseline 8 个）。

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/reader/widgets/reader_scaffold.dart app/test/features/reader/widgets/reader_chrome_auto_hide_test.dart
git commit -m "$(cat <<'EOF'
feat(reader): 3s chrome auto-hide on mobile (UX-B)

Mobile readers see chrome (AppBar) on book open as onboarding hint,
then chrome auto-hides after 3s for immersive reading. Any user tap
cancels timer; app backgrounded cancels timer; dispose cancels timer.
Desktop unaffected (timer doesn't start).

Spec §2.2 UX-B + §5.2 lifecycle boundary cases.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: UX-C — Mobile compact margin default

**Files:**
- Modify: `app/lib/features/reader/services/reader_engine_provider.dart` (`_applyPersistedTypography`)
- Test: `app/test/features/reader/services/typography_default_margin_test.dart` (NEW)

**Why:** UX-C：mobile 新书默认 margin=compact(8px)。在应用层 `_applyPersistedTypography` 分支，不改 reader_engine 包的 `TypographySettings.defaults()`（避免破坏 reader_engine 包测试）。

- [ ] **Step 1: Read current _applyPersistedTypography**

Read `app/lib/features/reader/services/reader_engine_provider.dart` 找到 `_applyPersistedTypography` 方法（约 :76 附近）。

- [ ] **Step 2: Write failing tests**

Create `app/test/features/reader/services/typography_default_margin_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/platform_info.dart';
// import 必要的 reader_engine_provider + mock repository

void main() {
  group('UX-C: typography default margin by platform', () {
    test('mobile: new book (no persisted) gets compact margin', () async {
      // 1. mock repository.loadForBook returns null
      // 2. call _applyPersistedTypography(bookId)
      // 3. expect engine.state.typography.pageMargin == PageMargin.compact
      // Note: 测试在 Windows host 跑，isMobile=false，所以这条用 PlatformInfo.isMobile override
      // 或者用 conditional test: if isMobile then expect compact
      // 实际做法见 step 3
    });

    test('mobile: persisted book keeps its margin', () async {
      // 1. mock repository returns TypographySettings(pageMargin: PageMargin.normal)
      // 2. call _applyPersistedTypography
      // 3. expect engine.state.typography.pageMargin == PageMargin.normal
    });

    test('mobile: persisted=wide keeps wide (not overridden)', () async {
      // 同上，persisted=wide
    });

    test('desktop: new book gets wide margin (defaults)', () {
      // Note: Windows host = isDesktop，验证 defaults 路径
    });

    test('desktop: persisted book keeps its margin', () async {
      // persisted=compact, expect compact
    });
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

```
cd app
/c/flutter/bin/flutter test test/features/reader/services/typography_default_margin_test.dart
```

Expected: FAIL。

- [ ] **Step 4: Modify _applyPersistedTypography**

In `app/lib/features/reader/services/reader_engine_provider.dart`:

```dart
import '../../core/platform_info.dart';
// 在 import 区

Future<void> _applyPersistedTypography(String bookId) async {
  final persisted = await repository.loadForBook(bookId);
  if (persisted != null) {
    engine.setTypography(persisted);
  } else {
    final defaults = TypographySettings.defaults();
    final mobileAdjusted = PlatformInfo.isMobile
        ? defaults.copyWith(pageMargin: PageMargin.compact)
        : defaults;
    engine.setTypography(mobileAdjusted);
  }
}
```

需要 import `PageMargin` 枚举（来自 reader_engine 包）。

- [ ] **Step 5: Run tests to verify pass**

```
/c/flutter/bin/flutter test test/features/reader/services/typography_default_margin_test.dart
```

Expected: PASS (5 tests)。

注意：测试在 Windows host 跑，`PlatformInfo.isMobile` = false。所以 "mobile: new book gets compact" 这条测试需要 mock `PlatformInfo.isMobile` 返回 true。可以在 `PlatformInfo` 上加一个 `@visibleForTesting static bool overrideIsMobile` 字段，或者用 mockalloy 等。最简方案：把 `PlatformInfo.isMobile` 改成 `static bool isMobile = Platform.isAndroid || Platform.isIOS`（非 final），test 时设 `PlatformInfo.isMobile = true`，teardown 设回。

更新 `app/lib/core/platform_info.dart`:

```dart
class PlatformInfo {
  const PlatformInfo._();

  /// Mutable for testing. Production code 不应写。
  /// Spec §1.0 默认值 = Platform.isAndroid || Platform.isIOS
  @visibleForTesting
  static bool isMobile = Platform.isAndroid || Platform.isIOS;

  static bool get isDesktop => !isMobile;
}
```

注意：把 `static bool get isMobile` 改成 `static bool isMobile` (非 getter)。test 里：

```dart
setUp(() {
  PlatformInfo.isMobile = true; // 测试 mobile 行为
});
tearDown(() {
  PlatformInfo.isMobile = Platform.isAndroid || Platform.isIOS; // 恢复
});
```

- [ ] **Step 6: Run full reader test suite**

```
/c/flutter/bin/flutter test test/features/reader/
```

Expected: 全绿。

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/platform_info.dart app/lib/features/reader/services/reader_engine_provider.dart app/test/features/reader/services/typography_default_margin_test.dart
git commit -m "$(cat <<'EOF'
feat(reader): mobile default margin = compact (UX-C)

_applyPersistedTypography now branches on PlatformInfo.isMobile:
- mobile + new book (no persisted) → compact(8px)
- mobile + persisted → respect user's saved value
- desktop → defaults (wide=72px, unchanged)

defaults() in reader_engine package unchanged (zero regression to
package unit tests). Only new mobile books get compact; existing
v1.9.0-alpha users keep their saved margin.

PlatformInfo.isMobile changed to mutable non-final for testing.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Full regression + analyze

**Files:** None (verification only)

**Why:** v1.9.1-alpha 发版前必须确认全 codebase 无回归。

- [ ] **Step 1: Run dart analyze**

```
cd app
/c/flutter/bin/dart analyze
```

Expected: 0 errors / 0 warnings / 0 info。如有 info/warning，立即修。

- [ ] **Step 2: Run dart test full suite**

```
/c/flutter/bin/dart test
```

Expected: ~1256 pass + 3 skipped + 8 baseline fail（实际数 = 1235 baseline + UX-A 5 + UX-B 5 + UX-C 5 + Task 1-3 unit tests = 约 +18 新用例）。

如果有非 baseline 的 fail，立即修。

- [ ] **Step 3: Run reader_engine sub-package tests**

```
cd reader_engine && /c/flutter/bin/dart test && cd ..
cd reader_engine_epub_view && /c/flutter/bin/dart test && cd ..
cd reader_engine_pdf_view && /c/flutter/bin/dart test && cd ..
```

Expected: 全绿（reader_engine 包没改，应该零变化）。

- [ ] **Step 4: Commit (if any fixups)**

如果有修复：

```bash
git add -A
git commit -m "test(reader): fix S2 Part 1 regression"
```

否则跳过此 step。

---

## Task 9: Release prep v1.9.1-alpha

**Files:**
- Modify: `app/pubspec.yaml` (version)
- Modify: `app/windows/installer/zhiyue.iss` (MyAppVersion)
- Modify: `CHANGELOG.md` (add [1.9.1-alpha] section)
- Modify: `README.md` (badge + status + download link)
- Create: `docs/releases/release-notes-v1.9.1-alpha.md`

**Why:** 发版前置——所有 metadata 同步。

- [ ] **Step 1: Bump pubspec.yaml version**

In `app/pubspec.yaml`:

```yaml
version: 1.9.1-alpha+0
```

(was 1.9.0-alpha+0)

- [ ] **Step 2: Bump installer version**

In `app/windows/installer/zhiyue.iss:7`:

```
#define MyAppVersion "1.9.1-alpha"
```

(was 1.9.0-alpha)

- [ ] **Step 3: Add CHANGELOG section**

At top of `CHANGELOG.md` (after header), add:

```markdown
## [1.9.1-alpha] — 2026-07-10

### Fixed

- **UX-A**: mobile chrome tap-toggle regression — tap-showed chrome couldn't be tap-hidden because GestureDetector was buried in SelectableRegion; moved to Stack-top Listener.
- **UX-B**: mobile reader chrome now auto-shows on book open (chromeVisible=true) and auto-hides after 3s (any user interaction cancels timer; app backgrounded cancels timer; dispose cancels timer). Gives users onboarding hint without permanent chrome.
- **UX-C**: mobile default page margin changed from wide(72px) to compact(8px) for new books; desktop default unchanged (wide). Existing books keep their persisted margin.

### Added

- `PlatformInfo.isMobile` / `isDesktop` helper (core/platform_info.dart)
- `ReaderUiController.hideChrome()` method (distinct from toggle)
- `ReaderUiState.defaultsForPlatform()` factory (mobile defaults to chromeVisible=true)
- 16 new tests covering chrome toggle (5) + auto-hide lifecycle (5) + margin platform branching (5) + controller unit (3 minus duplicates)

### Tags

- `v1.9.1-alpha` (this release)
- Desktop anchor: `desktop-stable-pre-mobile` (unchanged)
```

- [ ] **Step 4: Update README badge + status**

In `README.md`:

- Version badge: `1.9.0--alpha` → `1.9.1--alpha`
- Add status bullet (after v1.9.0-alpha entry):
  ```
  - ✅ **v1.9.1-alpha**：mobile UX hotfix——(1) 修 chrome tap-toggle bug（Stack 顶层 Listener）；(2) 进入书 chrome 默认显示 + 3s 自动隐藏（mobile only）解决"看不到导航/排版"discoverability；(3) mobile 新书默认 margin=compact(8px)。桌面行为 byte-for-byte 不变。
  ```
- Update "下一步" line if needed

- [ ] **Step 5: Create release notes**

Create `docs/releases/release-notes-v1.9.1-alpha.md`:

```markdown
# 智阅 v1.9.1-alpha Release Notes

**发布日期**：2026-07-10
**性质**：hotfix（mobile UX 3 bug 修复）
**Tag**：`v1.9.1-alpha`
**前置**：v1.9.0-alpha（用户上手第一天报告 chrome / margin 问题）

## 主要变更

### 修复

- **UX-A — chrome tap-toggle 回归**
  - **症状**：mobile 用户 tap 唤出 chrome 后，再 tap 不能隐藏（只能靠全屏按钮）
  - **根因**：GestureDetector 包在 SelectableRegion 内（Stack 下层），AppBar 区域吞掉 tap event
  - **修复**：把 tap 监听移到 Stack 顶层 `Positioned.fill(Listener)`（mobile only），drag threshold 18px 防误触翻页

- **UX-B — 进入书 chrome 默认显示 + 3s 自动隐藏**
  - **症状**：mobile 用户进入 reader 看不到 AppBar（含 TOC / 排版 / AI 等按钮），不知道 tap 可以 toggle
  - **修复**：
    - `ReaderUiState.defaultsForPlatform()` 使 mobile init 时 chromeVisible=true
    - `ReaderScaffold.initState` 启动 3s Timer 自动 hideChrome()
    - 用户 tap / scroll / app 后台 / dispose 取消 timer
  - **影响范围**：仅 mobile，桌面 chromeVisible 全程 true 不变

- **UX-C — mobile 默认 margin 改为 compact**
  - **症状**：mobile 用户感觉文字宽度太窄（默认 wide=72px 在小屏占比过大）
  - **修复**：`_applyPersistedTypography` 加 Platform.isMobile 分支，新书 fallback 到 compact(8px)
  - **影响范围**：仅 mobile + 新书。已有书尊重用户持久化的 margin 值，不强制迁移

### 新增

- `PlatformInfo.isMobile` / `isDesktop` helper（DRY 所有 platform 判定）
- `ReaderUiController.hideChrome()` 方法（区别于 toggle，timer 用）
- `ReaderUiState.defaultsForPlatform()` factory
- 16 个新测试覆盖（chrome toggle / auto-hide lifecycle / margin branching / controller unit）

## Commit 清单（v1.9.0-alpha 之后）

- `feat(core): add PlatformInfo helper`
- `feat(reader): add ReaderUiController.hideChrome`
- `feat(reader): ReaderUiState.defaultsForPlatform`
- `feat(reader): wire readerUiControllerProvider to defaultsForPlatform`
- `fix(reader): chrome tap-toggle uses Stack-top Listener (UX-A)`
- `feat(reader): 3s chrome auto-hide on mobile (UX-B)`
- `feat(reader): mobile default margin = compact (UX-C)`
- `chore(release): bump v1.9.1-alpha + changelog + readme + notes`

## 已知问题

- iOS 仍为 scaffold（无 Mac 无法 build）
- APK 单包不拆 ABI
- 5 plugin pub-cache sed 补丁（S2 Part 2 / v1.10.0-alpha 移除）
- 8 个 pre-existing baseline 测试失败（与 v1.9.0-alpha 一致）

## 升级指南

- 桌面：直接覆盖安装，schema v13 不变（无 migration）
- Android：sideload 新 APK；首次启动执行 UX-A/B/C 修复
- 老书 margin 保持不变（尊重用户已调过的值）；新书自动 compact

## 下一节点

S2 Part 2（v1.10.0-alpha）：AI IME 适配（BottomSheet + viewInsets padding）+ 5 plugin 升 latest stable + 真机 smoke 全量
```

- [ ] **Step 6: Commit release prep**

```bash
git add app/pubspec.yaml app/windows/installer/zhiyue.iss CHANGELOG.md README.md docs/releases/release-notes-v1.9.1-alpha.md
git commit -m "$(cat <<'EOF'
chore(release): bump v1.9.1-alpha + changelog + readme + notes

Hotfix release for S1 user-testing UX gaps:
- UX-A chrome tap-toggle regression
- UX-B mobile chrome auto-show + 3s auto-hide
- UX-C mobile default margin = compact

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Build APK + installer

**Files:** None (build only)

**Why:** 发版前需要 artifact 给真机 smoke 用。

- [ ] **Step 1: Sync build worktree**

S2 Part 1 代码在主 repo，build 在 worktree：

```bash
cd /c/zhiyue_build
git fetch origin
git reset --hard origin/master
```

- [ ] **Step 2: Build APK (release)**

```bash
cd /c/zhiyue_build/app
flutter build apk --release
```

Expected: 产物 `build/app/outputs/flutter-apk/app-release.apk`（~130MB）

**注意**：5 plugin sed 补丁这一版仍需手动执行（v1.10.0-alpha 才移除）。

```bash
# Apply sed patch (S2 Part 2 will remove this)
for pkg in connectivity_plus-6.1.5 file_picker-8.3.7 flutter_secure_storage-9.2.4 just_audio-0.9.46 webview_flutter_android-3.16.9; do
  f="$LOCALAPPDATA/Pub/Cache/hosted/pub.dev/$pkg/android/build.gradle"
  sed -i 's/compileSdk 34/compileSdk 36/g' "$f"
done
```

- [ ] **Step 3: Build Windows installer**

```bash
cd /c/zhiyue_build/app
flutter build windows --release
iscc windows\installer\zhiyue.iss
```

Expected: `build/installer/zhiyue-setup-1.9.1-alpha.exe`（~47MB）

- [ ] **Step 4: Copy artifacts to Desktop**

```bash
cp /c/zhiyue_build/app/build/app/outputs/flutter-apk/app-release.apk /c/Users/1/Desktop/zhiyue-1.9.1-alpha.apk
cp /c/zhiyue_build/app/build/installer/zhiyue-setup-1.9.1-alpha.exe /c/Users/1/Desktop/zhiyue-setup-1.9.1-alpha.exe
```

- [ ] **Step 5: Verify file size sanity**

```
ls -lh /c/Users/1/Desktop/zhiyue-1.9.1-alpha.apk
ls -lh /c/Users/1/Desktop/zhiyue-setup-1.9.1-alpha.exe
```

Expected: APK ~130MB, installer ~47MB. 严重偏差需排查。

---

## Task 11: Real-device smoke test (T19a — UX subset)

**Files:** None (manual test on physical Android device)

**Why:** v1.9.1-alpha 验收必须真机验证 UX-A/B/C 在真实硬件上工作。

### Smoke 步骤（spec §6.3 v1.9.1-alpha smoke）

```
1. adb install -r C:\Users\1\Desktop\zhiyue-1.9.1-alpha.apk
2. 启动 app → 进入 library
3. 打开任意已存在的书
   期望：进入 reader，chrome 可见（含 TOC / 排版 / AI 等按钮）  ← UX-B 默认显示
4. 不操作等待 3 秒
   期望：chrome 自动消失，只剩浮动书签 FAB                  ← UX-B auto-hide
5. 单 tap 屏幕中央
   期望：chrome 重新出现                                    ← UX-A toggle
6. 单 tap 屏幕中央
   期望：chrome 再次消失                                    ← UX-A 核心 bug 回归
7. 导入新书（library → 导入 → 选 epub）
8. 打开新书 → 检查 margin
   期望：左右边距明显紧凑（8px），文字宽度接近屏幕宽度     ← UX-C
9. 退出 reader → 重启 app → 重新打开新书
   期望：margin 仍为 compact（持久化生效）
10. 截图：
    - chrome 显示状态（步骤 3）
    - chrome 隐藏状态（步骤 4 后）
    - 新书紧凑 margin（步骤 8）
```

- [ ] **Step 1: Install APK on Android device**

```
adb install -r C:\Users\1\Desktop\zhiyue-1.9.1-alpha.apk
```

- [ ] **Step 2: Run smoke steps 1-9 above**

User runs manually on physical device, reports pass/fail per step.

- [ ] **Step 3: Capture 3 screenshots**

User screenshots and copies to `docs/screenshots/` with names:
- `v1.9.1-chrome-shown.png`
- `v1.9.1-chrome-hidden.png`
- `v1.9.1-margin-compact.png`

- [ ] **Step 4: Commit screenshots**

```bash
git add docs/screenshots/v1.9.1-*.png
git commit -m "docs: v1.9.1-alpha smoke screenshots"
```

### Smoke 失败处理

- 任一步骤 fail → 不打 tag → 修复后重测
- P1/P2 issue → 进 v1.9.2-alpha 或 v1.10.0-alpha（不阻塞 Part 2）

---

## Task 12: Tag + push v1.9.1-alpha

**Files:** None (git operations)

**Why:** smoke 全绿后发版。

- [ ] **Step 1: Tag**

```bash
git tag v1.9.1-alpha -m "v1.9.1-alpha: mobile UX hotfix (UX-A/B/C)"
```

- [ ] **Step 2: Push tag + commits**

```bash
git push origin master --tags
```

- [ ] **Step 3: Verify tag on remote**

```bash
git ls-remote origin refs/tags/v1.9.1-alpha
```

Expected: 输出包含 v1.9.1-alpha。

- [ ] **Step 4: Update scripts/create_gitee_releases.py**

In `scripts/create_gitee_releases.py`:

- Add `("v1.9.1-alpha", "智阅 v1.9.1-alpha", "release-notes-v1.9.1-alpha.md"),` to `RELEASES` list
- Add to `ATTACHMENTS` dict:

```python
"v1.9.1-alpha": [
    "C:/Users/1/Desktop/zhiyue-setup-1.9.1-alpha.exe",
    "C:/Users/1/Desktop/zhiyue-1.9.1-alpha.apk",
],
```

- [ ] **Step 5: Commit script update**

```bash
git add scripts/create_gitee_releases.py
git commit -m "chore(release): add v1.9.1-alpha to gitee release script"
git push origin master
```

- [ ] **Step 6: User decides when to upload to Gitee Release**

User: "等完善后再上传"（v1.9.0-alpha 时的策略延续）。当用户准备好时，运行：

```bash
GITEE_TOKEN=xxx python scripts/create_gitee_releases.py
```

(token 用户在终端 export，不进对话历史)

---

## Self-Review Notes

### Spec coverage

| Spec section | Tasks |
|---|---|
| §2.1 UX-A chrome tap-toggle | Task 5 |
| §2.2 UX-B auto-hide timer | Tasks 2, 3, 4, 6 |
| §2.3 UX-C mobile compact margin | Task 7 |
| §4.1 chrome 状态机 | Task 5 (toggle) + Task 6 (auto-hide) |
| §4.2 margin 数据流 | Task 7 |
| §5.1 UX-A 边界 case | Task 5 widget tests (5 用例覆盖全部) |
| §5.2 UX-B 边界 case | Task 6 widget tests (5 用例覆盖 lifecycle) |
| §5.3 UX-C 边界 case | Task 7 widget tests (5 用例覆盖 persisted/new/platform) |
| §6.2 新测试矩阵 | Tasks 2, 3, 5, 6, 7 共 ~20 个用例 |
| §6.3 v1.9.1 smoke 步骤 | Task 11 |
| §6.4 桌面回归 | Task 8 (analyze + full test) |
| §7.1 实施顺序 Day 1-2 | Tasks 1-12（顺序一致） |
| §9.1 v1.9.1 验收 checklist | Tasks 8 + 11 + 12 全覆盖 |

### Placeholder scan

- Task 5 widget test harness 标 "TODO 占位"，但提供了现有 test 文件参考路径（reader_body_test.dart），subagent 实施时读现有 harness 模式即可。这是参考已有 codebase 模式，不是 plan placeholder。
- Task 6 "如果复杂，先把 widget test 'scroll cancel' 标 skip"——这是 fallback 策略明确写在 plan 里，不是 placeholder。
- All code snippets are complete Dart code, no `// ...` omissions in implementation steps.

### Type consistency

- `PlatformInfo.isMobile` 在 Task 1 创建，Tasks 4, 5, 6, 7 全部引用 — 一致
- `ReaderUiController.hideChrome()` 在 Task 2 创建，Task 6 (auto-hide timer) 引用 — 一致
- `ReaderUiState.defaultsForPlatform()` 在 Task 3 创建，Task 4 引用 — 一致
- `PageMargin.compact` 在 Task 7 引用，与 spec §1.0 术语一致
- `_applyPersistedTypography` 在 Task 7 修改，与 spec §4.2 数据流一致

### Risks

- Task 5 widget test harness 可能复杂（reader_engine mock）。Subagent 实施时如果太复杂，简化为 minimum viable test（直接 pump Stack with Listener）。
- Task 6 fakeAsync API 在不同 Flutter 版本有差异。Subagent 实施时查 `flutter_test` 当前版本 API。
- Task 11 真机 smoke 依赖用户时间安排。Tag 可以延后，代码可先 ready。

---

## Plan complete

Plan covers Tasks 1-12, ~2 days estimated. Each task is bite-sized (15-60 min), TDD-driven, with frequent commits. Desktop stable anchor enforced in every task (PlatformInfo.isMobile guards).
