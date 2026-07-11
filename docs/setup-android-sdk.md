# Android SDK 安装指南（Windows）

M7 sprint 期间发现本机未安装 Android SDK，导致 `flutter build apk --release` 和真机 smoke test 阻塞。M8 把安装步骤文档化，确保用户能在本地完成 release build。

## 前置条件

- Flutter SDK 已安装并加到 PATH（`flutter --version` 能跑）
- 本机 OS：Windows 10/11
- 磁盘空间：至少 5GB（SDK + 模拟器镜像）

## 方案 A：Android Studio（推荐，~3GB）

适合计划后续长期做 Android 开发的开发者。

1. 下载 [Android Studio](https://developer.android.com/studio)，安装时勾选 Android SDK + Android SDK Platform + Android Virtual Device。
2. 首次启动，按 Setup Wizard 完成 SDK 安装（默认装最新的 stable API level）。
3. 启动 Android Studio → Settings → Languages & Frameworks → Android SDK：
   - SDK Platforms：勾 **Android 14.0 (API 34)** + **Android 15+ (API 36)**（v1.8.0-alpha 起 `flutter_plugin_android_lifecycle` 要求 compileSdk 36）
   - SDK Tools：勾 **Android SDK Build-Tools 34.0.0** + **Android SDK Platform-Tools** + **Android Emulator**
4. 设置环境变量：
   ```cmd
   setx ANDROID_HOME "%LOCALAPPDATA%\Android\Sdk"
   setx PATH "%PATH%;%LOCALAPPDATA%\Android\Sdk\platform-tools"
   ```
   （关闭并重开所有终端让 setx 生效）
5. 接受许可：
   ```cmd
   flutter doctor --android-licenses
   ```
   全部输入 `y`。

## 方案 B：命令行 sdkmanager（~1GB）

适合只想要 SDK 不想要 IDE 的开发者。

1. 下载 [Command line tools only](https://developer.android.com/studio#command-line-tools-only)，解压到 `C:\Android\sdk\cmdline-tools\latest\`（注意子目录必须是 `latest`）。
2. 设置环境变量：
   ```cmd
   setx ANDROID_HOME "C:\Android\sdk"
   setx PATH "%PATH%;C:\Android\sdk\cmdline-tools\latest\bin;C:\Android\sdk\platform-tools"
   ```
3. 重开终端，安装必需组件：
   ```cmd
   sdkmanager "platform-tools" "platforms;android-34" "platforms;android-36" "build-tools;34.0.0"
   ```
4. 接受许可：
   ```cmd
   flutter doctor --android-licenses
   ```

## 验证

```cmd
flutter doctor -v
```

预期输出（关键行）：

```
[✓] Flutter (Channel stable, ...)
[✓] Windows Version (Installed Windows 11)
[✓] Android toolchain - develop for Android devices (Android SDK version 34.0.0)
[✓] Connected device (the emulator or real device)
```

如果 `flutter doctor` 仍报 Android 相关错误，回到上述步骤检查。

## compileSdk 36 plugin 补丁（v1.8.0-alpha 起强制）

`flutter_plugin_android_lifecycle` 强制要求 compileSdk 36，但少数 transitive plugin 默认仍是 34。

**v1.10.0-alpha 起，direct dep 已全部升级**，pubspec 锁定如下：

| Direct dep | 锁定版本 | 默认 compileSdk |
|---|---|---|
| connectivity_plus | `^7.0.0`（resolved 7.2.0） | 36（`flutter.compileSdkVersion`） |
| file_picker | `>=10.3.3 <10.3.9`（resolved 10.3.8） | 36（`flutter.compileSdkVersion`） |
| flutter_secure_storage | `^10.0.0`（resolved 10.3.1） | 36（hardcoded） |

剩余 transitive plugin 仍需手动补丁：

| Transitive plugin | 版本 | 上游 issue |
|---|---|---|
| just_audio | 0.9.46 | 待升级（S4 候选） |
| webview_flutter_android | 3.16.9 | 待升级（S4 候选） |

`flutter build apk` 时这 2 个 transitive plugin 子项目会编译失败。当前 workaround 是直接 sed 改 pub cache：

```bash
for pkg in just_audio-0.9.46 webview_flutter_android-3.16.9; do
  f="$LOCALAPPDATA/Pub/Cache/hosted/pub.dev/$pkg/android/build.gradle"
  # CRLF-safe: 只替换 compileSdk 34 这一行
  sed -i 's/compileSdk 34/compileSdk 36/g' "$f"
done
```

> **注意**：`flutter pub get` 重下 plugin 后补丁丢失，需重跑。Gradle 子项目级 `subprojects { afterEvaluate ... }` override 在 Flutter `evaluationDependsOn(":app")` 早评估下不生效（已试，3 次失败）。**长期方案**：升级这 2 个 transitive plugin 到默认 compileSdk 36 的版本（S4 候选）。

## 下一步

SDK 装好后，按 [`docs/release-procedure.md`](release-procedure.md) 跑 release build + smoke test。
