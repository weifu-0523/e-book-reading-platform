# v1.16.3-alpha — 小米/OPPO TTS 引擎枚举重试

## 问题

v1.16.2-alpha 已让 init 失败时显示 SnackBar，但小米/OPPO 用户反馈「测试朗读」仍然无声。诊断日志：

```
TTS init callback status=-1     ← 5ms 内同步失败
TTS init FAILED status=-1
scheduling TTS init retry in 500ms with applicationContext
TTS init callback status=-1     ← 500ms 后 retry 也失败
TTS init retry exhausted, emitting init_error to Dart
```

荣耀/老华为设备正常 → 排除 Android API 本身问题。用户已确认系统 TTS 设置里点击测试能播放声音 → 引擎本身工作。

## 根因

小米 MIUI / OPPO ColorOS 的默认 TTS 引擎：
- `com.xiaomi.mibrain.speech`（小爱语音，MIUI 默认）
- `com.heytap.speechservice`（小布语音，ColorOS 默认）

这些 ROM 自家引擎**对第三方 app 不可绑定**（签名保护或未完整实现 `Engine.INTENT_ACTION_TTS_SERVICE`）。系统的 TTS 测试能播 = 引擎本身能工作（system UID 不受限），但 app 调用就被拒。

5ms 同步 `status=-1` 的特征是 `bindService` 在 package resolution 阶段返回 false，符合「service 拒绝绑定」而非 timing race。

## 修复：3 阶段 init 重试状态机

1. **Stage A（v1.16.2 保留）**：500ms 后用 `applicationContext` 重试默认引擎。
2. **Stage B（v1.16.3 新增）**：调用 `PackageManager.queryIntentServices(Engine.INTENT_ACTION_TTS_SERVICE)` 枚举所有标准兼容 TTS 引擎，依次用 3-参构造函数 `TextToSpeech(ctx, listener, enginePackage)` 重试。绕过默认引擎查找，如果用户设备上装了 Google TTS（`com.google.android.tts`）就能成功绑定。
3. **Stage C**：全部失败后 emit `init_error` 事件附带 manufacturer + 引擎列表到 Dart。

## UI 改进

- SnackBar 根据「引擎列表是否为空」给差异化引导：
  - 引擎列表空 → 「未安装标准 TTS 引擎，请到应用商店安装 Google TTS」
  - 引擎列表非空但全失败 → 「ROM 拒绝第三方 app 绑定，建议改用云端引擎」
- SnackBar 新增「改用云端引擎」按钮，一键切到 `qwenCloud`（最易上手的云端引擎，只需 API key）。
- 持续时间 10s → 15s，给用户充分阅读时间。
- 移除「打开系统 TTS 设置」action（系统设置路径不能修复 ROM 绑定拒绝；改用云端引擎更直接）。

## 已知限制

- 如果小米/OPPO 设备上未安装任何标准兼容 TTS 引擎（只有 ROM 自家引擎），3-参构造函数也无效。此时只能切云端引擎。
- Stage B 重试间隔 500ms × 引擎数，最坏情况 4 个引擎 = 2s 启动延迟（用户感知是「点了朗读等了 2 秒才开始」）。
- sherpaOnnxMelo 引擎在 v1.16.0-alpha 已移除（POC 失败：MeloTTS RTF 0.85 + 音质差），所以**没有离线 fallback** —— 云端引擎是唯一的非系统选择。

## 测试

- **Kotlin**：4 个新测试覆盖 3 阶段状态机：引擎枚举重试 / 引擎列表为空跳到 stage C / 所有引擎都失败 / destroyed 守卫防 native leak
- **Dart**：3 个新测试覆盖 engines 字段解析：非空列表 / 空列表 / 字段缺失
- **Widget**：4 个新测试覆盖 SnackBar 行为：ROM 拒绝文案 / 引擎缺失文案 / 按钮切换 qwenCloud / 15s duration regression guard
- 总计：~1670 Dart pass / 52 Kotlin pass

## 真机测试场景（待用户验证）

1. **场景 A（核心修复）**：小米/OPPO 点「测试朗读」→ 后台枚举引擎尝试 3-参构造函数 → 若有可用引擎（如 Google TTS 已装）则朗读成功
2. **场景 B（fallback）**：若所有引擎都失败 → SnackBar 显示「改用云端引擎」按钮 → 点击切换引擎 → 配置云 API key 后再次测试朗读应能播放
3. **场景 C（无误报）**：荣耀/华为不出现 SnackBar（确保正常设备不被误报）

## 包体

- APK: 约 135 MB（v1.16.2 = 135 MB，无新依赖）
- Windows installer: 46 MB

## 不在本次范围

- MIUI/OPPO autostart settings deep-link（用户澄清荣耀/华为也有 autostart 但能用，故 autostart 非主因，autostart 引导降级）
- WebSocket bidirectional streaming for cloud TTS（feedback_tts_is_auxiliary）
- Cloud TTS 自动 fallback when system init fails（架构耦合，D7 in v1.16.2 spec）
