# v1.16.0-alpha

**发布日期**：2026-07-23
**类型**：major（TTS 混合云策略 — 移除 SherpaOnnx + 新增双云端 TTS）
**上一版本**：v1.15.6-alpha

## 摘要

v1.15.0 → v1.15.6 的 SherpaOnnx + MeloTTS 离线神经 TTS POC 共 7 个版本验证失败：
- **RTF ≈ 0.85**（用户荣耀真机日志），句间卡顿不可消除
- **音质差强人意**，明显劣于系统 TTS / 云端 TTS

v1.16.0-alpha **彻底移除 SherpaOnnx**（包体 -164MB），改为**默认系统 TTS + 可选双云端 TTS**：
- **火山引擎（豆包语音）**：国内顶级中文音质，5 个预设声音
- **阿里云 Qwen/CosyVoice**：6 个预设声音 + 3 个模型可选
- 网络失败自动 fallback 系统 TTS + SnackBar 提示

## 架构（Hybrid Cloud Strategy）

```
┌─ ttsEngineProvider (StateNotifierProvider, persisted in SharedPreferences)
│   ├─ system (default) ──── FlutterTtsServiceImpl (desktop) / SelfBuiltTtsServiceImpl (Android)
│   ├─ volcengineCloud ──── VolcengineCloudTtsService (HTTP, base64 MP3)
│   └─ qwenCloud ────────── QwenCloudTtsService (HTTP, OSS URL + 二次 GET)
│
├─ ttsServiceProvider (Provider<TtsService>) watches engine pref + credentials FutureProvider
│
├─ ttsPlaybackControllerProvider (StateNotifierProvider<TtsPlaybackController>)
│   ├─ 订阅 service.state → 推进 queue
│   ├─ 订阅 service.error → 瞬时错误触发 fallbackHandler
│   └─ fallbackHandler → setEngine(system) + reportFallback → provider rebuild
│
└─ ttsFallbackProvider (StateNotifierProvider<TtsFallbackNotifier>)
    └─ TtsSettingsSection ref.listen → SnackBar
```

## 获取 API 凭证

### 火山引擎

1. 访问 https://console.volcengine.com/speech/service/8
2. 开通「语音合成」服务
3. 应用管理 → 创建应用 → 获取 **App ID** + **Access Token**
4. （声音列表参考 https://www.volcengine.com/docs/6561/1257584）

设置 → 朗读 → TTS 引擎选「火山引擎（云端）」→ 填 App ID + Access Token + 选声音 → 「测试连接」验证

### 阿里云 Qwen / CosyVoice

1. 访问 https://bailian.console.aliyun.com/ （百炼控制台）
2. API-KEY 管理 → 创建新 API Key
3. （模型列表参考 https://help.aliyun.com/zh/model-studio/cosyvoice-voice-list）

设置 → 朗读 → TTS 引擎选「阿里云 Qwen（云端）」→ 填 API Key + 选 Model + 选声音 → 「测试连接」验证

## 声音列表

### 火山引擎（5 个预设）

| Voice ID | 名称 | 性别 | 描述 |
|---|---|---|---|
| BV001_streaming | 通用女声 | 女 | 通用场景 |
| BV002_streaming | 通用男声 | 男 | 通用场景 |
| BV700_streaming | 灿灿 | 女 | 活泼女声 |
| BV701_streaming | 擎苍 | 男 | 沉稳男声 |
| BV705_streaming | 炉鼎 | 男 | 说书男声 |

### Qwen / CosyVoice（6 个预设）

| Voice ID | 名称 | 性别 | 描述 |
|---|---|---|---|
| longxiaoxia_v2 | 龙小夏 | 女 | 沉稳权威女 |
| longyichen | 龙逸尘 | 男 | 洒脱活力男 |
| longwanjun | 龙婉君 | 女 | 细腻柔声女 |
| longlaobo | 龙老伯 | 男 | 沧桑岁月爷 |
| longxiu_v2 | 龙修 | 男 | 博才说书男 |
| longbaizhi | 龙白芷 | 女 | 睿气旁白女 |

**Model 选项**：qwen-audio-3.0-tts-flash（默认，最快）/ qwen-audio-3.0-tts-plus（高质量）/ cosyvoice-v1

## Fallback 行为

云端 TTS 在以下情况**自动切换**至系统 TTS：
- 网络异常（network error）
- 服务端错误（server error, HTTP 5xx）
- 预取失败（prefetch-fail network/server）

**不触发 fallback**（需用户操作）：
- 认证失败（auth error, HTTP 401/403）→ 检查 API Key
- 配额超限（quota error, HTTP 429）→ 升级套餐或等待
- 请求无效（invalidRequest, HTTP 400）→ 反馈给开发者

Fallback 时弹 SnackBar `"⚠ <message>，已切换至系统 TTS"`（仅在设置页 mounted 时显示）。

## 测试步骤（用户）

### 测试 1：系统引擎回归（确保旧路径不破）

1. 装 v1.16.0-alpha APK
2. 设置 → 朗读 → TTS 引擎选「系统（默认）」
3. 选段朗读 → 应正常播放
4. 桌面端用 flutter_tts（SAPI / NSSpeechSynthesizer）
5. Android 端用自研 plugin

### 测试 2：火山引擎凭证流程

1. 设置 → 朗读 → 引擎切「火山引擎（云端）」
2. 下方出现「火山引擎凭证」表单（App ID + Access Token + 声音下拉）
3. 填入控制台获取的 App ID + Token
4. 点「测试连接」→ 弹 SnackBar `✓ 连接成功（XXXX bytes）`
5. 点「保存」→ SnackBar `已保存`
6. 完全关闭 app 重启
7. 选段朗读 → 应听到火山引擎声音

### 测试 3：Qwen 凭证流程

同测试 2，但选「阿里云 Qwen（云端）」+ API Key + Model + Voice

### 测试 4：多句平滑播放（核心痛点验证）

1. 选段 5+ 句朗读
2. **句间应无明显 gap**（HTTP prefetch 在 hintNext 时并行启动，下一句 audio 已缓存）
3. 设置 → 朗读 → 「TTS 调试日志」→ 看 prefetchHit > 0

### 测试 5：网络失败 fallback

1. 故意填错 Token，点测试连接 → SnackBar `✗ 失败: auth: ...`（不触发 fallback，因 auth 非瞬时）
2. 朗读时拔网线/关 WiFi → service.error 流发 network → fallbackHandler 触发 setEngine(system) → SnackBar `⚠ network: ...，已切换至系统 TTS`
3. 注意：fallback SnackBar 仅在设置页 mounted 时显示，朗读页不显示（v1.17 改进）

### 测试 6：包体验证

1. APK 大小应从 v1.15.6 的 264MB 降至 ~100MB（-60%+）
2. Windows installer 从 202MB 降至 ~50MB

## 升级路径

直接装 v1.16.0-alpha 覆盖 v1.15.x：

- **drift schema v15 不变**（无数据库迁移）
- **versionCode 2019** > v1.15.6 的 2018
- **旧 tts.engine=sherpaOnnxMelo 自动降级 system**（TtsEnginePreferenceX.fromPersistedValue 处理）
- **旧 secure_storage 中无云端凭证** → 默认 system 引擎

## Breaking Change

- **API**：所有 SherpaOnnx 相关 Dart 类移除（SherpaOnnxTtsService / SherpaOnnxAudioPlayer / sherpa_onnx_tts_benchmark）
- **配置**：`tts.engine=sherpaOnnxMelo` 持久化值自动降级 system
- **依赖**：移除 sherpa_onnx pub 依赖（Android JNI so + Windows DLL + 163MB 模型全删）
- **Android**：移除 `packaging { jniLibs { useLegacyPackaging = true } }`（SherpaOnnx JNI 解压 workaround）

## 已知限制 + v1.17 路线

- **Qwen API 二次 GET**：DashScope 返回 OSS URL 而非 base64 bytes，多 100-200ms 延迟。v1.17 切 WebSocket 流式。
- **Fallback SnackBar 仅设置页可见**：v1.17 移 listener 到 MaterialApp.router 根。
- **凭证不同步**：API key 走 WebDAV 风险太大，本机有效。
- **测试连接实例化临时 service**：每次点都新建 http.Client，可优化为复用。
- **`_VolcengineCredentialsForm` 用固定 volume=50**：v1.17 可加 volume 滑杆或注释说明 Qwen API 无客户端 volume 控制。
- **`audio['url'] as String?` 防御**：v1.17 改为 `if (url is! String || url.isEmpty)` 防 TypeError。
