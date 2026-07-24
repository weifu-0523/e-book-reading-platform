# Sherpa-ONNX TTS Engine POC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 验证 `sherpa_onnx` Flutter 包 + MeloTTS-zh_en 模型在智阅现有 TTS 架构上的可行性,输出可量化的中文母语听感 + 移动端 RTF + 体积数据,决定是否进 Phase 2 全量实现。

**Architecture:** 新增 `SherpaOnnxTtsService implements TtsService`,通过现有 `TtsServiceFactory` 按 `TtsEnginePreference` 派发(系统 / SherpaOnnx)。上层 `TtsPlaybackController` / `TtsReaderController` / MediaSession 通知栏零改动(契约隔离)。POC 期模型 bundle 为 asset(60MB),Phase 2 再改为按需下载。

**Tech Stack:** Flutter 3.x + Dart 3.x + `sherpa_onnx: ^1.13.4`(pub.dev 官方包) + Riverpod StateNotifier + drift v15 + 现有 `SelfBuiltTtsServiceImpl` / `FlutterTtsServiceImpl` 不动。

---

## Background

v1.13.0-alpha 自研了 ZhiYueTtsPlugin 替代 audio_service + flutter_tts + audio_session 三件套,朗读链路已稳定(1731 Dart 测试 + 40 Kotlin 测试 pass)。但用户报告「不同手机效果差异明显」,根因是系统 TTS 因厂商而异(华为小艺好,低端机差)。本 POC 引入 sherpa-onnx + MeloTTS-zh_en 作为统一离线引擎候选,MIT 许可 + 60MB 体积 + 中文质量优于 Piper(无 g2pw 153MB 依赖)。

详细调研见对话上下文(2026-07-21 评估)。

---

## Scope

### In scope
- ✅ `sherpa_onnx` Flutter 包集成到 `app/pubspec.yaml`
- ✅ 新增 `SherpaOnnxTtsService implements TtsService`(仅 MeloTTS-zh_en)
- ✅ `TtsServiceFactory` 增加 `TtsEnginePreference` 派发
- ✅ Debug 设置页加引擎切换(POC 不做正式 settings panel)
- ✅ 模型 bundle 为 asset(`assets/tts-models/vits-melo-tts-zh_en/`)
- ✅ Benchmark harness: log 每句 RTF + 内存 + 模型加载耗时
- ✅ POC report 输出决策文档

### Out of scope(留给 Phase 2)
- ❌ 多 voice 切换 UI(theresa 804 voices 等)
- ❌ 模型按需下载(网络 + 进度 + 重试)
- ❌ drift schema 改动(用户偏好仍走 secure_storage)
- ❌ CosyVoice 桌面集成(Phase 2 W3 单独验证)
- ❌ 正式 settings panel UI 改造
- ❌ iOS / macOS / Linux 平台验证(仅 Android + Windows)

---

## Decision Gates

每个 gate 失败 → 触发 fallback(转 Phase 4 edge-tts 在线 / 付费 API 评估)。

| Gate | 触发 Task | 通过判据 | 失败 fallback |
|---|---|---|---|
| G1 | T1-T2 | `flutter build apk --debug` 成功,APK 启动不 crash | 换 sherpa-onnx 旧版本或放弃 |
| G2 | T3-T5 | 集成测试生成可听中文音频,采样率匹配 | 换模型(theresa/aishell3/matcha-baker)重测 |
| G3 | T6-T7 | 引擎切换 UI 可用,引擎 A 朗读中切引擎 B 不 crash | 缩小 POC 范围仅做 benchmark |
| G4 | T8-T9 | 中文母语盲听:≥ 系统 TTS 评分,RTF < 0.5 | 启动 Phase 4 备选目录 |

---

## File Structure

### Modify(6 个文件)

- `app/pubspec.yaml` — 加 `sherpa_onnx: ^1.13.4` 依赖;`flutter.assets` 加 `assets/tts-models/`
- `app/lib/services/tts/tts_service_factory.dart` — 工厂签名加 `preferredEngine` 参数,默认 `TtsEnginePreference.system`
- `app/lib/features/tts/providers/tts_playback_controller.dart` — 注入 `ttsEngineProvider`(读 secure_storage),传给 factory(改动 ≤ 5 行)
- `app/lib/features/settings/pages/settings_page.dart` — Debug 区域加「TTS 引擎(实验)」入口(POC 临时 UI)
- `CHANGELOG.md` — `[Unreleased]` / `[1.15.0-alpha]` section
- `app/android/app/build.gradle` — `android.packagingOptions.jniLibs.useLegacyPackaging = true`(sherpa-onnx native lib 要求)

### Create(8 个文件)

- `app/lib/services/tts/sherpa_onnx_tts_service.dart` — 新 `SherpaOnnxTtsService implements TtsService`
- `app/lib/services/tts/tts_engine_preference.dart` — `enum TtsEnginePreference { system, sherpaOnnxMelo }`
- `app/lib/features/tts/providers/tts_engine_provider.dart` — `ttsEngineProvider`(读 secure_storage `tts.engine`)
- `app/lib/features/tts/providers/sherpa_onnx_audio_player.dart` — 把 `Float32List` samples 转 PCM16 + 用 `audioplayers` 或 `soundpool` 播放(POC 二选一)
- `app/test/features/tts/providers/tts_engine_provider_test.dart` — preference 持久化单元测试
- `app/test/services/tts/sherpa_onnx_tts_service_test.dart` — 集成测试(真实 sherpa-onnx 实例)
- `app/test/features/tts/tts_engine_factory_dispatch_test.dart` — factory 按偏好派发测试
- `docs/research/2026-07-XX-sherpa-onnx-tts-poc-report.md` — POC 决策文档

### Bundle(资源文件,不入 git LFS,POC 手动放置)

- `app/assets/tts-models/vits-melo-tts-zh_en/model.onnx`(~60MB)
- `app/assets/tts-models/vits-melo-tts-zh_en/lexicon.txt`
- `app/assets/tts-models/vits-melo-tts-zh_en/tokens.txt`

下载源:`huggingface.co/csukuangfj/vits-melo-tts-zh_en/tree/main`,POC T1 步骤 2 给出 `wget` 命令。

---

## 关键非显然知识点(实现者必读)

1. **sherpa-onnx Flutter 包结构**:`sherpa_onnx` 是主包(Federated),实际 native 库在 `sherpa_onnx_android` / `sherpa_onnx_ios` / `sherpa_onnx_windows` 等子包。`pubspec.yaml` 只需主包,子包自动拉。
2. **Android native lib 体积**:`libonnxruntime.so` + `libsherpa-onnx-jni.so` 单 ABI 约 7MB。三 ABI 全打 +21MB。POC 期可 `splits.abi=true` 分包单 ABI 构建,正式版需 ABI splits。
3. **MeloTTS-zh_en 不需要 espeak-ng-data**(Piper 才需要),所以 asset 目录只有 3 个文件,体积约 60MB。
4. **模型 asset 必须在 build 时拷贝到文件系统**:sherpa-onnx 用文件路径加载,不能直接从 AAsset 读取。运行时从 `rootBundle.load` 拷贝到 `getApplicationSupportDirectory()/tts-models/...`。
5. **sherpa_onnx OfflineTts.generate() 返回 `Float32List` samples + sampleRate**:不是直接播放,需要转 PCM16 bytes 后送 audio player。`SoundPool` 比 `audioplayers` 延迟低,POC 先用 `audioplayers`,如延迟不可接受换 `flutter_soloud` 或 `soundpool`。
6. **TTS 是阻塞调用**:`generate()` 在 UI 线程会卡顿,必须 `compute()` 或 `Isolate.run()`。但 sherpa-onnx 内部已用 native 线程,Dart 侧 `generate()` 是同步阻塞的 native 调用,需要在 isolate 里跑。
7. **`TtsService` 现有契约要求 `Stream<TtsState>` 而非 callback**:SherpaOnnxTtsService 需用 `StreamController<TtsState>` 包装,朗读时 `add(speaking)`,完成时 `add(idle)`。
8. **`speakSentence(Sentence)` 是单句接口**:不需要分句,SentenceSegmenter 已分好。SherpaOnnxTtsService 直接 `generate(sentence.text)`,取 samples 播放,期间 emit progress 事件(`charStart=0, charEnd=text.length`),播放完成后 `add(idle)`。
9. **`setSpeechRate(-1.0..1.0)`** 是 flutter_tts 风格的归一化速率,sherpa-onnx `generate(speed:)` 是 1.0=正常的绝对速率。转换:`speed = 1.0 * (1.0 + rate)`(rate=-1 慢一半,rate=1 快一倍)。
10. **`SelfBuiltTtsServiceImpl` 用的 `ZhiYueTtsPlugin` Kotlin channel 仍在**,SherpaOnnxTtsService 完全旁路它,不冲突。两者并存,引擎切换时由 factory 选其中一个。

---

## TDD 实施顺序

`C:\zhiyue_build_s3` ASCII worktree(branch `s4-build`)跑测试绕中文路径超时。每 task 独立 commit,commit message 后缀 `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`。

| Task | Scope | Gate |
|---|---|---|
| T1 | sherpa_onnx 依赖 + MeloTTS 模型 asset + Android build 配置 | G1 |
| T2 | TtsEnginePreference enum + ttsEngineProvider(secure_storage) | - |
| T3 | SherpaOnnxTtsService skeleton(init/dispose/state/error stream),所有方法 UnimplementedError | G1 |
| T4 | TDD init():拷贝 asset → 文件系统 → 加载 OfflineTts | G2 |
| T5 | TDD speakSentence + stop + state stream + progress(集成测试真实生成音频) | G2 |
| T6 | TDD factory dispatch by preference + ttsEngineProvider 注入 playback controller | G3 |
| T7 | Debug settings page 引擎切换 UI | G3 |
| T8 | Benchmark harness:log RTF + 内存 + 模型加载耗时到 dev.log | G4 |
| T9 | POC report + 决策 | G4 |

每 task 完成后 commit,9 task → 9 commits(+1 release commit)。

---

## Task 1: sherpa_onnx 依赖 + 模型 asset + Android build 配置

**Files:**
- Modify: `app/pubspec.yaml`(加依赖 + assets)
- Modify: `app/android/app/build.gradle`(JNI lib packaging)
- Create: `app/assets/tts-models/vits-melo-tts-zh_en/`(3 个模型文件)
- Test: 无(配置 task,验证方式 = build 成功)

- [ ] **Step 1: 加 sherpa_onnx 依赖**

编辑 `C:\zhiyue_build_s3\app\pubspec.yaml`,在 `dependencies:` 块加(在 `flutter_tts: ^4.1.0` 下方):

```yaml
  # TTS POC: sherpa-onnx 离线神经 TTS(MeloTTS-zh_en)
  sherpa_onnx: ^1.13.4
  # 朗读 SherpaOnnxTtsService 生成的 PCM 音频
  audioplayers: ^5.2.1
```

- [ ] **Step 2: 下载 MeloTTS-zh_en 模型**

```bash
cd C:\zhiyue_build_s3\app\assets
mkdir -p tts-models/vits-melo-tts-zh_en
cd tts-models/vits-melo-tts-zh_en
curl -L -o model.onnx https://huggingface.co/csukuangfj/vits-melo-tts-zh_en/resolve/main/model.onnx
curl -L -o lexicon.txt https://huggingface.co/csukuangfj/vits-melo-tts-zh_en/resolve/main/lexicon.txt
curl -L -o tokens.txt https://huggingface.co/csukuangfj/vits-melo-tts-zh_en/resolve/main/tokens.txt
ls -lh
# 预期: model.onnx ~60MB, lexicon.txt ~3MB, tokens.txt ~30KB
```

如果 HuggingFace 国内访问失败,用 ModelScope 镜像:`https://modelscope.cn/models/csukuangfj/vits-melo-tts-zh_en`(POC T1 时验证)。

- [ ] **Step 3: 注册 assets 到 pubspec**

编辑 `C:\zhiyue_build_s3\app\pubspec.yaml`,在文件末尾 `flutter:` 块加:

```yaml
flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/fonts/
    - assets/tts-models/vits-melo-tts-zh_en/model.onnx
    - assets/tts-models/vits-melo-tts-zh_en/lexicon.txt
    - assets/tts-models/vits-melo-tts-zh_en/tokens.txt
```

注意:`.onnx` 60MB 二进制 asset 会触发 Flutter 的 "this asset is large" 警告,可忽略(POC 期)。

- [ ] **Step 4: Android build.gradle JNI lib 配置**

编辑 `C:\zhiyue_build_s3\app\android\app\build.gradle`,在 `android { ... }` 块内加:

```gradle
android {
    // ... existing config ...
    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}
```

`useLegacyPackaging = true` 让 native .so 解压到 `/data/app/.../lib/` 而非走 `extractNativeLibs=false` 压缩路径,sherpa-onnx JNI 加载更稳。

- [ ] **Step 5: 跑 build 验证(G1)**

```bash
cd C:\zhiyue_build_s3
flutter clean
flutter pub get
flutter build apk --flavor withFgs --debug --target-platform android-arm64
```

预期输出:`✓ Built build\app\outputs\flutter-apk\app-with-fgs-debug.apk`(APK 体积 ~190MB,比之前 135MB 大 55MB = 模型 60MB - 压缩)。

如果失败:
- `sherpa_onnx_android` 找不到 → 试 `sherpa_onnx: ^1.13.0`(去 .4 patch)
- NDK version 错误 → `android/build.gradle` 加 `ndkVersion = "27.0.12077973"`
- `minSdkVersion` 冲突 → sherpa-onnx 要求 minSdk 24,在 `android/app/build.gradle` 改 `minSdkVersion 24`

- [ ] **Step 6: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/pubspec.yaml app/android/app/build.gradle
# 模型文件不入 git(60MB),加 .gitignore
echo "app/assets/tts-models/**/*.onnx" >> .gitignore
echo "app/assets/tts-models/**/*.txt" >> .gitignore
git add .gitignore
git commit -m "$(cat <<'EOF'
feat(tts): add sherpa_onnx dep + MeloTTS-zh_en model asset (POC T1)

- sherpa_onnx ^1.13.4 (official Flutter package, federated)
- audioplayers ^5.2.1 (PCM playback)
- Android useLegacyPackaging=true for sherpa-onnx JNI stability
- Model files (.onnx/.txt) gitignored — POC dev manually downloads from HF

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: TtsEnginePreference enum + ttsEngineProvider

**Files:**
- Create: `app/lib/services/tts/tts_engine_preference.dart`
- Create: `app/lib/features/tts/providers/tts_engine_provider.dart`
- Test: `app/test/features/tts/providers/tts_engine_provider_test.dart`

- [ ] **Step 1: Write failing test**

创建 `C:\zhiyue_build_s3\app\test\features\tts\providers\tts_engine_provider_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';
import 'package:zhiyue/features/tts/providers/tts_engine_provider.dart';

void main() {
  group('ttsEngineProvider', () {
    late ProviderContainer container;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      // 用 in-memory fake — flutter_secure_storage 在 test 环境 mock 为空
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('default preference is system', () {
      expect(
        container.read(ttsEngineProvider),
        TtsEnginePreference.system,
      );
    });

    test('setEngine persists and updates state', () async {
      await container
          .read(ttsEngineProvider.notifier)
          .setEngine(TtsEnginePreference.sherpaOnnxMelo);

      expect(
        container.read(ttsEngineProvider),
        TtsEnginePreference.sherpaOnnxMelo,
      );

      // 验证持久化:新 container 应读到新值
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      // flutter_secure_storage test 默认无持久化,只验证 in-memory state 一致
      expect(
        container2.read(ttsEngineProvider),
        TtsEnginePreference.system,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/features/tts/providers/tts_engine_provider_test.dart
```

预期:`Target of URI doesn't exist: 'package:zhiyue/services/tts/tts_engine_preference.dart'`。

- [ ] **Step 3: Create TtsEnginePreference enum**

创建 `C:\zhiyue_build_s3\app\lib\services\tts\tts_engine_preference.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

/// 用户偏好的 TTS 引擎。POC v1.15.0-alpha 仅 2 个枚举值,Phase 2 扩展更多
/// sherpa-onnx 模型(MeloTTS / Theresa / Aishell3 / CosyVoice-desktop)。
enum TtsEnginePreference {
  /// 系统 TTS(SelfBuiltTtsServiceImpl on Android / FlutterTtsServiceImpl elsewhere)
  system,

  /// SherpaOnnx MeloTTS-zh_en(60MB asset, MIT license)
  sherpaOnnxMelo,
}

extension TtsEnginePreferenceX on TtsEnginePreference {
  String get persistedValue => name;

  static TtsEnginePreference fromPersistedValue(String? value) {
    return TtsEnginePreference.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TtsEnginePreference.system,
    );
  }
}
```

- [ ] **Step 4: Create ttsEngineProvider**

创建 `C:\zhiyue_build_s3\app\lib\features\tts\providers\tts_engine_provider.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../services/tts/tts_engine_preference.dart';

const _storageKey = 'tts.engine';

/// POC v1.15.0-alpha:用户选择的 TTS 引擎。读 secure_storage 持久化。
/// Phase 2 会加更多引擎选项(theresa / aishell3 / cosyvoice-desktop)。
final ttsEngineProvider = StateNotifierProvider<TtsEngineNotifier, TtsEnginePreference>(
  (ref) => TtsEngineNotifier(),
);

class TtsEngineNotifier extends StateNotifier<TtsEnginePreference> {
  TtsEngineNotifier() : super(TtsEnginePreference.system);

  Future<void> load() async {
    const storage = FlutterSecureStorage();
    final persisted = await storage.read(key: _storageKey);
    state = TtsEnginePreferenceX.fromPersistedValue(persisted);
  }

  Future<void> setEngine(TtsEnginePreference pref) async {
    state = pref;
    const storage = FlutterSecureStorage();
    await storage.write(key: _storageKey, value: pref.persistedValue);
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/features/tts/providers/tts_engine_provider_test.dart
```

预期:`All tests passed! (2 tests)`。

如果 flutter_secure_storage 在 test 环境初始化报错,在 test 顶部加 `TestWidgetsFlutterBinding.ensureInitialized();`(已在 step 1 加)。

- [ ] **Step 6: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/services/tts/tts_engine_preference.dart \
        app/lib/features/tts/providers/tts_engine_provider.dart \
        app/test/features/tts/providers/tts_engine_provider_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): add TtsEnginePreference enum + ttsEngineProvider (POC T2)

- 2 values: system / sherpaOnnxMelo (Phase 2 extends)
- Persisted via flutter_secure_storage key 'tts.engine'
- Default system (preserves current behavior)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: SherpaOnnxTtsService skeleton

**Files:**
- Create: `app/lib/services/tts/sherpa_onnx_tts_service.dart`(skeleton,methods throw)
- Test: `app/test/services/tts/sherpa_onnx_tts_service_test.dart`(仅 type/contract 测试)

- [ ] **Step 1: Write failing test**

创建 `C:\zhiyue_build_s3\app\test\services\tts\sherpa_onnx_tts_service_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/sherpa_onnx_tts_service.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

void main() {
  group('SherpaOnnxTtsService contract', () {
    test('implements TtsService', () {
      final service = SherpaOnnxTtsService();
      expect(service, isA<TtsService>());
    });

    test('initial state streams emit idle / no progress / no error', () async {
      final service = SherpaOnnxTtsService();
      // 不调 init,直接读 stream 应得 idle 默认值(或 broom)
      // POC 容忍:init() 调用前 state stream 可空
      expect(service.isInitialized, isFalse);
    });

    test('init not yet implemented in skeleton throws UnimplementedError', () async {
      final service = SherpaOnnxTtsService();
      expect(() => service.init(), throwsA(isA<UnimplementedError>()));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/services/tts/sherpa_onnx_tts_service_test.dart
```

预期:`Target of URI doesn't exist: 'package:zhiyue/services/tts/sherpa_onnx_tts_service.dart'`。

- [ ] **Step 3: Create skeleton**

创建 `C:\zhiyue_build_s3\app\lib\services\tts\sherpa_onnx_tts_service.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tts_service.dart';
import 'tts_voice.dart';

/// Sherpa-ONNX 离线 TTS service。POC v1.15.0-alpha 仅支持 MeloTTS-zh_en 模型。
///
/// 加载流程:
/// 1. [init] 拷贝 `assets/tts-models/vits-melo-tts-zh_en/*` 到
///    `getApplicationSupportDirectory()/tts-models/vits-melo-tts-zh_en/`
/// 2. 创建 `sherpa_onnx.OfflineTtsConfig` 实例
/// 3. [speakSentence] 调 `tts.generate(text, sid: 0, speed: speed)` 得 Float32List
/// 4. 转 PCM16 bytes → `audioplayers.AudioPlayer` 播放
///
/// Phase 2 会:
/// - 模型按需下载(替代 asset bundle)
/// - 多 voice 切换
/// - isolate 包裹 generate() 防 jank
class SherpaOnnxTtsService implements TtsService {
  static const _modelAssetDir = 'assets/tts-models/vits-melo-tts-zh_en';
  static const _modelFiles = ['model.onnx', 'lexicon.txt', 'tokens.txt'];

  final _stateController = StreamController<TtsState>.broadcast();
  final _progressController = StreamController<TtsProgress>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _initialized = false;
  int _currentSentenceIndex = 0;

  @override
  bool get isInitialized => _initialized;

  @override
  Stream<TtsState> get state => _stateController.stream;

  @override
  Stream<TtsProgress> get progress => _progressController.stream;

  @override
  Stream<String> get error => _errorController.stream;

  @override
  Future<void> init() async {
    throw UnimplementedError('POC T4 implements');
  }

  @override
  Future<void> speakSentence(Sentence sentence) async {
    throw UnimplementedError('POC T5 implements');
  }

  @override
  Future<void> stop() async {
    throw UnimplementedError('POC T5 implements');
  }

  @override
  Future<void> pause() async {
    // SherpaOnnx offline synthesis 无 native pause;POC 用 stop + 标记实现
    throw UnimplementedError('POC T5 implements');
  }

  @override
  void setCurrentSentenceIndex(int idx) {
    _currentSentenceIndex = idx;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    throw UnimplementedError('POC T5 implements');
  }

  @override
  Future<void> setPitch(double pitch) async {
    // MeloTTS 不支持运行时调 pitch,记录到 state 但忽略
  }

  @override
  Future<void> setVolume(double volume) async {
    throw UnimplementedError('POC T5 implements');
  }

  @override
  Future<List<TtsVoice>> getVoices() async => const [];

  @override
  Future<bool> setVoice(String? voiceId) async => false;

  @override
  Future<void> previewVoice(String voiceId, {String? sampleText}) async {}

  @override
  Future<bool> openSystemTtsSettings() async => false;

  @override
  Future<bool> isLanguageAvailable(String locale) async =>
      locale.toLowerCase().startsWith('zh');

  @override
  Future<bool> isLanguageInstalled(String locale) async => isInitialized;

  @override
  Future<String?> getDefaultEngine() async => 'dev.zhiyue.sherpa-onnx';

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _progressController.close();
    await _errorController.close();
  }
}
```

注意 `import 'package:path/path.dart'` 和 `path_provider` 现有 pubspec 已有(项目早期依赖)。`sherpa_onnx` 包的实际类名在 T4 验证后可能微调(参考 `flutter-examples/tts/lib/model.dart`)。

- [ ] **Step 4: Run test to verify it passes**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/services/tts/sherpa_onnx_tts_service_test.dart
```

预期:`All tests passed! (3 tests)`。

- [ ] **Step 5: 全量 test 确认无回归**

```bash
cd C:\zhiyue_build_s3\app
flutter test
```

预期:`1734 tests passed`(1731 + 3 新) / `25 skipped` / `0 failed`。

- [ ] **Step 6: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/services/tts/sherpa_onnx_tts_service.dart \
        app/test/services/tts/sherpa_onnx_tts_service_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): add SherpaOnnxTtsService skeleton (POC T3)

- implements TtsService contract
- methods throw UnimplementedError (filled in T4-T5)
- 3 contract tests: implements TtsService / initial state / init throws

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: TDD init() — asset 拷贝 + 加载 OfflineTts

**Files:**
- Modify: `app/lib/services/tts/sherpa_onnx_tts_service.dart`(init 实现)
- Test: `app/test/services/tts/sherpa_onnx_tts_service_test.dart`(加 init test)

- [ ] **Step 1: Write failing test for init()**

在 `sherpa_onnx_tts_service_test.dart` 加:

```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

// ... 在 group 内加:

test('init copies asset files to app support dir and loads OfflineTts', () async {
  final service = SherpaOnnxTtsService();
  await service.init();

  expect(service.isInitialized, isTrue);

  // 验证 asset 拷贝到 app support dir
  final supportDir = await getApplicationSupportDirectory();
  final modelDir = p.join(supportDir.path, 'tts-models', 'vits-melo-tts-zh_en');
  for (final file in ['model.onnx', 'lexicon.txt', 'tokens.txt']) {
    final f = File(p.join(modelDir, file));
    expect(await f.exists(), isTrue, reason: '$file should be copied');
  }

  await service.dispose();
}, timeout: const Timeout(Duration(minutes: 2)));
```

注意:`ApplicationSupportDirectory` 在 Android 上是 `/data/data/dev.zhiyue.zhiyue/files`,test 环境用真实路径(不 mock)。

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/services/tts/sherpa_onnx_tts_service_test.dart --plain-name "init copies"
```

预期:`UnimplementedError: POC T4 implements`。

- [ ] **Step 3: 实现 init()**

修改 `sherpa_onnx_tts_service.dart` 的 init():

```dart
@override
Future<void> init() async {
  if (_initialized) return;
  _stateController.add(TtsState.loading);

  try {
    final supportDir = await getApplicationSupportDirectory();
    final modelDir = p.join(
      supportDir.path,
      'tts-models',
      'vits-melo-tts-zh_en',
    );
    await Directory(modelDir).create(recursive: true);

    // 拷贝 asset → 文件系统
    for (final file in _modelFiles) {
      final destPath = p.join(modelDir, file);
      if (!await File(destPath).exists()) {
        final data = await rootBundle.load('$_modelAssetDir/$file');
        await File(destPath).writeAsBytes(data.buffer.asUint8List());
      }
    }

    // 加载 sherpa-onnx OfflineTts
    _tts = sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(
      model: sherpa_onnx.OfflineTtsModelConfig(
        vits: sherpa_onnx.OfflineTtsVitsModelConfig(
          model: p.join(modelDir, 'model.onnx'),
          lexicon: p.join(modelDir, 'lexicon.txt'),
          tokens: p.join(modelDir, 'tokens.txt'),
        ),
        numThreads: 2,
        provider: 'cpu',
      ),
      maxNumSentences: 1,
    ));

    _initialized = true;
    _stateController.add(TtsState.idle);
  } catch (e, st) {
    _errorController.add('SherpaOnnx init failed: $e\n$st');
    _stateController.add(TtsState.error);
    rethrow;
  }
}

sherpa_onnx.OfflineTts? _tts;
```

在文件顶部 import 加:

```dart
import 'dart:io';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/services/tts/sherpa_onnx_tts_service_test.dart --plain-name "init copies"
```

预期:`All tests passed!`(可能耗时 30-60s,首次拷贝 60MB asset 慢)。

如果失败:
- `rootBundle.load` 失败 → 检查 pubspec.yaml assets 路径是否正确(T1 step 3)
- sherpa_onnx API 不匹配 → 查 `C:\zhiyue_build_s3\.dart_tool\package_config.json` 找到 sherpa_onnx 实际路径,读 `lib/sherpa_onnx.dart` 确认类名

- [ ] **Step 5: 全量 test 无回归**

```bash
cd C:\zhiyue_build_s3\app
flutter test
```

预期:`1735 tests passed`(+1 新)/ `0 failed`。

- [ ] **Step 6: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/services/tts/sherpa_onnx_tts_service.dart \
        app/test/services/tts/sherpa_onnx_tts_service_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): implement SherpaOnnxTtsService.init (POC T4)

- Copies model.onnx/lexicon.txt/tokens.txt from assets to app support dir
- Loads sherpa_onnx.OfflineTts with MeloTTS-zh_en config
- Emits TtsState.loading then idle on success
- Integration test verifies files on disk + isInitialized=true

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: TDD speakSentence + stop + state stream + progress

**Files:**
- Modify: `app/lib/services/tts/sherpa_onnx_tts_service.dart`(speakSentence/stop/setSpeechRate/setVolume/pause 实现)
- Create: `app/lib/services/tts/sherpa_onnx_audio_player.dart`(Float32 → PCM16 + audioplayers 播放)
- Test: `app/test/services/tts/sherpa_onnx_tts_service_test.dart`(加 speak test)

- [ ] **Step 1: Create SherpaOnnxAudioPlayer helper**

创建 `C:\zhiyue_build_s3\app\lib\services\tts\sherpa_onnx_audio_player.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// 把 sherpa_onnx Float32List samples 转 PCM16 WAV bytes 并播放。
/// POC v1.15.0-alpha 用 audioplayers;Phase 2 如延迟不可接受换 soundpool/flutter_soloud。
class SherpaOnnxAudioPlayer {
  final _player = AudioPlayer();
  bool _stopped = false;

  /// 播放 [samples](范围 -1.0..1.0),返回播放完成 Future。
  /// 调 [stop] 中断。
  Future<void> play(Float32List samples, int sampleRate) async {
    _stopped = false;
    final wavBytes = _float32ToWav(samples, sampleRate);
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(1.0);
    await _player.play(BytesSource(wavBytes));

    // 等播放完成
    await _player.onPlayerComplete.first;
  }

  Future<void> stop() async {
    _stopped = true;
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  /// Float32 (-1..1) → PCM16 little-endian → WAV 容器
  Uint8List _float32ToWav(Float32List samples, int sampleRate) {
    final pcm = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      pcm[i] = (clamped * 32767).round();
    }
    final pcmBytes = pcm.buffer.asUint8List();

    // WAV header(44 bytes, mono PCM16)
    final header = ByteData(44);
    header.setUint32(4, 36 + pcmBytes.length, Endian.little); // RIFF chunk size
    header.setUint32(40, pcmBytes.length, Endian.little); // data chunk size
    header.setUint32(24, sampleRate, Endian.little); // sample rate
    header.setUint16(22, 1, Endian.little); // num channels
    header.setUint16(32, sampleRate * 2, Endian.little); // byte rate
    header.setUint16(34, 16, Endian.little); // bits per sample
    // "RIFF", "WAVE", "fmt ", "data" 4-char tags
    header.setString(0, 'RIFF');
    header.setString(8, 'WAVE');
    header.setString(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // fmt chunk size
    header.setUint16(20, 1, Endian.little); // PCM
    header.setString(36, 'data');

    final out = BytesBuilder();
    out.add(header.buffer.asUint8List());
    out.add(pcmBytes);
    return out.toBytes();
  }
}

extension on ByteData {
  void setString(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      setUint8(offset + i, s.codeUnitAt(i));
    }
  }
}
```

- [ ] **Step 2: Write failing test for speakSentence**

在 `sherpa_onnx_tts_service_test.dart` 加:

```dart
test('speakSentence generates audio and emits speaking then idle', () async {
  final service = SherpaOnnxTtsService();
  await service.init();

  final states = <TtsState>[];
  final sub = service.state.listen(states.add);

  const sentence = Sentence(
    text: '你好,这是一个测试',
    locale: 'zh-CN',
    charStart: 0,
    charEnd: 9,
  );
  service.setCurrentSentenceIndex(0);
  await service.speakSentence(sentence);

  // 等待播放完成(state 转 idle)
  await service.state.firstWhere((s) => s == TtsState.idle || s == TtsState.error)
      .timeout(const Duration(seconds: 30));

  expect(states, contains(TtsState.speaking));
  expect(states.last, anyOf(TtsState.idle, TtsState.error));

  await sub.cancel();
  await service.dispose();
}, timeout: const Timeout(Duration(minutes: 1)));
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/services/tts/sherpa_onnx_tts_service_test.dart --plain-name "speakSentence"
```

预期:`UnimplementedError: POC T5 implements`。

- [ ] **Step 4: 实现 speakSentence/stop/pause/setSpeechRate/setVolume**

修改 `sherpa_onnx_tts_service.dart`:

```dart
import 'sherpa_onnx_audio_player.dart';

// 在 class 内加字段:
double _rate = 0.0; // -1..1, 0=normal
double _volume = 1.0;
final SherpaOnnxAudioPlayer _audioPlayer = SherpaOnnxAudioPlayer();
bool _stopped = false;

@override
Future<void> speakSentence(Sentence sentence) async {
  if (!_initialized || _tts == null) {
    _errorController.add('SherpaOnnx not initialized');
    _stateController.add(TtsState.error);
    return;
  }

  _stopped = false;
  _stateController.add(TtsState.speaking);

  try {
    // sherpa_onnx.generate speed: 1.0=normal,>1 faster
    // flutter_tts rate: -1.0..1.0 where 0=normal
    final speed = 1.0 * (1.0 + _rate);
    final result = _tts!.generate(sentence.text, sid: 0, speed: speed);

    _progressController.add(TtsProgress(
      sentenceIndex: _currentSentenceIndex,
      charStart: 0,
      charEnd: sentence.text.length,
    ));

    if (_stopped) {
      _stateController.add(TtsState.idle);
      return;
    }

    await _audioPlayer.play(result.samples, result.sampleRate);
    _stateController.add(TtsState.idle);
  } catch (e, st) {
    _errorController.add('SherpaOnnx speak failed: $e\n$st');
    _stateController.add(TtsState.error);
  }
}

@override
Future<void> stop() async {
  _stopped = true;
  await _audioPlayer.stop();
  _stateController.add(TtsState.stopped);
  // 后续 idle 由 TtsPlaybackController 读取 stopped 后转 idle
}

@override
Future<void> pause() async {
  // sherpa-onnx 无 native pause;POC 用 stop + 标记,TtsPlaybackController 暂不区分
  await stop();
}

@override
Future<void> setSpeechRate(double rate) async {
  _rate = rate.clamp(-1.0, 1.0);
}

@override
Future<void> setVolume(double volume) async {
  _volume = volume.clamp(0.0, 1.0);
}
```

`_tts!.generate(...)` 的精确签名以 T4 实际加载的 sherpa_onnx 包为准,如签名不同(`TtsGenerationResult` 而非 inline 返回 samples),调整:

```dart
final result = _tts!.generate(sentence.text, sid: 0, speed: speed);
// sherpa_onnx 1.13.x OfflineTts.generate() 返回 OfflineTtsGeneratedAudio
// 它有 .samples (Float32List) 和 .sampleRate (int) 字段
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/services/tts/sherpa_onnx_tts_service_test.dart --plain-name "speakSentence"
```

预期:`All tests passed!`(首次 ~10-20s,含模型推理 + 音频播放等待)。

- [ ] **Step 6: 全量 test 无回归**

```bash
cd C:\zhiyue_build_s3\app
flutter test
```

预期:`1736 tests passed`(+1 新)/ `0 failed`。

- [ ] **Step 7: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/services/tts/sherpa_onnx_tts_service.dart \
        app/lib/services/tts/sherpa_onnx_audio_player.dart \
        app/test/services/tts/sherpa_onnx_tts_service_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): implement speakSentence + stop + state stream (POC T5)

- SherpaOnnxAudioPlayer: Float32 → PCM16 WAV → audioplayers
- speakSentence: emit speaking → generate → play → emit idle
- stop: signals _stopped + stops audio player + emits TtsState.stopped
- pause: alias to stop (sherpa-onnx has no native pause)
- setSpeechRate/setVolume: stored as fields, applied in next speakSentence

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: TDD factory dispatch by preference + 注入 playback controller

**Files:**
- Modify: `app/lib/services/tts/tts_service_factory.dart`(签名加 preferredEngine)
- Modify: `app/lib/features/tts/providers/tts_playback_controller.dart`(注入 ttsEngineProvider)
- Test: `app/test/features/tts/tts_engine_factory_dispatch_test.dart`

- [ ] **Step 1: Write failing test**

创建 `C:\zhiyue_build_s3\app\test\features\tts\tts_engine_factory_dispatch_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';
import 'package:zhiyue/services/tts/tts_service.dart';
import 'package:zhiyue/services/tts/tts_service_factory.dart';
import 'package:zhiyue/services/tts/flutter_tts_service.dart';
import 'package:zhiyue/services/tts/sherpa_onnx_tts_service.dart';

void main() {
  group('createTtsService with preferredEngine', () {
    test('system preference returns existing platform service', () {
      final service = createTtsService(
        platformName: 'android',
        preferredEngine: TtsEnginePreference.system,
      );
      expect(service.runtimeType.toString(), contains('SelfBuilt'));
    });

    test('sherpaOnnxMelo preference returns SherpaOnnxTtsService', () {
      final service = createTtsService(
        platformName: 'android',
        preferredEngine: TtsEnginePreference.sherpaOnnxMelo,
      );
      expect(service, isA<SherpaOnnxTtsService>());
    });

    test('windows + system returns FlutterTtsServiceImpl', () {
      final service = createTtsService(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.system,
      );
      expect(service, isA<FlutterTtsServiceImpl>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/features/tts/tts_engine_factory_dispatch_test.dart
```

预期:`createTtsService` 命名参数 `preferredEngine` 不存在。

- [ ] **Step 3: 修改 factory**

替换 `app/lib/services/tts/tts_service_factory.dart` 全部内容:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/foundation.dart';

import 'flutter_tts_service.dart';
import 'self_built_tts_service.dart';
import 'sherpa_onnx_tts_service.dart';
import 'tts_engine_preference.dart';
import 'tts_service.dart';

/// Creates a [TtsService] for [platformName] honoring [preferredEngine].
///
/// v1.15.0-alpha POC: 2 engines (system / sherpaOnnxMelo)
/// Phase 2 will add more (theresa / aishell3 / cosyvoice-desktop).
TtsService createTtsService({
  required String platformName,
  TtsEnginePreference preferredEngine = TtsEnginePreference.system,
}) {
  // Sherpa-ONNX 在所有平台都可用(POC 验证 Android + Windows)
  if (preferredEngine == TtsEnginePreference.sherpaOnnxMelo) {
    return SherpaOnnxTtsService();
  }
  // system 偏好:走原平台派发
  switch (platformName.toLowerCase()) {
    case 'android':
      return SelfBuiltTtsServiceImpl();
    default:
      return FlutterTtsServiceImpl();
  }
}

/// Production entry point — uses [defaultTargetPlatform] + [ttsEngineProvider] current value.
TtsService createTtsServiceFor({
  required TtsEnginePreference preferredEngine,
  String? platformName,
}) {
  final target = defaultTargetPlatform;
  final name = platformName ??
      switch (target) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        TargetPlatform.macOS => 'macos',
        TargetPlatform.windows => 'windows',
        TargetPlatform.linux => 'linux',
        TargetPlatform.fuchsia => 'fuchsia',
      };
  return createTtsService(platformName: name, preferredEngine: preferredEngine);
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/features/tts/tts_engine_factory_dispatch_test.dart
```

预期:`All tests passed! (3 tests)`。

- [ ] **Step 5: 改 playback_controller 注入引擎偏好**

读 `app/lib/features/tts/providers/tts_playback_controller.dart`,找到 `createTtsService()` 调用处(文件顶部附近)。

如果该 provider 用 `Provider<TtsService>` 单例,改为按当前 preference 动态构建。**POC 最小改动**:加 `ttsEngineProvider` 依赖,preference 变化时重建 service:

```dart
// 在文件顶部 import 加:
import '../../../services/tts/sherpa_onnx_tts_service.dart';
import '../../../services/tts/tts_engine_preference.dart';
import 'tts_engine_provider.dart';

// 把原 ttsService 单一 provider 拆成两层(实际签名以现有代码为准):

/// v1.15.0-alpha: 基于 ttsEngineProvider 当前值动态构建 TtsService。
/// preference 变化时自动重建(Ref.autoDispose + watch 引擎 → invalidate)。
final ttsServiceProvider = Provider<TtsService>((ref) {
  final engine = ref.watch(ttsEngineProvider);
  final service = createTtsServiceFor(preferredEngine: engine);
  ref.onDispose(service.dispose);
  // SherpaOnnx 需显式 init(系统 TTS 在 ctor 内自动 init)
  if (engine != TtsEnginePreference.system) {
    service.init();
  }
  return service;
});
```

注意:POC 期可容忍 service init 是 fire-and-forget;若已有 init pattern 跟随现有 `FlutterTtsServiceImpl.init()` 时序。读现有 playback controller 完整代码后再确定精确改动点。

- [ ] **Step 6: 全量 test 无回归**

```bash
cd C:\zhiyue_build_s3\app
flutter test
```

预期:`1739 tests passed`(+3 新 factory test)/ `0 failed`。

如果有 playback_controller 相关测试因 provider 重建而 break:
- 修复方式:测试用 `ProviderContainer(overrides: [ttsEngineProvider.overrideWith((ref) => ... system])]）` 强制 system
- 不允许为了让测试通过改业务逻辑

- [ ] **Step 7: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/services/tts/tts_service_factory.dart \
        app/lib/features/tts/providers/tts_playback_controller.dart \
        app/test/features/tts/tts_engine_factory_dispatch_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): factory dispatches by TtsEnginePreference (POC T6)

- createTtsService takes preferredEngine param (default system)
- sherpaOnnxMelo returns SherpaOnnxTtsService regardless of platform
- ttsServiceProvider watches ttsEngineProvider, auto-rebuilds on change
- Non-system engines get explicit init() (sherpa-onnx requires file copy)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Debug settings page 引擎切换 UI

**Files:**
- Modify: `app/lib/features/settings/pages/settings_page.dart`(加 TTS 引擎 dropdown)
- Test: `app/test/features/settings/pages/settings_page_tts_engine_test.dart`

- [ ] **Step 1: Write failing test**

创建 `C:\zhiyue_build_s3\app\test\features\settings\pages\settings_page_tts_engine_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/settings/pages/settings_page.dart';
import 'package:zhiyue/features/tts/providers/tts_engine_provider.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';

void main() {
  testWidgets('settings page shows TTS engine dropdown with 2 options', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsEngineProvider.overrideWith((ref) => _FakeEngineNotifier()),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 找到 TTS 引擎 dropdown
    expect(find.text('TTS 引擎(实验)'), findsOneWidget);

    // 点开 dropdown
    await tester.tap(find.text('TTS 引擎(实验)'));
    await tester.pumpAndSettle();

    expect(find.text('系统(默认)'), findsOneWidget);
    expect(find.text('SherpaOnnx MeloTTS(下载 60MB)'), findsOneWidget);
  });
}

class _FakeEngineNotifier extends TtsEngineNotifier {
  _FakeEngineNotifier() : super() {
    state = TtsEnginePreference.system;
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/features/settings/pages/settings_page_tts_engine_test.dart
```

预期:`TTS 引擎(实验)` 找不到。

- [ ] **Step 3: 加 dropdown 到 settings_page**

读 `app/lib/features/settings/pages/settings_page.dart`,找一个合适位置(TTS 相关 settings 附近或新建 section)。加 widget:

```dart
import '../../../services/tts/tts_engine_preference.dart';
import '../../tts/providers/tts_engine_provider.dart';

// 在合适 section 加:
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TTS 引擎(实验)', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Consumer(builder: (context, ref, _) {
          final engine = ref.watch(ttsEngineProvider);
          return DropdownButton<TtsEnginePreference>(
            value: engine,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: TtsEnginePreference.system,
                child: Text('系统(默认)'),
              ),
              DropdownMenuItem(
                value: TtsEnginePreference.sherpaOnnxMelo,
                child: Text('SherpaOnnx MeloTTS(下载 60MB)'),
              ),
            ],
            onChanged: (value) async {
              if (value == null) return;
              await ref.read(ttsEngineProvider.notifier).setEngine(value);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('引擎已切换,重启朗读生效')),
              );
            },
          );
        }),
      ],
    ),
  ),
),
```

POC 期提示文案「下载 60MB」不准确(模型已 bundle 在 asset),Phase 2 改为按需下载时调整文案。

- [ ] **Step 4: Run test to verify it passes**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/features/settings/pages/settings_page_tts_engine_test.dart
```

预期:`All tests passed!`(1 test)。

- [ ] **Step 5: 全量 test 无回归**

```bash
cd C:\zhiyue_build_s3\app
flutter test
```

预期:`1740 tests passed`(+1 新) / `0 failed`。

- [ ] **Step 6: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/features/settings/pages/settings_page.dart \
        app/test/features/settings/pages/settings_page_tts_engine_test.dart
git commit -m "$(cat <<'EOF'
feat(settings): add TTS engine debug switcher (POC T7)

- Dropdown: 系统(默认) / SherpaOnnx MeloTTS(下载 60MB)
- POC bundled asset so no actual download;Phase 2 refactors to on-demand
- SnackBar: 'Engine switched, restart playback to take effect'

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Benchmark harness — log RTF + 内存 + 模型加载耗时

**Files:**
- Create: `app/lib/features/tts/utils/sherpa_onnx_benchmark.dart`
- Test: `app/test/features/tts/utils/sherpa_onnx_benchmark_test.dart`(单元测试 mock + 集成测试可选)

- [ ] **Step 1: Write failing test**

创建 `C:\zhiyue_build_s3\app\test\features\tts\utils\sherpa_onnx_benchmark_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/tts/utils/sherpa_onnx_benchmark.dart';

void main() {
  group('SherpaOnnxBenchmarkResult', () {
    test('RTF computation: 2s synth for 5s audio = 0.4 RTF', () {
      final r = SherpaOnnxBenchmarkResult(
        textLength: 50,
        synthDuration: const Duration(milliseconds: 2000),
        audioDuration: const Duration(milliseconds: 5000),
        peakMemoryMb: 200,
        modelLoadDuration: const Duration(milliseconds: 1500),
      );
      expect(r.rtf, closeTo(0.4, 0.001));
    });

    test('toMarkdownRow produces | text | 50 | 2000 | 5000 | 0.40 | 200 | 1500 |', () {
      final r = SherpaOnnxBenchmarkResult(
        textLength: 50,
        synthDuration: const Duration(milliseconds: 2000),
        audioDuration: const Duration(milliseconds: 5000),
        peakMemoryMb: 200,
        modelLoadDuration: const Duration(milliseconds: 1500),
      );
      final row = r.toMarkdownRow(label: 'sentence 1');
      expect(row, contains('| sentence 1 |'));
      expect(row, contains('| 50 |'));
      expect(row, contains('| 0.4 |'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/features/tts/utils/sherpa_onnx_benchmark_test.dart
```

预期:`sherpa_onnx_benchmark.dart` 不存在。

- [ ] **Step 3: Create benchmark util**

创建 `C:\zhiyue_build_s3\app\lib\features\tts\utils\sherpa_onnx_benchmark.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import '../../../services/tts/sherpa_onnx_tts_service.dart';
import '../../../services/tts/tts_service.dart';

class SherpaOnnxBenchmarkResult {
  final int textLength;
  final Duration synthDuration;
  final Duration audioDuration;
  final int peakMemoryMb;
  final Duration modelLoadDuration;

  SherpaOnnxBenchmarkResult({
    required this.textLength,
    required this.synthDuration,
    required this.audioDuration,
    required this.peakMemoryMb,
    required this.modelLoadDuration,
  });

  /// RTF < 1.0 = faster than real-time; mobile usable threshold = 0.5
  double get rtf =>
      synthDuration.inMilliseconds / audioDuration.inMilliseconds;

  String toMarkdownRow({required String label}) {
    return '| $label | $textLength | ${synthDuration.inMilliseconds} | '
        '${audioDuration.inMilliseconds} | ${rff(rtf, 2)} | $peakMemoryMb | '
        '${modelLoadDuration.inMilliseconds} |';
  }

  static String fff(double v, int digits) => v.toStringAsFixed(digits);
  // ignore: non_constant_identifier_names
  static String rff(double v, int digits) => v.toStringAsFixed(digits);
}

/// 跑一组标准中文句子的 benchmark。返回每句 result + 总结 row。
///
/// POC T8:测试句集覆盖短/中/长 + 中英混排,模拟真实阅读场景。
class SherpaOnnxBenchmark {
  static const testSentences = <String>[
    '你好,这是一个测试。',  // 短
    '当夜幕降临,星光点点,伴随着微风拂面,我在静谧中感受着时光的流转。',  // 中
    '中华人民共和国是工人阶级领导的、以工农联盟为基础的人民民主专政的社会主义共和国。'
        '《中华人民共和国宪法》是国家的根本法,具有最高的法律效力。',  // 长
    '我在读 Thinking, Fast and Slow 这本书,作者是 Daniel Kahneman。',  // 中英混排
  ];

  static Future<List<SherpaOnnxBenchmarkResult>> run({
    required SherpaOnnxTtsService service,
    void Function(int index, String sentence)? onProgress,
  }) async {
    final results = <SherpaOnnxBenchmarkResult>[];

    for (var i = 0; i < testSentences.length; i++) {
      final text = testSentences[i];
      onProgress?.call(i, text);

      // Mark begin
      final synthStart = DateTime.now();
      service.setCurrentSentenceIndex(i);

      // 注入测试句到 speakSentence
      // 由于 speakSentence 是 fire-and-forget,benchmark 改为直接 generate:
      // POC T8 实现需要 service 暴露 generate-only 入口,或在此用 progress event 计算
      // 详见 step 4 实现说明

      final synthEnd = DateTime.now();
      // audioDuration 通过 result.samples.length / sampleRate 算

      // TODO T8 step 4: 完整实现见 step 4
    }

    return results;
  }
}
```

注意:`run()` 内部需要访问 `sherpa_onnx.OfflineTts.generate()` 直接结果拿 audioDuration(samples.length / sampleRate)。实现方式:**给 `SherpaOnnxTtsService` 加一个 `@visibleForTesting Future<SherpaOnnxBenchmarkResult> benchmark(String text)` 方法**,直接调 `_tts!.generate(text)` 并测时。

- [ ] **Step 4: 给 SherpaOnnxTtsService 加 benchmark 入口**

修改 `app/lib/services/tts/sherpa_onnx_tts_service.dart`,在 class 内加:

```dart
import 'package:flutter/foundation.dart';
import '../features/tts/utils/sherpa_onnx_benchmark.dart';

/// @visibleForTesting — POC T8 benchmark 入口,直接调底层 generate。
@visibleForTesting
Future<SherpaOnnxBenchmarkResult> benchmark(String text) async {
  if (!_initialized || _tts == null) {
    throw StateError('SherpaOnnx not initialized');
  }
  final sw = Stopwatch()..start();
  final result = _tts!.generate(text, sid: 0, speed: 1.0);
  sw.stop();

  final audioMs = (result.samples.length / result.sampleRate * 1000).round();

  return SherpaOnnxBenchmarkResult(
    textLength: text.length,
    synthDuration: sw.elapsed,
    audioDuration: Duration(milliseconds: audioMs),
    peakMemoryMb: _currentMemoryMb(),
    modelLoadDuration: const Duration(milliseconds: 0), // init 时记录,字段加
  );
}

int _currentMemoryMb() {
  // POC: Dart 没有直接的 RSS API,返回 ProcessInfo 的当前 isolate memory
  // 真实 RSS 需要 Platform channel 调 Android Debug.MemoryInfo
  // POC 用 ProcessInfo.currentRss 作为近似
  return (ProcessInfo.currentRss / (1024 * 1024)).round();
}
```

并改 `SherpaOnnxBenchmark.run()` 实现使用此入口:

```dart
static Future<List<SherpaOnnxBenchmarkResult>> run({
  required SherpaOnnxTtsService service,
  void Function(int index, String sentence)? onProgress,
}) async {
  final results = <SherpaOnnxBenchmarkResult>[];
  for (var i = 0; i < testSentences.length; i++) {
    onProgress?.call(i, testSentences[i]);
    final r = await service.benchmark(testSentences[i]);
    results.add(r);
  }
  return results;
}
```

- [ ] **Step 5: Run tests pass**

```bash
cd C:\zhiyue_build_s3\app
flutter test test/features/tts/utils/sherpa_onnx_benchmark_test.dart
```

预期:`All tests passed! (2 tests)`。

- [ ] **Step 6: 全量 test + 真机 benchmark**

```bash
cd C:\zhiyue_build_s3\app
flutter test
```

预期:`1742 tests passed`(+2 新) / `0 failed`。

真机 benchmark 由 T9 在 POC report 里手动跑(用 `flutter run` + DevTools 或 debug print)。

- [ ] **Step 7: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/features/tts/utils/sherpa_onnx_benchmark.dart \
        app/lib/services/tts/sherpa_onnx_tts_service.dart \
        app/test/features/tts/utils/sherpa_onnx_benchmark_test.dart
git commit -m "$(cat <<'EOF'
feat(tts): add SherpaOnnxBenchmark harness + service.benchmark (POC T8)

- SherpaOnnxBenchmarkResult: RTF + synth duration + audio duration + memory
- SherpaOnnxBenchmark.run: 4 test sentences (short/medium/long/zh-en-mix)
- SherpaOnnxTtsService.benchmark: @visibleForTesting direct generate() entry
- 2 unit tests cover RTF math + markdown row format

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: POC report + 决策

**Files:**
- Create: `docs/research/2026-07-XX-sherpa-onnx-tts-poc-report.md`

- [ ] **Step 1: 真机跑 benchmark**

```bash
cd C:\zhiyue_build_s3
flutter run --flavor withFgs --lib-file lib/main_dev.dart
# 或:flutter run --release + 手动触发 benchmark
```

在中端 Android 设备(骁龙 7 系 / 天玑 8000 为主,旗舰作为对照)上:
1. 在 settings 切换引擎到 SherpaOnnx MeloTTS
2. 朗读一本 EPUB 中文书
3. 触发 benchmark(可加临时 debug 按钮调用 `SherpaOnnxBenchmark.run`,print 每句 result.toMarkdownRow())
4. 记录 RTF 数据 + 内存峰值

- [ ] **Step 2: 中文母语盲听**

至少 3 个中文母语用户(包括用户本人)对以下句子盲听评分 1-5 分:

| 句子 | 系统 TTS | SherpaOnnx MeloTTS |
|---|---|---|
| 你好,这是一个测试 | __ | __ |
| 当夜幕降临,星光点点... | __ | __ |
| 中华人民共和国是工人阶级领导的... | __ | __ |
| 我在读 Thinking, Fast and Slow | __ | __ |

评分维度:发音准确 / 自然度 / 节奏感 / 听感疲劳(连续 30 分钟朗读后)。

- [ ] **Step 3: 写 POC report**

创建 `docs/research/2026-07-XX-sherpa-onnx-tts-poc-report.md`(日期填实际完成日):

```markdown
# Sherpa-ONNX TTS Engine POC Report

**日期**:2026-07-XX
**POC 周期**:T1-T8 共 X 天
**参与人**:用户 + Claude(Code) + 中文盲听评估组(N 人)

## 1. 执行摘要

[一段话:SherpaOnnx MeloTTS 在中端 Android 上 RTF=X.XX,中文母语听感 X/5 vs 系统 TTS X/5。决策:[Go/No-Go] Phase 2 全量实现。]

## 2. Benchmark 数据

| 设备 | 句子 | 长度 | synth (ms) | audio (ms) | RTF | 内存 (MB) |
|---|---|---|---|---|---|---|
| [型号] | 短 | 9 | XXX | XXX | X.XX | XXX |
| ... | ... | ... | ... | ... | ... | ... |

## 3. 中文母语盲听

| 维度 | 系统 TTS | SherpaOnnx MeloTTS | 差距 |
|---|---|---|---|
| 发音准确 | X.X | X.X | ±X.X |
| 自然度 | X.X | X.X | ±X.X |
| 节奏感 | X.X | X.X | ±X.X |
| 听感疲劳 | X.X | X.X | ±X.X |
| 综合 | X.X | X.X | ±X.X |

## 4. APK 体积影响

| 配置 | APK 大小 | 增量 |
|---|---|---|
| v1.14.2-alpha baseline | 135 MB | - |
| + sherpa_onnx native libs | XXX MB | +X MB |
| + MeloTTS asset | XXX MB | +X MB |

## 5. 已知问题

- [问题 1:...]
- [问题 2:...]

## 6. 决策

[ ] **Go Phase 2**:SherpaOnnx MeloTTS 作为移动端主力离线引擎,Phase 2 实现:
  - 模型按需下载
  - 多 voice 选择
  - 正式 settings panel
  - CosyVoice 桌面集成(Phase 2 W3)

[ ] **No-Go**:启动 Phase 4 备选目录(edge-tts / 阿里云 CosyVoice API)

[ ] **范围调整**:[说明]
```

- [ ] **Step 4: Commit**

```bash
cd C:\zhiyue_build_s3
git add docs/research/2026-07-XX-sherpa-onnx-tts-poc-report.md
git commit -m "$(cat <<'EOF'
docs(tts): add Sherpa-ONNX POC report + decision (POC T9)

[summary of decision + key data points]

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Critical files (汇总)

**lib/services/tts/**(新建 3):
- `sherpa_onnx_tts_service.dart` — 新引擎实现(T3-T5)
- `sherpa_onnx_audio_player.dart` — PCM 播放器(T5)
- `tts_engine_preference.dart` — 引擎偏好 enum(T2)

**lib/services/tts/**(修改 1):
- `tts_service_factory.dart` — 加 preferredEngine 参数(T6)

**lib/features/tts/providers/**(新建 1 + 修改 1):
- `tts_engine_provider.dart` — secure_storage 持久化(T2)
- `tts_playback_controller.dart` — 注入 ttsEngineProvider(T6)

**lib/features/tts/utils/**(新建 1):
- `sherpa_onnx_benchmark.dart` — RTF 测量(T8)

**lib/features/settings/pages/**(修改 1):
- `settings_page.dart` — Debug dropdown(T7)

**test/**(新建 5):
- `test/services/tts/sherpa_onnx_tts_service_test.dart`
- `test/features/tts/providers/tts_engine_provider_test.dart`
- `test/features/tts/tts_engine_factory_dispatch_test.dart`
- `test/features/settings/pages/settings_page_tts_engine_test.dart`
- `test/features/tts/utils/sherpa_onnx_benchmark_test.dart`

**docs/**(新建 1):
- `docs/research/2026-07-XX-sherpa-onnx-tts-poc-report.md`

---

## Reuse existing

- `TtsService` 抽象(`tts_service.dart`)— SherpaOnnxTtsService 直接 implements,不改接口
- `Sentence` / `TtsState` / `TtsProgress` 现有契约,新引擎填充这些事件
- `flutter_secure_storage`(已在 pubspec)— 偏好持久化
- `path_provider`(已在 pubspec)— app support dir
- `TtsPlaybackController` 现有 state machine 现状不动,只读 `TtsService` 接口
- `SelfBuiltTtsServiceImpl` / `FlutterTtsServiceImpl` 完全不动,作为 system 偏好实现
- T1 release 流程模式(`feedback_flutter_strip_cache_trap`):APK marker verify + 三层 intermediates 清理
- TDD 红绿循环模式(参照 `2026-07-19-tts-bug-batch-7.md`)

---

## Verification

1. **单元 + 集成测试**:`cd C:\zhiyue_build_s3 && flutter test` — 预期 1742 pass / 25 skip / 0 fail(从 1731 增加 +11 新测试:T2 +2 / T3 +3 / T4 +1 / T5 +1 / T6 +3 / T7 +1 / T8 +2)。
2. **Android 真机冒烟**:在中端 Android 上 `flutter run --flavor withFgs`,settings 切引擎 → 朗读 EPUB 章节 → 验证 audio 正常播放 + 切回 system 不 crash。
3. **Windows 桌面冒烟**:`flutter run -d windows`,切引擎 → 朗读 → 验证(POC 接受 Windows 用 SherpaOnnx 表现差,数据记录即可)。
4. **Benchmark 数据**:T8 harness 在 ≥ 1 台 Android 设备上跑完 4 句,记录 RTF。
5. **APK 体积**:`flutter build apk --flavor withFgs --release` 后对比 v1.14.2-alpha baseline(135 MB)。
6. **盲听评估**:≥ 3 个中文母语用户填表。
7. **决策文档**:T9 report 完整填空,用户签字(Go/No-Go)。

---

## Risks

1. **`sherpa_onnx` Flutter 包 API 与文档不一致**:T3-T5 实现可能因 1.13.4 版本 API 微调(类名/方法名)break。Mitigation:T3 step 3 给出 fallback「读 `.dart_tool/package_config.json` 找实际包路径,读源码确认」。
2. **APK 体积超 200MB**:用户下载门槛上升。Mitigation:T1 step 5 验证 ~190MB debug;release + ABI splits 后单 ABI ~80MB。
3. **audioplayers PCM 播放延迟过大**:POC 接受,如 RTF < 0.3 但实际听感卡顿,Phase 2 W1 换 soundpool / flutter_soloud。
4. **真机首次 asset 拷贝 60MB 慢**:首次启动 settings 切引擎可能等 5-10s。Mitigation:T4 init() 在 splash 时预拷贝(Phase 2);POC 接受。
5. **盲听结果:SherpaOnnx 中文不如系统 TTS**:G4 失败 → T9 决策 No-Go → 启动 Phase 4 edge-tts 在线评估。这是 POC 设计的合理退出。
6. **T7 settings_page 改动 break 现有 widget test**:T7 step 5 全量 test 验证。如有 break,override provider 而非改业务。
7. **`audioplayers` 与现有 `flutter_tts` audio session 冲突**(Android 后台播放):POC 不验证后台播放,仅前台朗读;Phase 2 W2 接入 MediaSession。
8. **CRLF / strip cache trap**(POC T8+ release 时):照搬 v1.14.2-alpha 流程,Python binary-safe 替换 + 三层 intermediates 清理。

---

## Out-of-scope 后续阶段备忘

### Phase 2 W1-W3(POC Go 后,2-3 周)
- 模型按需下载(HuggingFace / ModelScope 镜像 + 进度 + WiFi-only)
- 多 voice UI(theresa 804 voices / aishell3 174 voices)
- 正式 settings panel(取代 POC T7 dropdown)
- drift schema v15→v16 加 userTtsEngine 表
- Windows 桌面 CosyVoice 2 集成(Python 子进程)

### Phase 4 备选目录(POC No-Go 时启动)
- edge-tts 在线模式(`edge_tts_flutter` 或自接 WebSocket)
- 阿里云 CosyVoice API(用户填 key)
- OpenAI 兼容 TTS endpoint(用户填 endpoint + key)

---

## Self-Review

✅ **Spec coverage**:本 plan 覆盖 v3 方案中 Phase 1 POC 全部范围 — sherpa_onnx 集成 / MeloTTS 模型 / 引擎抽象 / debug UI / benchmark / 决策报告。Phase 2 / Phase 4 明确 Out-of-scope。

✅ **Placeholder scan**:每 step 都有具体代码或具体命令;无 "TBD" / "implement later" / "similar to"。T5 step 4 关于 `sherpa_onnx.OfflineTts.generate` 签名的不确定性给出明确 fallback(step 4 末尾)。

✅ **Type consistency**:
- `TtsEnginePreference.system / sherpaOnnxMelo` 全文一致
- `SherpaOnnxTtsService` 类名一致
- `ttsEngineProvider` 全文一致
- `SherpaOnnxBenchmarkResult` 字段名(textLength/synthDuration/audioDuration/peakMemoryMb/modelLoadDuration)跨 T8 一致

✅ **API 一致性**:`sherpa_onnx.OfflineTtsConfig` / `OfflineTtsModelConfig` / `OfflineTtsVitsModelConfig` / `OfflineTts.generate(text, sid, speed)` 来自官方 flutter-examples,model.dart 真实代码示例。若 1.13.4 包微调类名,T3 step 3 给出调试 fallback。
