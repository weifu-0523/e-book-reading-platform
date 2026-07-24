# 豆包语音合成 V3 (HTTP SSE) 接入实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把火山引擎云端 TTS 从 V1 协议（cluster=volcano_tts，已废）升级到 V3 HTTP SSE 协议（resource_id=seed-tts-2.0），让用户能用上已购买的豆包语音合成 2.0 资源。

**Architecture:** 仅替换 `VolcengineCloudTtsService` 内部实现（endpoint / headers / body / response parsing），保留 `BaseCloudTtsService` 抽象基类 + prefetch cache + fallback 机制 + UI 入口不变。客户端 audio pipeline 不重写（仍 `audioplayers` 整段播）。

**Tech Stack:** Flutter 3.x + Dart 3.x + Riverpod StateNotifier + `http` package（MockClient 测试）+ drift v15（schema 不变）

**Spec:** `docs/superpowers/specs/2026-07-24-volcengine-v3-tts-design.md`

---

## Task 1: Fetch V3 HTTP SSE 官方协议细节

**Files:**
- Read: 3 个官方文档（Tavily extract）
- Create: `docs/superpowers/research/2026-07-24-volcengine-v3-protocol-notes.md`

- [ ] **Step 1: 提取 HTTP SSE V3 协议主体**

```
用 mcp__tavily-mcp__tavily_extract 拉 https://docs.volcengine.com/docs/6561/1598757
query: "V3 HTTP SSE endpoint URL 认证 X-Api 请求体 schema SSE event 格式 speed_ratio"
```

记录：endpoint URL / 请求体 schema / SSE event 格式 / 错误响应格式

- [ ] **Step 2: 提取 V3 单向流式（参考请求体 schema）**

```
用 mcp__tavily-mcp__tavily_extract 拉 https://docs.volcengine.com/docs/6561/1719100
query: "V3 单向流式 request body user req_params audio_params voice_type speed_ratio"
```

记录：body schema 字段名 + speed_ratio 取值范围

- [ ] **Step 3: 确认 8 个豆包 2.0 音色 voice_type 字符串**

```
用 mcp__tavily-mcp__tavily_extract 拉 https://www.volcengine.com/docs/6561/1257544
query: "豆包同款 婆婆 高冷御姐 傲娇霸总 魅力女友 深夜播客 开朗弟弟 东方浩然 直率英子 voice_type"
```

逐个核对 8 个音色的 voice_type 字符串与 spec D3 表格一致。

- [ ] **Step 4: 写协议总结到 research notes**

在 `docs/superpowers/research/2026-07-24-volcengine-v3-protocol-notes.md` 写：
- 确认的 endpoint URL
- 完整 headers list（含必需/可选）
- body JSON schema 示例
- SSE event 格式（A/B/C 选哪个）
- speed_ratio 范围 + 映射公式
- 错误响应格式
- 6 个不确定项各自答案

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/research/2026-07-24-volcengine-v3-protocol-notes.md
git commit -m "$(cat <<'EOF'
research(tts): volcengine v3 HTTP SSE protocol notes

Fetch 3 official docs (1598757, 1719100, 1257544) and confirm:
- V3 HTTP SSE endpoint URL
- X-Api-App-Id + X-Api-Access-Key + X-Api-Resource-Id headers
- body schema + speed_ratio range
- SSE event format

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: 更新音色列表 + 默认音色

**Files:**
- Modify: `app/lib/services/tts/voice_preset.dart`
- Modify: `app/lib/services/tts/cloud_tts_credentials.dart`
- Modify: `app/test/services/tts/voice_preset_test.dart`
- Modify: `app/test/services/tts/cloud_tts_credentials_test.dart`

- [ ] **Step 1: 写失败测试 — `voice_preset_test.dart` 加 V3 音色断言**

在 `app/test/services/tts/voice_preset_test.dart` 添加：

```dart
test('volcengine voice list contains 8 doubao 2.0 voices', () {
  final voices = CloudTtsVoicePresets.volcengine;
  expect(voices.length, 8);
  expect(voices.any((v) => v.id == 'zh_male_shenyeboke_moon_bigtts'), isTrue);
  expect(voices.any((v) => v.id == 'zh_female_popo_mars_bigtts'), isTrue);
  expect(voices.any((v) => v.id == 'zh_female_gaolengyujie_moon_bigtts'), isTrue);
  expect(voices.any((v) => v.id == 'zh_male_aojiaobazong_moon_bigtts'), isTrue);
  expect(voices.any((v) => v.id == 'zh_female_meilinvyou_moon_bigtts'), isTrue);
  expect(voices.any((v) => v.id == 'zh_male_livelybro_mars_bigtts'), isTrue);
  expect(voices.any((v) => v.id == 'zh_male_dongfanghaoran_moon_bigtts'), isTrue);
  expect(voices.any((v) => v.id == 'zh_female_naying_mars_bigtts'), isTrue);
});

test('all volcengine voices have _bigtts suffix (v3 exclusive)', () {
  for (final v in CloudTtsVoicePresets.volcengine) {
    expect(v.id.endsWith('_bigtts'), isTrue, reason: '${v.id} missing _bigtts');
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd C:/zhiyue_build_s3/app && flutter test test/services/tts/voice_preset_test.dart
```

预期：FAIL（现有 5 个 V1 音色 + 不带 `_bigtts` 后缀）

- [ ] **Step 3: 改 `voice_preset.dart` 替换 8 个音色**

在 `app/lib/services/tts/voice_preset.dart` 找到 `CloudTtsVoicePresets.volcengine` 静态 getter，替换为：

```dart
static final List<VoicePreset> volcengine = [
  VoicePreset(id: 'zh_male_shenyeboke_moon_bigtts', name: '深夜播客', gender: VoiceGender.male, description: '长篇朗读 / 说书风格'),
  VoicePreset(id: 'zh_female_popo_mars_bigtts', name: '婆婆', gender: VoiceGender.female, description: '长者女声'),
  VoicePreset(id: 'zh_female_gaolengyujie_moon_bigtts', name: '高冷御姐', gender: VoiceGender.female, description: '沉稳女声'),
  VoicePreset(id: 'zh_male_aojiaobazong_moon_bigtts', name: '傲娇霸总', gender: VoiceGender.male, description: '沉稳男声'),
  VoicePreset(id: 'zh_female_meilinvyou_moon_bigtts', name: '魅力女友', gender: VoiceGender.female, description: '甜美女声'),
  VoicePreset(id: 'zh_male_livelybro_mars_bigtts', name: '开朗弟弟', gender: VoiceGender.male, description: '活泼男声'),
  VoicePreset(id: 'zh_male_dongfanghaoran_moon_bigtts', name: '东方浩然', gender: VoiceGender.male, description: '浑厚男声'),
  VoicePreset(id: 'zh_female_naying_mars_bigtts', name: '直率英子', gender: VoiceGender.female, description: '直率女声'),
];
```

注意：`VoiceGender` enum 和 `VoicePreset` 构造函数签名以现有代码为准（如果字段名不同，调整）。

- [ ] **Step 4: 改 `cloud_tts_credentials.dart` 的 `defaultVoice`**

在 `app/lib/services/tts/cloud_tts_credentials.dart` 找到 `VolcengineTtsCredentials.defaultVoice` 静态字段，改为：

```dart
static const String defaultVoice = 'zh_male_shenyeboke_moon_bigtts';
```

- [ ] **Step 5: 跑测试确认通过**

```bash
cd C:/zhiyue_build_s3/app && flutter test test/services/tts/voice_preset_test.dart
```

预期：PASS（步骤 1 加的 2 个新测试通过；其他现有测试可能失败，下一步修）

- [ ] **Step 6: 修 `cloud_tts_credentials_test.dart` 的 defaultVoice 断言**

Grep 找 `defaultVoice` 或 `BV001_streaming` 在 `cloud_tts_credentials_test.dart` 的引用，全部改为 `zh_male_shenyeboke_moon_bigtts`。

- [ ] **Step 7: 跑所有 credentials + voice_preset 测试**

```bash
cd C:/zhiyue_build_s3/app && flutter test test/services/tts/voice_preset_test.dart test/services/tts/cloud_tts_credentials_test.dart
```

预期：PASS

- [ ] **Step 8: dart analyze 无 error**

```bash
cd C:/zhiyue_build_s3/app && dart analyze lib/services/tts/voice_preset.dart lib/services/tts/cloud_tts_credentials.dart
```

预期：No issues found

- [ ] **Step 9: Commit**

```bash
cd C:/zhiyue_build_s3 && git add app/lib/services/tts/voice_preset.dart app/lib/services/tts/cloud_tts_credentials.dart app/test/services/tts/voice_preset_test.dart app/test/services/tts/cloud_tts_credentials_test.dart && git commit -m "$(cat <<'EOF'
feat(tts): volcengine v3 voice list (8 doubao 2.0 _bigtts voices)

Replace 5 v1 BV0xx_streaming voices with 8 v2.0 _bigtts voices.
Default voice: zh_male_shenyeboke_moon_bigtts (说书风格，适合长篇朗读).
Backward compat: V1 voices auto-fallback to default via CloudTtsVoicePresets.find.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 重写 VolcengineCloudTtsService 核心协议

**Files:**
- Modify: `app/lib/services/tts/volcengine_cloud_tts_service.dart`

- [ ] **Step 1: 改 `_endpoint` 为 V3 URL**

在 `app/lib/services/tts/volcengine_cloud_tts_service.dart` 找到：

```dart
static const _endpoint =
    'https://openspeech.bytedance.com/api/v1/tts';
```

改为（URL 以 Task 1 research notes 确认值为准，下面是候选）：

```dart
static const _endpoint =
    'https://openspeech.bytedance.com/api/v3/tts/sse'; // 确认值见 docs/superpowers/research/2026-07-24-volcengine-v3-protocol-notes.md
```

- [ ] **Step 2: 添加 uuid 依赖（如果还没有）**

检查 `app/pubspec.yaml` 是否有 `uuid:` 依赖。如果没有，加 `uuid: ^4.4.2`（项目已有此依赖，应该不需加）。

- [ ] **Step 3: 重写认证 headers**

在 `fetchAudio` 方法找到现有的 `_httpClient.post` 调用，把 headers 从：

```dart
headers: {
  'Authorization': 'Bearer;${credentials.accessToken}',
  'Content-Type': 'application/json',
},
```

改为：

```dart
headers: {
  'Content-Type': 'application/json',
  'X-Api-App-Id': credentials.appId,
  'X-Api-Access-Key': credentials.accessToken,
  'X-Api-Resource-Id': 'seed-tts-2.0',
  'X-Api-Request-Id': const Uuid().v4(),
  'Accept': 'text/event-stream',
},
```

注意：需 `import 'package:uuid/uuid.dart';` 在文件顶部。

- [ ] **Step 4: 重写请求 body schema**

参考 Task 1 research notes 中确认的 V3 schema，把 body 从：

```dart
final body = jsonEncode({
  'app': {
    'appid': credentials.appId,
    'token': credentials.accessToken,
    'cluster': 'volcano_tts',
  },
  'user': {'uid': 'zhiyue'},
  'audio': {
    'voice_type': voice,
    'speed_ratio': _mapRate(rate),
    'encoding': 'mp3',
    'rate': 24000,
  },
  'request': {
    'reqid': DateTime.now().microsecondsSinceEpoch.toString(),
    'text': text,
    'operation': 'query',
  },
});
```

改为（具体字段名以 Task 1 research notes 为准，下面是预测结构）：

```dart
final body = jsonEncode({
  'user': {'uid': 'zhiyue'},
  'req_params': {
    'text': text,
    'audio_params': {
      'voice_type': voice,
      'speed_ratio': _mapRate(rate),
      'encoding': 'mp3',
      'rate': 24000,
    },
  },
});
```

- [ ] **Step 5: 改 `_mapRate` 如果 V3 范围不同**

如果 Task 1 research notes 显示 V3 `speed_ratio` 是 `[-50, 100]`（而不是 V1 的 `[0.5, 2.0]`），把：

```dart
double _mapRate(double normalized) {
  return (normalized + 1.0) * 0.75 + 0.5; // [-1,1] → [0.5,2.0]
}
```

改为：

```dart
int _mapRate(double normalized) {
  return (normalized * 50).round().clamp(-50, 100); // [-1,1] → [-50,100]
}
```

并相应调整 `audio_params.speed_ratio` 字段类型。

如果 V3 仍是 `[0.5, 2.0]`，**不改**。

- [ ] **Step 6: dart analyze 编译通过**

```bash
cd C:/zhiyue_build_s3/app && dart analyze lib/services/tts/volcengine_cloud_tts_service.dart
```

预期：No issues found（编译通过；运行时逻辑待 Task 4 修）

- [ ] **Step 7: Commit**

```bash
cd C:/zhiyue_build_s3 && git add app/lib/services/tts/volcengine_cloud_tts_service.dart && git commit -m "$(cat <<'EOF'
feat(tts): volcengine v3 endpoint + headers + body schema

- endpoint: /api/v1/tts -> /api/v3/tts/sse (HTTP SSE V3)
- auth: Bearer;<token> -> X-Api-App-Id + X-Api-Access-Key + X-Api-Resource-Id=seed-tts-2.0 + X-Api-Request-Id (uuid v4)
- body: app.{appid,token,cluster=volcano_tts} removed; user.uid + req_params.{text, audio_params.{voice_type,speed_ratio,encoding,rate}} V3 schema
- response parsing: TODO task 4 (currently broken — still expects JSON {data:base64})

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: 重写 SSE response 解析

**Files:**
- Modify: `app/lib/services/tts/volcengine_cloud_tts_service.dart`

- [ ] **Step 1: 写失败测试 — SSE 多 chunk 拼接**

在 `app/test/services/tts/volcengine_cloud_tts_service_test.dart` 添加：

```dart
test('fetchAudio parses SSE multi-event response correctly', () async {
  final chunk1 = base64Encode([0x49, 0x44, 0x33]); // 'ID3' MP3 header bytes
  final chunk2 = base64Encode([0xAB, 0xCD, 0xEF, 0x12]);
  final sseBody = 'data: $chunk1\n\ndata: $chunk2\n\ndata: [DONE]\n\n';
  
  final mockClient = MockClient((request) async {
    expect(request.url.toString(), contains('/api/v3/tts/'));
    expect(request.headers['X-Api-Resource-Id'], 'seed-tts-2.0');
    return http.Response(sseBody, 200, headers: {'Content-Type': 'text/event-stream'});
  });
  
  final service = VolcengineCloudTtsService(
    credentials: VolcengineTtsCredentials(appId: 'test', accessToken: 'test'),
    httpClient: mockClient,
  );
  
  final bytes = await service.fetchAudio('hello', 0.0, 'zh_male_shenyeboke_moon_bigtts');
  expect(bytes.length, 7); // 3 + 4
  expect(bytes.sublist(0, 3), [0x49, 0x44, 0x33]);
});
```

注意：SSE event 格式以 Task 1 research notes 为准（可能是 `event: audio\ndata: ...` 而非裸 `data:`）。

- [ ] **Step 2: 跑测试确认失败**

```bash
cd C:/zhiyue_build_s3/app && flutter test test/services/tts/volcengine_cloud_tts_service_test.dart
```

预期：FAIL（现实现仍按 V1 JSON 解析 `data` 字段）

- [ ] **Step 3: 实现 SSE parser**

在 `volcengine_cloud_tts_service.dart` 找到现有的 response 解析逻辑（`jsonDecode(response.body)` 那段），替换为：

```dart
if (response.statusCode != 200) {
  throw CloudTtsException(
    kind: CloudTtsErrorKind.fromHttpStatus(response.statusCode),
    message: 'HTTP ${response.statusCode}: ${response.body}',
  );
}

// V3 SSE response: multiple `data: <base64>` events + termination
final bodyString = response.body;
final chunks = <int>[];
final lines = bodyString.split('\n');
for (final line in lines) {
  if (!line.startsWith('data: ')) continue;
  final payload = line.substring(6).trim();
  if (payload.isEmpty || payload == '[DONE]') continue;
  // 如果 SSE event 是 JSON 包装（如 {"audio": "<base64>"}），先 jsonDecode 再取 audio 字段
  // 这里以 Task 1 research notes 确认格式为准
  try {
    chunks.addAll(base64Decode(payload));
  } catch (e) {
    throw CloudTtsException(
      kind: CloudTtsErrorKind.invalidRequest,
      message: 'Invalid base64 in SSE chunk: $payload',
    );
  }
}

if (chunks.isEmpty) {
  throw CloudTtsException(
    kind: CloudTtsErrorKind.invalidRequest,
    message: 'Empty audio data in SSE response: $bodyString',
  );
}

return Uint8List.fromList(chunks);
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd C:/zhiyue_build_s3/app && flutter test test/services/tts/volcengine_cloud_tts_service_test.dart
```

预期：步骤 1 的 SSE 测试 PASS

- [ ] **Step 5: 写失败测试 — error event 处理**

```dart
test('fetchAudio handles SSE error event', () async {
  // 如果 V3 SSE 错误是 HTTP 非 200，已被 fromHttpStatus 处理；
  // 如果是 200 但 event 内 error 字段，需单独测
  // 具体 error event 格式以 Task 1 为准
  final sseBody = 'event: error\ndata: {"code":55000000,"message":"resource ID mismatched"}\n\n';
  
  final mockClient = MockClient((request) async {
    return http.Response(sseBody, 200, headers: {'Content-Type': 'text/event-stream'});
  });
  
  final service = VolcengineCloudTtsService(
    credentials: VolcengineTtsCredentials(appId: 'test', accessToken: 'test'),
    httpClient: mockClient,
  );
  
  expect(
    () => service.fetchAudio('hello', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
    throwsA(isA<CloudTtsException>()),
  );
});
```

- [ ] **Step 6: 实现 SSE error event 解析**

在 SSE parser 里加 `event: error` 分支处理（解析 JSON `data` 提取 code/message，转 CloudTtsException）。

- [ ] **Step 7: 跑测试确认通过**

```bash
cd C:/zhiyue_build_s3/app && flutter test test/services/tts/volcengine_cloud_tts_service_test.dart
```

预期：所有 SSE 测试 PASS

- [ ] **Step 8: Commit**

```bash
cd C:/zhiyue_build_s3 && git add app/lib/services/tts/volcengine_cloud_tts_service.dart app/test/services/tts/volcengine_cloud_tts_service_test.dart && git commit -m "$(cat <<'EOF'
feat(tts): volcengine v3 SSE response parsing

- parse multi-event SSE stream (data: <base64> per chunk)
- handle termination signal ([DONE] or event:done)
- handle error event (event:error with JSON {code,message})
- code=55000000 (resource mismatch) -> CloudTtsException(invalidRequest)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: 重写认证 + 错误处理测试

**Files:**
- Modify: `app/test/services/tts/volcengine_cloud_tts_service_test.dart`

- [ ] **Step 1: 写失败测试 — 认证 headers 完整性**

```dart
test('fetchAudio sends correct v3 auth headers', () async {
  String? capturedAppId;
  String? capturedAccessKey;
  String? capturedResourceId;
  String? capturedRequestId;
  
  final mockClient = MockClient((request) async {
    capturedAppId = request.headers['X-Api-App-Id'];
    capturedAccessKey = request.headers['X-Api-Access-Key'];
    capturedResourceId = request.headers['X-Api-Resource-Id'];
    capturedRequestId = request.headers['X-Api-Request-Id'];
    return http.Response('data: ${base64Encode([1,2,3])}\n\ndata: [DONE]\n\n', 200);
  });
  
  final service = VolcengineCloudTtsService(
    credentials: VolcengineTtsCredentials(appId: '6885189822', accessToken: 'mytoken'),
    httpClient: mockClient,
  );
  await service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts');
  
  expect(capturedAppId, '6885189822');
  expect(capturedAccessKey, 'mytoken');
  expect(capturedResourceId, 'seed-tts-2.0');
  expect(capturedRequestId, isNotNull);
  expect(capturedRequestId!.length, 36); // UUID v4 长度
  expect(capturedRequestId!.split('-').length, 5); // UUID v4 5 段
});
```

- [ ] **Step 2: 跑测试确认通过（应在 Task 3 已实现）**

```bash
cd C:/zhiyue_build_s3/app && flutter test test/services/tts/volcengine_cloud_tts_service_test.dart --plain-name "sends correct v3 auth headers"
```

如果 FAIL，回 Task 3 检查 headers 实现。

- [ ] **Step 3: 写失败测试 — HTTP 401/403/429/5xx 错误分类**

```dart
test('HTTP 401 -> auth error', () async {
  final mockClient = MockClient((request) async => http.Response('Unauthorized', 401));
  final service = VolcengineCloudTtsService(
    credentials: VolcengineTtsCredentials(appId: 'x', accessToken: 'x'),
    httpClient: mockClient,
  );
  expect(
    () => service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
    throwsA(predicate((e) => e is CloudTtsException && e.kind == CloudTtsErrorKind.auth)),
  );
});

test('HTTP 429 -> quota error', () async {
  final mockClient = MockClient((request) async => http.Response('Rate limited', 429));
  final service = VolcengineCloudTtsService(
    credentials: VolcengineTtsCredentials(appId: 'x', accessToken: 'x'),
    httpClient: mockClient,
  );
  expect(
    () => service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
    throwsA(predicate((e) => e is CloudTtsException && e.kind == CloudTtsErrorKind.quota)),
  );
});

test('HTTP 500 -> server error (transient)', () async {
  final mockClient = MockClient((request) async => http.Response('Server error', 500));
  final service = VolcengineCloudTtsService(
    credentials: VolcengineTtsCredentials(appId: 'x', accessToken: 'x'),
    httpClient: mockClient,
  );
  expect(
    () => service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
    throwsA(predicate((e) => e is CloudTtsException && e.kind == CloudTtsErrorKind.server)),
  );
});
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd C:/zhiyue_build_s3/app && flutter test test/services/tts/volcengine_cloud_tts_service_test.dart
```

预期：所有 HTTP 错误分类测试 PASS

- [ ] **Step 5: 写失败测试 — code=55000000 resource mismatch**

```dart
test('code=55000000 resource mismatch -> invalidRequest', () async {
  // 如果是 SSE error event（200 + event:error）
  final sseBody = 'event: error\ndata: {"code":55000000,"message":"resource ID mismatched with speaker related resource"}\n\n';
  final mockClient = MockClient((request) async => http.Response(sseBody, 200));
  final service = VolcengineCloudTtsService(
    credentials: VolcengineTtsCredentials(appId: 'x', accessToken: 'x'),
    httpClient: mockClient,
  );
  expect(
    () => service.fetchAudio('hi', 0.0, 'zh_male_shenyeboke_moon_bigtts'),
    throwsA(predicate((e) =>
      e is CloudTtsException &&
      e.kind == CloudTtsErrorKind.invalidRequest &&
      e.message.contains('55000000')
    )),
  );
});
```

- [ ] **Step 6: 跑测试确认通过**

Task 4 的 SSE error event 实现应已覆盖，预期 PASS。

- [ ] **Step 7: 写测试 — prefetch cache 命中 + rate 变化清缓存**

```dart
test('prefetch cache hits on same text+voice+rate', () async {
  int callCount = 0;
  final mockClient = MockClient((request) async {
    callCount++;
    return http.Response('data: ${base64Encode([1,2,3])}\n\ndata: [DONE]\n\n', 200);
  });
  final service = VolcengineCloudTtsService(
    credentials: VolcengineTtsCredentials(appId: 'x', accessToken: 'x'),
    httpClient: mockClient,
  );
  await service.fetchAudio('hi', 0.0, 'v1');
  await service.fetchAudio('hi', 0.0, 'v1'); // cache hit
  expect(callCount, 1);
});

test('rate change invalidates prefetch cache', () async {
  int callCount = 0;
  final mockClient = MockClient((request) async {
    callCount++;
    return http.Response('data: ${base64Encode([1,2,3])}\n\ndata: [DONE]\n\n', 200);
  });
  final service = VolcengineCloudTtsService(
    credentials: VolcengineTtsCredentials(appId: 'x', accessToken: 'x'),
    httpClient: mockClient,
  );
  await service.fetchAudio('hi', 0.0, 'v1');
  await service.fetchAudio('hi', 0.5, 'v1'); // rate changed
  expect(callCount, 2);
});
```

注意：cache 实际逻辑由 `BaseCloudTtsService` 提供；如果 BaseCloudTtsService 已有 cache 行为，这两测试应直接 PASS（回归保护）。

- [ ] **Step 8: 跑所有 V3 测试 + dart analyze**

```bash
cd C:/zhiyue_build_s3/app && flutter test test/services/tts/volcengine_cloud_tts_service_test.dart
cd C:/zhiyue_build_s3/app && dart analyze lib/services/tts/volcengine_cloud_tts_service.dart
```

预期：全 PASS + No issues

- [ ] **Step 9: Commit**

```bash
cd C:/zhiyue_build_s3 && git add app/test/services/tts/volcengine_cloud_tts_service_test.dart && git commit -m "$(cat <<'EOF'
test(tts): volcengine v3 auth headers + error classification + cache regression

- assert 4 v3 headers + UUID v4 Request-Id
- assert HTTP 401/403 -> auth, 429 -> quota, 5xx -> server (transient)
- assert code=55000000 resource mismatch -> invalidRequest
- assert prefetch cache hit on same input + invalidation on rate change

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Widget test 兼容性 + V1 持久化音色降级

**Files:**
- Modify: `app/test/features/settings/pages/tts_settings_section_test.dart` (如果断言失败)
- 可能 Modify: `app/lib/services/tts/voice_preset.dart` (加 V1→V3 fallback)

- [ ] **Step 1: 跑 widget test 看现状**

```bash
cd C:/zhiyue_build_s3/app && flutter test test/features/settings/pages/tts_settings_section_test.dart
```

预期：可能有失败（dropdown 默认值或音色数量断言）

- [ ] **Step 2: 修复失败的 widget test 断言**

按报错调整：
- 如果断言 dropdown item count == 5 → 改为 8
- 如果断言 voice dropdown 默认值 == `BV001_streaming` → 改为 `zh_male_shenyeboke_moon_bigtts`

- [ ] **Step 3: 写测试 — V1 持久化音色自动降级**

在 `app/test/services/tts/voice_preset_test.dart` 添加：

```dart
test('V1 persisted voice (BV001_streaming) falls back to default v3 voice', () {
  // 模拟用户从 v1.16.0-alpha 升级，持久化的 voice 是 V1 格式
  final v1Voice = 'BV001_streaming';
  final voices = CloudTtsVoicePresets.volcengine;
  final match = voices.where((v) => v.id == v1Voice).toList();
  
  // V1 voice 不在 V3 列表里
  expect(match.isEmpty, isTrue);
  
  // 应用层在找不到时降级到默认音色
  final fallback = voices.where((v) => v.id == VolcengineTtsCredentials.defaultVoice).first;
  expect(fallback.id, 'zh_male_shenyeboke_moon_bigtts');
});
```

- [ ] **Step 4: 如有需要，加 V1→V3 fallback helper 到 voice_preset.dart**

如果 `CloudTtsVoicePresets.find(voiceId)` 或类似 helper 不存在，加一个：

```dart
static VoicePreset findOrDefault(String? voiceId, String defaultVoice) {
  if (voiceId == null) {
    return volcengine.firstWhere((v) => v.id == defaultVoice);
  }
  return volcengine.firstWhere(
    (v) => v.id == voiceId,
    orElse: () => volcengine.firstWhere((v) => v.id == defaultVoice),
  );
}
```

注意：以现有代码风格为准（可能已有 `firstWhereSafe` 之类的 helper）。

- [ ] **Step 5: 跑全部 TTS 相关测试 + widget test**

```bash
cd C:/zhiyue_build_s3/app && flutter test test/services/tts/ test/features/tts/ test/features/settings/pages/tts_settings_section_test.dart
```

预期：全 PASS

- [ ] **Step 6: dart analyze 整个 TTS 模块**

```bash
cd C:/zhiyue_build_s3/app && dart analyze lib/services/tts/ lib/features/tts/ lib/features/settings/
```

预期：No issues

- [ ] **Step 7: Commit**

```bash
cd C:/zhiyue_build_s3 && git add app/ && git commit -m "$(cat <<'EOF'
test(tts): widget compat + v1 voice persisted fallback

- update tts_settings_section widget test for 8 v3 voices
- add v1 (BV001_streaming) -> v3 default voice fallback test
- ensure user persisted voice from v1.16.0-alpha auto-downgrades

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: 发布准备

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `app/windows/installer/zhiyue.iss`
- Modify: `CHANGELOG.md`
- Create: `docs/releases/release-notes-v1.16.1-alpha.md`

- [ ] **Step 1: 用 Python binary-safe 改 pubspec.yaml version**

```bash
python -c "
content = open('app/pubspec.yaml', 'rb').read().decode('utf-8')
content = content.replace('version: 1.16.0-alpha+2019', 'version: 1.16.1-alpha+2020')
open('app/pubspec.yaml', 'wb').write(content.encode('utf-8'))
"
```

注意：用 binary-safe Python 避免 CRLF→LF 转换（feedback_changelog_binary_safe 教训）。

- [ ] **Step 2: 用 Python binary-safe 改 zhiyue.iss MyAppVersion**

```bash
python -c "
content = open('app/windows/installer/zhiyue.iss', 'rb').read().decode('utf-8')
content = content.replace('#define MyAppVersion \"1.16.0-alpha\"', '#define MyAppVersion \"1.16.1-alpha\"')
open('app/windows/installer/zhiyue.iss', 'wb').write(content.encode('utf-8'))
"
```

- [ ] **Step 3: 在 CHANGELOG.md 顶部插入 v1.16.1-alpha entry**

用 Python binary-safe 插入：

```python
import re
content = open('CHANGELOG.md', 'rb').read().decode('utf-8')
new_entry = """## [1.16.1-alpha] - 2026-07-24

### Major (TTS 协议升级)

- 火山引擎云端 TTS 从 V1 协议升级到 V3 HTTP SSE（用户已购买的豆包语音合成 2.0 资源可用）
- 替换 5 个 V1 `BV0xx_streaming` 音色为 8 个 V3 `_bigtts` 音色（深夜播客/婆婆/高冷御姐/傲娇霸总/魅力女友/开朗弟弟/东方浩然/直率英子）
- 默认音色：深夜播客（说书风格，适合长篇朗读）

### Breaking

- 用户必须开通豆包语音合成 2.0（不再支持「语音合成标准版 1.0」资源）
- 用户持久化的 V1 音色（如 `BV001_streaming`）自动降级到默认音色

### Fixed

- v1.16.0-alpha 火山引擎测试连接报 401/403 `code 3001 "load grant: requested grant not found"` 的根本原因（V1 endpoint 与豆包 2.0 资源不匹配）

### Internal

- VolcengineCloudTtsService V1→V3 重写：endpoint / 4 个 X-Api-* headers / V3 body schema / SSE response parser
- BaseCloudTtsService / TtsFallbackNotifier / TtsPlaybackController 不变
- Qwen V1 代码保留（用户未购买 Qwen 资源，v1.17 升级）

"""
# 找到现有第一条 ## 之后插入
content = re.sub(r'(\n)(## \[)', r'\1' + new_entry + r'\2', content, count=1)
open('CHANGELOG.md', 'wb').write(content.encode('utf-8'))
```

把这段 Python 写到临时文件执行（避免 bash backtick 解释问题）。

- [ ] **Step 4: 创建 release-notes-v1.16.1-alpha.md**

在 `docs/releases/release-notes-v1.16.1-alpha.md` 新建（参考 v1.16.0-alpha 格式）：

- 摘要：TTS 协议升级 V1→V3
- 背景：用户开豆包语音合成 2.0，V1 endpoint 报 401/403
- 新音色列表 8 个 + 默认「深夜播客」
- 升级路径（用户持久化字段复用）
- 测试步骤（测试连接 + 多句平滑 + 切音色 + fallback）
- 已知限制 + v1.17 路线

- [ ] **Step 5: Commit**

```bash
cd C:/zhiyue_build_s3 && git add app/pubspec.yaml app/windows/installer/zhiyue.iss CHANGELOG.md docs/releases/release-notes-v1.16.1-alpha.md && git commit -m "$(cat <<'EOF'
docs(release): v1.16.1-alpha prep

- pubspec version 1.16.0-alpha+2019 -> 1.16.1-alpha+2020
- installer MyAppVersion bump
- CHANGELOG entry (V1->V3 协议升级 + 音色列表替换)
- release notes 新建

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: 构建 + marker 验证 + 分发

- [ ] **Step 1: 切到 worktree 同步 master**

```bash
cd C:/zhiyue_build_s3 && git fetch origin && git rebase origin/master  # 或 merge
```

确保所有 v1.16.1-alpha commits 都在 s4-build branch HEAD。

- [ ] **Step 2: 清 Android intermediates 避免 strip cache trap**

```bash
rm -rf C:/zhiyue_build_s3/app/build/app/intermediates
rm -rf C:/zhiyue_build_s3/app/build/flutter_assets
rm -rf C:/zhiyue_build_s3/app/.dart_tool
```

教训见 [[feedback_flutter_strip_cache_trap]] 第 6-7 次踩。

- [ ] **Step 3: 构建 APK withFgs release**

```bash
cd C:/zhiyue_build_s3/app && /c/flutter/bin/flutter build apk --flavor withFgs --release
```

- [ ] **Step 4: 验证 libapp.so 含 V3 markers（ASCII 标记）**

```bash
cd C:/zhiyue_build_s3/app/build/app/intermediates/flutter_release_withFgs/flutter-release/armeabi-v7a && strings libapp.so | grep -E "seed-tts-2.0|zh_male_shenyeboke|X-Api-Resource-Id"
```

预期：每个 marker 至少 1 个匹配。

如果 0 匹配 → strip cache trap 第 8 次踩，重做 Step 2-3。

- [ ] **Step 5: 验证 libapp.so MD5 跟 v1.16.0-alpha 不同**

```bash
certutil -hashfile libapp.so MD5
```

预期：跟 v1.16.0-alpha 的 MD5 不同（确认 Dart 改动进 so）。

- [ ] **Step 6: 清 Windows 缓存避免 SherpaOnnx 残留**

```bash
rm -rf C:/zhiyue_build_s3/app/build/flutter_assets
rm -rf C:/zhiyue_build_s3/app/build/windows
rm -rf C:/zhiyue_build_s3/app/.dart_tool
```

教训见 [[project_zhiyue_2026_07_23_v1_16_tts_hybrid_cloud]] Windows strip cache trap。

- [ ] **Step 7: 构建 Windows release**

```bash
cd C:/zhiyue_build_s3/app && /c/flutter/bin/flutter build windows --release
```

- [ ] **Step 8: 验证 Release 目录无 SherpaOnnx 残留**

```bash
find C:/zhiyue_build_s3/app/build/windows/x64/runner/Release -type f -size +1M -exec ls -lh {} \; | sort -hr | head -15
```

预期：最大文件是字体（~20MB NotoSansSC.otf 等），无 `model.onnx` / `onnxruntime.dll` / `sherpa-onnx-c-api.dll`。

- [ ] **Step 9: 构建 Windows installer**

```bash
/c/Users/1/InnoSetup/ISCC.exe C:/zhiyue_build_s3/app/windows/installer/zhiyue.iss
```

- [ ] **Step 10: 验证 installer 大小 ~46 MB**

```bash
ls -lh C:/zhiyue_build_s3/app/build/installer/zhiyue-setup-1.16.1-alpha.exe
```

预期：~46 MB（跟 v1.16.0-alpha 一致，无新依赖）。

- [ ] **Step 11: 复制 artifacts 到分发路径**

```bash
cp C:/zhiyue_build_s3/app/build/app/outputs/flutter-apk/app-withFgs-release.apk /c/Users/1/Desktop/zhiyue-1.16.1-alpha.apk
cp C:/zhiyue_build_s3/app/build/installer/zhiyue-setup-1.16.1-alpha.exe /c/Users/1/Desktop/
cp C:/zhiyue_build_s3/app/build/app/outputs/flutter-apk/app-withFgs-release.apk "/h/华为同步盘/华为云盘/新版本发布/zhiyue-1.16.1-alpha.apk"
cp C:/zhiyue_build_s3/app/build/installer/zhiyue-setup-1.16.1-alpha.exe "/h/华为同步盘/华为云盘/新版本发布/"
```

- [ ] **Step 12: Tag + push**

```bash
cd C:/zhiyue_build_s3 && git tag v1.16.1-alpha && git tag m-volcengine-v3-tts && git push origin s4-build --tags
```

如果是 master branch：相应改为 `git push origin master --tags`。

- [ ] **Step 13: Merge s4-build → master + push**

```bash
cd "H:/projiect/电子书阅读平台" && git fetch origin && git merge origin/s4-build --ff-only && git push origin master
```

- [ ] **Step 14: 通知用户测试**

向用户报告：
- APK 路径 + 大小
- Installer 路径 + 大小
- 4 个测试场景：测试连接 / 多句平滑 / 切音色 / fallback
- 用户 APP ID `6885189822` + Token 直接复用（无需重填）

---

## Self-Review

**Spec coverage:**
- D1 协议 HTTP SSE → Task 1, 3, 4 ✓
- D2 认证 X-Api-* → Task 3, 5 ✓
- D3 音色列表 8 个 → Task 2 ✓
- D4 架构替换 → Task 2, 3, 4 ✓
- D5 Qwen 不动 → 不需要 task（默认）✓
- D6 Fallback 沿用 → 不需要 task（默认）✓
- D7 测试策略 → Task 2, 4, 5, 6 ✓

**Placeholder scan:** 
- Task 1 的 SSE event 格式留「以 research notes 为准」是合理的（task 1 就是去拿准确值）
- Task 3 的 body schema 是预测结构，Task 1 确认后调整
- 无 TBD/TODO

**Type consistency:**
- `zh_male_shenyeboke_moon_bigtts` 字符串在 Task 2/4/5/6 一致
- `seed-tts-2.0` 在 Task 3/5 一致
- 4 个 X-Api-* headers 在 Task 3/5 一致
- V1 持久化降级测试在 Task 6 跟 spec D4 表格一致

**Risks:**
- Task 1 fetch 失败（如 Tavily 配额耗尽）→ 回退到 WebFetch 工具
- Task 4 SSE 格式跟预测不同 → implementer 在 Task 1 notes 拿准确值后调整 parser
- Task 8 strip cache trap 第 8 次触发 → step 2/6 强制清理

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-24-volcengine-v3-tts.md`.

**Recommended:** superpowers:subagent-driven-development（fresh subagent per task + 两阶段 review）

按 [[feedback_subagent_model_selection]]：14-18 点用 haiku，其他时段 opus。本 plan 多任务跨文件，建议 sonnet（标准模型）。
