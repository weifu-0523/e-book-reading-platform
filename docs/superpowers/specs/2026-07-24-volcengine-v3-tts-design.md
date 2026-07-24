# 豆包语音合成 V3 (HTTP SSE) 接入设计

**日期**：2026-07-24
**版本**：v1.16.1-alpha
**类型**：hotfix（火山引擎云端 TTS 协议升级 V1→V3）
**上一版本**：v1.16.0-alpha（2026-07-23）

## 背景

v1.16.0-alpha 实现的是火山引擎**老版语音合成 1.0** 接口：
- Endpoint: `https://openspeech.bytedance.com/api/v1/tts`
- Body: `app.cluster = "volcano_tts"`
- 认证: `Authorization: Bearer;<token>`

用户在火山引擎控制台开通的是**豆包语音合成模型 2.0**（APP ID `6885189822`），属于完全不同的产品线：

| 产品 | 控制台入口 | Endpoint | Resource |
|---|---|---|---|
| 语音合成标准版 1.0 | 语音技术 → 语音合成 | `/api/v1/tts` | `volc.tts.default` (cluster=`volcano_tts`) |
| 大模型语音合成 1.0 | 豆包语音 → 大模型 TTS | `/api/v1/tts` | `seed-tts-1.0` (cluster=`volcano_mega`) |
| **大模型语音合成 2.0** ← 用户买的 | 豆包语音 → 大模型 TTS | `/api/v3/tts/...` | `seed-tts-2.0` |

用户两次测试均失败：
1. 用 API Key（`api-key-20260724090012`）填 App ID/Token：HTTP 401 + `code 3001 "load grant: requested grant not found in SaaS storage"`（API Key 模式下访问 v1 endpoint 找不到 grant）
2. 用真实 App ID + Token：HTTP 403 + `code 3001 "[resource_id=volc.tts.default] requested resource not granted"`（账号没有 `volc.tts.default` 资源）

根因都是 resource 不匹配。本设计把 `VolcengineCloudTtsService` 从 V1 协议升级到 **V3 HTTP SSE 协议**。

## 目标

1. 让用户能用上已购买的豆包语音合成 2.0 资源（resource_id=`seed-tts-2.0`）
2. 不破坏 v1.16.0-alpha 已有的 `BaseCloudTtsService` 抽象 + prefetch cache + fallback 机制
3. 客户端 audio pipeline 不重写（仍 `audioplayers` 整段播）
4. UI 入口不变，用户凭证复用（无需重新填 App ID/Token）

## 非目标

- WebSocket 双向流式（v1.17+；电子书朗读场景低收益）
- 新版控制台 API Key 单字段模式（v1.17+；旧版 App ID + Token 已够用）
- Qwen V3 升级（用户未购买 Qwen 资源，无法真机验证）
- 中途插话/换句/实时吐字（电子书朗读场景不需要）
- 流式 audio buffer pipeline 重写（首句首音 1-2s 延迟可接受，句间 gap 已被 prefetch cache 解决）

## 决策

### D1: 协议 = V3 HTTP SSE 单向流式

**Endpoint**（待 task 1 fetch 官方文档确认具体路径）:
- 候选 A：`https://openspeech.bytedance.com/api/v3/tts/sse`
- 候选 B：`https://openspeech.bytedance.com/api/v3/tts/http_stream`
- 准确值以 [HTTP Chunked/SSE 单向流式-V3 文档 1598757](https://docs.volcengine.com/docs/6561/1598757) 为准

**为何不 WebSocket 双向流式**（用户初始偏好，经讨论后调整）：
- 句间 gap 已被 `BaseCloudTtsService.prefetch cache` 解决（v1.16.0-alpha 已验证）
- WebSocket 双向流式额外能力（中途取消/插话/换句）在电子书朗读场景**低频**
- 工作量：HTTP SSE ~1 天 vs WebSocket 双向 ~3-5 天
- 用户原话：「电子书阅读只是辅助，重要的还是阅读」—— TTS 不应消耗不成比例的工作量（见 [[feedback-tts-is-auxiliary]]）

**客户端模式**：
- HTTP `POST` + `Accept: text/event-stream`
- 收集所有 SSE `data:` chunks → base64 解码 → 拼成完整 `Uint8List`
- 给 `audioplayers` `BytesSource` 整段播（非真流式播放）
- 协议支持流式但客户端 buffer 完再播（first-byte 延迟仍 1-2s，可接受）

### D2: 认证 = 旧版控制台 App ID + Token

**Headers**（参考 [V3 单向流式文档 1719100](https://www.volcengine.com/docs/6561/1719100) + [HTTP SSE 文档 1598757](https://docs.volcengine.com/docs/6561/1598757)）：

```
Content-Type: application/json
X-Api-App-Id: 6885189822          ← 用户填的 "App ID" 字段
X-Api-Access-Key: <token>          ← 用户填的 "Access Token" 字段
X-Api-Resource-Id: seed-tts-2.0    ← 硬编码（豆包语音合成 2.0）
X-Api-Request-Id: <uuid v4>        ← 每次请求随机生成
```

**v1.16.0-alpha UI 字段语义映射**：
- "App ID" 字段值 → `X-Api-App-Id` header（语义不变，用户不重填）
- "Access Token" 字段值 → `X-Api-Access-Key` header（语义不变）
- "Voice" 下拉框值 → body 内 `voice_type`（值改：V1 的 `BV001_streaming` → V3 的 `zh_male_shenyeboke_moon_bigtts`）

**v1.17 路线**：增加 "API Key" 单字段模式（新版控制台），UI 让用户二选一。

### D3: 音色列表（8 个豆包 2.0 同款）

**约束**：所有音色必须带 `_bigtts` 后缀（2.0 专属）。混用 1.0 音色 + `seed-tts-2.0` 会触发 `code=55000000 "resource ID is mismatched with speaker related resource"`（参考 [skills.re doubao](https://skills.re/skills/vm0-ai/vm0-skills/doubao)）。

| 名称 | voice_type | 性别 | 适合场景 |
|---|---|---|---|
| 深夜播客 ⭐默认 | `zh_male_shenyeboke_moon_bigtts` | 男 | 长篇朗读 / 说书风格 |
| 婆婆 | `zh_female_popo_mars_bigtts` | 女 | 长者女声 |
| 高冷御姐 | `zh_female_gaolengyujie_moon_bigtts` | 女 | 沉稳女声 |
| 傲娇霸总 | `zh_male_aojiaobazong_moon_bigtts` | 男 | 沉稳男声 |
| 魅力女友 | `zh_female_meilinvyou_moon_bigtts` | 女 | 甜美女声 |
| 开朗弟弟 | `zh_male_livelybro_mars_bigtts` | 男 | 活泼男声 |
| 东方浩然 | `zh_male_dongfanghaoran_moon_bigtts` | 男 | 浑厚男声 |
| 直率英子 | `zh_female_naying_mars_bigtts` | 女 | 直率女声 |

来源：[音色列表官方文档 1257544](https://www.volcengine.com/docs/6561/1257544) 筛选「豆包同款」标记的音色。

### D4: 架构 = 替换 volcengineCloud 内部实现

**TtsEnginePreference enum 不动**：
- `system` / `volcengineCloud` / `qwenCloud` 三选一不变
- 持久化值 `tts.engine = "volcengineCloud"` 不变
- UI 入口不变（用户感知不到内部协议切换）

**VolcengineCloudTtsService 重写**（核心改动）：

| 字段/方法 | v1.16.0-alpha (V1) | v1.16.1-alpha (V3) |
|---|---|---|
| `_endpoint` | `/api/v1/tts` | `/api/v3/tts/sse` (待 task 1 确认) |
| 认证 header | `Authorization: Bearer;<token>` | `X-Api-App-Id` + `X-Api-Access-Key` + `X-Api-Resource-Id: seed-tts-2.0` + `X-Api-Request-Id: <uuid>` |
| 请求体 | `app.{appid,token,cluster=volcano_tts}` + `user.uid` + `audio.{voice_type,speed_ratio,encoding,rate}` + `request.{reqid,text,operation=query}` | V3 schema（task 1 fetch 文档确认；大概率是 `user.uid` + `req_params.{text, audio_params.{voice_type,speed_ratio<改格式>,encoding,rate}}`） |
| 响应解析 | `JSON { code: 3000, data: <base64 mp3> }` 一次性返回 | SSE event stream：多个 `data: <base64>` chunk + 终止 signal |
| `supportedVoices` | 5 个 V1 音色（`BV001_streaming` 等） | 8 个 V3 `_bigtts` 音色 |
| `_mapRate` | `[-1,1] → [0.5,2.0]`（speed_ratio 直接乘） | `[-1,1] → [-50,100]`（V3 speech_rate 整数范围，待确认） |
| `defaultVoice` | `BV001_streaming` | `zh_male_shenyeboke_moon_bigtts` |

**VolcengineTtsCredentials 不动**：
- 字段 `appId` + `accessToken` 保留（语义不变）
- `defaultVoice` 改为 V3 默认音色
- `fromJson` / `toJson` 兼容（用户已保存的凭证无缝迁移）

### D5: Qwen 不动

- `QwenCloudTtsService`（V1）代码保留，UI 入口不变
- 用户持久化的 `tts.qwen.*` 凭证不变
- v1.17 升级到 Qwen V3

### D6: Fallback 沿用

- `TtsFallbackNotifier` 不动
- 网络失败 / 服务端错误 → 系统 TTS
- 错误分类（`CloudTtsErrorKind`：network/auth/quota/server/invalidRequest）沿用
- `ttsPlaybackControllerProvider._onServiceError` 按消息前缀过滤瞬时错误的逻辑不变

### D7: 测试策略

**单元测试**（用 v1.16.0-alpha 的 `MockClient` pattern）：
- `volcengine_cloud_tts_service_test.dart` **重写**：
  - 认证头正确性（4 个 headers + Request-Id 是 UUID v4）
  - SSE event 解析（multi-event + termination + error event）
  - 错误处理（HTTP 401/403/429/5xx + `code=55000000` resource mismatch）
  - prefetch cache 命中/失效（rate 变化清缓存沿用 v1.13.10 Bug 1 教训）
- `voice_preset_test.dart` 更新：8 个新音色 + 默认值断言
- `cloud_tts_credentials_test.dart` 更新：V3 默认音色 + 向后兼容（旧 V1 音色降级）

**Widget test**：
- `tts_settings_section_test.dart` 更新：volcengine 引擎选时表单字段不变（用户凭证复用验证）

**集成测试**（用户真机）：
- App ID `6885189822` + Token → 「测试连接」成功
- 选段朗读 5+ 句 → 句间无明显 gap（验证 prefetch cache 仍工作）
- 切换音色 → 立即生效（cache 失效正确）

## 文件影响

### 修改（核心）

- `app/lib/services/tts/volcengine_cloud_tts_service.dart` — V3 协议重写（endpoint + headers + body + response parsing）
- `app/lib/services/tts/cloud_tts_credentials.dart` — `VolcengineTtsCredentials.defaultVoice` 改为 `zh_male_shenyeboke_moon_bigtts`
- `app/lib/services/tts/voice_preset.dart` — `CloudTtsVoicePresets.volcengine` 改为 8 个新音色

### 修改（测试）

- `app/test/features/tts/services/volcengine_cloud_tts_service_test.dart` — 重写所有测试用例（V3 endpoint + headers + SSE parsing）
- `app/test/features/tts/services/voice_preset_test.dart` — 更新音色断言（8 个 `_bigtts` 音色）
- `app/test/services/tts/cloud_tts_credentials_test.dart` — 更新 `defaultVoice` 断言 + 向后兼容测试（V1 音色降级）
- `app/test/features/settings/pages/tts_settings_section_test.dart` — 验证 UI 字段兼容（用户凭证复用）

### 文档

- `CHANGELOG.md` — v1.16.1-alpha entry（CRLF binary-safe Python）
- `docs/releases/release-notes-v1.16.1-alpha.md` — 新建
- `app/pubspec.yaml` — version `1.16.0-alpha+2019` → `1.16.1-alpha+2020`
- `app/windows/installer/zhiyue.iss` — `MyAppVersion "1.16.0-alpha"` → `"1.16.1-alpha"`

### 不动（关键）

- `app/lib/services/tts/base_cloud_tts_service.dart` — 抽象基类（prefetch cache + roughEqual + 5 类错误）
- `app/lib/services/tts/cloud_tts_exception.dart` — `CloudTtsErrorKind` 枚举
- `app/lib/services/tts/tts_service_factory.dart` — 工厂分发
- `app/lib/features/tts/providers/tts_fallback_notifier.dart`
- `app/lib/features/tts/providers/tts_playback_controller.dart`
- `app/lib/features/tts/providers/cloud_tts_credentials_providers.dart`
- `app/lib/features/settings/pages/tts_settings_section.dart` — UI 完全不动
- `app/lib/services/tts/qwen_cloud_tts_service.dart` — Qwen V1 保留
- 所有 system TTS / Android 自研 plugin 代码

## 实现不确定项（task 1 fetch 官方文档确认）

1. **HTTP SSE 具体 endpoint 路径**：候选 `/api/v3/tts/sse` 或 `/api/v3/tts/http_stream`，准确值以文档 [1598757](https://docs.volcengine.com/docs/6561/1598757) 为准
2. **请求体 JSON schema**：参考 V3 单向流式文档 [1719100](https://www.volcengine.com/docs/6561/1719100)，预计字段：
   - `user.uid`
   - `req_params.text`
   - `req_params.audio_params.{voice_type, speed_ratio, encoding, rate}`
3. **SSE event 格式**：
   - 选项 A：`data: <base64-encoded-mp3-chunk>\n\n`（每个 event 一个 chunk）+ 终止 `data: [DONE]\n\n`
   - 选项 B：`event: audio\ndata: <base64>\n\n` + 终止 `event: done\ndata: {}\n\n`
   - 选项 C：JSON 行流（每行一个 JSON 对象，含 `audio_chunk` 字段）
4. **`speed_ratio` 范围**：V1 文档说 `[0.5, 2.0]`，V3 可能是 `[-50, 100]`（参考端到端实时大模型 `speech_rate`）
5. **错误响应格式**：HTTP 非 200 时 body 是 JSON 还是 SSE error event
6. **`X-Api-Request-Id` 是否必需**：官方文档列为「可选」，但 [Raycast Doubao TTS](https://www.raycast.com/xianwei_zhang/doubao-tts) 实践说「always set」

## 验收

1. ✅ `dart analyze lib/services/tts lib/features/tts lib/features/settings` 无 error
2. ✅ `flutter test test/features/tts/ test/features/settings/` 全部 pass（含新 SSE 解析测试）
3. ✅ APK 构建 marker 验证（搜 `seed-tts-2.0` / `zh_male_shenyeboke_moon_bigtts` / `X-Api-Resource-Id`）
4. ✅ Windows installer 重建（无新依赖，包体不变）
5. ✅ 用户真机测试：
   - App ID `6885189822` + Token → 「测试连接」成功（返回 MP3 bytes > 0）
   - 选段朗读 5+ 句 → 句间无明显 gap（prefetch cache 工作）
   - 切换音色 → 立即生效（cache 失效正确）
   - 关网 → 触发 fallback 到 system TTS（SnackBar 提示）

## 风险

| 风险 | 等级 | Mitigation |
|---|---|---|
| HTTP SSE endpoint URL 猜错 | 中 | task 1 先 fetch 官方文档 1598757 + 1719100 确认 |
| SSE event 格式不一致 | 中 | task 实现时打印 raw response body，肉眼分析格式后再写 parser |
| 请求体 schema 不对 | 中 | task 1 fetch 时同时拿 Python 示例代码对照 |
| 2.0 音色 voice_type 字符串版本演进 | 低 | task 1 同时 fetch 音色列表官方文档 1257544；保留 fallback 默认音色 |
| 用户已购买的 2.0 资源包不含我们选的某些音色 | 低 | 用户测试连接 + 试听验证；音色失败时 SnackBar 提示「资源未授权，换音色」|
| `audioplayers` 处理 MP3 bytes 流式拼接问题 | 低 | 仍是整段 bytes 一次性给 BytesSource，跟 v1.16.0-alpha 一致 |
| 用户旧持久化的 V1 音色（`BV001_streaming`）失效 | 低 | `CloudTtsVoicePresets.find` 找不到时降级默认音色 |

## 升级路径（用户侧）

直接装 v1.16.1-alpha 覆盖 v1.16.0-alpha：

- **drift schema v15 不变**（无数据库迁移）
- **versionCode 2020** > v1.16.0-alpha 的 2019
- **用户持久化 `tts.engine="volcengineCloud"` 不变**（直接复用）
- **用户持久化 `tts.volcengine.appId` + `tts.volcengine.accessToken` 不变**（语义不变）
- **用户持久化 `tts.volcengine.voice` 若是 V1 音色**（如 `BV001_streaming`）→ 自动降级到默认 `zh_male_shenyeboke_moon_bigtts`（`CloudTtsVoicePresets.find` 找不到时）

## Breaking Change

- **协议**：火山引擎云端 TTS 从 V1 升级到 V3 HTTP SSE（内部实现细节，用户不感知）
- **音色列表**：5 个 V1 音色（`BV001_streaming` 等）→ 8 个 V3 `_bigtts` 音色。用户已选音色若是 V1 会自动降级默认。
- **资源要求**：用户必须开通**豆包语音合成 2.0**（resource `seed-tts-2.0`），不再是「语音合成标准版 1.0」。

## 后续路线（v1.17+）

- 新版控制台 API Key 单字段认证（`X-Api-Key`）
- Qwen V3 升级
- WebSocket 双向流式（如果用户反馈首句延迟成问题，或需要朗读中途取消）
- 用户界面音色分组（按性别/风格/方言/情感）
- 服务端事件 log 收集（`X-Tt-Logid` response header 用于厂商支持工单）

## 参考

- [HTTP Chunked/SSE 单向流式-V3 文档 1598757](https://docs.volcengine.com/docs/6561/1598757)
- [WebSocket 单向流式-V3 文档 1719100](https://www.volcengine.com/docs/6561/1719100)
- [WebSocket 双向流式-V3 文档 1329505](https://www.volcengine.com/docs/6561/1329505)
- [音色列表官方文档 1257544](https://www.volcengine.com/docs/6561/1257544)
- [产品简介 1257543](https://www.volcengine.com/docs/6561/1257543)
- [模型列表 2499930](https://www.volcengine.com/docs/6561/2499930)
- [API 接入 FAQ 111586](https://www.volcengine.com/docs/6561/111586)
- [GitHub Issue #4709 new-api V3 protocols table](https://github.com/QuantumNous/new-api/issues/4709)
- [skills.re doubao connector](https://skills.re/skills/vm0-ai/vm0-skills/doubao)
- [Raycast Doubao TTS（实践参考）](https://www.raycast.com/xianwei_zhang/doubao-tts)

相关 memory：[[project_zhiyue_2026_07_23_v1_16_tts_hybrid_cloud]]（前一版本基础）/ [[feedback_tts_is_auxiliary]]（设计原则）/ [[feedback_flutter_strip_cache_trap]]（发布流程）
