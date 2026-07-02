# 智阅 v1.5.0-alpha Release Notes

**Tag**: `v1.5.0-alpha`（双 tag：`m2.5-complete`）
**发布日期**: 2026-07-03
**性质**: Reader UX Overhaul——2 个 P0 bug 修复 + 8 项 UX 增强

---

## 这是什么

v1.5.0-alpha 是 M2.5「Reader UX Overhaul」的交付版本。目标：把阅读器从"能用"推进到"在桌面宽屏上舒服用"。

修了两个用户面 P0 bug（高亮不渲染、笔记点击无效），并交付 8 项 UX 增强：多输入翻页、全屏模式、合并摘录入口、宽屏 TOC sidebar、PDF 双页布局、书签系统、margin 调整、chrome 默认可见。

## 改动总览

### Bug 修复（P0）

- **#4 高亮不渲染**：选中文本后选颜色，页面上不出现高亮。根因是 `NotesState.annotations` 变更后没有桥接到 `engine.injectHighlights()`，加一行 `ref.listen` 修复。
- **#6 笔记点击无效**：NotesPage / drawer 里点笔记不跳回原位置。`EpubxRenderer.gotoLocator` 没处理 `EpubRangeLocator` 分支，补齐。

### 新功能

- **书签系统**：drift v10 schema + sync pipeline + 4 个 UI 入口（AppBar 收藏图标 + 标签对话框、drawer 书签 tab、独立 `/book/:id/bookmarks` 页面）。
- **PDF 双页布局**：宽屏 (>=1200px) 自动启用；扫描件自动降级单页。

### UX 增强

- **多输入翻页**：键盘 ←/→/↑/↓/PgUp/PgDn、鼠标滚轮、触摸拖拽、左右 tap zone。
- **全屏模式**：桌面 window_manager + 移动 SystemChrome；Esc/F11 快捷键，全屏态中心双击显示 chrome。
- **合并摘录按钮**：原来「高亮」「笔记」两键合并为「摘录」bottom sheet（5 色 + 笔记输入）。
- **宽屏 TOC sidebar**：>=1100px 自动升级为永久侧栏（280↔40px 可折叠）。
- **默认 margin 调整**：Normal 16 → 24 px；新增 ExtraWide=40 px 选项。
- **chrome 默认可见**：桌面端 reader AppBar 默认显示。
- **抽屉 3-tab 重构**：目录 / 书签 / 笔记三 tab 合并到单一 `ReaderDrawer`。

### 已知限制

- **EPUB 双页布局渲染层未实现**：`dualPageMode` 标志已端到端 wire（API surface），但实际渲染仍为单页。原因：EPUB 分页当前是 degraded plain-text 模式（不是 M3 最终形态），现在重写算法是抛一次性的工作；PDF T13 已覆盖更常见的双页格式需求。计划在 v1.6 落地真正的双页渲染。
- 用户面 UI 文案、动效、错误恢复路径仍为 alpha 阶段。
- 性能 baseline 沿用 v1.0.0（v1.5 主体是 UX 重构，未触及渲染/DB/sync 性能敏感路径）。

## 下载

- **Windows installer**: `zhiyue-setup-1.5.0.exe`（待 build）
- **Windows portable**: `zhiyue-portable-1.5.0.zip`（待 build）
- **Android APK**: `zhiyue-1.5.0.apk`（待 build）

> artifact 暂不强制重新 build。如需最新代码效果，从源码 `git checkout v1.5.0-alpha` 即可。

## 升级路径

- 从 v1.4.0-alpha：直接升级即可。Drift 自动迁移 v9 → v10（创建 bookmarks 表），已存的 margin 偏好保留（Normal 像素值会从 16 变 24）。
- 从 v1.0.0 GA：建议直接升至 v1.5.0-alpha 获取全部 UX 改进 + AI 章节回顾 + Markdown 批量导出 + 跨书筛选。

## 测试

- 4 个包共 1066 pass + 3 skipped
  - `app`: 888 pass + 3 skipped
  - `reader_engine`: 50 pass
  - `reader_engine_epub_view`: 83 pass
  - `reader_engine_pdf_view`: 45 pass
- 静态分析：0 errors / 0 warnings / 0 info
- AGPLv3 头覆盖率：100%（生成文件除外）

## 反馈

Gitee Issues: https://gitee.com/weifu0523/e-book-reading-platform/issues
