# v1.16.2-alpha Release Notes

## OPPO/小米 系统默认 TTS 初始化失败反馈

### 背景

用户反馈 OPPO 和小米手机上「系统默认 TTS」没声音，设置页测试朗读也无反应。

诊断日志关键证据：
- `TTS init callback status=-1` 在 5ms 内同步失败
- 11 个 SPEAK intent 全部静默 deferred
- 荣耀 / 老华为（EMUI/MagicOS）正常

荣耀/老华为正常是**决定性证据**——问题不在 Android 原生 `TextToSpeech` API 本身，而在 **OPPO ColorOS / 小米 MIUI ROM** 对 foreground service 内绑定 system TTS service 的限制。

### 本次修复

| 改动 | 说明 |
|---||
| init 失败 500ms 后用 `applicationContext` 重试 1 次 | 绕过部分 ROM 对 service context 的限制 |
| retry 失败 emit `init_error` 事件到 Dart | 之前完全静默，用户无任何反馈 |
| UI SnackBar 含 OPPO/小米引导 | 「允许自启动」+「切换 TTS 引擎」+ 「打开系统 TTS 设置」按钮 |

### 用户测试场景

**场景 A（核心修复验证）**：
1. 设置 → 朗读 → 引擎选「系统默认」
2. 点击「测试朗读」
3. **预期**：弹出 SnackBar「系统 TTS 初始化失败 + OPPO/小米引导」+ 「打开系统 TTS 设置」按钮
4. 点「打开系统 TTS 设置」 → 跳转系统设置页

**场景 B（根因 #2 验证）**：
1. 在系统 TTS 设置切换默认引擎（如 Google TextToSpeech 或 iflytek 讯飞）
2. 重启智阅
3. **预期**：测试朗读成功 → 证明根因是引擎（候选 #2）
4. 如仍失败 → 根因是 ROM 限制 service binding（候选 #1），需在「应用启动管理」授权

**场景 C（不误报）**：
1. 荣耀 / 华为设备测试
2. **预期**：测试朗读直接成功，**不出现 SnackBar**

### 不做的（参考 feedback_tts_is_auxiliary）

- ROM 检测 + 自动跳转 OPPO/小米「自启动」Intent（维护成本高，每 ROM 版本路径不同）
- 自动 fallback 到 SherpaOnnx 或云端 TTS（用户应显式切换，避免困惑）

### 已知限制

- v1.16.0-alpha 升级用户：如持久化了 V1 火山音色，需在音色 Dropdown 重选（v1.16.1 已知问题）
- 13 个 tts_reader_controller_test.dart 测试 v1.16.0-alpha 起失败，本版本未修（不阻塞）

### 升级路径

- v1.16.0-alpha → v1.16.1-alpha：火山引擎云端 TTS V1→V3 协议升级（不影响系统 TTS）
- v1.16.1-alpha → v1.16.2-alpha：OPPO/小米系统 TTS init 失败反馈（本版本）

### 包体

- Android APK: ~135 MB（无新依赖）
- Windows installer: ~46 MB（无新依赖）
- libapp.so MD5 v1.16.1-alpha → v1.16.2-alpha 不同（确认 Dart 改动进 so）
