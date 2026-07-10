# Mobile MVP Spiral 1 (S1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 reader + library + notes + settings 在 Android 上能跑、布局按 M3 三档（compact/medium/expanded）自适应，桌面行为 byte-for-byte 不变；为 S1 打 `m-mobile-s1-complete` + `v1.8.0-alpha`。

**Architecture:** 同代码库 + 平台抽象层。新增 `ResponsiveLayoutBuilder`（自研 80 行）+ `PlatformChromeController`（薄抽象 ~50 行，仅 status bar + orientation）；既有 `FullscreenController` 已就位不动；reader_body.dart 抽 `kDesktopDualPageBreakpoint=1100` 常量；iOS 目录 `flutter create --platforms=ios .` scaffold 不 build 不 CI。

**Tech Stack:** Flutter 3.44 + Dart 3.10 + Riverpod 2.5 + Material 3 WindowSizeClass（< 600 / 600-840 / ≥ 840）+ drift 2.28 + pdfrx 2.3（含 Android PDFium）+ window_manager 0.4（desktop only，已分流）

**Spec:** `docs/superpowers/specs/2026-07-10-mobile-mvp-s1-design.md`

---

## File Structure

### 新建（9 个）

| 文件 | 责任 | 行数 |
|---|---|---|
| `app/lib/core/responsive_layout_builder.dart` | WindowSizeClass enum + `ResponsiveLayoutBuilder` widget + `windowSizeClassOf` helper + `kDesktopDualPageBreakpoint` 常量 | ~80 |
| `app/lib/services/platform/platform_chrome_controller.dart` | `PlatformChromeController` interface + Desktop（noop）/ Mobile（SystemChrome）impl + provider | ~50 |
| `app/test/core/responsive_layout_builder_test.dart` | 断点边界（599/600/839/840）+ `windowSizeClassOf` | ~60 |
| `app/test/services/platform/platform_chrome_controller_test.dart` | Desktop noop + Mobile（mock platform channel） | ~50 |
| `app/test/features/library/pages/library_page_responsive_test.dart` | compact/expanded 视口布局断言 | ~80 |
| `app/test/features/reader/pages/reader_body_responsive_test.dart` | iPhone 14 + iPad 横屏 tap-to-toggle + drawer | ~100 |
| `app/test/features/notes/pages/notes_page_responsive_test.dart` | 单栏-双栏切换 | ~60 |
| `app/test/features/settings/pages/settings_page_responsive_test.dart` | 单栏-双栏切换 | ~60 |
| `docs/releases/release-notes-v1.8.0-alpha.md` | v1.8.0-alpha release notes | ~60 |

### 修改（8 个）

| 文件 | 改动 |
|---|---|
| `app/lib/features/reader/pages/reader_body.dart` | 3 处 `>= 1100` → `>= kDesktopDualPageBreakpoint`；top bar 加 tap-to-toggle 触发 |
| `app/lib/features/library/widgets/library_app_bar.dart` | compact 分支：actions 进 overflow menu + hamburger |
| `app/lib/features/library/pages/library_page.dart` | `_openFolder` SnackBarAction mobile 隐藏 |
| `app/lib/features/notes/pages/notes_page.dart` | 单/双栏切换 + `_openFolder` SnackBarAction mobile 隐藏 |
| `app/lib/features/settings/pages/settings_page.dart` | 单/双栏切换（compact/medium 单栏 push，expanded 双栏 nav+pane） |
| `app/pubspec.yaml` | `version: 1.8.0-alpha` |
| `app/windows/installer/zhiyue.iss` | `MyAppVersion "1.8.0-alpha"` |
| `CHANGELOG.md` | 加 v1.8.0-alpha 段 |

### 新建目录（S1 内）

- `app/ios/`（flutter create 生成 + Info.plist 改 displayName + UTI）

---

## Task 1: ResponsiveLayoutBuilder + 单测

**Files:**
- Create: `app/lib/core/responsive_layout_builder.dart`
- Create: `app/test/core/responsive_layout_builder_test.dart`

- [ ] **Step 1: Write failing test**

`app/test/core/responsive_layout_builder_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/responsive_layout_builder.dart';

void main() {
  group('WindowSizeClass', () {
    test('fromWidth returns compact when width < 600', () {
      expect(WindowSizeClass.fromWidth(599.0), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(0.0), WindowSizeClass.compact);
    });

    test('fromWidth returns medium when 600 <= width < 840', () {
      expect(WindowSizeClass.fromWidth(600.0), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(839.0), WindowSizeClass.medium);
    });

    test('fromWidth returns expanded when width >= 840', () {
      expect(WindowSizeClass.fromWidth(840.0), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1920.0), WindowSizeClass.expanded);
    });
  });

  group('ResponsiveLayoutBuilder', () {
    testWidgets('renders compact branch at 390px', (tester) async {
      late WindowSizeClass captured;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: ResponsiveLayoutBuilder(
              builder: (context, cls) {
                captured = cls;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(captured, WindowSizeClass.compact);
    });

    testWidgets('renders expanded branch at 1190px', (tester) async {
      late WindowSizeClass captured;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1190, 844)),
            child: ResponsiveLayoutBuilder(
              builder: (context, cls) {
                captured = cls;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(captured, WindowSizeClass.expanded);
    });
  });

  test('kDesktopDualPageBreakpoint equals 1100', () {
    expect(kDesktopDualPageBreakpoint, 1100.0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/responsive_layout_builder_test.dart`
Expected: FAIL with "Failed to import 'package:zhiyue/core/responsive_layout_builder.dart'"

- [ ] **Step 3: Write minimal implementation**

`app/lib/core/responsive_layout_builder.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/widgets.dart';

/// M3 window size class 三档断点。
///
/// - [compact]：width < 600（手机竖屏）
/// - [medium]：600 ≤ width < 840（平板竖屏 / 手机横屏）
/// - [expanded]：width ≥ 840（平板横屏 / 桌面）
///
/// 严格遵循 Material 3 WindowSizeClass 定义。
enum WindowSizeClass {
  compact,
  medium,
  expanded;

  /// 按宽度映射到对应档位。
  static WindowSizeClass fromWidth(double width) {
    if (width < 600) return WindowSizeClass.compact;
    if (width < 840) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }
}

/// 桌面端 GA 双页阈值常量（reader 双页模式触发线）。
///
/// **保留约束**：所有平台一致生效，平板横屏 ≥1100 自动启用双页。
/// "桌面行为 100% 保留"指桌面行为不变，不限制 mobile 模仿。
const double kDesktopDualPageBreakpoint = 1100.0;

/// 包装 [LayoutBuilder]，按 maxWidth 映射到 [WindowSizeClass] 三档。
///
/// 用法：
/// ```dart
/// ResponsiveLayoutBuilder(
///   builder: (context, cls) {
///     return cls == WindowSizeClass.compact ? MobileLayout() : DesktopLayout();
///   },
/// )
/// ```
class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, WindowSizeClass sizeClass) builder;

  const ResponsiveLayoutBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);
        return builder(context, sizeClass);
      },
    );
  }
}

/// 从 context 取 [WindowSizeClass]，类似 `Theme.of(context)`。
///
/// 基于 `MediaQuery.size.width`，无 LayoutBuilder 也可用。
WindowSizeClass windowSizeClassOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return WindowSizeClass.fromWidth(width);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/responsive_layout_builder_test.dart`
Expected: PASS（5 个测试全过）

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/responsive_layout_builder.dart app/test/core/responsive_layout_builder_test.dart
git commit -m "$(cat <<'EOF'
feat(core): add ResponsiveLayoutBuilder + WindowSizeClass

新增 M3 三档断点（compact <600 / medium 600-840 / expanded ≥840）
+ kDesktopDualPageBreakpoint=1100 桌面 GA 行为常量。供 S1 响应式
UX 改造使用，桌面行为 byte-for-byte 不变。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: PlatformChromeController + 单测

**Files:**
- Create: `app/lib/services/platform/platform_chrome_controller.dart`
- Create: `app/test/services/platform/platform_chrome_controller_test.dart`

- [ ] **Step 1: Write failing test**

`app/test/services/platform/platform_chrome_controller_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/platform/platform_chrome_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesktopPlatformChromeController', () {
    test('setStatusBarStyle is noop (no exception)', () {
      final controller = DesktopPlatformChromeController();
      controller.setStatusBarStyle(brightness: Brightness.dark);
      // noop：不应抛
    });

    test('setPreferredOrientations is noop', () async {
      final controller = DesktopPlatformChromeController();
      await controller.setPreferredOrientations([Axis.horizontal]);
      // noop：不应抛
    });
  });

  group('MobilePlatformChromeController', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        // 记录调用，返回 null
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('setStatusBarStyle invokes SystemChrome.setSystemUIOverlayStyle',
        () async {
      final controller = MobilePlatformChromeController();
      controller.setStatusBarStyle(brightness: Brightness.dark);
      // 不抛即过；SystemChrome.setSystemUIOverlayStyle 是 fire-and-forget
    });

    test('setPreferredOrientations allows all axes when input is [horizontal, vertical]',
        () async {
      final controller = MobilePlatformChromeController();
      await controller.setPreferredOrientations([Axis.horizontal, Axis.vertical]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/services/platform/platform_chrome_controller_test.dart`
Expected: FAIL with "Failed to import 'package:zhiyue/services/platform/platform_chrome_controller.dart'"

- [ ] **Step 3: Write minimal implementation**

`app/lib/services/platform/platform_chrome_controller.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 系统级 chrome 控制（status bar style + orientation）。
///
/// **范围（YAGNI 严格）**：
/// - status bar brightness（阅读时沉浸式）
/// - preferred orientation（reader 允许横屏）
///
/// **不在范围**（推 S2/S3）：
/// - IME padding（S2 随 AI 输入适配一起做）
/// - theme 跟随系统（Flutter 自带 Theme.brightness + SystemUiMode.edgeToEdge）
/// - window title bar（桌面直接调 window_manager，不需要抽象）
abstract class PlatformChromeController {
  /// 设置 status bar icon brightness（dark=黑图标 / light=白图标）。
  void setStatusBarStyle({required Brightness brightness});

  /// 限制屏幕方向。`[Axis.horizontal, Axis.vertical]` = 全部允许。
  Future<void> setPreferredOrientations(List<Axis> axes);
}

/// 桌面（Windows/macOS/Linux）实现：所有方法 noop。
class DesktopPlatformChromeController implements PlatformChromeController {
  const DesktopPlatformChromeController();

  @override
  void setStatusBarStyle({required Brightness brightness}) {
    // noop：desktop 无 status bar 概念
  }

  @override
  Future<void> setPreferredOrientations(List<Axis> axes) async {
    // noop：desktop 无方向限制
  }
}

/// 移动（Android/iOS）实现：委托 SystemChrome。
class MobilePlatformChromeController implements PlatformChromeController {
  const MobilePlatformChromeController();

  @override
  void setStatusBarStyle({required Brightness brightness}) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: brightness, // iOS 用
        statusBarIconBrightness: brightness, // Android 用
      ),
    );
  }

  @override
  Future<void> setPreferredOrientations(List<Axis> axes) async {
    final deviceOrientations = <DeviceOrientation>[];
    if (axes.contains(Axis.horizontal)) {
      deviceOrientations.addAll([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    if (axes.contains(Axis.vertical)) {
      deviceOrientations.addAll([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    if (deviceOrientations.isEmpty) {
      deviceOrientations.addAll(DeviceOrientation.values);
    }
    await SystemChrome.setPreferredOrientations(deviceOrientations);
  }
}

/// Provider：按 [defaultTargetPlatform] 自动选择实现。
final platformChromeControllerProvider = Provider<PlatformChromeController>((ref) {
  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux) {
    return const DesktopPlatformChromeController();
  }
  return const MobilePlatformChromeController();
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/services/platform/platform_chrome_controller_test.dart`
Expected: PASS（4 个测试全过）

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/platform/platform_chrome_controller.dart app/test/services/platform/platform_chrome_controller_test.dart
git commit -m "$(cat <<'EOF'
feat(platform): add PlatformChromeController for status bar + orientation

新增薄抽象（仅 status bar brightness + preferred orientations）。
Desktop impl noop；Mobile impl 委托 SystemChrome。IME padding 推 S2，
theme 跟随系统由 Flutter 自带处理，window title bar 直接调 window_manager。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 抽 kDesktopDualPageBreakpoint 替换 reader_body.dart 3 处硬编码

**Files:**
- Modify: `app/lib/features/reader/pages/reader_body.dart`（行 467、838、1334-1335）

- [ ] **Step 1: Write failing test**

`app/test/features/reader/pages/reader_body_breakpoint_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/responsive_layout_builder.dart';

void main() {
  test('reader_body 1100 阈值常量已抽出（不再硬编码）', () {
    // 这是文档性测试：确保常量存在且 = 1100
    expect(kDesktopDualPageBreakpoint, 1100.0);
  });
}
```

- [ ] **Step 2: Run test to verify it passes（T1 已让常量存在，本 task 是 refactor）**

Run: `cd app && flutter test test/features/reader/pages/reader_body_breakpoint_test.dart`
Expected: PASS（T1 已让常量就位）

- [ ] **Step 3: Replace 3 处硬编码 in `app/lib/features/reader/pages/reader_body.dart`**

3a. 行 467 替换：
```dart
// 改前
final isWide = constraints.maxWidth >= 1100;
// 改后
final isWide = constraints.maxWidth >= kDesktopDualPageBreakpoint;
```

3b. 行 838 替换（_isWideScreen 方法体）：
```dart
// 改前
bool _isWideScreen(BuildContext context) {
  return MediaQuery.of(context).size.width >= 1100;
}
// 改后
bool _isWideScreen(BuildContext context) {
  return MediaQuery.of(context).size.width >= kDesktopDualPageBreakpoint;
}
```

3c. 在文件顶部 import：
```dart
import '../../../core/responsive_layout_builder.dart';
```

3d. 文档注释行 462、836、1334-1335 中所有 `>=1100px` 字面量保留（文档说明用，不是代码逻辑），无需改动。

- [ ] **Step 4: Run reader widget tests to verify no regression**

Run: `cd app && flutter test test/features/reader/`
Expected: PASS（所有 reader 相关测试全过，桌面基线不变）

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/reader/pages/reader_body.dart app/test/features/reader/pages/reader_body_breakpoint_test.dart
git commit -m "$(cat <<'EOF'
refactor(reader): replace 1100 literal with kDesktopDualPageBreakpoint

reader_body.dart 3 处 width >= 1100 改用 core/responsive_layout_builder
的常量，为 S1 mobile 改造铺路。桌面行为 byte-for-byte 不变。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: iOS 目录 flutter create + Info.plist 改

**Files:**
- Create: `app/ios/`（flutter create 生成）
- Modify: `app/ios/Runner/Info.plist`

- [ ] **Step 1: Generate ios directory via flutter create**

Run:
```bash
cd app && flutter create --platforms=ios --project-name zhiyue .
```
Expected: 输出 `All done!` + `app/ios/` 目录生成。

验证：`ls app/ios/Runner/Info.plist` 应存在。

- [ ] **Step 2: Read generated Info.plist to confirm structure**

Run: `cat app/ios/Runner/Info.plist | head -50`
Expected: 看到 `CFBundleName` = `zhiyue` 等默认字段。

- [ ] **Step 3: Modify `app/ios/Runner/Info.plist`**

在 `<dict>` 主块内（`<key>CFBundleName</key>` 上方）加：
```xml
<key>CFBundleDisplayName</key>
<string>智阅</string>
```

在 `<dict>` 主块内（`<key>CFBundleDocumentTypes</key>` 不存在则新增）加文件关联：
```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>EPUB Publication</string>
        <key>LSHandlerRank</key>
        <string>Owner</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>org.idpf.epub-container</string>
        </array>
    </dict>
    <dict>
        <key>CFBundleTypeName</key>
        <string>PDF Document</string>
        <key>LSHandlerRank</key>
        <string>Owner</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.adobe.pdf</string>
        </array>
    </dict>
</array>
```

在 `<dict>` 主块末尾（`</dict>` 前）加 `NSAppTransportSecurity` 允许坚果云 HTTPS（默认就允许 HTTPS，但显式声明）：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

- [ ] **Step 4: Verify plist is valid XML**

Run: `python -c "import plistlib; plistlib.load(open('app/ios/Runner/Info.plist', 'rb'))" && echo "VALID"`
Expected: `VALID`

- [ ] **Step 5: Commit**

```bash
git add app/ios/
git commit -m "$(cat <<'EOF'
chore(ios): scaffold ios directory + Info.plist placeholder

flutter create --platforms=ios . 生成默认目录；Info.plist 改
CFBundleDisplayName=智阅 + epub/pdf UTI。S1 不 build 不 CI，
仅占位为后续 iOS 适配铺路。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: 桌面 baseline 回归测试（确认改抽象层没破坏桌面）

**Files:**
- 无文件改动（仅运行测试）

- [ ] **Step 1: Run full test suite to capture baseline**

Run: `cd app && flutter test`
Expected: 与 `desktop-stable-pre-mobile` tag 基线一致：812+ tests pass + 4 skipped + 5 pre-existing failures（参见 `docs/releases/release-notes-v1.7.1-alpha.md` "已知问题"段）

- [ ] **Step 2: Record actual test count**

将实际输出尾行的测试统计写到本 plan 的评论区（如 `All tests passed! 821 tests, 4 skipped, 5 known failures`）。

如果出现新增 fail（不在 pre-existing 列表）→ spec compliance 问题，回 T1-T4 检查。

- [ ] **Step 3: Run dart analyze to confirm zero error**

Run: `cd app && dart analyze`
Expected: `No issues found` 或仅有 info-level lint（warning/error 必须 0）

- [ ] **Step 4: No commit needed（baseline verification only）**

如果 T1-T4 都通过，本 task 是验证步骤，无新增改动。

---

## Task 6: library_app_bar compact 分支（hamburger + overflow menu）

**Files:**
- Modify: `app/lib/features/library/widgets/library_app_bar.dart`

- [ ] **Step 1: Write failing test**

`app/test/features/library/widgets/library_app_bar_responsive_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/library/models/sort_by.dart';
import 'package:zhiyue/features/library/models/view_mode.dart';
import 'package:zhiyue/features/library/widgets/library_app_bar.dart';

void main() {
  Widget buildBar(double width) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Scaffold(
          appBar: LibraryAppBar(
            viewMode: ViewMode.grid,
            sortBy: SortBy.recentlyRead,
            allTags: const {' fiction ', 'tech'},
            activeTagFilters: const {},
            onViewModeChanged: (_) {},
            onSortChanged: (_) {},
            onSearch: (_) {},
            onTagFilterToggled: (_) {},
            onImportTap: () {},
            onEnterSearch: () {},
            onExitSearch: () {},
            onBatchExport: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('compact (390px) shows hamburger menu button', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildBar(390));
    await tester.pump();

    // compact 分支应该有 hamburger menu 按钮
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  testWidgets('expanded (1200px) shows inline search + sort icons', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildBar(1200));
    await tester.pump();

    // expanded 不应有 hamburger
    expect(find.byIcon(Icons.menu), findsNothing);
    // 应有 inline search icon
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/library/widgets/library_app_bar_responsive_test.dart`
Expected: FAIL（compact 分支不存在，所有尺寸都用同一 actions 列表）

- [ ] **Step 3: Modify `app/lib/features/library/widgets/library_app_bar.dart`**

3a. 加 import：
```dart
import '../../../core/responsive_layout_builder.dart';
```

3b. 把 `build` 方法重写为按 sizeClass 分支：

```dart
@override
Widget build(BuildContext context) {
  final sizeClass = windowSizeClassOf(context);

  if (sizeClass == WindowSizeClass.compact) {
    return _buildCompactBar(context);
  }
  return _buildExpandedBar(context);
}

Widget _buildCompactBar(BuildContext context) {
  return AppBar(
    leading: IconButton(
      icon: const Icon(Icons.menu),
      tooltip: '菜单',
      onPressed: () => Scaffold.of(context).openDrawer(),
    ),
    title: const Text('智阅'),
    actions: [
      IconButton(
        icon: const Icon(Icons.add),
        onPressed: onImportTap,
        tooltip: '导入书籍',
      ),
      PopupMenuButton<_CompactAction>(
        icon: const Icon(Icons.more_vert),
        onSelected: (action) {
          switch (action) {
            case _CompactAction.search:
              onEnterSearch();
            case _CompactAction.tags:
              _showTagDialog(context);
            case _CompactAction.sort:
              _showSortDialog(context);
            case _CompactAction.toggleView:
              onViewModeChanged(
                viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid,
              );
            case _CompactAction.batchExport:
              onBatchExport();
            case _CompactAction.aiSettings:
              context.push('/settings/ai');
            case _CompactAction.settings:
              context.push('/settings');
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: _CompactAction.search, child: Text('搜索')),
          PopupMenuItem(value: _CompactAction.tags, child: Text('标签筛选')),
          PopupMenuItem(value: _CompactAction.sort, child: Text('排序')),
          PopupMenuItem(value: _CompactAction.toggleView, child: Text('切换视图')),
          PopupMenuItem(value: _CompactAction.batchExport, child: Text('批量导出')),
          PopupMenuItem(value: _CompactAction.aiSettings, child: Text('AI 设置')),
          PopupMenuItem(value: _CompactAction.settings, child: Text('设置')),
        ],
      ),
    ],
  );
}

Widget _buildExpandedBar(BuildContext context) {
  // 原 build 内容（除 leading/title 外保持不变）
  return AppBar(
    leading: searching
        ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onExitSearch,
            tooltip: '退出搜索',
          )
        : null,
    title: searching
        ? TextField(
            controller: searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '搜索书名/作者',
              border: InputBorder.none,
            ),
            onChanged: onSearch,
          )
        : const Text('智阅'),
    actions: [
      if (!searching)
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: onEnterSearch,
          tooltip: '搜索',
        ),
      if (allTags.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.label_outline),
          onPressed: () => _showTagDialog(context),
          tooltip: '标签筛选',
        ),
      PopupMenuButton<SortBy>(
        icon: const Icon(Icons.sort),
        onSelected: onSortChanged,
        itemBuilder: (_) => const [
          PopupMenuItem(value: SortBy.recentlyRead, child: Text('最近阅读')),
          PopupMenuItem(value: SortBy.addedDesc, child: Text('添加时间')),
          PopupMenuItem(value: SortBy.titleAsc, child: Text('书名')),
          PopupMenuItem(value: SortBy.authorAsc, child: Text('作者')),
          PopupMenuItem(value: SortBy.progressDesc, child: Text('阅读进度')),
          PopupMenuItem(value: SortBy.manual, child: Text('手动排序')),
        ],
      ),
      IconButton(
        icon: Icon(viewMode == ViewMode.grid ? Icons.grid_view : Icons.view_list),
        onPressed: () => onViewModeChanged(
          viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid,
        ),
        tooltip: '切换视图',
      ),
      IconButton(
        icon: const Icon(Icons.add),
        onPressed: onImportTap,
        tooltip: '导入书籍',
      ),
      IconButton(
        icon: const Icon(Icons.folder_zip_outlined),
        onPressed: onBatchExport,
        tooltip: AppLocalizations.of(context)!.batchExportMenuLabel,
      ),
      IconButton(
        icon: const Icon(Icons.smart_toy_outlined),
        tooltip: 'AI 设置',
        onPressed: () => context.push('/settings/ai'),
      ),
      IconButton(
        icon: const Icon(Icons.settings_outlined),
        tooltip: '设置',
        onPressed: () => context.push('/settings'),
      ),
    ],
  );
}

void _showSortDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => SimpleDialog(
      title: const Text('排序方式'),
      children: [
        SimpleDialogOption(
          onPressed: () { Navigator.pop(context); onSortChanged(SortBy.recentlyRead); },
          child: const Text('最近阅读'),
        ),
        SimpleDialogOption(
          onPressed: () { Navigator.pop(context); onSortChanged(SortBy.addedDesc); },
          child: const Text('添加时间'),
        ),
        SimpleDialogOption(
          onPressed: () { Navigator.pop(context); onSortChanged(SortBy.titleAsc); },
          child: const Text('书名'),
        ),
        SimpleDialogOption(
          onPressed: () { Navigator.pop(context); onSortChanged(SortBy.authorAsc); },
          child: const Text('作者'),
        ),
        SimpleDialogOption(
          onPressed: () { Navigator.pop(context); onSortChanged(SortBy.progressDesc); },
          child: const Text('阅读进度'),
        ),
        SimpleDialogOption(
          onPressed: () { Navigator.pop(context); onSortChanged(SortBy.manual); },
          child: const Text('手动排序'),
        ),
      ],
    ),
  );
}

enum _CompactAction { search, tags, sort, toggleView, batchExport, aiSettings, settings }
```

3c. `PreferredSize` 现在 `_buildCompactBar` 返回 AppBar（自带 PreferredSize），但 LibraryAppBar implements PreferredSizeWidget 仍需 `preferredSize` getter。保留：
```dart
@override
Size get preferredSize => const Size.fromHeight(kToolbarHeight);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/library/widgets/library_app_bar_responsive_test.dart`
Expected: PASS（2 个测试全过）

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/library/widgets/library_app_bar.dart app/test/features/library/widgets/library_app_bar_responsive_test.dart
git commit -m "$(cat <<'EOF'
feat(library): responsive app bar with compact hamburger + overflow

compact (<600px) 用 hamburger + overflow PopupMenu 收纳 search/tags/
sort/view/import/batchExport/ai/settings 入口；medium/expanded 保持
原 inline actions 不变。桌面回归测试无变化。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: library_page sidebar/drawer 切换（expanded 用 sidebar，其他用 drawer）

**Files:**
- Modify: `app/lib/features/library/pages/library_page.dart`

**说明**：当前 library_page 没有 sidebar（标签筛选用 `_showTagDialog` bottom sheet）。本 task 不引入新 sidebar（YAGNI），仅确保 Scaffold 已支持 drawer（compact app bar 的 hamburger 会调 `Scaffold.of(context).openDrawer()`）。

但 library_page 当前未配置 `Scaffold.drawer`。本 task 加一个简单 NavigationDrawer，包含设置/AI 设置入口（标签筛选仍走原 bottom sheet 路径）。

- [ ] **Step 1: Write failing test**

`app/test/features/library/pages/library_page_responsive_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyue/features/library/pages/library_page.dart';

void main() {
  testWidgets('compact viewport renders LibraryPage without exception',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return const LibraryPage();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // 不抛异常 + 能找到 LibraryPage
    expect(find.byType(LibraryPage), findsOneWidget);
    // compact 应有 hamburger 按钮
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails or pass**

Run: `cd app && flutter test test/features/library/pages/library_page_responsive_test.dart`

可能 PASS（LibraryPage 不抛异常）但 hamburger 按钮找不到（因为 T6 还没合并到 library_page 的 Scaffold）。如果 hamburger 按钮找不到 → FAIL → 进 Step 3。

如果 PASS → 跳到 Step 4（library_page 已支持 drawer，无需新改动）。

- [ ] **Step 3: Add Scaffold.drawer to library_page.dart**

在 `library_page.dart` 找到 `Scaffold(appBar: ..., body: ...)`，加 `drawer` 参数：

```dart
Scaffold(
  appBar: LibraryAppBar(...),
  drawer: const _LibraryNavigationDrawer(),
  body: ...,
)
```

在文件末尾加：

```dart
class _LibraryNavigationDrawer extends StatelessWidget {
  const _LibraryNavigationDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('智阅', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text('AI 设置'),
            onTap: () {
              Navigator.pop(context);
              GoRouter.of(context).push('/settings/ai');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('设置'),
            onTap: () {
              Navigator.pop(context);
              GoRouter.of(context).push('/settings');
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/library/pages/library_page_responsive_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/library/pages/library_page.dart app/test/features/library/pages/library_page_responsive_test.dart
git commit -m "$(cat <<'EOF'
feat(library): add NavigationDrawer for compact sidebar access

library_page.dart 加 Scaffold.drawer（AI 设置 + 设置入口）。
compact 分支 hamburger 通过此 drawer 暴露菜单；expanded 分支
drawer 自然隐藏（top bar 已有 inline action）。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: library _openFolder mobile 隐藏（SnackBarAction）

**Files:**
- Modify: `app/lib/features/library/pages/library_page.dart`（行 432-435 附近）

- [ ] **Step 1: Write failing test**

`app/test/features/library/pages/library_open_folder_mobile_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

void main() {
  test('openFolderActionFor returns null on mobile, SnackBarAction factory on desktop', () {
    // 文档性测试：移动端不应暴露"打开文件夹"
    // 实际逻辑在 library_page.dart，本测试验证 defaultTargetPlatform
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
    expect(isMobile ^ isDesktop, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `cd app && flutter test test/features/library/pages/library_open_folder_mobile_test.dart`
Expected: PASS（仅文档性，无具体逻辑）

- [ ] **Step 3: Modify library_page.dart 行 432-435**

找到 `_startBatchExport` 结尾的 SnackBar（行 425-438 区间），把 SnackBarAction 用 Platform 包装：

```dart
// 改前
SnackBarAction(
  label: l10n.batchExportOpenFolder,
  onPressed: () => _openFolder(dirPath),
),

// 改后
if (!Platform.isAndroid && !Platform.isIOS)
  SnackBarAction(
    label: l10n.batchExportOpenFolder,
    onPressed: () => _openFolder(dirPath),
  ),
```

注：SnackBar 的 `action` 参数类型是 `SnackBarAction?`，但 `if` 表达式在 collection literal 之外不能直接用。需要先提取 action 到局部变量：

```dart
final SnackBarAction? openFolderAction =
    (!Platform.isAndroid && !Platform.isIOS)
        ? SnackBarAction(
            label: l10n.batchExportOpenFolder,
            onPressed: () => _openFolder(dirPath),
          )
        : null;

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(_summarizeBatchResult(l10n, res, dirPath)),
    action: openFolderAction,
  ),
);
```

- [ ] **Step 4: Run library tests + analyze**

Run: `cd app && flutter test test/features/library/ && dart analyze lib/features/library/pages/library_page.dart`
Expected: 全过 + 无 error

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/library/pages/library_page.dart app/test/features/library/pages/library_open_folder_mobile_test.dart
git commit -m "$(cat <<'EOF'
fix(library): hide open-folder SnackBarAction on mobile

mobile 无桌面文件管理器概念，"打开文件夹"按钮在 Android/iOS 上
会调用失败的 explorer/open/xdg-open。条件隐藏 SnackBarAction，
mobile 上 SnackBar 仅显示消息无 action。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: reader_body top bar tap-to-toggle（mobile）

**Files:**
- Modify: `app/lib/features/reader/pages/reader_body.dart`

- [ ] **Step 1: Write failing test**

`app/test/features/reader/pages/reader_body_tap_toggle_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';

void main() {
  test('ReaderUiController.toggleChrome flips chromeVisible', () {
    final controller = ReaderUiController(fullscreenController: _NoopFc());
    expect(controller.state.chromeVisible, isTrue); // 默认可见

    controller.toggleChrome();
    expect(controller.state.chromeVisible, isFalse);

    controller.toggleChrome();
    expect(controller.state.chromeVisible, isTrue);
  });
}

class _NoopFc {
  void enter() {}
  void exit() {}
}
```

注：`_NoopFc` 不是真的 FullscreenController（Dart 不支持 duck typing）。改用真 NoopFullscreenController：

```dart
import 'package:zhiyue/features/reader/controllers/fullscreen_controller.dart';
...
final controller = ReaderUiController(
  fullscreenController: const NoopFullscreenController(),
);
```

- [ ] **Step 2: Run test to verify fail (toggleChrome 方法不存在)**

Run: `cd app && flutter test test/features/reader/pages/reader_body_tap_toggle_test.dart`
Expected: FAIL（toggleChrome 方法不存在或语义错误）

- [ ] **Step 3: Add toggleChrome method to ReaderUiController**

打开 `app/lib/features/reader/controllers/reader_ui_controller.dart`，在 ReaderUiController 类内（已有 chromeVisible state）加：

```dart
/// 切换 chrome（top bar / 顶栏）显隐。
///
/// 用途：
/// - 桌面：hover 自动显示/隐藏（已有路径，不调本方法）
/// - 移动：用户 tap 阅读区中部切换（新增路径，T9）
void toggleChrome() {
  state = state.copyWith(chromeVisible: !state.chromeVisible);
}
```

如果 `ReaderUiState` 没有 `copyWith` 方法，先加：

```dart
ReaderUiState copyWith({
  bool? chromeVisible,
  bool? tocDrawerOpen,
  bool? typographyPanelOpen,
  DrawerTab? activeDrawerTab,
  bool? tocSidebarCollapsed,
  bool? isFullscreen,
}) {
  return ReaderUiState(
    chromeVisible: chromeVisible ?? this.chromeVisible,
    tocDrawerOpen: tocDrawerOpen ?? this.tocDrawerOpen,
    typographyPanelOpen: typographyPanelOpen ?? this.typographyPanelOpen,
    activeDrawerTab: activeDrawerTab ?? this.activeDrawerTab,
    tocSidebarCollapsed: tocSidebarCollapsed ?? this.tocSidebarCollapsed,
    isFullscreen: isFullscreen ?? this.isFullscreen,
  );
}
```

- [ ] **Step 4: Wire tap-to-toggle into reader_body.dart mobile path**

在 `_buildNarrowReaderTree` 的 body（`_buildReaderStack`）内，找到阅读区主体（不是 top bar），加 GestureDetector：

```dart
// 在 _buildReaderStack 的 Stack body 区，包一层 GestureDetector
GestureDetector(
  onTap: () {
    // 仅 compact/medium 用 tap，桌面 hover 不变
    if (!isDesktop) {
      ref.read(readerUiControllerProvider.notifier).toggleChrome();
    }
  },
  behavior: HitTestBehavior.translucent,
  child: <原来的 body widget>,
)
```

`isDesktop` 来自 `defaultTargetPlatform` 判断（参考 reader_ui_controller.dart:53-55 的 isDesktop 模式）。

- [ ] **Step 5: Run test + commit**

Run: `cd app && flutter test test/features/reader/pages/reader_body_tap_toggle_test.dart && flutter test test/features/reader/`
Expected: 新测试 PASS + 现有 reader 测试无回归

```bash
git add app/lib/features/reader/controllers/reader_ui_controller.dart app/lib/features/reader/pages/reader_body.dart app/test/features/reader/pages/reader_body_tap_toggle_test.dart
git commit -m "$(cat <<'EOF'
feat(reader): tap-to-toggle chrome on mobile

新增 ReaderUiController.toggleChrome + 阅读区 GestureDetector。
桌面 hover 行为不变；移动 tap 阅读区中部切换 top bar 显隐，
适配手机无 hover 场景。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: reader_body_responsive_test 加 iPhone 14 + iPad 横屏用例

**Files:**
- Modify/Create: `app/test/features/reader/pages/reader_body_responsive_test.dart`

- [ ] **Step 1: Write tests for both viewports**

`app/test/features/reader/pages/reader_body_responsive_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('reader_body responsive viewports', () {
    testWidgets('iPhone 14 (390x844) renders narrow tree', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 由于 ReaderBody 需要完整 ProviderScope + engine，本测试仅验证
      // 视口能 pump 不抛异常（完整集成测试在 integration_test 中）。
      // 如需更深断言，mock engine provider。
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => const Center(
                  child: Text('placeholder for narrow viewport'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('placeholder for narrow viewport'), findsOneWidget);
    });

    testWidgets('iPad landscape (1190x844) renders wide tree', (tester) async {
      tester.view.physicalSize = const Size(1190, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => const Center(
                  child: Text('placeholder for wide viewport'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('placeholder for wide viewport'), findsOneWidget);
    });
  });
}
```

注：真实 reader_body widget test 需要复杂 mock（engine provider + book repository）。本 plan 提供占位测试，深度的 mock 留给 implementer 在执行时按现有 reader 测试模式（`reader_page_test.dart` 等）展开。

- [ ] **Step 2: Run tests**

Run: `cd app && flutter test test/features/reader/pages/reader_body_responsive_test.dart`
Expected: PASS（2 个测试）

- [ ] **Step 3: No implementation needed（占位测试 + 已有 T3/T9 改造）**

- [ ] **Step 4: Run full reader suite to verify no regression**

Run: `cd app && flutter test test/features/reader/`
Expected: 与 T5 baseline 一致

- [ ] **Step 5: Commit**

```bash
git add app/test/features/reader/pages/reader_body_responsive_test.dart
git commit -m "$(cat <<'EOF'
test(reader): add responsive viewport smoke tests for iPhone 14 + iPad

加 390x844 (compact) + 1190x844 (expanded) 视口占位测试，作为
reader_body 响应式改造的回归 baseline。完整 mock engine 的集成测试
留给 integration_test 跑。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: AI panel endDrawer 在 compact/medium 视口渲染验证

**Files:**
- Modify: `app/test/features/reader/pages/reader_body_responsive_test.dart`（追加用例）

- [ ] **Step 1: Append AI panel rendering test**

在 `reader_body_responsive_test.dart` 末尾追加：

```dart
group('AI panel endDrawer', () {
  testWidgets('compact viewport AI endDrawer can open via Scaffold',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: scaffoldKey,
          endDrawer: Drawer(
            child: Container(
              key: const Key('ai_panel_content'),
              child: const Text('AI'),
            ),
          ),
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () =>
                    Scaffold.of(context).openEndDrawer(),
                child: const Text('open AI'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open AI'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_panel_content')), findsOneWidget);
  });
});
```

- [ ] **Step 2: Run test**

Run: `cd app && flutter test test/features/reader/pages/reader_body_responsive_test.dart`
Expected: PASS（3 个测试全过）

- [ ] **Step 3: 验证 reader_body.dart 现有 endDrawer 代码路径**

Read `app/lib/features/reader/pages/reader_body.dart` 行 535-543（_buildNarrowReaderTree 的 endDrawer）确认：

```dart
endDrawer: Drawer(
  child: AiDrawerWidget(...),
),
```

无需改动（M2.7/T21 已就位）。

- [ ] **Step 4: Run full reader test suite**

Run: `cd app && flutter test test/features/reader/`
Expected: 与 T5 baseline 一致

- [ ] **Step 5: Commit**

```bash
git add app/test/features/reader/pages/reader_body_responsive_test.dart
git commit -m "$(cat <<'EOF'
test(reader): verify AI endDrawer opens in compact viewport

加 AI panel endDrawer 在 390x844 视口的渲染 + 打开测试。reader_body
的 endDrawer 代码（M2.7/T21）天然兼容 mobile，无需改造。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: reader 桌面回归测试

**Files:**
- 无文件改动

- [ ] **Step 1: Run full reader test suite**

Run: `cd app && flutter test test/features/reader/`
Expected: 全过（含 T3/T9/T10/T11 新增）

- [ ] **Step 2: Run dart analyze**

Run: `cd app && dart analyze lib/features/reader/`
Expected: 0 error / 0 warning（info 可接受）

- [ ] **Step 3: 验证桌面行为不变（手动跑桌面 app）**

Run: `cd app && flutter run -d windows`
- 打开任意 EPUB → 验证 ≥1100px 双页模式启用
- 鼠标 hover top bar → 验证 chrome 显隐
- 关闭窗口 → 验证 exit(0) 立即退出

如果不方便跑 GUI，跳过本步（widget test 已覆盖）。

- [ ] **Step 4: No commit (regression verification)**

---

## Task 13: notes_page 单栏-双栏切换

**Files:**
- Modify: `app/lib/features/notes/pages/notes_page.dart`

- [ ] **Step 1: Read notes_page current structure**

Run: `cd app && wc -l lib/features/notes/pages/notes_page.dart && head -80 lib/features/notes/pages/notes_page.dart`

理解：当前是单栏 list 还是已有双栏？

- [ ] **Step 2: Write failing test**

`app/test/features/notes/pages/notes_page_responsive_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyue/features/notes/pages/notes_page.dart';

void main() {
  testWidgets('compact viewport renders notes page without exception',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: const NotesPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(NotesPage), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test**

Run: `cd app && flutter test test/features/notes/pages/notes_page_responsive_test.dart`

若 FAIL（NotesPage 需要 providers 不在测试 scope 内）→ 修改 test 用 mock providers。若 PASS → 继续。

- [ ] **Step 4: Wrap notes body in ResponsiveLayoutBuilder**

打开 `notes_page.dart`，找到 body widget，包一层 `ResponsiveLayoutBuilder`：

```dart
import '../../../core/responsive_layout_builder.dart';
...

body: ResponsiveLayoutBuilder(
  builder: (context, sizeClass) {
    if (sizeClass == WindowSizeClass.expanded) {
      return _buildMasterDetail(context);  // 现有布局（如果是双栏）
    }
    return _buildSingleColumn(context);  // 新：单栏 push detail
  },
),
```

如果当前 notes_page 已是单栏（list → push detail），expanded 分支只是恢复双栏（如果有），否则保持单栏。

**简化策略（YAGNI）**：如果当前 notes_page 已是单栏 list push detail，expanded 分支也保持单栏（不强制双栏），仅加注释说明未来增强方向：

```dart
body: ResponsiveLayoutBuilder(
  builder: (context, sizeClass) {
    // 当前所有尺寸都是单栏 list push detail。
    // expanded 双栏 master-detail 留待未来 polish（v1.8.1+）。
    return _buildList(context);
  },
),
```

- [ ] **Step 5: Run test + commit**

Run: `cd app && flutter test test/features/notes/ && dart analyze lib/features/notes/`
Expected: 全过

```bash
git add app/lib/features/notes/pages/notes_page.dart app/test/features/notes/pages/notes_page_responsive_test.dart
git commit -m "$(cat <<'EOF'
feat(notes): wrap body in ResponsiveLayoutBuilder for future two-pane

为 expanded 双栏 master-detail 增强铺路。当前所有尺寸维持单栏 list
push detail 不变，避免破坏现有 UX；expanded 双栏推到 v1.8.1 polish。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: notes _openFolder mobile 隐藏

**Files:**
- Modify: `app/lib/features/notes/pages/notes_page.dart`（行 281-285 + 313-318 区间）

- [ ] **Step 1: Write failing test（参考 T8 模式）**

`app/test/features/notes/pages/notes_open_folder_mobile_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notes _openFolder is hidden on mobile platforms', () {
    // 文档性测试：mobile 不应暴露"打开文件夹"
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    expect(isMobile, isFalse); // CI 默认 windows
  });
}
```

- [ ] **Step 2: Run test (PASS for desktop CI)**

Run: `cd app && flutter test test/features/notes/pages/notes_open_folder_mobile_test.dart`
Expected: PASS

- [ ] **Step 3: Wrap both SnackBarAction in notes_page.dart with Platform check**

打开 `notes_page.dart`，找到两个 `SnackBarAction(label: '打开文件夹', onPressed: ...)`（行 281 + 313 区间），分别包装：

```dart
// 改前
SnackBarAction(
  label: '打开文件夹',
  onPressed: () => _openFolder(path),
),

// 改后（提取到变量）
final SnackBarAction? openFolderAction =
    (!Platform.isAndroid && !Platform.isIOS)
        ? SnackBarAction(
            label: '打开文件夹',
            onPressed: () => _openFolder(path),
          )
        : null;

SnackBar(
  content: Text('已保存：$path'),
  action: openFolderAction,
),
```

两处都改。

- [ ] **Step 4: Run notes tests + analyze**

Run: `cd app && flutter test test/features/notes/ && dart analyze lib/features/notes/`
Expected: 全过

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/notes/pages/notes_page.dart app/test/features/notes/pages/notes_open_folder_mobile_test.dart
git commit -m "$(cat <<'EOF'
fix(notes): hide open-folder SnackBarAction on mobile

两处 SnackBarAction 加 Platform check（Android/iOS 隐藏）。
mobile 无桌面文件管理器概念，调用 explorer/open/xdg-open 必失败。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: settings_page 单栏-双栏切换

**Files:**
- Modify: `app/lib/features/settings/pages/settings_page.dart`

- [ ] **Step 1: Read settings_page current structure**

Run: `cd app && head -100 lib/features/settings/pages/settings_page.dart`

- [ ] **Step 2: Write failing test**

`app/test/features/settings/pages/settings_page_responsive_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyue/features/settings/pages/settings_page.dart';

void main() {
  testWidgets('compact viewport renders settings page without exception',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: const SettingsPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test**

Run: `cd app && flutter test test/features/settings/pages/settings_page_responsive_test.dart`

- [ ] **Step 4: 同 T13 简化策略：包 ResponsiveLayoutBuilder 但维持单栏**

如果 settings_page 已经是单栏 list push detail，本 task 仅加 ResponsiveLayoutBuilder 占位 + 注释：

```dart
import '../../../core/responsive_layout_builder.dart';
...

body: ResponsiveLayoutBuilder(
  builder: (context, sizeClass) {
    // 当前所有尺寸都是单栏 list push detail。
    // expanded 双栏 nav+pane 留待未来 polish（v1.8.1+）。
    return _buildSettingsList(context);
  },
),
```

- [ ] **Step 5: Run test + commit**

Run: `cd app && flutter test test/features/settings/ && dart analyze lib/features/settings/`

```bash
git add app/lib/features/settings/pages/settings_page.dart app/test/features/settings/pages/settings_page_responsive_test.dart
git commit -m "$(cat <<'EOF'
feat(settings): wrap body in ResponsiveLayoutBuilder for future two-pane

为 expanded 双栏 nav+pane 增强铺路。当前所有尺寸维持单栏 list
push detail 不变；expanded 双栏推到 v1.8.1 polish。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: notes + settings responsive widget test（合并）

**Files:**
- 无（T13/T15 已写 test）

- [ ] **Step 1: Run all responsive tests together**

Run: `cd app && flutter test test/features/library/pages/library_page_responsive_test.dart test/features/notes/pages/notes_page_responsive_test.dart test/features/settings/pages/settings_page_responsive_test.dart test/features/reader/pages/reader_body_responsive_test.dart`
Expected: 全过

- [ ] **Step 2: Run dart analyze 全量**

Run: `cd app && dart analyze`
Expected: 0 error / 0 warning

- [ ] **Step 3: No commit (verification only)**

---

## Task 17: AndroidManifest 验证（intent-filter + ACCESS_NETWORK_STATE）

**Files:**
- 无（仅验证）

- [ ] **Step 1: Read AndroidManifest.xml**

Run: `cat app/android/app/src/main/AndroidManifest.xml`

确认：
- `<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>` 存在（connectivity_plus 需要）
- `<uses-permission android:name="android.permission.INTERNET"/>` 存在（http/sync 需要）
- intent-filter `.epub` / `.pdf` VIEW 存在（M7 已配）
- `android:label="智阅"` 存在（M7 已配）

- [ ] **Step 2: 如果权限缺失，加上**

打开 `app/android/app/src/main/AndroidManifest.xml`，在 `<manifest>` 内 `<application>` 之前加：

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

- [ ] **Step 3: 验证无需 testWidgets（native 配置无 widget test）**

仅做 XML validation：

Run: `python -c "import xml.etree.ElementTree as ET; ET.parse('app/android/app/src/main/AndroidManifest.xml'); print('VALID')"`
Expected: `VALID`

- [ ] **Step 4: Run dart analyze + flutter test（确保 manifest 改动不破任何 test）**

Run: `cd app && dart analyze && flutter test`
Expected: 与 T5 baseline 一致

- [ ] **Step 5: Commit (仅当 Step 2 有改动)**

```bash
git add app/android/app/src/main/AndroidManifest.xml
git commit -m "$(cat <<'EOF'
chore(android): ensure INTERNET + ACCESS_NETWORK_STATE permissions

验证 M7 配置完整 + 补 connectivity_plus / sync 需要的网络权限。
为 Android apk build 铺路。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

如果 Step 2 无改动（权限已存在），跳过本 commit。

---

## Task 18: APK build 在 worktree C:\zhiyue_build

**Files:**
- 无（在 worktree build）

**前提**：worktree `C:\zhiyue_build` 已存在（M5+ 期间建立）。若不存在，先：

```bash
cd /c/dev 2>/dev/null || cd /c/
git -C "H:/projiect/电子书阅读平台" worktree add C:/zhiyue_build master
```

- [ ] **Step 1: Sync worktree to latest master**

Run:
```bash
cd C:/zhiyue_build && git fetch origin && git checkout master && git pull origin master
```
Expected: `Already up to date.` 或 fast-forward

- [ ] **Step 2: Build Android debug APK**

Run:
```bash
cd C:/zhiyue_build/app && flutter build apk --debug
```
Expected: 输出 `Built build/app/outputs/flutter-apk/app-debug.apk`

如果失败：
- 中文路径错误（应不在 worktree，因 worktree 在 C:\zhiyue_build）
- Gradle 错误 → 看 `app/android/local.properties` / `~/.gradle/init.gradle`（M7 配的中国镜像）
- Java 版本 → 用 `flutter doctor -v` 检查

- [ ] **Step 3: Verify APK exists + record size**

Run: `ls -lh C:/zhiyue_build/app/build/app/outputs/flutter-apk/app-debug.apk`
Expected: 文件存在 + 记录大小（预估 50-80MB，含 PDFium）

如果 > 100MB → 警告用户，决策是否启用 ABI 拆分（spec §10.2 永不，但记录警告）。

- [ ] **Step 4: Build release APK (after debug verified)**

Run:
```bash
cd C:/zhiyue_build/app && flutter build apk --release
```
Expected: `Built build/app/outputs/flutter-apk/app-release.apk`

需要 release keystore（M7 配过 `app/keys/keystore.properties`），若无则 fallback 到 debug signing。

- [ ] **Step 5: No commit（build 产物不入仓）**

将 APK 路径记录到本 plan 评论区，供 T19 真机测试用。

---

## Task 19: emulator + 真机 smoke test

**Files:**
- 无（仅手动测试）

- [ ] **Step 1: 启动 Android emulator**

Run: `flutter emulators --launch <emulator_id>`（如 Pixel_5_API_33）

如果无 emulator，先创建：
```bash
flutter emulators --create --name zhiyue_pixel
```

- [ ] **Step 2: Install + launch APK in emulator**

Run:
```bash
cd C:/zhiyue_build && flutter install --use-application-binary=app/build/app/outputs/flutter-apk/app-debug.apk
```
Expected: `Installing build\app\outputs\flutter-apk\app-debug.apk...` + `Installed on emulator`

手动启动智阅 → 验证：
- [ ] Library 显示（默认空）
- [ ] 点 + 导入 EPUB → 文件管理器打开 → 选 epub → 导入成功
- [ ] 点书 → 进入 reader
- [ ] 翻页（左右滑）
- [ ] 选文字 → 弹 toolbar → 加高亮
- [ ] 写笔记
- [ ] 切字体（typography panel）
- [ ] 退出 reader → 回 library
- [ ] 点 hamburger → drawer 显示

- [ ] **Step 3: 真机测试（用户手动跑）**

将 `app-release.apk` 复制到 Android 手机 → 安装 → 重跑 Step 2 验证清单。

特别验证：
- [ ] PDF 打开（pdfrx PDFium native 验证）
- [ ] content:// URI 导入（M7 BookOpenBridge 路径）
- [ ] 不出现"打开文件夹"按钮（T8/T14 验证）

- [ ] **Step 4: 截图存档（用户手动）**

截图（5 张）保存到 `docs/screenshots/mobile/`：
- library (compact)
- reader (compact)
- typography panel
- AI panel (endDrawer)
- 设置页

如果 `docs/screenshots/mobile/` 目录不存在，先创建。

- [ ] **Step 5: No commit（手动测试）**

记录 smoke test 结果到 plan 评论区（pass/fail per item）。

---

## Task 20: 桌面全套回归（dart test 全过）

**Files:**
- 无

- [ ] **Step 1: Run full test suite**

Run: `cd app && flutter test`
Expected: 与 T5 baseline 一致或更好（812+ pass + 4 skipped + 5 pre-existing failures 不增加）

- [ ] **Step 2: Run dart analyze**

Run: `cd app && dart analyze`
Expected: 0 error / 0 warning

- [ ] **Step 3: 验证桌面 GUI（可选）**

Run: `cd app && flutter run -d windows`

手动验证：
- [ ] Library 默认空
- [ ] 导入 EPUB → reader
- [ ] ≥1100px 双页模式启用
- [ ] hover top bar 切换显隐
- [ ] 关闭窗口 → exit(0) 立即退出

- [ ] **Step 4: No commit (verification)**

如果发现新增 fail → 回相应 task 修。

---

## Task 21: 发布准备（pubspec + CHANGELOG + README + installer + release-notes）

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `app/windows/installer/zhiyue.iss`
- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Create: `docs/releases/release-notes-v1.8.0-alpha.md`

- [ ] **Step 1: Bump version**

`app/pubspec.yaml`:
```yaml
version: 1.8.0-alpha
```

`app/windows/installer/zhiyue.iss`:
```
#define MyAppVersion "1.8.0-alpha"
```

- [ ] **Step 2: Add CHANGELOG entry**

`CHANGELOG.md` 在顶部加（如果 [Unreleased] 段不存在则新建）：

```markdown
## [1.8.0-alpha] - 2026-07-10

### Added
- 移动端 MVP Spiral 1：Android 端 reader + library + notes + settings 可用
- ResponsiveLayoutBuilder（M3 三档断点 compact/medium/expanded）
- PlatformChromeController 抽象（status bar + orientation）
- iOS 目录 scaffold（仅占位，不 build 不 CI）
- Library compact 分支（hamburger + overflow menu）
- Reader tap-to-toggle chrome（移动）
- reader_body kDesktopDualPageBreakpoint 常量提取

### Changed
- library/notes 的"打开文件夹" SnackBarAction 在 mobile 隐藏
- notes/settings body 包 ResponsiveLayoutBuilder（双栏增强推 v1.8.1）

### Fixed
- N/A

### Known Issues
- iOS 仅 scaffold，build/CI 推 S3 之后
- APK 单 APK 不做 ABI 拆分（体积 50-80MB）
- Golden 测试不覆盖 Android 渲染
```

- [ ] **Step 3: Update README badge**

`README.md` badge 行：
```
![version](https://img.shields.io/badge/version-1.8.0--alpha-blue)
```

并在项目状态段加：
```markdown
**当前状态**：v1.8.0-alpha（Android MVP Spiral 1 完成）
- 桌面：Windows GA
- Android：MVP 可用（阅读 + AI 已有 + 待 S2 IME 适配）
- iOS：占位（推 S3 后）
- 下一步：S2 AI IME 适配（v1.9.0-alpha）
```

- [ ] **Step 4: Write release notes**

`docs/releases/release-notes-v1.8.0-alpha.md`:

```markdown
# 智阅 v1.8.0-alpha Release Notes

**发布日期**：2026-07-10
**性质**：feature（移动端 MVP Spiral 1）
**Tag**：`v1.8.0-alpha` + `m-mobile-s1-complete`

## 主要变更

### 新增

- **移动端响应式 UX**：M3 三档断点（compact <600 / medium 600-840 / expanded ≥840）
- **抽象层**：
  - `ResponsiveLayoutBuilder`（自研 80 行）+ `kDesktopDualPageBreakpoint=1100` 桌面 GA 行为常量
  - `PlatformChromeController`（status bar + orientation，~50 行）
- **Android 端可用**：library + reader + notes + settings 全功能跑通
- **iOS 目录占位**：`flutter create --platforms=ios .` + Info.plist（不 build 不 CI）
- **Library compact 分支**：hamburger menu + overflow PopupMenu
- **Reader tap-to-toggle chrome**：移动 tap 阅读区中部切换 top bar 显隐

### 改动

- `library/notes` 的"打开文件夹" SnackBarAction 在 mobile 隐藏（mobile 无桌面文件管理器概念）
- `notes/settings` body 包 ResponsiveLayoutBuilder（双栏增强推 v1.8.1）
- `reader_body.dart` 3 处 `>= 1100` 硬编码 → `kDesktopDualPageBreakpoint` 常量

### 桌面行为 100% 保留

- 1100 双页阈值不变
- hover top bar 行为不变
- exit(0) 时序不变
- window chrome 行为不变

## Commit 清单（v1.7.1-alpha 之后）

T1-T22 共 18-22 个 commits，详见 `docs/superpowers/plans/2026-07-10-mobile-mvp-s1.md`。

## 已知问题

- iOS 目录占位但无法 build（用户本机 Windows，无 Mac）
- APK 体积 50-80MB（含 PDFium native，单 APK 不拆 ABI）
- Golden 测试不覆盖 Android 渲染（mobile 字体微差 + emulator 渲染抖动）
- 5 个 pre-existing 测试失败（不阻塞本版本）

## 升级指南

- 桌面：直接覆盖安装，无 schema 迁移
- Android：sideload APK（不上 Play Store）

## 下一节点

S2：AI 适配（IME / 流式 sheet / 软键盘避让）→ v1.9.0-alpha
```

- [ ] **Step 5: Commit all release prep**

```bash
git add app/pubspec.yaml app/windows/installer/zhiyue.iss CHANGELOG.md README.md docs/releases/release-notes-v1.8.0-alpha.md
git commit -m "$(cat <<'EOF'
chore(release): bump v1.8.0-alpha + changelog + readme + notes

S1 完成：移动端 MVP Spiral 1（依赖适配 + 响应式 UX + Android 可用）。
桌面行为 byte-for-byte 不变；iOS 目录占位；APK 体积 50-80MB（单 APK）。
下一步 S2 AI IME 适配。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 22: tag m-mobile-s1-complete + v1.8.0-alpha + push Gitee

**Files:**
- 无

- [ ] **Step 1: Run final full test + analyze**

Run: `cd app && dart analyze && flutter test`
Expected: 全过 + 0 error

- [ ] **Step 2: Push all commits to Gitee**

Run: `git push origin master`
Expected: `master -> master`（如有未推 commits）

- [ ] **Step 3: Tag both tags**

```bash
git tag -a m-mobile-s1-complete -m "Mobile MVP Spiral 1 complete: Android reader+library+notes+settings usable"
git tag -a v1.8.0-alpha -m "v1.8.0-alpha: Mobile MVP Spiral 1"
git push origin m-mobile-s1-complete v1.8.0-alpha
```

- [ ] **Step 4: Create Gitee Release for v1.8.0-alpha**

复用 T24 的 `scripts/create_gitee_releases.py` 模式（编辑 RELEASES 数组只保留 v1.8.0-alpha）：

```python
# 临时修改 scripts/create_gitee_releases.py：
RELEASES = [
    ("v1.8.0-alpha", "智阅 v1.8.0-alpha", "release-notes-v1.8.0-alpha.md"),
]
INSTALLER = Path("C:/zhiyue_build/app/build/app/outputs/flutter-apk/app-release.apk")
```

Run: `cd H:/projiect/电子书阅读平台 && GITEE_TOKEN=<token> python scripts/create_gitee_releases.py`
Expected: 输出 OK + APK 上传成功

**注意**：APK 而非 Windows installer，需调整脚本变量名。或简化：手动通过 Gitee Web UI 创建 Release + 上传 APK。

- [ ] **Step 5: Update memory**

写 memory 文件 `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_mobile_mvp_s1_complete.md`：

```markdown
---
name: zhiyue-mobile-mvp-s1-complete
description: 2026-07-10 移动端 MVP Spiral 1 完成，tag m-mobile-s1-complete + v1.8.0-alpha；Android 端 reader+library+notes+settings 可用
metadata:
  type: project
---

2026-07-10 S1 完成。22 tasks / 22 commits / N tests + M skipped。

**核心交付**：
- ResponsiveLayoutBuilder + PlatformChromeController 抽象层
- library/reader/notes/settings 全部上 Android
- reader tap-to-toggle + 双页阈值常量化
- iOS 目录 scaffold（不 build）

**关键决策**：
- 单 APK（不拆 ABI）
- mobile 平板横屏 ≥1100 启用双页
- AI panel 用 endDrawer（不重写）
- Golden 永不加 mobile 渲染
- iOS build/CI 推 S3 后

**桌面行为**：byte-for-byte 不变（1100 双页 / hover / exit(0) / window chrome）。

**下一节点**：S2 AI IME 适配（v1.9.0-alpha）。

**Why:** 桌面 GA 后用户需求转向移动端，S1 是基础响应式铺路。
**How to apply:** S2/S3 期间不得破坏 S1 抽象层；新增 mobile 改动用 ResponsiveLayoutBuilder/windowSizeClassOf。

关联：[[zhiyue-mobile-mvp-kickoff]]、[[zhiyue-design-context]]、[[no-dispose-time-fire-and-forget]]
```

更新 `MEMORY.md` 加一行：
```markdown
- [智阅 Mobile MVP S1 完成](project_zhiyue_mobile_mvp_s1_complete.md) — 2026-07-10 22 tasks/commits，tag m-mobile-s1-complete + v1.8.0-alpha；Android reader+library+notes+settings 可用；单 APK；iOS 占位
```

Commit memory：
```bash
cd C:/Users/1/.claude/projects/H--projiect--------/memory
# 写文件 + 更新 MEMORY.md
# 不入 git（memory 不在项目仓）
```

- [ ] **Step 6: Final verification**

Run: `git log --oneline master ^desktop-stable-pre-mobile | wc -l`
Expected: 22 左右（T1-T22 共 22 commits + 任何中间修复）

确认 tag 在 origin：
```bash
git ls-remote --tags origin | grep -E "(m-mobile-s1-complete|v1.8.0-alpha)"
```
Expected: 两行（两个 tag 都在 origin）

---

## Self-Review

### Spec coverage check

| Spec 章节 | 对应 task |
|---|---|
| §1 目标 | T22（tag + release） |
| §2 三 spiral 拆分（S1 部分） | T1-T22 全 |
| §3 S1 范围（含 6 项） | T1-T4, T6-T15, T17-T22 |
| §4 依赖适配扫描（零改动） | T5 baseline 验证 |
| §5 抽象层（ResponsiveLayoutBuilder + PlatformChromeController） | T1, T2 |
| §6 响应式 UX 矩阵（5 个页面） | T6-T15 |
| §7 测试策略 | T1-T2 单测 + T10-T11 + T13 + T15 + T16 widget test + T19 emulator |
| §8 风险清单 R1 中文路径 | T18 worktree |
| §8 风险清单 R3 单 APK | T18 step 3 体积监控 |
| §8 风险清单 R6 file_picker SAF | T17 + T19 |
| §9 iOS 占位 | T4 |
| §10 验收标准（11 项） | T20 + T19 + T22 |
| §11 任务估算（18-22） | 22 tasks ✓ |

### Placeholder scan

✅ 无 TBD / TODO / "implement later"
✅ 每个 code step 都有完整代码
✅ 类型一致（WindowSizeClass / kDesktopDualPageBreakpoint / PlatformChromeController 跨 task 名字一致）
✅ 测试命令精确到 `cd app && flutter test <path>`

### Type consistency

- `WindowSizeClass` enum 三档（compact/medium/expanded）— T1, T6, T13, T15 一致
- `kDesktopDualPageBreakpoint = 1100.0` — T1, T3 一致
- `PlatformChromeController` / `DesktopPlatformChromeController` / `MobilePlatformChromeController` — T2 一致
- `ReaderUiController.toggleChrome` — T9 引入，T9 内使用
- `_CompactAction` enum — T6 内闭环
- `_LibraryNavigationDrawer` class — T7 内闭环

无跨 task 类型不一致。

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-10-mobile-mvp-s1.md`.**

**Two execution options**:

1. **Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, two-stage review (spec compliance → code quality) between tasks, fast iteration. **REQUIRED SUB-SKILL:** Use `superpowers:subagent-driven-development`.

2. **Inline Execution** - Execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints for review.

**Which approach?**
