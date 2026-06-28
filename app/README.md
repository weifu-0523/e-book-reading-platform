# zhiyue

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 应用图标生成

图标源文件 `app/assets/icon.png`（推荐 1024×1024 PNG）。运行：

```bash
cd app && dart run flutter_launcher_icons
```

会重新生成 Android 各分辨率 mipmap + Windows .ico。

修改源文件后请重新运行此命令并提交所有生成产物。

## M7 验收 smoke test

### Android（需要 adb + 模拟器或真机）

```bash
# 1. 装 release APK
cd app
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk

# 2. 推一个测试 epub
adb push test/fixtures/sample.epub /sdcard/Download/

# 3. 在文件管理器打开 /sdcard/Download/sample.epub → 选「智阅」
#    预期：app 启动 → 自动跳转 reader 显示该书

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

:: 3. app 已运行时无法 deep-link（Windows 桌面单实例未实现，M8 可选）
```

### 版本号验证

- `flutter --version` 不影响
- Android: `aapt dump badging app-release.apk | grep versionName` 应输出 `versionName='0.4.0'`
- Windows: 右键 zhiyue.exe → 属性 → 详细信息 → 产品版本应为 `0.4.0`
