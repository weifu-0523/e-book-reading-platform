# v1.13.0-alpha Release Notes

**发布日期**：2026-07-18
**版本类型**：alpha（移动端功能恢复 + 真机测试待验证）
**上一版本**：v1.12.3-alpha（custom MainActivity 跳过 audio plugin，启动不 crash 但 TTS no-op）

## TL;DR

替代 v1.12.0-alpha 引入的 audio_service + audio_session + flutter_tts 三件套（在国产 ROM 触发启动 crash），自研轻量 Android TTS plugin。完全恢复 Android TTS 四大能力：基本朗读 + 通知栏 + 后台播放 + 锁屏/蓝牙。

## 背景

v1.12.0-alpha 引入移动端 TTS 时，采用了 audio_service + audio_session + flutter_tts 标准三件套。在国产 ROM（华为/小米/OPPO/vivo/Honor，Android 12+）上 app 打开后瞬间被 kill。v1.12.1-v1.12.3-alpha 4 次修复尝试均失败：

| 版本 | 修复尝试 | 结果 |
|------|---------|------|
| v1.12.1-alpha | lazy init AudioService 在 main() | 失败 — plugin attach 早于 main |
| v1.12.2-alpha | 删 audio_service manifest 注册 | 失败 — manifest 不是 trigger |
| v1.12.3-alpha exp2 | patch pub-cache 三方 plugin | 失败 — patch 不可持续 |
| v1.12.3-alpha exp3 | custom MainActivity 跳过 audio plugin | 成功启动，但 TTS 完全 no-op |

## v1.13 方案：自研 plugin + service

### 架构 3 层

1. **Dart 接口层**：`TtsService` interface + `SelfBuiltTtsServiceImpl`（Android 走 MethodChannel，桌面用旧 flutter_tts）
2. **Plugin 层**（Kotlin）：`ZhiYueTtsPlugin` — `onAttachedToEngine` 空，只 bind channel
3. **Service 层**（Android Service）：`ZhiYueTtsService` — 持有 TextToSpeech + MediaSession + AudioFocus + PhoneStateListener + foreground notification

### 核心不变量

`onAttachedToEngine` **必须为空**。所有 system service 构造在 Service.onCreate 内，由用户点击「朗读」触发（Android 12+ user-gesture 豁免）。

### Build flavor 双保险

- **withFgs**（默认）：完整 FGS 声明，全功能
- **noFgs**（fallback）：无 FGS，`ensureServiceStarted` 用 try/catch 吞异常，TTS 变 no-op

## 真机测试矩阵

### withFgs variant（推荐）

预期验证 7 项：
1. 启动不 crash
2. 点「朗读」→ 朗读出声
3. Home 切后台 → 通知栏出现控件
4. 5 分钟后回来 → 仍在读
5. 锁屏 → 出现控件
6. 蓝牙耳机按键 → 响应
7. 电话打入 → 自动 pause

### noFgs variant（fallback）

如果 withFgs crash → 装 noFgs variant，TTS 完全 no-op（按钮在但点击无效果），但其他功能正常。

## 测试覆盖

- **Dart 单元测试**：~1685 pass + 25 skip + 8 baseline fail
- **Kotlin 单元测试**：20 pass（8 plugin + 12 service）
- **subagent-driven TDD**：每个 task 走 red → green → commit → spec review → code quality review → fixup

## 已知限制

- iOS 未实现（v1.14 路线图）
- 媒体按钮 receiver body 是 no-op（AndroidX 自动路由，待真机验证）
- eventEmitter re-attach race（hot restart 场景，v1.14 加 ServiceConnection）
- stopForeground(true) deprecated（v1.14 cleanup）
- handleResume 空实现（Dart 端重发 SPEAK intent 模拟）

## 跨设备兼容性

- drift schema 仍 v15
- recordBook payload 不变
- 同步协议不变
- 覆盖安装即生效

## 升级路径

- 桌面用户：覆盖安装（无 schema 变更）
- Android 用户：卸载 v1.12.0-v1.12.3-alpha 后装 v1.13.0-alpha（避免 plugin 残留）
- iOS 用户：v1.13.0-alpha 仍调旧 code path，行为同 v1.12.3-alpha

## v1.14 路线图

- iOS 自研 AVSpeechSynthesizer wrapper
- ZhiYueTtsMediaButtonReceiver 真实实现
- eventEmitter ServiceConnection 绑定
- stopForeground API 升级
