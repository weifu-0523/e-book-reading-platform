# 智阅 Release 发布流程

本文档记录从源码到 Gitee Release 的完整发布步骤。每次发版（v1.0.0、v1.1.0-alpha 等）都按此跑一遍。

> **历史**：v0.5.0 之前的流程见本文档末尾"v0.5.0 Windows Smoke Test Results"段落。v1.0.0+ 流程增加了 M7 平台适配（图标/显示名/deep-link/签名）与 M8 单实例 smoke 步骤。

## 前置条件

- Flutter SDK 已装（`flutter --version` 能跑，当前 3.44+）
- Dart SDK 3.10+
- Android SDK 34 已装（见 [setup-android-sdk.md](setup-android-sdk.md)）
- **Android keystore 已配置**：`app/android/app/keys/keystore.properties` + `app/android/app/keys/zhiyue.jks`（首次发版前生成，参考 [`app/android/app/keys/README.md`](../app/android/app/keys/README.md)）
- Inno Setup 6+ 已装（[下载](https://jrsoftware.org/isdl.php)，安装后 `iscc` 在 PATH 中）
- Visual Studio 2022 Build Tools + Windows 10 SDK 10.0.26100（Windows native build）
- 项目已 clone 完整，`git remote -v` 输出 Gitee 地址
- 当前在 master 分支，所有改动已 commit
- **ASCII 工作路径**（仅 Windows release build 时）：因 Flutter engine 中文路径 MSBuild UTF-8↔GBK mojibake bug，build 前需 `cp -r` 项目到 `/c/dev/zhiyue` 等纯 ASCII 路径（详见 `docs/maintainers-runbook.md` §3）

## 步骤 1：版本号确认

```bash
grep "^version:" app/pubspec.yaml
# 期望：version: 1.1.0-alpha+0（或当前发布版本）
```

若需 bump：
- `app/pubspec.yaml` → `version: X.Y.Z+N`
- `app/windows/installer/zhiyue.iss` → `#define MyAppVersion "X.Y.Z"`
- `CHANGELOG.md` → 新增 `[X.Y.Z]` 段落
- `README.md` → 版本徽章 + 项目状态段落 + 下载链接

## 步骤 2：跑测试 + 静态分析

```bash
cd app
/c/flutter/bin/dart analyze
/c/flutter/bin/dart test
```

期望：
- analyze 干净（0 errors / 0 warnings；131 info 为既有 cascade/const 风格 lint，可忽略）
- test 全部通过（≥ 762 + 3 skipped）

reader_engine / epub_view / pdf_view 包同样跑一遍：

```bash
cd reader_engine && /c/flutter/bin/dart test && cd ..
cd reader_engine_epub_view && /c/flutter/bin/dart test && cd ..
cd reader_engine_pdf_view && /c/flutter/bin/dart test && cd ..
```

## 步骤 3：构建 Windows release

> **中文路径警告**：`flutter build windows` 在含非 ASCII 字符的路径（如 `H:\projiect\电子书阅读平台`）下会失败，因 MSBuild 收到的路径会 UTF-8 → GBK mojibake。**必须先 cp 到 ASCII 路径**：
>
> ```bash
> cp -r "H:/projiect/电子书阅读平台" /c/dev/zhiyue
> cd /c/dev/zhiyue/app
> flutter clean && flutter pub get
> ```

```cmd
cd app
flutter build windows --release
```

产物：`build\windows\x64\runner\Release\`（zhiyue.exe + flutter_windows.dll + data/）

### 步骤 3b：Windows 单实例 smoke test（M8 起强制）

冷启动 zhiyue.exe → 显示 Library → 再启动第二个 zhiyue.exe（任意 argv）→ 期望：第二个进程在 ~2s 内退出，第一个进程保持运行（mutex + WM_COPYDATA forward 正常）。

若第二个进程不退出或两个进程都显示窗口，说明 `windows/runner/main.cpp` 的 mutex / EnumWindows / WM_COPYDATA 路径有回归，**不可发版**。

## 步骤 4：生成 Inno Setup installer

```cmd
cd app
iscc windows\installer\zhiyue.iss
```

产物：`build\installer\zhiyue-setup-X.Y.Z.exe`

验证（手动）：
1. 双击 setup.exe → 安装到 `%LOCALAPPDATA%\Programs\智阅\`
2. 检查开始菜单 → 智阅
3. 双击一个 .epub 文件 → 应自动用智阅打开
4. 卸载 → 检查注册表 `.epub` 关联已清理

## 步骤 5：生成便携 Zip

```cmd
cd app
powershell -ExecutionPolicy Bypass -File windows\installer\build-portable-zip.ps1
```

产物：`build\installer\zhiyue-portable-X.Y.Z.zip`

验证（手动）：解压到任意目录 → 双击 zhiyue.exe → 正常启动。

## 步骤 6：构建 Android release APK

前置：
- `app/android/app/keys/keystore.properties` 已生成（参考 [`app/android/app/keys/README.md`](../app/android/app/keys/README.md)）
- Android SDK 34 已装（见 setup-android-sdk.md）
- Gradle 镜像已配置（用户级 `~/.gradle/init.gradle` 指向腾讯/阿里云镜像，详见 `docs/maintainers-runbook.md` §3）

```cmd
cd app
flutter build apk --release
```

验证签名：

```cmd
apksigner verify --verbose build\app\outputs\flutter-apk\app-release.apk
```

期望输出包含：
- `Verified using v1 scheme (JAR signing): true`
- `Verified using v2 scheme (APK Signature Scheme v2): true`

复制到 installer 目录（统一上传位置）：

```cmd
copy build\app\outputs\flutter-apk\app-release.apk build\installer\zhiyue-X.Y.Z.apk
```

## 步骤 6b：Android 平台适配验证（M7 起强制）

- 应用图标：`flutter pub run flutter_launcher_icons` 已生成所有密度，检查 `app/android/app/src/main/res/mipmap-*` 时间戳
- 显示名：`app/android/app/src/main/AndroidManifest.xml` 的 `android:label="智阅"`
- File provider / deep-link：`AndroidManifest` 含 `<intent-filter>` for `application/epub+zip` + `application/pdf`
- 签名方案：v1 + v2 都通过（v1 兼容 Android 7 以下）

## 步骤 7：Android 真机 smoke test

```cmd
:: 装到设备
adb install -r build\app\outputs\flutter-apk\app-release.apk

:: 推一个 epub + pdf
adb push test\fixtures\sample.epub /sdcard\Download\
adb push test\fixtures\sample.pdf  /sdcard\Download\

:: 模拟从文件管理器打开 epub（冷启动）
adb shell am start -a android.intent.action.VIEW ^
  -d "file:///sdcard/Download/sample.epub" ^
  -t application/epub+zip ^
  dev.zhiyue.zhiyue/.MainActivity

:: 期望：app 启动 → 跳转 reader 显示该书

:: 暖启动：在已运行的 app 内打开新书
adb shell am start -a android.intent.action.VIEW ^
  -d "file:///sdcard/Download/sample.pdf" ^
  -t application/pdf ^
  dev.zhiyue.zhiyue/.MainActivity

:: 期望：reader push 到新书的 PDF 视图
```

## 步骤 8：Windows 单实例 smoke test

1. 双击 `build\windows\x64\runner\Release\zhiyue.exe` → 显示 library
2. 在文件管理器双击一个 .epub 文件（已通过安装版注册关联）
   - 若用便携版（未注册关联），手动跑：`zhiyue.exe C:\path\to\book.epub`
3. 期望：app 启动 → 跳转 reader
4. **再次**双击另一个 .epub → 期望：在已运行的窗口打开新书，**不启动第二个窗口**

## 步骤 9：截图（用于 README）

```cmd
cd app
flutter run -d windows
```

在 app 内：
1. 导入一本 EPUB 和一本 PDF（fixture 可在 `test/fixtures/` 找）
2. 截图（Win + Shift + S 或 PrtSc）：
   - Library 页面（含至少 2 本书）
   - EPUB reader 页面（含高亮）
   - PDF reader 页面
   - Notes 页面（per-book）
3. 保存到 `docs/screenshots/`，命名 `library.png` / `epub_reader.png` / `pdf_reader.png` / `notes.png`
4. 提交：`git add docs/screenshots/*.png && git commit -m "docs: v0.5.0 release screenshots"`

## 步骤 10：tag + 推送

```bash
git tag mX-complete
git tag vX.Y.Z
git push origin master --tags
```

## 步骤 11：上传 Gitee Release

1. 浏览器打开 [Gitee Release 创建页](https://gitee.com/weifu0523/e-book-reading-platform/releases/new)
2. 选择刚推送的 tag（如 `v1.1.0-alpha`）
3. 标题：`智阅 X.Y.Z`（如"智阅 1.1.0-alpha"）
4. 上传 3 个 artifact：
   - `build/installer/zhiyue-setup-X.Y.Z.exe`
   - `build/installer/zhiyue-portable-X.Y.Z.zip`
   - `build/installer/zhiyue-X.Y.Z.apk`
5. Release notes 内容（复制 `CHANGELOG.md` 对应版本的段落，开头加一行简短描述）
6. 附 4 张 release 截图（library / epub_reader / pdf_reader / notes）
7. 发布

## 步骤 12：发布后核对

- [ ] Gitee Release 页面能看到 3 个 artifact，下载链接可访问
- [ ] 仓库根 `README.md` 下载链接指向新 release
- [ ] `CHANGELOG.md` 已更新到新版本
- [ ] tag 在 `git tag --list` 中存在，已 push 到 Gitee
- [ ] AGPLv3 源文件头覆盖（`grep -rL "SPDX-License-Identifier" app/lib --include="*.dart" | wc -l` 应 ≤ 17，即只生成文件缺）
- [ ] `dart analyze` 0 errors / 0 warnings
- [ ] `flutter test --concurrency=1` 全通过

完成。

---

## 历史：v0.5.0 Windows Smoke Test Results (T13, 2026-06-28)

## v0.5.0 Windows Smoke Test Results (T13, 2026-06-28)

- OS: Windows 11 家庭版 中文版 25H2
- Build host: Visual Studio 2022 Build Tools 17.14.21 + Windows 10 SDK 10.0.26100
- Flutter: 3.44.2 (channel stable)
- Version: 0.5.0+2

### Pass

- ✅ `flutter build windows --release` succeeds (after C++ compile fix in 747136f)
- ✅ Build output: `build/windows/x64/runner/Release/zhiyue.exe` (137 KB exe + flutter_windows.dll + data/)
- ✅ Process launches and stays running (GUI window appears)
- ✅ Single-instance mutex: second instance with argv exits within ~2s while first instance keeps running (mutex + WM_COPYDATA forward confirmed)
- ✅ Portable zip: `build/installer/zhiyue-portable-0.5.0.zip` (18.1 MB)

### Deferred

- ❌ Inno Setup installer compile: dev machine network restricted, `winget install JRSoftware.InnoSetup` and direct download from jrsoftware.org both failed. User must install Inno Setup 6+ manually from https://jrsoftware.org/isdl.php to produce `zhiyue-setup-0.5.0.exe`.
- ❌ File association smoke test (.epub / .pdf): requires installer to register HKA registry entries.
- ❌ Warm-start deep-link (open book in running window via file double-click): requires file association.

### Known issue: Chinese path encoding

`flutter build windows` fails when project path contains non-ASCII characters (e.g., the dev machine's `H:\projiect\电子书阅读平台`). MSBuild subprocess receives the path with UTF-8 → GBK mojibake (`锟斤拷` artifacts), causing it to fail reading `.dart_tool/flutter_build/*/app.dill`.

**Workaround:** copy project to an ASCII path before building:

```bash
cp -r "H:/projiect/电子书阅读平台" /c/dev/zhiyue
cd /c/dev/zhiyue/app && flutter clean && flutter pub get && flutter build windows --release
```

This is a Flutter engine bug, not project-specific. Tracked for upstream report.

