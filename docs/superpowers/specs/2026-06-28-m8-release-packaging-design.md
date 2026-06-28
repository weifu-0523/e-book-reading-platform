# M8 发布打包设计 Spec

**Date**: 2026-06-28
**Status**: Approved (architecture, components, data flow, error handling, testing)
**Author**: brainstorming session w/ user
**Tag target**: `m8-complete` + `v0.5.0`

## 1. 目标

把智阅从「平台适配就绪」（M7 状态）升级为「可分发的 1.0 候选版本」——双端 release artifact 产出 + Gitee Release 流程文档 + 公开 README，tag `v0.5.0`。

**MVP 1.0 路线图中的位置**：
- M0–M4 已交付（数据层 + EPUB 阅读器 + 高亮笔记 + PDF 阅读器）
- M7：平台适配 → tag `v0.4.0`
- **M8：发布打包（Inno Setup + Gitee Release + README + 真机 smoke test）→ tag `v0.5.0`**
- 测试/打磨后 → tag `v1.0.0`（不在本 sprint 范围）

## 2. 现状盘点（M7 完成态）

| 项 | 当前（v0.4.0） | 目标（v0.5.0） |
|---|---|---|
| `.github/workflows/ci.yml` | GitHub Actions（Gitee remote 不触发） | 删除 |
| Windows release artifact | 无 | Inno Setup `setup.exe` + 便携 `zip` |
| Android release artifact | 无 | 单 fat APK（真签名 + `apksigner verify`） |
| Android SDK | 本机未装 | 装到本机 + `flutter doctor` 通过 |
| 真机 deep-link smoke test | 仅 README 文档 | 实际跑通（.epub + .pdf） |
| 根 `README.md` | 中文产品 README 但状态停在 M2 | 状态刷到 M8 + 截图 + 下载安装段 |
| `app/README.md` | Flutter 模板骨架（仅加 M7 段） | 重写为开发者操作手册 |
| `dart_test.yaml` | 不存在（每次 golden test warning） | 新建，配 golden tag |
| `BookOpenBridge` 错误 UX | 静默忽略 | SnackBar（可选 onError 注入，默认行为兼容） |
| Windows 单实例 deep-link | 第二实例会启动新窗口 | 命名 mutex + `WM_COPYDATA` 透传 argv |
| `CHANGELOG.md` / `NOTICE` | 不存在 | 新建，累计 M0→M8 + 第三方版权声明 |
| pubspec version | `0.4.0+1` | `0.5.0+2` |

## 3. 架构决策

### 3.1 Windows 双分发：Installer + Zip

**决策**：Inno Setup 生成的 `setup.exe` 作为主分发渠道，便携 `zip` 作为免安装备选。

**Why**：
- Installer 注册文件关联（双击 .epub/.pdf 自动开智阅）+ 开始菜单 + 卸载项 = 用户预期体验
- Zip 兼顾「不喜欢装东西」的 power user + 便携场景（U 盘 / 公司机）
- 两个都进 Gitee Release artifacts，~80MB 总量在 Gitee 100MB 单文件限制内

### 3.2 Android 单 fat APK

**决策**：`flutter build apk --release` 默认输出（含 armeabi-v7a / arm64-v8a / x86_64），单文件分发。

**Why**：
- 不上 Play Store 不需要 App Bundle
- 单文件用户安装简单（不用选架构）
- ~30-40MB 在合理范围
- 95% Android 设备是 arm64，但保留 32-bit 兼容老设备

### 3.3 删除 GitHub Actions CI

**决策**：删除 `.github/workflows/ci.yml`。

**Why**：
- 项目 remote 在 Gitee，GitHub Actions 不会被 push 触发（除非镜像到 GitHub）
- M7 brainstorm 已定调「本地手动 build only (no Pipeline)」
- 删除后与决策一致；测试改为本地 `flutter test` + 代码审查流程

### 3.4 Android SDK 必装 + 真机 smoke test

**决策**：M8 包含本机 Android SDK 安装（M7 阻塞项），并跑通真机/模拟器 deep-link smoke test。

**Why**：
- M7 标记 release APK 签名流程「从未真跑过」为最高优先级风险
- 没有真签名 APK 就没有 Gitee Release artifact
- smoke test 验证 MethodChannel bridge + content:// 拷贝 + 路由跳转端到端正确

### 3.5 Bridge 错误回调：向后兼容

**决策**：`BookOpenBridge.init()` 新增可选 `BookOpenBridgeOptions.onError` 回调，默认行为（无回调）与 M7 完全一致。

**Why**：
- 现有 10 个单测假设静默忽略，API 改动会破坏
- onError 由调用方（main.dart）注入 SnackBar 逻辑，bridge 本身不依赖 Flutter widget 层
- 单测仍能用 mock onError 验证错误路径

### 3.6 Windows 单实例：Mutex + WM_COPYDATA

**决策**：标准 Win32 模式——命名互斥锁 `Local\ZhiYueApp` + `WM_COPYDATA` 跨进程消息。

**Why**：
- `FindWindow` 用窗口标题（含中文「智阅」），字符集坑多
- Mutex 是 Win32 推荐做法，原子检测+创建
- `WM_COPYDATA` 是 Windows 跨进程传字符串的标准 API，无需自定义 IPC

### 3.7 CHANGELOG + NOTICE + LICENSE 三件套

**决策**：根目录补齐开源分发标准文件。

**Why**：
- LICENSE（AGPLv3）已存在
- CHANGELOG.md（Keep-a-Changelog 风格，累计 M0→M8）便于 v1.0 直接发版
- NOTICE 列第三方依赖版权（Flutter / drift / pdfrx / epubx / riverpod 等 MIT/Apache），AGPLv3 合规
- Gitee Release 说明直接引用 CHANGELOG 段落

## 4. 组件分解

### 4.1 删除 CI yaml

**删除**：`.github/workflows/ci.yml`

### 4.2 Inno Setup installer 脚本

**新文件**：`app/windows/installer/zhiyue.iss`

关键段：
- `[Setup]`：`AppName=智阅`、`AppVersion=0.5.0`、`DefaultDirName={pf}\智阅`、`DefaultGroupName=智阅`、`OutputBaseFilename=zhiyue-setup-0.5.0`、`SetupIconFile=..\runner\resources\app_icon.ico`、`UninstallDisplayIcon`
- `[Files]`：`Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs`
- `[Icons]`：开始菜单 + 桌面（可选）快捷方式 → `{app}\zhiyue.exe`
- `[FileAssoc]`（Inno Setup 6+）或 `[Registry]` 手写：`.epub` / `.pdf` → `{app}\zhiyue.exe %1`
- `[Run]`：安装后可选启动
- `[UninstallDelete]`：清理 cache / settings（用户数据保留选项）

**生成命令**：`iscc app/windows/installer/zhiyue.iss`（需要 Inno Setup 6+ 已安装）

### 4.3 Android SDK 安装 + 真签名 build

**前置**：
- 安装 Android Studio 或 `sdkmanager` 命令行工具
- `sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"`
- 配置 `ANDROID_HOME` 环境变量
- `flutter doctor --android-licenses` 接受许可

**验证**：`flutter doctor` 全绿

**Release build**：
```bash
cd app
# 前置：app/android/app/keys/keystore.properties 已存在（M7 文档）
flutter build apk --release
apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

预期输出包含 `Verified using v1 scheme` / `Verified using v2 scheme`。

### 4.4 Bridge 错误回调（向后兼容）

**修改 `app/lib/services/book_open_bridge.dart`**：

```dart
class BookOpenBridgeOptions {
  final void Function(Object error, StackTrace stackTrace)? onError;
  const BookOpenBridgeOptions({this.onError});
}

class BookOpenBridge {
  // ... isSupportedBookPath 不变 ...

  static Future<void> handlePath({
    required String path,
    required BookImportService importer,
    required GoRouter router,
    BookOpenBridgeOptions options = const BookOpenBridgeOptions(),
  }) async {
    if (!isSupportedBookPath(path)) return;
    try {
      final result = await importer.importFile(File(path));
      unawaited(router.push('/book/${result.book.id}'));
    } catch (e, st) {
      options.onError?.call(e, st);
    }
  }

  static Future<void> init({
    required List<String> argv,
    required BookImportService importer,
    required GoRouter router,
    BookOpenBridgeOptions options = const BookOpenBridgeOptions(),
  }) async {
    // argv / cold start / warm start 三条路径调 handlePath 时透传 options
  }
}
```

**修改 `app/lib/main.dart`**：

```dart
// 新增全局 navigatorKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  // ...
  await BookOpenBridge.init(
    argv: args,
    importer: importer,
    router: router,
    options: BookOpenBridgeOptions(
      onError: (e, _) {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return; // UI 还没 mount，静默
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('打开书籍失败：$e')),
        );
      },
    ),
  );
  // ...
}

class ZhiYueApp extends ConsumerWidget {
  // MaterialApp.router 的 navigatorKey 注入
  // routerConfig 同时配置 navigatorKey
}
```

### 4.5 Windows 单实例（mutex + WM_COPYDATA）

**修改 `app/windows/runner/main.cpp`**：

```cpp
int APIENTRY wWinMain(...) {
  // 1. 创建命名 mutex
  HANDLE hMutex = CreateMutexW(nullptr, TRUE, L"Local\\ZhiYueApp");
  bool isFirstInstance = (GetLastError() != ERROR_ALREADY_EXISTS);

  if (!isFirstInstance) {
    // 2. 第二实例：枚举窗口找到第一实例，发 WM_COPYDATA
    HWND existing = FindZhiYueWindow();
    if (existing && argc > 1) {
      std::string arg = WideToUtf8(argv[1]);
      COPYDATASTRUCT cds = {1, arg.size() + 1, (void*)arg.c_str()};
      SendMessageW(existing, WM_COPYDATA, nullptr, (LPARAM)&cds);
    }
    CloseHandle(hMutex);
    return 0;
  }

  // 3. 第一实例：正常启动 Flutter
  // ...
}

// FindZhiYueWindow: 用 EnumWindows + GetPropW 找附加了 "ZhiYueWindowProp" 的窗口
// WideToUtf8: WideCharToMultiByte(CP_UTF8, ...)
```

**修改 `app/windows/runner/flutter_window.cpp`**（接收 `WM_COPYDATA`）：

```cpp
LRESULT FlutterWindow::MessageHandler(HWND hWnd, UINT message,
                                       WPARAM wParam, LPARAM lParam) {
  if (message == WM_COPYDATA) {
    auto* cds = reinterpret_cast<COPYDATASTRUCT*>(lParam);
    if (cds->dwData == 1) {  // argv tag
      std::string arg(reinterpret_cast<const char*>(cds->lpData));
      // SetPropW 标记本窗口为 ZhiYueWindowProp
      // 透传给 Flutter engine：调 engine 的 entry point arguments
      // 或通过 MethodChannel 推送 "openBook"
    }
  }
  return Win32Window::MessageHandler(hWnd, message, wParam, lParam);
}
```

**Dart 侧不变**：`BookOpenBridge.init` 已处理 `argv`（第一实例）和 MethodChannel `openBook`（暖启动路径）。WM_COPYDATA → MethodChannel 是 Windows 内部细节，Dart 看不到。

### 4.6 dart_test.yaml golden tag

**新文件**：`app/dart_test.yaml`

```yaml
tags:
  golden:
    # golden_toolkit 包要求；M8 配置后消除每次 test 的 warning
    # 不 skip，默认就跑
```

### 4.7 CHANGELOG + NOTICE + LICENSE

**新文件 `CHANGELOG.md`**（根目录，Keep-a-Changelog 风格，累计）：

```markdown
# Changelog

## [0.5.0] - 2026-06-28
### Added
- Windows Inno Setup installer（.epub/.pdf 文件关联 + 开始菜单 + 卸载）
- Windows 便携 Zip 分发
- Android fat APK 真签名 release
- BookOpenBridge SnackBar 错误反馈（可选 onError 注入）
- Windows 单实例 deep-link（mutex + WM_COPYDATA）
- dart_test.yaml golden tag 配置
- CHANGELOG.md + NOTICE

## [0.4.0] - 2026-06-28
### Added
- 应用显示名「智阅」（Android + Windows）
- flutter_launcher_icons pipeline（应用图标）
- Android release signing（keystore.properties gitignored）
- Android intent-filter 注册 VIEW epub/pdf
- BookOpenBridge Dart bridge（isSupportedBookPath / handlePath / init）
- MainActivity Kotlin MethodChannel bridge
- main.dart 接入（main(List<String> args)）

## [0.1.0–0.3.5] - 2026-06-24 ~ 2026-06-27
- M0+M1 数据层基础（drift SQLite + Repository + FTS5）
- M2 EPUB 阅读器（epubx + 自研渲染）
- M3.1 库页面 + 导入 + 标签 + 排版
- M3.2 高亮 + 笔记 + FTS5 跨书搜索 + 5 色选择
- M3.3 精确 offset + chapterTitles + 深链滚动
- M3.4 per-book NotesPage + Markdown 导出 + paged 精确滚动
- M3.5 设置/字体/i18n/多预设排版
- M4 PDF 渲染器（pdfrx + Page-as-Chapter + 文本高亮 + 扫描降级）
```

**新文件 `NOTICE`**（根目录，第三方版权声明）：

```
智阅 (ZhiYue)
Copyright 2026 ZhiYue Open Source contributors

本项目使用以下开源软件（按字母序）：

- drift (Apache License 2.0) - https://drift.simonbinder.eu/
- epubx (MIT License) - https://github.com/rbcprolabs/epubx.dart
- file_picker (MIT License) - https://pub.dev/packages/file_picker
- flutter (BSD-3-Clause License) - https://flutter.dev
- flutter_riverpod (MIT License) - https://riverpod.dev
- go_router (BSD-3-Clause License) - https://pub.dev/packages/go_router
- path (BSD-3-Clause License) - https://pub.dev/packages/path
- pdfrx (MIT License) - https://github.com/espresso33893/pdfrx
- sqlite3_flutter_libs (MIT License) - https://pub.dev/packages/sqlite3_flutter_libs
- uuid (MIT License) - https://pub.dev/packages/uuid

详见各包仓库的 LICENSE 文件。

本项目源码以 AGPLv3 协议发布，详见 LICENSE。
```

### 4.8 版本号 bump

- `app/pubspec.yaml`: `version: 0.5.0+2`
- `app/windows/CMakeLists.txt`: `VERSION 0.5.0`（同步影响 .exe 属性面板）
- `app/windows/installer/zhiyue.iss`: `AppVersion=0.5.0`

### 4.9 README 重写 + 截图

**修改根 `README.md`**：

```markdown
# 智阅（Zhi Yue）

> 面向深度阅读/学习者的开源 Flutter 电子书阅读平台。
> 先做极致本地阅读体验，逐步叠加 AI 陪伴式学习与跨端同步。

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](...)

## 项目状态

✅ MVP 1.0 候选：v0.5.0 已发布（双端 release artifact）。
下一步：测试/打磨后 tag v1.0.0。

## 下载安装

### Windows
- [安装包（setup.exe）](...) - 自动注册 .epub/.pdf 文件关联
- [便携版（zip）](...) - 解压即用，免安装

### Android
- [APK](...) - sideload 安装（需在系统设置允许「未知来源」）

## 主界面预览

| Library | EPUB Reader | PDF Reader | Notes |
|---|---|---|---|
| ![](docs/screenshots/library.png) | ![](docs/screenshots/epub_reader.png) | ![](docs/screenshots/pdf_reader.png) | ![](docs/screenshots/notes.png) |

## MVP 1.0 目标
- 跨端阅读：Windows + Android，一套 Flutter 代码（Mac 后期）
- 格式支持：EPUB 完整功能 + PDF（文本版基础 + 扫描版仅阅读）
- 本地优先：所有数据本地 SQLite，完全离线可用
- 沉浸阅读：极致排版、4 套主题、全屏沉浸模式
- 读书笔记：高亮（5 色）+ 笔记 + 标签 + 全文搜索（FTS5）
- 知识沉淀：读书笔记库 + Markdown 导出（Obsidian 兼容）

## 技术栈 / 文档 / 反馈
（保留现有段）

## 开源协议
（保留现有段）

## 更新日志
详见 [CHANGELOG.md](CHANGELOG.md)。
```

**修改 `app/README.md`**：Flutter 模板替换为开发者操作手册——构建、打包、测试、签名流程，保留 M7 smoke test 段落。

**新文件 `docs/screenshots/`**：4 张手动截图（library.png / epub_reader.png / pdf_reader.png / notes.png）。

## 5. 数据流

### 5.1 Gitee Release 上传 Windows 安装包

```
[开发者本地]
  1. cd app && flutter build windows --release
     → build/windows/x64/runner/Release/zhiyue.exe + dll + data + assets
  2. iscc windows/installer/zhiyue.iss
     → build/windows/installer/zhiyue-setup-0.5.0.exe
  3. 压缩 Release/ → zhiyue-portable-0.5.0.zip
  4. 浏览器打开 gitee.com/weifu0523/e-book-reading-platform/releases/new
     tag: v0.5.0  title: 智阅 0.5.0
     附件: zhiyue-setup-0.5.0.exe + zhiyue-portable-0.5.0.zip
     说明: 引用 CHANGELOG.md#050 段落
```

### 5.2 Windows 第二实例 argv 透传

```
[Windows Explorer]
  双击 book.epub（.epub 已被 Inno Setup 关联到 zhiyue.exe %1）
     │ argv[1] = "C:\path\book.epub"
     ▼
[main.cpp wWinMain]
  CreateMutexW(L"Local\\ZhiYueApp")
     │
     ├─ GetLastError() != ERROR_ALREADY_EXISTS → 第一实例：正常启动
     │     └─ flutter_window 创建后，SetPropW("ZhiYueWindowProp")
     │           接收 WM_COPYDATA → 转 MethodChannel("openBook")
     │
     └─ ERROR_ALREADY_EXISTS → 第二实例：
           EnumWindows 找附加了 "ZhiYueWindowProp" 的窗口
           WM_COPYDATA 把 argv[1] 发送过去
           return 0  // 自身退出
```

### 5.3 BookOpenBridge SnackBar 错误反馈

```
[BookOpenBridge.handlePath]
  try {
    final result = await importer.importFile(File(path));
    unawaited(router.push('/book/${result.book.id}'));
  } catch (e, st) {
    options.onError?.call(e, st);
  }
     ▼
[main.dart 注入的 onError]
  if (navigatorKey.currentContext == null) return; // 启动早期
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text('打开书籍失败：$e')),
  );
```

### 5.4 Android deep-link 真机 smoke test

```
[adb shell]
  adb install -r app/build/app/outputs/flutter-apk/app-release.apk
  adb push test/fixtures/sample.epub /sdcard/Download/
  adb shell am start -a android.intent.action.VIEW \
    -d "file:///sdcard/Download/sample.epub" \
    -t application/epub+zip \
    dev.zhiyue.zhiyue/.MainActivity
     ▼
[MainActivity.onCreate]
  intent.data → uriToPath → pendingBookPath
     ▼
[Dart BookOpenBridge.init → popPendingBookPath]
  importer.importFile → router.push('/book/$id')
     ▼
[smoke test 通过条件] reader 显示该书第一章
```

## 6. 错误处理

| 场景 | 处理 |
|---|---|
| Inno Setup 编译失败（路径含中文） | 用户在 `app/` 下手动跑 `iscc windows\installer\zhiyue.iss`；Inno Setup 支持 UTF-8 路径但脚本顶部 `SourceDir` 用绝对路径兜底 |
| apksigner verify 失败（v1/v2 scheme 未通过） | 检查 keystore.properties 路径解析；fallback 退 debug 仅本地试；release artifact 必须真签名才能 release |
| Android SDK 未配置 ANDROID_HOME | `flutter doctor` 在 T1 阻塞；spec 提供 Windows 安装步骤（命令行 sdkmanager 或 Android Studio SDK Manager）|
| Bridge SnackBar 触发时 `navigatorKey.currentContext == null` | 静默忽略（启动极早期阶段，UI 还没 mount） |
| Bridge 失败但用户已在 reader 内 | onError 不影响 router 状态；SnackBar 显示但 reader 仍在上次位置 |
| WM_COPYDATA 发送失败（接收窗口已关闭） | 静默失败；第二实例正常退出，用户重启第一实例即可 |
| Windows release build 失败（pdfrx native link） | M4 已验证 pdfrx 在本机能 build；若失败提示用户开 Developer Mode（符号链接权限）|
| Dart golden test 没有 golden tag | `dart_test.yaml` 配置 `tags: { golden: {} }`，warning 消除 |
| 截图时 reader 没装书 | smoke test 流程规定截图前 `flutter run` 装一本 fixture epub/pdf 再截 |
| Gitee Release 上传失败（单文件 100MB 限制） | APK ~30MB + setup.exe ~40MB + zip ~40MB 都在限制内；万一超限，文档化「上传到对象存储 + 链接 release」备选方案 |
| 用户 release APK 在 Android 8+ 安装报「未知来源」 | README 安装步骤明确提示「设置 → 安全 → 允许此来源」，符合 sideload 通用做法 |
| BookOpenBridge 错误回调未注入（默认行为） | 与 M7 完全一致（静默忽略），保证 10 个现有单测通过；SnackBar 仅在 main.dart 注入后才生效 |

## 7. 测试策略

### 单元测试（新增 ~4 个）

- `BookOpenBridge.handlePath` 错误路径 → 验证 `onError` 被调用 + 不抛出（3 个新测试）
- `BookOpenBridge.init` 注入 `options.onError` → 验证传递到 handlePath（1 个新测试）
- 现有 10 个测试全部保持通过（默认 options 不传 → 行为兼容）

### 集成测试

- 不新增 widget test；SnackBar UX 靠真机 smoke test 覆盖

### Windows 单实例 deep-link 测试

- 无单元测试（C++ Win32 代码）
- 手动 smoke test：
  1. 启动 zhiyue.exe（实例 1，显示 library）
  2. 双击 book.epub（已关联文件类型）
  3. 验证：实例 1 跳转到 reader，没有第二个窗口
  4. 第二次双击不同 book2.epub → 实例 1 跳到 book2，仍单窗口

### Android 真机 smoke test

- M7 已有 README 流程文档；M8 真机执行：
  1. `flutter build apk --release` + `apksigner verify`
  2. `adb install` + `adb push` + `am start`（.epub + .pdf 各一遍）
  3. 验证：冷启动自动跳 reader / 暖启动 push 新 reader / 退出后重开仍能 deep-link

### Inno Setup artifact 验证

- 安装 setup.exe → 检查开始菜单 / 卸载项 / 文件关联
- 卸载 → 验证清理干净（注册表 + 文件 + 快捷方式）

### README 截图任务（独立任务）

- `flutter run -d windows` 装好 fixture book 后截 4 张：library / EPUB reader / PDF reader / Notes page
- 命名 `docs/screenshots/{library,epub_reader,pdf_reader,notes}.png`，README 用相对路径引用

### 整体验收

- 全部包测试通过（app + reader_engine + epub_view + pdf_view ≥ 575 + ~4 新增）
- `dart analyze` 干净（除非 M7 已知的 pdfrx info-lint）
- 全部 golden test 不再 warning
- tag `m8-complete` + `v0.5.0` 推到 Gitee

## 8. 不在 M8 范围

- iOS / macOS（M7 已跳）
- Android 12 SplashScreen API / dataExtractionRules（M7 defer 到 v1.0）
- ProGuard / R8 收缩（APK 体积优化 → v1.0）
- App Bundle / Play Store 上架
- 自动签名 / CI 流水线（用户选本地手动 build）
- Gitee Pipeline（用户选本地手动 build）
- Android 12+ photo picker 集成（用户已用 file_picker）
- AI 导读 / 跨端同步（1.5 / 2.0 阶段）
- 截图自动化（v1.0 打磨，integration_test 截 golden）

## 9. 任务估算（plan 阶段细化）

预估 ~12-14 个 TDD 任务，按以下顺序：

1. T1：删 `.github/workflows/ci.yml` + dart_test.yaml golden tag
2. T2：BookOpenBridgeOptions + onError 单测（向后兼容）
3. T3：main.dart navigatorKey 注入 + SnackBar
4. T4：Windows main.cpp mutex + 第一/第二实例分支
5. T5：flutter_window.cpp WM_COPYDATA 接收 + SetPropW 标记
6. T6：Android SDK 安装 + flutter doctor 通过（手动 + 文档化）
7. T7：keystore.properties 真实生成 + release APK build + apksigner verify
8. T8：Android 真机 deep-link smoke test（.epub + .pdf）
9. T9：Inno Setup zhiyue.iss + 编译 setup.exe
10. T10：便携 Zip 打包
11. T11：CHANGELOG.md + NOTICE + 根 README 重写 + app/README 重写
12. T12：截图 4 张 + 插入 README
13. T13：Gitee Release v0.5.0 上传 + tag push
14. T14：tag `m8-complete` + push

## 10. 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| Android SDK 安装失败 / PATH 配置坑 | 中 | 高 | T1 阻塞 + 文档化完整步骤；T6 任务隔离，失败不阻塞其他 T |
| Inno Setup 6+ 未在用户机安装 | 高 | 中 | spec 提供 Inno Setup 下载链接；T9 加前置检查 |
| Windows mutex + WM_COPYDATA C++ 代码坑（字符集） | 中 | 中 | 用 UTF-8 转换 wrapper；现有 M7 已有 argv→Dart 桥接，WM_COPYDATA 只是补一层 |
| 真签名 release APK 体积超 Gitee 单文件 100MB | 低 | 高 | fat APK 实测 ~30-40MB，远低于限制 |
| 截图时机 / fixture 准备不充分 | 低 | 低 | 规定 smoke test 流程在截图前先跑通 |
| Gitee Release 流程用户没接触过 | 中 | 低 | spec 提供 step-by-step 命令 + 浏览器路径 |
| CHANGELOG 累计内容不全（M2-M4 细节遗漏） | 中 | 低 | 引用各 milestone spec 的 commit log，逐步回填 |
