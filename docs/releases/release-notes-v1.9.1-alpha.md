# 智阅 v1.9.1-alpha Release Notes

**发布日期**：2026-07-11
**性质**：hotfix（移动端 UX 三连修复，无新功能 / 无 schema 变更）
**Tag**：`v1.9.1-alpha`
**桌面稳定锚点**：`desktop-stable-pre-mobile`（不变）

## 概述

v1.9.0-alpha 上线后真机/上手测试发现 3 个移动端 UX 阻塞问题，本版作为
hotfix 全部修复。桌面端行为完全不受影响（无新功能、无回归）。

## 修复

### UX-A：移动端 chrome tap-toggle 回归

- **症状**：在 v1.8.0-alpha 中 reader 区 tap 可唤出 / 隐藏 top chrome；
  v1.9.0-alpha 用户反馈「tap 唤出 chrome 后再 tap 无法隐藏」。
- **根因**：`reader_body.dart` 中 `GestureDetector` 被埋进
  `SelectableRegion`，selection region 先消费 tap 事件导致 toggle 失效。
- **修复**：把 `Listener` 提到 Stack 顶层（在 selection region 之外）；
  使用 18px 拖拽阈值区分 tap vs drag（避免左右翻页与 chrome toggle 互扰）；
  豁免 AppBar 命中区域（避免误触返回/收藏按钮反而触发 toggle）。

### UX-B：打开书后 chrome 默认可见 + 3s 自动隐藏

- **症状**：v1.8.0-alpha 起移动端 reader 默认 chrome 隐藏（`chromeVisible=false`），
  新用户打开书后完全不知道有 AppBar（书签 / TOC / AI 抽屉）可用，上手成本极高。
- **修复**：
  - `ReaderUiState.defaultsForPlatform()` 平台分支：移动 `chromeVisible=true`
    （桌面同 true，行为不变）
  - 打开书后启动 3s 计时器，到点调用 `ReaderUiController.hideChrome()`
  - 取消计时触发器：任意用户交互（tap / scroll / selection）、
    app 进入后台（`WidgetsBindingObserver.didChangeAppLifecycleState`）、
    controller dispose
  - 新增 `hideChrome()` 方法（区别于 `toggleChrome`，幂等且语义明确）
- **影响范围**：仅移动端；桌面端不启动计时器，chrome 保持持久可见。

### UX-C：移动端默认页边距 wide → compact

- **症状**：v1.8.0-alpha 起移动新书默认页边距沿用桌面 `wide=72px`，
  手机小屏（如 360dp 宽）双 72px 边距后可读宽度只剩 ~216px，文字过窄。
- **修复**：
  - `resolveDefaultTypography()` 平台分支：移动新书默认 `compact=8px`，
    桌面默认仍 `wide=72px`
  - 已存在书目保留其持久化的 margin（向后兼容，无静默变更）
  - 用户仍可在排版面板手动切换 narrow/normal/wide/extraWide/compact
- **影响范围**：仅影响首次打开的「新」书目；存量书目零变更。

## 新增基础设施

> 以下均为支持上述 UX 修复的内部助手，不暴露用户可见行为。

- `PlatformInfo.isMobile` / `isDesktop`（`lib/core/platform_info.dart`）
  - 尊重 `debugDefaultTargetPlatformOverride` 以便 widget 测试覆盖
- `ReaderUiController.hideChrome()`（独立于 `toggleChrome`）
- `ReaderUiState.defaultsForPlatform()` 工厂
- `ReaderUiController` 接受可选 `initialState` 参数（提升可测试性）
- `resolveDefaultTypography()` 纯函数助手（按平台分支 margin 默认）

## Commit 清单（v1.9.0-alpha 之后）

- `785e9eb` feat(core): add PlatformInfo helper for isMobile / isDesktop (T1)
- `6283288` feat(reader): add ReaderUiController.hideChrome for UX-B auto-hide (T2)
- `815169e` feat(reader): ReaderUiState.defaultsForPlatform() for UX-B chrome default (T3)
- `45301ed` feat(reader): wire readerUiControllerProvider to defaultsForPlatform (T4)
- `f912fd3` fix(reader): chrome tap-toggle uses Stack-top Listener (UX-A / T5)
- `0373ae7` feat(reader): 3s chrome auto-hide on mobile (UX-B / T6)
- `7ce79f1` feat(reader): mobile default margin = compact (UX-C / T7)

## 测试覆盖

新增 23 个测试（v1.9.0-alpha 之后）：

- `platform_info_test.dart`（2）：isMobile / isDesktop 各平台分支
- `reader_ui_controller_test.dart`（+3）：hideChrome 幂等 / 与 toggle 互操作 / 已隐藏态 no-op
- `reader_ui_state_defaults_test.dart`（2）：defaultsForPlatform 桌面/移动分支
- `reader_scaffold_chrome_toggle_test.dart`（5）：UX-A tap 唤出后 tap 可隐藏 / 拖拽阈值 / AppBar 命中豁免 / 桌面无 toggle
- `reader_chrome_auto_hide_test.dart`（5）：UX-B 计时器触发 / 用户交互取消 / app 后台取消 / dispose 取消 / 桌面不启动计时
- `typography_default_margin_test.dart`（6）：UX-C 移动新书 compact / 桌面新书 wide / 存量书目保留持久化值 / 平台 override 互操作

完整回归：**1260 pass / 3 skip / 10 baseline fail**（详见下节）。

## 已知问题

10 个 pre-existing 测试失败（v1.8.0-alpha 12 baseline 中 library_golden_test
4 已在 T7 修复 regen，剩 8；本轮 UX-C 又新增发现 2 个 reader 相关 baseline
漂移，全部反向验证为本 hotfix 之前就存在）：

- `router_test` 1
- `reader_page_test` 4
- `reader_flow_integration` timeout 1
- `reader_page_pdf_integration` load 1
- `reader_ai_drawer_integration` load 1
- `library_golden_test` 2（pre-existing 字体漂移）

具体清单与 baseline 来源参见
[`docs/baselines/`](../baselines/)（如有）与本 commit PR 评论。

其它沿用 v1.9.0-alpha：

- iOS 仍为 scaffold（无 Mac 无法 build）
- APK 单包不拆 ABI（50-80 MB release，含 PDFium）
- 5 plugin pub-cache `sed` 补丁仍需手动执行（S2 升级 plugin 默认 compileSdk 36）
- Golden 测试不覆盖 Android 渲染

## 升级指南

- **桌面**：直接覆盖安装，无 schema 变更（v1.9.0-alpha 的 v13 schema 沿用）
- **Android**：sideload 新 APK；无 schema 变更
- **WebDAV**：协议未变，无需重新登录

## 截图

> 本版为 hotfix，未重新截图；UX-A/B/C 三项可参考真机演示。
> 完整截图矩阵见 [`docs/screenshots/README.md`](../screenshots/README.md)。

## 下载

> 待 T10 build 产出 artifact 后补充链接；T12 tag 后 Gitee Release 页生效。

- Windows 安装包：`zhiyue-setup-1.9.1-alpha.exe`（待补）
- Windows 便携版：`zhiyue-portable-1.9.1-alpha.zip`（待补）
- Android APK：`zhiyue-1.9.1-alpha.apk`（待补）

## 下一节点

S2 Part 2：5 plugin 升级（compileSdk 36 默认）+ IME / 软键盘深度适配
+ 全屏模式安全区 → v1.10.0-alpha。
