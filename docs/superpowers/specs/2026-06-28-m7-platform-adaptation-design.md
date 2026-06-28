# M7 平台适配设计 Spec

**Date**: 2026-06-28
**Status**: Approved (architecture, components, data flow, testing)
**Author**: brainstorming session w/ user
**Tag target**: `m7-complete` + `v0.4.0`

## 1. 目标

把智阅从 Flutter 默认脚手架配置升级为 Android + Windows 双端「平台适配就绪」状态 —— 含应用图标、显示名、文件关联（含 deep-link 冷启动打开）、Android 签名、Windows 窗口打磨、版本号。

**MVP 1.0 路线图中的位置**：
- M0–M4 已交付（数据层 + EPUB 阅读器 + 高亮笔记 + PDF 阅读器）
- M7：平台适配 → tag `v0.4.0`
- M8：发布打包（Inno Setup + Gitee Release + README）→ tag `v0.5.0`
- 测试/打磨后 → tag `v1.0.0`（不在本 sprint 范围）

## 2. 现状盘点

| 项 | 当前 | 目标 |
|---|---|---|
| Android applicationId | `dev.zhiyue.zhiyue` ✓ | 保持 |
| Android app label | `zhiyue` | `智阅` |
| Android intent-filter | 仅 MAIN+LAUNCHER | 加 VIEW epub/pdf |
| Android release signing | debug 复用 | release keystore（gitignored） |
| Android permissions | 默认 | 评估是否需 INTERNET |
| Windows title bar | `zhiyue` | `智阅` |
| Windows runner info | 默认 Flutter | FileDescription / ProductName / Version 同步 |
| Windows file assoc | 无 | M7 在 Runner.rc 占位，M8 Inno Setup 注册 |
| App icon | 默认 Flutter | 1024×1024 主图 → flutter_launcher_icons |
| pubspec version | `0.1.0+1` | `0.4.0+1` |
| 文件 deep-link | 无 | Android MethodChannel + Windows argv[1] |

## 3. 架构决策

### 3.1 Deep-link 完整做（不拆 M7/M8）

**决策**：M7 包含 native bridge + 路由跳转，不只注册文件类型。

**Why**：注册文件类型但不自动打开 = 破碎 UX（用户点击「用智阅打开」→ app 启动 → 空白 library → 困惑）。Native bridge 仅 3 行 Kotlin + 3 行 C++，复杂度可控。

**How**：
- Android：`MainActivity.onCreate` / `onNewIntent` 提取 `intent.data` → MethodChannel 推送
- Windows：`main.cpp` 解析 `argv[1]`（如存在）→ MethodChannel 推送
- Dart：`BookOpenBridge` 监听 MethodChannel → 调用现有 `BookImportService.importFromFile` → 路由到 reader

### 3.2 不做 Android 12 splash + backup rules

**决策**：Android 12 SplashScreen API（`<style>` + `postSplashScreenTheme`）和 `dataExtractionRules.xml` 推到 M8 或 v1.0 打磨。

**Why**：M7 核心价值是「能分发」，splash/backup 是「体验优化」。M7 优先保证可分发 + 文件 deep-link 可用。

### 3.3 Signing：本地 keystore + .env 风格 keystore.properties

**决策**：`app/keys/zhiyue-release.jks` + `app/keys/keystore.properties` 全部 gitignored，`build.gradle.kts` 读取时 fallback 到 debug。

**Why**：
- Self-signed 对 sideload APK 完全够用（不上 Play Store）
- 不入仓 = 密钥不泄漏
- Fallback debug = 团队成员无需 keystore 也能 build debug

### 3.4 Icon pipeline：flutter_launcher_icons

**决策**：用 `flutter_launcher_icons` 包从单张 1024×1024 主图自动生成 Android 各 mipmap + iOS（暂跳）+ Windows .ico。

**Why**：
- 单一来源 → 生成多分辨率，避免手工维护 N 个 mipmap
- 配置文件版本控制可复现
- iOS 暂跳（M7 不含 iOS，但生成配置预留）

## 4. 组件分解

### 4.1 App icon pipeline

**新文件**：
- `app/assets/icon.png` (1024×1024，用户 AI 生成)
- `app/flutter_launcher_icons.yaml`

**修改**：
- `app/pubspec.yaml` dev_dependencies 加 `flutter_launcher_icons: ^0.14.3`

**AI 生图提示词**（用户喂给 Midjourney / DALL-E / SD）：
```
A minimalist mobile app icon for an e-book reader called "智阅" (ZhiYue,
meaning "wise reading"). 1024x1024 square. Design: a single open book
silhouette in deep ink blue (#1a3a6c) on a warm cream background (#f5f0e8),
with a subtle crescent moon merged into the book's pages suggesting
night/contemplative reading. Flat design, no text, no shadows, no gradient.
Centered, with 10% padding from edges. Material You aesthetic. Vector-like
clean lines, looks good at 48x48 px.
```

**生成命令**：`cd app && dart run flutter_launcher_icons`

### 4.2 Display name

**修改**：
- `app/android/app/src/main/AndroidManifest.xml`: `android:label="智阅"`
- `app/windows/runner/Runner.rc`: `FileDescription "智阅"`、`ProductName "智阅"`
- `app/windows/runner/flutter_window.cpp`: window title `"智阅"`

### 4.3 Android intent-filter

加在 `<activity>` 内（保留现有 MAIN+LAUNCHER）：
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="content"/>
    <data android:scheme="file"/>
    <data android:mimeType="application/epub+zip"/>
    <data android:mimeType="application/pdf"/>
    <data android:pathPattern=".*\\.epub"/>
    <data android:pathPattern=".*\\.pdf"/>
</intent-filter>
```

### 4.4 Native deep-link bridge

**Android `MainActivity.kt`**：
```kotlin
class MainActivity : FlutterActivity() {
    private val CHANNEL = "dev.zhiyue.bookopen"
    private var pendingBookPath: String? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        // 处理 cold start
        intent.data?.let { uri -> pendingBookPath = uriToPath(uri) }
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "popPendingBookPath" -> {
                    result.success(pendingBookPath)
                    pendingBookPath = null
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.let { uri ->
            val path = uriToPath(uri)
            if (path != null) methodChannel?.invokeMethod("openBook", path)
        }
    }

    private fun uriToPath(uri: Uri): String? {
        return when (uri.scheme) {
            "file" -> uri.path
            "content" -> copyToCache(uri)  // content URI 需先拷贝到 cache 再传路径
            else -> null
        }
    }
    // copyToCache 实现：从 contentResolver.openInputStream 读取，写入 cacheDir，返回路径
}
```

**Windows `main.cpp`**（新增 argv 解析 + 推送）：
```cpp
int APIENTRY wWinMain(...) {
    // ... Flutter 启动 ...
    int argc;
    auto argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    std::string first_arg;
    if (argc > 1) {
        // Convert wide char to UTF-8
        first_arg = wideToUtf8(argv[1]);
    }
    LocalFree(argv);

    // 在 Flutter engine 启动后通过 MethodChannel 推送
    // 实现细节 spike 后定（flutter_window.cpp 或 main.cpp）
}
```

**Dart `app/lib/services/book_open_bridge.dart`**：
```dart
class BookOpenBridge {
  static const _channel = MethodChannel('dev.zhiyue.bookopen');

  static Future<void> init({
    required ReaderRouter router,
    required BookImportService importer,
  }) async {
    // 1. 启动时主动询问 native 是否有 pending book path（cold start）
    final coldPath = await _channel.invokeMethod<String>('popPendingBookPath');
    if (coldPath != null) await _importAndOpen(coldPath, router, importer);

    // 2. 监听 warm start 推送
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openBook') {
        final path = call.arguments as String;
        await _importAndOpen(path, router, importer);
      }
    });
  }

  static Future<void> _importAndOpen(
    String path, ReaderRouter router, BookImportService importer,
  ) async {
    if (!_isSupported(path)) return;
    final book = await importer.importFromFile(path);
    router.go('/reader/${book.id}');
  }
}
```

### 4.5 Android signing

**新文件**（gitignored）：
- `app/keys/zhiyue-release.jks`
- `app/keys/keystore.properties`（含 `storePassword` / `keyAlias` / `keyPassword` / `storeFile`）

**修改 `app/android/app/build.gradle.kts`**：
```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("keys/keystore.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ...
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}
```

**`.gitignore`**：
```
app/keys/*.jks
app/keys/keystore.properties
```

**本地生成命令**（写入 README，不执行）：
```bash
keytool -genkey -v -keystore app/keys/zhiyue-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias zhiyue
```

### 4.6 Version bump

- `app/pubspec.yaml`: `version: 0.4.0+1`
- `app/windows/CMakeLists.txt`: `VERSION 0.4.0` 同步

## 5. 数据流：文件 deep-link

```
[File Explorer / Android Files app]
    │ 用户点击 book.epub
    ▼
[OS 文件类型注册表匹配智阅]
    │
    ├─ Android: Intent.ACTION_VIEW + content://... → MainActivity.onCreate/onNewIntent
    │       │
    │       └─→ MethodChannel("dev.zhiyue.bookopen")
    │              .invokeMethod("openBook", absolutePath)
    │
    └─ Windows: argv[1] = "C:\\path\\book.epub" → main.cpp 提取
            │
            └─→ MethodChannel 推送 absolutePath
    ▼
[Dart: BookOpenBridge.listen()]
    │ 收到 path → 验证 .epub / .pdf 扩展
    ▼
[BookImportService.importFromFile(path)]
    │ 复用 M3.1 现有导入流程（format 自动检测 / 元数据 / 封面）
    ▼
[go_router push /reader/$bookId]
    ▼
[Reader 打开]
```

## 6. 错误处理

| 场景 | 处理 |
|---|---|
| Android content:// URI 无读权限 | `contentResolver.openInputStream` 失败 → log + 静默忽略 |
| Windows argv[1] 是文件夹 / 不存在 | 路径检查失败 → 静默忽略 |
| 文件扩展名不在 .epub/.pdf 白名单 | BookOpenBridge 跳过，不调 importer |
| 导入过程异常（损坏 epub 等） | 复用 BookImportService 现有 try/catch → SnackBar 报错 |
| 用户在 reader 内时点新文件 | push 新 /reader/$id（保留返回栈），不 replace |
| Cold start 收到 path 但 router 尚未就绪 | BookOpenBridge 等 scaffold mounted 后再触发（用 completer / post-frame） |

## 7. 测试策略

### Unit tests（纯 Dart）

- `BookOpenBridge`：
  - 收到 mock MethodChannel `openBook` 调用 → 验证 `BookImportService.importFromFile` 收到正确 path
  - 收到非白名单扩展 → 静默忽略，不调 importer
  - 收到 cold-start `popPendingBookPath` 返回值 → 同样路由到 reader
- 路径校验：绝对路径转换、白名单匹配函数

### Integration tests（`app/integration_test/`）

- Mock 一个文件 URI（用真 fixture epub/pdf）→ `BookOpenBridge` 注入 → 验证路由跳到 `/reader/$id`
- Warm-start：bridge 已 init → 第二次 MethodChannel 推送 → 验证不重复导入相同 path（按 path 去重或按 BookImportService 现有去重逻辑）

### Native 代码

- Kotlin：无单测，仅代码审查（MethodChannel 模板代码 ~30 行）
- C++：无单测，仅代码审查（argv 解析 ~20 行）
- 手动 smoke test：
  - `flutter build apk --release` → adb install → 文件管理器点 .epub → 验证启动并打开
  - `flutter build windows --release` → 双击 .exe（带 argv）→ 验证打开

### Icon pipeline

- 运行 `flutter_launcher_icons` 后，所有 `app/android/app/src/main/res/mipmap-*/ic_launcher.png` 存在
- `app/windows/runner/resources/app_icon.ico` 存在且非零字节

### Signing

- `flutter build apk --release`（keystore.properties 存在）→ `apksigner verify --verbose` 通过
- `flutter build apk --debug`（无 keystore）→ debug fallback 仍可构建

## 8. 不在 M7 范围

- Inno Setup 脚本 → M8
- Gitee Release 上传 → M8
- README 更新 + 截图 → M8
- Android 12 SplashScreen API → M8 或 v1.0 打磨
- Android 12 dataExtractionRules / fullBackupContent → M8 或 v1.0 打磨
- ProGuard / R8 收缩（APK 体积优化）→ v1.0 打磨
- iOS（M7 跳 Mac）
- macOS（M7 跳）
- CI/CD（用户选了仅本地手动 build）
- APK 拆分 ABI / App Bundle（不上 Play Store 不需要）

## 9. 任务估算（plan 阶段细化）

预估 ~10-12 个 TDD 任务（T0–T11/T12），按以下顺序：

1. T0：基础设施（flutter_launcher_icons 依赖、配置文件、.gitignore）
2. T1：Display name 改「智阅」（Android + Windows）
3. T2：icon 资产占位 + flutter_launcher_icons 运行（用户用 AI 生图后填入）
4. T3：版本号 bump 0.4.0
5. T4：Android signing keystore 配置（不含生成密钥，仅 build.gradle.kts 改造）
6. T5：Android intent-filter 加 VIEW epub/pdf
7. T6：Dart BookOpenBridge 骨架 + unit tests
8. T7：Android MainActivity.kt native bridge
9. T8：Windows main.cpp / flutter_window.cpp argv 解析
10. T9：BookOpenBridge 接入 main.dart 启动流程 + integration test
11. T10：手动 smoke test 文档（README 段落）
12. T11：tag `m7-complete` + `v0.4.0` + push

## 10. 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| Android content URI 处理（cache 拷贝）复杂度超预期 | 中 | 中 | plan 里 spike + 单独任务覆盖 |
| Windows argv wide-char → UTF-8 转换坑 | 中 | 低 | 用 Windows API `WideCharToMultiByte`，C++ 标准 |
| flutter_launcher_icons 配置兼容性问题 | 低 | 低 | 配置简单，文档清晰 |
| Cold start 时机问题（router 未就绪） | 中 | 中 | 用 `WidgetsBinding.instance.addPostFrameCallback` 等首帧后触发 |
| 用户没生成 icon → T2 阻塞 | 低 | 低 | T2 设计成「不依赖实际图标也能跑」，icon 可后补 |
