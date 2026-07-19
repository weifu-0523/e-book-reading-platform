# v1.13.11-alpha

**发布日期**：2026-07-19
**类型**：hotfix（1 bug：选段朗读坐标系统一为渲染层）
**上一版本**：v1.13.10-alpha

## 摘要

v1.13.10-alpha 的 Bug 2 修复（whitespace-insensitive regex fallback）没解决问题——3 本书测试选中朗读，2 本仍从章节头开始。本版本找到**真根因**并修复。

## Bug 2 真根因：坐标系统一

### 决定性证据

v1.13.10-alpha 的 `_findSelectionStartWhitespaceInsensitive` 用 regex `\s*` 连接非空白字符。该 fallback 仍失败的唯一解释：选区头部包含**非空白、非选区**的字符。

### 坐标系不匹配详解

| 数据源 | 路径 | 输出 |
|---|---|---|
| `selectedText` | EPUB 渲染层 `SelectionAssistant.plainText` | 走 `HtmlToInlineSpanConverter`（渲染坐标） |
| `chapterText` | `ttsChapterTextResolverProvider` → `EpubChapterTextProvider.get` → `PlainTextUtils.htmlToPlainWithOffsets` | 走另一条提取路径（提取坐标） |

两者在 HTML 元素分隔符处理上**完全不同**：

| 元素 | 渲染坐标（HtmlToInlineSpanConverter） | 提取坐标（htmlToPlainWithOffsets） |
|---|---|---|
| `<p>` | `\n\n` 前后 | 直接删 tag（无分隔符） |
| `<h1>`-`<h6>` | U+FFFC + `\n\n` | 直接删 tag |
| `<img>` | U+FFFC | 直接删 tag |
| `<br>` | `\n` | 直接删 tag |

`indexOf` 严格匹配必然失败（U+FFFC 不在提取坐标的 chapterText 里）。whitespace regex 也无法匹配 U+FFFC（它是 OBJECT REPLACEMENT CHARACTER，不是空白）。

### 修复

`TtsReaderController` 的两处章节文本获取改用 `engine.currentChapterPlainText`：

| 方法 | 旧路径 | 新路径 |
|---|---|---|
| `_prepareCurrentChapter` | `ttsChapterTextResolverProvider` | `engine.currentChapterPlainText` |
| `_loadNextChapterAndContinue` | `ttsChapterTextResolverProvider` | `engine.currentChapterPlainText` |
| `resumeFromLast` | `ttsChapterTextResolverProvider` | **保留旧路径**（engine 可能不在目标章节） |

这与 `reader_body._openExcerptSheet`（line 1209）的做法完全一致——同源，问题自然消失。

`_locateSelectionStartIndex` 保留 `_findSelectionStartWhitespaceInsensitive` fallback 作为容错（虽然坐标系统一后理论上 indexOf 应直接命中，但保留无害）。

### 测试（2 新）

`group 'TtsReaderController.startFromSelection uses engine.currentChapterPlainText coordinate (v1.13.11-alpha Bug 2 real root cause)'`：

1. **新数据源验证**：fakeReaderEngine.currentChapterPlainText 返回带 U+FFFC 的渲染坐标文本，startFromSelection 应正确从选区起点朗读（不 fallback 到章节头）
2. **currentIndex 计算正确**：选区起点 = sent_1 的 charStart 时，currentIndex 应为 1（不是 0）

为支持测试，新增私有接口 `_EnginePlainTextAware`，5 个 fake engine（`_FakeReaderEngine` / `_FakeScrollReaderEngine` / `_FakeLocationEngine` / `_FakeScrollLocationEmittingEngine` / tts_resume_prompt_test 的 `_FakeReaderEngine`）全部加 `currentChapterPlainText` getter。

## 用户测试步骤

1. 装 v1.13.11-alpha（覆盖 v1.13.10-alpha，versionCode 2008 > 2007）

2. **回归场景 D（之前失败的 2 本书）**：
   - 用 v1.13.10-alpha 测试时选段朗读仍从章节头开始的 2 本书
   - 选中文字 → 点"朗读选中"
   - **应立即播放选中句子（不是章节头）**

3. **回归场景 E（之前工作的 1 本书）**：
   - 用之前工作的 1 本书测试选段朗读
   - **仍能正确从选中句子开始**

4. **跨章节自动续读**：
   - 让朗读到章节末自动到下一章
   - **下一章应从该章首句开始**（不是空白或错误位置）

5. **resumeFromLast 路径**：
   - 朗读到某句暂停 → 关闭 app → 重开 → 点续读
   - **应从上次停止位置续读**（保留旧路径，行为不变）

## 升级路径

直接装 `zhiyue-1.13.11-alpha-with-fgs.apk` 覆盖 v1.13.10-alpha。

- drift schema v15 不变（无 DB 迁移）
- TTS 设置不重置
- versionCode 2008 > v1.13.10 的 2007

## Breaking Change

无。
