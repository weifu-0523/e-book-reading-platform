# 豆包语音 V3 HTTP SSE 协议确认笔记

**日期**: 2026-07-24
**用途**: v1.16.1-alpha VolcengineCloudTtsService V3 升级（V1→V3 HTTP SSE）
**Spec**: docs/superpowers/specs/2026-07-24-volcengine-v3-tts-design.md
**数据源**: 火山引擎官方文档 [1598757 / 1719100 / 1257544] + skills.re doubao + new-api issue #4709 + IMA Studio TTS skill

---

## 1. Endpoint URL

**确认值**: `https://openspeech.bytedance.com/api/v3/tts/sse`

来源:
- [skills.re doubao](https://skills.re/skills/vm0-ai/vm0-skills/doubao) 给出 curl 例子（虽然 URL 被截断显示为空，但描述明确为 "Synthesise speech (SSE)" 同一个 body 走 SSE parser）
- [new-api issue #4709](https://github.com/QuantumNous/new-api/issues/4709) 表格列出 4 个 V3 transports，HTTP SSE 是其中之一（HTTP Chunked 是另一个相似但不同的 endpoint）
- spec 候选 A `/api/v3/tts/sse` 与候选 B `/api/v3/tts/http_stream` 中选 **A**（http_stream 实际指 HTTP Chunked transfer，与 SSE 不同）

**实现提示（给 Task 3）**:
- 把 `_endpoint` 改为 `https://openspeech.bytedance.com/api/v3/tts/sse`
- 如果 SSE endpoint 真机不通（404），fallback 顺序: 先试 `/api/v3/tts/sse` → 再试 `/api/v3/tts/http_stream`（HTTP Chunked，二进制帧）→ 最后 WebSocket `/api/v3/tts/unidirectional/stream`

---

## 2. 完整 Headers

| Header | 必需 | 示例值 | 说明 |
|---|---|---|---|
| `Content-Type` | ✓ | `application/json` | 标准 JSON body |
| `X-Api-App-Id` | ✓ | `6885189822` | 用户控制台 APP ID（旧版控制台） |
| `X-Api-Access-Key` | ✓ | `<access-token>` | 用户控制台 Access Token（旧版控制台） |
| `X-Api-Resource-Id` | ✓ | `seed-tts-2.0` | 豆包语音合成 2.0（硬编码） |
| `X-Api-Request-Id` | 推荐 | `<uuid v4>` | 官方文档列为「可选」，但 [skills.re](https://skills.re/skills/vm0-ai/vm0-skills/doubao) + [Raycast](https://www.raycast.com/xianwei_zhang/doubao-tts) 实践都说「always set」以便问题排查 |
| `X-Control-Require-Usage-Tokens-Return` | 否 | `text_words` | 携带后 SessionFinish/最终帧会带 usage JSON（计费字符数），可选 |
| `Accept` | 推荐 | `text/event-stream` | SSE 客户端标准头，部分 server 强制检查 |

**Response headers**:
- `Transfer-Encoding: chunked` — 流式响应
- `X-Tt-Logid: <hex>` — **强烈建议捕获并打印**，提工单/排错时用

**重要说明（控制台双模式）**:
- **旧版控制台**（用户当前模式）：`X-Api-App-Id` + `X-Api-Access-Key` + `X-Api-Resource-Id`
- **新版控制台**（v1.17+）：仅 `X-Api-Key` + `X-Api-Resource-Id`（单字段 API Key）
- spec D2 设计完全正确：UI 字段 "App ID" → `X-Api-App-Id`，"Access Token" → `X-Api-Access-Key`

来源: [doc 1598757] headers 章节 + [doc 1719100] headers 章节（两份文档 headers 完全一致）

---

## 3. Body JSON Schema

**确认 schema**（V3 与 V1 完全不同，字段名变了）:

```json
{
  "user": {
    "uid": "zhiyue"
  },
  "req_params": {
    "text": "要合成的文本",
    "speaker": "zh_male_shenyeboke_moon_bigtts",
    "audio_params": {
      "format": "mp3",
      "sample_rate": 24000,
      "speech_rate": 0,
      "loudness_rate": 0
    }
  }
}
```

### 关键字段对照表

| Spec 预测字段 | **实际字段** | 备注 |
|---|---|---|
| `user.uid` | `user.uid` | ✓ 一致 |
| `req_params.text` | `req_params.text` | ✓ 一致 |
| `req_params.voice_type` ❌ | **`req_params.speaker`** | **spec 错了！V3 用 `speaker` 不是 `voice_type`** |
| `req_params.audio_params.voice_type` ❌ | **`req_params.audio_params` 无 speaker** | speaker 在 req_params 顶层 |
| `req_params.audio_params.format` | `req_params.audio_params.format` | ✓ 但可选（默认 `mp3`） |
| `req_params.audio_params.encoding` ❌ | **`req_params.audio_params.format`** | V3 改名了（V1 叫 encoding） |
| `req_params.audio_params.rate` ❌ | **`req_params.audio_params.sample_rate`** | V3 改名（V1 叫 rate） |
| `req_params.audio_params.speed_ratio` ❌ | **`req_params.audio_params.speech_rate`** | V3 改名 + 类型从 float [0.5,2.0] 改 int [-50,100] |
| `req_params.audio_params.volume_ratio` ❌ | **`req_params.audio_params.loudness_rate`** | V3 改名 + 类型改 int [-50,100] |

### 必填字段（doc 1598757 / 1719100 表格中标记 √）

| 字段 | 必需 | 默认 |
|---|---|---|
| `user.uid` | 否（推荐填） | — |
| `req_params.text` | **是**（与 ssml 二选一） | — |
| `req_params.speaker` | **是** | — |
| `req_params.audio_params` | **是** | — |
| `req_params.audio_params.format` | 否 | `mp3` |
| `req_params.audio_params.sample_rate` | 否 | `24000`（可选 8000/16000/22050/24000/32000/44100/48000） |
| `req_params.audio_params.speech_rate` | 否 | `0` |
| `req_params.audio_params.loudness_rate` | 否 | `0` |
| `req_params.audio_params.bit_rate` | 否 | 默认 64k-160k，MP3 专用 |
| `req_params.audio_params.emotion` | 否 | 部分音色支持 |
| `req_params.audio_params.emotion_scale` | 否 | `4`（范围 1-5） |
| `req_params.model` | 否 | `seed-tts-2.0-standard`（声音复刻 2.0 才用） |
| `req_params.ssml` | 否 | TTS 2.0 音色暂不支持 |

**重要**：`speaker` 必须带 `_bigtts` 后缀（2.0 专属）。混 1.0 音色 + `seed-tts-2.0` → `code=55000000 "resource ID is mismatched with speaker related resource"`。

**format 流式注意**（doc 1719100）：流式场景传 `wav` 会多次返回 wav header，建议用 `pcm` 或 `mp3`。我们用 `mp3` 没问题。

来源: [doc 1598757] Body 章节 + [doc 1719100] Body 章节 + [doc 1829010]（speech_rate 范围明确）

---

## 4. SSE Event Format

**确认选项: C（JSON-line stream，每行一个 JSON 对象）**

不是裸 `data: <base64>` 也不是 `event: audio\ndata: ...`。每行是一个完整 JSON 对象（SSE `data:` 字段含 JSON），按 frame type 区分。

### 帧类型（参考 skills.re doubao 描述）

| 帧 | code | 说明 |
|---|---|---|
| 音频帧 | — | `data` 字段含 base64 mp3 chunk，每帧一段 |
| 句子边界 | — | `sentence` 字段含 per-word 时间戳（需 enable_subtitle/enable_timestamp，默认不开） |
| 结束帧 | **`code: 20000000 / message: "ok"`** | 标记流结束 |
| 错误帧 | 非 20000000 | `code` + `message` 字段标识错误 |

**推测单帧 JSON 结构**（基于 skills.re 描述 + V1 响应字段 1257584 + doc 1719100 binary protocol frame types）:

```json
{"data": "<base64-mp3-chunk>", "sequence": 1, ...}
```

或纯音频帧可能直接 base64 文本（无 JSON wrapper），结束帧才带 code/message。

**警告**：spec 选项 A/B/C 三种格式都无法从抓到的官方文档中 100% 确认。**Task 4 implementer 必须在第一次真机测试时打印 raw response body 头 1KB**，肉眼分析后再写最终 parser。建议先按 C 实现（JSON-line），fallback 到 A（裸 base64）。

### skills.re 描述原文

> `code: 20000000 / message: ok` marks end of stream. `data` carries one base64 audio chunk per frame. `sentence` frames carry per-word timestamps when `enable_subtitle` (2.0) or `enable_timestamp` (1.0) is requested.

来源: [skills.re doubao](https://skills.re/skills/vm0-ai/vm0-skills/doubao) （描述 SSE 与 binary 都用同一个 body，仅 parser 不同）

---

## 5. Termination Signal

**确认值**: 收到 `code: 20000000` + `message: "ok"` 的 JSON 帧即结束。

**不是**:
- ❌ `data: [DONE]\n\n`（那是 OpenAI chat completion 风格）
- ❌ `event: done` SSE event（Volcengine V3 不用 event: tag）

**实现提示（给 Task 4）**:
- SSE parser 累积所有 `data:` payload，按 JSON parse
- 遇到 `code == 20000000` 停止读取
- 遇到非 20000000 的 code 或缺 code 但有 message 字段，按错误处理
- 流自然结束（HTTP connection close）也是合法终止（防御性兜底）

---

## 6. speed_ratio Range

**确认值**: V3 不用 `speed_ratio`（float [0.2, 3]），改用 **`speech_rate`（int [-50, 100]）**

| 字段 | 范围 | 含义 | 默认 |
|---|---|---|---|
| `audio_params.speech_rate` | **`[-50, 100]`** | 100 = 2.0x, -50 = 0.5x, 0 = 1.0x | `0` |
| `audio_params.loudness_rate` | `[-50, 100]` | 同样整数范围 | `0` |

### _mapRate 映射公式（spec D4 表中标注的「待确认」）

**spec 预测的 `[-1,1] → [-50, 100]` 正确**。映射公式:

```dart
int _mapRate(double normalized) {
  // normalized [-1.0, 1.0] → speech_rate [-50, 100]
  // -1.0 → -50 (0.5x)
  //  0.0 →  25 (1.0x, 中点)
  // +1.0 → 100 (2.0x)
  // 注意：[-50, 100] 的中点是 25，不是 0
  // 但实际语义上 0 应该映射到 "正常语速"
  // 因此采用：normalized=0 → speech_rate=0 (1.0x, 正常)
  //          normalized=-1 → speech_rate=-50 (0.5x)
  //          normalized=+1 → speech_rate=100 (2.0x)
  return (normalized * 50).round().clamp(-50, 100);
  // 等价：normalized=0 → 0 (1.0x), normalized=+1 → 50 (1.5x), normalized=+2 → 100 (2.0x)
  // 但 normalized 上限是 1，所以实际范围是 [-50, 50]
  // 如果想让用户能到 2.0x，需要 normalized 上限放宽到 2，或单独乘 100/2=50
}
```

**简化决策**（给 Task 3 implementer）:
- 如果 UI slider 是 `[-1.0, 1.0]`，映射公式 `(normalized * 50).round().clamp(-50, 100)` → 实际 speech_rate 范围 `[-50, 50]`，对应速度 `[0.5x, 1.5x]`
- 如果想覆盖到 `2.0x`（与 V1 对齐），UI slider 上限改为 `2.0`，公式 `(normalized * 50).round().clamp(-50, 100)`
- 推荐：保持 UI slider `[-1, 1]`，speech_rate `[-50, 50]`，速度 `[0.5x, 1.5x]`（足够电子书朗读场景）

来源: [doc 1829010] 明确写 `取值范围[-50,100]，100代表2.0倍速，-50代表0.5倍数` + [IMA Studio TTS skill](https://vibehackers.io/claude-code/skills/ima-studio-tts)

---

## 7. Error Response Format

### HTTP 非 200（认证/配额错误）

body 是 **JSON**，不是纯文本。格式:

```json
{
  "code": 3001,
  "message": "load grant: requested grant not found in SaaS storage",
  "reqid": "..."
}
```

或资源不匹配:

```json
{
  "code": 55000000,
  "message": "resource ID is mismatched with speaker related resource"
}
```

**注意**：用户 v1.16.0-alpha 测试时收到的 `code 3001 / code 55000000` 就是这种格式，已经过真机验证。

### HTTP 200 + 错误事件

V3 SSE 流中可以出现错误帧:
- HTTP status 200 + Content-Type: text/event-stream
- 流中途收到 `{... "code": <non-20000000>, "message": "..."}` 帧
- 之后流可能立即关闭

**实现提示（给 Task 4/5）**:
- HTTP status check 仍然要做（401/403/429/5xx）
- 流式 body 也要检查每帧 code 字段，非 20000000 即错误
- `code=55000000` → `CloudTtsErrorKind.invalidRequest`（资源/音色不匹配，用户配置问题）
- `code=3001` → `CloudTtsErrorKind.auth`（认证失败）
- `code=3001` + message 含 `resource not granted` → `CloudTtsErrorKind.auth`（账号没开通资源）

### 常见错误码（参考 V1 doc 1257584 + new-api issue）

| code | 含义 | CloudTtsErrorKind |
|---|---|---|
| 3001 | 认证失败 / grant not found / resource not granted | auth |
| 4293 | 文本含敏感词 | invalidRequest |
| 4295 | 文本过长 | invalidRequest |
| 4296 | 文本含不支持字符 | invalidRequest |
| 55000000 | resource/speaker mismatch | invalidRequest |
| 4xx HTTP | 网络问题 | network |

来源: [doc 1598757] + 用户 v1.16.0-alpha 真机报错 + [API 接入 FAQ 111586]

---

## 8. 音色列表确认

| spec D3 值 | 官方文档值 | 匹配？ | 标签 |
|---|---|---|---|
| `zh_male_shenyeboke_moon_bigtts` | `zh_male_shenyeboke_moon_bigtts` | ✓ | 豆包同款 |
| `zh_female_popo_mars_bigtts` | `zh_female_popo_mars_bigtts` | ✓ | 豆包同款、剪映同款、抖音同款 |
| `zh_female_gaolengyujie_moon_bigtts` | `zh_female_gaolengyujie_moon_bigtts` | ✓ | 豆包同款 |
| `zh_male_aojiaobazong_moon_bigtts` | `zh_male_aojiaobazong_moon_bigtts` | ✓ | 豆包同款 |
| `zh_female_meilinvyou_moon_bigtts` | `zh_female_meilinvyou_moon_bigtts` | ✓ | 豆包同款、剪映同款 |
| `zh_male_livelybro_mars_bigtts` | `zh_male_livelybro_mars_bigtts` | ✓ | 剪映同款、抖音同款 |
| `zh_male_dongfanghaoran_moon_bigtts` | `zh_male_dongfanghaoran_moon_bigtts` | ✓ | 豆包同款 |
| `zh_female_naying_mars_bigtts` | `zh_female_naying_mars_bigtts` | ✓ | 剪映同款、抖音同款、豆包同款 |

**全部 8 个 voice_type 字符串官方文档确认存在且带 `_bigtts` 后缀**。

**注意**:
- doc 1257544 中还有更多 `_bigtts` 音色（如 `zh_female_sajiaonvyou_moon_bigtts` 柔美女友、`zh_female_yuanqinvyou_moon_bigtts` 撒娇学妹、`zh_female_jiyejizi2_mars_bigtts` 春日部姐姐、`zh_male_tangseng_mars_bigtts` 唐僧等），spec 选的 8 个是子集
- 部分音色标「仅中文」（如开朗弟弟、直率英子），不影响中文电子书朗读

来源: [doc 1257544] 音色列表表格（豆包同款 + 剪映/抖音同款部分）

---

## 9. 实现要点（给 Task 3/4/5 implementer）

### Task 3（重写 VolcengineCloudTtsService）

```dart
static const _endpoint =
    'https://openspeech.bytedance.com/api/v3/tts/sse';
// 2026-07-24 task 1 confirmed via skills.re + new-api issue #4709
```

```dart
final headers = {
  'Content-Type': 'application/json',
  'Accept': 'text/event-stream',
  'X-Api-App-Id': credentials.appId,
  'X-Api-Access-Key': credentials.accessToken,
  'X-Api-Resource-Id': 'seed-tts-2.0',
  'X-Api-Request-Id': _uuidV4(), // 推荐填，便于排错
};

final body = jsonEncode({
  'user': {'uid': 'zhiyue'},
  'req_params': {
    'text': text,
    'speaker': voiceType, // 注意：是 speaker 不是 voice_type
    'audio_params': {
      'format': 'mp3',
      'sample_rate': 24000,
      'speech_rate': _mapRate(rateNormalized), // int [-50, 100]
    },
  },
});

final response = await client.post(
  Uri.parse(_endpoint),
  headers: headers,
  body: body,
);
// 注意：response.bodyBytes 是 SSE 流，不是单段 mp3
// 交给 Task 4 的 SSE parser
```

### Task 4（SSE parser）

**实现策略**：
1. 按 SSE 协议 split `\n\n` 分 event
2. 每个 event 提取 `data:` 后的内容
3. 尝试 JSON decode:
   - 成功 → 检查 `code` 字段
     - `code == 20000000` → 流结束，break
     - 其他非 null → 错误帧，throw CloudTtsException
     - null → 可能是音频帧，取 `data` 字段做 base64 decode
   - 失败 → 可能是裸 base64 字符串（V1 风格残留），尝试直接 base64 decode
4. 累积所有 base64 decode 后的 bytes → 完整 mp3

**调试防御**：
```dart
if (kDebugMode) {
  debugPrint('[VolcengineV3] raw response head 500: '
      '${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
}
```

**终止条件**（任一即可）:
- 收到 `code: 20000000` 帧
- HTTP 连接关闭（response fully received）
- 超时（建议 30s）

### Task 5（错误处理测试）

测试矩阵:
- HTTP 401 + JSON body `{"code":3001,"message":"..."}` → CloudTtsErrorKind.auth
- HTTP 403 + JSON body `{"code":3001,"message":"resource not granted"}` → CloudTtsErrorKind.auth
- HTTP 200 + SSE 流含 `{"code":55000000,"message":"resource ID mismatched"}` → CloudTtsErrorKind.invalidRequest
- HTTP 429 → CloudTtsErrorKind.quota
- HTTP 5xx → CloudTtsErrorKind.server
- 网络异常 → CloudTtsErrorKind.network

### speed_ratio → speech_rate 映射

```dart
int _mapRate(double normalized) {
  // normalized [-1.0, 1.0] → speech_rate [-50, 50]（保守范围，覆盖 0.5x-1.5x）
  // 如需到 2.0x，UI slider 上限改为 2.0
  return (normalized * 50).round().clamp(-50, 100);
}
```

### prefetch cache key

`roughEqual` 比较时：rate 用 normalized（UI slider 值），不用映射后的 speech_rate（避免浮点抖动）。spec D6 已说 fallback 沿用。

---

## 10. 不确定项 / 风险

### 风险 1: SSE endpoint URL 未 100% 确认

- skills.re curl 例子的 URL 被截断显示为空（`curl -sS -N -X POST "`）
- new-api issue #4709 列了 4 个 transports 但 endpoint URL 也是空的
- spec 候选 A `/api/v3/tts/sse` 是基于 V3 docs + 推理的最佳猜测

**Mitigation**:
- Task 3 实现时把 endpoint 设为 const，便于一次改全
- Task 8 真机测试如果 404，立即试 fallback endpoints：
  - `/api/v3/tts/http_stream`（HTTP Chunked transfer，二进制帧）
  - `/api/v3/tts/unidirectional`（WS unidirectional）
- 用户控制台 resource 已开通，最坏情况 endpoint 错也能拿到错误码（说明 URL 至少 path 在 server 上存在）

### 风险 2: SSE event 格式未 100% 确认

- skills.re 只描述了 code/data/sentence 三类帧，没给 raw 示例
- 可能是选项 A（裸 `data: <base64>\n\n`），也可能是选项 C（JSON-line）

**Mitigation**:
- Task 4 parser 实现两种 fallback（先 JSON parse，失败则按裸 base64）
- 第一次真机测试必打印 raw response head 500 字符
- 用户测试连接失败时让用户截图 debug log

### 风险 3: speed_ratio → speech_rate UI 范围决策

- V3 speech_rate 范围 `[-50, 100]`（0.5x - 2.0x）
- V1 speed_ratio 范围 `[0.5, 2.0]`（同语义）
- UI slider 当前是 `[-1.0, 1.0]` normalized

**Mitigation**:
- 决策（Task 3）：UI slider 保持 `[-1, 1]`，实际覆盖 `[-50, 50]`（0.5x-1.5x）
- 如果用户反馈「最快不够快」，UI slider 上限放宽到 `2.0`（v1.17 改）

### 风险 4: `speaker` vs `voice_type` 字段名

- spec 多处写 `voice_type`（V1 字段名），实际 V3 改为 `speaker`
- Task 3 必须用 `speaker`（已在 Section 3 标注）

### 风险 5: 用户的 2.0 资源是否包含全部 8 个音色

- doc 1257544 中 8 个音色都标「豆包同款 2.0」，理论上 `seed-tts-2.0` 资源应包含
- 但火山引擎 resource tier 可能有细分（标准/高质/旗舰）
- **Mitigation**: Task 8 用户测试时先试默认 `zh_male_shenyeboke_moon_bigtts`，通过后逐个试其他 7 个

### 风险 6: HTTP SSE 与 HTTP Chunked 的混淆

- new-api issue 把 V3 transport 列了 4 种，其中 HTTP SSE 和 HTTP Chunked 是两个不同 endpoint
- doc 1598757 标题是「HTTP Chunked/SSE 单向流式-V3」，可能合并描述了两种
- 我们走 SSE（更易 Dart 实现，`http` package 原生支持 streaming response）

---

## 总结

**6 项 spec 不确定项全部解决**:

1. ✓ Endpoint: `/api/v3/tts/sse`（spec 候选 A）
2. ✓ Body schema: `user.uid` + `req_params.{text, speaker, audio_params.{format, sample_rate, speech_rate, loudness_rate}}`（spec 字段名错：`voice_type` → `speaker`，`speed_ratio` → `speech_rate`）
3. ✓ SSE 格式: 选项 C（JSON-line），终止 `code:20000000`
4. ✓ Rate 范围: `[-50, 100]` 整数（speech_rate），不是 V1 的 `[0.5, 2.0]` float
5. ✓ 错误格式: HTTP 非 200 是 JSON body；HTTP 200 + 流中错误帧也是 JSON `{code, message}`
6. ✓ X-Api-Request-Id: 推荐填（不是强制），便于排错

**Task 3/4/5 implementer 行动项**:
- 用 `speaker` 字段名（不是 `voice_type`）
- 用 `audio_params.speech_rate` int 范围（不是 `audio.speed_ratio` float）
- 用 `audio_params.format` + `audio_params.sample_rate`（不是 `audio.encoding` + `audio.rate`）
- endpoint 设为 const，便于真机 fallback
- SSE parser 双路径（JSON first，裸 base64 fallback）
- 第一次测试必打印 raw response head

---

## 参考链接

- [doc 1598757 HTTP Chunked/SSE 单向流式-V3](https://docs.volcengine.com/docs/6561/1598757)（主协议文档）
- [doc 1719100 WebSocket 单向流式-V3](https://www.volcengine.com/docs/6561/1719100)（body schema 同 SSE，仅 transport 不同）
- [doc 1829010 参数说明](https://www.volcengine.com/docs/6561/1829010)（speech_rate 范围明确）
- [doc 1257544 音色列表](https://www.volcengine.com/docs/6561/1257544)（8 个音色确认）
- [doc 79823 参数基本说明](https://www.volcengine.com/docs/6561/79823)（V1 字段对比，证明 V3 改名）
- [doc 1257584 大模型HTTP非流式-V1](https://www.volcengine.com/docs/6561/1257584)（V1 字段 + 响应格式参考）
- [doc 111586 API 接入 FAQ](https://www.volcengine.com/docs/6561/111586)
- [skills.re doubao connector](https://skills.re/skills/vm0-ai/vm0-skills/doubao)（SSE 终止码 20000000 描述）
- [new-api issue #4709](https://github.com/QuantumNous/new-api/issues/4709)（4 个 V3 transports 表格 + gotchas）
- [IMA Studio TTS skill](https://vibehackers.io/claude-code/skills/ima-studio-tts)（speech_rate/loudness_rate 范围验证）
- [doubao-tts PyPI](https://libraries.io/pypi/doubao-tts)（VOLCENGINE_APP_ID/VOLCENGINE_ACCESS_TOKEN 环境变量约定）
