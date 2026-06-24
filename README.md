# 智阅（Zhi Yue）

> 面向深度阅读/学习者的开源 Flutter 电子书阅读平台。
> 先做极致本地阅读体验，逐步叠加 AI 陪伴式学习与跨端同步。

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

## 项目状态

🚧 **MVP 1.0 设计阶段** —— 设计文档已定稿，待实现。

## MVP 1.0 目标

- **跨端阅读**：Windows + Android，一套 Flutter 代码（Mac 后期）
- **格式支持**：EPUB 完整功能 + PDF（文本版基础 + 扫描版仅阅读）
- **本地优先**：所有数据本地 SQLite，完全离线可用
- **沉浸阅读**：极致排版、4 套主题、全屏沉浸模式
- **读书笔记**：高亮（5 色）+ 笔记 + 标签 + 全文搜索（FTS5）
- **知识沉淀**：读书笔记库 + Markdown 导出（Obsidian 兼容）

## 后续阶段

- **1.5**：AI 导读 + 伴随式问答（DeepSeek BYOK）
- **2.0**：章节学习回顾 + 知识库深化 + 坚果云 WebDAV 同步
- **3.0+**：Zotero/Obsidian 双向同步、知识图谱、Mac 端

## 技术栈

| 层 | 技术 |
|---|---|
| 框架 | Flutter |
| 语言 | Dart |
| 状态管理 | Riverpod |
| 路由 | go_router |
| 数据库 | drift (SQLite) + FTS5 |
| 协议 | AGPLv3 |

## 文档

- [设计文档（MVP 1.0）](docs/superpowers/specs/2026-06-24-ebook-platform-design.md)
- [原始调研报告](docs/01-research.md)（从市场到产品的战略分析）

## 开源协议

本项目采用 [AGPLv3](LICENSE) 协议开源。

任何对本项目代码的修改、网络服务化使用，都必须以同等协议开源。

## 反馈与贡献

- Gitee Issues：[https://gitee.com/weifu0523/e-book-reading-platform/issues](https://gitee.com/weifu0523/e-book-reading-platform/issues)
- 项目尚在开发初期，暂不接受外部 PR；欢迎在 Issues 中提出建议。
