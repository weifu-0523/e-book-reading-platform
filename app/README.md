# 智阅 - Flutter app

本目录包含智阅主 app 的 Dart 源码。开发文档（产品定位、MVP 目标）见仓库根 [`README.md`](../README.md)。

## 开发环境

- Flutter SDK 3.27+
- Dart 3.10+
- Windows 10/11（Windows 构建）
- Android SDK 34（Android 构建，安装见 [docs/setup-android-sdk.md](../docs/setup-android-sdk.md)）

验证：

```bash
flutter doctor -v
```

## 常用命令

```bash
# 1. 装依赖（首次 clone 或 pubspec 改动后）
flutter pub get

# 2. 代码生成（drift / riverpod annotation）
dart run build_runner build --delete-conflicting-outputs

# 3. 静态分析（注意：用 dart analyze，不要用 flutter analyze；中文路径会让 flutter analyze 的 LSP 崩溃）
dart analyze

# 4. 跑测试
dart test

# 5. 跑指定测试文件
dart test test/services/book_open_bridge_test.dart
```

## 应用图标生成

图标源文件 `app/assets/icon.png`（推荐 1024×1024 PNG，已在 M7 提交）。

修改源文件后重新生成 Android 各分辨率 mipmap + Windows .ico：

```bash
cd app && dart run flutter_launcher_icons
```

提交所有生成产物（mipmap-* + colors.xml + .ico）。

## 构建 release artifact

### Windows

```cmd
cd app
flutter build windows --release

# 产物在 build\windows\x64\runner\Release\
# 生成 Inno Setup installer（需 Inno Setup 6+ 已安装）：
iscc windows\installer\zhiyue.iss

# 生成便携 Zip：
powershell -ExecutionPolicy Bypass -File windows\installer\build-portable-zip.ps1
```

详见 [docs/release-procedure.md](../docs/release-procedure.md)。

### Android

前置：`app/android/app/keys/keystore.properties` 已生成（参考 [`keys/README.md`](android/app/keys/README.md)）。

```bash
cd app
flutter build apk --release
apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

预期输出包含 `Verified using v1 scheme` / `Verified using v2 scheme`。

## Smoke test 流程

### Android（真机或模拟器，需 Android SDK 已装）

```bash
# 1. 装 release APK
cd app
adb install -r build/app/outputs/flutter-apk/app-release.apk

# 2. 推一个测试 epub
adb push test/fixtures/sample.epub /sdcard/Download/

# 3. 模拟用户从文件管理器打开
adb shell am start -a android.intent.action.VIEW \
  -d "file:///sdcard/Download/sample.epub" \
  -t application/epub+zip \
  dev.zhiyue.zhiyue/.MainActivity

# 预期：app 启动 → 自动跳转 reader 显示该书

# 4. 已运行 app 时再次打开另一本书
#    预期：路由 push 到新 reader（保留返回栈）
```

### Windows

```cmd
cd app
flutter build windows --release

:: 1. 双击 build\windows\runner\Release\zhiyue.exe 启动 → 显示 library
:: 2. 命令行带参数启动：
::    zhiyue.exe C:\path\to\book.epub
::    预期：app 启动 → 自动跳转 reader 显示该书

:: 3. 单实例验证：app 已运行时，双击 .epub 文件
::    预期：在运行中的窗口打开新 reader，不启动第二个进程
```

### Bridge 失败反馈

打开损坏的 .epub / .pdf 时，应看到 SnackBar 提示「打开书籍失败：...」。

### 版本号验证

- Android: `aapt dump badging app-release.apk | grep versionName` 应输出 `versionName='0.5.0'`
- Windows: 右键 zhiyue.exe → 属性 → 详细信息 → 产品版本应为 `0.5.0`
