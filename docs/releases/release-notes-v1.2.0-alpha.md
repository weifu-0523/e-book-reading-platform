# 智阅 v1.2.0-alpha Release Notes

**发布日期**：2026-07-01
**性质**：feature（EPUB 自动章节结束提示）
**Tag**：`v1.2.0-alpha`
**对应里程碑**：M2.2 — Auto Chapter-End Prompt

## 为什么有这个 release

读完一章该做什么？翻到 EPUB 一章末页时，用户经常犹豫「该看 AI 回顾？还是直接翻下一章？」。这个版本让 app 主动提示——非阻塞 SnackBar 弹出，提供「回顾本章 / 下一章 / 关闭」三个动作。

## 主要变更

**范围决策**：spec 起草时含 PDF，但实施中缩到 **EPUB only**。理由：pdfrx Page-as-Chapter 模型下用户翻页频繁（一章可能只有 1-2 页），每次翻页都弹 SnackBar 会打扰。PDF 路径在 spec §2.2 明确推后。

### Added

- `reader_engine_epub_view/lib/src/chapter_end_event.dart` — 纯数据类（chapterIndex + isLastChapter，值相等）。
- `EpubxRenderer.chapterEndEvents`（broadcast Stream）— 内部 flag 同次访问去抖。
- `ChapterEndDetector`（app 层）— per-session per-(bookId, chapterIndex) Set 去重（一次会话同一章只提示一次）。
- `ChapterEndPromptController`（StateNotifier）— settings gate + mounted 检查。
- `ChapterEndPromptSnackBar` — 自定义 content Row（3 个 TextButton；Next 条件显示，末章时隐藏）。
- `kChapterEndPromptEnabledKey` const + `chapterEndPromptEnabledProvider` `AsyncValue<bool>` + `ensureChapterEndPromptDefault` 首次启动默认值 seeding。
- Settings 页 `_ChapterEndPromptTile` ConsumerWidget（用户可关掉这个功能）。

### Changed

- `reader_engine_epub_view/lib/src/epubx_renderer.dart` 4 个 `_currentChapterIndex =` 写入点都重置 flag（setChapter / gotoLocator / openFile / bookForTesting）——之前漏了 gotoLocator，跨章跳转后会误报。
- `reader_body._ReaderBodyState` — lazy init + addListener 边沿检测（hidden→visible）+ `ScaffoldMessenger.showSnackBar`。

### Technical

- 22 个新测试（全量 782 pass + 3 skipped）。
- spec §2.2 明确推后 PDF 路径（pdfrx controller plumbing 留待 future）。

## Commit 清单

12 个 commit（含 spec/plan/review）：

- docs：`0e36af0` spec、`2eb683d` 缩到 EPUB only、`7f73152` plan + release checklist
- feat：`742cd4c` ChapterEndEvent、`64ce049` EpubxRenderer emit、`69e8712`/`9bc8dd5` ConcreteEpubReaderEngine 转发、`8953a66` ChapterEndDetector、`c95c5e2` SettingsRepository.getOrNull、`b97d7bc` settings toggle + 首启默认、`e0eab07` ChapterEndPromptController、`de20a9a` ChapterEndPromptSnackBar、`fc28465` wire into reader_body

## 关键决策

**spec 缩范围（PDF 推后）**：原 spec 含 PDF，实施时评估 pdfrx Page-as-Chapter 频繁翻页 → SnackBar 打扰。两阶段 subagent review 抓到 magic number（章节末尾 64px 阈值提取为 const）+ flag reset race（gotoLocator 分支漏重置 flag），都在 release 前修复。

## 升级指南

无破坏性变更。Settings 默认开启此功能；用户可在「设置 → 阅读体验 → 章节结束提示」关闭。
