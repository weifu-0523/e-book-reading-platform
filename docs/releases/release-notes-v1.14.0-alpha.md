# v1.14.0-alpha

**发布日期**：2026-07-20
**类型**：feature release（2 features + 2 bug fixes）
**上一版本**：v1.13.11-alpha

## 摘要

本版本交付用户长期要求的两大功能 + 修复两个相关 deep-link bug：

1. **TTS 多播音员声音选择** — 用户报告"目前只有一个播音员的声音，能不能有多个可以选择"
2. **设为默认阅读器提示** — 用户报告"打开软件时希望提示设为默认阅读器"
3. **Android deep-link 乱码修复（P0）** — 用户报告"在手机里点 epub 选「用智阅打开」出现乱码页面"
4. **Windows 热启动 deep-link 失败修复（P1）** — 用户报告"软件已开启时双击 epub 没反应"

## Feature 1：TTS 多播音员声音选择

### 入口

设置 → 朗读 → 「朗读声音」tile（在 朗读 语速/音调/音量 sliders 下方）

### 行为

- 列表显示「系统默认」+ 设备所有可用 TTS 声音
- 每个声音显示名称 + locale，右侧 `▶` 按钮可试听（不影响当前设置）
- 选某个声音 → 立即同步到 engine，下一句朗读生效
- 列表底部「打开系统 TTS 设置」按钮 → 跳系统设置加声音（华为/荣耀等 ROM 只带 1 个声音时有用）

### 平台覆盖

| 平台 | API | 声音来源 |
|---|---|---|
| Android | `TextToSpeech.getVoices()` | 系统 TTS 引擎（Google TTS、华为、讯飞等） |
| Windows | SAPI5 via flutter_tts | 已安装桌面声音 |
| iOS/macOS/Linux | 不可用，VoiceListPage 不渲染（未来可加） |

### ROM 差异预期

- **华为/荣耀**：默认只装 1 个中文声音（"小艺"或类似），列表很短
- **小米**：1-2 个（小爱同学 + 系统）
- **OPPO/vivo**：1-2 个
- **Pixel**：10+ 个（Google TTS 多语言）
- **Samsung**：Samsung SMT 引擎中文支持差，被 `TtsAvailability.checkTtsAvailability` 检测后建议切换

### 持久化

`TtsSettings.voiceId` 加到 json（drift schema 不变），跨会话保留。`previewVoice` 试听后自动恢复用户原设置，不污染全局。

## Feature 2：设为默认阅读器提示

### 触发逻辑

App 启动后 post-frame 回调：

1. 检查 `AppSettings.promptedDefaultReader`
2. 若 `true` → 不弹（已弹过）
3. 若 `false` → 检查 `DefaultReaderDetector.isRegisteredAsDefault()`
4. 若已注册为默认 → 标记 `promptedDefaultReader=true`，不弹
5. 若未注册 → 弹 `DefaultReaderPromptDialog`

弹窗后无论用户选「设为默认」还是「稍后再说」，都标记 `promptedDefaultReader=true`（不再自动弹）。

### 平台行为

| 平台 | 主操作 | 说明 |
|---|---|---|
| Windows | 写 HKCU `Software\Classes\.epub` 和 `.pdf` | 不需 admin；Inno Setup 写的 HKLM 被 HKCU 覆盖（HKCU 优先级高） |
| Android | 跳系统「默认应用」设置 | Android 不允许 app 自注册为默认；用户手动设置 |

### 手动重触发

Settings → 关于 → 「设为默认阅读器」tile → 重新弹 dialog

### 持久化

`AppSettings.promptedDefaultReader` 存到 `app_settings.json`（与 `tts_settings.json` 同目录）。跨设备同步**不**包含此 flag（设备本地行为）。

## Bug 1（P0）：Android deep-link 乱码

### 症状

用户在手机文件管理器点 .epub 文件 → 选「用智阅打开」→ 出现全是乱码的页面，无法导入。必须从「书架 → +」入口才能正常导入。

### 根因

`MainActivity.copyContentToCache` 把 content URI 复制到临时文件时硬编码 `.book` 扩展名：

```kotlin
val tempFile = File(cacheDir, "import_${System.currentTimeMillis()}.book")
```

下游：
- `BookOpenBridge.isSupportedBookPath` 白名单 `.epub/.pdf/.md/.markdown/.mdown/.txt` — `.book` 被过滤
- `BookFormatDetector.detect` 要求 `.epub` 扩展名才走 EPUB 检测（即使 magic bytes 是 ZIP）

→ 静默失败 → 渲染层收到无效路径 → 乱码页面

### 修复

`MainActivity.inferExtensionFromUri`：

1. 先看 URI `lastPathSegment`（通常含原始文件名如 `三体.epub`）
2. 取最后一个 `.` 后的部分，小写化，校验在支持列表内（`.epub/.pdf/.txt/.md/.markdown/.mdown`）
3. 失败时 fallback 到 `ContentResolver.getType(uri)` MIME type 映射

临时文件名用推断出的扩展名：`import_<timestamp>.epub`，下游检测正常工作。

## Bug 2（P1）：Windows 热启动 deep-link 失败

### 症状

用户报告：
- 智阅**已开启**时，双击 .epub 选「用智阅打开」→ 无反应
- 智阅**已关闭**时，双击 .epub 选「用智阅打开」→ 正常打开并导入

### 根因

Windows 单实例机制：第二个实例通过 `WM_COPYDATA` 把 argv 转发给运行中的实例，`FlutterWindow.MessageHandler` 立即 `channel_->InvokeMethod("openBook", arg)`。

但 Dart 端 `BookOpenBridge.init` 中 `setMethodCallHandler` 注册的时机晚于 `WM_COPYDATA` 到达（Flutter engine 启动后几百毫秒窗口）。若消息在这个窗口内到达，`InvokeMethod` 静默丢弃。

冷启动工作正常，因为 entry-point arguments 走另一条路径（`main.dart` 的 `argv` 参数）。

### 修复

3 层缓存机制：

1. **C++ 层（T2）**：`FlutterWindow` 新增 `cached_argv_` 字段，`WM_COPYDATA` 处理器无论 `channel_` 是否就绪都缓存载荷，再尝试 InvokeMethod（即使静默失败也有备份）
2. **C++ ↔ Dart 桥（T2）**：新增专用 `dev.zhiyue.bookopen.argv` MethodChannel + `popPendingArgv` 处理器（不用 `dev.zhiyue.bookopen` 是因为该 channel 已被 Dart-side `openBook` handler 占用，MethodChannel 只允许一个 handler）
3. **Dart 层（T3）**：`BookOpenBridge.init` 在 `popPendingBookPath`（Android）之后调用 `popPendingArgv` 排空 C++ 缓存

即使 `WM_COPYDATA` 在 engine 启动期间到达，Dart 端 `init` 时也会从缓存中取回 argv 并正常导入。

## 用户测试步骤

### 测试 1：TTS 多声音选择（Android）

1. 装 v1.14.0-alpha APK
2. 打开任意书 → 朗读某章 → 暂停
3. 设置 → 朗读 → 「朗读声音」tile
4. **应看到列表**（条数取决于 ROM，华为/荣耀 1 个，小米 1-2 个，Pixel 10+）
5. 点某个声音的 `▶` 试听 → **应听到该声音朗读测试句**
6. 选某个声音 → 回到阅读页 → 点朗读 → **应用新声音**
7. 重启 app → 设置 → 朗读 → 「朗读声音」→ **应保留上次选择**

### 测试 2：TTS 多声音选择（Windows）

1. 装新的 zhiyue.exe（v1.14.0-alpha）
2. 设置 → 朗读 → 「朗读声音」
3. **应看到 5+ 个声音**（默认 Windows 自带 Microsoft Huihui/Yaoyao/Kangkang 等）
4. 选不同声音 → 朗读 → **应用新声音**

### 测试 3：设为默认阅读器（Windows）

1. **全新安装** v1.14.0-alpha（或删除 `%APPDATA%\zhiyue\app_settings.json` 模拟首次启动）
2. 启动 app
3. **应弹「设为默认阅读器？」dialog**
4. 点「设为默认」 → dialog 关闭
5. 关闭 app
6. 在文件管理器双击任意 .epub → **应直接用智阅打开**（不再弹"选择应用"）
7. 重启 app → **不应再弹** dialog（已标记 promptedDefaultReader=true）

### 测试 4：设为默认阅读器（Android）

1. **全新安装** v1.14.0-alpha
2. 启动 app
3. **应弹 dialog**，但主按钮是「打开系统设置」（不是「设为默认」）
4. 点「打开系统设置」 → 跳到系统「默认应用」页面
5. 手动把智阅设为 .epub 默认 → 返回 app
6. 重启 app → **不应再弹**

### 测试 5：Android deep-link 导入（P0 修复）

1. 用任意文件管理器（如小米文件管理、Solid Explorer）
2. 找一个 .epub 文件 → 点 → 选「用智阅打开」
3. **应正常打开并加入书架**（不再出现乱码页面）
4. 智阅在后台运行 → 重复步骤 2 → **仍应正常打开**

### 测试 6：Windows 热启动 deep-link（P1 修复）

1. 启动智阅（让它保持运行）
2. 在文件管理器双击 .epub 文件
3. **应正常导入到运行中的智阅实例**（不是启动新实例）
4. 重复测试 → **每次都应正常**（不丢消息）

## 升级路径

直接装 v1.14.0-alpha 覆盖 v1.13.x-alpha。

- drift schema v15 不变（无 DB 迁移）
- TTS 设置（rate/pitch/volume）保留；voiceId 是新字段，老配置文件 `fromJson` 容错缺失字段
- `app_settings.json` 是新文件，首次启动自动创建
- versionCode 2009 > v1.13.11 的 2008

## Breaking Change

无。

## 已知限制

- iOS/macOS/Linux 不支持多声音选择（VoiceListPage 仍可进入但列表为空）
- Android 设备实际可用声音取决于 ROM 和用户安装的 TTS 引擎；某些 ROM（如华为）只暴露 1 个声音
- HKCU 写注册表可能被严格 anti-virus 拦截；set_default_reader 失败时 dialog 会自动关闭，用户可重试
- `app_settings.json` 不跨设备同步（设备本地行为）
