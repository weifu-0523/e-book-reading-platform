# 智阅 v1.4.0-alpha Release Notes

**Tag**: `v1.4.0-alpha`（双 tag：`m2.4-complete`）
**发布日期**: 2026-07-01
**性质**: Release hygiene sweep，无新功能

---

## 这是什么

v1.4.0-alpha 是 v1.3.0-alpha 之后的一次"清理 milestone"——把 Phase 3+ 之前所有遗留的 release housekeeping 工作（reader 代码拆分、lint 清理、文档同步、截图补齐、Gitee Release 页面创建）一次性解决，让代码库进入"可被用户真实使用测试"的状态。

**没有新功能**。如果你已经用上 v1.3.0-alpha，无需更新；想从源码安装的话直接 `git checkout v1.4.0-alpha` 即可。

## 改动总览

### Code（开发者可见）

- `reader_body.dart` 644 → 578 行，抽出 2 个零依赖 widget：
  - `ReaderChapterEndPrompt`（M2.2 章节结束提示的 controller lifecycle）
  - `ReaderSelectionToolbar`（文本选区浮动工具条）
- `dart fix --apply` + 手工清理：lint info 数 49 → 0

### Docs（所有人均可读）

- `maintainers-runbook.md §9.4.1` — 性能 baseline v1.4 复测决策（沿用 v1.0.0 baseline）
- `release-procedure.md` — 同步当前版本号、测试数、AGPLv3 头覆盖率阈值
- 补回 CHANGELOG 中遗漏的 `[1.2.0-alpha]` 与 `[1.3.0-alpha]` 段落
- 完整 CHANGELOG 见仓库根 `CHANGELOG.md`

### Release artifacts（用户可见）

- 3 张新截图：library / pdf_reader / notes
- 4 个 Gitee Release 页面创建：v1.0.0 / v1.1.0-alpha / v1.2.0-alpha / v1.3.0-alpha（之前只 push 了 tag，没建 release 页面）

## 下载

- **Windows installer**: `zhiyue-setup-1.4.0.exe`（待 build）
- **Windows portable**: `zhiyue-portable-1.4.0.zip`（待 build）
- **Android APK**: `zhiyue-1.4.0.apk`（待 build）

> v1.4.0-alpha 本身是 polish release，artifact 暂不强制重新 build。如需最新代码效果，建议从 v1.3.0-alpha release 直接下载。

## 升级路径

- 从 v1.3.0-alpha：无需操作（无功能变化）
- 从 v1.0.0 GA：建议升至 v1.3.0-alpha 获取 AI 章节回顾 + Markdown 批量导出 + 自动章节结束提示 + 批量导出范围筛选

## 已知限制

- 用户面 UI 文案、动效、错误恢复路径仍为 alpha 阶段
- 性能 baseline 沿用 v1.0.0（v1.5 跨书 AI 伴读后强制复测）

## 反馈

Gitee Issues: https://gitee.com/weifu0523/e-book-reading-platform/issues
