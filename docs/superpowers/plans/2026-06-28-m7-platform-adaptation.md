# M7 平台适配 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把智阅从 Flutter 默认脚手架升级为 Android + Windows 双端「平台适配就绪」状态：含应用图标 pipeline、显示名「智阅」、文件关联 deep-link（冷启动打开 .epub/.pdf 自动跳转阅读器）、Android 签名配置、Windows 窗口标题、版本号 bump 到 0.4.0+1。

**Architecture:** Display name + intent-filter + Windows manifest 改 XML/RC/CMake；Android deep-link 通过 Kotlin `MainActivity` 捕获 `Intent.ACTION_VIEW` → MethodChannel 推送到 Dart；**Windows deep-link 直接读 `main(List<String> args)`（main.cpp 已通过 `set_dart_entrypoint_arguments` 透传，无需 C++ 改动）**；Dart 端 `BookOpenBridge` 统一两条来源，调用现有 `BookImportService.importFile` → 通过 Riverpod `routerProvider` 路由到 `/book/:id`。

**Tech Stack:** Flutter 3.44 / Dart 3.12 / Riverpod 2.6 / go_router 14.2 / Kotlin (Android) / CMake + MSVC (Windows) / flutter_launcher_icons 0.14 / Android keystore (keytool)

---

## File Structure Overview

### 新建文件

| Path | Responsibility |
|---|---|
| `app/flutter_launcher_icons.yaml` | flutter_launcher_icons 配置（输入 `assets/icon.png`，输出 Android mipmap-* + Windows .ico） |
| `app/assets/icon.png` | 1024×1024 主图（**由用户 AI 生成，commit 前 placeholder 不阻塞 build**） |
| `app/lib/services/book_open_bridge.dart` | 统一 Android MethodChannel + Windows argv 的 Dart bridge，路由到 reader |
| `app/test/services/book_open_bridge_test.dart` | BookOpenBridge unit tests（路径校验、import 调用、router 跳转） |
| `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/BookOpenPlugin.kt` | Kotlin 端 MethodChannel 注册：捕获 cold/warm intent → 推 path 到 Dart |
| `app/keys/README.md` | 说明如何本地生成 keystore（不入仓实际 .jks） |

### 修改文件

| Path | Change |
|---|---|
| `app/pubspec.yaml` | version `0.1.0+1` → `0.4.0+1`；dev_dependencies 加 `flutter_launcher_icons: ^0.14.3` |
| `app/android/app/src/main/AndroidManifest.xml` | `android:label="智阅"`；`<activity>` 加 intent-filter for VIEW epub/pdf |
| `app/android/app/build.gradle.kts` | 读 `keys/keystore.properties`，存在则 release 签名用 release keystore，否则 fallback debug |
| `app/windows/runner/main.cpp` | window title `L"zhiyue"` → `L"智阅"`（智阅 UTF-16 转义） |
| `app/windows/runner/Runner.rc` | `FileDescription` / `ProductName` → "智阅"；CompanyName 改 "ZhiYue Open Source" |
| `app/lib/main.dart` | `void main()` → `void main(List<String> args)`；启动后调用 `BookOpenBridge.init(args)` |
| `app/lib/core/router.dart` | 拆 `routerProvider` Riverpod provider；`createAppRouter()` 保留为内部实现 |
| `app/lib/core/app.dart` | `routerConfig: createAppRouter()` → `routerConfig: ref.watch(routerProvider)` |
| `.gitignore`（根） | 加 `app/keys/*.jks`、`app/keys/keystore.properties` |

---

## 项目纪律约束（每个 subagent 必读）

- **Flutter SDK**：`/c/flutter/bin/`（PATH 未持久化，需 `export PATH=/c/flutter/bin:$PATH`）
- **静态分析**：用 `dart analyze`（**不要** `flutter analyze` —— 中文路径 `H:\projiect\电子书阅读平台` 触发 LSP UTF-8 解析崩溃）
- **跑测试**：`flutter test`（works fine）
- **TDD**：每个 Dart 任务先写失败测试 → 实现 → 通过 → commit
- **Commit message**：HEREDOC 格式，结尾必须有 `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`
- **禁止**：`--no-verify`、`--amend`（除非用户明确要求）、force push 到 master
- **Working dir**：`H:\projiect\电子书阅读平台`
- **每次迭代 push** 到 Gitee：`git push origin master`
- **平台代码（XML/Kotlin/RC/CMake）**：无单测；改完用 `flutter build apk --debug` / `flutter build windows --debug` 验证可构建，再 commit
- **当前测试基线**：565 passing + 1 skipped —— 每个 task 完成后测试数必须 ≥ 基线

---

## Task 1: flutter_launcher_icons 接入 + .gitignore

**Files:**
- Modify: `app/pubspec.yaml` (dev_dependencies)
- Create: `app/flutter_launcher_icons.yaml`
- Modify: `.gitignore` (root)

- [ ] **Step 1: 加 flutter_launcher_icons 到 dev_dependencies**

`app/pubspec.yaml`，在 `dev_dependencies:` 块尾部加：

```yaml
  # M7: 应用图标 pipeline
  flutter_launcher_icons: ^0.14.3
```

- [ ] **Step 2: 创建 flutter_launcher_icons.yaml**

新建 `app/flutter_launcher_icons.yaml`：

```yaml
# flutter_launcher_icons 配置：从单一 1024x1024 PNG 生成 Android + Windows 各分辨率图标。
# 运行命令：cd app && dart run flutter_launcher_icons
# 注意：iOS 暂跳（M7 不含 iOS）。

flutter_launcher_icons:
  image_path: "assets/icon.png"
  # Android
  android: true
  min_sdk_android: 21
  adaptive_icon_background: "#F5F0E8"
  adaptive_icon_foreground: "assets/icon.png"
  # iOS（暂跳）
  ios: false
  # Windows desktop
  windows:
    generate: true
    icon_size: 256
```

- [ ] **Step 3: 根 .gitignore 加 keystore 保护**

`.gitignore`（项目根）尾部追加：

```
# M7: Android release signing
app/keys/*.jks
app/keys/*.keystore
app/keys/keystore.properties
```

- [ ] **Step 4: 跑 pub get 验证依赖**

Run: `export PATH=/c/flutter/bin:$PATH && cd app && flutter pub get`
Expected: 输出含 `+ flutter_launcher_icons 0.14.x`，无错误

- [ ] **Step 5: 验证 analyze 通过（不应受影响）**

Run: `cd app && dart analyze`
Expected: 0 errors（infos OK）

- [ ] **Step 6: Commit**

```bash
git add app/pubspec.yaml app/flutter_launcher_icons.yaml .gitignore
git commit -m "$(cat <<'EOF'
chore(m7/t1): flutter_launcher_icons dep + config + keystore gitignore

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: 应用显示名「智阅」(Android + Windows)

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/windows/runner/main.cpp`
- Modify: `app/windows/runner/Runner.rc`

- [ ] **Step 1: Android Manifest label 改「智阅」**

`app/android/app/src/main/AndroidManifest.xml`，第 3 行：

```xml
<!-- before -->
android:label="zhiyue"

<!-- after -->
android:label="智阅"
```

- [ ] **Step 2: Windows main.cpp window title 改「智阅」**

`app/windows/runner/main.cpp`，约第 38 行 `window.Create(...)`：

```cpp
// before
if (!window.Create(L"zhiyue", origin, size)) {

// after（智阅 UTF-16 编码：0x667A 0x9605）
if (!window.Create(L"智阅", origin, size)) {
```

- [ ] **Step 3: Windows Runner.rc FileDescription / ProductName 改「智阅」**

`app/windows/runner/Runner.rc`，VS_VERSION_INFO 块内 VALUE 行：

```rc
// before
            VALUE "CompanyName", "dev.zhiyue" "\0"
            VALUE "FileDescription", "zhiyue" "\0"
            VALUE "FileVersion", VERSION_AS_STRING "\0"
            VALUE "InternalName", "zhiyue" "\0"
            VALUE "LegalCopyright", "Copyright (C) 2026 dev.zhiyue. All rights reserved." "\0"
            VALUE "OriginalFilename", "zhiyue.exe" "\0"
            VALUE "ProductName", "zhiyue" "\0"
            VALUE "ProductVersion", VERSION_AS_STRING "\0"

// after
            VALUE "CompanyName", "ZhiYue Open Source" "\0"
            VALUE "FileDescription", "智阅" "\0"
            VALUE "FileVersion", VERSION_AS_STRING "\0"
            VALUE "InternalName", "zhiyue" "\0"
            VALUE "LegalCopyright", "Copyright (C) 2026 ZhiYue Open Source. AGPLv3." "\0"
            VALUE "OriginalFilename", "zhiyue.exe" "\0"
            VALUE "ProductName", "智阅" "\0"
            VALUE "ProductVersion", VERSION_AS_STRING "\0"
```

注：`.rc` 文件顶部已有 `#pragma code_page(65001)`，所以中文字符以 UTF-8 直接写即可，MSVC 会处理。

- [ ] **Step 4: 验证 Android 编译（label 改动）**

Run: `cd app && flutter build apk --debug --no-pub 2>&1 | tail -5`
Expected: `✓ Built build\\app\\outputs\\flutter-apk\\app-debug.apk`

- [ ] **Step 5: 验证 Windows 编译（runner 改动）**

Run: `cd app && flutter build windows --debug 2>&1 | tail -5`
Expected: `✓ windows\\runner\\Release\\zhiyue.exe`（无 fatal error）

- [ ] **Step 6: Commit**

```bash
git add app/android/app/src/main/AndroidManifest.xml app/windows/runner/main.cpp app/windows/runner/Runner.rc
git commit -m "$(cat <<'EOF'
feat(m7/t2): app display name 智阅 on Android + Windows

- AndroidManifest.xml android:label="智阅"
- main.cpp window title 智阅
- Runner.rc FileDescription / ProductName 智阅

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 版本号 bump 0.4.0+1

**Files:**
- Modify: `app/pubspec.yaml`
- Verify: `app/windows/CMakeLists.txt`（Flutter 自动注入 FLUTTER_VERSION，无需手改）

- [ ] **Step 1: pubspec.yaml version 改 0.4.0+1**

`app/pubspec.yaml` 第 4 行：

```yaml
# before
version: 0.1.0+1

# after
version: 0.4.0+1
```

- [ ] **Step 2: 跑 pub get 让 Flutter 重读 version**

Run: `cd app && flutter pub get`
Expected: 无错误

- [ ] **Step 3: 验证 Android versionCode/versionName 自动同步**

Run: `cd app && grep -E "versionCode|versionName" android/app/build.gradle.kts`
Expected: 仍为 `versionCode = flutter.versionCode` / `versionName = flutter.versionName`（不需要手改，Flutter Gradle plugin 自动从 pubspec 读）

- [ ] **Step 4: Commit**

```bash
git add app/pubspec.yaml
git commit -m "$(cat <<'EOF'
chore(m7/t3): bump version to 0.4.0+1

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Android release signing 配置（build.gradle.kts + keys/README）

**Files:**
- Modify: `app/android/app/build.gradle.kts`
- Create: `app/keys/README.md`

- [ ] **Step 1: build.gradle.kts 顶部加 keystoreProperties 加载**

`app/android/app/build.gradle.kts`，文件顶部（plugin 块之后、`android {` 块之前）加：

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("keys/keystore.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

- [ ] **Step 2: android { } 块内加 signingConfigs + release signing**

`app/android/app/build.gradle.kts`，`android { ... }` 块内（在 `buildTypes { ... }` 之前）加：

```kotlin
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
```

然后修改 `buildTypes { release { ... } }` 块：

```kotlin
    buildTypes {
        release {
            // M7: 优先用 release keystore（keys/keystore.properties 存在时），
            // 不存在时 fallback debug（开发本机或 CI 无 keystore 也能 build）。
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
```

- [ ] **Step 3: 创建 app/keys/README.md 说明本地生成流程**

新建 `app/keys/README.md`：

```markdown
# Android Release Signing

本目录被 `.gitignore` 保护。本地构建 release APK 前，需要先生成 keystore：

## 1. 生成 keystore

```bash
keytool -genkey -v \
  -keystore app/keys/zhiyue-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias zhiyue
```

按提示输入 keystore 密码、姓名/组织等（个人项目可填任意）。

## 2. 创建 keystore.properties

新建 `app/keys/keystore.properties`（不要提交）：

```properties
storePassword=<你刚才输入的 keystore 密码>
keyPassword=<你刚才输入的 key 密码（通常与 storePassword 相同）>
keyAlias=zhiyue
storeFile=app/keys/zhiyue-release.jks
```

## 3. 验证

```bash
cd app && flutter build apk --release
apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

应输出 `Verified using v1 scheme` / `Verified using v2 scheme`。
```

- [ ] **Step 4: 验证 debug build 仍可（无 keystore.properties 时）**

Run: `cd app && flutter build apk --debug 2>&1 | tail -3`
Expected: `✓ Built build\\app\\outputs\\flutter-apk\\app-debug.apk`（fallback debug signing 生效）

- [ ] **Step 5: Commit**

```bash
git add app/android/app/build.gradle.kts app/keys/README.md
git commit -m "$(cat <<'EOF'
feat(m7/t4): android release signing via keys/keystore.properties

build.gradle.kts reads keys/keystore.properties when present (gitignored),
falls back to debug signing otherwise. Local keystore generation
documented in keys/README.md.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Android intent-filter 注册 epub/pdf

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: AndroidManifest 加 intent-filter**

`app/android/app/src/main/AndroidManifest.xml`，在现有 `<intent-filter>` (MAIN+LAUNCHER) **之后**、`</activity>` **之前**加：

```xml
            <!-- M7: 接收外部 .epub / .pdf 打开请求 -->
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
                <data android:pathPattern=".*\\..*\\.epub"/>
                <data android:pathPattern=".*\\..*\\.pdf"/>
            </intent-filter>
```

注：pathPattern 加 `.*\\..*\\.` 变体是为了匹配多重扩展名（如 `book.backup.epub`）。

- [ ] **Step 2: 验证 Android 编译**

Run: `cd app && flutter build apk --debug 2>&1 | tail -3`
Expected: `✓ Built build\\app\\outputs\\flutter-apk\\app-debug.apk`

- [ ] **Step 3: Commit**

```bash
git add app/android/app/src/main/AndroidManifest.xml
git commit -m "$(cat <<'EOF'
feat(m7/t5): android intent-filter for VIEW epub/pdf

Registers ZhiYue as a handler for application/epub+zip and application/pdf
VIEW intents, so users can open .epub/.pdf from any file manager.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: BookOpenBridge 骨架 + 路径校验（TDD）

**Files:**
- Create: `app/lib/services/book_open_bridge.dart`
- Create: `app/test/services/book_open_bridge_test.dart`

- [ ] **Step 1: 写失败测试 — 路径白名单**

新建 `app/test/services/book_open_bridge_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/book_open_bridge.dart';

void main() {
  group('BookOpenBridge.isSupportedBookPath', () {
    test('accepts .epub paths', () {
      expect(BookOpenBridge.isSupportedBookPath('/tmp/book.epub'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('C:\\Users\\me\\book.epub'), isTrue);
    });

    test('accepts .pdf paths', () {
      expect(BookOpenBridge.isSupportedBookPath('/tmp/paper.pdf'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('C:\\docs\\paper.pdf'), isTrue);
    });

    test('rejects non-book extensions', () {
      expect(BookOpenBridge.isSupportedBookPath('/tmp/readme.txt'), isFalse);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/image.png'), isFalse);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/'), isFalse);
    });

    test('rejects empty / null-like paths', () {
      expect(BookOpenBridge.isSupportedBookPath(''), isFalse);
      expect(BookOpenBridge.isSupportedBookPath('book'), isFalse);
    });

    test('case-insensitive on extensions', () {
      expect(BookOpenBridge.isSupportedBookPath('/tmp/BOOK.EPUB'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/Paper.PDF'), isTrue);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd app && flutter test test/services/book_open_bridge_test.dart`
Expected: FAIL with `BookOpenBridge not defined` / `Error: Method not found`

- [ ] **Step 3: 写最小实现 — isSupportedBookPath 静态方法**

新建 `app/lib/services/book_open_bridge.dart`：

```dart
import 'package:path/path.dart' as p;

/// 统一 Android MethodChannel + Windows argv 的文件打开 bridge。
///
/// M7：从 native 层（Android MethodChannel `dev.zhiyue.bookopen` 或
/// Windows main(List<String> args)）接收文件路径，验证为支持的电子书格式，
/// 调用 [BookImportService] 导入，路由到 reader 页面。
class BookOpenBridge {
  const BookOpenBridge._();

  /// 是否是支持的电子书路径（按扩展名白名单）。
  ///
  /// 大小写不敏感；空字符串返回 false。
  static bool isSupportedBookPath(String path) {
    if (path.isEmpty) return false;
    final ext = p.extension(path).toLowerCase();
    return ext == '.epub' || ext == '.pdf';
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd app && flutter test test/services/book_open_bridge_test.dart`
Expected: `All tests passed!` (5 tests)

- [ ] **Step 5: 验证 analyze 通过**

Run: `cd app && dart analyze lib/services/book_open_bridge.dart test/services/book_open_bridge_test.dart`
Expected: 0 errors

- [ ] **Step 6: Commit**

```bash
git add app/lib/services/book_open_bridge.dart app/test/services/book_open_bridge_test.dart
git commit -m "$(cat <<'EOF'
feat(m7/t6): BookOpenBridge path validation

Static isSupportedBookPath() guards .epub/.pdf by extension (case-insensitive).
Subsequent tasks will add import + routing logic.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: BookOpenBridge import + 路由（TDD）

**Files:**
- Modify: `app/lib/services/book_open_bridge.dart`
- Modify: `app/test/services/book_open_bridge_test.dart`

- [ ] **Step 1: 写失败测试 — handle path with fakes**

`app/test/services/book_open_bridge_test.dart` 顶部 imports 加：

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/services/book_import_service.dart';
import 'package:zhiyue/services/book_open_bridge.dart';

class _FakeBookImportService extends Mock implements BookImportService {}

class _MockGoRouter extends Mock implements GoRouter {}
```

在 `void main() { ... }` 内加新 group：

```dart
  group('BookOpenBridge.handlePath', () {
    late _FakeBookImportService importer;
    late _MockGoRouter router;
    late Directory tempDir;
    late File epubFile;

    setUp(() async {
      importer = _FakeBookImportService();
      router = _MockGoRouter();
      tempDir = await Directory.systemTemp.createTemp('bridge_test_');
      epubFile = File('${tempDir.path}/book.epub')
        ..writeAsBytesSync([0x50, 0x4B, 0x03, 0x04, 0x00]); // PK header
      registerFallbackValue(Uri.parse('/'));
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('imports and routes to /book/:id for supported path', () async {
      final book = Book(
        id: 'book-1',
        title: 'Test',
        author: null,
        format: BookFormat.epub,
        filePath: epubFile.path,
        fileHash: 'hash',
        fileSizeBytes: 5,
        coverPath: null,
        addedAt: DateTime.now(),
        lastReadAt: null,
      );
      when(() => importer.importFile(any(),
              format: any(named: 'format')))
          .thenAnswer((_) async => ImportResult(book: book, isNew: true));

      await BookOpenBridge.handlePath(
        path: epubFile.path,
        importer: importer,
        router: router,
      );

      // importFile 应以 File 形式收到 path
      final captured = verify(() => importer.importFile(captureAny(),
              format: any(named: 'format')))
          .captured
          .single as File;
      expect(captured.path, epubFile.path);

      // router.push 应被调用到 /book/book-1
      verify(() => router.push('/book/book-1')).called(1);
    });

    test('skips silently on unsupported extension', () async {
      await BookOpenBridge.handlePath(
        path: '/tmp/image.png',
        importer: importer,
        router: router,
      );
      verifyNever(() => importer.importFile(any(),
          format: any(named: 'format')));
      verifyNever(() => router.push(any()));
    });

    test('does not crash when import throws', () async {
      when(() => importer.importFile(any(),
              format: any(named: 'format')))
          .thenThrow(Exception('corrupt file'));

      // 不应抛出（silent failure，避免 native bridge 报错）
      await BookOpenBridge.handlePath(
        path: epubFile.path,
        importer: importer,
        router: router,
      );

      verifyNever(() => router.push(any()));
    });
  });
```

注：需 `mocktail` 依赖。先验证 app/pubspec.yaml dev_dependencies 有 `mocktail: ^1.0.0`，若无则在 Step 2 加。

- [ ] **Step 2: 加 mocktail 依赖（如缺）**

`app/pubspec.yaml` dev_dependencies 末尾加（若不存在）：

```yaml
  mocktail: ^1.0.0
```

Run: `cd app && flutter pub get`

- [ ] **Step 3: 运行测试验证失败**

Run: `cd app && flutter test test/services/book_open_bridge_test.dart`
Expected: FAIL with `handlePath not defined` 或类型错误

- [ ] **Step 4: 实现 handlePath**

`app/lib/services/book_open_bridge.dart` 完整重写：

```dart
import 'dart:io';

import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../data/models/book.dart';
import 'book_import_service.dart';

/// 统一 Android MethodChannel + Windows argv 的文件打开 bridge。
///
/// M7：从 native 层（Android MethodChannel `dev.zhiyue.bookopen` 或
/// Windows main(List<String> args)）接收文件路径，验证为支持的电子书格式，
/// 调用 [BookImportService] 导入，路由到 reader 页面。
class BookOpenBridge {
  const BookOpenBridge._();

  /// 是否是支持的电子书路径（按扩展名白名单）。
  static bool isSupportedBookPath(String path) {
    if (path.isEmpty) return false;
    final ext = p.extension(path).toLowerCase();
    return ext == '.epub' || ext == '.pdf';
  }

  /// 处理 native 层推送的文件路径：导入并路由到 reader。
  ///
  /// 不支持的扩展 / 导入失败均静默忽略（native bridge 不应抛错给 native 层）。
  /// 调用方负责传入已就绪的 [router] 实例（一般来自 routerProvider）。
  static Future<void> handlePath({
    required String path,
    required BookImportService importer,
    required GoRouter router,
  }) async {
    if (!isSupportedBookPath(path)) return;

    try {
      final result = await importer.importFile(File(path));
      router.push('/book/${result.book.id}');
    } catch (_) {
      // 静默忽略：损坏的文件、读权限失败等
      // （SnackBar 报错由 import service 在内部已处理；这里防止 native bridge 异常）
    }
  }
}
```

- [ ] **Step 5: 运行测试验证通过**

Run: `cd app && flutter test test/services/book_open_bridge_test.dart`
Expected: `All tests passed!` (8 tests, 5 + 3 新)

- [ ] **Step 6: 验证 analyze 通过**

Run: `cd app && dart analyze lib/services/book_open_bridge.dart test/services/book_open_bridge_test.dart`
Expected: 0 errors

- [ ] **Step 7: Commit**

```bash
git add app/lib/services/book_open_bridge.dart app/test/services/book_open_bridge_test.dart app/pubspec.yaml app/pubspec.lock
git commit -m "$(cat <<'EOF'
feat(m7/t7): BookOpenBridge.handlePath imports + routes to /book/:id

Static handlePath() validates path, imports via BookImportService, pushes
to /book/{bookId}. Silent failure on unsupported ext / import errors.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Router provider 重构（让 BookOpenBridge 能拿 router）

**Files:**
- Modify: `app/lib/core/router.dart`
- Modify: `app/lib/core/app.dart`

- [ ] **Step 1: router.dart 暴露 routerProvider**

`app/lib/core/router.dart` 顶部加 import：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

文件底部加 provider：

```dart
/// 应用级 [GoRouter] 实例 provider。
///
/// M7 重构：原来 [createAppRouter] 在 ZhiYueApp.build 里每次重建都新建 router
/// （Flutter 反模式）；改为 Riverpod 单例后，BookOpenBridge 和 ZhiYueApp
/// 共用同一 router 实例。
final routerProvider = Provider<GoRouter>((ref) {
  return createAppRouter();
});
```

- [ ] **Step 2: app.dart 改用 routerProvider**

`app/lib/core/app.dart`，`routerConfig: createAppRouter()` 改为：

```dart
      routerConfig: ref.watch(routerProvider),
```

- [ ] **Step 3: 验证 analyze 通过**

Run: `cd app && dart analyze lib/core/router.dart lib/core/app.dart`
Expected: 0 errors

- [ ] **Step 4: 跑全量测试验证不破坏现有 widget tests**

Run: `cd app && flutter test 2>&1 | tail -10`
Expected: `All tests passed!` 或 `+1 skipped`，无 fail（565 baseline）

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/router.dart app/lib/core/app.dart
git commit -m "$(cat <<'EOF'
refactor(m7/t8): routerProvider singleton

Was: ZhiYueApp.build() called createAppRouter() every rebuild (new router
per state change). Now: Riverpod provider; BookOpenBridge reads same
instance via routerProvider.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Android MainActivity MethodChannel bridge

**Files:**
- Modify: `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/MainActivity.kt`

- [ ] **Step 1: 写 MainActivity 完整版**

`app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/MainActivity.kt` 完整替换：

```kotlin
package dev.zhiyue.zhiyue

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "dev.zhiyue.bookopen"
    private var pendingBookPath: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Cold start：从 launch intent 取出文件 URI，转成本地路径暂存
        pendingBookPath = intent?.data?.let { uriToPath(it) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
        // Warm start：app 已运行时收到新文件 URI
        intent.data?.let { uri ->
            uriToPath(uri)?.let { path ->
                methodChannel?.invokeMethod("openBook", path)
            }
        }
    }

    /// 把 file:// / content:// URI 解析为本地文件绝对路径。
    /// file:// → 直接取 path
    /// content:// → 拷贝到 cacheDir 返回副本路径（避免权限 / 持久化问题）
    private fun uriToPath(uri: Uri): String? {
        return when (uri.scheme?.lowercase()) {
            "file" -> uri.path
            "content" -> copyContentToCache(uri)
            else -> null
        }
    }

    private fun copyContentToCache(uri: Uri): String? {
        return try {
            val input = contentResolver.openInputStream(uri) ?: return null
            val tempFile = File(cacheDir, "import_${System.currentTimeMillis()}.book")
            tempFile.outputStream().use { output ->
                input.use { it.copyTo(output) }
            }
            tempFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }
}
```

- [ ] **Step 2: 验证 Android 编译**

Run: `cd app && flutter build apk --debug 2>&1 | tail -5`
Expected: `✓ Built build\\app\\outputs\\flutter-apk\\app-debug.apk`

- [ ] **Step 3: Commit**

```bash
git add app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/MainActivity.kt
git commit -m "$(cat <<'EOF'
feat(m7/t9): MainActivity MethodChannel bridge for file deep-link

Cold start: extract intent.data → cache pendingBookPath, exposed via
'popPendingBookPath' method call.
Warm start: onNewIntent pushes path via 'openBook' invokeMethod.
content:// URIs are copied to cacheDir to bypass SAF permission scope.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: main.dart 接入 BookOpenBridge（含 Windows argv + Android MethodChannel）

**Files:**
- Modify: `app/lib/main.dart`
- Modify: `app/lib/services/book_open_bridge.dart`

- [ ] **Step 1: 写失败测试 — init 流程**

`app/test/services/book_open_bridge_test.dart` 顶部 import 加：

```dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

在 `void main() { ... }` 内加 group：

```dart
  group('BookOpenBridge.init', () {
    late _FakeBookImportService importer;
    late _MockGoRouter router;

    setUp(() {
      importer = _FakeBookImportService();
      router = _MockGoRouter();
    });

    test('handles Windows argv directly when path present', () async {
      final epubPath = '/tmp/win_arg_book.epub';
      // 模拟 import 成功
      final book = Book(
        id: 'b1',
        title: 'T',
        author: null,
        format: BookFormat.epub,
        filePath: epubPath,
        fileHash: 'h',
        fileSizeBytes: 1,
        coverPath: null,
        addedAt: DateTime.now(),
        lastReadAt: null,
      );
      when(() => importer.importFile(any(),
              format: any(named: 'format')))
          .thenAnswer((_) async => ImportResult(book: book, isNew: true));

      // argv = ['--some-flag', '/tmp/win_arg_book.epub']，应过滤非白名单
      await BookOpenBridge.init(
        argv: ['--some-flag', epubPath],
        importer: importer,
        router: router,
      );

      verify(() => router.push('/book/b1')).called(1);
    });

    test('ignores argv with no supported path', () async {
      await BookOpenBridge.init(
        argv: ['--debug', '--enable-logging'],
        importer: importer,
        router: router,
      );
      verifyNever(() => importer.importFile(any(),
          format: any(named: 'format')));
    });
  });
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd app && flutter test test/services/book_open_bridge_test.dart`
Expected: FAIL with `BookOpenBridge.init not defined`

- [ ] **Step 3: 实现 init 方法**

`app/lib/services/book_open_bridge.dart` 加 init 静态方法（imports 加 `dart:async`、`package:flutter/services.dart`）：

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../data/models/book.dart';
import 'book_import_service.dart';

class BookOpenBridge {
  const BookOpenBridge._();

  static const _channel = MethodChannel('dev.zhiyue.bookopen');

  static bool isSupportedBookPath(String path) {
    if (path.isEmpty) return false;
    final ext = p.extension(path).toLowerCase();
    return ext == '.epub' || ext == '.pdf';
  }

  static Future<void> handlePath({
    required String path,
    required BookImportService importer,
    required GoRouter router,
  }) async {
    if (!isSupportedBookPath(path)) return;

    try {
      final result = await importer.importFile(File(path));
      router.push('/book/${result.book.id}');
    } catch (_) {
      // 静默忽略
    }
  }

  /// 启动时调用：处理 Windows argv（桌面端）+ Android MethodChannel
  /// （cold start popPendingBookPath + warm start openBook listener）。
  ///
  /// [argv] 在桌面端来自 main(List<String> args)；Android 端可传空 list。
  static Future<void> init({
    required List<String> argv,
    required BookImportService importer,
    required GoRouter router,
  }) async {
    // 1. Windows argv：找第一个支持的扩展
    for (final arg in argv) {
      if (isSupportedBookPath(arg)) {
        await handlePath(path: arg, importer: importer, router: router);
        break; // 只处理第一个
      }
    }

    // 2. Android MethodChannel
    // 2a. Cold start：popPendingBookPath
    try {
      final pending = await _channel.invokeMethod<String>('popPendingBookPath');
      if (pending != null && pending.isNotEmpty) {
        await handlePath(
            path: pending, importer: importer, router: router);
      }
    } catch (_) {
      // 非 Android 平台 / channel 未注册 → 忽略
    }

    // 2b. Warm start：监听后续推送
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openBook' && call.arguments is String) {
        await handlePath(
          path: call.arguments as String,
          importer: importer,
          router: router,
        );
      }
      return null;
    });
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd app && flutter test test/services/book_open_bridge_test.dart`
Expected: `All tests passed!` (10 tests)

注：在测试环境 MethodChannel 不会真的 invokeMethod，会抛 MissingPluginException，被 catch 忽略。

- [ ] **Step 5: 验证 analyze 通过**

Run: `cd app && dart analyze lib/services/book_open_bridge.dart test/services/book_open_bridge_test.dart`
Expected: 0 errors

- [ ] **Step 6: 改 main.dart 接入**

`app/lib/main.dart` 完整重写：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'core/app.dart';
import 'core/app_providers.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'services/book_open_bridge.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize(); // M4: pdfrx 引擎初始化

  final container = ProviderContainer(overrides: providers);

  // M7: 启动后处理文件 deep-link（Windows argv + Android MethodChannel）。
  // 用 post-frame callback 确保 router 已 mount 后再 push，避免冷启动时
  // navigator 状态未就绪。
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final router = container.read(routerProvider);
    // bookImportServiceProvider 是 FutureProvider，需 await 解包
    final importer = await container.read(bookImportServiceProvider.future);
    await BookOpenBridge.init(
      argv: args,
      importer: importer,
      router: router,
    );
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ZhiYueApp(),
    ),
  );
}
```

注：
- 用 `UncontrolledProviderScope + ProviderContainer` 是因为我们需要 `container.read` 在 runApp 之前先拿到 router/importer。
- `bookImportServiceProvider` 在 `app/lib/core/providers.dart:64` 定义为 `FutureProvider<BookImportService>`，必须用 `.future` 后缀 await。
- `app_providers.dart` 当前导出空的 `providers` list（兼容入口）；如果未来加 override，仍在此处。

- [ ] **Step 7: 验证 providers.dart 的 provider 名（subagent 必须 grep 确认）**

Run: `grep -n "bookImportServiceProvider" app/lib/core/providers.dart`
Expected: 找到第 64 行 `final bookImportServiceProvider = FutureProvider<BookImportService>((ref) async {`

若 provider 不存在或名字不同，subagent 必须停下来报告 BLOCKED，由 controller 决定如何处理。

- [ ] **Step 8: 跑全量测试**

Run: `cd app && flutter test 2>&1 | tail -5`
Expected: All tests passed（≥ 575 baseline = 565 + 10 新）

- [ ] **Step 9: Commit**

```bash
git add app/lib/main.dart app/lib/services/book_open_bridge.dart app/test/services/book_open_bridge_test.dart
git commit -m "$(cat <<'EOF'
feat(m7/t10): wire BookOpenBridge into main.dart

- main(List<String> args) accepts Windows argv
- Post-frame callback reads routerProvider + bookImportServiceProvider
- BookOpenBridge.init handles Windows argv + Android MethodChannel
  (popPendingBookPath cold start + openBook warm start)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: 应用图标资源 + flutter_launcher_icons 运行文档

**Files:**
- Create: `app/assets/icon.png` (1024×1024)
- Create: `app/assets/icon_foreground.png` (1024×1024, 用于 Android adaptive icon)
- Update: `app/README.md` (加图标生成工作流)

**说明**：本任务依赖用户用 AI 生图工具（Midjourney / DALL-E / SD）按 spec §4.1 提示词生成 1024×1024 主图。**如果用户还没生成图，本任务可以跳过 commit，由用户后续手工跑命令**。

- [ ] **Step 1: 用户提供 icon.png 后放置到 app/assets/**

把 AI 生成的 1024×1024 PNG 命名为 `icon.png`，放到 `app/assets/icon.png`。

如果是 adaptive icon（Android），需要单独的 `icon_foreground.png`（背景透明，前景居中 60% 大小）。可以暂时用 `icon.png` 重复。

- [ ] **Step 2: 运行 flutter_launcher_icons**

Run: `cd app && dart run flutter_launcher_icons`
Expected: 输出类似：
```
Android adaptive icons generated
Android round icons generated
Windows icon generated
```

- [ ] **Step 3: 验证生成的产物存在**

Run:
```bash
ls app/android/app/src/main/res/mipmap-hdpi/ic_launcher.png
ls app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
ls app/windows/runner/resources/app_icon.ico
```
Expected: 三个文件都存在，非零字节

- [ ] **Step 4: README 加图标生成工作流段落**

`app/README.md` 加段落（如不存在则创建文件）：

```markdown
## 应用图标生成

图标源文件 `app/assets/icon.png`（1024×1024）。运行：

```bash
cd app && dart run flutter_launcher_icons
```

会重新生成 Android 各分辨率 mipmap + Windows .ico。

修改源文件后请重新运行此命令并提交所有生成产物。
```

- [ ] **Step 5: 验证 Android + Windows 仍可 build**

Run: `cd app && flutter build apk --debug 2>&1 | tail -3 && flutter build windows --debug 2>&1 | tail -3`
Expected: 两个 build 都成功

- [ ] **Step 6: Commit**

```bash
git add app/assets/icon.png app/assets/icon_foreground.png \
  app/android/app/src/main/res/mipmap-*/ic_launcher.png \
  app/android/app/src/main/res/mipmap-*/ic_launcher_round.png \
  app/android/app/src/main/res/mipmap-*/ic_launcher_foreground.png \
  app/android/app/src/main/res/mipmap-*/ic_launcher_background.png \
  app/android/app/src/main/res/values/colors.xml \
  app/windows/runner/resources/app_icon.ico \
  app/README.md
git commit -m "$(cat <<'EOF'
feat(m7/t11): app icon assets generated via flutter_launcher_icons

Source: assets/icon.png (1024x1024). Generated: Android mipmap-*,
adaptive icon foreground/background, Windows app_icon.ico.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

注：如果某些文件 path 不存在（比如 colors.xml 已存在），按实际产物调整 git add。

---

## Task 12: 手动 smoke test 文档 + tag m7-complete + v0.4.0

**Files:**
- Update: `app/README.md` (加 smoke test 段落)

- [ ] **Step 1: README 加 smoke test 流程**

`app/README.md` 加段落：

```markdown
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
```

- [ ] **Step 2: Commit README**

```bash
git add app/README.md
git commit -m "$(cat <<'EOF'
docs(m7/t12): smoke test procedure for Android + Windows

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: 跑全量测试确认无回归**

Run: `cd app && flutter test 2>&1 | tail -3 && cd ../reader_engine && flutter test 2>&1 | tail -3 && cd ../reader_engine_epub_view && flutter test 2>&1 | tail -3 && cd ../reader_engine_pdf_view && flutter test 2>&1 | tail -3`
Expected: 4 个包全部通过，总数 ≥ 575（565 baseline + 10 新）

- [ ] **Step 4: 验证 analyze 干净**

Run: `cd app && dart analyze 2>&1 | tail -3`
Expected: `No issues found!` 或仅 pre-existing infos

- [ ] **Step 5: 打 tag m7-complete + v0.4.0**

```bash
git tag m7-complete
git tag v0.4.0
git push origin master
git push origin m7-complete v0.4.0
```

- [ ] **Step 6: 提交 task 完成**

向 controller 报告：12 tasks 完成，新增 ~10 tests，tag 已推。

---

## Self-Review Checklist

### Spec coverage

| Spec section | Implemented by |
|---|---|
| §3.1 Deep-link 完整做 | T6 + T7 + T9 + T10 |
| §3.2 不做 splash + backup | skipped ✓ |
| §3.3 Signing 本地 keystore + .env | T4 |
| §3.4 flutter_launcher_icons pipeline | T1 + T11 |
| §4.1 App icon pipeline | T1 + T11 |
| §4.2 Display name 智阅 | T2 |
| §4.3 Android intent-filter | T5 |
| §4.4 Native deep-link bridge | T6 + T7 + T9 + T10 |
| §4.5 Android signing | T4 |
| §4.6 Version bump | T3 |
| §5 数据流 | 全程贯穿 T6-T10 |
| §6 错误处理 | T7（silent failure）+ T6（whitelist） |
| §7 测试策略 | T6 + T7 + T10 unit tests；T9/T11 平台验证；T12 手动 smoke |
| §8 不在 M7 范围 | 全部未做 ✓ |
| §9 任务估算 10-12 个 | 实际 12 个 ✓ |

无 spec gap。

### Type consistency

- `BookOpenBridge.isSupportedBookPath(String)` 在 T6 定义，T7/T10 使用 ✓
- `BookOpenBridge.handlePath({path, importer, router})` 在 T7 定义，T10 使用 ✓
- `BookOpenBridge.init({argv, importer, router})` 在 T10 定义 ✓
- `routerProvider` 在 T8 定义，T10 通过 `container.read(routerProvider)` 使用 ✓
- `bookImportServiceProvider` 在 T10 引用（subagent 必须先 grep 找到现有 provider 名）

### 红旗扫描

- 无 TBD/TODO ✓
- 每个 code step 都有完整代码块 ✓
- 测试断言具体（verify/push called 1 次）✓
- 平台任务（T1-T5, T9, T11, T12）有 build 验证替代单测 ✓

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-28-m7-platform-adaptation.md`. Two execution options:

1. **Subagent-Driven (recommended)** - 我分派 fresh subagent 每个 task，两段 review（spec compliance → code quality）
2. **Inline Execution** - 当前 session 内批量执行，checkpoint review

选哪个？
