# 智阅 v1.0.0 Release Notes

**发布日期**：2026-06-30
**性质**：release（首个正式发布 GA）
**Tag**：`v1.0.0`
**对应里程碑**：M1.6 — Polish Sweep

## 为什么有这个 release

智阅的第一个正式版本（GA）。从 M0 数据层一路迭代到 M1.6，所有功能模块（阅读 / 笔记 / AI / 同步 / 平台适配）就位，代码质量、文档、Windows 原生冒烟测试齐了。AGPLv3 开源。

## M1.6 Polish Sweep（本次发布）

### 代码质量

- **lint 清理**：15 warnings + 26 lib info → 0。
- **`reader_page.dart` 机械拆分**：772 行 → 97 行 + `reader_body` / `reader_progress_bar` / `reader_typography_panel_trigger` 三个聚焦文件。
- **共享 UX 三态组件**（`LoadingView` / `EmptyView` / `ErrorView`）在 9 个页面落地——所有可见页面不再有裸 `CircularProgressIndicator` 或临时 error `Text`。
- **drift row 命名一致性**：`Book.fromRow` 工厂集中映射。

### 文档

- **`maintainers-runbook.md`**（639 行）覆盖：环境搭建、中文路径坑、subagent-driven 开发流程、Git/发布流程、11 个常见 bug、性能基线方法论、24 术语词汇表。

### Windows 原生冒烟测试

- **`deep_link_parser` 提取** + 基于 `cl.exe` 的 `test_main.cpp`（13 个断言用例）。
- 中文路径 → `cl.exe` 失败的 ASCII 路径 workaround 已记录在 runbook。

### UX 一致性

- 所有可见字符串走 l10n。
- TOC 渐进式章节标记（已预处理 ✓ / 失败 ⚠ / 未处理）。

### 防御性

- `ai_summaries` 在 preprocessor 中防御性缓存。
- `qaControllerProvider` 默认 NoOp。
- `SyncController` 强制要求 `http.Client`。
- 共享 `httpClientProvider`（带 dispose 测试）。

## 累积里程碑（M0 → M1.6）

| 里程碑 | 内容 | 测试 | 对应版本 |
|---|---|---|---|
| M0+M1 | 数据层基础 | 58 | — |
| M2 | EPUB 阅读器 | 179 | — |
| M3.1-3.5 | 书架 / 笔记 / 排版 / i18n | 491 | — |
| M4 | pdfrx PDF 阅读器 + 文本高亮 | 565 | — |
| M7 | 平台适配（Android + Windows） | 575 | v0.4.0 |
| M8 | Windows 安装器 | 579 | v0.5.0 |
| M1.5a | AI MVP（OpenAI 兼容 LLM + 3 种导读 + 摘要缓存） | — | v0.7.0-alpha |
| M2.0a | 同步 MVP（WebDAV push/pull + LWW） | — | v0.6.0-alpha |
| M2.0b | 同步冲突解决 + 后台定时器 | — | v0.8.0-alpha |
| M1.5b+c | 导入批处理 + 同书 Q&A | — | v0.9.0-alpha |
| M1.5b+c Fixups | 内存泄漏 + spec 偏差闭环 | — | v0.9.1-alpha |
| **M1.6** | **Polish Sweep（GA）** | **713 + 2 skipped** | **v1.0.0** |

### 跳过的 2 个测试（预存在，非本次新引入）

- `app/test/features/settings/font_import_service_test.dart:187`（FontLoader 在非字体字节上的行为依赖运行环境）
- `app/test/features/reader/reader_page_pdf_integration_test.dart:60`（`skip: true` 占位骨架）

`background_sync_scheduler_test` 与 `book_import_service_test` 的偶发失败属于 **flaky**（并发相关），重跑通过。

## Commit 清单（本次 M1.6 sweep，22 个）

- docs：`8ea3763` spec、`6cd3f40` plan、`8ee9172`/`7e00aa0` runbook + perf baseline + screenshot placeholders
- refactor：`deb04c3`/`d71214f` Book.fromRow、`e326cc3` BookDetailPage i18n、`2b5852a`/`9a557df` 共享 httpClient、`a27c019`/`d2840b2` SyncController/qaController NoOp、`3759018` ai_summaries 防御 cache、`69708ef` reader_page 拆分
- feat：`8ee9172` TOC 章节标记、`eb44c9f`/`541140f`/`44b6e39` 共享 UX widgets
- fix：`76c3d88` reader loading + log notes
- chore/test：`a7f0b6b` lint cleanup、`c056b1d` precedence test、`c33de3a` Windows native smoke test、`edde312` bump v1.0.0 GA

## 已知限制

- Windows release 构建在中文路径（`H:\projiect\电子书阅读平台`）下失败；构建时需拷贝到 ASCII 路径。详见 runbook §3。
- 3 张截图待手动采集（`docs/screenshots/README.md`）。
- 性能基线待手动测量（runbook §9.6）。
- 新表（`book_passages`、`qa_history`）尚未接入 `sync_outbox`——推迟至 M2.0x。
- Q&A 为单轮（每次提问独立，无上下文累积）。
- 成本/token 估算 UI 按用户反馈有意省略。

## 升级指南

从 v0.9.x-alpha 升级：直接覆盖二进制即可。drift schema v9（v0.9.0 已升级）后无 schema 变更。

从更早版本升级：app 启动会自动跑所有 drift migration（v1 → v9），用户数据无损。
