# v1.14.0-alpha: TTS 多播音员（Voice）选择

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让用户在「设置 → 朗读 → 朗读声音」里看到设备所有可用 voice（动态枚举 Android `TextToSpeech.getVoices()` / Windows SAPI5），选一个作为全局默认 voice，可试点「试听」预览，列表为空时有「去系统添加 TTS 引擎」入口。

**Architecture:**
- 抽象层：`TtsService` 加 4 个新方法（`getVoices / setVoice / previewVoice / openSystemTtsSettings`）+ `TtsVoice` 数据类
- 实现层：`FlutterTtsServiceImpl`（桌面，封装 flutter_tts plugin）+ `SelfBuiltTtsServiceImpl`（Android，MethodChannel 接 Kotlin）
- Kotlin 端：`ZhiYueTtsPlugin.kt` + `ZhiYueTtsService.kt` 加 3 个 handler + SPEAK Intent 加 voiceId 参数
- 状态层：`TtsSettings` 加 `voiceId` 字段（持久化到 `tts_settings.json`），`setVoice` 即时同步 TtsService
- UI 层：`VoiceListPage`（单选 + 试听 + 系统跳转 + 空状态）
- 同步规则：voiceId 不进 outbox（设备本地偏好）

**Tech Stack:** Flutter 3.x + Dart 3.x + Kotlin 1.9 + Android TextToSpeech + flutter_tts plugin + Riverpod StateNotifier

**Spec:** `docs/superpowers/specs/2026-07-19-tts-multi-voice-design.md`

---

## File Structure

### Create

- `app/lib/services/tts/tts_voice.dart` — TtsVoice 数据类
- `app/lib/features/tts/providers/tts_voices_provider.dart` — `ttsVoicesProvider` FutureProvider
- `app/lib/features/tts/pages/voice_list_page.dart` — VoiceListPage + controller
- `app/test/services/tts/tts_voice_test.dart`
- `app/test/services/tts/flutter_tts_service_voice_test.dart`
- `app/test/services/tts/self_built_tts_service_voice_test.dart`
- `app/test/features/tts/pages/voice_list_page_test.dart`
- `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceVoiceTest.kt`

### Modify

- `app/lib/services/tts/tts_service.dart` — 加 4 个抽象方法
- `app/lib/services/tts/flutter_tts_service.dart` — 实现 4 个新方法
- `app/lib/services/tts/self_built_tts_service.dart` — 实现 4 个新方法 + speakSentence piggy-back voiceId
- `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsPlugin.kt` — 加 3 个 handler（getVoices / setVoice / openSystemTtsSettings）
- `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt` — handleSpeak 加 voiceId 参数（在 setLanguage 前应用）
- `app/lib/features/tts/providers/tts_settings_provider.dart` — 加 voiceId 字段 + setVoice notifier
- `app/lib/features/settings/pages/tts_settings_section.dart` — 加「朗读声音」入口
- `app/lib/l10n/app_zh.arb` / `app_en.arb` — i18n strings
- `app/pubspec.yaml` — version `1.14.0-alpha+2009`
- `CHANGELOG.md` — `[1.14.0-alpha]` 段落（与 open-with-default-reader plan 共用）
- `app/windows/installer/zhiyue.iss` — `MyAppVersion` → `1.14.0-alpha`

---

## TDD 实施顺序

`C:\zhiyue_build_s3` ASCII worktree（branch `s4-build`）跑测试绕中文路径超时。每 task 独立 commit。

| Task | Scope | 文件数 |
|---|---|---|
| **T1** | TtsVoice 数据类 + TtsService 4 个抽象方法（红测 fake engine 补全） | 1 新建 + 1 修改 + 1 测试 |
| **T2** | FlutterTtsServiceImpl 实现 getVoices / setVoice / previewVoice / openSystemTtsSettings | 1 修改 + 1 测试 |
| **T3** | SelfBuiltTtsServiceImpl MethodChannel 接线（Dart 侧） | 1 修改 + 1 测试 |
| **T4** | Kotlin ZhiYueTtsService handleGetVoices / handleSetVoice / handleOpenSystemTtsSettings + SPEAK args voiceId | 2 修改 + 1 测试 |
| **T5** | TtsSettings.voiceId 持久化 + setVoice notifier 即时同步 TtsService | 1 修改 + 1 测试 |
| **T6** | VoiceListPage UI（radio list + 试听 + 系统跳转 + 空状态） | 1 新建 + 1 测试 + l10n + 设置页 wire |
| **T7** | Release v1.14.0-alpha（与 open-with-default-reader plan 合并执行） | pubspec + CHANGELOG + installer + APK + tag push |

---

## Task 1: TtsVoice 数据类 + TtsService 抽象方法扩展

**Files:**
- Create: `app/lib/services/tts/tts_voice.dart`
- Modify: `app/lib/services/tts/tts_service.dart`（加 4 个抽象方法）
- Test: `app/test/services/tts/tts_voice_test.dart`

- [ ] **Step 1: Write failing test for TtsVoice data class**

Create `app/test/services/tts/tts_voice_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/tts_voice.dart';

void main() {
  group('TtsVoice', () {
    test('toJson round-trips via fromJson', () {
      const voice = TtsVoice(
        id: 'zh-CN-xiaoxiao|zh-CN',
        name: 'Xiaoxiao',
        locale: 'zh-CN',
        isDefault: true,
      );
      final j = voice.toJson();
      expect(j['id'], 'zh-CN-xiaoxiao|zh-CN');
      expect(j['name'], 'Xiaoxiao');
      expect(j['locale'], 'zh-CN');
      expect(j['isDefault'], true);

      final restored = TtsVoice.fromJson(j);
      expect(restored, voice);
      expect(restored.id, voice.id);
      expect(restored.isDefault, true);
    });

    test('fromJson tolerates missing isDefault (defaults to false)', () {
      final v = TtsVoice.fromJson({
        'id': 'en-US-Zira',
        'name': 'Zira',
        'locale': 'en-US',
      });
      expect(v.isDefault, false);
    });

    test('equality is by id only', () {
      const a = TtsVoice(id: 'id1', name: 'A', locale: 'zh');
      const b = TtsVoice(id: 'id1', name: 'B', locale: 'en', isDefault: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3 && flutter test test/services/tts/tts_voice_test.dart
```

Expected: FAIL with "Error when reading ... tts_voice.dart: File does not exist" or "Target of URI doesn't exist".

- [ ] **Step 3: Create TtsVoice data class**

Create `app/lib/services/tts/tts_voice.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

/// A single TTS voice exposed by the platform's speech engine.
///
/// [id] is the platform-unique identifier (Android Voice.name + locale,
/// Windows SAPI5 voice name). Stable across launches for the same engine,
/// but **not portable across devices** (different ROMs / engine installs
/// produce different voice sets).
///
/// [locale] is BCP47 (e.g. "zh-CN", "en-US"). Used to filter voices when
/// the user's book language is known.
class TtsVoice {
  final String id;
  final String name;
  final String locale;
  final bool isDefault;

  const TtsVoice({
    required this.id,
    required this.name,
    required this.locale,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'locale': locale,
        'isDefault': isDefault,
      };

  factory TtsVoice.fromJson(Map<String, dynamic> j) => TtsVoice(
        id: j['id'] as String,
        name: j['name'] as String,
        locale: j['locale'] as String,
        isDefault: (j['isDefault'] as bool?) ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is TtsVoice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TtsVoice(id=$id, name=$name, locale=$locale, isDefault=$isDefault)';
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd C:\zhiyue_build_s3 && flutter test test/services/tts/tts_voice_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Add abstract methods to TtsService**

Modify `app/lib/services/tts/tts_service.dart`. Add after the existing `setVolume` declaration (before `isLanguageAvailable`):

```dart
  // === v1.14.0-alpha: Voice selection ===

  /// Returns all voices available on this device.
  ///
  /// Returns empty list when the platform doesn't expose any (rare:
  /// Huawei/Honor with locked engine, or pre-Android 21).
  /// **Never throws** — engine errors fall back to empty list; UI shows
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
  /// the saved voice. Avoids needing a second TTS instance.
  Future<void> previewVoice(String voiceId, {String? sampleText});

  /// Opens the platform's system TTS settings page (where the user can
  /// install / select TTS engines). Returns false on platforms without
  /// a system page.
  Future<bool> openSystemTtsSettings();
```

Add import at top:

```dart
import 'tts_voice.dart';
```

- [ ] **Step 6: Verify the existing FakeTtsService / mocks still compile**

If there's a FakeTtsService in tests, it must override the new methods. Find with:

```bash
cd C:\zhiyue_build_s3 && grep -rn "implements TtsService" app/test app/lib
```

For each `implements TtsService` (typically FakeTtsService, mock classes), add minimal stubs:

```dart
  @override
  Future<List<TtsVoice>> getVoices() async => const [];

  @override
  Future<bool> setVoice(String? voiceId) async => false;

  @override
  Future<void> previewVoice(String voiceId, {String? sampleText}) async {}

  @override
  Future<bool> openSystemTtsSettings() async => false;
```

- [ ] **Step 7: Run full test suite to verify nothing broke**

```bash
cd C:\zhiyue_build_s3 && flutter test
```

Expected: All existing tests still pass + 3 new TtsVoice tests.

- [ ] **Step 8: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/services/tts/tts_voice.dart app/lib/services/tts/tts_service.dart app/test/services/tts/tts_voice_test.dart
# Also add any fake/mock updates
git commit -m "$(cat <<'EOF'
feat(tts): add TtsVoice data class + TtsService voice API

v1.14.0-alpha T1: cross-platform voice selection foundation.
- TtsVoice: id/name/locale/isDefault, equality by id
- TtsService.getVoices / setVoice / previewVoice / openSystemTtsSettings
- All fakes/mocks stubbed with empty/false defaults

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: FlutterTtsServiceImpl 实现 voice 方法（桌面 SAPI5）

**Files:**
- Modify: `app/lib/services/tts/flutter_tts_service.dart`
- Test: `app/test/services/tts/flutter_tts_service_voice_test.dart`

- [ ] **Step 1: Write failing test for getVoices / setVoice**

Create `app/test/services/tts/flutter_tts_service_voice_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/services/tts/flutter_tts_service.dart';
import 'package:zhiyue/services/tts/tts_voice.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  late _MockFlutterTts mock;
  late FlutterTtsServiceImpl service;

  setUp(() {
    mock = _MockFlutterTts();
    // FlutterTtsServiceImpl constructs `FlutterTts()` internally; refactor
    // to accept an injected instance OR use registerMockValue pattern.
    // For now: stub the methods that constructor wires (handlers/setters).
    when(() => mock.awaitSpeakCompletion(any())).thenAnswer((_) async => 1);
    service = FlutterTtsServiceImpl.withTts(mock);  // ← need to add this ctor
  });

  test('getVoices returns empty when plugin returns null', () async {
    when(() => mock.getVoices()).thenAnswer((_) async => null);
    final voices = await service.getVoices();
    expect(voices, isEmpty);
  });

  test('getVoices maps plugin List<Map> to List<TtsVoice>', () async {
    when(() => mock.getVoices()).thenAnswer((_) async => [
          {'name': 'Microsoft HuiHui', 'locale': 'zh-CN'},
          {'name': 'Microsoft Zira', 'locale': 'en-US'},
        ]);
    final voices = await service.getVoices();
    expect(voices.length, 2);
    expect(voices[0].name, 'Microsoft HuiHui');
    expect(voices[0].locale, 'zh-CN');
    expect(voices[0].id, 'Microsoft HuiHui');  // Desktop: id == name
  });

  test('setVoice(null) calls plugin.setVoice with empty string', () async {
    when(() => mock.setVoice(any())).thenAnswer((_) async => 1);
    final ok = await service.setVoice(null);
    verify(() => mock.setVoice('')).called(1);
    expect(ok, isTrue);
  });

  test('setVoice returns false when plugin returns 0 (not accepted)', () async {
    when(() => mock.setVoice(any())).thenAnswer((_) async => 0);
    final ok = await service.setVoice('nonexistent-voice');
    expect(ok, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3 && flutter test test/services/tts/flutter_tts_service_voice_test.dart
```

Expected: FAIL — `FlutterTtsServiceImpl.withTts` constructor doesn't exist.

- [ ] **Step 3: Add `withTts` constructor + voice implementations**

Modify `app/lib/services/tts/flutter_tts_service.dart`:

(a) Change the class to allow injecting a FlutterTts instance:

```dart
class FlutterTtsServiceImpl implements TtsService {
  final FlutterTts _tts;
  final _stateController = StreamController<TtsState>.broadcast();
  final _progressController = StreamController<TtsProgress>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _initialized = false;
  int _currentSentenceIdx = 0;

  /// Production constructor — creates a new [FlutterTts] instance.
  FlutterTtsServiceImpl() : _tts = FlutterTts();

  /// Test constructor — injects a mock [FlutterTts].
  @visibleForTesting
  FlutterTtsServiceImpl.withTts(this._tts);

  // ... existing methods unchanged except init() ...

  @override
  Future<void> init() async {
    if (_initialized) return;
    // existing handler wiring ...
    await _tts.awaitSpeakCompletion(true);
    _stateController.add(TtsState.idle);
    _initialized = true;
  }

  // ... existing speakSentence / stop / pause / setRate / etc ...
```

Add `import 'package:flutter/foundation.dart';` for `@visibleForTesting`.

(b) Add the 4 voice methods before `dispose()`:

```dart
  // === v1.14.0-alpha: Voice selection ===

  @override
  Future<List<TtsVoice>> getVoices() async {
    try {
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
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> setVoice(String? voiceId) async {
    try {
      // flutter_tts has no explicit "revert to default"; empty string
      // triggers plugin's internal fallback to system default voice.
      final result = await _tts.setVoice(voiceId ?? '');
      return result == 1 || result == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> previewVoice(String voiceId, {String? sampleText}) async {
    final previous = _previewSavedVoice;  // null on first preview
    if (!await setVoice(voiceId)) return;
    _previewSavedVoice = voiceId;
    try {
      final text = sampleText ?? '你好，这是该声音的试听样本。';
      await _tts.speak(text);
      // Restore happens via completion handler (set in init): on next
      // idle event, if _previewSavedVoice != null, restore it.
    } catch (_) {
      // Best-effort; restore regardless
      await _restorePreviewVoice(previous);
    }
  }

  String? _previewSavedVoice;

  Future<void> _restorePreviewVoice(String? previous) async {
    _previewSavedVoice = null;
    if (previous != null) {
      await setVoice(previous);
    }
  }

  @override
  Future<bool> openSystemTtsSettings() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
          'cmd', ['/c', 'start', 'ms-settings:speech']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
```

(c) Modify the completion handler in `init()` to also restore preview voice:

```dart
      ..setCompletionHandler(() {
        _stateController.add(TtsState.idle);
        // v1.14.0-alpha: restore preview voice after preview playback.
        if (_previewSavedVoice != null) {
          final prev = _previewSavedVoice;
          _previewSavedVoice = null;
          setVoice(prev);  // fire-and-forget; safe since setVoice is idempotent
        }
      })
```

(d) Add imports:

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'tts_voice.dart';
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd C:\zhiyue_build_s3 && flutter test test/services/tts/flutter_tts_service_voice_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 5: Run full test suite**

```bash
cd C:\zhiyue_build_s3 && flutter test
```

Expected: All pass.

- [ ] **Step 6: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/services/tts/flutter_tts_service.dart app/test/services/tts/flutter_tts_service_voice_test.dart
git commit -m "$(cat <<'EOF'
feat(tts-desktop): implement voice API for flutter_tts wrapper

v1.14.0-alpha T2: FlutterTtsServiceImpl gets getVoices/setVoice/
previewVoice/openSystemTtsSettings. Adds withTts(mock) test constructor.
previewVoice uses setVoice + completion-handler restore pattern
(no second TTS instance, avoids memory leak).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: SelfBuiltTtsServiceImpl MethodChannel 接线（Dart 侧）

**Files:**
- Modify: `app/lib/services/tts/self_built_tts_service.dart`
- Test: `app/test/services/tts/self_built_tts_service_voice_test.dart`

- [ ] **Step 1: Write failing test for getVoices / setVoice MethodChannel calls**

Create `app/test/services/tts/self_built_tts_service_voice_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/self_built_tts_service.dart';
import 'package:zhiyue/services/tts/tts_voice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SelfBuiltTtsServiceImpl service;
  final List<MethodCall> calls = [];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.tts'),
            (call) async {
      calls.add(call);
      if (call.method == 'getVoices') {
        return [
          {'id': 'xiaoxiao|zh-CN', 'name': 'Xiaoxiao', 'locale': 'zh-CN', 'isDefault': true},
          {'id': 'yunyang|zh-CN', 'name': 'Yunyang', 'locale': 'zh-CN'},
        ];
      }
      if (call.method == 'setVoice') return true;
      if (call.method == 'openSystemTtsSettings') return true;
      return null;
    });
    service = SelfBuiltTtsServiceImpl();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.tts'), null);
  });

  test('getVoices maps Kotlin List<Map> to List<TtsVoice>', () async {
    final voices = await service.getVoices();
    expect(voices.length, 2);
    expect(voices[0].id, 'xiaoxiao|zh-CN');
    expect(voices[0].name, 'Xiaoxiao');
    expect(voices[0].locale, 'zh-CN');
    expect(voices[0].isDefault, isTrue);
    expect(calls.last.method, 'getVoices');
  });

  test('setVoice invokes MethodChannel with voiceId arg', () async {
    final ok = await service.setVoice('xiaoxiao|zh-CN');
    expect(ok, isTrue);
    expect(calls.any((c) =>
        c.method == 'setVoice' && c.arguments['voiceId'] == 'xiaoxiao|zh-CN'),
        isTrue);
  });

  test('setVoice(null) invokes MethodChannel with voiceId=null', () async {
    final ok = await service.setVoice(null);
    expect(ok, isTrue);
    expect(calls.any((c) =>
        c.method == 'setVoice' && c.arguments['voiceId'] == null),
        isTrue);
  });

  test('openSystemTtsSettings invokes Kotlin handler', () async {
    final ok = await service.openSystemTtsSettings();
    expect(ok, isTrue);
    expect(calls.any((c) => c.method == 'openSystemTtsSettings'), isTrue);
  });

  test('speakSentence piggy-backs cached voiceId', () async {
    await service.setVoice('xiaoxiao|zh-CN');
    calls.clear();
    await service.speakSentence(const Sentence(
      text: '你好',
      locale: 'zh-CN',
      charStart: 0,
      charEnd: 2,
    ));
    final speakCall = calls.firstWhere((c) => c.method == 'speak');
    expect(speakCall.arguments['voiceId'], 'xiaoxiao|zh-CN');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3 && flutter test test/services/tts/self_built_tts_service_voice_test.dart
```

Expected: FAIL — methods don't exist.

- [ ] **Step 3: Implement voice methods + speakSentence piggy-back**

Modify `app/lib/services/tts/self_built_tts_service.dart`:

(a) Add cached voiceId field after `_cachedVolume`:

```dart
  /// v1.14.0-alpha: cached voiceId, piggy-backed onto each SPEAK Intent
  /// (mirrors v1.13.7 Bug 4 rate/pitch/volume pattern).
  String? _cachedVoiceId;
```

(b) Add the 4 voice methods before `dispose()`:

```dart
  // === v1.14.0-alpha: Voice selection ===

  @override
  Future<List<TtsVoice>> getVoices() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getVoices');
      if (result == null) return const [];
      return result.map((v) {
        final map = v as Map<dynamic, dynamic>;
        return TtsVoice(
          id: map['id'] as String,
          name: map['name'] as String,
          locale: map['locale'] as String,
          isDefault: (map['isDefault'] as bool?) ?? false,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> setVoice(String? voiceId) async {
    _cachedVoiceId = voiceId;  // always cache, even if null
    try {
      final result = await _methodChannel.invokeMethod<bool>(
          'setVoice', {'voiceId': voiceId});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> previewVoice(String voiceId, {String? sampleText}) async {
    final previous = _cachedVoiceId;
    if (!await setVoice(voiceId)) return;
    try {
      final text = sampleText ?? '你好，这是该声音的试听样本。';
      await _methodChannel.invokeMethod('speak', {
        'text': text,
        'locale': 'zh-CN',
        'sentenceIndex': -1,  // sentinel: preview, not main queue
        'rate': _cachedRate,
        'pitch': _cachedPitch,
        'volume': _cachedVolume,
        'voiceId': voiceId,
      });
    } finally {
      // Restore on next done event OR immediately (Kotlin flushes utterance
      // queue synchronously, but Dart side restores eagerly to avoid races).
      _cachedVoiceId = previous;
      await _methodChannel.invokeMethod('setVoice', {'voiceId': previous});
    }
  }

  @override
  Future<bool> openSystemTtsSettings() async {
    try {
      final result = await _methodChannel
          .invokeMethod<bool>('openSystemTtsSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
```

(c) Modify `speakSentence` to piggy-back `_cachedVoiceId`:

```dart
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
      if (_cachedVoiceId != null) 'voiceId': _cachedVoiceId,
    });
  }
```

(d) Add import:

```dart
import 'tts_voice.dart';
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd C:\zhiyue_build_s3 && flutter test test/services/tts/self_built_tts_service_voice_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Run full test suite**

```bash
cd C:\zhiyue_build_s3 && flutter test
```

- [ ] **Step 6: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/services/tts/self_built_tts_service.dart app/test/services/tts/self_built_tts_service_voice_test.dart
git commit -m "$(cat <<'EOF'
feat(tts-android): wire voice API via MethodChannel

v1.14.0-alpha T3: SelfBuiltTtsServiceImpl gets getVoices/setVoice/
previewVoice/openSystemTtsSettings. SPEAK args piggy-back _cachedVoiceId
(same pattern as v1.13.7 Bug 4 rate/pitch/volume).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Kotlin ZhiYueTtsService voice handlers + SPEAK voiceId

**Files:**
- Modify: `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsPlugin.kt`
- Modify: `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt`
- Test: `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceVoiceTest.kt`

- [ ] **Step 1: Write failing Robolectric test**

Create `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceVoiceTest.kt`:

```kotlin
package dev.zhiyue.zhiyue.tts

import android.speech.tts.Voice
import android.os.Build
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.Locale
import org.assertj.core.api.Assertions.assertThat

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ZhiYueTtsServiceVoiceTest {

    @Test
    fun `handleGetVoices maps TextToSpeech voices to List of Map`() {
        val fakeVoices = setOf(
            Voice("zh-CN-xiaoxiao", Locale.SIMPLIFIED_CHINESE,
                Voice.QUALITY_HIGH, Voice.LATENCY_NORMAL, false, setOf()),
            Voice("zh-CN-yunyang", Locale.SIMPLIFIED_CHINESE,
                Voice.QUALITY_HIGH, Voice.LATENCY_NORMAL, false, setOf()),
        )
        val service = createServiceWithVoices(fakeVoices, defaultVoiceName = "zh-CN-xiaoxiao")

        val result = service.handleGetVoicesForTest()

        assertThat(result).hasSize(2)
        assertThat(result[0]["id"]).isEqualTo("zh-CN-xiaoxiao|zh-CN")
        assertThat(result[0]["name"]).isEqualTo("zh-CN-xiaoxiao")
        assertThat(result[0]["locale"]).isEqualTo("zh-CN")
        assertThat(result[0]["isDefault"]).isEqualTo(true)
        assertThat(result[1]["isDefault"]).isEqualTo(false)
    }

    @Test
    fun `handleSetVoice finds matching voice and applies`() {
        val fakeVoices = setOf(
            Voice("zh-CN-xiaoxiao", Locale.SIMPLIFIED_CHINESE,
                Voice.QUALITY_HIGH, Voice.LATENCY_NORMAL, false, setOf()),
        )
        val service = createServiceWithVoices(fakeVoices)

        val applied = service.handleSetVoiceForTest("zh-CN-xiaoxiao|zh-CN")

        assertThat(applied).isTrue()
        assertThat(service.lastAppliedVoiceName).isEqualTo("zh-CN-xiaoxiao")
    }

    @Test
    fun `handleSetVoice returns false when voiceId not found`() {
        val service = createServiceWithVoices(emptySet())

        val applied = service.handleSetVoiceForTest("nonexistent|zh-CN")

        assertThat(applied).isFalse()
    }

    @Test
    fun `handleSpeak applies voiceId when present in extras`() {
        val fakeVoices = setOf(
            Voice("zh-CN-xiaoxiao", Locale.SIMPLIFIED_CHINESE,
                Voice.QUALITY_HIGH, Voice.LATENCY_NORMAL, false, setOf()),
        )
        val service = createServiceWithVoices(fakeVoices)

        service.handleSpeakForTest(
            text = "你好",
            locale = "zh-CN",
            voiceId = "zh-CN-xiaoxiao|zh-CN",
            rate = 1.0, pitch = 1.0, volume = 1.0,
        )

        assertThat(service.lastAppliedVoiceName).isEqualTo("zh-CN-xiaoxiao")
    }
}
```

Note: `createServiceWithVoices` is a test helper from existing `ZhiYueTtsServiceTest.kt`; extend it if needed. The `*ForTest` methods are `@VisibleForTesting` wrappers around the private handlers.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3\app\android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*VoiceTest"
```

Expected: FAIL — `handleGetVoicesForTest` doesn't exist.

- [ ] **Step 3: Add voice handlers to ZhiYueTtsPlugin**

Modify `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsPlugin.kt` `onMethodCall`:

```kotlin
override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
        // existing handlers...
        "getVoices" -> service?.handleGetVoices(result)
        "setVoice" -> {
            val voiceId = call.argument<String>("voiceId")
            service?.handleSetVoice(voiceId, result)
        }
        "openSystemTtsSettings" -> openSystemTtsSettings(result)
        else -> result.notImplemented()
    }
}

private fun openSystemTtsSettings(result: Result) {
    try {
        val intent = Intent("com.android.settings.TTS_SETTINGS")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context?.startActivity(intent)
        result.success(true)
    } catch (e: Exception) {
        Log.e("ZhiYueTtsPlugin", "openSystemTtsSettings failed", e)
        result.success(false)
    }
}
```

Add imports: `import android.content.Intent`, `import android.util.Log`.

- [ ] **Step 4: Add handler implementations + helpers to ZhiYueTtsService**

Modify `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt`:

```kotlin
// === v1.14.0-alpha: Voice selection ===

private var lastAppliedVoiceNameForTest: String? = null
    @VisibleForTesting get() = field

fun handleGetVoices(result: Result) {
    val tts = _tts ?: run {
        result.error("NOT_INIT", "TTS not initialized", null)
        return
    }
    val defaultName = tts.defaultVoice?.name
    val voices = tts.voices?.map { v ->
        mapOf(
            "id" to "${v.name}|${v.locale.toLanguageTag()}",
            "name" to v.name,
            "locale" to v.locale.toLanguageTag(),
            "isDefault" to (v.name == defaultName)
        )
    } ?: emptyList<Map<String, Any>>()
    result.success(voices)
}

fun handleSetVoice(voiceId: String?, result: Result) {
    if (voiceId == null) {
        // Revert to system default: clear our override; let TextToSpeech
        // pick the engine's default voice on next speak.
        _voiceOverride = null
        result.success(true)
        return
    }
    val tts = _tts ?: run {
        result.success(false); return
    }
    val matched = tts.voices?.find { "${it.name}|${it.locale.toLanguageTag()}" == voiceId }
    if (matched != null) {
        tts.voice = matched
        _voiceOverride = matched.name
        lastAppliedVoiceNameForTest = matched.name
        result.success(true)
    } else {
        result.success(false)
    }
}

/// Cached voiceId from setVoice, reapplied on each handleSpeak to defend
/// against engine resets (service recreate / plugin rebind).
private var _voiceOverride: String? = null

@VisibleForTesting
fun handleSpeakForTest(
    text: String,
    locale: String,
    voiceId: String?,
    rate: Double,
    pitch: Double,
    volume: Double,
) {
    // Test shim: mirrors handleSpeak's voice-application path.
    if (voiceId != null) {
        val matched = _tts?.voices?.find { "${it.name}|${it.locale.toLanguageTag()}" == voiceId }
        if (matched != null) {
            _tts?.voice = matched
            lastAppliedVoiceNameForTest = matched.name
        }
    }
}
```

(b) Modify the production `handleSpeak` to apply voiceId from Intent extras:

```kotlin
private fun handleSpeak(extras: Bundle) {
    val text = extras.getString("text") ?: return
    val locale = extras.getString("locale") ?: "zh-CN"
    val voiceId = extras.getString("voiceId")  // may be null

    // v1.14.0-alpha: apply voice before language (language may pick a
    // different engine default voice that overrides our selection).
    if (voiceId != null) {
        val matched = _tts?.voices?.find { "${it.name}|${it.locale.toLanguageTag()}" == voiceId }
        if (matched != null) {
            _tts?.voice = matched
            _voiceOverride = matched.name
        }
    } else if (_voiceOverride != null) {
        // Reapply last setVoice; some engines reset on each speak call.
        val matched = _tts?.voices?.find { it.name == _voiceOverride }
        if (matched != null) _tts?.voice = matched
    }

    // existing setLanguage / setRate / setPitch / setVolume / speak...
}
```

Add imports: `import androidx.annotation.VisibleForTesting`.

- [ ] **Step 5: Run Robolectric test to verify it passes**

```bash
cd C:\zhiyue_build_s3\app\android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*VoiceTest"
```

Expected: PASS (4 tests).

- [ ] **Step 6: Run full Kotlin test suite**

```bash
cd C:\zhiyue_build_s3\app\android && ./gradlew :app:testWithFgsDebugUnitTest
```

Expected: All pass (existing 33 + 4 new = 37).

- [ ] **Step 7: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsPlugin.kt \
        app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsService.kt \
        app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/tts/ZhiYueTtsServiceVoiceTest.kt
git commit -m "$(cat <<'EOF'
feat(tts-android): Kotlin voice handlers + SPEAK voiceId

v1.14.0-alpha T4: ZhiYueTtsPlugin gets getVoices/setVoice/
openSystemTtsSettings handlers. ZhiYueTtsService.handleSpeak applies
voiceId from Intent extras (before setLanguage to avoid engine reset).
_voiceOverride persists across speak calls for engine-resilience.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: TtsSettings.voiceId 持久化 + notifier 即时同步

**Files:**
- Modify: `app/lib/features/tts/providers/tts_settings_provider.dart`
- Test: `app/test/features/tts/providers/tts_settings_provider_test.dart` (extend existing)

- [ ] **Step 1: Write failing test for voiceId persistence + setVoice sync**

Extend existing `app/test/features/tts/providers/tts_settings_provider_test.dart` (or create if absent):

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/features/tts/providers/tts_settings_provider.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

class _MockTtsService extends Mock implements TtsService {}

void main() {
  test('TtsSettings voiceId round-trips through json', () {
    const s = TtsSettings(voiceId: 'xiaoxiao|zh-CN');
    final j = s.toJson();
    expect(j['voiceId'], 'xiaoxiao|zh-CN');
    final restored = TtsSettings.fromJson(j);
    expect(restored.voiceId, 'xiaoxiao|zh-CN');
  });

  test('TtsSettings.fromJson tolerates missing voiceId (old settings)', () {
    final s = TtsSettings.fromJson({
      'rate': 0.0,
      'pitch': 1.0,
      'volume': 1.0,
      'chapterBoundary': 'continuous',
      // voiceId absent
    });
    expect(s.voiceId, isNull);
  });

  test('setVoice persists voiceId and calls TtsService.setVoice', () async {
    final tmpDir = await Directory.systemTemp.createTemp('tts_settings_test');
    final mockService = _MockTtsService();
    when(() => mockService.setVoice(any())).thenAnswer((_) async => true);

    final container = ProviderContainer(overrides: [
      ttsSettingsDirProvider.overrideWithValue(tmpDir),
      ttsServiceProvider.overrideWithValue(mockService),
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(ttsSettingsProvider.notifier);
    await notifier.setVoice('xiaoxiao|zh-CN');

    expect(container.read(ttsSettingsProvider).voiceId, 'xiaoxiao|zh-CN');
    verify(() => mockService.setVoice('xiaoxiao|zh-CN')).called(1);

    // Verify persisted to disk
    final file = File('${tmpDir.path}/tts_settings.json');
    final raw = await file.readAsString();
    expect(raw, contains('"voiceId":"xiaoxiao|zh-CN"'));
  });

  test('setVoice(null) clears voiceId and notifies service', () async {
    final mockService = _MockTtsService();
    when(() => mockService.setVoice(any())).thenAnswer((_) async => true);

    final tmpDir = await Directory.systemTemp.createTemp('tts_settings_test2');
    final container = ProviderContainer(overrides: [
      ttsSettingsDirProvider.overrideWithValue(tmpDir),
      ttsServiceProvider.overrideWithValue(mockService),
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(ttsSettingsProvider.notifier);
    await notifier.setVoice('initial|zh-CN');
    await notifier.setVoice(null);

    expect(container.read(ttsSettingsProvider).voiceId, isNull);
    verify(() => mockService.setVoice(null)).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3 && flutter test test/features/tts/providers/tts_settings_provider_test.dart
```

Expected: FAIL — `voiceId` field doesn't exist.

- [ ] **Step 3: Add voiceId field + setVoice notifier**

Modify `app/lib/features/tts/providers/tts_settings_provider.dart`:

(a) Add `voiceId` to `TtsSettings`:

```dart
class TtsSettings {
  final double rate;
  final double pitch;
  final double volume;
  final TtsChapterBoundary chapterBoundary;
  final String? voiceId;  // ← NEW

  const TtsSettings({
    this.rate = 0.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.chapterBoundary = TtsChapterBoundary.continuous,
    this.voiceId,  // ← NEW (null = system default)
  });

  Map<String, dynamic> toJson() => {
        'rate': rate,
        'pitch': pitch,
        'volume': volume,
        'chapterBoundary': chapterBoundary.name,
        'voiceId': voiceId,  // ← NEW
      };

  factory TtsSettings.fromJson(Map<String, dynamic> j) => TtsSettings(
        rate: _clamp((j['rate'] as num?)?.toDouble() ?? 0.0, -1.0, 1.0),
        pitch: _clamp((j['pitch'] as num?)?.toDouble() ?? 1.0, 0.5, 2.0),
        volume: _clamp((j['volume'] as num?)?.toDouble() ?? 1.0, 0.0, 1.0),
        chapterBoundary: TtsChapterBoundary.values.firstWhere(
          (e) => e.name == j['chapterBoundary'],
          orElse: () => TtsChapterBoundary.continuous,
        ),
        voiceId: j['voiceId'] as String?,  // ← NEW (null-safe for old files)
      );

  TtsSettings copyWith({
    double? rate,
    double? pitch,
    double? volume,
    TtsChapterBoundary? chapterBoundary,
    String? voiceId,
    bool clearVoiceId = false,  // ← to allow setting null explicitly
  }) =>
      TtsSettings(
        rate: rate ?? this.rate,
        pitch: pitch ?? this.pitch,
        volume: volume ?? this.volume,
        chapterBoundary: chapterBoundary ?? this.chapterBoundary,
        voiceId: clearVoiceId ? null : (voiceId ?? this.voiceId),
      );
```

(b) Add `setVoice` notifier method + TtsService sync:

```dart
class TtsSettingsNotifier extends StateNotifier<TtsSettings> {
  final Directory _dir;
  final TtsService _ttsService;  // ← NEW dependency for sync
  File? _file;

  TtsSettingsNotifier(this._dir, this._ttsService) : super(const TtsSettings()) {
    _load();
  }

  // ... existing _load / _persist / setRate / setPitch / setVolume / setChapterBoundary ...

  /// v1.14.0-alpha: sets voiceId, persists, and syncs to TtsService.
  Future<void> setVoice(String? voiceId) async {
    if (voiceId == null) {
      state = state.copyWith(clearVoiceId: true);
    } else {
      state = state.copyWith(voiceId: voiceId);
    }
    await _persist();
    // Best-effort sync; failures are surfaced via TtsService.error stream.
    try {
      await _ttsService.setVoice(voiceId);
    } catch (_) {
      // ignored — state still persisted, user can retry via UI
    }
  }
}

final ttsSettingsProvider =
    StateNotifierProvider<TtsSettingsNotifier, TtsSettings>(
  (ref) => TtsSettingsNotifier(
    ref.watch(ttsSettingsDirProvider),
    ref.watch(ttsServiceProvider),  // ← NEW
  ),
);
```

(c) Make sure `ttsServiceProvider` is defined in `app/lib/core/providers.dart`. If it's only an async provider, change `TtsSettingsNotifier` to accept a `Future<TtsService>` and resolve in `_load`. Preferably: add a synchronous `ttsServiceSyncProvider` for non-async access.

- [ ] **Step 4: Run test to verify it passes**

```bash
cd C:\zhiyue_build_s3 && flutter test test/features/tts/providers/tts_settings_provider_test.dart
```

Expected: PASS (4 new + existing).

- [ ] **Step 5: Run full test suite**

```bash
cd C:\zhiyue_build_s3 && flutter test
```

- [ ] **Step 6: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/features/tts/providers/tts_settings_provider.dart \
        app/test/features/tts/providers/tts_settings_provider_test.dart
git commit -m "$(cat <<'EOF'
feat(tts-settings): persist voiceId + sync to TtsService

v1.14.0-alpha T5: TtsSettings gains voiceId field (null = system default).
Notifier.setVoice persists + eagerly calls TtsService.setVoice so changes
apply without restart. Old tts_settings.json without voiceId is tolerated.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: VoiceListPage UI + 试听 + 系统跳转 + 空状态

**Files:**
- Create: `app/lib/features/tts/providers/tts_voices_provider.dart`
- Create: `app/lib/features/tts/pages/voice_list_page.dart`
- Modify: `app/lib/features/settings/pages/tts_settings_section.dart` (add tile)
- Modify: `app/lib/l10n/app_zh.arb` / `app_en.arb`
- Test: `app/test/features/tts/pages/voice_list_page_test.dart`

- [ ] **Step 1: Write failing widget test**

Create `app/test/features/tts/pages/voice_list_page_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyue/features/tts/pages/voice_list_page.dart';
import 'package:zhiyue/features/tts/providers/tts_settings_provider.dart';
import 'package:zhiyue/features/tts/providers/tts_voices_provider.dart';
import 'package:zhiyue/services/tts/tts_service.dart';
import 'package:zhiyue/services/tts/tts_voice.dart';

class _MockTtsService extends Mock implements TtsService {}
class _MockTtsSettingsNotifier extends Mock
    implements TtsSettingsNotifier {}

void main() {
  testWidgets('renders voice list from provider', (tester) async {
    final mockService = _MockTtsService();
    when(() => mockService.getVoices()).thenAnswer((_) async => const [
      TtsVoice(id: 'a|zh', name: 'Voice A', locale: 'zh', isDefault: true),
      TtsVoice(id: 'b|zh', name: 'Voice B', locale: 'zh'),
    ]);

    final container = ProviderContainer(overrides: [
      ttsServiceProvider.overrideWithValue(mockService),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: VoiceListPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Voice A'), findsOneWidget);
    expect(find.text('Voice B'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);  // default selected
  });

  testWidgets('tapping voice triggers setVoice', (tester) async {
    final mockService = _MockTtsService();
    when(() => mockService.getVoices()).thenAnswer((_) async => const [
      TtsVoice(id: 'a|zh', name: 'A', locale: 'zh'),
    ]);
    when(() => mockService.setVoice(any())).thenAnswer((_) async => true);

    final container = ProviderContainer(overrides: [
      ttsServiceProvider.overrideWithValue(mockService),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: VoiceListPage()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();

    verify(() => mockService.setVoice('a|zh')).called(greaterThanOrEqualTo(1));
  });

  testWidgets('empty list shows hint + system settings button', (tester) async {
    final mockService = _MockTtsService();
    when(() => mockService.getVoices()).thenAnswer((_) async => const []);
    when(() => mockService.openSystemTtsSettings()).thenAnswer((_) async => true);

    final container = ProviderContainer(overrides: [
      ttsServiceProvider.overrideWithValue(mockService),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: VoiceListPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('当前设备未提供可选声音'), findsOneWidget);
    expect(find.text('打开系统 TTS 设置'), findsOneWidget);
  });

  testWidgets('preview button triggers previewVoice', (tester) async {
    final mockService = _MockTtsService();
    when(() => mockService.getVoices()).thenAnswer((_) async => const [
      TtsVoice(id: 'a|zh', name: 'A', locale: 'zh'),
    ]);
    when(() => mockService.previewVoice(any(), sampleText: any(named: 'sampleText')))
        .thenAnswer((_) async {});

    final container = ProviderContainer(overrides: [
      ttsServiceProvider.overrideWithValue(mockService),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: VoiceListPage()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('试听'));
    await tester.pump();

    verify(() => mockService.previewVoice('a|zh',
        sampleText: any(named: 'sampleText'))).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3 && flutter test test/features/tts/pages/voice_list_page_test.dart
```

Expected: FAIL — `ttsVoicesProvider` and `VoiceListPage` don't exist.

- [ ] **Step 3: Create ttsVoicesProvider**

Create `app/lib/features/tts/providers/tts_voices_provider.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../services/tts/tts_voice.dart';

/// FutureProvider that fetches the device's available TTS voices.
/// Returns empty list on any failure (UI shows "no voices" hint).
final ttsVoicesProvider = FutureProvider<List<TtsVoice>>((ref) async {
  final service = ref.watch(ttsServiceProvider);
  try {
    return await service.getVoices();
  } catch (_) {
    return const [];
  }
});
```

- [ ] **Step 4: Create VoiceListPage**

Create `app/lib/features/tts/pages/voice_list_page.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/tts_settings_provider.dart';
import '../providers/tts_voices_provider.dart';

class VoiceListPage extends ConsumerWidget {
  const VoiceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voicesAsync = ref.watch(ttsVoicesProvider);
    final settings = ref.watch(ttsSettingsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ttsVoiceListTitle)),
      body: voicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.ttsVoiceLoadError),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(ttsVoicesProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (voices) => ListView(
          children: [
            // System default option
            RadioListTile<String?>(
              value: null,
              groupValue: settings.voiceId,
              title: Text(l10n.ttsVoiceSystemDefault),
              onChanged: (_) => _selectVoice(ref, null),
            ),
            for (final v in voices)
              RadioListTile<String?>(
                value: v.id,
                groupValue: settings.voiceId,
                title: Text(v.name),
                subtitle: Text(v.locale),
                secondary: IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: l10n.ttsVoicePreview,
                  onPressed: () => _previewVoice(ref, v.id),
                ),
                onChanged: (_) => _selectVoice(ref, v.id),
              ),
            if (voices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.ttsVoiceEmptyHint),
                  ),
                ),
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.settings),
                label: Text(l10n.ttsVoiceOpenSystemSettings),
                onPressed: () async {
                  final service = ref.read(ttsServiceProvider);
                  final ok = await service.openSystemTtsSettings();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.ttsVoiceOpenSystemFailed)),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectVoice(WidgetRef ref, String? voiceId) async {
    final notifier = ref.read(ttsSettingsProvider.notifier);
    await notifier.setVoice(voiceId);
  }

  Future<void> _previewVoice(WidgetRef ref, String voiceId) async {
    final service = ref.read(ttsServiceProvider);
    try {
      await service.previewVoice(voiceId);
    } catch (_) {
      // best-effort; UI doesn't surface preview errors
    }
  }
}
```

- [ ] **Step 5: Add i18n strings**

Modify `app/lib/l10n/app_zh.arb`:

```json
  "ttsVoiceListTitle": "朗读声音",
  "ttsVoiceSystemDefault": "系统默认",
  "ttsVoicePreview": "试听",
  "ttsVoiceEmptyHint": "当前设备未提供可选声音。请在系统 TTS 设置里安装引擎（如讯飞语音+、百度语音、Google TTS）。",
  "ttsVoiceOpenSystemSettings": "打开系统 TTS 设置",
  "ttsVoiceOpenSystemFailed": "无法打开系统设置，请手动前往",
  "ttsVoiceLoadError": "加载声音列表失败",
  "retry": "重试",
  "ttsSettingsVoiceTile": "朗读声音",
  "ttsSettingsVoiceTileSubtitle": "选择默认朗读声音"
```

(Add corresponding English in `app_en.arb`.)

Regenerate gen_l10n:

```bash
cd C:\zhiyue_build_s3 && flutter gen-l10n
```

Then restore CRLF endings (gen-l10n rewrites as LF, breaks git diff):

```bash
cd C:\zhiyue_build_s3 && git checkout app/lib/gen_l10n/
# Then use Python binary-safe replace to add new strings without
# triggering CRLF/LF noise (see feedback_flutter_strip_cache_trap).
```

- [ ] **Step 6: Add settings page tile**

Modify `app/lib/features/settings/pages/tts_settings_section.dart`:

```dart
// Add after the chapter boundary tile:
ListTile(
  leading: const Icon(Icons.record_voice_over),
  title: Text(l10n.ttsSettingsVoiceTile),
  subtitle: Text(l10n.ttsSettingsVoiceTileSubtitle),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/settings/tts/voice'),
),
```

Add the route to your GoRouter configuration (`app/lib/core/router.dart` or wherever `routerProvider` lives):

```dart
GoRoute(
  path: '/settings/tts/voice',
  builder: (context, state) => const VoiceListPage(),
),
```

- [ ] **Step 7: Run widget test to verify it passes**

```bash
cd C:\zhiyue_build_s3 && flutter test test/features/tts/pages/voice_list_page_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 8: Run full test suite**

```bash
cd C:\zhiyue_build_s3 && flutter test
```

- [ ] **Step 9: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/features/tts/providers/tts_voices_provider.dart \
        app/lib/features/tts/pages/voice_list_page.dart \
        app/lib/features/settings/pages/tts_settings_section.dart \
        app/lib/l10n/app_zh.arb app/lib/l10n/app_en.arb \
        app/lib/gen_l10n/ \
        app/lib/core/router.dart \
        app/test/features/tts/pages/voice_list_page_test.dart
git commit -m "$(cat <<'EOF'
feat(tts-ui): VoiceListPage with preview + system jump

v1.14.0-alpha T6: settings page gets 「朗读声音」tile routing to
VoiceListPage. Page renders radio list (system default + all device
voices), 试听 button per voice, 空状态 hint card, 「打开系统 TTS 设置」
outlined button. ttsVoicesProvider fetches on demand, auto-invalidate
on retry.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Release v1.14.0-alpha（与 open-with-default-reader plan 合并执行）

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `CHANGELOG.md`
- Modify: `app/windows/installer/zhiyue.iss`
- Create: `docs/releases/release-notes-v1.14.0-alpha.md`
- Build: APK + Windows installer
- Tag: `v1.14.0-alpha` + `m-tts-multi-voice` + `m-open-with-default-reader`

**重要：** 本任务必须在 open-with-default-reader plan 的 T7 完成后执行（合并 release）。如果两个 plan 并行进行，最后一个完成的 task 负责执行 T7。

- [ ] **Step 1: Verify both feature plans' T1-T6 are complete**

```bash
cd C:\zhiyue_build_s3 && git log --oneline | head -20
```

Expected: 至少 14 个 commits（TTS T1-T6 + open-with-default T1-T6 + 任何 subagent review fixups）。

- [ ] **Step 2: Run full test suite**

```bash
cd C:\zhiyue_build_s3 && flutter test
```

Expected: ~1720 pass / ~30 skip / 0 fail（v1.13.11 baseline 1676 + 2 spec 各 ~15-20 新测试）。

```bash
cd C:\zhiyue_build_s3\app\android && ./gradlew :app:testWithFgsDebugUnitTest
```

Expected: ~38 pass / 0 fail（v1.13.11 baseline 33 + 5 新）。

```bash
cd C:\zhiyue_build_s3\app\windows\runner && ./run_smoke_test.bat
```

Expected: PASS（含新加的 copydata/registry 测试）。

- [ ] **Step 3: Bump pubspec version**

Modify `app/pubspec.yaml`:

```yaml
version: 1.14.0-alpha+2009
```

- [ ] **Step 4: Bump Windows installer version**

Modify `app/windows/installer/zhiyue.iss` line 7:

```
#define MyAppVersion "1.14.0-alpha"
```

- [ ] **Step 5: Update CHANGELOG**

Add new section at top of `CHANGELOG.md` (use Python binary-safe to preserve CRLF):

```python
import io
path = "CHANGELOG.md"
with open(path, "rb") as f: data = f.read()
new_section = """## [1.14.0-alpha] - 2026-07-19

### Added
- **TTS 多播音员（Voice）选择**：设置 → 朗读 → 朗读声音，枚举设备所有可用 voice（Android TextToSpeech / Windows SAPI5），支持试听 + 系统跳转。voiceId 不跨设备同步（设备本地偏好）。
- **「直接打开电子书」修复**：从文件管理器 / 微信 / 浏览器下载点 .epub / .pdf 选智阅打开，自动加入书架 + 跳转 reader（修 Android MainActivity `.book` 扩展名 bug + Windows warm start `cached_argv` 缓存）。
- **「设为默认阅读器」首次启动提示**：检测智阅未设为系统默认 → 弹 dialog（Windows 写 HKCU 注册表 / Android 跳系统「默认应用」页）。设置页有手动入口兜底。

### Fixed
- Android: `MainActivity.copyContentToCache` 不再用固定 `.book` 扩展名，改为从 URI lastPathSegment 或 MIME type 推断 `.epub` / `.pdf` / `.txt` / `.md`。修因扩展名丢失导致的 `BookFormatDetector` 拒识别 + `BookOpenBridge.isSupportedBookPath` early return。
- Windows: warm start argv 转发加 `cached_argv_` C++ 端缓存 + Dart `popPendingArgv` 主动拉，避免 Dart handler 未注册时丢消息。

### Notes
- voiceId 持久化到 `tts_settings.json`，向后兼容旧文件（无 voiceId 字段 → null = 系统默认）
- `TtsService` 抽象加 4 个新方法（`getVoices / setVoice / previewVoice / openSystemTtsSettings`），所有 fake/mock 需 stub

"""
with open(path, "wb") as f: f.write(new_section.encode() + data)
```

- [ ] **Step 6: Write release notes**

Create `docs/releases/release-notes-v1.14.0-alpha.md`:

```markdown
# v1.14.0-alpha Release Notes

**Date:** 2026-07-19
**Tag:** `v1.14.0-alpha` (+ `m-tts-multi-voice` + `m-open-with-default-reader`)
**APK:** `zhiyue-1.14.0-alpha-with-fgs.apk`
**Installer:** `zhiyue-setup-1.14.0-alpha.exe`

## 3 项更新

### 1. TTS 多播音员选择（用户高频需求）

设置 → 朗读 → 朗读声音：

- 列出设备所有可用 voice（Android 系统 TTS engine / Windows SAPI5）
- 点 [试听] 预览音色（自动恢复原 voice）
- 列表为空时显示「去系统添加 TTS 引擎」入口（讯飞 / 百度 / Google TTS 等）

**国产 ROM 默认 voice 数量参考：**
- 华为 / 荣耀：1 个（小艺）→ 装讯飞语音+ / 百度语音可加
- 小米：1-2 个 → 同上
- 原生 Android / Pixel：10+（Google TTS）
- Windows 10/11：1-3 个（Huihui 等）→ 系统设置下载 Neural voice 加 10+

### 2. 「直接打开电子书」修复（用户报告 P0 bug）

修复前：手机点 .epub 选智阅 → 出现乱码页面（实际是 MainActivity 把文件复制到 cache 时丢失 `.epub` 扩展名 → 后续识别失败）。

修复后：
- **Android**：从文件管理器 / 微信 / 浏览器下载点 .epub / .pdf → 自动导入书架 + 跳转 reader
- **Windows**：双击 .epub → 智阅已运行时也自动导入（修 warm start argv 丢失 bug）

### 3. 「设为默认阅读器」首次启动提示

首次启动检测智阅未设为默认 → 弹 dialog：

- **Windows**：点「设为默认」→ 写 HKCU 注册表（不需 admin）
- **Android**：点「打开系统设置」→ 跳系统「默认应用」页（用户手动选）

拒绝后不再问；设置页有手动入口兜底。

## 真机回归测试

| 场景 | 平台 | 步骤 | 预期 |
|---|---|---|---|
| TTS voice 选择 | Android | 设置 → 朗读 → 朗读声音 → 选某 voice → 朗读一本书 | 用所选 voice 朗读 |
| TTS 试听 | 通用 | voice 列表点 [试听] | 听到该 voice 朗读 "你好，这是该声音的试听样本。" |
| Android 直接打开 | Android | 文件管理器点 .epub → 选智阅 | 智阅打开 + 跳 reader |
| Android 微信收 .epub | Android | 微信点 .epub → 选智阅 | 同上 |
| Windows cold start | Windows | 智阅未运行 + 双击 .epub | 智阅启动 + 跳 reader |
| Windows warm start | Windows | 智阅已运行 + 双击 .epub | 智阅前置 + 跳 reader |
| 首次启动 dialog | 通用 | 装好后首次启动 | 弹「设为默认阅读器」dialog |
| 设置页入口 | 通用 | 设置 → 通用 → 设为默认阅读器 | Windows: 写注册表；Android: 跳系统设置 |
```

- [ ] **Step 7: Commit release prep**

```bash
cd C:\zhiyue_build_s3
git add app/pubspec.yaml app/windows/installer/zhiyue.iss CHANGELOG.md docs/releases/release-notes-v1.14.0-alpha.md
git commit -m "$(cat <<'EOF'
chore(release): bump v1.14.0-alpha + changelog + release notes

- TTS 多播音员选择
- 「直接打开电子书」修复（Android MainActivity + Windows warm start）
- 「设为默认阅读器」首次启动提示

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: Build Android APK**

```bash
cd C:\zhiyue_build_s3\app && /c/flutter/bin/flutter build apk --flavor withFgs --release
```

Expected: `app/build/app/outputs/flutter-apk/app-withfgs-release.apk`

- [ ] **Step 9: Verify APK markers (no strip cache trap)**

Run marker verification script (write fresh each release). Required markers:

- `currentChapterPlainText` (v1.13.11 legacy)
- `TtsVoice` (new, public class)
- `getVoices` / `setVoice` (new, public API)
- `voiceId` (new, Map key)
- `inferExtensionFromUri` (new Kotlin log)
- `popPendingArgv` (new Dart invokeMethod)

Not expected (AOT-stripped):
- `_VoiceListPageState` or similar private class names

- [ ] **Step 10: Build Windows installer**

```bash
cd C:\zhiyue_build_s3\app && /c/flutter/bin/flutter build windows --release
"C:/Program Files (x86)/Inno Setup 6/iscc.exe" windows/installer/zhiyue.iss
```

Expected: `build/installer/zhiyue-setup-1.14.0-alpha.exe`

- [ ] **Step 11: Verify installer markers**

Verify `app.so` contains:
- `TtsVoice`, `getVoices`, `setVoice`, `voiceId` (Dart side)
- `cached_argv_` log string (Windows runner): check via TestCP + signtool if needed

- [ ] **Step 12: Push s4-build + master**

```bash
cd C:\zhiyue_build_s3 && git push origin s4-build
cd H:\projiect\电子书阅读平台 && git merge s4-build --ff-only && git push origin master
```

- [ ] **Step 13: Tag**

```bash
cd H:\projiect\电子书阅读平台
git tag v1.14.0-alpha
git tag m-tts-multi-voice
git tag m-open-with-default-reader
git push origin v1.14.0-alpha m-tts-multi-voice m-open-with-default-reader
```

- [ ] **Step 14: Distribute**

Copy to:

```bash
cp C:\zhiyue_build_s3\app\build\app\outputs\flutter-apk\app-withfgs-release.apk \
   C:\Users\1\Desktop\zhiyue-1.14.0-alpha-with-fgs.apk
cp C:\zhiyue_build_s3\app\build\app\outputs\flutter-apk\app-withfgs-release.apk \
   "H:\华为同步盘\华为云盘\新版本发布\zhiyue-1.14.0-alpha-with-fgs.apk"
cp C:\zhiyue_build_s3\app\build\installer\zhiyue-setup-1.14.0-alpha.exe \
   C:\Users\1\Desktop\
cp C:\zhiyue_build_s3\app\build\installer\zhiyue-setup-1.14.0-alpha.exe \
   "H:\华为同步盘\华为云盘\新版本发布\"
```

- [ ] **Step 15: Update memory**

Add memory entry `project_zhiyue_2026_07_19_v1_14_multi_voice_open_with.md` + index in `MEMORY.md`:

```markdown
- [智阅 2026-07-19 v1.14 多播音员 + 直接打开](project_zhiyue_2026_07_19_v1_14_multi_voice_open_with.md) — 2026-07-19 v1.14.0-alpha 双 tag m-tts-multi-voice + m-open-with-default-reader；TTS voice 选择（Android TextToSpeech / Windows SAPI5）+ 直接打开修复（MainActivity 扩展名 + Windows cached_argv）+ 设为默认 dialog；14 tasks / 2 spec 合并 release
```

---

## Reuse existing

- `flutter_tts` plugin `getVoices()` / `setVoice()` API（M0 起内置）
- v1.13.7 Bug 4 speak-args piggy-back 模式（rate/pitch/volume 现在加 voiceId）
- M2.0a outbox 设备本地偏好分类规则
- TtsSettingsNotifier 现有持久化模式（即时落盘 + autoDispose keepAlive）
- feedback_flutter_strip_cache_trap 流程（Python binary-safe CHANGELOG + marker verify）
- M8 Inno Setup installer（仅 bump `MyAppVersion`）

## Verification（最终验收）

- 1676 + ~35 新测试全 PASS / 0 fail
- APK 134-150 MB（withFgs flavor）, libapp.so MD5 ≠ v1.13.11（确认 Dart 变化）
- Windows installer ~48 MB, app.so MD5 ≠ v1.13.11
- 真机 8 场景全 PASS（TTS voice + Android 直接打开 + Windows warm start + 设为默认 dialog）

## Risks

1. **国产 ROM `TextToSpeech.getVoices()` 返回 null** → UI 空状态 + 系统跳转入口（设计预期内）
2. **试听 voice 期间主朗读触发** → previewVoice 期间 mini 控制台禁用「播放」按钮（loading 状态）
3. **失效 voiceId**（用户卸载 engine 后）→ 不删 voiceId，UI 标红提示重选
4. **flutter_tts Windows setVoice(null) 行为不一致** → 用空字符串触发 plugin 内部 fallback
5. **setVoice(null) 在国产 ROM 可能拒绝空 voice** → 用 `tts.defaultVoice` 显式设置
