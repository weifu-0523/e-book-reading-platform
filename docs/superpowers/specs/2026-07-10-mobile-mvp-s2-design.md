# 智阅 Mobile MVP Spiral 2 (S2) Design

> **状态**：approved（6 section 全通过 user review，2026-07-10）
> **前置**：S1 已交付（v1.8.0-alpha），v1.9.0-alpha（bug batch 3）紧随其后
> **后续**：v1.9.1-alpha hotfix + v1.10.0-alpha 正式发版
> **桌面稳定锚点**：`desktop-stable-pre-mobile` tag —— 桌面行为 byte-for-byte 不变

## 1. 目标与范围

### 1.0 术语约定

- **`isMobile`**：spec 中多次引用的布尔判定，等价于 `Platform.isAndroid || Platform.isIOS`（与 reader_body.dart:698 现有 `_isDesktopPlatform` 反向逻辑一致；Web 平台尚未支持，不在 S2 范围）
- **`isDesktop`**：`!isMobile`（Windows / macOS / Linux）
- **chrome / AppBar**：reader 顶部的 12 按钮工具条（Back / TOC / 排版 / AI / 字号± / 全屏 等），由 `ReaderUiState.chromeVisible` 控制可见
- **wide / compact margin**：`PageMargin` 枚举值，对应 72px / 8px

### 1.1 用户痛点（触发原因）

S1 验收盲区：v1.9.0-alpha 真机上手第一天，用户报告"看不到导航条和排版"。根因是 mobile chrome 默认隐藏（`ReaderUiState.defaults()` 设 `chromeVisible = isDesktop`）+ 无 visual hint。用户进一步测试发现：

- **Bug #1**：tap 屏幕唤出 chrome 后，再 tap 不能隐藏（但全屏按钮能）
- **Bug #2**：用户不知道 tap 可以 toggle（无引导）
- **Bug #3**：mobile margin 默认 wide(72px) 在小屏太挤

### 1.2 S2 完整范围（10 子项）

| ID | 子项 | 工时（实现+测试） |
|---|---|---|
| **UX-A** | chrome tap-toggle bug fix（Stack 顶层 Listener） | 0.5d |
| **UX-B** | 进入书 3s 自动隐藏 chrome（mobile） | 0.5d |
| **UX-C** | mobile 默认 margin=compact(8px)；桌面=wide 不变；只新书生效 | 0.5d |
| **AI-D** | mobile AI 抽屉改 BottomSheet（70%→100%）；桌面不变 | 1.5d |
| **AI-E** | AiInputComposer IME padding（MediaQuery.viewInsets.bottom） | 0.5d |
| **AI-F** | Scaffold.resizeToAvoidBottomInset 全 codebase 审计 | 0.5d |
| **PLG-G** | 5 plugin 升 latest stable + breaking API 修复 | 1.5d |
| **PLG-H** | 移除 sed 补丁文档 | 0.2d |
| **SMK-I** | T19 真机 smoke 闭环（金路 + 边界用例 + 截图） | 1.5d |
| **REL-J** | 发版（pubspec/CHANGELOG/README/notes/tag/APK/installer）×2 | 0.5d |

**总工时约 6.7 天**（不含用户真机测试等待时间）。

### 1.3 双 tag 路径

```
v1.9.0-alpha (当前)
    │
    ├─ v1.9.1-alpha (hotfix, ~2 天)
    │   • UX-A: chrome tap-toggle bug
    │   • UX-B: 进入书 3s 自动隐藏 chrome
    │   • UX-C: mobile 默认 margin=compact
    │   └─ 真机 smoke (UX 部分, ~5min)
    │
    └─ v1.10.0-alpha (正式, +4-5 天)
        • AI-D: mobile AI BottomSheet
        • AI-E: IME padding
        • AI-F: Scaffold.resizeToAvoidBottomInset
        • PLG-G: 5 plugin 升 latest stable
        • PLG-H: 移除 sed 补丁
        └─ 真机 smoke (全量, ~20min)
```

### 1.4 范围外

- WebDAV / sync 适配（推 S3）
- iOS build / CI（仍 scaffold）
- Android 模拟器 CI（推 S3 或更晚）
- EPUB 双页渲染（桌面 v1.6 遗留，仍推后）
- 手势导航 / 长按菜单 / 分享 sheet（推 S3+）

---

## 2. v1.9.1-alpha Hotfix 详细设计

### 2.1 UX-A：chrome tap-toggle bug fix

**根因（实证）**：

`reader_body.dart:689-703` 的 `GestureDetector(behavior: translucent)` 包了 `SelectableRegion`，在 Stack 下层。当 `chromeVisible=true` 时 AppBar 在上层渲染，**tap 落在 AppBar 区域被吞，落在非 AppBar 区域进入"显示"分支无效**。

`toggleChrome()` 本身是正确的 toggle（`chromeVisible: !state.chromeVisible`），但 tap 路径不通。

**修法**：

把 tap 监听从 SelectableRegion 外层移到 **Stack 最顶层** 的一个透明 `Listener`（用 `Listener` 而非 `GestureDetector` 避免 race）。Listener 在所有 chrome 之上，**但仅在 mobile 启用**（桌面保持现状：tap=null）。

```dart
// reader_scaffold.dart 大致结构
Stack(
  children: [
    _buildReaderBody(),         // 含 SelectableRegion，不再包 tap
    if (ui.chromeVisible) _buildChrome(...),  // AppBar 等
    if (isMobile) _buildChromeToggleListener(), // 新增：最顶层
    if (!ui.chromeVisible) _buildBookmarkFab(), // 浮动书签
  ],
)
```

`_buildChromeToggleListener` 是 `Positioned.fill(child: Listener(onPointerDown: ..., onPointerUp: ...))`。**仅 `onPointerUp` 时若是 tap（无显著 move）才 toggle**。

**桌面行为不变**：`if (isMobile)` 守卫。

### 2.2 UX-B：进入书 3s 自动隐藏 chrome

**新行为（仅 mobile）**：

1. `ReaderUiState.defaults()` 设 `chromeVisible: isMobile`（mobile=true，desktop 不变）
2. `ReaderScaffold.initState` 启动 `_autoHideTimer = Timer(Duration(seconds: 3), () => ref.read(readerUiControllerProvider.notifier).hideChrome())`
3. 任何 user interaction（tap toggle / scroll / 翻页）触发时 `_autoHideTimer.cancel()`
4. 用户 tap 后正常 toggle（不再受 timer 干扰）
5. `WidgetsBindingObserver.didChangeAppLifecycleState` 在 `paused` 时 cancel timer（避免后台 3s 后回前台 chrome 已隐藏）
6. `dispose()` 时 cancel timer 防泄漏

**新增方法**：`ReaderUiController.hideChrome()`（当前只有 `toggleChrome()`）。

**桌面不受影响**：`isMobile` 守卫，timer 不启动。

### 2.3 UX-C：mobile 默认 margin=compact

**当前**（`reader_engine/lib/core/typography_settings.dart:77-85`）：

```dart
factory TypographySettings.defaults() => const TypographySettings(
  pageMargin: PageMargin.wide,  // 72px 全平台
);
```

**枚举值**：

- `compact` = 8px ← mobile 新默认
- `normal` = 48px
- `wide` = 72px ← 当前全平台默认 / 桌面新默认（不变）
- `extraWide` = 96px

**修法**：`defaults()` 不改（避免影响 reader_engine 包测试），改在应用层 `_applyPersistedTypography()` 分支：

```dart
// reader_engine_provider.dart:76 附近的 _applyPersistedTypography
final persisted = await repository.loadForBook(bookId);
if (persisted != null) {
  engine.setTypography(persisted);  // 老书尊重用户已自定义
} else {
  // 新书 fallback：mobile 用 compact，desktop 用 defaults（=wide）
  final defaults = TypographySettings.defaults();
  final mobileAdjusted = Platform.isAndroid || Platform.isIOS
      ? defaults.copyWith(pageMargin: PageMargin.compact)
      : defaults;
  engine.setTypography(mobileAdjusted);
}
```

**只新书生效**——已有 customSettings 的书走 persisted 分支，不受影响。v1.9.0-alpha 用户已手动调成紧凑的书会保留，用户没动过的书仍是 wide（需手动调一次）。

---

## 3. v1.10.0-alpha 详细设计

### 3.1 AI-D：mobile AI 抽屉改 BottomSheet

**当前**（`reader_body.dart:538-546`）：mobile 用 `Scaffold.endDrawer` + `Drawer` 包 `AiDrawerWidget(wide: false)`。

**新设计**：

```dart
// reader_body.dart 紧凑分支
if (constraints.maxWidth < kDesktopDualPageBreakpoint) {
  // mobile: 不再 endDrawer，改用 showModalBottomSheet
  // 入口：AppBar 的 AI IconButton onPressed 改成 _openAiBottomSheet(context)
} else {
  // desktop: inline SizedBox(width: 570) 不变
}

Future<void> _openAiBottomSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,       // 关键：让 sheet 可全屏 + 避让键盘
    useSafeArea: true,
    isDismissible: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      initialSize: 0.7,             // 70% 高度起步
      maxSize: 1.0,                 // 可拖到全屏
      minSize: 0.3,                 // 最小 30% 不消失
      expand: false,
      snapSizes: [0.7, 1.0],        // 仅吸附这两个高度
      snap: true,
      builder: (_, controller) => AiDrawerWidget(
        wide: false,
        mobileSheet: true,          // 新参数：内部布局微调
      ),
    ),
  );
}
```

**关键约束**：
- `isScrollControlled: true` 让 sheet 在键盘弹出时整体上移（解决 IME 避让）
- `useSafeArea: true` 避开 status bar
- `showDragHandle: true` 用户可拖拽（70% → 100%）
- `snapSizes: [0.7, 1.0]` 拖到中间值会吸附到最近的点
- `snap: true` 启用 snap 行为
- AiDrawerWidget 加 `mobileSheet` 布尔参数区分 mobile sheet 模式（顶部 padding / 标题栏可能微调）

**重复打开防御**：检测 sheet 已打开（`Navigator.canPop` 或全局 bool）→ 不重复 show。

**桌面完全不变**：所有 mobile 分支用 `if (!kIsMobile)` 守卫。

### 3.2 AI-E：AiInputComposer IME padding

**当前**：TextField 仅包 `Padding(all: 8)`，没处理 viewInsets。

**修法**：

```dart
// ai_input_composer.dart 顶层
Widget build(BuildContext context) {
  final bottomInset = MediaQuery.of(context).viewInsets.bottom;
  return AnimatedPadding(
    duration: const Duration(milliseconds: 200),
    padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomInset),
    child: /* existing input row */,
  );
}
```

**BottomSheet 内自带避让**：`isScrollControlled: true` 配合 AnimatedPadding，键盘弹起时整个 composer 上推。

### 3.3 AI-F：Scaffold.resizeToAvoidBottomInset 审计

**审计范围**：所有 `Scaffold(` 出现的位置。

**Flutter Scaffold 默认 `resizeToAvoidBottomInset: true`**，所以审计重点在确认没人手动设过 `false`。如果有人设了，移除该 flag。

**预期审计点**：
- `reader_scaffold.dart`：默认即可
- `library_page.dart`：默认即可（导入对话框需要）
- `notes_page.dart` / `note_edit_page.dart`：默认即可（自由笔记编辑器必须）
- `settings_page.dart`：默认即可（API key 输入框）

**widget test**：grep `resizeToAvoidBottomInset: false` 全 codebase 应返回 0 结果。

### 3.4 PLG-G：5 plugin 升 latest stable

**当前 → 升级目标**：

| Plugin | 当前 | 升级目标（latest stable@2026-07-10） | Breaking 风险 |
|---|---|---|---|
| connectivity_plus | 6.1.5 | 6.x latest | 低 |
| file_picker | 8.3.7 | 10.x latest | **高**（API 大改） |
| flutter_secure_storage | 9.2.4 | 9.x latest | 低 |
| just_audio | 0.9.46 | 0.9.x latest | 低 |
| webview_flutter_android | 3.16.9 | 4.x latest | 中 |

**file_picker 8.x → 10.x 重点审查**：
- API 调用点：library_page import 按钮 + 自由笔记附件 + 任何 FileType / FilePickerResult 使用
- 预期变化：`FilePicker.platform.pickFiles()` 可能改名或参数变化

**webview_flutter_android 3.x → 4.x**：当前没在 code 直接用，是 webview_flutter 的 transitive dependency。需要确认 webview_flutter 主包也跟着升。

**实施步骤**（每步独立 commit，便于 bisect）：

1. `flutter pub upgrade --major-versions connectivity_plus flutter_secure_storage just_audio`（低风险三个先升）
2. 跑 analyze + test，确认无回归 → commit
3. 单独升 `file_picker`，手动改所有调用点 → analyze + test 全绿 → commit
4. 单独升 `webview_flutter`（含 android），确认 webview 在 settings 页能用 → analyze + test 全绿 → commit
5. 跑全量 test + analyze → 全绿

**回滚策略**：每个 plugin 升级独立 commit。某个 plugin 升级后 analyze + test 大量失败且 30 分钟内修不好，`git revert` 那个 commit，不影响其他 plugin。file_picker 是最高风险，预期单独花 0.5-1 天修。

**pub cache 状态**：升完后跑一次 `flutter clean && flutter pub get`，确认 5 plugin 的 `compileSdk 36` 是 plugin 自带的，不再依赖手动 sed。

### 3.5 PLG-H：移除 sed 补丁文档

**改动**：
- `docs/setup-android-sdk.md`：删末段"compileSdk 36 plugin 补丁"
- `docs/release-procedure.md:106`：删 step 6 关于 sed 补丁的提及
- `CHANGELOG.md`：在 v1.10.0-alpha 段落注明"移除 sed 补丁"
- `README.md:23`：更新下一步为 S3

---

## 4. 数据流（状态机 + 关键路径）

### 4.1 Chrome 可见性状态机（v1.9.1）

```
打开 reader (mobile)
    │
    ▼
[chromeVisible = true]  ← UX-B: mobile 默认显示
    │
    ▼
启动 _autoHideTimer (3s)
    │
    ├─ 3s 到 + 无 interaction
    │     │
    │     ▼
    │   chromeVisible = false  ───┐
    │                              │
    ├─ 用户 tap (UX-A Listener)   │ timer 已激活 → cancel
    │     │                        ▼
    │     ▼                        [循环 toggle]
    │   cancel timer               chromeVisible = !chromeVisible
    │                              │
    ├─ 用户 scroll / 翻页           │
    │     │                        │
    │     ▼                        │
    │   cancel timer               │
    │   (不改变 chromeVisible)      │
    │                              │
    ├─ app 进入 paused（后台）      │
    │     │                        │
    │     ▼                        │
    │   cancel timer               │
    │                              │
    ▼                              ▼
[稳定状态：用户控制 toggle]
```

**关键不变量**：
- timer 只在 reader 首次 init 时启动一次
- 任何 user interaction 后 timer 失效，**不再自动重启**
- 桌面：`isMobile=false`，timer 不启动，chromeVisible=true 全程

### 4.2 Margin 默认值数据流（v1.9.1）

```
打开 book (bookId)
    │
    ▼
_applyPersistedTypography(bookId)
    │
    ├─ repository.loadForBook(bookId) != null (老书)
    │     │
    │     ▼
    │   engine.setTypography(persisted)   ← 用户已自定义，原样应用
    │
    └─ repository.loadForBook(bookId) == null (新书)
          │
          ▼
        defaults = TypographySettings.defaults()  // pageMargin=wide
          │
          ├─ Platform.isAndroid || Platform.isIOS
          │     │
          │     ▼
          │   defaults.copyWith(pageMargin: PageMargin.compact)
          │     │
          │     ▼
          │   engine.setTypography(mobileAdjusted)
          │
          └─ Desktop (Windows/macOS/linux)
                │
                ▼
              engine.setTypography(defaults)   // pageMargin=wide 不变
```

**关键不变量**：
- defaults() 不改（reader_engine 包测试零回归）
- 仅 mobile 新书走 compact 分支
- 老书持久化值原样加载（不破坏用户选择）
- 一旦 mobile 用户首次调整过，即持久化（即使后续手动改回），之后 reload 走 persisted 分支

### 4.3 AI BottomSheet 状态机（v1.10.0）

```
用户点 AppBar AI IconButton (mobile)
    │
    ▼
_openAiBottomSheet(context)
    │
    ▼
showModalBottomSheet(isScrollControlled: true, useSafeArea: true)
    │
    ▼
DraggableScrollableSheet (initialSize=0.7, snapSizes=[0.7,1.0])
    │
    ├─ 用户拖到顶 → size=1.0 (全屏)
    │
    ├─ 用户拖到 size < 0.3 释放 → dismiss (返回 reader)
    │
    ├─ 用户在 AiInputComposer 输入文字 → 软键盘弹起
    │     │
    │     ▼
    │   MediaQuery.viewInsets.bottom 变化
    │     │
    │     ▼
    │   AnimatedPadding 推 input composer 上移
    │     │
    │     ▼
    │   sheet 内容自动 scroll 到底部（保持可见）
    │
    └─ 用户 tap sheet 外（reader 区域）→ sheet dismiss
```

**桌面完全独立路径**：endDrawer / inline panel 不变。

### 4.4 Plugin 升级数据流（v1.10.0）

```
flutter pub upgrade --major-versions connectivity_plus flutter_secure_storage just_audio
    │
    ▼
pubspec.lock 更新 (低风险三包)
    │
    ▼
dart analyze + dart test
    │
    ├─ 全绿 ────────────────────────────┐
    │                                    │
    └─ 报错                              │
          │                              │
          ▼                              ▼
        修复调用点              单独升 file_picker 8→10
                                    │
                                    ▼
                              grep 所有 FilePicker 调用点
                                    │
                                    ▼
                              逐个改 API（预期：参数 / 返回类型变）
                                    │
                                    ▼
                              dart analyze + dart test
                                    │
                                    ▼
                              单独升 webview_flutter 4.x
                                    │
                                    ▼
                              手动 smoke：settings 页（如有 webview）能渲染
                                    │
                                    ▼
                              dart analyze + dart test 全绿
                                    │
                                    ▼
                              移除 docs/setup-android-sdk.md sed 段
                                    │
                                    ▼
                              flutter build apk --release 验证（无 sed 也能编）
```

### 4.5 真机 smoke 数据流（每次发版）

```
APK install on Android (adb install -r)
    │
    ├─ v1.9.1 smoke (~5min)
    │     ├─ 打开任意书 → 看见 chrome
    │     ├─ 3s 后 chrome 自动消失 ✓ UX-B
    │     ├─ tap → chrome 出现 ✓ UX-A
    │     ├─ 再 tap → chrome 消失 ✓ UX-A
    │     ├─ 导入新书 → margin 看起来紧凑 ✓ UX-C
    │     └─ 截图 3 张（chrome 显示/隐藏/紧凑 margin）
    │
    └─ v1.10.0 smoke (~20min)
          ├─ v1.9.1 全部 +
          ├─ 打开 AI 抽屉 → BottomSheet 弹出 ✓ AI-D
          ├─ 输入消息 → 软键盘弹起 → 输入框可见 ✓ AI-E
          ├─ 切到 settings → 输入 API key → 软键盘正常 ✓ AI-F
          ├─ 切到 library → 导入文件 ✓ PLG-G (file_picker)
          ├─ 切到 settings → webview (如有) 渲染 ✓ PLG-G (webview)
          ├─ 锁屏 → 重启 → typography 持久化（margin 仍紧凑）✓
          └─ 截图 5+ 张
```

---

## 5. 错误处理 + 边界 case

### 5.1 UX-A chrome toggle bug fix

| 场景 | 行为 |
|---|---|
| 用户 tap 后立即 drag（翻页） | Listener 只在 `pointerUp + 无显著 move` 时 toggle，drag 不触发 |
| 用户 tap 在浮动书签 FAB 上 | FAB 用 `IconButton` 自带 hit test，会消费 event；Listener 不触发 toggle |
| 用户 tap 在选中文字的 SelectionRegion | SelectionRegion 优先消费，toggle 不触发（保留选区 → 工具条逻辑不变） |
| 用户 tap 在选区工具条按钮上 | 工具条消费，toggle 不触发 |
| 桌面端 | `if (isMobile)` 守卫，Listener 不挂载，桌面行为零变化 |

### 5.2 UX-B 3s auto-hide timer

| 场景 | 行为 |
|---|---|
| 用户在 3s 内退出 reader | `dispose()` 必须 `_autoHideTimer.cancel()` 防泄漏 |
| 用户在 3s 内切换到另一本书 | 旧 reader dispose → 旧 timer cancel；新 reader init → 新 timer 启动 |
| 用户在 3s 内锁屏 / 切后台回来 | 用 `WidgetsBindingObserver.didChangeAppLifecycleState` 在 `paused` 时 cancel timer |
| 用户在 3s 内旋转屏幕 | Flutter 不重建 Scaffold（只 layout），timer 继续。安全 |
| 桌面端 | isMobile=false，timer 不启动，无影响 |

### 5.3 UX-C mobile compact margin

| 场景 | 行为 |
|---|---|
| 用户首次安装（无任何 book） | database 空，导入第一本书走 "新书" 分支 → mobile 得到 compact |
| 用户从 v1.9.0-alpha 升级（已有多本书 + 已存 wide） | 老书走 persisted 分支，保持 wide；用户得手动改 |
| 用户手动调过某本书 margin 为 normal（48px） | persisted = normal，加载走 persisted，尊重用户选择 |
| 用户在桌面端 v1.10.0-alpha 打开 | isDesktop = true，走 defaults（wide）不变 |
| 同一本书在桌面打开后切换到手机（同步后） | typography 通过 WebDAV sync（已有），margin 会跟随用户在桌面调的值同步过来（仍 persisted 分支） |
| books 表被外部 SQL 修改清空 customSettings | repository.loadForBook 返回 null → 走"新书"分支，mobile 重置为 compact |

### 5.4 AI-D BottomSheet

| 场景 | 行为 |
|---|---|
| 用户拖到 size < 0.3 | 释放 → dismiss（返回 reader） |
| 用户拖到中间值（如 0.5）释放 | `snapSizes: [0.7, 1.0]`：snap 到最近的吸附点 |
| 软键盘弹起时 sheet 被压缩 | `isScrollControlled: true` + AnimatedPadding 推 composer 上移；MaxHeight = screen - status bar - keyboard |
| 用户在 sheet 内 tap 外部（reader 区域） | `isDismissible: true` + `enableDrag: true` → tap 外部 dismiss |
| 用户在 AI 流式响应中关闭 sheet | 流式 stream 不取消（AI 后台继续跑），用户重新打开能看到完整回复 |
| 桌面端 | isMobile 守卫，endDrawer 路径不变 |
| BottomSheet 已打开时再点 AppBar AI 按钮 | 检测 sheet 已打开 → 不重复 show（用 `Navigator.canPop` 或全局 bool 状态） |

### 5.5 PLG-G plugin 升级

| Plugin | 风险点 | 兜底策略 |
|---|---|---|
| connectivity_plus | enum 值可能改 | 改完跑 sync test 全套 |
| file_picker | `FilePicker.platform.pickFiles()` 返回类型 / 参数可能改 | grep 调用点（预期 5-10 处），逐一修；跑 library import widget test |
| flutter_secure_storage | iOS/macOS auth 要求 | 仅 mobile 范围，Android 不受影响 |
| just_audio | API 兼容性 | 跑 audio 相关 widget test（如有） |
| webview_flutter_android | webview_flutter 主包同步升 | 升 webview_flutter 主包，android 子包跟随 |

**回滚策略**：每个 plugin 升级**独立 commit**。如果某个 plugin 升级后 analyze + test 大量失败且 30 分钟内修不好，`git revert` 那个 commit，**不影响其他 plugin**。file_picker 是最高风险，预期单独花 0.5-1 天修。

### 5.6 真机 smoke 失败处理

| 失败场景 | 处理 |
|---|---|
| v1.9.1 smoke 失败（chrome 或 margin 不对） | 不发 v1.9.1-alpha tag；修复后重测 |
| v1.10.0 smoke 失败（plugin 不工作 / BottomSheet bug） | 不发 v1.10.0-alpha tag；保留 v1.9.1-alpha 作为基线，修复后重测 |
| 用户白天没空测，拖几天 | 不阻塞代码推进；smoke 不到位前不打 tag |
| smoke 发现新 bug | 视严重程度：P0 fix 后重测；P1/P2 进 v1.10.1-alpha 或 v1.11.0-alpha |

### 5.7 桌面稳定锚点不变量

**每次 commit 前必跑**：

```
1. dart analyze → 0 errors / 0 warnings / 0 info
2. dart test 全套（≥ 1235 pass + 3 skipped + 8 baseline 失败）
3. 桌面 widget test 全绿
4. Platform.isWindows 分支不被新代码 touch（除非必要）
```

**桌面行为基线**（任何修改都不能破坏）：
- 1100px 双页布局阈值（kDesktopDualPageBreakpoint）
- hover 状态
- exit(0) 时序（TypographyPersister / ProgressPersister 即时落盘）
- window chrome 默认可见

---

## 6. 测试策略

### 6.1 测试金字塔

```
        ┌─────────────────┐
        │ 真机 smoke (2x) │  v1.9.1 + v1.10.0 各一次
        └─────────────────┘
       ┌───────────────────┐
       │ Integration test  │  reader flow + AI flow + sync flow（已有）
       └───────────────────┘
      ┌─────────────────────┐
      │   Widget test       │  UX-A/B/C + AI-D/E/F 各 1-3 个用例
      └─────────────────────┘
     ┌───────────────────────┐
     │    Unit test          │  reader_ui_controller 新 hideChrome() + timer 逻辑
     └───────────────────────┘
```

### 6.2 新增测试矩阵

| 测试文件（新增/修改） | 测试用例 | 子项 |
|---|---|---|
| `test/features/reader/services/reader_ui_controller_test.dart`（修改） | `hideChrome() sets chromeVisible=false`<br>`hideChrome() no-op when already hidden` | UX-B |
| `test/features/reader/widgets/reader_scaffold_chrome_toggle_test.dart`（新增） | `mobile: single tap toggles chrome visible→hidden`<br>`mobile: single tap toggles chrome hidden→visible`<br>`mobile: drag does not toggle chrome`<br>`mobile: tap on FAB does not toggle chrome`<br>`desktop: tap does not toggle chrome (hover preserved)` | UX-A |
| `test/features/reader/widgets/reader_chrome_auto_hide_test.dart`（新增） | `mobile: chrome auto-hides after 3 seconds`<br>`mobile: user tap cancels auto-hide timer`<br>`mobile: scroll cancels auto-hide timer`<br>`mobile: app backgrounded cancels timer`<br>`mobile: dispose cancels timer (no fire after unmount)`<br>`desktop: timer does not start` | UX-B |
| `test/features/reader/services/typography_default_margin_test.dart`（新增） | `mobile: new book gets compact margin`<br>`mobile: persisted book keeps its margin`<br>`mobile: persisted=normal keeps normal`<br>`desktop: new book gets wide margin`<br>`desktop: persisted book keeps its margin` | UX-C |
| `test/features/ai_chat/widgets/ai_input_composer_ime_test.dart`（新增） | `mobile: keyboard shown pushes composer up by viewInsets.bottom`<br>`mobile: keyboard hidden returns composer to bottom`<br>`AnimatedPadding duration is 200ms` | AI-E |
| `test/features/reader/pages/reader_body_ai_bottom_sheet_test.dart`（新增） | `mobile: tap AI icon opens BottomSheet at 70% height`<br>`mobile: drag to top sets size to 100%`<br>`mobile: drag below 0.3 dismisses sheet`<br>`mobile: tap outside dismisses sheet`<br>`desktop: AI icon opens endDrawer (no BottomSheet)` | AI-D |
| `test/features/scaffold/resize_to_avoid_bottom_inset_audit_test.dart`（新增） | `audit: no Scaffold explicitly sets resizeToAvoidBottomInset=false` | AI-F |
| `test/services/sync/..._after_plugin_upgrade_test.dart`（已有，跑即可） | connectivity_plus 升级后 sync test 全套仍绿 | PLG-G |
| `test/features/library/pages/library_page_import_test.dart`（已有，跑即可） | file_picker 升级后导入路径仍工作 | PLG-G |

**预估新增测试**：~25 个新用例，~3-4 个新文件。

### 6.3 真机 smoke 步骤（详细）

#### v1.9.1-alpha smoke (~5 分钟)

```
1. adb install -r zhiyue-1.9.1-alpha.apk
2. 启动 app → 进入 library
3. 打开任意已存在的书
   期望：进入 reader，chrome 可见（含 TOC / 排版 / AI 等按钮）
4. 不操作等待 3 秒
   期望：chrome 自动消失，只剩浮动书签 FAB
5. 单 tap 屏幕中央
   期望：chrome 重新出现
6. 单 tap 屏幕中央
   期望：chrome 再次消失 ← UX-A 核心回归
7. 导入新书（library → 导入 → 选 epub）
8. 打开新书 → 检查 margin
   期望：左右边距明显紧凑（8px），文字宽度接近屏幕宽度
9. 退出 reader → 重启 app → 重新打开新书
   期望：margin 仍为 compact（持久化生效）
10. 截图：
    - chrome 显示状态
    - chrome 隐藏状态
    - 新书紧凑 margin

通过标准：所有期望全 ✓，截图清晰。
```

#### v1.10.0-alpha smoke (~20 分钟)

```
1. adb install -r zhiyue-1.10.0-alpha.apk
2. v1.9.1 smoke 全套（先回归）
3. 打开 reader → tap AI icon (smart_toy)
   期望：BottomSheet 从底部弹出，高度约屏幕 70%
4. 在 input composer 输 "你好"
   期望：软键盘弹起，composer 被推到键盘上方，可见可输入
5. 发送消息 → AI 流式响应
   期望：流式 token 在 sheet 内可见，可滚动
6. 拖 sheet 到顶
   期望：sheet 全屏
7. 拖 sheet 到 < 30% 释放
   期望：sheet dismiss，回到 reader
8. 设置 → API key 输入
   期望：键盘弹起，输入框可见
9. library → 导入 epub（file_picker 路径）
   期望：file_picker 10.x 工作正常
10. 设置 → 关于（如有 webview）
    期望：webview 渲染（如适用）
11. 锁屏 → 解锁 → 回到 app
    期望：状态恢复正确
12. 重启 app → typography 持久化
    期望：margin 仍 compact，字体/行距等不变

通过标准：全 ✓。截图 5+ 张。
失败处理：P0 fix 后重测；P1/P2 进 v1.10.1。
```

### 6.4 桌面回归测试

**每次 commit 前必跑**：

```bash
cd app
/c/flutter/bin/dart analyze          # 0 errors / 0 warnings / 0 info
/c/flutter/bin/dart test             # ≥ 1235 pass + 3 skipped + 8 baseline 失败
```

**v1.9.1-alpha 发版前**：
- 桌面 widget test 全套（reader_page_test / library_test / notes_test / settings_test）
- 桌面 golden test（library_golden_test 4 张 baseline 不变）
- 桌面手动 smoke：打开 reader → chrome 默认可见（不变） → 不受 mobile 改动影响

**v1.10.0-alpha 发版前**：
- 全套桌面 widget test
- 桌面 golden test
- 桌面手动 smoke：AI 抽屉（endDrawer 路径）正常工作 → 桌面行为零变化验证

### 6.5 plugin 升级后测试调整

**预期会受影响的现有测试**：

| 测试 | 预期影响 | 应对 |
|---|---|---|
| connectivity_plus 相关（sync test） | API 兼容，预期绿 | 跑即可 |
| file_picker 相关（library import test） | API 可能变 | 失败后逐个改 mock |
| flutter_secure_storage 相关（API key test） | API 兼容 | 跑即可 |
| just_audio 相关（如有） | API 兼容 | 跑即可 |
| webview_flutter 相关（如有） | API 可能变 | 失败后改 |

**plugin 升级 test failure 不是 baseline**：每次 plugin 升级 commit 都要让 test 全绿才能进下一个 plugin。

### 6.6 测试覆盖率目标

- **UX-A/B/C**：每个子项 ≥ 3 个 widget test 用例
- **AI-D/E/F**：每个子项 ≥ 2 个 widget test 用例
- **PLG-G/H**：无新测试，跑现有 test 不回归即可
- **桌面回归**：现有 widget test 全绿 + 桌面 golden test baseline 不变

总测试数预期：1235 → ~1260 pass（+25 个新用例），baseline 失败保持 8 个。

### 6.7 CI 状态

**手动 CI**（不变）：
- 每个 commit 前：dart analyze + dart test
- 每个发版前：桌面 widget test + golden test + 真机 smoke
- **不引入 Gitee Actions 自动化 CI**（推到 S3 或后续 spiral）

---

## 7. 实施顺序与里程碑

### 7.1 v1.9.1-alpha（hotfix，~2 天）

```
Day 1:
  T1: UX-A chrome tap-toggle bug fix + widget test (5 用例)
  T2: UX-B chrome auto-hide timer + hideChrome() + widget test (6 用例)
  T3: UX-C mobile compact margin default + widget test (5 用例)
  T4: 桌面回归测试（确保 chromeVisible 桌面 true 不变 + golden 不变）

Day 2:
  T5: pubspec/CHANGELOG/README/release-notes bump → v1.9.1-alpha
  T6: build APK + installer
  T7: 真机 smoke (5 min)
  T8: tag v1.9.1-alpha + push + Gitee Release（等用户决定上传时机）
```

### 7.2 v1.10.0-alpha（正式，+4-5 天）

```
Day 3:
  T9:  AI-D BottomSheet scaffold + widget test (5 用例)
  T10: AI-E IME padding + widget test (3 用例)
  T11: AI-F Scaffold audit + audit test (1 用例)

Day 4:
  T12: PLG-G plugin upgrade Step 1: connectivity_plus / flutter_secure_storage / just_audio
  T13: PLG-G plugin upgrade Step 2: file_picker (最高风险)
  T14: PLG-G plugin upgrade Step 3: webview_flutter

Day 5:
  T15: PLG-H 移除 sed 补丁文档
  T16: 全量回归 + analyze
  T17: pubspec/CHANGELOG/README/release-notes bump → v1.10.0-alpha
  T18: build APK + installer

Day 6 (或用户当晚):
  T19: 真机 smoke (20 min)
  T20: tag v1.10.0-alpha + push + Gitee Release
```

---

## 8. 风险与未决项

### 8.1 已识别风险

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| file_picker 10.x API 大改 | 高 | 1 天返工 | 独立 commit + 详细 grep + revert 兜底 |
| BottomSheet 在某些机型键盘弹起行为异常 | 中 | 0.5 天调试 | 真机 smoke 暴露 + 用户实测机型反馈 |
| 3s timer 在低端机型 ANR 时表现异常 | 低 | 0.5 天调试 | paused 时 cancel + dispose cancel 双保险 |
| plugin 升级后某个桌面 widget test 失败 | 中 | 0.5 天 | 桌面回归测试每次都跑 |
| 用户出差/没空跑真机 smoke | 高 | tag 时间推迟 | 不阻塞代码推进，tag 时间灵活 |

### 8.2 未决项（无）

所有 6 个 section 都已通过用户 review，无未决项。

---

## 9. 验收标准

### 9.1 v1.9.1-alpha 验收

- [ ] UX-A widget test 5 用例全绿
- [ ] UX-B widget test 6 用例全绿
- [ ] UX-C widget test 5 用例全绿
- [ ] 桌面 widget test 全绿（无回归）
- [ ] 桌面 golden test baseline 不变
- [ ] dart analyze 0/0/0
- [ ] dart test 全套：~1251 pass + 3 skipped + 8 baseline 失败
- [ ] 真机 smoke v1.9.1 步骤 1-10 全 ✓
- [ ] tag v1.9.1-alpha pushed

### 9.2 v1.10.0-alpha 验收

- [ ] AI-D widget test 5 用例全绿
- [ ] AI-E widget test 3 用例全绿
- [ ] AI-F audit test 1 用例全绿
- [ ] 5 plugin 升 latest stable，pubspec.lock 更新
- [ ] sed 补丁段从 docs 移除
- [ ] flutter build apk --release 无需 sed 补丁也能编
- [ ] 桌面 widget test 全绿（无回归）
- [ ] 桌面 golden test baseline 不变
- [ ] dart analyze 0/0/0
- [ ] dart test 全套：~1260 pass + 3 skipped + 8 baseline 失败
- [ ] 真机 smoke v1.10.0 步骤 1-12 全 ✓
- [ ] tag v1.10.0-alpha pushed

---

## 10. 下一步（S3）

S2 交付后，S3 候选范围：

- WebDAV 统一收尾 + 桌面端 sync 实战补强（原 S3 计划）
- iOS build + CI（如果用户获得 Mac）
- Android 模拟器 CI（GitHub Actions / Gitee CI）
- 手势导航（Android 返回键 / 长按菜单 / 分享 sheet）
- EPUB 双页渲染层（桌面 v1.6 遗留）

具体范围 S2 结束后再 brainstorm。

---

## 附录 A：相关文档

- S1 spec: `docs/superpowers/specs/2026-07-10-mobile-mvp-s1-design.md`
- Pre-mobile cleanup: `docs/superpowers/specs/2026-07-09-pre-mobile-deep-cleanup-design.md`
- Phase 2 roadmap: `docs/superpowers/specs/2026-06-28-phase2-roadmap-design.md`
- Release procedure: `docs/release-procedure.md`
- Maintainers runbook: `docs/maintainers-runbook.md`
- Android SDK setup: `docs/setup-android-sdk.md`

## 附录 B：决策日志

| 决策点 | 选项 | 用户决策 | 日期 |
|---|---|---|---|
| S2 范围 | A 按原计划 / B 只 plugin / C 扩 polish / D 最小可发版 | A | 2026-07-10 |
| Reader chrome 修复 | A 默认显示 / B 隐藏+提示 / C 双保险 / D 不改 | 用户提供新设计：tap bug + 3s 自动隐藏 + margin | 2026-07-10 |
| Margin 迁移 | A 只新书 / B 批量 / C 弹窗 | A（用户已自调，无影响） | 2026-07-10 |
| Plugin 升级 | A latest / B 最小 36 / C hook 自动化 | A | 2026-07-10 |
| AI 抽屉形态 | A 保留 Drawer / B BottomSheet / C 混合 / D 澄清 | B | 2026-07-10 |
| S2 验收 | A 含真机 smoke / B build+tag / C 加 CI | A | 2026-07-10 |
| 执行策略 | A 双 tag / B 单 tag / C 并行 | A | 2026-07-10 |
