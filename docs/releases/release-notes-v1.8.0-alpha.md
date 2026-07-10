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
- 8 个 pre-existing 测试失败（不阻塞本版本）

## 升级指南

- 桌面：直接覆盖安装，无 schema 迁移
- Android：sideload APK（不上 Play Store）

## 下一节点

S2：AI 适配（IME / 流式 sheet / 软键盘避让）→ v1.9.0-alpha
