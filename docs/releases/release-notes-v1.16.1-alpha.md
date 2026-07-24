# v1.16.1-alpha

**发布日期**: 2026-07-24
**类型**: hotfix（火山引擎云端 TTS 协议升级 V1 → V3）
**上一版本**: v1.16.0-alpha（2026-07-23）

## 摘要

v1.16.0-alpha 实现的是火山引擎**老版语音合成 1.0** 接口，但用户在控制台开通的是**豆包语音合成模型 2.0**，两者是火山引擎的独立产品线，资源池不共享。用户两次测试均失败（HTTP 401 + 403 + code 3001 `load grant not found`）。

v1.16.1-alpha 把火山引擎云端 TTS **从 V1 协议升级到 V3 HTTP SSE 协议**，让用户能用上已购买的豆包语音合成 2.0 资源。

## 主要改动

### 协议升级
- endpoint: `/api/v1/tts` → `/api/v3/tts/sse`
- 认证: `Authorization: Bearer;<token>` → 4 个 `X-Api-*` headers（含 `X-Api-Resource-Id: seed-tts-2.0`）
- body schema 字段重命名（V3 与 V1 完全不同）
- response 解析: V1 JSON 一次性返回 → V3 SSE event stream（多帧 + 终止帧 `code:20000000`）

### 音色列表替换

| v1.16.0-alpha (V1) | v1.16.1-alpha (V3) |
|---|---|
| BV001_streaming 通用女声 | 深夜播客 ⭐默认 |
| BV002_streaming 通用男声 | 婆婆 |
| BV700_streaming 灿灿 | 高冷御姐 |
| BV701_streaming 擎苍 | 傲娇霸总 |
| BV705_streaming 炉鼎 | 魅力女友 |
|  | 开朗弟弟 |
|  | 东方浩然 |
|  | 直率英子 |

全部 8 个 V3 音色带 `_bigtts` 后缀（豆包语音合成 2.0 专属）。

## 获取凭证

如果你已在 v1.16.0-alpha 配置过火山引擎：
- **App ID + Access Token 直接复用**（字段语义不变，无需重新填）
- **音色需要重新选**（V1 音色不在 V3 列表里，设置页 Dropdown 会显示为空 → 选一个新音色保存即可）

如果是首次配置：
1. 访问 https://console.volcengine.com/speech/service/8
2. 开通「豆包语音合成模型 2.0」服务
3. 应用管理 → 创建应用 → 获取 **App ID**（数字格式如 `6885189822`）+ **Access Token**
4. 智阅 设置 → 朗读 → TTS 引擎选「火山引擎（云端）」→ 填凭证 + 选音色 → 「测试连接」验证

## 测试场景（用户真机）

### 场景 1: 凭证连接测试
1. 设置 → 朗读 → 引擎选「火山引擎（云端）」
2. 填 App ID + Access Token
3. 选音色（推荐「深夜播客」）
4. 点「测试连接」→ 弹 SnackBar `✓ 连接成功（XXXX bytes）`

### 场景 2: 多句平滑播放
1. 选段朗读 5+ 句
2. **句间应无明显 gap**（HTTP prefetch cache 在前一句播放时并行合成下一句）
3. 设置 → 朗读 → 「TTS 调试日志」→ 看 prefetchHit > 0

### 场景 3: 切换音色
1. 朗读中暂停
2. 设置 → 朗读 → 换音色
3. 重新朗读 → 立即生效（cache 自动失效）

### 场景 4: 网络失败 fallback
1. 朗读时关 WiFi/拔网线
2. service.error 触发 network 错误
3. 自动 fallback 到系统 TTS（SnackBar 提示）

## 升级路径

直接装 v1.16.1-alpha 覆盖 v1.16.0-alpha：
- drift schema v15 不变（无数据库迁移）
- versionCode 2020 > v1.16.0-alpha 的 2019
- 用户持久化 `tts.engine="volcengineCloud"` 不变
- 用户持久化 App ID + Access Token 不变
- **用户持久化的 V1 音色（如 `BV001_streaming`）失效**，设置页 Dropdown 会显示为空，需重新选

## 已知限制

- v1.16.0-alpha → v1.16.1-alpha 升级后，**设置页音色 Dropdown 可能显示为空**（持久化的 V1 音色不在 V3 列表）。**手动重选音色即可**，不影响其他功能。
- 13 个 pre-existing test failures in `tts_reader_controller_test.dart`（v1.16.0-alpha 遗留 bug，与本版本无关）。

## v1.17 路线

- 新版控制台 API Key 单字段认证（`X-Api-Key` 替代 `X-Api-App-Id` + `X-Api-Access-Key`）
- Qwen V3 升级（用户未购买 Qwen 资源，v1.17 待升级）
- WebSocket 双向流式（如果用户反馈首句延迟成问题，或需要朗读中途取消）
- 用户界面音色分组（按性别/风格/方言）

## 参考

- [HTTP Chunked/SSE 单向流式-V3 文档 1598757](https://docs.volcengine.com/docs/6561/1598757)
- [WebSocket 单向流式-V3 文档 1719100](https://www.volcengine.com/docs/6561/1719100)
- [音色列表官方文档 1257544](https://www.volcengine.com/docs/6561/1257544)
- 内部协议确认笔记: `docs/superpowers/research/2026-07-24-volcengine-v3-protocol-notes.md`
- Spec: `docs/superpowers/specs/2026-07-24-volcengine-v3-tts-design.md`
