# 移动端 MVP Spiral 1 (S1) Design Spec

**日期**：2026-07-10
**作者**：wf + Claude（brainstorming session）
**前置**：深度清理完成 + tag `desktop-stable-pre-mobile`（commit `2b364d4`）
**目标读者**：S1 期间的执行者（subagent）+ 未来的维护者
**Tag 目标**：`m-mobile-s1-complete` + `v1.8.0-alpha`
**总体路线**：移动端 MVP 切 3 个 spiral（S1 依赖/响应式 → S2 AI 适配 → S3 WebDAV 统一收尾），每 spiral 独立 spec → plan → 实施 → tag

---

## 1. 目标

把智阅从"桌面端 GA（v1.7.1-alpha）"推进到"Android 端 MVP 可用"的中间态：**S1 让 reader + library + notes + settings 在 Android 上能跑、布局自适应，桌面行为 byte-for-byte 不变**。

**完成态**（双轨）：
- Android：debug APK 在 emulator + 真机能 install + 启动 + 进入 library + 打开 EPUB/PDF + 加高亮 + 写笔记 + 设置字体
- 桌面：回归 812+ tests 全过，1100 双页 / hover / exit(0) 时序 / window chrome 行为 100% 保留

**不在 S1 完成态**（推后）：
- AI 输入框 IME 完整适配 → S2
- WebDAV 移动端 sync 适配 → S3
- iOS build / macOS CI → S3 之后
- Play Store 发布 → 永不（sideload only）

---

## 2. 三 Spiral 拆分（移动端 MVP 全景）

| Spiral | 范围 | 估时 | tag |
|---|---|---|---|
| **S1（本 spec）** | 依赖适配 + 抽象层补齐 + 响应式 UX + reader/library 上 Android + iOS 目录占位 | ~2 周 | `m-mobile-s1-complete` + `v1.8.0-alpha` |
| S2 | AI 适配（IME / 流式 sheet / 软键盘避让） | ~1 周 | `v1.9.0-alpha` |
| S3（最后） | WebDAV 统一收尾：移动端 sync 适配（WorkManager + Keystore 已有 + 移动网络感知）+ 桌面端 sync 实战补强（2 台真机验证）+ 跨平台 sync 集成测试 | ~2 周 | `v2.0.0-alpha` |

**为什么 sync 放最后**：
- 桌面端 sync 核心代码已就绪（M2.0a 单向 push + M2.0b 双向冲突，617 tests），S3 不重写桌面
- 把它放最后，避免 S1/S2 期间被 sync 集成 bug 拖累
- 桌面端实战补强 + 移动端接入合并，一次跨端验证

**为什么 AI 在中间**：
- AI 已有完整桌面实现（M1.5a + M1.5b/c + M2.7），S2 只补 IME / 软键盘避让
- 工作量最小（~1 周），可以快速进入 S3

---

## 3. S1 范围（YAGNI 严格）

### 3.1 包含

- `flutter create . --platforms=ios,android`（android 已有，补 ios 目录占位）
- `ResponsiveLayoutBuilder` 自研（compact < 600 / medium 600-840 / expanded ≥ 840，M3 标准）
- `PlatformChromeController` 新建（仅 status bar style + orientation lock，~50 行）
- 重构 1100px 双页阈值硬编码（reader_body.dart 4 处）→ 抽常量 `kDesktopDualPageBreakpoint`
- 响应式 UX 矩阵改造（library / reader top bar / sidebar→drawer / AI panel→endDrawer / notes list / settings nav）
- `_openFolder` mobile 隐藏（library_page.dart + notes_page.dart，2 处）
- iOS Info.plist 占位（CFBundleDisplayName + LSItemContentTypes）
- Android 真机 smoke test + 桌面回归 100% 通过
- iOS 目录 scaffold（不 build 不 CI）

### 3.2 不包含（推到 S2/S3 或之后）

| 推后项 | 去向 |
|---|---|
| AI 输入框 IME 适配 | S2 |
| WebDAV WorkManager 后台同步 | S3 |
| 桌面端 sync 实战补强 | S3 |
| iOS 实测 + macOS CI | S3 之后 |
| Play Store 发布 | 永不（sideload only） |
| Android 12 SplashScreen API | v1.8.1 polish |
| 平板横竖屏切换动画 polish | v1.8.1 polish |
| Golden 测试 Android 渲染 | 永不做（渲染抖动维护贵） |
| APK ABI 拆分 / App Bundle | 永不做（sideload 单 APK） |

### 3.3 关键既有资产（不需要重做）

- ✅ `FullscreenController` 抽象（`reader/controllers/fullscreen_controller.dart`）+ Desktop/Mobile/Noop 三实现 + provider 按 `defaultTargetPlatform` 分流（`reader_ui_controller.dart:131-146`）
- ✅ AndroidManifest intent-filter（M7 已配 .epub/.pdf）
- ✅ Android app label = "智阅"（M7）
- ✅ Android signing fallback to debug（M7）
- ✅ BookOpenBridge MethodChannel（M7，已支持 Android cold/warm start）
- ✅ Material 3 主题
- ✅ drift 配置天然兼容 Android（`getApplicationDocumentsDirectory` 自动指向 `/data/data/<app>/files`）

**S1 不重做以上任一项**。

---

## 4. 依赖适配扫描

### 4.1 依赖平台支持矩阵

| 依赖 | Android | iOS | 备注 |
|---|---|---|---|
| `window_manager` ^0.4.3 | ❌ | ❌ | desktop only，mobile 不进初始化分支 |
| `flutter_secure_storage` ^9.2.2 | ✅ Keystore | ✅ Keychain | API 19+ 默认 |
| `file_picker` ^8.1.2 | ✅ SAF | ✅ doc picker | 已配 |
| `connectivity_plus` ^6.0.5 | ✅ | ✅ | 需 ACCESS_NETWORK_STATE 权限（M2.0b 已加） |
| `sqlite3_flutter_libs` ^0.5.24 | ✅ | ✅ | drift 自动处理 isolate |
| `pdfrx` ^2.3.0 | ✅ PDFium | ✅ PDFium | native lib 自动打包 |
| `epubx` (patched) | ✅ pure Dart | ✅ pure Dart | |
| 其他全部 | ✅ | ✅ | 全平台 |

**结论**：唯一需要分流的 `window_manager` 已经在 main.dart 和 fullscreen_controller.dart 做好了，**S1 依赖层零改动**。

### 4.2 现有平台硬编码 4 处扫描

| 文件 | 行 | 现状 | S1 改造 |
|---|---|---|---|
| `main.dart` | 61-72 | desktop-only windowManager init + WindowCloseHandler | **无需改**（mobile 不进 if 分支） |
| `reader_ui_controller.dart` | 131-146 | FullscreenController provider 按 platform 分流 | **无需改**（已分好 Desktop/Mobile/Noop） |
| `library_page.dart` | 334 | `_openFolder` 仅 Windows/macOS/Linux | 加 mobile 分支：隐藏"打开所在文件夹"按钮 |
| `notes_page.dart` | 460 | 同上 | 同上 |

**关键：4 处硬编码里 2 处已分好，剩 2 处是同一个 `_openFolder` 工具方法，改造工作量极小。**

---

## 5. 抽象层设计

### 5.1 新建文件（2 个）

#### 5.1.1 `app/lib/core/responsive_layout_builder.dart`（~80 行）

```dart
enum WindowSizeClass { compact, medium, expanded }  // M3 标准

class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext, WindowSizeClass) builder;
  // 包装 LayoutBuilder，按 maxWidth 映射到三档
}

WindowSizeClass windowSizeClassOf(BuildContext context);  // 类 Theme.of(context)

// 桌面双页阈值常量（保留桌面 GA 行为，不与 WindowSizeClass 耦合）
const double kDesktopDualPageBreakpoint = 1100;
```

**断点定义**：
- compact：< 600（手机竖屏）
- medium：600-840（平板竖屏 / 手机横屏）
- expanded：≥ 840（平板横屏 / 桌面）

**为什么自研 vs 用 `responsive_framework`/`adaptive_scaffold`**：
- 避免引入新依赖
- M3 断点严格对齐
- 桌面 1100 阈值需要作为独立常量与 WindowSizeClass 共存（桌面行为不变约束）
- 自研 80 行可控

#### 5.1.2 `app/lib/services/platform/platform_chrome_controller.dart`（~50 行）

```dart
abstract class PlatformChromeController {
  void setStatusBarStyle({required Brightness brightness});
  Future<void> setPreferredOrientations(List<Axis> axes);
}

class DesktopPlatformChromeController implements PlatformChromeController {
  // noop：desktop 无 status bar 概念
}

class MobilePlatformChromeController implements PlatformChromeController {
  // 委托 SystemChrome
}
```

**为什么这么薄**：
- IME padding 推 S2（AI 输入适配时一起做）
- Theme 跟随系统 Flutter 自带（SystemUiMode.edgeToEdge + Theme.brightness）
- Window chrome（title bar 等）只在 desktop 用 window_manager 直接调，不需要抽象（YAGNI）
- 用途：移动端阅读时沉浸式 status bar + 锁定 reader 内允许横屏

### 5.2 不新建（已有）

- `FullscreenController`（`reader/controllers/fullscreen_controller.dart`）—— 不动

---

## 6. 响应式 UX 决策矩阵

### 6.1 整体策略

**单一判定原则**：每个页面用 `windowSizeClassOf(context)` 选 layout 分支；桌面精确阈值（如 1100px 双页）保留为常量 `kDesktopDualPageBreakpoint`，不与 WindowSizeClass 耦合。

**移动端"功能完整"原则**：手机上不裁剪功能，只重排布局（YAGNI 反对：为了"简化"砍掉桌面已有功能，反而要做两套 UX）。

### 6.2 Library 页面

| 元素 | compact (<600) | medium (600-840) | expanded (≥840) | 桌面现状 |
|---|---|---|---|---|
| 书籍布局 | grid 2-3 列 | grid 3-4 列 | grid 4-6 列 | grid 自适应 |
| App bar | 标题 + hamburger + 导入 icon | 标题 + 搜索 icon + 导入 | 完整 search bar inline + hover actions | 同 expanded |
| 标签筛选 | hamburger → Drawer | Drawer | sidebar 常驻（左侧 200px） | 同 expanded |
| 排序/视图切换 | overflow menu | overflow menu | top bar actions 直接 | 同 expanded |
| 长按书 | context menu | 同 | 同 + 右键 | hover + 右键 |
| 导入 | top bar icon | top bar icon | top bar icon | top bar icon |
| `_openFolder` 按钮 | **隐藏** | 显示 | 显示 | 显示 |

**改动文件**：`library_app_bar.dart`（compact 分支）+ `library_page.dart`（sidebar/drawer 切换 + `_openFolder` mobile 隐藏）。

### 6.3 Reader 页面（reader_body.dart 已有 LayoutBuilder 基础）

| 元素 | compact (<600) | medium (600-840) | expanded (≥840) | 桌面 ≥1100 现状（保留） |
|---|---|---|---|---|
| 单页/双页 | 单页 | 单页 | 单页 | **双页**（保留 1100 阈值常量） |
| TOC/sidebar | Scaffold.drawer 滑出 | Scaffold.drawer 滑出 | Scaffold.drawer 滑出 | sidebar 常驻 280px |
| AI panel | endDrawer 全屏 sheet | endDrawer 半屏 (304-360px) | endDrawer 半屏 | inline panel 380px |
| Top bar | tap 切换显隐 | tap 切换 | hover + tap | hover |
| Selection toolbar | 不变 | 不变 | 不变 | 不变 |
| 章节结束提示 | bottom sheet | bottom sheet | bottom sheet | bottom sheet |
| 书签 FAB | 右下 | 右下 | 右下 | 右下 |
| 排版 panel | bottom sheet（不变） | bottom sheet | bottom sheet | bottom sheet |
| ESC 全屏切换 | 不适用 | 不适用 | 不适用 | 保留 |

**决策 1：mobile 平板横屏（≥1100）启用双页**
- 1100px 阈值常量在所有平台一致生效
- 平板横屏自然进入双页模式
- "桌面行为 100% 保留"指桌面行为不变，不限制 mobile 模仿

**决策 2：Reader top bar mobile tap-to-toggle**
- 桌面：hover 显示 chrome（已有）
- Mobile：tap center 区域切换 chrome 显隐（新增）
- 实现复用已有 `chromeVisible` state，只是触发源增加 tap

**改动文件**：`reader_body.dart`（top bar tap 触发 + 常量提取，~30 行）。

### 6.4 Notes 页面

| 元素 | compact | medium | expanded | 桌面现状 |
|---|---|---|---|---|
| 布局 | 单栏（list push detail） | 单栏 | 双栏 master-detail | 双栏 |
| 筛选/搜索 | top bar icon push | top bar icon push | inline panel | inline panel |
| `_openFolder` 按钮 | **隐藏** | 隐藏 | 显示 | 显示 |

**改动文件**：`notes_page.dart`（LayoutBuilder 切单栏/双栏 + `_openFolder` mobile 隐藏，~30 行）。

### 6.5 Settings 页面

| 元素 | compact | medium | expanded | 桌面现状 |
|---|---|---|---|---|
| 布局 | 单栏（list push detail） | 单栏 | 双栏（nav + pane） | 双栏 |

**改动文件**：`settings_page.dart`（LayoutBuilder 切换，~30 行）。

### 6.6 AI chat panel（ai_drawer_widget.dart）

| 元素 | compact | medium | expanded | 桌面现状 |
|---|---|---|---|---|
| 形态 | endDrawer（全屏宽度 ≈304） | endDrawer（304） | endDrawer（360） | inline panel 380px |
| 输入框 | 顶部 + 软键盘避让（S2 完善 IME） | 同 | 同 | 顶部固定 |
| 流式消息 | 不变 | 不变 | 不变 | 不变 |

**S1 不动 IME 适配**，仅确保 endDrawer 在 mobile 渲染正常。

### 6.7 改动总览

| 文件 | 改动量 | 类型 |
|---|---|---|
| `responsive_layout_builder.dart` | 新建 ~80 行 | 抽象层 |
| `platform_chrome_controller.dart` | 新建 ~50 行 | 抽象层 |
| `reader_body.dart` | ~30 行：top bar tap 触发 + 常量提取 | 改 |
| `library_app_bar.dart` | ~40 行：compact 分支 | 改 |
| `library_page.dart` | ~30 行：sidebar/drawer 切换 + `_openFolder` mobile 隐藏 | 改 |
| `notes_page.dart` | ~30 行：单栏/双栏 + `_openFolder` mobile 隐藏 | 改 |
| `settings_page.dart` | ~30 行：单栏/双栏 | 改 |
| `ios/Runner/Info.plist` | 新建 + 占位（`flutter create` 后改） | 占位 |
| `ios/...`（其他） | `flutter create` 默认生成 | 占位 |

---

## 7. 测试策略

### 7.1 单元测试（新建 class 都加）

- `responsive_layout_builder_test.dart`：测三档断点边界（599/600/839/840）+ `windowSizeClassOf`
- `platform_chrome_controller_test.dart`：Desktop noop + Mobile impl（mock SystemChrome platform channel）

### 7.2 Widget 测试（每个改造页面加 2 视口）

- iPhone 14 视口 `Size(390, 844)` — compact 路径
- iPad 横屏视口 `Size(1190, 844)` — expanded 路径
- 桌面回归：现有所有 widget test 在 `Size(800, 600)` / `Size(1200, 800)` 跑（不变）

具体新增：
- `library_page_test.dart`：compact hamburger + drawer、expanded sidebar
- `notes_page_test.dart`：单栏 push / 双栏 master-detail
- `settings_page_test.dart`：单栏 push / 双栏 nav
- `reader_body_responsive_test.dart`：compact/medium tap-to-toggle + drawer AI panel + expanded sidebar
- `_openFolder` mobile 隐藏按钮断言（library + notes 各 1 测试）

### 7.3 Golden 测试

**mobile 永不加新 golden**。理由：
- Android 渲染字体微差 + emulator 渲染抖动，golden 维护成本高
- 已记录在 memory：[智阅 mobile MVP 启动] 决策

### 7.4 Integration 测试（可选）

- `app/integration_test/android_smoke_test.dart`：启动 → library → 打开 EPUB → 翻页 → 加高亮 → 退出
- 仅用户本地手动跑（emulator 启动慢、CI 跑贵），spec 写但默认 skip

### 7.5 桌面回归套件

所有现有 widget test 全跑一遍（812+ tests + 4 skip 基线），S1 完成时不得新增 fail。改造前先跑一遍录 baseline，每个改造 commit 后回归。

---

## 8. 风险清单

| # | 风险 | 等级 | 影响 | 缓解 |
|---|---|---|---|---|
| R1 | 中文路径 build Android APK | HIGH | apk build 卡死 | 在 worktree `C:\zhiyue_build` 跑 build（同 Windows build 流程），不在主仓 build |
| R2 | `window_manager` import 在 mobile 编译失败 | MED | 编译错 | 验证 import 是否纯 Dart；若失败改 conditional import（`if (platform.dart)` 静态分支） |
| R3 | pdfrx PDFium native lib 体积（apk +30-50MB） | MED | apk 体积大 | **S1 用单 APK**（用户决策），ABI 拆分推后；评估体积，若 > 80MB 警告 |
| R4 | reader 双页阈值 `kDesktopDualPageBreakpoint=1100` 在 mobile 平板触发，回归测试可能漏 | MED | 平板横屏双页未测 | widget test 加 iPad 横屏 1190 视口用例 |
| R5 | iOS 目录在 Windows 上 `flutter create` 失败 | LOW | iOS 占位无法生成 | 用 `flutter create --platforms=ios .` 静默生成；若失败用子目录 workaround |
| R6 | `file_picker` 在 Android 用 SAF，URI 处理和 Windows 文件路径不同 | MED | 导入失败 | 已有 MethodChannel `BookOpenBridge`（M7）处理 content URI copyToCache；S1 加 Android 真机验证导入 |
| R7 | 桌面 hover 行为被响应式改造破坏 | MED | 桌面回归 fail | 改造前先跑一遍桌面 widget test 录 baseline，每个改造 commit 后回归 |
| R8 | SystemUiMode 在 Android 进程切换时状态不一致 | LOW | 全屏退出残留 | MobileFullscreenController.exit 用 `edgeToEdge` 强制恢复；widget test 验证 |
| R9 | Android 模拟器/emulator 渲染慢导致 widget test flaky | LOW | CI flake | 仅手动跑 emulator，CI 跑纯 widget test（无需 emulator） |

---

## 9. iOS 占位策略（YAGNI）

- `flutter create . --platforms=ios`（不签 Xcode 协议，用户无 Mac 跑不了）
- 改 `Info.plist`：
  - `CFBundleDisplayName = 智阅`
  - `LSItemContentTypes` 加 `org.idpf.epub-container` + `com.adobe.pdf`
- **不动**：Xcode project settings、signing、capabilities
- 不在 S1 加 macOS CI（推迟 S3 之后）

**未来 iOS 暴露的问题留给 S3 之后的 iOS spec 处理**，S1 只保证 iOS 目录就位 + Info.plist 占位。

---

## 10. 验收标准（S1 完成定义）

### 10.1 必须

- [ ] Android debug APK 在 emulator（Pixel 5 / 1080x2340）能 install + 启动
- [ ] **真机 smoke test**（用户手动跑）：用户 Android 手机 install APK → library → 导入 EPUB → 打开 → 翻页 → 加高亮 → 写笔记 → 切字体 → 设置 → 退出（截图为证）
- [ ] PDF 在 Android 真机能打开（pdfrx PDFium native 验证）
- [ ] 桌面回归 100% 通过（812+ tests，5 pre-existing failure 不算新增）
- [ ] iPhone 视口（390x844）+ iPad 横屏（1190x844）widget test 全过
- [ ] dart analyze 零 error
- [ ] dart test 全过（除 pre-existing skip）
- [ ] 桌面行为 byte-for-byte 不变（1100 双页 / hover / exit(0) 时序 / window chrome）
- [ ] iOS 目录就位（`flutter create --platforms=ios .`）+ Info.plist 改 displayName + UTI
- [ ] tag `m-mobile-s1-complete` + `v1.8.0-alpha`，push Gitee
- [ ] CHANGELOG 加 v1.8.0-alpha 段
- [ ] README badge bump 1.8.0-alpha + 项目状态加"Android MVP"

### 10.2 不在 S1 范围（推后）

- AI 输入框 IME 完整适配（S2）
- WebDAV 后台 sync（S3）
- iOS build / CI（S3 后）
- Play Store 发布（永不做，sideload only）
- Golden Android 渲染（永不做）
- Android 12 SplashScreen（v1.8.1 polish）
- APK ABI 拆分优化（永不做，sideload 单 APK）

---

## 11. 任务估算（plan 阶段细化）

预估 **18-22 个 TDD 任务**（T0-T21/T22），按以下顺序：

### 阶段 A：基础抽象层（T1-T5）
- T1：新建 `ResponsiveLayoutBuilder` + 单测
- T2：新建 `PlatformChromeController` + 单测
- T3：抽 `kDesktopDualPageBreakpoint` 常量，替换 reader_body.dart 4 处硬编码
- T4：iOS 目录 `flutter create --platforms=ios .` + Info.plist 改
- T5：commit baseline（桌面回归测试通过）

### 阶段 B：Library 改造（T6-T8）
- T6：`library_app_bar.dart` 加 compact 分支（hamburger + drawer）
- T7：`library_page.dart` sidebar/drawer 切换 + 单/双栏布局
- T8：`_openFolder` mobile 隐藏 + widget test

### 阶段 C：Reader 改造（T9-T12）
- T9：`reader_body.dart` top bar tap-to-toggle（mobile）
- T10：drawer/endDrawer 在 compact/medium/expanded 三档验证
- T11：reader_body_responsive_test.dart 加 iPhone 14 + iPad 横屏用例
- T12：AI panel endDrawer 在 compact/medium 视口渲染验证 + 加 widget test 用例（不重写 AI panel，只断言渲染正确）

### 阶段 D：Notes + Settings 改造（T13-T16）
- T13：`notes_page.dart` 单栏-双栏切换
- T14：`_openFolder` mobile 隐藏（notes）
- T15：`settings_page.dart` 单栏-双栏切换
- T16：notes + settings widget test 加 2 视口

### 阶段 E：Android 集成（T17-T19）
- T17：AndroidManifest 验证（intent-filter + 权限）
- T18：APK build 在 `C:\zhiyue_build` worktree（避开中文路径）
- T19：emulator + 真机 smoke test

### 阶段 F：回归 + 发布（T20-T22）
- T20：桌面全套回归（812+ tests）
- T21：dart analyze + dart test 全过
- T22：tag `m-mobile-s1-complete` + `v1.8.0-alpha` + CHANGELOG + README + push Gitee

每个 task 独立 commit + subagent 两阶段 review（spec compliance → code quality）。

---

## 12. 开放问题（推迟到 plan 阶段或后续 spiral）

| 问题 | 推迟到 |
|---|---|
| mobile reader 翻页手势（左右滑动 vs 点击左右区域）是否启用？ | plan 阶段（倾向：保留 EPUB paged 模式默认左右滑动） |
| mobile 长按书 context menu 是否改 bottom sheet（更"原生"）？ | plan 阶段（倾向：保留 context menu，YAGNI） |
| APK 体积若 > 80MB 是否启用 ABI 拆分？ | S1 末评估（倾向：单 APK，体积可接受） |

---

## 13. 执行模型

- **每个 task = 1 个 implementer subagent + 两阶段 review**（spec compliance → code quality）
- 每 commit 推 Gitee（既有规则）
- subagent 模型分配：14-18 点用 haiku，其他时段 opus；iOS/Kotlin/Gradle 用 sonnet
- 每 phase 完成交付物：代码 + 测试 + commit
- S1 完成时一次性 tag + bump + push

---

## 14. 风险升级触发

- 若 R1 中文路径在 Gradle build 卡死超过 4 小时 → 升级到主线程，考虑 worktree 子目录深度 workaround
- 若 R3 APK 体积 > 100MB → 升级到用户，决策是否启用 ABI 拆分
- 若 R6 file_picker 在 Android 真机导入失败 → 升级到用户，决策是否改用 SAF dedicated picker
- 若 S1 工期超 3 周（基线 2 周）→ 升级到用户，决策是否拆 S1 为 S1a/S1b

---

**Spec 状态**：Draft，待用户 review 后转 writing-plans skill 写 implementation plan。
