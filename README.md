# 智阅（Zhi Yue）

> 面向深度阅读/学习者的开源 Flutter 电子书阅读平台。
> 先做极致本地阅读体验，逐步叠加 AI 陪伴式学习与跨端同步。

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Version](https://img.shields.io/badge/version-1.9.0--alpha-blue.svg)](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.9.0-alpha)

## 项目状态

- ✅ **v1.0.0 GA 已发布**：Windows + Android 双端 release artifact，本地阅读 + AI 导读 + 坚果云同步全功能可用。
- ✅ **v1.1.0-alpha**：在 v1.0 GA 基础上新增**章节学习回顾**（AI 用本章正文 + 用户高亮生成总结 + 要点）与 **Markdown 批量导出**（Obsidian vault 兼容）。
- ✅ **v1.2.0-alpha**：新增**自动章节结束提示**（EPUB paged/scroll 模式翻到末页时弹出 SnackBar，提供「回顾本章 / 下一章 / 关闭」三个动作；可在 Settings 开关；首次启动根据 API key 配置情况默认开/关）。仍为 alpha：UI 文案、动效、错误恢复路径有待真实用户反馈打磨。
- ✅ **v1.3.0-alpha**：新增**批量导出范围筛选**（独立筛选页：按标签 OR / 按导入时间 / 按最近阅读；实时预览匹配书单 + 高亮总数；底部按钮直接显示"导出 N 本"）。仍为 alpha：边界 UX、动效、错误恢复路径有待真实用户反馈打磨。
- ✅ **v1.4.0-alpha**：release hygiene sweep——`reader_body` 拆分（644→578 行，抽出 `ReaderChapterEndPrompt` + `ReaderSelectionToolbar` 两个零依赖 widget）+ `dart fix --apply` lint 清理 + 文档同步 + 3 张截图（library/pdf_reader/notes）+ 4 个 Gitee Release 页面（v1.0.0 / v1.1.0-alpha / v1.2.0-alpha / v1.3.0-alpha）。无新功能。
- ✅ **v1.5.0-alpha**：Reader UX Overhaul——修 2 个 P0 bug（高亮不渲染、笔记点击无效）+ 8 项 UX 增强（多输入翻页、全屏模式、合并摘录按钮、宽屏 TOC sidebar、PDF 双页布局、书签系统、margin 调整、chrome 默认可见）。EPUB 双页渲染层留 v1.6。
- ✅ **v1.5.1-alpha**：Emergency Bug Fix Sweep——v1.5.0-alpha 用户上手测试发现 9 个 bug（翻页/排版/双页/高亮/目录/边距/选择/全屏 ESC/书签）全闭。无新功能，纯 fix sweep。
- ✅ **v1.6.0-alpha**：阅读体验大修——EPUB **双页对开布局**（M2.9，含每页页码/书脊/孤页处理）+ 段落首行缩进真正生效（em-space 预处理）+ 末页顶部对齐（双页 Row crossAxis 修复）+ 新增 5 款中文字体（黑体/宋体/楷体/普惠体/新晰黑）+ 摘录/书签右键菜单与可见删除/导出按钮 + 摘录工具条跟随选区 + 顶栏书架/字号快捷键挪到时钟左侧。用户两轮反馈共 7 个问题逐一定位修复。
- ✅ **v1.7.0-alpha**：AI 抽屉重构——5 入口收敛为 1 个统一抽屉（Reader AppBar `smart_toy_outlined`）+ per-book 多会话（`chat_sessions` / `chat_messages` 表）+ 章节级 subagent 隔离契约 + 苏格拉底式追问 + slash 命令（`/new` / `/del` / `/switch`）+ @-note 提及。schema v11→v12 DROP `qa_history`。
- ✅ **v1.7.1-alpha**：typography 持久化修复——用户报告"调整字体设为默认后退出重开仍恢复预设"的 bug。根因：dispose-time fire-and-forget 被 `exit(0)` 截断。引入 `TypographyPersister` 即时落盘（stream + debounce 500ms），PDF `setTypography` 补 emit state$ 保持契约一致。
- ✅ **v1.8.0-alpha**：移动端 MVP Spiral 1——M3 三档断点（compact <600 / medium 600-840 / expanded ≥840）+ `ResponsiveLayoutBuilder`（自研 ~80 行）+ `kDesktopDualPageBreakpoint=1100` 桌面 GA 行为常量 + `PlatformChromeController`（status bar + orientation 抽象）+ Library compact 分支（hamburger menu + overflow PopupMenu）+ Reader tap-to-toggle chrome + Android INTERNET 权限 + iOS 目录占位（不 build 不 CI）。桌面行为 100% 保留（hover / 双页阈值 / exit(0) 时序 / window chrome 不变）。
- ✅ **v1.9.0-alpha**：用户测试 3 bug 修复 + 自由笔记——(1) 修坚果云 WebDAV 上传报 `AncestorsNotFound` (409)（MKCOL ensureAncestors）；(2) 修 AI 聊天发送后输入框文字残留（clear-on-send）；(3) 新增自由笔记：reader drawer `note_add` + NotesPage FAB + 全局入口（library drawer），drift schema v13 + 跨设备同步（tier 1，与 bookNote 同级）+ NoteEditPage（Markdown 编辑/预览切换 + 500ms write-through debounce）。
- 下一步：**S2 AI 适配 + 5 plugin 升级**（IME / 流式 sheet / 软键盘避让 / 默认 compileSdk 36）→ v1.10.0-alpha。

## 下载安装

### Windows

- **v1.1.0-alpha 安装包**（[zhiyue-setup-1.1.0.exe](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.1.0-alpha)）— 自动注册 .epub/.pdf 文件关联、加开始菜单快捷方式、含卸载项。
- **v1.1.0-alpha 便携版**（[zhiyue-portable-1.1.0.zip](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.1.0-alpha)）— 解压即用，免安装。
- 稳定版用户请使用 [v1.0.0](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.0.0)。

> 安装后双击任意 .epub / .pdf 文件会自动用智阅打开。若已运行智阅，会在原窗口打开新书而不是启动新进程（M8 单实例 mutex）。

### Android

- **v1.9.0-alpha APK**（[zhiyue-1.9.0-alpha.apk](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.9.0-alpha)）— sideload 安装，含 WebDAV + AI 输入修复 + 自由笔记全部能力。
- **v1.8.0-alpha APK**（[zhiyue-1.8.0-alpha.apk](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.8.0-alpha)）— 旧版（移动端 MVP Spiral 1）。
- **v1.1.0-alpha APK**（[zhiyue-1.1.0.apk](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.1.0-alpha)）— 旧版（v1.0 GA 同款 APK）。
- Android 8+ 需在「设置 → 应用 → 特殊访问权限 → 安装未知应用」中允许浏览器安装 APK。
- 安装后在文件管理器点击 .epub / .pdf，选「智阅」打开。

## 主界面预览

| Library | EPUB Reader | PDF Reader | Notes |
|---|---|---|---|
| ![Library](docs/screenshots/library.png) | ![EPUB Reader](docs/screenshots/epub_reader.png) | ![PDF Reader](docs/screenshots/pdf_reader.png) | ![Notes](docs/screenshots/notes.png) |

> 截图为 Windows release 构建。`epub_reader.png` 在 M8 捕获；`library` / `pdf_reader` / `notes` 三张在 v1.4.0-alpha 补齐——参见 [`docs/screenshots/README.md`](docs/screenshots/README.md) 与 [`docs/release-procedure.md`](docs/release-procedure.md) 步骤 9。

## 已交付能力

### MVP 1.0（v0.5.0 → v1.0.0）

- **跨端阅读**：Windows + Android，一套 Flutter 代码
- **格式支持**：EPUB 完整功能 + PDF（文本版基础 + 扫描版仅阅读）
- **本地优先**：所有数据本地 SQLite，完全离线可用
- **沉浸阅读**：极致排版、4 套主题（亮/暗/护眼/电子墨水）、全屏沉浸模式
- **读书笔记**：高亮（5 色）+ 笔记 + 标签 + 全文搜索（FTS5）
- **知识沉淀**：读书笔记库 + Markdown 单本导出（Obsidian 兼容）

### Phase 2 AI + 同步（v0.6 → v1.0，5 个螺旋）

- **AI 导读**（DeepSeek BYOK）：全书摘要 + 章节导读 + 高亮点评 + 同书问答（带 `[ch=N]` 引用跳转）
- **跨端同步**（坚果云 WebDAV）：高亮/笔记/进度/书签双向同步，last-write-wins + 冲突日志
- **后台定时同步** + 30 天 outbox 清理

### v1.1.0-alpha 新增

- **章节学习回顾**：TOC 抽屉按章节"回顾"按钮 → AI 用本章正文 + 本章高亮生成 summary + keyTakeaways → 模态预览 → 写入读书笔记（幂等前缀 + sentinel 约定）
- **Markdown 批量导出**：库 AppBar "导出为 Markdown" → 选文件夹 → 每本书一份 .md + 一个 index.md（YAML frontmatter + wiki-links + 标签云）
- **平台适配加固**：Windows 单实例 mutex、deep-link 文件关联、应用图标、AGPLv3 SPDX 源文件头

### v1.2.0-alpha 新增

- **自动章节结束提示**（EPUB）：用户翻到一章末页（paged 或 scroll 模式）时弹出非阻塞 SnackBar，提供「回顾本章 / 下一章 / 关闭」三个动作。同章本次会话去重；Settings 页可全局开关；首次启动根据 API key 配置情况默认开/关。PDF 阅读不弹（pdfrx Page-as-Chapter 频繁打扰）。

### v1.3.0-alpha 新增

- **批量导出范围筛选**：Library 溢出菜单"导出为 Markdown"先开筛选页，支持按标签（多选 OR）、按导入时间、按最近阅读三维度组合筛选；实时预览匹配书目数与高亮总数；底部按钮直接显示"导出 N 本"。底层 `BookFilter` + `applyBookFilter` 纯函数 + 既有 `VaultExporter` 零改动；预览数 = 实际导出数的不变量由 `VaultExporter.hasContent` 公开为 static 保证。

### v1.5.0-alpha 新增（M2.5 Reader UX Overhaul）

- **修复高亮不渲染 / 笔记点击无效**（P0 bug）：前者补 `ref.listen` 把 `NotesState.annotations` 桥接到 `engine.injectHighlights()`；后者补 `EpubxRenderer.gotoLocator` 的 `EpubRangeLocator` 分支。
- **多输入翻页**：键盘 ←/→/↑/↓/PgUp/PgDn、鼠标滚轮、触摸拖拽、左右 tap zone 五种输入。
- **全屏模式**：桌面 `window_manager` + 移动 `SystemChrome`；Esc/F11 快捷键，全屏态中心双击显示 chrome。`FullscreenController` 抽象让平台分支可注入测试。
- **合并摘录按钮**：原来「高亮」「笔记」两键合并为「摘录」bottom sheet（5 色 + 笔记输入）。
- **宽屏 TOC sidebar**：>=1100px 自动升级为永久侧栏（280↔40px 可折叠），drawer 3-tab 重构（目录 / 书签 / 笔记）。
- **PDF 双页布局**：>=1200px 自动启用，按偶数页对齐；扫描件自动降级单页。
- **书签系统**：drift v10 schema + sync pipeline + 4 个 UI 入口（AppBar 收藏图标 + 标签对话框、drawer 书签 tab、独立页面）。
- **margin 调整**：Normal 16 → 24 px；新增 ExtraWide=40 px 选项。
- **EPUB 双页布局**：API surface 已 wire，渲染层留 v1.6（详见 release notes）。

## 后续阶段

- **v1.6+**：EPUB 双页渲染层、跨书 AI 伴读、Zotero/Obsidian 双向同步、知识图谱、性能 baseline 测量
- **长期**：iOS 端、Mac 端

完整路线图见 [`docs/superpowers/specs/2026-06-28-phase2-roadmap-design.md`](docs/superpowers/specs/2026-06-28-phase2-roadmap-design.md)。

## 技术栈

| 层 | 技术 |
|---|---|
| 框架 | Flutter 3.44+ |
| 语言 | Dart 3.10+ |
| 状态管理 | Riverpod 2.5 |
| 路由 | go_router 14.2 |
| 数据库 | drift 2.18（SQLite + FTS5） |
| EPUB | epubx 4.0.0（本地 fork `epubx_patched/`） |
| PDF | pdfrx 2.3.0 |
| AI | OpenAI-compatible client（先期 DeepSeek） |
| 同步 | 坚果云 WebDAV（不自建后端） |
| 协议 | AGPLv3 |

## 测试与质量

- **测试**：~1240 通过 + 3 skipped + 8 pre-existing baseline 失败（v1.9.0-alpha；细分见 [release-notes](docs/releases/release-notes-v1.9.0-alpha.md)）
- **静态分析**：0 errors / 0 warnings / 0 info（M2.4/T4 已清零；既有 cascade/const 风格 lint 已通过 dart fix --apply + 手工处理）
- **文档**：836 行 maintainer's runbook + 16 milestone spec + 17 plan + 项目级 review
- **CI**：手动（每 milestone 完成跑全量回归 + analyze）

## 文档

- [原始设计文档（MVP 1.0）](docs/superpowers/specs/2026-06-24-ebook-platform-design.md)
- [Phase 2 路线图](docs/superpowers/specs/2026-06-28-phase2-roadmap-design.md)
- [项目级 Review（2026-07-01）](docs/reviews/2026-07-01-project-review.md)
- [原始调研报告](docs/01-research.md)（从市场到产品的战略分析）
- [维护者 Runbook](docs/maintainers-runbook.md)（冷启动手册）
- [发布流程](docs/release-procedure.md)
- [Android SDK 安装指南](docs/setup-android-sdk.md)
- [更新日志](CHANGELOG.md)

## 反馈与贡献

- Gitee Issues：[https://gitee.com/weifu0523/e-book-reading-platform/issues](https://gitee.com/weifu0523/e-book-reading-platform/issues)
- 项目尚在开发初期，暂不接受外部 PR；欢迎在 Issues 中提出建议。

## 开源协议

本项目采用 [AGPLv3](LICENSE) 协议开源。

每个源文件顶部均带有 `SPDX-License-Identifier: AGPL-3.0-or-later` 标识与版权声明。任何对本项目代码的修改、网络服务化使用，都必须以同等协议开源。第三方依赖版权声明详见 [NOTICE](NOTICE)。
