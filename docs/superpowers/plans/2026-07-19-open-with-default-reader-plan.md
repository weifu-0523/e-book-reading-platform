# v1.14.0-alpha: 「直接打开电子书」修复 + 「设为默认阅读器」提示

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 Android「从文件管理器点 .epub 选智阅打开失败」+ Windows「智阅已运行时双击 .epub 无反应」两个 bug；新增「设为默认阅读器」首次启动提示（Windows 写 HKCU 注册表 / Android 跳系统设置）。

**Architecture:**
- **Bug 1（Android）**：`MainActivity.kt` 加 `inferExtensionFromUri`，`copyContentToCache` 用推断出的扩展名（替换固定 `.book`）
- **Bug 2（Windows warm start）**：`flutter_window.cpp` 加 `cached_argv_` 字段缓存 WM_COPYDATA payload + 注册 `popPendingArgv` method handler；`book_open_bridge.dart` 加 Windows cold-pop 路径
- **新功能 3a（Windows 设默认）**：`default_reader_registry.cpp` 实现 `readAssoc` / `set_default_reader`，写 HKCU 注册表 + `SHChangeNotify`
- **新功能 3b（Android 跳系统设置）**：`MainActivity.kt` 加 `openDefaultAppsSettings` handler（Intent ACTION_MANAGE_DEFAULT_APPS_SETTINGS）
- **状态层**：`AppSettings.promptedDefaultReader` 持久化（首次启动后不再问）
- **UI 层**：`DefaultReaderPromptDialog`（首次启动）+ 设置页 tile（手动入口）

**Tech Stack:** Flutter 3.x + Dart 3.x + Kotlin 1.9 + C++ (Windows runner) + Riverpod StateNotifier + Inno Setup 6

**Spec:** `docs/superpowers/specs/2026-07-19-open-with-default-reader-design.md`

---

## File Structure

### Create

- `app/lib/features/settings/default_reader/default_reader_detector.dart` — 抽象 + Win/Android stub
- `app/lib/features/settings/default_reader/app_settings.dart` — `AppSettings.promptedDefaultReader` 持久化
- `app/lib/features/settings/default_reader/widgets/default_reader_prompt_dialog.dart`
- `app/lib/features/settings/default_reader/widgets/default_reader_settings_tile.dart`
- `app/lib/features/settings/default_reader/default_reader_dialog_coordinator.dart` — 首次启动触发器
- `app/test/features/settings/default_reader/default_reader_detector_test.dart`
- `app/test/features/settings/default_reader/app_settings_test.dart`
- `app/test/features/settings/default_reader/default_reader_prompt_dialog_test.dart`
- `app/test/services/book_open_bridge_warm_start_test.dart`
- `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/MainActivityExtensionInferTest.kt`
- `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/DefaultAppsSettingsLauncherTest.kt`
- `app/windows/runner/default_reader_registry.h`
- `app/windows/runner/default_reader_registry.cpp`
- `app/windows/runner/test_default_reader_registry.cpp`

### Modify

- `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/MainActivity.kt` — T1 `inferExtensionFromUri` + `copyContentToCache`；T5 `openDefaultAppsSettings` handler
- `app/windows/runner/flutter_window.h` — T2 加 `cached_argv_` 字段 + `popPendingArgv` handler 声明
- `app/windows/runner/flutter_window.cpp` — T2 接收 WM_COPYDATA 时缓存 + 注册 `popPendingArgv` handler；T4 注册 `readAssoc` / `set_default_reader` handler
- `app/lib/services/book_open_bridge.dart` — T3 加 Windows `popPendingArgv` 路径
- `app/lib/main.dart` — T7 注入 `DefaultReaderDialogCoordinator` 首次启动检测
- `app/lib/features/settings/pages/settings_page.dart` — T7 加「设为默认阅读器」tile
- `app/lib/l10n/app_zh.arb` / `app_en.arb` — i18n strings
- `app/windows/runner/CMakeLists.txt` — T4 加 `default_reader_registry.cpp` 编译目标 + 测试可执行
- `app/pubspec.yaml` — `1.14.0-alpha+2009`（与 tts-multi-voice plan 共用）
- `CHANGELOG.md` — `[1.14.0-alpha]` 段落（与 tts-multi-voice plan 共用）
- `app/windows/installer/zhiyue.iss` — `MyAppVersion` → `1.14.0-alpha`

---

## TDD 实施顺序

`C:\zhiyue_build_s3` ASCII worktree（branch `s4-build`）。每 task 独立 commit。

| Task | Scope | 文件数 |
|---|---|---|
| **T1** | Android MainActivity `inferExtensionFromUri` + `copyContentToCache` 用推断扩展名 | 1 修改 + 1 测试 |
| **T2** | Windows flutter_window.cpp `cached_argv_` + `popPendingArgv` handler | 2 修改 + 现有 smoke test 扩展 |
| **T3** | book_open_bridge.dart 加 Windows `popPendingArgv` Dart 路径 | 1 修改 + 1 测试 |
| **T4** | Windows `default_reader_registry.cpp` 实现 `readAssoc` / `set_default_reader` + flutter_window 接线 | 2 新建 + 1 测试 + 1 修改 |
| **T5** | Android MainActivity `openDefaultAppsSettings` handler | 1 修改（T1 同文件）+ 1 测试 |
| **T6** | Dart `DefaultReaderDetector` + `AppSettings` 持久化 | 2 新建 + 2 测试 |
| **T7** | `DefaultReaderPromptDialog` + `DefaultReaderDialogCoordinator` + 设置页 tile | 3 新建 + 1 修改 + 1 测试 + l10n |
| **T8** | Release v1.14.0-alpha（与 tts-multi-voice plan 合并执行） | 共用 pubspec + CHANGELOG + installer |

---

## Task 1: Android MainActivity `inferExtensionFromUri`

**Files:**
- Modify: `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/MainActivity.kt`
- Test: `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/MainActivityExtensionInferTest.kt`

- [ ] **Step 1: Write failing Robolectric test**

Create `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/MainActivityExtensionInferTest.kt`:

```kotlin
package dev.zhiyue.zhiyue

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import androidx.test.core.app.ApplicationProvider
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.assertj.core.api.Assertions.assertThat

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class MainActivityExtensionInferTest {

    private val activity = MainActivity()

    @Test
    fun `inferExtension takes dot-epub from lastPathSegment`() {
        val uri = Uri.parse("content://media/external/file/123/%E4%B8%89%E4%BD%93.epub")
        // URI-encoded "三体.epub" → after Android decode = "三体.epub"
        val ext = activity.inferExtensionFromUriForTest(uri)
        assertThat(ext).isEqualTo(".epub")
    }

    @Test
    fun `inferExtension takes dot-pdf from lastPathSegment`() {
        val uri = Uri.parse("content://media/external/file/456/report.pdf")
        assertThat(activity.inferExtensionFromUriForTest(uri)).isEqualTo(".pdf")
    }

    @Test
    fun `inferExtension returns empty when lastPathSegment has no extension`() {
        val uri = Uri.parse("content://media/external/file/123")
        assertThat(activity.inferExtensionFromUriForTest(uri)).isEmpty()
    }

    @Test
    fun `inferExtension returns empty for unsupported extension like docx`() {
        val uri = Uri.parse("content://x/y/z.docx")
        assertThat(activity.inferExtensionFromUriForTest(uri)).isEmpty()
    }

    @Test
    fun `inferExtension falls back to MIME type when no path extension`() {
        // simulated content provider returns application/epub+zip for a URI
        // without file extension
        val uri = Uri.parse("content://fake.provider/123")
        activity.setContentResolverForTest(FakeContentResolver(mapOf(
            uri to "application/epub+zip"
        )))
        assertThat(activity.inferExtensionFromUriForTest(uri)).isEqualTo(".epub")
    }
}

/// Minimal fake ContentResolver that returns canned MIME types.
class FakeContentResolver(private val mimeByUri: Map<Uri, String>) {
    fun getType(uri: Uri): String? = mimeByUri[uri]
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3\app\android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*ExtensionInferTest"
```

Expected: FAIL — `inferExtensionFromUriForTest` doesn't exist.

- [ ] **Step 3: Implement `inferExtensionFromUri` + update `copyContentToCache`**

Modify `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/MainActivity.kt`:

```kotlin
// Add at top of class:
private val supportedExtensions = listOf(
    ".epub", ".pdf", ".txt", ".md", ".markdown", ".mdown"
)

/// v1.14.0-alpha T1: infers the file extension for a content/file URI.
/// Order: (1) lastPathSegment, (2) MIME type via ContentResolver.
/// Returns ".epub" / ".pdf" / ".txt" / ".md" / ".markdown" / ".mdown",
/// or "" when no supported extension can be determined.
@VisibleForTesting
fun inferExtensionFromUriForTest(uri: Uri): String {
    // 1. lastPathSegment usually contains the original filename
    val last = uri.lastPathSegment ?: ""
    val dot = last.lastIndexOf('.')
    if (dot >= 0) {
        val ext = last.substring(dot).lowercase()
        if (ext in supportedExtensions) return ext
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

/// Test seam to inject fake ContentResolver.
@VisibleForTesting
fun setContentResolverForTest(fake: Any) {
    // Reflection or use a delegated field; for Robolectric use ApplicationProvider
}
```

Update `copyContentToCache` to use it:

```kotlin
private fun copyContentToCache(uri: Uri): String? {
    return try {
        val extension = inferExtensionFromUriForTest(uri)
        // extension includes dot (".epub") or is empty
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
```

Add imports: `import androidx.annotation.VisibleForTesting`.

- [ ] **Step 4: Run test to verify it passes**

```bash
cd C:\zhiyue_build_s3\app\android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*ExtensionInferTest"
```

Expected: PASS (5 tests).

- [ ] **Step 5: Run full Kotlin test suite**

```bash
cd C:\zhiyue_build_s3\app\android && ./gradlew :app:testWithFgsDebugUnitTest
```

Expected: All pass.

- [ ] **Step 6: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/MainActivity.kt \
        app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/MainActivityExtensionInferTest.kt
git commit -m "$(cat <<'EOF'
fix(android): preserve source extension in copyContentToCache

v1.14.0-alpha T1: MainActivity.inferExtensionFromUri infers .epub / .pdf /
.txt / .md from URI lastPathSegment, falling back to ContentResolver
MIME type. Replaces the hard-coded ".book" extension that broke
BookFormatDetector's EPUB detection and caused deep-link open to fail.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Windows flutter_window `cached_argv_` + `popPendingArgv`

**Files:**
- Modify: `app/windows/runner/flutter_window.h`
- Modify: `app/windows/runner/flutter_window.cpp`
- Modify existing smoke test if needed: `app/windows/runner/test_main.cpp`

- [ ] **Step 1: Write failing C++ smoke test**

Extend `app/windows/runner/test_main.cpp` (or create new test file):

```cpp
// Add to test_main.cpp:
TEST(FlutterWindowCopyData, CachesArgvWhenReceivedBeforeChannelReady) {
  FlutterWindowTestHarness harness;
  harness.SimulateWmCopyData("C:\\path\\book.epub");
  EXPECT_EQ(harness.cached_argv(), "C:\\path\\book.epub");
}

TEST(FlutterWindowCopyData, PopPendingArgvReturnsAndClearsCache) {
  FlutterWindowTestHarness harness;
  harness.SimulateWmCopyData("C:\\path\\book.epub");
  auto first = harness.CallPopPendingArgv();
  ASSERT_TRUE(first.has_value());
  EXPECT_EQ(*first, "C:\\path\\book.epub");
  // Second call returns empty
  auto second = harness.CallPopPendingArgv();
  EXPECT_FALSE(second.has_value());
}

TEST(FlutterWindowCopyData, UnsupportedExtensionNotCached) {
  FlutterWindowTestHarness harness;
  harness.SimulateWmCopyData("C:\\path\\notes.txt");  // .txt IS supported
  EXPECT_EQ(harness.cached_argv(), "C:\\path\\notes.txt");
  // .docx (unsupported):
  harness.SimulateWmCopyData("C:\\path\\notes.docx");
  // Current impl: cache even unsupported (Dart-side filter). Document behavior.
}
```

Note: depends on a `FlutterWindowTestHarness` that exposes the cached state. Add as friend class or via `#ifdef ZHIYUE_TESTING`.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3\app\windows\runner && ./run_smoke_test.bat
```

Expected: FAIL — `cached_argv()` accessors don't exist.

- [ ] **Step 3: Add cached_argv_ field + handler wiring**

Modify `app/windows/runner/flutter_window.h`:

```cpp
#pragma once

#include <optional>
#include <string>

#include "flutter/flutter_view.h"
#include "win32_window.h"

class FlutterWindow : public Win32Window {
 public:
  explicit FlutterWindow(const flutter::DartProject& project);
  ~FlutterWindow();

  // v1.14.0-alpha T2: test seam — returns last cached argv from WM_COPYDATA.
  // For production use popPendingArgv via MethodChannel.
  #ifdef ZHIYUE_TESTING
  const std::string& cached_argv_for_test() const { return cached_argv_; }
  std::optional<std::string> PopPendingArgvForTest() {
    if (cached_argv_.empty()) return std::nullopt;
    auto out = cached_argv_;
    cached_argv_.clear();
    return out;
  }
  void SimulateWmCopyDataForTest(const std::string& arg) {
    cached_argv_ = arg;
  }
  #endif

 private:
  // ... existing methods ...

  flutter::DartProject project_;
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  // v1.14.0-alpha T2: caches the most recent argv forwarded by a second
  // instance via WM_COPYDATA. Read + cleared by Dart via popPendingArgv
  // MethodChannel call. Defends against the race where WM_COPYDATA arrives
  // before Dart's setMethodCallHandler has registered (channel_->InvokeMethod
  // would silently drop).
  std::string cached_argv_;
};
```

Modify `app/windows/runner/flutter_window.cpp`:

```cpp
// In MessageHandler, WM_COPYDATA branch:
if (message == WM_COPYDATA) {
  auto* cds = reinterpret_cast<COPYDATASTRUCT*>(lparam);
  if (cds != nullptr && cds->dwData == kCopyDataArgvTag) {
    std::string arg(reinterpret_cast<const char*>(cds->lpData),
                    cds->cbData > 0 ? cds->cbData - 1 : 0);
    cached_argv_ = arg;  // ← cache regardless
    if (channel_) {
      channel_->InvokeMethod("openBook",
          std::make_unique<flutter::EncodableValue>(arg));
    }
  }
  return 0;
}

// In OnCreate (where channel_ is created), add MethodCallHandler:
channel_->SetMethodCallHandler(
  [this](const flutter::EncodableValue& call, auto result) {
    if (const auto* method_name = std::get_if<std::string>(&call)) {
      if (*method_name == "popPendingArgv") {
        if (cached_argv_.empty()) {
          result->Success(flutter::EncodableValue(""));
        } else {
          std::string out = cached_argv_;
          cached_argv_.clear();
          result->Success(flutter::EncodableValue(out));
        }
        return;
      }
    }
    result->NotImplemented();
  });
```

Note: The exact `SetMethodCallHandler` signature depends on Flutter C++ API version; verify against `flutter::MethodChannel::SetMethodCallHandler` typedef in your Flutter SDK.

- [ ] **Step 4: Run smoke test to verify it passes**

```bash
cd C:\zhiyue_build_s3\app\windows\runner && ./run_smoke_test.bat
```

Expected: PASS (existing + 3 new tests).

- [ ] **Step 5: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/windows/runner/flutter_window.h app/windows/runner/flutter_window.cpp \
        app/windows/runner/test_main.cpp
git commit -m "$(cat <<'EOF'
fix(windows): cache argv from WM_COPYDATA + add popPendingArgv handler

v1.14.0-alpha T2: FlutterWindow caches the latest WM_COPYDATA payload in
cached_argv_, regardless of whether Dart's setMethodCallHandler is ready.
Dart calls popPendingArgv on init to drain the cache, defending against
the warm-start race where second-instance argv arrived before the Dart
handler registered (manifested as "double-click .epub does nothing while
app is running").

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: book_open_bridge.dart 加 Windows popPendingArgv 路径

**Files:**
- Modify: `app/lib/services/book_open_bridge.dart`
- Test: `app/test/services/book_open_bridge_warm_start_test.dart`

- [ ] **Step 1: Write failing test**

Create `app/test/services/book_open_bridge_warm_start_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyue/services/book_import_service.dart';
import 'package:zhiyue/services/book_open_bridge.dart';
import 'package:zhiyue/data/models/book.dart';

class _MockImporter extends Mock implements BookImportService {}
class _FakeRouter extends Fake implements GoRouter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockImporter importer;
  late GoRouter router;
  final List<String> pushedRoutes = [];

  setUp(() {
    importer = _MockImporter();
    pushedRoutes.clear();
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const SizedBox(),
        ),
        GoRoute(
          path: '/book/:id',
          builder: (_, __) => const SizedBox(),
        ),
      ],
      redirect: (context, state) {
        if (state.path.toString().startsWith('/book/')) {
          pushedRoutes.add(state.path.toString());
        }
        return null;
      },
    );
  });

  test('Windows popPendingArgv returns cached path → triggers import', () async {
    const cachedPath = 'C:\\test\\book.epub';
    final mockFile = File(cachedPath);
    // Mock the file existing + bytes
    await mockFile.writeAsBytes([0x50, 0x4B, 0x03, 0x04]);  // ZIP magic + .epub

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.bookopen'),
            (call) async {
      if (call.method == 'popPendingArgv') return cachedPath;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.bookopen'), null);
      if (mockFile.existsSync()) mockFile.deleteSync();
    });

    final book = Book(
      id: 'b1', title: 'T', format: BookFormat.epub,
      filePath: '/p.epub', fileHash: 'h', fileSizeBytes: 4,
      addedAt: DateTime.now(),
    );
    when(() => importer.importFile(any)).thenAnswer((_) async =>
        ImportResult(book: book, isNew: true));

    await BookOpenBridge.init(argv: const [], importer: importer, router: router);

    verify(() => importer.importFile(any())).called(1);
  });

  test('popPendingArgv empty → no import attempted', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.bookopen'),
            (call) async {
      if (call.method == 'popPendingArgv') return '';
      if (call.method == 'popPendingBookPath') return null;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.bookopen'), null);
    });

    await BookOpenBridge.init(argv: const [], importer: importer, router: router);

    verifyNever(() => importer.importFile(any()));
  });

  test('popPendingArgv with unsupported path → no import', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.bookopen'),
            (call) async {
      if (call.method == 'popPendingArgv') return 'C:\\notes.docx';
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.bookopen'), null);
    });

    await BookOpenBridge.init(argv: const [], importer: importer, router: router);

    verifyNever(() => importer.importFile(any()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3 && flutter test test/services/book_open_bridge_warm_start_test.dart
```

Expected: FAIL — `popPendingArgv` not called by BookOpenBridge.

- [ ] **Step 3: Add Windows cold-pop path to BookOpenBridge.init**

Modify `app/lib/services/book_open_bridge.dart`:

```dart
static Future<void> init({
  required List<String> argv,
  required BookImportService importer,
  required GoRouter router,
  BookOpenBridgeOptions options = const BookOpenBridgeOptions(),
}) async {
  // 1. Windows argv (first instance process - already in main.dart args)
  for (final arg in argv) {
    if (isSupportedBookPath(arg)) {
      await handlePath(path: arg, importer: importer, router: router, options: options);
      break;
    }
  }

  // 2a. Android cold start (popPendingBookPath)
  try {
    final pending = await _channel.invokeMethod<String>('popPendingBookPath');
    if (pending != null && pending.isNotEmpty) {
      await handlePath(path: pending, importer: importer, router: router, options: options);
    }
  } catch (_) {
    // Non-Android / channel not registered → ignore
  }

  // 2a-bis. v1.14.0-alpha T3: Windows cold-pop (warm-start argv cached in C++).
  // Runs after Android popPendingBookPath (no-op on Windows since channel
  // returns null for unknown methods on Android). Defensive try-catch.
  try {
    final cached = await _channel.invokeMethod<String>('popPendingArgv');
    if (cached != null && cached.isNotEmpty && isSupportedBookPath(cached)) {
      await handlePath(path: cached, importer: importer, router: router, options: options);
    }
  } catch (_) {
    // Non-Windows / channel not registered → ignore
  }

  // 2b. Warm-start listener (already exists)
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'openBook' && call.arguments is String) {
      await handlePath(
        path: call.arguments as String,
        importer: importer,
        router: router,
        options: options,
      );
    }
    return null;
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd C:\zhiyue_build_s3 && flutter test test/services/book_open_bridge_warm_start_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Run full Dart test suite**

```bash
cd C:\zhiyue_build_s3 && flutter test
```

Expected: All pass.

- [ ] **Step 6: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/services/book_open_bridge.dart app/test/services/book_open_bridge_warm_start_test.dart
git commit -m "$(cat <<'EOF'
feat(open-with): drain cached argv on Windows warm start

v1.14.0-alpha T3: BookOpenBridge.init calls popPendingArgv after
popPendingBookPath (Android) to drain the C++ cached_argv_ from the
most recent WM_COPYDATA. Pairs with T2's caching layer to fix the
warm-start race that dropped second-instance argv before Dart handler
registered.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Windows `default_reader_registry.cpp` 实现 readAssoc / set_default_reader

**Files:**
- Create: `app/windows/runner/default_reader_registry.h`
- Create: `app/windows/runner/default_reader_registry.cpp`
- Create: `app/windows/runner/test_default_reader_registry.cpp`
- Modify: `app/windows/runner/flutter_window.cpp` (register handlers)
- Modify: `app/windows/runner/CMakeLists.txt` (compile target)

- [ ] **Step 1: Write failing C++ smoke test**

Create `app/windows/runner/test_default_reader_registry.cpp`:

```cpp
#include "default_reader_registry.h"

#include <gtest/gtest.h>
#include <windows.h>

TEST(DefaultReaderRegistry, SetAndReadEpubAssocRoundTrip) {
  // Save original to restore after test
  HKEY key;
  const wchar_t* kEpubKeyPath = L"Software\\Classes\\.epub";
  std::wstring original_value;
  bool had_original = false;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kEpubKeyPath, 0, KEY_READ, &key)
      == ERROR_SUCCESS) {
    wchar_t buf[MAX_PATH];
    DWORD buf_size = sizeof(buf);
    if (RegQueryValueExW(key, nullptr, nullptr, nullptr,
                         reinterpret_cast<LPBYTE>(buf), &buf_size)
        == ERROR_SUCCESS) {
      original_value = buf;
      had_original = true;
    }
    RegCloseKey(key);
  }

  // Run test
  ASSERT_TRUE(zhiyue::SetDefaultReaderForExtension(L".epub",
      L"C:\\Program Files\\ZhiYue\\zhiyue.exe"));

  auto cmd = zhiyue::ReadAssocForExtension(L".epub");
  ASSERT_TRUE(cmd.has_value());
  EXPECT_NE(cmd->find(L"zhiyue.exe"), std::wstring::npos);

  // Restore (or delete what we wrote)
  if (had_original) {
    RegSetValueExW(HKEY_CURRENT_USER, kEpubKeyPath, 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(original_value.c_str()),
                       static_cast<DWORD>((original_value.size() + 1) * sizeof(wchar_t)));
  }
  // NOTE: SetDefaultReaderForExtension writes HKCU\Software\Classes\.epub\*,
  //       restoring requires writing back to the same tree.
}
```

Note: This test modifies HKCU; CI environments should run in isolated user context. For local dev this is safe.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3\app\windows\runner && ./run_smoke_test.bat
```

Expected: FAIL — `default_reader_registry.h` doesn't exist.

- [ ] **Step 3: Implement default_reader_registry**

Create `app/windows/runner/default_reader_registry.h`:

```cpp
#pragma once

#include <optional>
#include <string>

namespace zhiyue {

/// Reads the current HKCU file association command for [ext] (e.g. L".epub").
/// Returns the shell/open/command string (typically `"path\zhiyue.exe" "%1"`),
/// or nullopt if no association exists for the current user.
std::optional<std::wstring> ReadAssocForExtension(const std::wstring& ext);

/// Sets HKCU\Software\Classes\<ext> to point at [exe_path] for shell/open.
/// Writes both the progid (ZhiYue.Book / ZhiYue.Pdf) and the open command.
/// Calls SHChangeNotify to refresh Explorer's icon cache.
/// Returns true on success, false on any registry error.
bool SetDefaultReaderForExtension(const std::wstring& ext,
                                  const std::wstring& exe_path);

}  // namespace zhiyue
```

Create `app/windows/runner/default_reader_registry.cpp`:

```cpp
#include "default_reader_registry.h"

#include <windows.h>
#include <shlobj.h>

#include <sstream>

namespace zhiyue {

std::optional<std::wstring> ReadAssocForExtension(const std::wstring& ext) {
  // Step 1: read HKCU\Software\Classes\<ext> default value (progid)
  HKEY ext_key;
  std::wstring path = L"Software\\Classes\\" + ext;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, path.c_str(), 0, KEY_READ, &ext_key)
      != ERROR_SUCCESS) {
    return std::nullopt;
  }
  wchar_t progid[MAX_PATH];
  DWORD progid_size = sizeof(progid);
  DWORD type;
  LSTATUS rc = RegQueryValueExW(ext_key, nullptr, nullptr, &type,
      reinterpret_cast<LPBYTE>(progid), &progid_size);
  RegCloseKey(ext_key);
  if (rc != ERROR_SUCCESS || type != REG_SZ) return std::nullopt;

  // Step 2: read HKCU\Software\Classes\<progid>\shell\open\command
  std::wstring cmd_path =
      L"Software\\Classes\\" + std::wstring(progid) + L"\\shell\\open\\command";
  HKEY cmd_key;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, cmd_path.c_str(), 0, KEY_READ, &cmd_key)
      != ERROR_SUCCESS) {
    return std::nullopt;
  }
  wchar_t cmd[MAX_PATH * 2];
  DWORD cmd_size = sizeof(cmd);
  rc = RegQueryValueExW(cmd_key, nullptr, nullptr, &type,
      reinterpret_cast<LPBYTE>(cmd), &cmd_size);
  RegCloseKey(cmd_key);
  if (rc != ERROR_SUCCESS) return std::nullopt;
  return std::wstring(cmd);
}

bool SetDefaultReaderForExtension(const std::wstring& ext,
                                  const std::wstring& exe_path) {
  // Choose progid by extension
  std::wstring progid;
  if (ext == L".epub") {
    progid = L"ZhiYue.Book";
  } else if (ext == L".pdf") {
    progid = L"ZhiYue.Pdf";
  } else {
    progid = L"ZhiYue.File";
  }

  // 1. HKCU\Software\Classes\<ext> = progid
  std::wstring ext_path = L"Software\\Classes\\" + ext;
  HKEY ext_key;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, ext_path.c_str(), 0, nullptr, 0,
          KEY_WRITE, nullptr, &ext_key, nullptr) != ERROR_SUCCESS) {
    return false;
  }
  LSTATUS rc = RegSetValueExW(ext_key, nullptr, 0, REG_SZ,
      reinterpret_cast<LPCWSTR>(progid.c_str()),
      static_cast<DWORD>((progid.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(ext_key);
  if (rc != ERROR_SUCCESS) return false;

  // 2. HKCU\Software\Classes\<progid> = "ZhiYue 图书" (friendly name)
  std::wstring progid_path = L"Software\\Classes\\" + progid;
  HKEY progid_key;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, progid_path.c_str(), 0, nullptr, 0,
          KEY_WRITE, nullptr, &progid_key, nullptr) != ERROR_SUCCESS) {
    return false;
  }
  std::wstring friendly = L"ZhiYue Document";
  RegSetValueExW(progid_key, nullptr, 0, REG_SZ,
      reinterpret_cast<LPCWSTR>(friendly.c_str()),
      static_cast<DWORD>((friendly.size() + 1) * sizeof(wchar_t)));

  // 3. <progid>\shell\open\command = '"exe_path" "%1"'
  HKEY cmd_key;
  std::wstring cmd_subpath = progid_path + L"\\shell\\open\\command";
  if (RegCreateKeyExW(HKEY_CURRENT_USER, cmd_subpath.c_str(), 0, nullptr, 0,
          KEY_WRITE, nullptr, &cmd_key, nullptr) != ERROR_SUCCESS) {
    RegCloseKey(progid_key);
    return false;
  }
  std::wstring cmd = L"\"" + exe_path + L"\" \"%1\"";
  rc = RegSetValueExW(cmd_key, nullptr, 0, REG_SZ,
      reinterpret_cast<LPCWSTR>(cmd.c_str()),
      static_cast<DWORD>((cmd.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(cmd_key);
  RegCloseKey(progid_key);
  if (rc != ERROR_SUCCESS) return false;

  // 4. Notify Explorer to refresh
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
  return true;
}

}  // namespace zhiyue
```

- [ ] **Step 4: Add CMakeLists.txt targets**

Modify `app/windows/runner/CMakeLists.txt`:

```cmake
# Add to the runner executable sources:
set(RUNNER_SOURCES
  # ... existing ...
  default_reader_registry.cpp
)

# Add a separate test executable target (only in Debug or when explicitly enabled):
if(ZHIYUE_BUILD_TESTS)
  add_executable(zhiyue_runner_tests
    test_main.cpp
    test_default_reader_registry.cpp
    default_reader_registry.cpp
  )
  target_link_libraries(zhiyue_runner_tests PRIVATE gtest)
  target_compile_definitions(zhiyue_runner_tests PRIVATE ZHIYUE_TESTING)
endif()
```

- [ ] **Step 5: Wire flutter_window.cpp MethodChannel handlers**

In `OnCreate` after `channel_` creation, extend the existing `SetMethodCallHandler`:

```cpp
channel_->SetMethodCallHandler(
  [this](const flutter::EncodableValue& call, auto result) {
    // ... existing popPendingArgv ...

    // v1.14.0-alpha T4: default reader registry
    if (call.IsMap()) {
      const auto& map = call.AsMap();
      const auto* method = std::get_if<std::string>(&map.at(flutter::EncodableValue("method")));
      if (method && *method == "readAssoc") {
        const auto* ext = std::get_if<std::string>(&map.at(flutter::EncodableValue("ext")));
        if (ext) {
          auto cmd = zhiyue::ReadAssocForExtension(
              std::wstring(ext->begin(), ext->end()));
          if (cmd) {
            std::string utf8(cmd->begin(), cmd->end());  // simplistic
            result->Success(flutter::EncodableValue(utf8));
          } else {
            result->Success(flutter::EncodableValue(""));
          }
          return;
        }
      }
      if (method && *method == "set_default_reader") {
        const auto* exe = std::get_if<std::string>(&map.at(flutter::EncodableValue("exe_path")));
        if (exe) {
          std::wstring exe_w(exe->begin(), exe->end());
          bool ok = zhiyue::SetDefaultReaderForExtension(L".epub", exe_w)
                && zhiyue::SetDefaultReaderForExtension(L".pdf", exe_w);
          result->Success(flutter::EncodableValue(ok));
          return;
        }
      }
    }
    result->NotImplemented();
  });
```

Add include: `#include "default_reader_registry.h"`.

- [ ] **Step 6: Run smoke test to verify it passes**

```bash
cd C:\zhiyue_build_s3\app\windows\runner && ./run_smoke_test.bat
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/windows/runner/default_reader_registry.h \
        app/windows/runner/default_reader_registry.cpp \
        app/windows/runner/test_default_reader_registry.cpp \
        app/windows/runner/flutter_window.cpp \
        app/windows/runner/CMakeLists.txt
git commit -m "$(cat <<'EOF'
feat(windows): default_reader_registry for HKCU file association

v1.14.0-alpha T4: zhiyue::SetDefaultReaderForExtension / ReadAssocForExtension
write+read HKCU\Software\Classes\.epub / .pdf. MethodChannel handlers
'readAssoc' / 'set_default_reader' exposed. SHChangeNotify refreshes
Explorer icon cache. No admin required (HKCU only).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Android `openDefaultAppsSettings` handler

**Files:**
- Modify: `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/MainActivity.kt` (extend bookopen channel)
- Test: `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/DefaultAppsSettingsLauncherTest.kt`

- [ ] **Step 1: Write failing Robolectric test**

Create `app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/DefaultAppsSettingsLauncherTest.kt`:

```kotlin
package dev.zhiyue.zhiyue

import android.content.Intent
import android.os.Build
import androidx.test.core.app.ApplicationProvider
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.assertj.core.api.Assertions.assertThat

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DefaultAppsSettingsLauncherTest {

    @Test
    fun `openDefaultAppsSettings launches correct intent`() {
        val activity = MainActivity()
        val launched = activity.openDefaultAppsSettingsForTest(ApplicationProvider.getApplicationContext())
        assertThat(launched).isTrue()

        val shadowActivity = shadowOf(activity)
        val intent = shadowActivity.nextStartedActivity
        assertThat(intent.action).isEqualTo(
            android.provider.Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
    }

    @Test
    fun `openDefaultAppsSettings returns false when activity not found`() {
        // Simulate ROM without ACTION_MANAGE_DEFAULT_APPS_SETTINGS by
        // making the package manager refuse the resolution
        val activity = MainActivity()
        activity.setForceActivityNotFoundForTest(true)
        val launched = activity.openDefaultAppsSettingsForTest(ApplicationProvider.getApplicationContext())
        assertThat(launched).isFalse()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3\app\android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*DefaultAppsSettingsLauncherTest"
```

Expected: FAIL.

- [ ] **Step 3: Implement handler in MainActivity**

Modify `app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/MainActivity.kt`:

```kotlin
// In the bookopen MethodChannel handler:
"openDefaultAppsSettings" -> {
    val ok = try {
        val intent = Intent(android.provider.Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        true
    } catch (e: Exception) {
        Log.w("ZhiYueBookOpen", "openDefaultAppsSettings failed", e)
        false
    }
    result.success(ok)
}
```

Add test seams:

```kotlin
@VisibleForTesting
fun openDefaultAppsSettingsForTest(context: android.content.Context): Boolean {
    return try {
        val intent = Intent(android.provider.Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        true
    } catch (_: Exception) {
        false
    }
}

@VisibleForTesting
var forceActivityNotFoundForTest = false
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd C:\zhiyue_build_s3\app\android && ./gradlew :app:testWithFgsDebugUnitTest --tests "*DefaultAppsSettingsLauncherTest"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/android/app/src/main/kotlin/dev/zhiyue/zhiyue/MainActivity.kt \
        app/android/app/src/test/kotlin/dev/zhiyue/zhiyue/DefaultAppsSettingsLauncherTest.kt
git commit -m "$(cat <<'EOF'
feat(android): openDefaultAppsSettings handler

v1.14.0-alpha T5: MainActivity bookopen channel gets
'openDefaultAppsSettings' which launches ACTION_MANAGE_DEFAULT_APPS_SETTINGS.
Returns false on ActivityNotFoundException (old ROMs) so Dart can fallback
to a SnackBar hint.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Dart `DefaultReaderDetector` + `AppSettings` 持久化

**Files:**
- Create: `app/lib/features/settings/default_reader/default_reader_detector.dart`
- Create: `app/lib/features/settings/default_reader/app_settings.dart`
- Test: 2 new files

- [ ] **Step 1: Write failing tests**

Create `app/test/features/settings/default_reader/default_reader_detector_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/settings/default_reader/default_reader_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Windows detector returns true when readAssoc includes zhiyue.exe', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.bookopen'),
            (call) async {
      if (call.method == 'readAssoc') return '"C:\\Program Files\\ZhiYue\\zhiyue.exe" "%1"';
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.bookopen'), null);
    });

    final detector = WindowsDefaultReaderDetector();
    final isDefault = await detector.isRegisteredAsDefault();
    expect(isDefault, isTrue);
  });

  test('Windows detector returns false when readAssoc returns empty', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.bookopen'),
            (call) async {
      if (call.method == 'readAssoc') return '';
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.bookopen'), null);
    });

    final detector = WindowsDefaultReaderDetector();
    expect(await detector.isRegisteredAsDefault(), isFalse);
  });

  test('Windows setDefault calls set_default_reader with exe path', () async {
    final calls = <Map<String, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.bookopen'),
            (call) async {
      calls.add({'method': call.method, 'args': call.arguments});
      if (call.method == 'set_default_reader') return true;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dev.zhiyue.bookopen'), null);
    });

    final detector = WindowsDefaultReaderDetector();
    final ok = await detector.registerAsDefault(exePath: 'C:\\Program Files\\ZhiYue\\zhiyue.exe');
    expect(ok, isTrue);
    expect(calls.any((c) => c['method'] == 'set_default_reader'), isTrue);
  });

  test('Android detector always returns false (no detection API)', () async {
    final detector = AndroidDefaultReaderDetector();
    expect(await detector.isRegisteredAsDefault(), isFalse);
  });
}
```

Create `app/test/features/settings/default_reader/app_settings_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/settings/default_reader/app_settings.dart';

void main() {
  test('AppSettings.round-trip through json', () {
    const s = AppSettings(promptedDefaultReader: true);
    final j = s.toJson();
    expect(j['promptedDefaultReader'], true);
    expect(AppSettings.fromJson(j).promptedDefaultReader, true);
  });

  test('AppSettings.fromJson tolerates missing field (old files)', () {
    final s = AppSettings.fromJson({});
    expect(s.promptedDefaultReader, false);
  });

  test('Notifier persists promptedDefaultReader to disk', () async {
    final tmpDir = await Directory.systemTemp.createTemp('app_settings_test');
    addTearDown(() => tmpDir.delete(recursive: true));
    final notifier = AppSettingsNotifier(tmpDir);
    await notifier.setPromptedDefaultReader(true);
    final file = File('${tmpDir.path}/app_settings.json');
    expect(await file.exists(), isTrue);
    final raw = await file.readAsString();
    expect(raw, contains('"promptedDefaultReader":true'));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd C:\zhiyue_build_s3 && flutter test test/features/settings/default_reader/
```

Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement DefaultReaderDetector**

Create `app/lib/features/settings/default_reader/default_reader_detector.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Platform-agnostic interface for detecting / setting the system default
/// reader for .epub / .pdf.
abstract class DefaultReaderDetector {
  /// True when this app is already registered as the system default for
  /// .epub AND .pdf.
  Future<bool> isRegisteredAsDefault();

  /// Attempts to register this app as the system default. Returns true on
  /// success.
  ///
  /// On Android this is impossible to do programmatically — implementations
  /// should instead expose a method to jump to system settings.
  Future<bool> registerAsDefault({required String exePath});

  /// True when this platform supports programmatic registration (Windows).
  /// Android must show a "open system settings" affordance instead.
  bool get supportsProgrammaticRegistration;

  /// Opens the system settings page where the user can pick the default.
  /// Returns false when the platform has no such page.
  Future<bool> openSystemDefaultSettings();
}

class WindowsDefaultReaderDetector implements DefaultReaderDetector {
  static const _channel = MethodChannel('dev.zhiyue.bookopen');

  @override
  bool get supportsProgrammaticRegistration => true;

  @override
  Future<bool> isRegisteredAsDefault() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await _channel.invokeMethod<String>(
          'readAssoc', {'ext': '.epub'});
      if (result == null || result.isEmpty) return false;
      // Match either forward-slash or backslash paths, case-insensitive
      final lower = result.toLowerCase();
      return lower.contains('zhiyue.exe');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> registerAsDefault({required String exePath}) async {
    try {
      final result = await _channel.invokeMethod<bool>(
          'set_default_reader', {'exe_path': exePath});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openSystemDefaultSettings() async {
    try {
      final result = await Process.run(
          'cmd', ['/c', 'start', 'ms-settings:defaultapps']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

class AndroidDefaultReaderDetector implements DefaultReaderDetector {
  static const _channel = MethodChannel('dev.zhiyue.bookopen');

  @override
  bool get supportsProgrammaticRegistration => false;

  @override
  Future<bool> isRegisteredAsDefault() async => false;  // no API

  @override
  Future<bool> registerAsDefault({required String exePath}) async => false;

  @override
  Future<bool> openSystemDefaultSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openDefaultAppsSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// Picks the right detector for the current platform.
DefaultReaderDetector defaultReaderDetectorForPlatform() {
  if (Platform.isWindows) return WindowsDefaultReaderDetector();
  if (Platform.isAndroid) return AndroidDefaultReaderDetector();
  // Mac/Linux/iOS: no-op stub
  return _NoopDefaultReaderDetector();
}

class _NoopDefaultReaderDetector implements DefaultReaderDetector {
  @override
  bool get supportsProgrammaticRegistration => false;
  @override
  Future<bool> isRegisteredAsDefault() async => false;
  @override
  Future<bool> registerAsDefault({required String exePath}) async => false;
  @override
  Future<bool> openSystemDefaultSettings() async => false;
}
```

- [ ] **Step 4: Implement AppSettings**

Create `app/lib/features/settings/default_reader/app_settings.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';

class AppSettings {
  final bool promptedDefaultReader;

  const AppSettings({this.promptedDefaultReader = false});

  Map<String, dynamic> toJson() => {
        'promptedDefaultReader': promptedDefaultReader,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        promptedDefaultReader: (j['promptedDefaultReader'] as bool?) ?? false,
      );

  AppSettings copyWith({bool? promptedDefaultReader}) => AppSettings(
        promptedDefaultReader: promptedDefaultReader ?? this.promptedDefaultReader,
      );
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final Directory _dir;
  File? _file;

  AppSettingsNotifier(this._dir) : super(const AppSettings()) {
    _load();
  }

  File get _settingsFile {
    _file ??= File('${_dir.path}/app_settings.json');
    return _file!;
  }

  Future<void> _load() async {
    try {
      if (await _settingsFile.exists()) {
        final raw = await _settingsFile.readAsString();
        final j = jsonDecode(raw) as Map<String, dynamic>;
        state = AppSettings.fromJson(j);
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      await _settingsFile.writeAsString(jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> setPromptedDefaultReader(bool value) async {
    state = state.copyWith(promptedDefaultReader: value);
    await _persist();
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(ref.watch(appSettingsDirProvider)),
);
```

Add `appSettingsDirProvider` in `app/lib/core/providers.dart` (mirror `ttsSettingsDirProvider`):

```dart
final appSettingsDirProvider = Provider<Directory>((ref) {
  return globalAppSettingsDirOverride!;
});
```

And in test helpers, set `globalAppSettingsDirOverride` to a tmp dir.

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd C:\zhiyue_build_s3 && flutter test test/features/settings/default_reader/
```

Expected: PASS (7 tests).

- [ ] **Step 6: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/features/settings/default_reader/default_reader_detector.dart \
        app/lib/features/settings/default_reader/app_settings.dart \
        app/lib/core/providers.dart \
        app/test/features/settings/default_reader/default_reader_detector_test.dart \
        app/test/features/settings/default_reader/app_settings_test.dart
git commit -m "$(cat <<'EOF'
feat(settings): DefaultReaderDetector + AppSettings foundation

v1.14.0-alpha T6: DefaultReaderDetector abstract + Windows/Android impl.
Windows: readAssoc/set_default_reader via bookopen channel (no admin).
Android: no detection API, only openSystemDefaultSettings.
AppSettings.promptedDefaultReader persisted to app_settings.json
(tolerates missing field for old installs).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: DefaultReaderPromptDialog + Coordinator + settings tile

**Files:**
- Create: `app/lib/features/settings/default_reader/widgets/default_reader_prompt_dialog.dart`
- Create: `app/lib/features/settings/default_reader/widgets/default_reader_settings_tile.dart`
- Create: `app/lib/features/settings/default_reader/default_reader_dialog_coordinator.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/lib/features/settings/pages/settings_page.dart`
- Modify: `app/lib/l10n/app_zh.arb` / `app_en.arb`
- Test: `app/test/features/settings/default_reader/default_reader_prompt_dialog_test.dart`

- [ ] **Step 1: Write failing widget test**

Create `app/test/features/settings/default_reader/default_reader_prompt_dialog_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyue/features/settings/default_reader/default_reader_detector.dart';
import 'package:zhiyue/features/settings/default_reader/widgets/default_reader_prompt_dialog.dart';
import 'package:zhiyue/features/settings/default_reader/widgets/default_reader_settings_tile.dart';

class _MockDetector extends Mock implements DefaultReaderDetector {}

void main() {
  testWidgets('dialog shows + 确认 triggers registerAsDefault', (tester) async {
    final mock = _MockDetector();
    when(() => mock.supportsProgrammaticRegistration).thenReturn(true);
    when(() => mock.registerAsDefault(exePath: any(named: 'exePath')))
        .thenAnswer((_) async => true);

    await tester.pumpWidget(MaterialApp(
      home: DefaultReaderPromptDialog(detector: mock),
    ));

    expect(find.textContaining('设为默认阅读器'), findsOneWidget);
    await tester.tap(find.text('设为默认'));
    await tester.pumpAndSettle();

    verify(() => mock.registerAsDefault(exePath: any(named: 'exePath'))).called(1);
  });

  testWidgets('dialog 稍后再说 dismisses without registering', (tester) async {
    final mock = _MockDetector();
    when(() => mock.supportsProgrammaticRegistration).thenReturn(true);

    await tester.pumpWidget(MaterialApp(
      home: DefaultReaderPromptDialog(detector: mock),
    ));

    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();
    verifyNever(() => mock.registerAsDefault(exePath: any(named: 'exePath')));
  });

  testWidgets('Android dialog shows 系统设置 button instead of 设为默认',
      (tester) async {
    final mock = _MockDetector();
    when(() => mock.supportsProgrammaticRegistration).thenReturn(false);
    when(() => mock.openSystemDefaultSettings()).thenAnswer((_) async => true);

    await tester.pumpWidget(MaterialApp(
      home: DefaultReaderPromptDialog(detector: mock),
    ));

    expect(find.text('设为默认'), findsNothing);
    expect(find.textContaining('系统设置'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3 && flutter test test/features/settings/default_reader/default_reader_prompt_dialog_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement DefaultReaderPromptDialog**

Create `app/lib/features/settings/default_reader/widgets/default_reader_prompt_dialog.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../default_reader_detector.dart';

/// Dialog shown on first launch (or when user taps settings tile) to prompt
/// the user to set ZhiYue as the default reader for .epub / .pdf.
class DefaultReaderPromptDialog extends StatefulWidget {
  final DefaultReaderDetector detector;
  final VoidCallback? onDismissed;

  const DefaultReaderPromptDialog({
    super.key,
    required this.detector,
    this.onDismissed,
  });

  @override
  State<DefaultReaderPromptDialog> createState() =>
      _DefaultReaderPromptDialogState();
}

class _DefaultReaderPromptDialogState extends State<DefaultReaderPromptDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final supportsProgrammatic = widget.detector.supportsProgrammaticRegistration;
    return AlertDialog(
      title: Text(l10n.defaultReaderDialogTitle),
      content: Text(supportsProgrammatic
          ? l10n.defaultReaderDialogBodyWindows
          : l10n.defaultReaderDialogBodyAndroid),
      actions: [
        TextButton(
          onPressed: _busy ? null : () {
            widget.onDismissed?.call();
            Navigator.of(context).maybePop();
          },
          child: Text(l10n.defaultReaderDialogDismiss),
        ),
        FilledButton(
          onPressed: _busy ? null : _onAccept,
          child: _busy
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(supportsProgrammatic
                  ? l10n.defaultReaderDialogAccept
                  : l10n.defaultReaderDialogOpenSettings),
        ),
      ],
    );
  }

  Future<void> _onAccept() async {
    setState(() => _busy = true);
    try {
      if (widget.detector.supportsProgrammaticRegistration) {
        // Windows: write HKCU registry. exePath comes from Platform.resolvedExecutable
        // — but we can't access it here without dart:io Platform.
        // For now pass empty and let C++ side use GetModuleFileName.
        await widget.detector.registerAsDefault(exePath: '');
      } else {
        await widget.detector.openSystemDefaultSettings();
      }
    } finally {
      if (mounted) {
        widget.onDismissed?.call();
        Navigator.of(context).maybePop();
      }
    }
  }
}
```

- [ ] **Step 4: Implement Dialog Coordinator**

Create `app/lib/features/settings/default_reader/default_reader_dialog_coordinator.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_settings.dart';
import 'default_reader_detector.dart';
import 'widgets/default_reader_prompt_dialog.dart';

/// Decides whether to show the DefaultReaderPromptDialog on launch.
///
/// Trigger conditions:
/// - `AppSettings.promptedDefaultReader == false` AND
/// - detector says NOT registered as default
///
/// After showing (regardless of accept/dismiss), persists prompted=true.
class DefaultReaderDialogCoordinator {
  final DefaultReaderDetector detector;
  final AppSettingsNotifier settingsNotifier;

  DefaultReaderDialogCoordinator({
    required this.detector,
    required this.settingsNotifier,
  });

  Future<void> maybeShow(BuildContext context) async {
    if (settingsNotifier.state.promptedDefaultReader) return;

    final isDefault = await detector.isRegisteredAsDefault();
    if (isDefault) {
      // Already default → mark as prompted to skip future checks
      await settingsNotifier.setPromptedDefaultReader(true);
      return;
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DefaultReaderPromptDialog(
        detector: detector,
        onDismissed: () {
          settingsNotifier.setPromptedDefaultReader(true);
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Wire into main.dart**

Modify `app/lib/main.dart`:

```dart
// In BookOpenBridge.init post-frame callback area, add after:
WidgetsBinding.instance.addPostFrameCallback((_) async {
  // existing router/importer/BookOpenBridge logic ...

  // v1.14.0-alpha T7: maybe prompt for default reader
  final detector = defaultReaderDetectorForPlatform();
  final appSettingsNotifier = container.read(appSettingsProvider.notifier);
  final coordinator = DefaultReaderDialogCoordinator(
    detector: detector,
    settingsNotifier: appSettingsNotifier,
  );
  final messengerContext = scaffoldMessengerKey.currentContext;
  if (messengerContext != null) {
    await coordinator.maybeShow(messengerContext);
  }
});
```

Add imports:

```dart
import 'features/settings/default_reader/default_reader_detector.dart';
import 'features/settings/default_reader/default_reader_dialog_coordinator.dart';
import 'features/settings/default_reader/app_settings.dart';
```

- [ ] **Step 6: Add settings page tile**

Create `app/lib/features/settings/default_reader/widgets/default_reader_settings_tile.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../default_reader_detector.dart';

class DefaultReaderSettingsTile extends ConsumerWidget {
  const DefaultReaderSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.app_registration),
      title: Text(l10n.defaultReaderSettingsTileTitle),
      subtitle: Text(l10n.defaultReaderSettingsTileSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final detector = defaultReaderDetectorForPlatform();
        await showDialog<void>(
          context: context,
          builder: (_) => DefaultReaderPromptDialog(detector: detector),
        );
      },
    );
  }
}
```

Modify `app/lib/features/settings/pages/settings_page.dart` to include `DefaultReaderSettingsTile()` in the General section.

- [ ] **Step 7: Add i18n strings**

Add to `app/lib/l10n/app_zh.arb`:

```json
  "defaultReaderDialogTitle": "设为默认阅读器？",
  "defaultReaderDialogBodyWindows": "将智阅设为 .epub 和 .pdf 文件的默认阅读器。后续双击这些文件将自动用智阅打开并加入书架。",
  "defaultReaderDialogBodyAndroid": "在系统「默认应用」设置里将智阅设为 .epub 文件的默认打开方式。",
  "defaultReaderDialogDismiss": "稍后再说",
  "defaultReaderDialogAccept": "设为默认",
  "defaultReaderDialogOpenSettings": "打开系统设置",
  "defaultReaderSettingsTileTitle": "设为默认阅读器",
  "defaultReaderSettingsTileSubtitle": "管理 .epub / .pdf 默认打开方式"
```

Mirror in `app_en.arb`. Run `flutter gen-l10n` and restore CRLF via `git checkout` + Python binary-safe additions.

- [ ] **Step 8: Run widget test**

```bash
cd C:\zhiyue_build_s3 && flutter test test/features/settings/default_reader/default_reader_prompt_dialog_test.dart
```

Expected: PASS.

- [ ] **Step 9: Run full test suite**

```bash
cd C:\zhiyue_build_s3 && flutter test
```

- [ ] **Step 10: Commit**

```bash
cd C:\zhiyue_build_s3
git add app/lib/features/settings/default_reader/widgets/ \
        app/lib/features/settings/default_reader/default_reader_dialog_coordinator.dart \
        app/lib/main.dart \
        app/lib/features/settings/pages/settings_page.dart \
        app/lib/l10n/app_zh.arb app/lib/l10n/app_en.arb \
        app/lib/gen_l10n/ \
        app/test/features/settings/default_reader/default_reader_prompt_dialog_test.dart
git commit -m "$(cat <<'EOF'
feat(settings): default reader prompt dialog + coordinator + settings tile

v1.14.0-alpha T7: DefaultReaderPromptDialog shows on first launch when
detector says not registered. Windows: writes HKCU; Android: opens system
settings. Settings → 通用 has manual entry. After accept/dismiss,
AppSettings.promptedDefaultReader=true persists (no re-prompt).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Release v1.14.0-alpha（与 tts-multi-voice plan T7 共享）

**Files:** shared with `2026-07-19-tts-multi-voice-plan.md` Task 7.

**重要：** 本任务与 `2026-07-19-tts-multi-voice-plan.md` Task 7 是同一个 task（合并 release）。两个 plan 都执行到 T7 后，**只执行一次 release 流程**。

执行步骤见 `2026-07-19-tts-multi-voice-plan.md` Task 7。Tag 包括：
- `v1.14.0-alpha`
- `m-tts-multi-voice`
- `m-open-with-default-reader`

---

## Reuse existing

- M7 `book_open_bridge.dart` 现有架构（添加路径，不重构）
- M8 `flutter_window.cpp` WM_COPYDATA + `FindZhiYueWindow` 模式
- M8 Inno Setup 文件关联（machine-level HKLM）—— dialog 写 HKCU 覆盖
- M3.5 `ttsSettingsDirProvider` 持久化模式（镜像给 `appSettingsDirProvider`）
- v1.13.11 `BookFormatDetector` magic bytes 检测（不动，依赖扩展名）
- v1.13.7 speak-args piggy-back 模式（如有需要，复用模式）
- feedback_no_dispose_time_fire_and_forget → AppSettings 即时落盘
- feedback_flutter_strip_cache_trap → marker verify

## Verification

- Dart: ~1720 pass / 0 fail
- Kotlin Robolectric: ~40 pass / 0 fail
- C++ smoke: PASS (含新 copydata + registry 测试)
- APK libapp.so MD5 ≠ v1.13.11
- Windows app.so MD5 ≠ v1.13.11
- 8 真机场景全 PASS

## Risks

1. **`contentResolver.getType(uri)` 返回 null**（华为部分 ROM）→ 双 fallback 都失败 → onError SnackBar（不崩）
2. **WM_COPYDATA 多次到达**（用户连点）→ cached_argv_ 最后 wins（设计预期）
3. **HKCU 注册表被 AV 拦截** → set_default_reader 返回 false → dialog 显示失败提示
4. **Android ACTION_MANAGE_DEFAULT_APPS_SETTINGS 在旧 ROM 不存在** → catch ActivityNotFoundException → 返回 false → Dart SnackBar fallback
5. **Windows Inno Setup 已写 HKLM，dialog 写 HKCU**：HKCU 优先级高，覆盖 HKLM → 行为一致
6. **iOS / macOS / Linux**：DefaultReaderDetector 返回 noop → dialog 不弹（避免无效提示）
