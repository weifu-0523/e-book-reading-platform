# 「直接打开电子书」+「设为默认阅读器」 Design

**Date:** 2026-07-19
**Version target:** v1.14.0-alpha（与 TTS multi-voice 合并发布）
**Type:** Bug fix + UX enhancement
**Scope:** Cross-platform (Android + Windows)

## 1. Background & Motivation

### 用户反馈

2026-07-19 用户报告：

> 在手机中 epub 电子书点击是有推荐使用咱们的软件打开，结果出现乱码，必须在软件中书架中添加才可以导入电子书。这问题就是不能直接用我们的软件打开电子书，必须要通过书架导入，我的想法是可以直接打开电子书，如果是新书就直接添加到书架。

> 电脑端也要这个效果。智阅软件开启状态，我们选择 epub 电子书，选择使用智阅打开，没有反应，但如果软件关闭，选择打开，可以正常打开，并添加到书架。同时我希望，在打开我们软件时，可以提示将我们的软件设为默认阅读器。

### 当前状态

**Android（M7 起接的 deep-link）：**
- `AndroidManifest.xml:60-72` 注册 `ACTION_VIEW` 接收 `content://` / `file://` + `.epub` / `.pdf`
- `MainActivity.kt:144-163` `uriToPath` 把 `content://` 复制到 cacheDir 作为 `import_${timestamp}.book`（**bug 源头**）
- `MainActivity.kt:79-82` `popPendingBookPath` 给 Dart cold start 用
- `MainActivity.kt:130-139` `onNewIntent` 给 Dart warm start 用（method channel `openBook`）
- `book_open_bridge.dart` 统一处理 Android + Windows 路径
- `book_import_service.dart:56` 导入逻辑（cold/warm 共用）
- `main.dart:148-158` 注入 onError → SnackBar「打开书籍失败：...」

**Windows（M8 起接的 single-instance + argv）：**
- `windows/runner/main.cpp:135-186` 单实例 mutex + `FindZhiYueWindow` + WM_COPYDATA 转发 argv
- `windows/runner/flutter_window.cpp:96-109` 接 WM_COPYDATA → `channel_->InvokeMethod("openBook", arg)` → Dart
- `windows/installer/zhiyue.iss:53-62` Inno Setup 注册 `.epub` / `.pdf` 文件关联到 `zhiyue.exe`
- 用户报告：**cold start 工作，warm start 「没反应」**

## 2. Goal & Non-Goals

### Goal

- **Android**：从文件管理器 / 微信 / 浏览器下载等入口点击 `.epub` / `.pdf`，选「用智阅打开」→ 自动导入书架 + 跳转 reader（新书）/ 直接跳 reader（已存在）
- **Windows**：双击 `.epub` / `.pdf` → 智阅已运行时也自动导入 + 跳转 reader（修 warm start bug）
- **新功能**：首次启动检测智阅未设为系统默认 `.epub` / `.pdf` 阅读器 → 弹 dialog「设为默认？」→ 用户同意后写注册表 / 跳系统设置

### Non-Goals

- **不实现自定义 URI scheme** (`zhiyue://book/<id>`)——M8 已声明但未启用，本版不动
- **不处理 iOS / macOS**——当前没有 iOS build（M-mobile-s1 起 Android 优先）
- **不引入「在所有支持的格式中只关联 .epub 还是 .pdf 还是都关联」的细粒度选择**——首次 dialog 是「全部」或「否」二选一
- **不修复「文件名含中文 URL encoding」**——这是另一个潜在 bug，本版不处理（修复 1 的扩展名提取会从 lastPathSegment 拿，已自动 decode）
- **不重新设计 file picker 内部导入流程**——内部「添加到书架」按钮已工作，不动

## 3. Architecture

### Bug 1 修复：Android `copyContentToCache` 保留原扩展名

```kotlin
// MainActivity.kt
private fun copyContentToCache(uri: Uri): String? {
    return try {
        val extension = inferExtensionFromUri(uri)
        val tempFile = File(cacheDir, "import_${System.currentTimeMillis()}${extension}")
        val input = contentResolver.openInputStream(uri) ?: return null
        tempFile.outputStream().use { output ->
            input.use { it.copyTo(output) }
        }
        tempFile.absolutePath
    } catch (e: Exception) {
        null
    }
}

/// 从 URI 推断支持的电子书扩展名（含点号，如 ".epub"）；无法识别返回 ""。
/// 优先从 URI lastPathSegment 取（文件管理器通常带原始文件名），
/// fallback 用 ContentResolver.getType() 的 MIME type 推断。
private fun inferExtensionFromUri(uri: Uri): String {
    val supportedExt = listOf(".epub", ".pdf", ".txt", ".md", ".markdown", ".mdown")

    // 1. lastPathSegment 通常含原始文件名（content://media/external/file/123/三体.epub）
    val last = uri.lastPathSegment ?: ""
    val dot = last.lastIndexOf('.')
    if (dot >= 0) {
        val ext = last.substring(dot).lowercase()
        if (ext in supportedExt) return ext
    }

    // 2. fallback: MIME type
    val mime = try { contentResolver.getType(uri) } catch (_: Exception) { null }
    return when (mime) {
        "application/epub+zip" -> ".epub"
        "application/pdf" -> ".pdf"
        "text/plain" -> ".txt"
        "text/markdown" -> ".md"
        else -> ""
    }
}
```

**影响范围：** 只改一个文件、两个方法。`uriToPath` 不变（已正确分发 file/content）。

### Bug 2 修复：Windows warm start argv 转发加固

**当前代码已写完整**（`main.cpp` + `flutter_window.cpp`），但用户报告"没反应"。诊断假设：

1. **C++ 端 channel_->InvokeMethod 在 Dart handler 注册前发出 → 丢失**
2. **C++ 端 IsSupportedBookPath 预过滤可能因路径含 UTF-8 中文 + 字节级比较误判**（实际上扩展名 `.epub` 是 ASCII，不受中文影响——但需要验证）

**修复策略：模仿 Android `popPendingBookPath` 模式——C++ 端缓存 argv，Dart 主动拉。**

```cpp
// flutter_window.h - 加 cached_argv_ 字段
class FlutterWindow : public Win32Window {
  // ...
private:
  std::string cached_argv_;  // ← NEW: 缓存最近一次 WM_COPYDATA 收到的 argv
};

// flutter_window.cpp MessageHandler - 接收时缓存 + 同步 invoke
if (message == WM_COPYDATA) {
  auto* cds = reinterpret_cast<COPYDATASTRUCT*>(lparam);
  if (cds != nullptr && cds->dwData == kCopyDataArgvTag) {
    std::string arg(reinterpret_cast<const char*>(cds->lpData),
                    cds->cbData > 0 ? cds->cbData - 1 : 0);
    cached_argv_ = arg;  // ← 缓存（无论 IsSupportedBookPath 是否过）
    if (channel_) {
      channel_->InvokeMethod("openBook",
          std::make_unique<flutter::EncodableValue>(arg));
    }
  }
  return 0;
}

// 新增 method call handler - 让 Dart 主动拉缓存（启动后调）
// OnCreate 里：
channel_->SetMethodCallHandler(
  [this](const flutter::EncodableValue& call) {
    // 处理 "popPendingArgv" method
    // 返回 cached_argv_，清空缓存
  });
```

**Dart 侧 `book_open_bridge.dart` 加 Windows cold-start 路径：**

```dart
static Future<void> init({...}) async {
  // 1. argv (Windows cold start - first instance process)
  for (final arg in argv) { ... }  // 已存在

  // 2a. Android popPendingBookPath
  try {
    final pending = await _channel.invokeMethod<String>('popPendingBookPath');
    // ...
  } catch (_) {}

  // 2a-bis. NEW: Windows popPendingArgv (warm start argv cached in C++)
  try {
    final cached = await _channel.invokeMethod<String>('popPendingArgv');
    if (cached != null && cached.isNotEmpty && isSupportedBookPath(cached)) {
      await handlePath(path: cached, ...);
    }
  } catch (_) {
    // Non-Windows / channel not yet registered → ignore
  }

  // 2b. Warm start listener (already exists)
  _channel.setMethodCallHandler(...);
}
```

**关键不变量：** `popPendingArgv` 必须在 Dart `setMethodCallHandler` 之前调（避免 race），但要在 channel 注册之后（避免 MissingPluginException）。`BookOpenBridge.init` 的执行顺序已是这个顺序（cold pop → set handler）。

### 新功能 3：「设为默认阅读器」首次启动提示

#### 检测逻辑

**Windows：** 读注册表 `HKCU\Software\Classes\.epub\shell\open\command` 默认值，检查是否含 `zhiyue.exe`：

```dart
// WindowsDefaultReaderDetector
static Future<bool> isRegisteredForExtension(String ext) async {
  // 通过 MethodChannel 调 C++ 端读注册表（HKCU 不需 admin）
  // HKCU\Software\Classes\.epub\shell\open\command
  // 返回值是 ""zhiyue.exe" "%1"" 之类的字符串
  final result = await _channel.invokeMethod<String>(
    'readAssoc', {'ext': ext});
  return result != null && result.contains('zhiyue.exe');
}
```

**Android：** 没有可靠的「检查当前默认」API（API 24+ `RoleManager` 只支持 browser/sms/dialer 等系统角色）。**只能跳系统设置让用户选**——所以 Android 不主动检测，只在用户点「设为默认」按钮时跳转。

#### 设置写入

**Windows：** 写 HKCU 注册表（不需 admin）。复用 Inno Setup 已有的注册逻辑（zhiyue.iss:53-62），但首次启动 dialog 时通过 MethodChannel 让 C++ 端写：

```cpp
// FlutterWindow.cpp OnCreate 加 channel handler
channel_->SetMethodCallHandler(
  [this](const flutter::EncodableValue& call, flutter::Auto windingMethodResult result) {
    if (call is "set_default_reader") {
      // 写 HKCU\Software\Classes\.epub + .pdf → zhiyue.exe "%1"
      // SHChangeNotify(SHCNE_ASSOCCHANGED) 通知资源管理器刷新
    }
  });
```

**Android：** 跳系统设置（BROWSABLE + ACTION_DEFAULT）：

```kotlin
"openDefaultAppsSettings" -> {
    val intent = Intent(android.provider.Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    context.startActivity(intent)
    result.success(true)
}
```

#### UI 流程（首次启动 dialog）

```
启动 app
  ↓ (PostFrameCallback)
检查「设为默认」偏好（持久化标志，已问过就不再问）
  ↓ 未问过
检测系统注册情况（Windows: 调 readAssoc；Android: 始终视为「未设」）
  ↓ 未设
显示 dialog：
┌───────────────────────────────────────┐
│ 设为默认阅读器                          │
│                                       │
│ 是否将智阅设为 .epub / .pdf 默认阅读器？│
│ 后续双击这些文件将自动用智阅打开。       │
│                                       │
│              [稍后再说]  [设为默认]    │
└───────────────────────────────────────┘
```

- 用户点「设为默认」→ Windows: 调 `set_default_reader` 写注册表 + `SHChangeNotify`；Android: 跳系统「默认应用」设置（用户手动选）
- 用户点「稍后再说」→ 写偏好 `prompted_default_reader=true`（不再问）
- 用户关闭 dialog（点外部 / ESC）→ 同「稍后再说」

#### 偏好持久化

加 `app_settings.json`（或复用现有 SharedPreferences / flutter_secure_storage）：

```json
{
  "promptedDefaultReader": true,
  "isDefaultReader": false  // Windows 实际状态缓存（每次启动重检测）
}
```

#### 设置页入口（兜底）

「设置 → 通用」加新条目「设为默认阅读器」，点击：
- Windows: 直接调 set_default_reader（覆盖式）
- Android: 跳系统「默认应用」设置

## 4. UI Design

### 首次启动 dialog（Windows）

```
┌───────────────────────────────────────┐
│  智阅                                  │
│                                       │
│  [icon]  设为默认阅读器？               │
│                                       │
│  将智阅设为 .epub 和 .pdf 文件的默认    │
│  阅读器，后续双击这些文件将自动用智阅    │
│  打开并加入书架。                       │
│                                       │
│  ☐ 不再提示                            │
│                                       │
│              [稍后再说]  [设为默认]    │
└───────────────────────────────────────┘
```

### 首次启动 dialog（Android）

```
┌───────────────────────────────────────┐
│  智阅                                  │
│                                       │
│  [icon]  设为默认阅读器？               │
│                                       │
│  在系统「默认应用」设置里将智阅设为      │
│  .epub 文件的默认打开方式。            │
│                                       │
│  [取消]                [打开系统设置]  │
└───────────────────────────────────────┘
```

### 设置页入口

「设置 → 通用」：

```
通用
├─ 语言                   简体中文 ▼
├─ 主题                   跟随系统 ▼
└─ 设为默认阅读器         [打开] →   ← NEW（Windows 显示状态：已设/未设）
```

## 5. Persistence

### 首次启动偏好

加到现有 `app/lib/features/settings/...`：

```dart
class AppSettings {
  final bool promptedDefaultReader;  // 已问过？
  // ...
}
```

持久化到 `app_settings.json`（与 typography / tts_settings 同目录，按 [[feedback-no-dispose-time-fire-and-forget]] 即时落盘）。

### Windows 注册表（系统级）

`HKCU\Software\Classes\.epub` (默认) = `"ZhiYue.Book"`
`HKCU\Software\Classes\.epub\shell\open\command` (默认) = `""C:\path\to\zhiyue.exe" "%1""`

Inno Setup 安装时已写一遍（machine-level HKLM）；用户首次启动 dialog 时再写 HKCU（user-level，覆盖 HKLM）。`SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr)` 通知资源管理器刷新图标。

### Android 系统设置

无注册表概念。用户在系统「默认应用」选智阅后，系统记 `package-restricted` 数据库。智阅侧只在 `promptedDefaultReader` 偏好里记录"已问过"。

## 6. Error Handling

### Android 扩展名推断失败

- `inferExtensionFromUri` 返回空字符串 → tempFile 用 `import_${timestamp}`（无扩展名）
- `BookOpenBridge.isSupportedBookPath` false → early return（不导入）
- main.dart onError SnackBar 显示「打开书籍失败：不支持的文件格式」

**改进：** 同时显示原始 URI 让用户反馈。可选，不在本版范围。

### Windows WM_COPYDATA 时序竞争

- 第二实例在 Dart handler 注册前发 WM_COPYDATA → C++ 端 cached_argv_ 缓存
- Dart init 调 `popPendingArgv` → 拿到缓存 → handlePath
- **如果 Dart 已经在处理中又收到第二个 WM_COPYDATA** → cached_argv_ 被覆盖（最后一个 wins）

**接受最后 wins 语义**：用户连续点两个 EPUB，最后那个 wins 是合理的（先打开的会过几秒自动加载）。

### 注册表写入失败

- C++ 端 `RegSetValueExW` 失败 → 返回 false → Dart dialog 显示「设置失败，请稍后再试」
- 偏好不写 `promptedDefaultReader=true`（下次启动再问）

## 7. TDD Task Decomposition

| Task | Scope | 测试 |
|---|---|---|
| **T1** | `MainActivity.inferExtensionFromUri` 新方法 + `copyContentToCache` 使用 | Robolectric test：5 个 URI 样本（含中文文件名 / MIME fallback / 无扩展名 / 不支持扩展名 / file:// scheme）→ 正确推断扩展名 |
| **T2** | `flutter_window.cpp` WM_COPYDATA handler 加 cached_argv_ 缓存 + `popPendingArgv` method handler | C++ 单元测试（已有 test_main.cpp 框架）：verify 接收 WM_COPYDATA 后 InvokeMethod 调用 + cached_argv_ 持有值；popPendingArgv 返回缓存并清空 |
| **T3** | `book_open_bridge.dart` 加 Windows popPendingArgv 路径（warm start cold pop） | Dart 单测：mock MethodChannel，verify invokeMethod 'popPendingArgv' 调用 + handlePath 触发（3 测试：有缓存/无缓存/unsupported path） |
| **T4** | Windows `readAssoc` / `set_default_reader` MethodChannel handlers（C++ 端读写 HKCU 注册表） | C++ 单元测试：set + read round-trip + SHChangeNotify 不抛错 |
| **T5** | Android `openDefaultAppsSettings` MethodChannel handler | Robolectric test：verify Intent action 正确 |
| **T6** | Dart `DefaultReaderDetector` 抽象 + Win/Android 实现 + `AppSettings.promptedDefaultReader` 持久化 | Dart 单测：toJson/fromJson round-trip + 平台 dispatch |
| **T7** | 首次启动 dialog widget（`DefaultReaderPromptDialog`）+ 设置页入口 | Widget test：用户同意/拒绝/关闭 dialog 各路径 + 持久化 |
| **T8** | Release v1.14.0-alpha（与 TTS multi-voice plan 合并） | 全量 flutter test + Robolectric + APK + Windows installer + tag push |

## 8. Risks

1. **`contentResolver.getType(uri)` 在部分 ROM 返回 null**（华为小艺引擎的 file:// scheme）→ MIME fallback 失效 → 用 lastPathSegment 取扩展名（fallback 链上层）。Risk: 低。
2. **`uri.lastPathSegment` 在某些 content provider 不含扩展名**（如 `content://media/external/file/123`）→ 两个 fallback 都失败 → tempFile 无扩展名 → 不导入 → onError SnackBar。Risk: 低（用户能感知失败 + 错误消息）。
3. **Windows HKCU 写注册表被 antivirus 拦截**（部分国产 AV 对注册表写入敏感）→ set_default_reader 返回 false → dialog 显示失败提示。Risk: 低。
4. **Windows 已有其他阅读器（如 Adobe / Kindle）占用 `.epub`**→ HKCU 写入覆盖 → 之前阅读器失效。**这是用户期望行为**（用户主动点了「设为默认」）。Risk: 设计预期内。
5. **Android 系统设置页跳转 ROM-specific**（华为/小米可能没有 ACTION_MANAGE_DEFAULT_APPS_SETTINGS）→ catch ActivityNotFoundException → 显示 toast「请手动到系统设置 → 默认应用」。Risk: 中（需 fallback）。
6. **WM_COPYDATA payload 大小限制**（Windows 限制 ~64KB）→ 文件路径通常 < 1KB，无风险。
7. **Inno Setup 已写的 HKLM 与 dialog 写的 HKCU 冲突**：HKCU 优先级高于 HKLM，用户级覆盖机器级 → 行为一致。Risk: 无。

## 9. Verification

### 单元测试

- Dart: `cd C:\zhiyue_build_s3 && flutter test` 预期 ~1720 pass（v1.13.11 是 1676 + TTS multi-voice 加的 ~19 + 本 spec 加的 ~15）
- Kotlin Robolectric: `./gradlew :app:testWithFgsDebugUnitTest` 预期 ~38 pass（+5 新测试）
- C++ Smoke: `app\windows\runner\run_smoke_test.bat` 预期 PASS（test_main.cpp + 新加的 copydata/registry 测试）

### 用户真机验证（手工）

| 场景 | 平台 | 步骤 | 预期 |
|---|---|---|---|
| A | Android | 文件管理器点 .epub → 选智阅 | 智阅打开 + 跳 reader |
| B | Android | 微信收 .epub → 点开 → 选智阅 | 智阅打开 + 跳 reader |
| C | Android | 浏览器下载 .epub → 点下载项 → 选智阅 | 智阅打开 + 跳 reader |
| D | Android | 同一书重复打开 | 跳 reader，不重复导入（dedup by hash） |
| E | Windows | 智阅未运行 + 双击 .epub | 智阅启动 + 跳 reader |
| F | Windows | 智阅已运行 + 双击 .epub | 智阅前置 + 跳 reader（**修复目标**） |
| G | Windows | 智阅已运行 + 选 .pdf 用智阅打开 | 智阅前置 + 跳 reader |
| H | Windows | 首次启动 → dialog 弹出 → 同意 | .epub / .pdf 关联到智阅 + 不再弹 |
| I | Windows | 首次启动 → dialog 弹出 → 拒绝 | 不写注册表 + 不再弹 |
| J | Windows | 已拒绝 → 设置 → 设为默认 → 点 | 写注册表 + 状态显示「已设」 |
| K | Android | 首次启动 → dialog 弹出 → 打开系统设置 | 跳系统「默认应用」页 |
| L | Android | 系统设置页不存在（华为旧 ROM） | Toast「请手动到系统设置」 |

### APK + installer marker 验证

**新增 libapp.so marker：**

- `popPendingArgv` (Dart invokeMethod 字面值)
- `promptedDefaultReader` (Map key)
- `readAssoc` / `set_default_reader` / `openDefaultAppsSettings` (Dart invokeMethod 字面值)
- `DefaultReaderPromptDialog` 类名

**新增 classes.dex marker：**

- `inferExtensionFromUri` (Kotlin log)
- `openDefaultAppsSettings` (Kotlin method 字符串)
- `ACTION_MANAGE_DEFAULT_APPS_SETTINGS` (Kotlin 引用)

**新增 zhiyue.exe (Windows runner) marker：**

- `cached_argv_` (C++ 字段名，但 Release build 可能 strip；用日志字符串「popPendingArgv called」代替)
- `set_default_reader` / `readAssoc` (C++ channel method 字符串)
- `HKCU\Software\Classes\` (C++ log 字符串)

### 分发

- Android: `zhiyue-1.14.0-alpha-with-fgs.apk`
- Windows: `zhiyue-setup-1.14.0-alpha.exe`
- Tag: `v1.14.0-alpha` + `m-open-with-default-reader`（与 `m-tts-multi-voice` 并列 tag）
- Gitee push s4-build + master

## 10. File Structure

**新增：**

- `app/lib/features/settings/default_reader/default_reader_detector.dart` — 抽象 + Win/Android stub
- `app/lib/features/settings/default_reader/app_settings.dart` — `AppSettings.promptedDefaultReader` 持久化
- `app/lib/features/settings/default_reader/widgets/default_reader_prompt_dialog.dart`
- `app/lib/features/settings/default_reader/widgets/default_reader_settings_tile.dart`
- `app/test/features/settings/default_reader/default_reader_detector_test.dart`
- `app/test/features/settings/default_reader/app_settings_test.dart`
- `app/test/features/settings/default_reader/default_reader_prompt_dialog_test.dart`
- `app/test/services/book_open_bridge_warm_start_test.dart` — T3 测试
- `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/MainActivityExtensionInferTest.kt` — T1 测试
- `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/DefaultAppsSettingsLauncherTest.kt` — T5 测试
- `app/windows/runner/default_reader_registry.h` + `.cpp` — T4 实现（读写 HKCU）
- `app/windows/runner/test_default_reader_registry.cpp` — T4 测试
- `docs/releases/release-notes-v1.14.0-alpha.md`（与 TTS multi-voice 共用）

**修改：**

- `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/MainActivity.kt` — T1 加 `inferExtensionFromUri` + `copyContentToCache` 用它；T5 加 `openDefaultAppsSettings` handler
- `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/MainActivity.kt`（再次）— channel handler 加分支
- `app/windows/runner/flutter_window.h` — T2 加 `cached_argv_` 字段 + `popPendingArgv` handler 声明
- `app/windows/runner/flutter_window.cpp` — T2 接收 WM_COPYDATA 时缓存 + 注册 `popPendingArgv` handler；T4 加 `readAssoc` / `set_default_reader` handler
- `app/lib/services/book_open_bridge.dart` — T3 加 Windows popPendingArgv 路径
- `app/lib/main.dart` — T7 注入 DefaultReaderPromptDialog 首次启动检测
- `app/lib/features/settings/pages/settings_page.dart` — T7 加「设为默认阅读器」入口
- `app/lib/l10n/app_zh.arb` / `app_en.arb` — i18n strings
- `app/pubspec.yaml` — `1.14.0-alpha+2009`（与 TTS multi-voice 共用 versionCode）
- `CHANGELOG.md` — `[1.14.0-alpha]` 段落（合并 TTS + 本 spec 内容）
- `app/windows/installer/zhiyue.iss` — `MyAppVersion` → `1.14.0-alpha`

## 11. Open Questions

无。所有决策点已在澄清问题阶段确认。

## 12. References

- M7 平台适配 deep-link 注册 → [[project-zhiyue-m7-complete]]
- M8 Windows 单实例 + Inno Setup 文件关联 → [[project-zhiyue-m8-complete]]
- M4.6-fix6 Windows zombie mutex + takeover → `app/windows/runner/main.cpp:120-186`
- v1.11.3 删书 errno=5（content:// URI 复制相关） → [[project-zhiyue-2026-07-13-import-errno5-bug]]
- BookOpenBridge 现有架构 → `app/lib/services/book_open_bridge.dart`
- BookImportService 共用入口 → `app/lib/services/book_import_service.dart:56`
- feedback_no_dispose_time_fire_and_forget → [[feedback-no-dispose-time-fire-and-forget]]
- feedback_flutter_strip_cache_trap → [[feedback-flutter-strip-cache-trap]]
- 关联 TTS multi-voice spec → `docs/superpowers/specs/2026-07-19-tts-multi-voice-design.md`
