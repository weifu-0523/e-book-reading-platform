# v1.13.10-alpha

**发布日期**：2026-07-19
**类型**：hotfix（2 bug：朗读关闭后自动恢复 + 选段朗读 whitespace fallback）
**上一版本**：v1.13.9-alpha

## 摘要

v1.13.9-alpha 修了 service 重建后 companion 残留，但用户测试发现 2 个新问题：
1. 朗读关闭后约 1 秒自动恢复
2. 3 本书测试选中朗读，2 本仍从章节头开始

本版本修复这两个 bug。

## Bug 1：朗读关闭后自动恢复（P0）

### 决定性诊断证据

```
[1784435465044] onStartCommand #76 action=dev.zhiyue.tts.STOP    ← 用户点通知栏停止
[1784435465054] EMIT_ATTEMPT type=state total_attempt=105        ← state=stopped emit
[1784435465889] onCreate start (companion state reset)           ← 845ms 后 service 重建
[1784435465900] onStartCommand #77 action=dev.zhiyue.tts.SPEAK   ← !!! 自动 SPEAK
[1784435465900] handleSpeak textLen=12 ... initStatus=-999
[1784435465900] handleSpeak DEFER: tts not ready
[1784435465954] flushing pending SPEAK after TTS init
```

新 SPEAK 的 `textLen=12` ≠ 上句 `sent_19 textLen=37`，证实是 queue 自动推进到 sent_20。

### 真根因

`SelfBuiltTtsServiceImpl._parseState` 把 Kotlin `'stopped'` 事件翻译成 `TtsState.idle`：

```dart
case 'idle':
case 'stopped':
  return TtsState.idle;  // ← BUG: 把 stop 当成 idle
```

`TtsPlaybackController._onServiceState` 看到 `idle + phase==speaking` → 误判句子自然播完 → 推进 queue → 调 `_speakCurrent()` → 发 SPEAK → service 已被 stopSelf 销毁 → ensureServiceStarted 重建 → onCreate → 朗读自动恢复（实际是下一句 sent_20）。

### 次生问题

TtsReaderController 的 `_onPlaybackChange` phase=idle 分支会触发 `_onChapterBoundaryReached`。当用户在朗读本章最后一句时点停止，会错误地：
- `chapterBoundary: continuous` → 自动到下一章
- `chapterBoundary: askAtEnd` → 弹"继续听下一章？"SnackBar

### 修复（4 文件）

| 文件 | 改动 |
|---|---|
| `app/lib/services/tts/tts_service.dart` | `enum TtsState` 加 `stopped` 成员 |
| `app/lib/services/tts/self_built_tts_service.dart` | `_parseState('stopped')` 返回 `TtsState.stopped`（不再 fallthrough 到 idle） |
| `app/lib/features/tts/providers/tts_playback_controller.dart` | (a) `TtsPlaybackState` 加 `userStopped` 字段（默认 false）；(b) `_onServiceState` 新增 stopped 分支重置 state 不推进 queue；(c) `driveStop` 也设 `userStopped=true` |
| `app/lib/features/tts/providers/tts_reader_controller.dart` | `_onPlaybackChange` phase=idle 分支读 `playback.userStopped`，user stop 不触发 chapter-boundary |

### 测试（4 新）

- `tts_playback_controller_test.dart` group `'external stop (Bug 1)'`：
  - TtsState.stopped 收到时 queue 不推进 + state.phase=idle + userStopped=true + 不发新 SPEAK
  - TtsState.idle（自然完成）仍正常推进 queue
  - driveStop 设 userStopped=true
- `self_built_tts_service_test.dart`：`{event:state, state:stopped}` 映射到 `TtsState.stopped`
- `tts_reader_controller_test.dart` group `'user stop suppresses chapter boundary (Bug 1)'`：state=stopped 不触发 askContinue prompt

## Bug 2：选段朗读 whitespace fallback

### 真根因

3 本书测试选中朗读：1 本工作，2 本仍从章节头开始。

`TtsReaderController._locateSelectionStartIndex`:

```dart
final startOffset = chapterText.indexOf(selectedText);
if (startOffset < 0) return 0;  // ← BUG: fallback 到 0（章节头）
```

`chapterText` 来自 `ttsChapterTextResolverProvider`（BookTextExtractor 输出）。`selectedText` 来自 EPUB 渲染层 `SelectionAssistant.plainText`。两者在某些 EPUB 章节（HTML 含 `<br>`、连续空格、`&nbsp;` 等）存在 **whitespace 差异**（multiple spaces vs single、newline vs space、leading/trailing）。`indexOf` 严格匹配返回 -1 → fallback 到 0 → 从章节头开始。

工作的 1 本书：HTML 渲染与 BookTextExtractor 输出完全一致。
失败的 2 本书：HTML 含触发 whitespace 差异的元素。

### 修复

`_locateSelectionStartIndex` 严格 `indexOf` 失败时调用新增的 `_findSelectionStartWhitespaceInsensitive`：

```dart
static int _findSelectionStartWhitespaceInsensitive(
  String chapterText,
  String selectedText,
) {
  final nonWs = selectedText.replaceAll(RegExp(r'\s+'), '');
  if (nonWs.length < 3) return -1;
  final key = nonWs.length > 30 ? nonWs.substring(0, 30) : nonWs;
  final pattern = key.split('').map(RegExp.escape).join(r'\s*');
  final match = RegExp(pattern).firstMatch(chapterText);
  return match?.start ?? -1;
}
```

算法：
1. Strip 掉 selectedText 所有 whitespace → nonWs
2. < 3 字符 bail（太短不唯一）
3. 截断到前 30 字符（regex 性能 + 章节内唯一性平衡）
4. 每个非空白 char 用 `RegExp.escape` 转义，用 `\s*` 连接
5. `firstMatch(chapterText)` 返回原 offset（保留 sentence.charStart 映射）

### 测试（3 新）

`group 'TtsReaderController.startFromSelection whitespace fallback (Bug 2)'`:
- chapterText=`'First sentence. Second one. Third one.'` selectedText=`'Second\none.'`（newline 差异）→ 命中 sent_1
- chapterText=`'First  sentence.'`（双空格）selectedText=`'First sentence.'`（单空格）→ 命中 sent_0
- chapterText=`'你好。'` selectedText=`'你好 世界。'`（多余字）→ 仍 -1 fallback 到 0（多余字符语义不一致，不能模糊匹配）

## 用户测试步骤

1. 装 v1.13.10-alpha（覆盖 v1.13.9-alpha，versionCode 2007 > 2006）

2. **回归 Bug 1 场景 A（核心）**：
   - 打开一本书 → 开始朗读本章
   - 下拉通知栏 → 点"停止"按钮
   - 等 10 秒
   - **应不再自动恢复朗读**（v1.13.9-alpha 会自动恢复）

3. **回归 Bug 1 场景 B（mini 控制）**：
   - 开始朗读本章
   - 点 mini 控制台"关闭"按钮（X 图标）
   - **应停止且 mini 控制台消失，不自动恢复**

4. **回归 Bug 1 场景 C（chapter-boundary）**：
   - 在设置里把 TTS 章节边界设为"自动到下一章"或"章节末询问"
   - 开始朗读本章最后一句
   - 朗读中点"停止"
   - **不应自动到下一章，不应弹"继续听下一章？"SnackBar**

5. **回归 Bug 2 场景 D（之前失败的 2 本书）**：
   - 用 v1.13.9-alpha 测试时选段朗读从章节头开始的 2 本书
   - 选中文字 → 点"朗读选中"
   - **应立即播放选中句子（不是章节头）**

6. **回归 Bug 2 场景 E（之前工作的 1 本书）**：
   - 用之前工作的 1 本书测试选段朗读
   - **仍能正确从选中句子开始**

## 升级路径

直接装 `zhiyue-1.13.10-alpha-with-fgs.apk` 覆盖 v1.13.9-alpha。

- drift schema v15 不变（无 DB 迁移）
- TTS 设置不重置
- versionCode 2007 > v1.13.9 的 2006

## Breaking Change

无。
