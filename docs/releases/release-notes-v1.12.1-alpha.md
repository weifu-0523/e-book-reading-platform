# v1.12.1-alpha

**发布日期**：2026-07-17
**类型**：hotfix（移动端启动 crash）
**上一版本**：v1.12.0-alpha

## 摘要

修复 v1.12.0-alpha 在国产 Android ROM（华为/小米/OPPO/vivo，Android 12+）
上启动后立即返回桌面的严重 crash。同时合并发布 v1.12.0-alpha 漏掉的
LIKE 通配符 escape 修复。

测试数：**1654 pass + 25 skip + 7 baseline fail**（与 v1.12.0-alpha
同 baseline，无新增 regression；+5 lazy init 新测试）。

---

## Hotfix：移动端 startup crash（lazy init audio_service）

### 用户报告

> 刚用户测试，移动版本点开后，就自动到后台，无法操作和使用。
> （"自动到后台" = 瞬间回桌面，测试手机：其它国产品牌）

### 根因（消去法定位）

v1.12.0-alpha 引入的 TTS 功能在 `main()` 内立即调用：

```dart
globalAudioHandler = await AudioService.init(builder: ...);
final session = await AudioSession.instance;
await session.configure(const AudioSessionConfiguration(...));
```

这两步会触发 `MediaBrowserService` foreground service bind。在 AOSP
原生 Android 上没问题，但国产 ROM（华为 EMUI / 鸿蒙、小米 MIUI、
OPPO ColorOS、vivo OriginOS）在 Android 12+ 对启动期 foreground
service bind 有定制限制，会直接 kill 进程——表现为 app 打开后
瞬间回桌面，无任何 Dart 异常（native SIGSEGV / ROM 行为），
try/catch 兜不住。

**消去法证据**：

1. v1.11.6-alpha（pre-TTS）在同设备正常运行 → 排除设备 / Android
   版本 / signing 问题。
2. v1.12.0-alpha 唯一新增的 startup 期 native bind 代码就是
   `AudioService.init` + `AudioSession.instance.configure`。
3. 用户描述"瞬间回桌面"+ 国产 ROM + Android 12+ → 与
   ForegroundServiceDidNotStartInTimeException / ROM 自定义
   foreground service 限制表现一致。

### 修复

把 audio_service + audio_session 的初始化从 startup 移到
**首次按「朗读」时**：

1. **`core/providers.dart`** 新增 `globalTtsInfraInitializer`
   全局闭包槽（`Future<void> Function()?`）。
2. **`main.dart`** 把原本的 `AudioService.init` + `session.configure`
   两块代码移进一个闭包，赋给 `globalTtsInfraInitializer`。闭包内
   逻辑不变（同样的 try/catch swallow、同样的
   `AudioServiceConfig`、同样的 session 配置）。Startup 完全不
   触碰 audio 栈。
3. **`tts_playback_controller.dart`** 的 `drivePlay` / `drivePlayAt`
   在调 `_service.init()` 之前先调 `_ensureMobileInfraReady()`：
   - 桌面 → early return（`PlatformInfo.isMobile` false）
   - mobile 但 `globalAudioHandler` 已 set → early return（idempotent）
   - mobile 且 handler 未 set → 调 `globalTtsInfraInitializer()`
   - 闭包抛异常 → swallow + debugPrint，TTS 继续 in-app 工作

### 为什么这样修有效

Android 12+ 限制后台启动 foreground service，但**用户手势触发
的 foreground service 启动是允许的**。当 `drivePlay` 被调用时，
用户已经明确点了「朗读本章」/「朗读选中」/「朗读」菜单——这是
合法的 user gesture，此时启动 foreground service 不会被系统
拒绝。

副作用：用户首次按「朗读」会有几百 ms 延迟（AudioService.init
需要绑定 service）。可接受——比 startup crash 强。

### 已知限制

- 如果用户在通知栏 / 锁屏按 play/pause 时 `globalAudioHandler`
  还没初始化（即用户还没在 app 内点过「朗读」），OS 控件不
  响应。但这是先有鸡还是先有蛋的问题：用户必须先在 app 内
  主动触发一次 TTS，OS 控件才需要存在。所以实际不会发生。
- iOS 未真机验证（同 v1.12.0-alpha 限制）。

### 测试覆盖

`test/features/tts/providers/tts_playback_controller_test.dart`
新增 `lazy infra init (v1.12.1-alpha hotfix)` group，5 个测试：

1. `drivePlay invokes globalTtsInfraInitializer on mobile when handler is unset`
2. `lazy init error is swallowed (in-app TTS continues to work)`
3. `handler already set → initializer NOT invoked (idempotent bypass)`
4. `desktop → initializer NOT invoked (PlatformInfo gate)`
5. `drivePlayAt also triggers lazy init`

---

## C1：LIKE 通配符 escape（从 Unreleased 合并发布）

`AnnotationsDao.searchFts` 和 `BookPassagesDao.searchFts` 在
`quote` / `note` / `tags` / `content_text` 上做子串 LIKE 搜索时，
用户输入的 `%` 和 `_` 被 SQLite 当作通配符——搜 `50%` 会命中
`5000`、搜 `foo_bar` 会命中 `fooxbar`。

修复：drift `.like(pattern, escapeChar: '\\')` +
`_escapeLikeWildcards` helper 转义 `%` / `_` / `\` 后再拼接
pattern。CJK 用户基本不触发，但属于搜索正确性 bug，必须修。

---

## 升级路径

- **drift schema**：不变（v15）。
- **outbox/sync 协议**：不变。
- **跨设备兼容性**：v1.12.0-alpha 与 v1.12.1-alpha 互通无障碍。
- **用户侧**：覆盖安装即可。

## 构建产物

- `zhiyue-app-release-1.12.1-alpha.apk`（Android，~134 MB）
- `zhiyue-setup-1.12.1-alpha.exe`（Windows installer，~48 MB）
- `zhiyue-portable-1.12.1-alpha.zip`（Windows portable，~61 MB）

桌面端用户不需要升级（行为完全不变）；Android 用户**强烈建议
升级**到 v1.12.1-alpha。
