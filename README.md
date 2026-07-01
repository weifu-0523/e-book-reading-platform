# 智阅（Zhi Yue）

> 面向深度阅读/学习者的开源 Flutter 电子书阅读平台。
> 先做极致本地阅读体验，逐步叠加 AI 陪伴式学习与跨端同步。

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Version](https://img.shields.io/badge/version-1.2.0--alpha-blue.svg)](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.2.0-alpha)

## 项目状态

- ✅ **v1.0.0 GA 已发布**：Windows + Android 双端 release artifact，本地阅读 + AI 导读 + 坚果云同步全功能可用。
- ✅ **v1.1.0-alpha**：在 v1.0 GA 基础上新增**章节学习回顾**（AI 用本章正文 + 用户高亮生成总结 + 要点）与 **Markdown 批量导出**（Obsidian vault 兼容）。
- 🚧 **v1.2.0-alpha**：新增**自动章节结束提示**（EPUB paged/scroll 模式翻到末页时弹出 SnackBar，提供「回顾本章 / 下一章 / 关闭」三个动作；可在 Settings 开关；首次启动根据 API key 配置情况默认开/关）。仍为 alpha：UI 文案、动效、错误恢复路径有待真实用户反馈打磨。
- 下一步：补 3 张 release 截图（library/pdf/notes）+ 创建 Gitee Release 页面；之后规划 v1.3（批量导出筛选、性能 baseline 测量）。

## 下载安装

### Windows

- **v1.1.0-alpha 安装包**（[zhiyue-setup-1.1.0.exe](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.1.0-alpha)）— 自动注册 .epub/.pdf 文件关联、加开始菜单快捷方式、含卸载项。
- **v1.1.0-alpha 便携版**（[zhiyue-portable-1.1.0.zip](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.1.0-alpha)）— 解压即用，免安装。
- 稳定版用户请使用 [v1.0.0](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.0.0)。

> 安装后双击任意 .epub / .pdf 文件会自动用智阅打开。若已运行智阅，会在原窗口打开新书而不是启动新进程（M8 单实例 mutex）。

### Android

- **v1.1.0-alpha APK**（[zhiyue-1.1.0.apk](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.1.0-alpha)）— sideload 安装。
- Android 8+ 需在「设置 → 应用 → 特殊访问权限 → 安装未知应用」中允许浏览器安装 APK。
- 安装后在文件管理器点击 .epub / .pdf，选「智阅」打开。

## 主界面预览

| Library | EPUB Reader | PDF Reader | Notes |
|---|---|---|---|
| ![Library](docs/screenshots/library.png) | ![EPUB Reader](docs/screenshots/epub_reader.png) | ![PDF Reader](docs/screenshots/pdf_reader.png) | ![Notes](docs/screenshots/notes.png) |

> 截图为 Windows release 构建。`epub_reader.png` 已在 M8 捕获；其余 3 张（library / pdf_reader / notes）将在 v1.1.0 stable 发布前补齐——参见 [`docs/screenshots/README.md`](docs/screenshots/README.md) 与 [`docs/release-procedure.md`](docs/release-procedure.md) 步骤 9。

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

## 后续阶段

- **v1.3**：批量导出筛选（按 tag / 时间）、性能 baseline 测量
- **v1.5+**：跨书 AI 伴读、Zotero/Obsidian 双向同步、知识图谱
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

- **测试**：782 通过 + 3 skipped（macOS-only golden + Windows release-build smoke + 1 性能测试）
- **静态分析**：0 errors / 0 warnings / 131 info（既有 cascade/const 风格 lint）
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
