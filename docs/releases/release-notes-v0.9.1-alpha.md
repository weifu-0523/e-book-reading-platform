# 智阅 v0.9.1-alpha Release Notes

**发布日期**：2026-06-30
**性质**：fix（M1.5b+c review fixups — 1 Critical + 5 Important 全闭）
**Tag**：`v0.9.1-alpha`
**对应里程碑**：M1.5b+c Review Fixups

## 为什么有这个 release

v0.9.0-alpha 交付后跑深度 code review，发现 1 个 Critical（内存泄漏）+ 5 个 Important（spec 偏差）。这个版本是 fast-follow 补丁，**纯修复，无新功能**。

## 修复了什么

### C1（Critical）— QaAnswerView 内存泄漏

`TapGestureRecognizer` 在 widget unmount 或 answer text 变化时没 dispose。之前流式 rebuild 每次泄漏约 1 个 recognizer per citation per build。改成 `QaAnswerView` Stateful + 显式 dispose。

### I1 — `chapterCountFor` 性能

线性 probe 改成 `ChapterTextProvider.count()`——O(1) 替代 O(N) EPUB 重复解析（厚书导入显著）。

### I2 — Preprocess 失败章节从未上报

`PreprocessDoneEvent.failedChapters` 现在反映真实的 per-chapter 失败（之前恒空）；`PreprocessChapterFailedEvent` 现在真的 emit（之前是 dead code）。BookDetailPage 的「N 章预处理失败」banner 现在诚实。

### I3 — Q&A 流卡死 + 总超时

`BookQaService` 改用 `StreamIterator` + per-moveNext `Future.timeout(stallTimeout)`（默认 30s）+ 90s 总超时。`QaAskDialog` 加「停止」按钮，通过 `QaController.reset()` 取消 in-flight 请求。chunk 到达后的网络错误是 terminal（不重放），mirror `ai_guide.dart` 模式。

### I4 — Preprocess 进行中提示

`QaAskDialog` 现在显示「预处理进行中（N/M），回答可能不全」caption（当 per-book preprocess controller 在 chunking/summarizing 时）。

### I5 — Q&A 历史列表

`QaAskDialog.initState` 加载最近 5 条历史，渲染成 ActionChips。tap 重发，long-press 删除。引入 `QaHistoryDaoLike` 接口便于测试。关闭 spec §14 验收缺口「Q&A 历史可查看 + 重发」。

## Spec coverage

Review 分类：1 Critical + 5 Important → 6/6 闭。Minors（M1-M7）推迟到 M2.0c。

## Commit 清单

10 个 commit：

- docs：`c545aad` final code review report、`afdaec1` plan for review fixups
- fix：`6847604` C1 内存泄漏、`2320241` I2 failed chapters、`ab2dc0a`+`f22247b` I3 stall timeout + Stop 按钮、`b9a8e8a` I1 性能
- feat：`618ae4d` I4 caption、`79d9db3` I5 历史列表、`6b21d6c` qaHistoryDaoProvider 默认 inert NoOp DAO
- chore：`83011d0` release v0.9.1-alpha

## 关键技术点

`Stream.timeout` 不能用于 paused `async*` 源——这是 I3 修复的关键发现。原实现用 `await for (final chunk in stream.timeout(30s))` 期望超时触发，但 paused 期间的 timer 不会 fire。改用 `StreamIterator` 主动 `moveNext` + 每次 `Future.timeout` 才正确。

## 升级指南

无破坏性变更。已有 v0.9.0-alpha 用户直接升级。
