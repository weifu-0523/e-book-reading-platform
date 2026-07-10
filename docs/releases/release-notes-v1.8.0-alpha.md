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
- APK 体积 224 MB（debug 构建，含 PDFium native + 调试符号；release 构建约 50-80 MB 单 APK 不拆 ABI）
- **5 个 Flutter plugin 默认 `compileSdk 34` 与 `flutter_plugin_android_lifecycle` 要求的 36 冲突**：connectivity_plus / file_picker / flutter_secure_storage / just_audio / webview_flutter_android。本次发布采用 pub cache 直接补丁（`sed 's/compileSdk 34/compileSdk 36/g'`）作为 band-aid；长期方案是升级到默认 compileSdk 36 的版本（S2 跟进）
- Golden 测试不覆盖 Android 渲染（mobile 字体微差 + emulator 渲染抖动）
- 12 个 pre-existing 测试失败（router + library golden 4 + reader_page_test 4 + reader_flow_integration timeout + reader_page_pdf_integration load + reader_ai_drawer_integration load — 全部为本分支 mobile 改动之前就存在的 baseline 问题，已通过 commit 1e0b497 反向验证）

## 升级指南

- 桌面：直接覆盖安装，无 schema 迁移
- Android：sideload APK（不上 Play Store）

## 下一节点

S2：AI 适配（IME / 流式 sheet / 软键盘避让）→ v1.9.0-alpha
