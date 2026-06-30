# Gitee Release Notes — v1.1.0-alpha

> **状态**：草稿（2026-07-01 生成）。复制以下内容到 Gitee Release 页面（https://gitee.com/weifu0523/e-book-reading-platform/releases/new）。
>
> **Tag**：`v1.1.0-alpha`（已推送，`git push origin v1.1.0-alpha`）
>
> **附 artifact**（需手动 build 后上传，见 `docs/release-procedure.md`）：
> - `build/installer/zhiyue-setup-1.1.0-alpha.exe`
> - `build/installer/zhiyue-portable-1.1.0-alpha.zip`
> - `build/installer/zhiyue-1.1.0-alpha.apk`
> - 4 张截图（`docs/screenshots/*.png`，目前仅 epub_reader.png 就绪）

---

## 标题

智阅 1.1.0-alpha

## Body

智阅首个 AI 增强里程碑（M2.1）。在 v1.0.0 GA 基础上新增**章节学习回顾**与 **Markdown 批量导出**两大功能。仍为 alpha：UI 文案、动效、错误恢复路径有待真实用户反馈打磨。

### 新增功能

- **章节学习回顾**（MVP 2.0）：TOC 抽屉按章节 + 阅读器溢出菜单"回顾本章"。AI 用本章正文 + 用户本章高亮生成 summary + keyTakeaways，写入读书笔记。模态预览 + 保存/取消。PDF 书禁用入口（Page-as-Chapter 语义不适用）。
- **Markdown 批量导出**（MVP 2.0）：库 AppBar "导出为 Markdown"。选文件夹，每本书一份 .md + 一个 index.md（Obsidian vault 兼容，含 YAML frontmatter + wiki-links + 标签云）。空库提示对话框。
- 25 个 i18n key（15 review + 10 batch export），中英双语。
- 17 个新测试覆盖核心逻辑（总测试数 762 + 3 skipped）。

### 技术改进

- `BookReviewer` **独立**服务（不复用 AiGuide）：AiGuide sourceHash 只 hash 章节文本，无法感知高亮变化；BookReviewer 用 `sha256(truncatedText + '::' + highlightsSignature)` 确保"新增高亮 → 下次回顾强制 miss"。
- `NotesRepository.applyChapterReview` 幂等写入：`【第N章】` 前缀 + `## 第 N 章` sentinel，先删后加，保留用户手动内容。
- 0 数据库 schema 迁移；0 同步逻辑改动。
- 203 个 dart 源文件统一加 AGPLv3 SPDX 版权头（合规性修复）。

### 完整变更

见 [CHANGELOG.md](https://gitee.com/weifu0523/e-book-reading-platform/blob/v1.1.0-alpha/CHANGELOG.md)。

### 下载

- **Windows 安装包**：`zhiyue-setup-1.1.0-alpha.exe`
- **Windows 便携版**：`zhiyue-portable-1.1.0-alpha.zip`
- **Android APK**：`zhiyue-1.1.0-alpha.apk`

### 升级须知

- v1.0.0 用户可直接覆盖安装；数据库 schema 无变更。
- AI 章节回顾需在设置中配置 OpenAI-compatible API key（推荐 DeepSeek）。
- Markdown 批量导出选输出文件夹后即开始；首次导出建议选空文件夹避免覆盖既有文件。

### 已知限制

- PDF 书不支持章节回顾入口（Page-as-Chapter 语义不适用）。
- 批量导出不支持按 tag / 时间筛选（计划 v1.2）。
- 自动章节结束提示未实现（用户在 M2.1 选择了手动触发）。

### 反馈

欢迎在 [Issues](https://gitee.com/weifu0523/e-book-reading-platform/issues) 提交 bug 报告与功能建议。

---

**协议**：AGPLv3。每个源文件均带 SPDX-License-Identifier 标识。
