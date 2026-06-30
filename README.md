# 智阅（Zhi Yue）

> 面向深度阅读/学习者的开源 Flutter 电子书阅读平台。
> 先做极致本地阅读体验，逐步叠加 AI 陪伴式学习与跨端同步。

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Version](https://img.shields.io/badge/version-0.5.0-blue.svg)](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.5.0)

## 项目状态

✅ **MVP 1.0 候选版本 v0.5.0 已发布**：双端 release artifact（Windows installer + Android APK）。
下一步：测试/打磨后 tag `v1.0.0`。

## 下载安装

### Windows

- **安装包**（[zhiyue-setup-0.5.0.exe](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.5.0)）— 自动注册 .epub/.pdf 文件关联、加开始菜单快捷方式、含卸载项。
- **便携版**（[zhiyue-portable-0.5.0.zip](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.5.0)）— 解压即用，免安装。

> 安装后双击任意 .epub / .pdf 文件会自动用智阅打开。若已运行智阅，会在原窗口打开新书而不是启动新进程。

### Android

- **APK**（[zhiyue-0.5.0.apk](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.5.0)）— sideload 安装。
- Android 8+ 需在「设置 → 应用 → 特殊访问权限 → 安装未知应用」中允许浏览器安装 APK。
- 安装后在文件管理器点击 .epub / .pdf，选「智阅」打开。

## 主界面预览

| Library | EPUB Reader | PDF Reader | Notes |
|---|---|---|---|
| ![Library](docs/screenshots/library.png) | ![EPUB Reader](docs/screenshots/epub_reader.png) | ![PDF Reader](docs/screenshots/pdf_reader.png) | ![Notes](docs/screenshots/notes.png) |

> 截图为 Windows release 构建。`epub_reader.png` 已在 M8 捕获；其余 3 张（library / pdf_reader / notes）计划在 v1.0.0 发布前手动补齐——参见 [`docs/screenshots/README.md`](docs/screenshots/README.md) 与 [`docs/release-procedure.md`](docs/release-procedure.md) 步骤 9。

## MVP 1.0 目标

- **跨端阅读**：Windows + Android，一套 Flutter 代码（Mac 后期）
- **格式支持**：EPUB 完整功能 + PDF（文本版基础 + 扫描版仅阅读）
- **本地优先**：所有数据本地 SQLite，完全离线可用
- **沉浸阅读**：极致排版、4 套主题（亮/暗/护眼/电子墨水）、全屏沉浸模式
- **读书笔记**：高亮（5 色）+ 笔记 + 标签 + 全文搜索（FTS5）
- **知识沉淀**：读书笔记库 + Markdown 导出（Obsidian 兼容）

## 后续阶段

- **1.5**：AI 导读 + 伴随式问答（DeepSeek BYOK）
- **2.0**：章节学习回顾 + 知识库深化 + 坚果云 WebDAV 同步
- **3.0+**：Zotero/Obsidian 双向同步、知识图谱、Mac 端

## 技术栈

| 层 | 技术 |
|---|---|
| 框架 | Flutter 3.27+ |
| 语言 | Dart 3.10+ |
| 状态管理 | Riverpod 2.6 |
| 路由 | go_router 14.2 |
| 数据库 | drift 2.18 (SQLite + FTS5) |
| EPUB | epubx 4.0.0（本地 fork） |
| PDF | pdfrx 2.4.4 |
| 协议 | AGPLv3 |

## 文档

- [原始设计文档（MVP 1.0）](docs/superpowers/specs/2026-06-24-ebook-platform-design.md)
- [原始调研报告](docs/01-research.md)（从市场到产品的战略分析）
- [Android SDK 安装指南](docs/setup-android-sdk.md)
- [发布流程](docs/release-procedure.md)
- [更新日志](CHANGELOG.md)

## 反馈与贡献

- Gitee Issues：[https://gitee.com/weifu0523/e-book-reading-platform/issues](https://gitee.com/weifu0523/e-book-reading-platform/issues)
- 项目尚在开发初期，暂不接受外部 PR；欢迎在 Issues 中提出建议。

## 开源协议

本项目采用 [AGPLv3](LICENSE) 协议开源。

任何对本项目代码的修改、网络服务化使用，都必须以同等协议开源。第三方依赖版权声明详见 [NOTICE](NOTICE)。
