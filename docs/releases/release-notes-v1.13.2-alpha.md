# v1.13.2-alpha

**发布日期**：2026-07-18
**类型**：hotfix（Android TTS 多句播放中断 + 选段朗读语义重构）
**上一版本**：v1.13.1-alpha

## 摘要

v1.13.1-alpha 修复了 Android 端"完全无声"的 P0 bug（factory 未接线）。
用户实测确认有声音后立即报告了两个新问题：

1. **多句队列只读一句就停**：选中一段话、或点「朗读本章」，只读到
   第一个句号/感叹号/问号就停止。
2. **「朗读选中」语义不符合预期**：用户希望选段视为"起点"——从选中句
   开始往后读，读完整章自动跳下一章（与「朗读本章」一致，只是起点不同）。
   而非"只读选段那几句就停"。

本 hotfix 同时闭环两件事。

## Bug 1：Android 多句队列只读一句

### 根因（systematic-debugging Phase 1）

**数据流（broken）**：

```
UI 触发朗读
  → TtsPlaybackController._speakCurrent
    → SelfBuiltTtsServiceImpl.speakSentence (queue[0])
      → MethodChannel('dev.zhiyue.tts').invokeMethod('speak')
        → ZhiYueTtsService.handleSpeak → tts.speak(QUEUE_FLUSH)
          → UtteranceProgressListener.onStart → emit {state: speaking} ✓
          → 第一句读完 → UtteranceProgressListener.onDone → emit {event: done}
            → ❌ Dart SelfBuiltTtsServiceImpl._handleEvent 的 switch
              只有 'state' / 'progress' / 'error'，'done' 落 default 丢弃
              → _stateController 永远不 emit TtsState.idle
                → TtsPlaybackController._onServiceState 第 380 行的
                  "if (svcState == TtsState.idle && phase == speaking)"
                  推进下一句逻辑永不触发
                  → 永远停在 queue[0]
```

对照 `flutter_tts_service.dart`（桌面/iOS）的 pattern：
`setCompletionHandler` 在一句读完时 emit `TtsState.idle`（行 48-50）。
self-built 服务少了这步——onDone emit 'done' 但 Dart 不识别。

### 修复（1 行 + 测试）

```dart
// self_built_tts_service.dart _handleEvent switch:
case 'done':
  _stateController.add(TtsState.idle);
  break;
```

回归测试（`test/services/tts/self_built_tts_service_test.dart`）：

```dart
test('done event maps to TtsState.idle (regression v1.13.2-alpha)', () async {
  final states = <TtsState>[];
  svc.state.listen(states.add);
  await svc.init();
  await emit({'event': 'done', 'utteranceId': 'sent_0'});
  await Future<void>.delayed(Duration.zero);
  expect(states, contains(TtsState.idle));
});
```

## Bug 2：选段朗读语义重构

### 旧逻辑

`reader_body._onReadSelectionAloud` 把选中文字 `SentenceSegmenter.split`，
直接调 `TtsPlaybackController.play(scope: TtsScopeAiMessage)`。结果：

- ephemeral scope，只读选段那几句就停
- 不持久化 last_tts_position（TtsScopeChapter 才持久化）
- 不接入章节边界跳转逻辑
- 选段长 = 多句，但 Bug 1 让它只读 queue[0] → 用户感知"只读一句"

### 新逻辑（用户决策对齐）

| 维度 | 决策 | 实施 |
|---|---|---|
| 跨章行为 | 沿用 TTS 设置（continuous / askAtEnd） | 复用 `TtsReaderController._onChapterBoundaryReached` |
| 起点判定 | 选区首字所在的整句 | `chapterText.indexOf(selectedText)` → 找 sentences[i] 包含该 offset |
| PDF 范围 | 维持现状（只读选段，不接续） | `engine is PdfReaderEngine` 分支保留 ephemeral scope |

### 实施

1. **`TtsReaderController`** 抽出 `_prepareCurrentChapter` helper（章节加载 +
   切句 + 订阅 playback + 订阅 engine location），消除 `start` 与
   新 `startFromSelection` 的代码重复。
2. **`TtsReaderController.startFromSelection({required String selectedText})`**
   调 `_prepareCurrentChapter` 后，用 `_locateSelectionStartIndex` 定位起点
   句，调 `playAt(scope: TtsScopeChapter, startIndex: idx)`。后续的播放、
   高亮、持久化、跳章分支自动复用——零新代码。
3. **`reader_body._onReadSelectionAloud`**：
   - 非 PDF：`ref.read(ttsReaderControllerProvider.notifier).startFromSelection(selectedText: sel.plainText)`
   - PDF：保留 v1.13.0 ephemeral 分支

### 测试

3 个新单测（`tts_reader_controller_test.dart`）：

- `starts at the sentence containing the selection first char`：
  章节文本 `'First sentence. Second one. Third one.'`，选 `'Second one.'`
  → `currentIndex == 1`，scope 是 `TtsScopeChapter`
- `falls back to index 0 when selection text is not in chapter`：
  退化保护，不 throw
- `no-op when engine is null`：边界保护

## 测试统计

- 全量：1658 pass + 25 skipped（+4 新增于 v1.13.2-alpha）
- analyze：0 issues on modified files

## 升级路径

直接装 `zhiyue-1.13.2-alpha-with-fgs.apk` 覆盖 v1.13.1-alpha。
- drift schema v15 不变（无 DB 迁移）
- TTS 设置不重置
- 已有 last_tts_position 跨设备同步不受影响

## 教训

1. **写协议要双端同审**：Kotlin emit `done`、Dart switch 没有 `done` case，
   这种"协议半挂"是双端协议最容易出的 bug。下次写 Kotlin→Dart event 时，
   必须在写 emit 的同时写 Dart 解析（同一 commit）。
2. **"只读一句就停"是经典征兆**：任何"播了一句就停"的多段播放 bug，
   首选假设是 completion 事件未正确转发到调度器。先看
   `_stateController.add(TtsState.idle)` 在不在 completion 路径上。
3. **ephemeral scope 是反模式**：选段朗读原本走 `TtsScopeAiMessage`
   ephemeral 分支，导致它和章节级流程割裂。复用 `TtsScopeChapter` 后，
   持久化、跨章、跳章 UI、自动翻页全部免费得到——再次印证"DRY 重于特例"。

---

