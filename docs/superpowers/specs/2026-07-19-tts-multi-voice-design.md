# TTS 多播音员（Voice）选择 Design

**Date:** 2026-07-19
**Version target:** v1.14.0-alpha
**Type:** User-facing feature
**Scope:** Cross-platform (Android self-built TTS + Desktop flutter_tts)

## 1. Background & Motivation

### 用户反馈

2026-07-19 多用户反馈："目前只有一个播音员的声音，能不能有多个可以选择？"

### 当前状态

- `TtsSettings` 已持久化 `rate / pitch / volume / chapterBoundary`，**无 voice 字段**（`app/lib/features/tts/providers/tts_settings_provider.dart:23-34`）
- `TtsService` 接口**无 voice 相关方法**（`app/lib/services/tts/tts_service.dart`）
- `FlutterTtsServiceImpl`（桌面）封装 `flutter_tts` plugin，未暴露 `getVoices / setVoice`（plugin 本身支持）
- `SelfBuiltTtsServiceImpl`（Android）Kotlin 端 `ZhiYueTtsPlugin.kt` **完全没暴露 voice API**
- 当前用户听到的是系统默认 voice

### 设备 voice 现状

| 平台 | 默认中文 voice 数 | 可扩展性 |
|---|---|---|
| 华为 HarmonyOS / 荣耀 MagicOS | 1（小艺） | 装「讯飞语音+」「百度语音」可加 |
| 小米 HyperOS（国行） | 1-2（小爱） | 装「讯飞 / 百度」或「谷歌安装器 + Google TTS」 |
| OPPO / vivo | 1 | 同上 |
| 三星 One UI | SMT 引擎对中文支持差 | 装 Google TTS 替换 |
| 原生 Android / Pixel | 10+（Google TTS 自带） | 系统设置下载更多语音包 |
| Windows 10/11 | 1-3（Huihui/Kangkang/Yaoyao） | 「设置 → 语音 → 添加声音」下载 Neural voice（10+） |

**核心结论：** 所有平台都支持「装第三方 engine → 系统 TTS 自动识别 → 智阅 `getVoices()` 自动看到」。智阅本次功能不需要 ROM-specific 适配，只需要把 Android/Windows 标准 TTS voice API 封装出来。

## 2. Goal & Non-Goals

### Goal

- 用户能在「设置 → 朗读 → 朗读声音」里看到当前设备所有可用 voice
- 可以选任意 voice 作为全局默认（持久化跨会话）
- 可试点「试听」按钮预览 voice 音色
- voice 列表为空或不够时，提供「去系统添加 TTS 引擎」入口跳转系统设置

### Non-Goals（明确不做）

- **不内置音色预设**（不通过变调模拟"男声/女声/儿童"）—— 系统已有真 voice，变调反而听感差
- **不接入云端 TTS**（Azure/讯飞云/百度云）—— 需网络/密钥/付费，与本地优先策略冲突
- **不内置推荐引擎清单 UI**（讯飞/百度/Google TTS 的清单）—— 推到后续版本（v1.16+）
- **不跨设备同步 voiceId** —— voiceId 是设备特定的（A 装的 voice B 没有），按 M2.0a outbox 规则标记为「设备本地偏好」
- **不在 mini 控制台即时切换 voice** —— 范围控制，所有切换走设置页（v1.14 之后视用户反馈再加）
- **不引入 WinRT Neural voice 支持**（Windows 11 xiaoxiao/yunyang 等）—— flutter_tts 走 SAPI5，WinRT voice 通过「系统设置 → 添加声音」自动注册到 SAPI5 后会被 SAPI5 看到，智阅侧无需改动

## 3. Architecture

### 数据流

```
┌─────────────────────────────────────────────────────────────┐
│ SettingsPage → VoiceListPage                                 │
│   ↓ 用户进入页面                                              │
│ ttsVoicesProvider (FutureProvider<List<TtsVoice>>)           │
│   ↓ 调                                                       │
│ TtsService.getVoices()  ← 抽象方法（新加）                   │
│   ├ Android: SelfBuiltTtsServiceImpl                         │
│   │   ↓ MethodChannel.invokeMethod('getVoices')              │
│   │   Kotlin ZhiYueTtsService.handleGetVoices()              │
│   │   ↓ tts.voices.map { Voice -> Map }                      │
│   │   返回 List<Map>                                         │
│   └ Desktop: FlutterTtsServiceImpl                           │
│       ↓ _tts.getVoices()  (flutter_tts plugin)               │
│       返回 List<Map>                                         │
└─────────────────────────────────────────────────────────────┘

用户选 voice：
VoiceListPage → TtsSettingsNotifier.setVoice(id)
   ↓ 持久化 tts_settings.json
   ↓ 同时调 TtsService.setVoice(id)（即时生效）
TtsService.setVoice  ← 抽象方法（新加）
   ├ Android: 缓存 _cachedVoiceId，下次 speakSentence piggy-back 到 SPEAK args
   └ Desktop: _tts.setVoice(id) 即时生效

用户点试听：
VoiceListPage → TtsService.previewVoice(id, sampleText)
   ↓ setVoice(id) + speakSentence(Sentence(sampleText))
   ↓ speak done 回调中恢复原 voiceId
``### TtsVoice 数据类

```dart
/// A single TTS voice exposed by the platform's speech engine.
///
/// [id] is the platform-unique identifier (Android Voice.name + locale,
/// Windows SAPI5 voice ID). Stable across launches for the same engine,
/// but **not portable across devices** (different ROMs / engine installs
/// produce different voice sets).
///
/// [locale] is BCP47 (e.g. "zh-CN", "en-US"). Used to filter voices when
/// the user's book language is known.
class TtsVoice {
  final String id;
  final String name;       // 用户可见名（"Google 普通话（中国大陆）"）
  final String locale;     // BCP47
  final bool isDefault;    // 是否系统默认 voice（用于 UI 标记）

  const TtsVoice({
    required this.id,
    required this.name,
    required this.locale,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'locale': locale, 'isDefault': isDefault};
  factory TtsVoice.fromJson(Map<String, dynamic> j) => TtsVoice(
        id: j['id'] as String,
        name: j['name'] as String,
        locale: j['locale'] as String,
        isDefault: (j['isDefault'] as bool?) ?? false,
      );

  @override
  bool operator ==(Object other) => other is TtsVoice && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
```

### TtsService 接口扩展

```dart
abstract class TtsService {
  // ... existing methods ...

  /// Returns all voices available on this device.
  ///
  /// Returns empty list when the platform doesn't expose any (rare:
  /// Huawei/Honor with locked engine, or pre-Android 21).
  /// **Never throws** — engine errors fall back to empty list + UI shows
  /// "no voices available, please install a TTS engine".
  Future<List<TtsVoice>> getVoices();

  /// Sets the active voice for subsequent speak() calls.
  ///
  /// Returns true if the platform accepted the voice. Returns false if
  /// [voiceId] is not in the current voice list (engine uninstall, stale
  /// persisted setting, etc.) — caller should fall back to system default.
  Future<bool> setVoice(String? voiceId);

  /// Previews a voice without changing the user's global setting.
  ///
  /// Implementations should: (1) save current voice, (2) set to [voiceId],
  /// (3) speak [sampleText], (4) on next completion/stop event, restore
  /// the saved voice. This avoids needing a second TTS instance.
  ///
  /// [sampleText] defaults to a localized "Hello, this is a voice preview."
  /// when null.
  Future<void> previewVoice(String voiceId, {String? sampleText});

  /// Opens the platform's system TTS settings page (where the user can
  /// install / select TTS engines). No-op on platforms without a system
  /// page (returns false).
  Future<bool> openSystemTtsSettings();
}
```

### TtsSettings 扩展

```dart
class TtsSettings {
  final double rate;
  final double pitch;
  final double volume;
  final TtsChapterBoundary chapterBoundary;
  final String? voiceId;  // ← NEW. null = system default

  // ... existing constructors / copyWith ...

  Map<String, dynamic> toJson() => {
        'rate': rate,
        'pitch': pitch,
        'volume': volume,
        'chapterBoundary': chapterBoundary.name,
        'voiceId': voiceId,  // ← NEW
      };

  factory TtsSettings.fromJson(Map<String, dynamic> j) => TtsSettings(
        // ... existing fields ...
        voiceId: j['voiceId'] as String?,  // ← NEW (null-safe: 旧文件无此字段 → null)
      );
}

class TtsSettingsNotifier {
  // ... existing methods ...

  Future<void> setVoice(String? voiceId) async {
    state = state.copyWith(voiceId: voiceId);
    await _persist();
    // 同步到 TtsService（即时生效，不依赖重启）
    await ref.read(ttsServiceProvider).setVoice(voiceId);
  }
}
```

### Android Kotlin 扩展

**新增 3 个 MethodChannel handler：**

```kotlin
// ZhiYueTtsPlugin.kt (or ZhiYueTtsService.kt)
when (call.method) {
    "getVoices" -> {
        if (tts == null) {
            result.error("NOT_INIT", "TTS not initialized", null)
            return@setMethodCallHandler
        }
        val voices = tts.voices?.map { v ->
            mapOf(
                "id" to "${v.name}|${v.locale.toLanguageTag()}",
                "name" to v.name,
                "locale" to v.locale.toLanguageTag(),
                "isDefault" to (v.name == tts.defaultVoice?.name)
            )
        } ?: emptyList<Map<String, Any>>()
        result.success(voices)
    }
    "setVoice" -> {
        val voiceId = call.argument<String>("voiceId") ?: run {
            result.success(false); return@setMethodCallHandler
        }
        val matched = tts?.voices?.find { "${it.name}|${it.locale.toLanguageTag()}" == voiceId }
        if (matched != null) {
            tts?.voice = matched
            result.success(true)
        } else {
            result.success(false)  // voice 不存在（engine 卸载等）
        }
    }
    "openSystemTtsSettings" -> {
        try {
            val intent = Intent(android.speech.tts.TextToSpeech.Engine.ACTION_CHECK_TTS_DATA)
            // or ACTION_GET_SAMPLE_TEXT; the canonical one is:
            val intent = Intent("com.android.settings.TTS_SETTINGS")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }
    // ...
}
```

**SPEAK args 扩展（piggy-back voiceId）：**

```kotlin
// ZhiYueTtsService.handleSpeak
private fun handleSpeak(extras: Bundle) {
    val text = extras.getString("text") ?: return
    val locale = extras.getString("locale") ?: "zh-CN"
    val voiceId = extras.getString("voiceId")  // ← NEW（null = 用当前 voice）

    if (voiceId != null) {
        val matched = tts?.voices?.find { "${it.name}|${it.locale.toLanguageTag()}" == voiceId }
        if (matched != null) tts?.voice = matched
    }

    // ... existing setLanguage / setRate / setPitch / setVolume logic ...
    tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
}
```

```dart
// SelfBuiltTtsServiceImpl.speakSentence (Dart 侧 piggy-back)
@override
Future<void> speakSentence(Sentence sentence) async {
  if (!_initialized) await init();
  await _methodChannel.invokeMethod('speak', {
    'text': sentence.text,
    'locale': sentence.locale,
    'sentenceIndex': _currentSentenceIdx,
    'rate': _cachedRate,
    'pitch': _cachedPitch,
    'volume': _cachedVolume,
    if (_cachedVoiceId != null) 'voiceId': _cachedVoiceId,  // ← NEW
  });
}
```

### Desktop (FlutterTts) 实现

```dart
@override
Future<List<TtsVoice>> getVoices() async {
  final raw = await _tts.getVoices();
  if (raw == null) return const [];
  return (raw as List<dynamic>).map((v) {
    final map = v as Map<dynamic, dynamic>;
    return TtsVoice(
      id: map['name'] as String,
      name: map['name'] as String,
      locale: map['locale'] as String,
    );
  }).toList();
}

@override
Future<bool> setVoice(String? voiceId) async {
  if (voiceId == null) {
    // flutter_tts 没有显式「回到默认」API；用空字符串触发 plugin 内部 fallback
    final r = await _tts.setVoice('');
    return r == 1;
  }
  final r = await _tts.setVoice(voiceId);
  return r == 1;
}

@override
Future<bool> openSystemTtsSettings() async {
  // Windows: open Settings → Time & Language → Speech
  // 用 Process.run('start', ['ms-settings:speech'])，错误则返回 false
  if (!Platform.isWindows) return false;
  try {
    await Process.run('cmd', ['/c', 'start', 'ms-settings:speech']);
    return true;
  } catch (_) {
    return false;
  }
}
```

## 4. UI Design

### 入口

**设置 → 朗读** 页面，在「语速 / 音调 / 音量」之后加新条目「朗读声音」：

```
朗读
├─ 语速                    [____●____] 0.0
├─ 音调                    [____●____] 1.0
├─ 音量                    [________●] 1.0
├─ 章节边界行为            [继续朗读 ▼]
└─ 朗读声音                Google 普通话（女声）→   ← NEW
```

点击「朗读声音」打开 `VoiceListPage`。

### VoiceListPage 布局

```
┌──────────────────────────────────────────────┐
│ ← 朗读声音                                    │
├──────────────────────────────────────────────┤
│ ○ 系统默认                                    │
│ ● Google 普通话（中国大陆）        [试听]     │
│ ○ Google 普通话（粤语）            [试听]     │
│ ○ 讯飞 小燕                        [试听]     │
│ ○ 讯飞 小宇                        [试听]     │
│ ○ HUAWEI 小艺                      [试听]     │
│                                              │
│ （设备未提供声音时显示此 card）              │
│ ┌────────────────────────────────────────┐  │
│ │ 当前设备未提供可选声音                  │  │
│ │ 请在系统 TTS 设置里安装引擎            │  │
│ └────────────────────────────────────────┘  │
│                                              │
│ ───────────────────────────                  │
│ 需要更多声音？                                │
│ [打开系统 TTS 设置]                           │
└──────────────────────────────────────────────┘
```

**关键交互：**

- 点击 voice 行 → 选中（radio 高亮）→ 调 `TtsSettingsNotifier.setVoice(id)` → 持久化 + 即时生效
- 点击 [试听] → 调 `TtsService.previewVoice(id)` → speak "你好，这是该声音的试听样本。" → 完成后恢复全局 voice
- 试听期间 [试听] 按钮禁用（避免连点）
- voice 列表为空 → 显示「未提供声音」提示 + 「打开系统 TTS 设置」按钮（唯一出口）
- 「打开系统 TTS 设置」按钮在底部固定显示（无论列表是否为空）

### 加载状态

- 进入 VoiceListPage 时显示 CircularProgressIndicator（~100ms-500ms，取决于设备）
- 加载失败 → 显示错误 message + 重试按钮
- 加载完成但列表为空 → 显示「未提供声音」card

## 5. Persistence & Sync

### tts_settings.json schema（新增字段）

```json
{
  "rate": 0.0,
  "pitch": 1.0,
  "volume": 1.0,
  "chapterBoundary": "continuous",
  "voiceId": "Google 普通话（中国大陆）|zh-CN"  // ← NEW, nullable
}
```

**向后兼容：** 旧 `tts_settings.json` 无 `voiceId` 字段 → `fromJson` 读 null → 用系统默认。无需 schema migration。

### Outbox 同步规则

**voiceId 不进 outbox**（设备本地偏好）。M2.0a sync rules 已建立「设备本地偏好」分类：

- `displayOptions / fontSize / typography` 等 reader 偏好不同步
- `voiceId` 加入同一分类（在 `SyncRules.shouldSync()` 加 1 个判断）
- 跨设备 sync 时 `tts_settings.json` 不同步（与现有行为一致）

## 6. Error Handling

### 失效 voiceId 容错

启动时 `ttsSettings.voiceId != null`：

1. TtsService.init() 后调 `getVoices()`
2. 如果 voiceId 不在列表 → log warning，**保留 voiceId**（不删）但用系统默认播放
3. 用户进 VoiceListPage 时若选中的 voiceId 不在列表，UI 显示「（已失效，可能引擎已卸载）」+ 红色文字
4. 用户选其他 voice → 替换 voiceId；用户选「系统默认」→ voiceId = null

### 试听播放冲突

试听触发时：

- 如果用户正在朗读 → 试听按钮禁用（显示 `朗读中，无法试听` tooltip）
- 如果用户在 mini 控制台暂停 → 试听可用，但试听完成后状态回到 paused（不自动 resume）
- 如果试听播放时收到 SPEAK intent（Kotlin 重入）→ 按 v1.13.8 pendingSpeak 模式排队（不冲突）

### MethodChannel 失败

- `getVoices` invokeMethod throw → 返回空列表 + log warning
- `setVoice` invokeMethod throw → 返回 false → UI SnackBar「设置声音失败，请稍后再试」
- `openSystemTtsSettings` throw → 返回 false → UI SnackBar「无法打开系统设置」

## 7. TDD Task Decomposition

| Task | Scope | 测试 |
|---|---|---|
| **T1** | `TtsVoice` 数据类 + `TtsService.getVoices/setVoice/previewVoice/openSystemTtsSettings` 抽象方法 | Dart 单测：TtsVoice.fromJson/toJson round-trip + equality（2 测试）；fake TtsService 实现所有新方法（5 测试 stub） |
| **T2** | `FlutterTtsServiceImpl` 实现 getVoices / setVoice / previewVoice / openSystemTtsSettings | Dart 单测：mock FlutterTts instance，verify getVoices returns List<TtsVoice>，setVoice(null) 调用 plugin with ''，previewVoice 在 completion 后 restore（4 测试） |
| **T3** | `SelfBuiltTtsServiceImpl` MethodChannel 接线 getVoices / setVoice / previewVoice / openSystemTtsSettings | Dart 单测：mock MethodChannel，verify invokeMethod 参数 + 返回值 mapping（5 测试） |
| **T4** | Kotlin ZhiYueTtsService handleGetVoices / handleSetVoice / handleOpenSystemTtsSettings + handleSpeak args voiceId | Robolectric test：fake TextToSpeech 返回 voice set，verify getVoices 返回正确 List<Map>，verify setVoice 找到匹配 voice 并应用（3 Kotlin 测试） |
| **T5** | `TtsSettings.voiceId` 持久化 + `TtsSettingsNotifier.setVoice` 即时同步 TtsService | Dart 单测：toJson/fromJson round-trip（含 voiceId null 路径）+ setVoice 触发 persist + service.setVoice（3 测试） |
| **T6** | `VoiceListPage` UI（radio list + 试听 + 系统跳转 + 空状态） | Widget test：列表渲染、点击触发 setVoice、试听触发 previewVoice、空状态显示提示（4 测试） |
| **T7** | Release v1.14.0-alpha | 全量 flutter test + Kotlin Robolectric + APK 构建与 marker verify + Windows installer + tag push |

## 8. Risks

1. **flutter_tts Windows SAPI5 voice ID 格式不稳**（不同 Windows build 返回不同 ID）→ voiceId 持久化可能在系统更新后失效。Mitigation：失效容错已设计（第 6 节）。Risk: 低。
2. **国产 ROM TextToSpeech.getVoices() 返回 null**（华为小艺 engine 可能锁死）→ 列表为空 → 用户看到「未提供声音」+ 系统跳转。Mitigation：UI 已设计空状态。Risk: 低。
3. **试听 voice 期间主朗读触发**（用户在 mini 控制台点播放）→ voice 状态混乱。Mitigation：previewVoice 期间 mini 控制台禁用「播放」按钮（loading 状态）。Risk: 低。
4. **Android TextToSpeech.getVoices() 阻塞主线程**（部分 ROM sync 调用慢）→ 设置页卡顿。Mitigation：getVoices 在 isolate/compute 里跑？实际 flutter_tts Android 已 async，Kotlin `tts.voices` 也是 fast property access。Risk: 极低。
5. **setVoice(null) 在国产 ROM 行为不一致**（华为可能拒绝空 voice → 用上次 voice）→ fallback 失效。Mitigation：用 `tts.defaultVoice` 显式设置而非 null。Risk: 低。
6. **Windows ms-settings: URI 在 Win10 早期版本不支持**（1803 之前）→ openSystemTtsSettings 返回 false。Mitigation：UI 显示 SnackBar 失败提示，用户手动开「设置」。Risk: 极低。

## 9. Verification

### 单元测试

`cd C:\zhiyue_build_s3 && flutter test`，预期 ~1700 pass（v1.13.11 是 1676，+19 新测试 + skip 不变）。

### Kotlin Robolectric

`cd C:\zhiyue_build_s3\app\android && ./gradlew :app:testWithFgsDebugUnitTest`，预期 ~36 pass（v1.13.11 是 33，+3 新测试）。

### APK + installer marker 验证

**新增 libapp.so marker（public API + Map key）：**

- `TtsVoice` 类名（公开类，AOT 保留）
- `getVoices` / `setVoice` / `previewVoice` 方法名（公开 API）
- `'voiceId'` 字面值（Map key，AOT 保留）
- `'系统默认'` / `'打开系统 TTS 设置'` UI 字符串

**新增 classes.dex marker（Kotlin 字符串）：**

- `"getVoices"` / `"setVoice"` / `"openSystemTtsSettings"` MethodChannel method 名
- Kotlin 日志字符串 `getVoices returned N voices` / `setVoice applied`

**Not expected（AOT 剥离）：**

- `_VoiceListPageState` 等私有类名（AOT 删私有符号）
- 测试 fake 类名（如 `_FakeTtsService`）

### 用户真机验证（手工）

| 场景 | 步骤 | 预期 |
|---|---|---|
| A. 列表加载 | 设置 → 朗读 → 朗读声音 | 显示当前设备所有可用 voice（1-15 个，视 ROM） |
| B. 选择持久化 | 选某 voice → 退出设置 → 重新进入 | 选中状态保持 |
| C. 试听 | 点 [试听] | 听到该 voice 朗读 "你好，这是该声音的试听样本。" |
| D. 试听恢复 | 试听完后点「朗读」 | 朗读仍用全局选中的 voice |
| E. 系统跳转 | 点「打开系统 TTS 设置」 | 跳到 Android 系统 TTS 设置页 |
| F. 装新 engine | 装讯飞语音+ → 重启 app → 进 voice 列表 | 看到讯飞的 voice 加入列表 |
| G. 失效 voiceId | 选某 voice → 卸载对应 engine → 重启 app | 选中 voice 显示「已失效」，UI 提示重选 |
| H. 空列表 | 设备完全无 TTS engine（极端） | 显示「未提供声音」+ 系统跳转入口 |

### 分发

- Android: `zhiyue-1.14.0-alpha-with-fgs.apk`（withFgs flavor）→ Desktop + 华为同步盘
- Windows: `zhiyue-setup-1.14.0-alpha.exe` → Desktop + 华为同步盘
- Tag: `v1.14.0-alpha` + `m-tts-multi-voice`（s4-build + master fast-forward）
- Gitee push

## 10. File Structure

**新增：**

- `app/lib/services/tts/tts_voice.dart` — TtsVoice 数据类
- `app/lib/features/tts/providers/tts_voices_provider.dart` — `ttsVoicesProvider` FutureProvider
- `app/lib/features/tts/pages/voice_list_page.dart` — VoiceListPage + controller
- `app/test/services/tts/tts_voice_test.dart` — TtsVoice 数据类测试
- `app/test/services/tts/flutter_tts_service_voice_test.dart` — FlutterTtsServiceImpl voice 测试
- `app/test/services/tts/self_built_tts_service_voice_test.dart` — SelfBuiltTtsServiceImpl voice 测试
- `app/test/features/tts/pages/voice_list_page_test.dart` — Widget test
- `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceVoiceTest.kt` — Robolectric test
- `docs/releases/release-notes-v1.14.0-alpha.md`

**修改：**

- `app/lib/services/tts/tts_service.dart` — 加抽象方法
- `app/lib/services/tts/tts_service_factory.dart`（视实现需要）
- `app/lib/services/tts/flutter_tts_service.dart` — 实现 4 个新方法
- `app/lib/services/tts/self_built_tts_service.dart` — 实现 4 个新方法 + speakSentence piggy-back voiceId
- `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsPlugin.kt` — 加 3 个 handler
- `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt` — handleSpeak 加 voiceId 参数
- `app/lib/features/tts/providers/tts_settings_provider.dart` — 加 voiceId 字段 + setVoice notifier
- `app/lib/features/settings/pages/tts_settings_section.dart` — 加「朗读声音」入口
- `app/lib/l10n/app_zh.arb` / `app_en.arb` — i18n strings
- `app/lib/gen_l10n/*.dart` — 自动生成（用 Python binary-safe 写入绕 CRLF/LF）
- `app/pubspec.yaml` — version `1.14.0-alpha+2009`
- `CHANGELOG.md` — `[1.14.0-alpha]` 段落
- `app/windows/installer/zhiyue.iss` — `MyAppVersion` → `1.14.0-alpha`

## 11. Open Questions

无。所有决策点已在澄清问题阶段确认。

## 12. References

- v1.13.7-alpha Bug 4 speak-args piggy-back 模式 → [[project-zhiyue-2026-07-19-v1-13-7-tts-bug-batch-7]]
- v1.13.10-alpha Bug 1 TtsState.stopped / TtsPlaybackState.userStopped 字段扩展模式 → [[project-zhiyue-2026-07-19-v1-13-10-stop-auto-resume]]
- M2.0a outbox 设备本地偏好分类规则 → [[project-zhiyue-m2-0a-complete]]
- feedback_no_dispose_time_fire_and_forget 即时落盘 → [[feedback-no-dispose-time-fire-and-forget]]
- feedback_flutter_strip_cache_trap APK marker 验证 → [[feedback-flutter-strip-cache-trap]]
- TtsSettingsNotifier 现有持久化模式 → `app/lib/features/tts/providers/tts_settings_provider.dart`
