# 智阅 v1.9.2-alpha Release Notes

**发布日期**：2026-07-11
**性质**：hotfix（v1.9.1-alpha 真机上手测试发现的 5 个移动端 bug 全闭，无新功能 / 无 schema 变更）
**Tag**：`v1.9.2-alpha`
**桌面稳定锚点**：`desktop-stable-pre-mobile`（不变）

## 概述

v1.9.1-alpha 推送后用户在 Android 真机上手测试，发现 5 个阻塞问题：
同步换账号失败、AI 入口在移动端不可达、抽屉覆盖状态栏、AI 抽屉过窄。
本版作为 hotfix 把 5 个 bug 全部修复。桌面端行为不受影响（无新功能、无回归）。

## 修复

### Bug 1：坚果云同步换账号后报 409 AncestorsNotFound

- **症状**：v1.9.1-alpha 在「账号设置」里换了新账号（新应用密码）后，同步按钮
  显示「同步失败」，错误：`WebDavException(409 at /zhiyue/snapshots/<deviceId>.jsonl):
  ...<s:exception>AncestorsNotFound</s:exception>`。
- **根因**：`WebDavSyncEngine.pushOnly` 在初始 GET 失败时只 catch `404`（文件
  不存在）。但**坚果云对「父目录不存在的文件」GET 会返回 409**（与 RFC 推荐的
  404 不同）。新账号根目录下没有 `/zhiyue/snapshots/`，GET 直接 409 → catch
  不命中 → rethrow → 同步永远到不了 `ensureAncestors` 那一步。
- **修复**：catch 404 OR 409，都视作 firstPush。新增 regression test 模拟
  用户报告里完整的坚果云 409 XML 响应体。

### Bug 2a：移动端 AppBar AI 图标点击无反应

- **症状**：v1.9.1-alpha 在 Android 真机点击阅读页 AppBar 的「AI 抽屉」图标
  （`smart_toy_outlined`），抽屉不打开。
- **根因**：`_toggleAiDrawer` 实现只翻转 `_aiPanelOpen` flag，但这个 flag 仅
  控制宽屏（≥1100px）的 inline panel。窄屏（手机）走 `Scaffold.endDrawer`，
  需要调 `Scaffold.of(context).openEndDrawer()`。
- **Bug 2a.1**（review 发现的次生 bug）：即便补了窄屏分支，`Scaffold.of(State.context)`
  会抛 `no Scaffold ancestor` —— 因为 State 的 context 位于 Scaffold 之上。
  修复：复用 `_buildReaderStack` 里 `Builder` 提供的 `innerContext`（与 line
  756/771 的 TOC `openDrawer()` 同模式）。预防性修了 `_onAskAi`（选区工具条
  「提问 AI」）的同根因 latent bug。

### Bug 2b：右下 FAB 从「书签」改为「AI 抽屉」

- **症状**：v1.9.1-alpha 在移动端阅读页右下有一个悬浮按钮（来自 M2.10/Bug C1），
  用于 chrome 隐藏时仍能添加书签。但 AI 抽屉是更频繁的操作，且原书签 FAB 占据
  了「最显眼快捷入口」的位置。
- **用户决策**：把右下 FAB 从书签改为 AI 入口。书签仍可通过 chrome 可见时的
  AppBar 图标添加。
- **副作用**：解决「右滑抽屉与系统返回手势冲突」的误触问题（用户原话：
  「从屏幕右部中间向中间拖动可以唤出 AI 抽屉，但和手机系统级滑动操作（推出）
  重叠，误操作概率极大」）。

### Bug 4：左右抽屉顶部与状态栏 / 灵动岛重叠

- **症状**：v1.9.1-alpha 在 iPhone（带灵动岛）和 Android（带挖孔）上打开
  左侧 TOC 抽屉或右侧 AI 抽屉，顶部文字（tab 标签 / AI 输入框 header）与
  状态栏图标、灵动岛重叠。重叠区域无法点击。
- **根因**：抽屉内容（`_DrawerTabBar` / `AiDrawerWidget`）未包 `SafeArea`，
  从 y=0 开始绘制。
- **修复**：左侧 `ReaderDrawer` 在 `Drawer(child: ...)` 内加 `SafeArea`；
  右侧 AI `Drawer` 的 child 外加 `SafeArea`。Drawer 背景仍延伸到边，仅内容让出
  安全区。

### Bug 5：AI 抽屉宽度 70% → 98%

- **症状**：v1.9.1-alpha 在 390px 宽的手机上，AI 抽屉宽度 = 默认 304px ≈ 78%
  屏宽，剩下 22% 露出阅读区——这个剩余宽度既不够阅读又压缩了 AI 交互区。
- **用户决策**：保留右侧滑出（拒绝底部 sheet 方案，见下节评估），改为 98%
  屏宽，让 AI 交互近全屏。
- **修复**：`Drawer(width: MediaQuery.of(context).size.width * 0.98, ...)`。

## 评估（未实施）：底部抽屉方案

用户晨测提出「AI 抽屉从底部出」的设想。评估结论：

**收益**：拇指可达（底部区在拇指范围）/ 消除右滑与系统返回手势冲突 / 聊天 UX
对齐主流移动 chat 应用（微信、ChatGPT）。

**损失**：阅读上下文被压缩 / AiDrawerWidget 需重写为扁宽布局（header / message
list / input composer 三段都要重排）/ BottomSheet + 软键盘叠层 / 上下拖改高
与系统下拉关闭冲突 / 跨端不一致（桌面/平板仍用侧边 inline panel，需维护两套）。

**决策**：**保留右侧滑出**，只改宽度。底部方案可作为 S2 Part 2 的独立任务
（<600px 走 bottom sheet，≥600px 保留右侧），届时一并解决布局重写成本。

## Commit 清单（v1.9.1-alpha 之后）

- `4757752` fix(sync): treat 409 AncestorsNotFound from GET as firstPush (Bug 1)
- `615b6b4` fix(reader): mobile AI drawer entry (AppBar icon + FAB swap) (Bug 2)
- `eb7e739` fix(reader): mobile drawer SafeArea + AI drawer width 98% (Bug 4 + 5)

## 测试覆盖

新增 7 个测试（v1.9.1-alpha 之后）：

- `web_dav_sync_engine_test.dart`（+1）：Bug 1 regression — getString 返回 409
  时 ensureAncestors 仍被调用。
- `reader_body_ai_entry_test.dart`（6）：Bug 2a AppBar AI icon 移动端打开
  endDrawer + Bug 2b FAB swap（图标 / chrome 隐藏时显示 / chrome 可见时隐藏 /
  tap 打开）+ Bug 4 SafeArea ancestor + Bug 5 width=0.98×screen。

完整回归：**~1267 pass / 3 skip / 10 baseline fail**（pre-existing）。

## 已知问题

10 个 pre-existing 测试失败（与 v1.9.1-alpha 相同，本 hotfix 无新增回归）：

- `router_test` 1
- `reader_page_test` 4
- `reader_flow_integration` timeout 1
- `reader_page_pdf_integration` load 1
- `reader_ai_drawer_integration` load 1（实际为 skip placeholder，统计口径差）
- `library_golden_test` 2（pre-existing 字体漂移）

其它沿用 v1.9.1-alpha：

- iOS 仍为 scaffold（无 Mac 无法 build）
- APK 单包不拆 ABI（50-80 MB release，含 PDFium）
- 5 plugin pub-cache `sed` 补丁仍需手动执行（S2 升级 plugin 默认 compileSdk 36）
- Golden 测试不覆盖 Android 渲染

## 升级指南

- **桌面**：直接覆盖安装，无 schema 变更（v13 沿用）
- **Android**：sideload 新 APK；无 schema 变更
- **WebDAV**：协议未变；如原账号同步失败，本次升级后重试即可（pushOnly 现在能
  正确处理新账号首次同步）

## 下载

> 待 build 产出 artifact 后补充链接；T12 tag 后 Gitee Release 页生效。

- Windows 安装包：`zhiyue-setup-1.9.2-alpha.exe`
- Android APK：`zhiyue-1.9.2-alpha.apk`

## 下一节点

S2 Part 2：5 plugin 升级（compileSdk 36 默认）+ IME / 软键盘深度适配
+ 全屏模式安全区 + 底部 AI 抽屉（<600px）候选方案 → v1.10.0-alpha。
