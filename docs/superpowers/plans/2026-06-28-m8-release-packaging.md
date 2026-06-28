# M8 Release Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce v0.5.0 release artifacts for Windows (Inno Setup installer + portable zip) and Android (signed fat APK), with public-facing README, CHANGELOG, NOTICE, and Gitee Release upload procedure.

**Architecture:** Incrementally delete the stale CI yaml, extend `BookOpenBridge` with an optional error callback wired to `ScaffoldMessenger`, add Windows single-instance (mutex + `WM_COPYDATA` + MethodChannel) so warm-start deep-link works, prepare Inno Setup + packaging scripts and release documentation, then run real Android signing/smoke test and Gitee Release upload with user collaboration.

**Tech Stack:** Flutter 3.27+ / Dart 3.10 / Riverpod / go_router / pdfrx / Win32 API (mutex, WM_COPYDATA, EnumWindows, SetPropW) / Inno Setup 6 / Android SDK 34 / Gitee Releases.

---

## File Structure

**New files:**
- `app/dart_test.yaml` — golden tag config (kills test runner warning)
- `app/lib/core/scaffold_messenger_key.dart` — global ScaffoldMessengerState key (avoids main↔app circular import)
- `app/windows/installer/zhiyue.iss` — Inno Setup script
- `app/windows/installer/build-portable-zip.ps1` — PowerShell packaging script
- `CHANGELOG.md` (root) — cumulative release notes
- `NOTICE` (root) — third-party copyright notices
- `docs/setup-android-sdk.md` — Android SDK install guide (Windows)
- `docs/release-procedure.md` — Gitee Release upload + smoke test runbook

**Modify:**
- `app/pubspec.yaml:4` — version bump
- `app/windows/CMakeLists.txt` — VERSION stamp (optional, .rc owns detail)
- `app/lib/services/book_open_bridge.dart` — `BookOpenBridgeOptions` + `options` param
- `app/lib/main.dart` — `scaffoldMessengerKey` + onError injection
- `app/lib/core/app.dart` — wire `scaffoldMessengerKey`
- `app/test/services/book_open_bridge_test.dart` — error-path tests + (default options still passes)
- `app/windows/runner/main.cpp` — mutex + EnumWindows + WM_COPYDATA send
- `app/windows/runner/flutter_window.h` — add MethodChannel member
- `app/windows/runner/flutter_window.cpp` — SetPropW marker + WM_COPYDATA receive + invokeMethod
- `README.md` (root) — status refresh + screenshots + download section
- `app/README.md` — replace Flutter template with developer operations manual
- `app/android/app/keys/README.md` — minor clarification on release build flow

**Delete:**
- `.github/workflows/ci.yml`

---

## Task 1: Delete stale CI + add dart_test.yaml + version bump

**Files:**
- Delete: `.github/workflows/ci.yml`
- Create: `app/dart_test.yaml`
- Modify: `app/pubspec.yaml:4`

- [ ] **Step 1: Delete stale GitHub Actions CI**

The remote is Gitee (no GitHub Actions trigger) and the project decided on local manual builds. Remove:

```bash
rm .github/workflows/ci.yml
rmdir .github/workflows 2>/dev/null || true
rmdir .github 2>/dev/null || true
```

Expected: `git status` shows `.github/workflows/ci.yml` deleted.

- [ ] **Step 2: Create `app/dart_test.yaml`**

```yaml
tags:
  golden:
    # golden_toolkit 包要求：声明 tag 以消除 "tag golden not declared" warning。
    # 默认行为是不 skip（项目内所有 golden 测试默认就跑）。
```

- [ ] **Step 3: Bump pubspec version to 0.5.0+2**

`app/pubspec.yaml:4` 改：

```yaml
version: 0.5.0+2
```

- [ ] **Step 4: Verify test runner no longer warns about golden tag**

Run:
```bash
cd app && /c/flutter/bin/dart test 2>&1 | head -50
```

Expected: 不再有 `Warning: ... tag "golden" ...`。Test pass count 不下降（仍 ≥ 575 包内 + app 包 ~422）。

- [ ] **Step 5: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add \
  .github/workflows/ci.yml \
  app/dart_test.yaml \
  app/pubspec.yaml
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
chore(m8/t1): drop stale GitHub Actions CI + add dart_test.yaml golden tag + bump 0.5.0

- Delete .github/workflows/ci.yml (Gitee remote, manual-build policy)
- Add app/dart_test.yaml declaring golden tag (kill warning)
- pubspec 0.4.0+1 → 0.5.0+2

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: BookOpenBridgeOptions + onError callback (backward-compatible)

**Files:**
- Modify: `app/lib/services/book_open_bridge.dart`
- Modify: `app/test/services/book_open_bridge_test.dart`

- [ ] **Step 1: Write failing tests for error-path callback**

Append to `app/test/services/book_open_bridge_test.dart`, before the closing `}` of `void main()`:

```dart
  group('BookOpenBridge.handlePath error callback', () {
    late _FakeBookImportService importer;
    late _MockGoRouter router;
    late Directory tempDir;
    late File epubFile;
    late List<Object> capturedErrors;

    setUp(() async {
      importer = _FakeBookImportService();
      router = _MockGoRouter();
      capturedErrors = [];
      tempDir = await Directory.systemTemp.createTemp('bridge_err_');
      epubFile = File('${tempDir.path}/bad.epub')
        ..writeAsBytesSync([0x50, 0x4B, 0x03, 0x04, 0x00]);
      registerFallbackValue(Uri.parse('/'));
      registerFallbackValue(File('${tempDir.path}/fallback.epub'));
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('onError fires when import throws', () async {
      when(() => importer.importFile(any(),
              format: any(named: 'format')))
          .thenThrow(Exception('corrupt epub'));

      await BookOpenBridge.handlePath(
        path: epubFile.path,
        importer: importer,
        router: router,
        options: BookOpenBridgeOptions(
          onError: (e, _) => capturedErrors.add(e),
        ),
      );

      expect(capturedErrors, hasLength(1));
      expect(capturedErrors.single, isA<Exception>());
      verifyNever(() => router.push(any()));
    });

    test('onError omitted (default) keeps old silent behavior', () async {
      when(() => importer.importFile(any(),
              format: any(named: 'format')))
          .thenThrow(Exception('corrupt epub'));

      // 不传 options：与 M7 行为完全一致（静默忽略）
      await BookOpenBridge.handlePath(
        path: epubFile.path,
        importer: importer,
        router: router,
      );

      verifyNever(() => router.push(any()));
    });

    test('onError does not fire on unsupported extension', () async {
      await BookOpenBridge.handlePath(
        path: '/tmp/image.png',
        importer: importer,
        router: router,
        options: BookOpenBridgeOptions(
          onError: (e, _) => capturedErrors.add(e),
        ),
      );

      expect(capturedErrors, isEmpty);
      verifyNever(() => importer.importFile(any(),
          format: any(named: 'format')));
    });

    test('init propagates options.onError to cold-start path', () async {
      when(() => importer.importFile(any(),
              format: any(named: 'format')))
          .thenThrow(Exception('corrupt'));

      // argv 中带支持路径 → handlePath 调用，options 应透传
      await BookOpenBridge.init(
        argv: ['/tmp/init_book.epub'],
        importer: importer,
        router: router,
        options: BookOpenBridgeOptions(
          onError: (e, _) => capturedErrors.add(e),
        ),
      );

      expect(capturedErrors, hasLength(1));
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd app && /c/flutter/bin/dart test test/services/book_open_bridge_test.dart 2>&1 | tail -30
```

Expected: 4 new tests FAIL — `BookOpenBridgeOptions isn't defined`, `options parameter not found`.

Existing 10 tests should still PASS (no options param needed → default behavior unchanged once `options` is added with a default value).

- [ ] **Step 3: Add BookOpenBridgeOptions class to bridge**

Modify `app/lib/services/book_open_bridge.dart`. Insert this class **before** the `BookOpenBridge` class declaration (after the imports):

```dart
/// BookOpenBridge 行为选项。
///
/// M8：可选错误回调，由调用方注入 UX（如 SnackBar）。
/// 不传 [onError] 时与 M7 行为完全一致（静默忽略）。
class BookOpenBridgeOptions {
  final void Function(Object error, StackTrace stackTrace)? onError;

  const BookOpenBridgeOptions({this.onError});
}
```

- [ ] **Step 4: Add `options` parameter to `handlePath`**

Modify `handlePath` in `app/lib/services/book_open_bridge.dart`:

```dart
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
```

- [ ] **Step 5: Add `options` parameter to `init` and propagate**

Modify `init` in `app/lib/services/book_open_bridge.dart`:

```dart
  static Future<void> init({
    required List<String> argv,
    required BookImportService importer,
    required GoRouter router,
    BookOpenBridgeOptions options = const BookOpenBridgeOptions(),
  }) async {
    // 1. Windows argv：找第一个支持的扩展
    for (final arg in argv) {
      if (isSupportedBookPath(arg)) {
        await handlePath(
          path: arg,
          importer: importer,
          router: router,
          options: options,
        );
        break; // 只处理第一个
      }
    }

    // 2. Android MethodChannel
    // 2a. Cold start：popPendingBookPath
    try {
      final pending = await _channel.invokeMethod<String>('popPendingBookPath');
      if (pending != null && pending.isNotEmpty) {
        await handlePath(
          path: pending,
          importer: importer,
          router: router,
          options: options,
        );
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
          options: options,
        );
      }
      return null;
    });
  }
```

- [ ] **Step 6: Run all bridge tests**

Run:
```bash
cd app && /c/flutter/bin/dart test test/services/book_open_bridge_test.dart 2>&1 | tail -10
```

Expected: 14 tests PASS（原 10 + 新 4）。

- [ ] **Step 7: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add \
  app/lib/services/book_open_bridge.dart \
  app/test/services/book_open_bridge_test.dart
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m8/t2): BookOpenBridgeOptions optional onError callback

- New BookOpenBridgeOptions class with optional onError
- handlePath/init accept options (default const — backward compatible)
- 4 new unit tests (onError fires on import throw / default silent / unsupported ext / init propagates)
- Existing 10 tests unchanged behavior

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Wire scaffoldMessengerKey + SnackBar injection

**Files:**
- Create: `app/lib/core/scaffold_messenger_key.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/lib/core/app.dart`

> Putting `scaffoldMessengerKey` in its own file (`core/scaffold_messenger_key.dart`) avoids a circular import between `main.dart` (imports app.dart for `ZhiYueApp`) and `app.dart` (would import main.dart for the key).

- [ ] **Step 1: Create `app/lib/core/scaffold_messenger_key.dart`**

```dart
import 'package:flutter/material.dart';

/// 全局 [ScaffoldMessengerState] key。
///
/// M8：[BookOpenBridge] 的 onError 回调从启动早期 post-frame callback 触发，
/// 此时 widget tree 已 mount（callback 在 frame 后跑），key 一定能拿到 state。
/// 用于 SnackBar 报错反馈（不在 widget tree 内拿不到 BuildContext）。
///
/// 独立文件避免 main.dart ↔ app.dart 之间循环 import。
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(debugLabel: 'scaffoldMessenger');
```

- [ ] **Step 2: Update `app/lib/main.dart` to import + inject onError**

Replace `app/lib/main.dart` content with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'core/app.dart';
import 'core/app_providers.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/scaffold_messenger_key.dart';
import 'services/book_open_bridge.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(pdfrxFlutterInitialize()); // M4: pdfrx 引擎初始化

  final container = ProviderContainer(overrides: providers);

  // M7+M8：启动后处理文件 deep-link（Windows argv + Android MethodChannel）。
  // M8：注入 onError → SnackBar 反馈。
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final router = container.read(routerProvider);
    final importer = await container.read(bookImportServiceProvider.future);
    await BookOpenBridge.init(
      argv: args,
      importer: importer,
      router: router,
      options: BookOpenBridgeOptions(
        onError: (e, _) {
          final messenger = scaffoldMessengerKey.currentState;
          if (messenger == null) return; // UI 还没 mount（理论不应到这）
          messenger.showSnackBar(
            SnackBar(content: Text('打开书籍失败：$e')),
          );
        },
      ),
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

- [ ] **Step 3: Wire `scaffoldMessengerKey` into MaterialApp.router**

Replace `app/lib/core/app.dart` content with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/providers/locale_provider.dart';
import '../features/settings/providers/theme_mode_provider.dart';
import '../gen_l10n/app_localizations.dart';
import 'router.dart';
import 'scaffold_messenger_key.dart';
import 'theme.dart';

class ZhiYueApp extends ConsumerWidget {
  const ZhiYueApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeSetting = ref.watch(localeProvider);
    final themeModeSetting = ref.watch(themeModeProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeModeSetting.toMaterialThemeMode(),
      locale: localeSetting.toLocale(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
```

- [ ] **Step 4: Run analyze + tests to verify no regression**

Run:
```bash
cd app && /c/flutter/bin/dart analyze lib/core/app.dart lib/main.dart lib/core/scaffold_messenger_key.dart 2>&1 | tail -20
cd app && /c/flutter/bin/dart test 2>&1 | tail -5
```

Expected: analyze 干净（除已知 pdfrx info-lint）；test 全通过（≥ 575）。

- [ ] **Step 5: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add \
  app/lib/main.dart \
  app/lib/core/app.dart \
  app/lib/core/scaffold_messenger_key.dart
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m8/t3): wire scaffoldMessengerKey + SnackBar error feedback

- New core/scaffold_messenger_key.dart holds global key (avoids main↔app cycle)
- MaterialApp.router uses scaffoldMessengerKey
- BookOpenBridge.init onError → SnackBar('打开书籍失败：$e')

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Windows main.cpp mutex + EnumWindows WM_COPYDATA send

**Files:**
- Modify: `app/windows/runner/main.cpp`

- [ ] **Step 1: Replace main.cpp with mutex + second-instance branch**

Full file content of `app/windows/runner/main.cpp`:

```cpp
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Window property name used to mark the first-instance window so the
// second instance can find it via EnumWindows + GetPropW.
// Note: max 4 chars after the slash per Win32 limit on atoms, but strings
// longer than that work fine as property names.
constexpr const wchar_t* kZhiYueWindowProp = L"ZhiYueWindowProp";

// COPYDATASTRUCT::dwData tag for argv payload.
constexpr ULONG_PTR kCopyDataArgvTag = 1;

// Convert a wide string (UTF-16) to UTF-8 std::string.
// Required because Flutter's argv arrives as UTF-8 but Win32 wide-char
// command line needs conversion before transmission via WM_COPYDATA.
std::string WideToUtf8(const std::wstring& w) {
  if (w.empty()) return std::string();
  int needed = WideCharToMultiByte(CP_UTF8, 0, w.c_str(),
                                   static_cast<int>(w.size()),
                                   nullptr, 0, nullptr, nullptr);
  std::string out(needed, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w.c_str(),
                      static_cast<int>(w.size()),
                      out.data(), needed, nullptr, nullptr);
  return out;
}

// Callback for EnumWindows. If we find a window marked with
// kZhiYueWindowProp, send WM_COPYDATA with the first argv and stop.
struct EnumContext {
  const std::string& argv;
};

BOOL CALLBACK FindZhiYueWindow(HWND hwnd, LPARAM lparam) {
  auto* ctx = reinterpret_cast<EnumContext*>(lparam);
  HANDLE marker = GetPropW(hwnd, kZhiYueWindowProp);
  if (marker != nullptr) {
    COPYDATASTRUCT cds = {};
    cds.dwData = kCopyDataArgvTag;
    cds.cbData = ctx->argv.size() + 1;  // include trailing null
    cds.lpData = const_cast<char*>(ctx->argv.c_str());
    SendMessageW(hwnd, WM_COPYDATA, nullptr,
                 reinterpret_cast<LPARAM>(&cds));
    return FALSE;  // stop enumeration
  }
  return TRUE;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // M8: Single-instance gate. Named mutex is the standard Win32 way.
  // First instance owns the mutex for process lifetime; second instance
  // forwards its argv to the first via WM_COPYDATA and exits.
  HANDLE mutex = CreateMutexW(nullptr, TRUE, L"Local\\ZhiYueApp");
  bool is_first_instance =
      (mutex != nullptr) && (GetLastError() != ERROR_ALREADY_EXISTS);

  // Capture argv before potentially short-circuiting on second instance.
  std::vector<std::string> argv_utf8 = GetCommandLineArguments();

  if (!is_first_instance) {
    if (mutex) CloseHandle(mutex);
    // Forward first supported argv (with .epub/.pdf) to the running instance.
    // The receiver in flutter_window.cpp filters non-book extensions.
    if (!argv_utf8.empty()) {
      EnumContext ctx{argv_utf8.front()};
      EnumWindows(FindZhiYueWindow, reinterpret_cast<LPARAM>(&ctx));
    }
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(std::move(argv_utf8));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"智阅", origin, size)) {
    if (mutex) CloseHandle(mutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (mutex) CloseHandle(mutex);
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
```

Key changes from M7 version:
1. Added `kZhiYueWindowProp` constant for window marker (set in T5 flutter_window.cpp OnCreate)
2. Added `WideToUtf8` helper (UTF-16 → UTF-8 for argv transit)
3. Added `FindZhiYueWindow` EnumWindows callback
4. Added mutex gate at top of wWinMain
5. Second instance: forward argv + early return (EXIT_SUCCESS, no window)
6. First instance: normal startup + close mutex at end

- [ ] **Step 2: Sanity check the file compiles syntactically (no Windows build available on this machine)**

Run (will fail on actual build because no Windows SDK at command line, but Dart-side analyze unaffected):

```bash
cd app && /c/flutter/bin/dart analyze lib 2>&1 | tail -5
```

Expected: Dart analyze 仍干净（C++ 编译受 Windows SDK 缺失影响，本任务无法 compile-verify on this machine；T6 Android SDK 安装后会另起 Windows build 验证）。

Document this as a known limitation for the reviewer. The C++ follows the Flutter Windows plugin standard pattern from official samples.

- [ ] **Step 3: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/windows/runner/main.cpp
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m8/t4): Windows single-instance via named mutex + EnumWindows forward

- CreateMutexW(Local\ZhiYueApp) at wWinMain top
- Second instance forwards argv[0] via WM_COPYDATA to running instance
- First instance proceeds normally, closes mutex at exit
- WideToUtf8 helper for UTF-16 command-line -> UTF-8 transit
- FindZhiYueWindow callback finds window marked with kZhiYueWindowProp

Receiver side (SetPropW + WM_COPYDATA handler) lands in T5.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Windows flutter_window.cpp WM_COPYDATA receiver + MethodChannel invoke

**Files:**
- Modify: `app/windows/runner/flutter_window.h`
- Modify: `app/windows/runner/flutter_window.cpp`

- [ ] **Step 1: Add MethodChannel member to FlutterWindow**

Replace `app/windows/runner/flutter_window.h` with:

```cpp
#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // M8: MethodChannel bridge to Dart BookOpenBridge. Used for warm-start
  // argv forwarding from second instance (received via WM_COPYDATA).
  std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
```

- [ ] **Step 2: Replace flutter_window.cpp to register prop + handle WM_COPYDATA**

Replace `app/windows/runner/flutter_window.cpp` with:

```cpp
#include "flutter_window.h"

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Same constant as in main.cpp. Duplicated to keep modules decoupled.
constexpr const wchar_t* kZhiYueWindowProp = L"ZhiYueWindowProp";
constexpr ULONG_PTR kCopyDataArgvTag = 1;

// Check whether a file path is one we should forward to Dart BookOpenBridge.
// Mirrors BookOpenBridge.isSupportedBookPath on Dart side.
bool IsSupportedBookPath(const std::string& path) {
  if (path.size() < 5) return false;  // shortest: ".epub" / ".pdf"
  auto pos = path.find_last_of('.');
  if (pos == std::string::npos) return false;
  std::string ext = path.substr(pos);
  // lowercase
  for (auto& c : ext) {
    if (c >= 'A' && c <= 'Z') c = c - 'A' + 'a';
  }
  return ext == ".epub" || ext == ".pdf";
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // M8: Mark this window so the second instance can find it via EnumWindows.
  // Use the HWND from the underlying Win32Window; GetHandle() returns it.
  SetPropW(GetHandle(), kZhiYueWindowProp,
           reinterpret_cast<HANDLE>(reinterpret_cast<uintptr_t>(1)));

  // M8: Open the MethodChannel that forwards argv to Dart BookOpenBridge
  // when the second instance sends WM_COPYDATA. Mirrors Android side
  // (dev.zhiyue.bookopen / "openBook").
  channel_ = std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "dev.zhiyue.bookopen",
      &flutter::StandardMethodCodec::GetInstance());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // M8: Receive argv forwarded by second instance via WM_COPYDATA.
  // Forward to Dart BookOpenBridge via the same MethodChannel pattern
  // as Android (BookOpenBridge.init sets up the openBook handler).
  if (message == WM_COPYDATA) {
    auto* cds = reinterpret_cast<COPYDATASTRUCT*>(lparam);
    if (cds != nullptr && cds->dwData == kCopyDataArgvTag && channel_) {
      // cbData includes trailing null; size the string without it.
      std::string arg(reinterpret_cast<const char*>(cds->lpData),
                      cds->cbData > 0 ? cds->cbData - 1 : 0);
      if (IsSupportedBookPath(arg)) {
        channel_->InvokeMethod(
            "openBook",
            std::make_unique<flutter::EncodableValue>(arg));
      }
    }
    return 0;  // we handled it
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
```

- [ ] **Step 3: Verify there's no Dart-side regression (build verify deferred)**

Run:
```bash
cd app && /c/flutter/bin/dart test 2>&1 | tail -5
```

Expected: all tests pass (≥ 575). Dart side is unchanged; the WM_COPYDATA → MethodChannel path is transparent to Dart because `BookOpenBridge.init` already registers the `openBook` handler in T2.

C++ build verification will happen in T6 (after Android SDK install, since flutter build also rebuilds Windows).

- [ ] **Step 4: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/windows/runner/flutter_window.h app/windows/runner/flutter_window.cpp
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m8/t5): FlutterWindow WM_COPYDATA receiver + MethodChannel forward

- SetPropW marks this window for EnumWindows discovery
- WM_COPYDATA handler extracts argv (UTF-8), filters non-book extensions
- MethodChannel invokeMethod("openBook", path) forwards to Dart BookOpenBridge
- Dart side unchanged: init already registers openBook handler

Completes Windows single-instance deep-link warm-start path.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Android SDK install documentation

**Files:**
- Create: `docs/setup-android-sdk.md`
- This task is **doc-only** (no code changes). The actual Android SDK install is done by the user as documented.

- [ ] **Step 1: Write Android SDK install guide**

Create `docs/setup-android-sdk.md`:

```markdown
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
   - SDK Platforms：勾 **Android 14.0 (API 34)**（项目 compileSdk）
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
   sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
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

## 下一步

SDK 装好后，按 [`docs/release-procedure.md`](release-procedure.md) 跑 release build + smoke test。
```

- [ ] **Step 2: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add docs/setup-android-sdk.md
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
docs(m8/t6): Android SDK install guide (Windows)

Two paths documented:
- Android Studio (recommended, ~3GB, includes emulator)
- Command-line sdkmanager (lightweight, ~1GB)

Resolves M7 blocker: Android SDK not installed on dev machine.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: CHANGELOG.md + NOTICE

**Files:**
- Create: `CHANGELOG.md`
- Create: `NOTICE`

- [ ] **Step 1: Write CHANGELOG.md (cumulative M0→M8)**

Create `CHANGELOG.md` at repo root:

```markdown
# Changelog

本项目所有重要变更记录在此文件。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

M8 之后到 v1.0 之间的打磨工作将记在此处。

## [0.5.0] - 2026-06-28

### Added
- Windows Inno Setup 安装包（自动注册 .epub/.pdf 文件关联、开始菜单快捷方式、卸载项）
- Windows 便携 Zip 分发（解压即用，免安装）
- Android fat APK release artifact（真签名 + `apksigner verify`）
- Windows 单实例 deep-link（命名 mutex + WM_COPYDATA 跨进程 argv 透传）
- `BookOpenBridgeOptions.onError` 可选回调 → SnackBar 失败反馈（默认行为向后兼容）
- `dart_test.yaml` 配置 golden tag（消除 test runner warning）
- `CHANGELOG.md` + `NOTICE` 三件套（AGPLv3 合规）
- `docs/setup-android-sdk.md` 安装指南
- `docs/release-procedure.md` 发布流程手册
- 4 张主界面截图（library / EPUB reader / PDF reader / Notes）

### Changed
- 根 `README.md` 状态刷到 v0.5.0；加下载安装段 + 主界面预览
- `app/README.md` 从 Flutter 模板骨架重写为开发者操作手册

### Removed
- `.github/workflows/ci.yml`（项目 remote 在 Gitee，本地手动 build only）

## [0.4.0] - 2026-06-28

### Added
- 应用显示名「智阅」（Android + Windows 双端同步）
- `flutter_launcher_icons` pipeline（用户 AI 生图 → Android mipmap-* + Windows .ico）
- Android release signing 配置（`keystore.properties` gitignored）
- Android `intent-filter` 注册 `VIEW` epub/pdf（含 4 个 pathPattern 覆盖多重扩展名）
- `BookOpenBridge` Dart bridge（`isSupportedBookPath` / `handlePath` / `init`，10 单测）
- `MainActivity` Kotlin MethodChannel bridge（cold start `popPendingBookPath` + warm start `openBook` + `content://` 拷贝到 cacheDir）
- `main.dart` 接入（`main(List<String> args)` + post-frame callback + `UncontrolledProviderScope`）
- `routerProvider` Riverpod singleton（修 ZhiYueApp.build 每次重建新建 router 反模式）

## [0.1.0] - 2026-06-24

M0 + M1：数据层基础交付（58 测试）。

### Added
- drift SQLite 数据库（`books` / `chapters` / `highlights` / `notes` / `tags` 表）
- FTS5 全文索引（跨书搜索 highlights + notes）
- `BookRepository` + `HighlightRepository` + `NoteRepository` + `TagRepository`
- 文件存储层（`BookStorageService`，分 book/highlight/note 三层目录）
- 应用启动初始化（drift database + ProviderContainer）

## 后续里程碑（无对应版本 tag，但内容已交付）

### M2 (2026-06-26) - EPUB 阅读器
- 30 commits + 179 tests，tag `m2-complete`
- epubx 解析 + 自研渲染（pivot 自 epub_view_plus，因为后者未上 pub.dev）
- EpubRangeLocator + ReaderEngine 接口
- 章节切换 / 进度持久化 / 主题适配

### M3.1 (2026-06-26) - 库 + 导入 + 标签 + 排版
- 28 commits + 295 tests，tag `m3.1-complete`
- LibraryPage（grid + list 双视图）
- BookImportService（EPUB/PDF 自动格式检测）
- 标签系统（多对多 + 拖拽排序）
- 排版预设扩展

### M3.2 (2026-06-27) - 高亮 + 笔记 + 跨书搜索
- 28 commits + 366 tests，tag `m3.2-complete`
- 5 色高亮 + 笔记
- FTS5 跨书搜索 highlights + notes
- 章节分组 drawer

### M3.3 (2026-06-27) - 精确 offset + chapterTitles
- 8 commits + 389 tests，tag `m3.3-complete`
- 精确 offset 定位（不再用 paragraphIndex 粗粒度）
- chapterTitles（章节深链滚动）

### M3.4 (2026-06-27) - per-book NotesPage + Markdown 导出
- 17 commits + 442 tests，tag `m3.4-complete`
- per-book NotesPage
- Markdown 导出（含 frontmatter）
- paged 模式精确滚动
- chapterRevisionNotifier

### M3.5 (2026-06-27) - 设置 / 字体 / i18n / 多预设排版
- 18 commits + 491 tests，tag `m3.5-complete`
- SettingsPage + FontManagementPage
- i18n（中文 + 英文）
- 多预设排版（serif / sans / 自定义）
- chapterSwitchSettled 重构

### M4 (2026-06-28) - PDF 阅读器
- 19 commits + 565 tests，tag `m4-complete`
- pdfrx 2.4.4 集成（MIT，AGPLv3 兼容）
- Page-as-Chapter 映射（PDF 第 N 页 = engine chapterIndex N-1）
- 文本选区高亮
- 扫描 PDF heuristic 检测（前 3 页 < 100 字符判定）
- 主题适配（light/dark/sepia/eInk via ColorFiltered）

### M7 (2026-06-28) - 平台适配
- 13 commits + 575 tests，tag `m7-complete` + `v0.4.0`
- 见 [0.4.0] 段落

## 链接

- [Unreleased]: https://gitee.com/weifu0523/e-book-reading-platform/compare/v0.5.0...master
- [0.5.0]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.5.0
- [0.4.0]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.4.0
- [0.1.0]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.1.0
```

- [ ] **Step 2: Write NOTICE file**

Create `NOTICE` at repo root:

```
智阅 (ZhiYue)
Copyright 2026 ZhiYue Open Source contributors

本项目使用以下开源软件（按字母序），版权属于各自作者：

- collection (BSD-3-Clause) - https://pub.dev/packages/collection
- crypto (BSD-3-Clause) - https://pub.dev/packages/crypto
- drift (Apache License 2.0) - https://drift.simonbinder.eu/
- epubx (MIT License) - https://github.com/rbcprolabs/epubx.dart
  （本项目通过本地 fork `epubx_patched/` 引入，详见 `app/pubspec.yaml` dependency_overrides）
- file_picker (MIT License) - https://pub.dev/packages/file_picker
- flutter (BSD-3-Clause) - https://flutter.dev
- flutter_launcher_icons (MIT License) - https://pub.dev/packages/flutter_launcher_icons
- flutter_riverpod (MIT License) - https://riverpod.dev
- go_router (BSD-3-Clause) - https://pub.dev/packages/go_router
- golden_toolkit (Apache License 2.0) - https://pub.dev/packages/golden_toolkit
- intl (BSD-3-Clause) - https://pub.dev/packages/intl
- mocktail (MIT License) - https://pub.dev/packages/mocktail
- path (BSD-3-Clause) - https://pub.dev/packages/path
- path_provider (BSD-3-Clause) - https://pub.dev/packages/path_provider
- pdfrx (MIT License) - https://github.com/espresso33893/pdfrx
- reorderables (MIT License) - https://pub.dev/packages/reorderables
- riverpod_annotation (MIT License) - https://pub.dev/packages/riverpod_annotation
- sqlite3_flutter_libs (MIT License) - https://pub.dev/packages/sqlite3_flutter_libs
- url_launcher (BSD-3-Clause) - https://pub.dev/packages/url_launcher
- uuid (MIT License) - https://pub.dev/packages/uuid

各包的具体 LICENSE 文件可在 pub cache 中查阅
（`%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\<package>-<version>\LICENSE`）。

本项目源码以 AGPLv3 协议发布，详见 LICENSE。
```

- [ ] **Step 3: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add CHANGELOG.md NOTICE
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
docs(m8/t7): add CHANGELOG.md + NOTICE (AGPLv3 compliance)

CHANGELOG: cumulative M0→M8 (Keep-a-Changelog format)
NOTICE: third-party copyright notices for all runtime/dev deps

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Root README.md rewrite + app/README.md rewrite

**Files:**
- Modify: `README.md` (root)
- Modify: `app/README.md`

- [ ] **Step 1: Replace root README.md**

Replace `README.md` (root) with:

```markdown
# 智阅（Zhi Yue）

> 面向深度阅读/学习者的开源 Flutter 电子书阅读平台。
> 先做极致本地阅读体验，逐步叠加 AI 陪伴式学习与跨端同步。

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Version](https://img.shields.io/badge/version-0.5.0-blue.svg)](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.5.0)

## 项目状态

✅ **MVP 1.0 候选版本 v0.5.0 已发布**：双端 release artifact（Windows installer + Android APK）。
下一步：测试/打磨后 tag `v1.0.0`。

## 下载安装

### Windows

- **安装包**（[zhiyue-setup-0.5.0.exe](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.5.0)）— 自动注册 .epub/.pdf 文件关联、加开始菜单快捷方式、含卸载项。
- **便携版**（[zhiyue-portable-0.5.0.zip](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.5.0)）— 解压即用，免安装。

> 安装后双击任意 .epub / .pdf 文件会自动用智阅打开。若已运行智阅，会在原窗口打开新书而不是启动新进程。

### Android

- **APK**（[zhiyue-0.5.0.apk](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.5.0)）— sideload 安装。
- Android 8+ 需在「设置 → 应用 → 特殊访问权限 → 安装未知应用」中允许浏览器安装 APK。
- 安装后在文件管理器点击 .epub / .pdf，选「智阅」打开。

## 主界面预览

| Library | EPUB Reader | PDF Reader | Notes |
|---|---|---|---|
| ![Library](docs/screenshots/library.png) | ![EPUB Reader](docs/screenshots/epub_reader.png) | ![PDF Reader](docs/screenshots/pdf_reader.png) | ![Notes](docs/screenshots/notes.png) |

## MVP 1.0 目标

- **跨端阅读**：Windows + Android，一套 Flutter 代码（Mac 后期）
- **格式支持**：EPUB 完整功能 + PDF（文本版基础 + 扫描版仅阅读）
- **本地优先**：所有数据本地 SQLite，完全离线可用
- **沉浸阅读**：极致排版、4 套主题（亮/暗/护眼/电子墨水）、全屏沉浸模式
- **读书笔记**：高亮（5 色）+ 笔记 + 标签 + 全文搜索（FTS5）
- **知识沉淀**：读书笔记库 + Markdown 导出（Obsidian 兼容）

## 后续阶段

- **1.5**：AI 导读 + 伴随式问答（DeepSeek BYOK）
- **2.0**：章节学习回顾 + 知识库深化 + 坚果云 WebDAV 同步
- **3.0+**：Zotero/Obsidian 双向同步、知识图谱、Mac 端

## 技术栈

| 层 | 技术 |
|---|---|
| 框架 | Flutter 3.27+ |
| 语言 | Dart 3.10+ |
| 状态管理 | Riverpod 2.6 |
| 路由 | go_router 14.2 |
| 数据库 | drift 2.18 (SQLite + FTS5) |
| EPUB | epubx 4.0.0（本地 fork） |
| PDF | pdfrx 2.4.4 |
| 协议 | AGPLv3 |

## 文档

- [原始设计文档（MVP 1.0）](docs/superpowers/specs/2026-06-24-ebook-platform-design.md)
- [原始调研报告](docs/01-research.md)（从市场到产品的战略分析）
- [Android SDK 安装指南](docs/setup-android-sdk.md)
- [发布流程](docs/release-procedure.md)
- [更新日志](CHANGELOG.md)

## 反馈与贡献

- Gitee Issues：[https://gitee.com/weifu0523/e-book-reading-platform/issues](https://gitee.com/weifu0523/e-book-reading-platform/issues)
- 项目尚在开发初期，暂不接受外部 PR；欢迎在 Issues 中提出建议。

## 开源协议

本项目采用 [AGPLv3](LICENSE) 协议开源。

任何对本项目代码的修改、网络服务化使用，都必须以同等协议开源。第三方依赖版权声明详见 [NOTICE](NOTICE)。
```

- [ ] **Step 2: Replace app/README.md**

Replace `app/README.md` with:

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add README.md app/README.md
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
docs(m8/t8): rewrite root README + replace app/README Flutter template

Root README:
- Status refreshed to v0.5.0
- New sections: download install (Windows installer + portable zip + Android APK),
  main UI preview (4 screenshots referenced), third-party NOTICE link
- Tech stack refreshed with version pins

app/README:
- Replace Flutter template with developer operations manual
- Sections: dev env, common commands, icon pipeline, release build (Win/Android),
  smoke test procedures (Android + Windows + bridge failure SnackBar)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Inno Setup zhiyue.iss script

**Files:**
- Create: `app/windows/installer/zhiyue.iss`

- [ ] **Step 1: Write Inno Setup script**

Create `app/windows/installer/zhiyue.iss`:

```pascal
; 智阅 (ZhiYue) Windows installer script
; Requires Inno Setup 6+ (https://jrsoftware.org/isdl.php)
; Run after `flutter build windows --release` produces build/windows/x64/runner/Release/

#define MyAppName "智阅"
#define MyAppNameAscii "ZhiYue"
#define MyAppVersion "0.5.0"
#define MyAppPublisher "ZhiYue Open Source"
#define MyAppURL "https://gitee.com/weifu0523/e-book-reading-platform"
#define MyAppExeName "zhiyue.exe"

[Setup]
AppId={{8F8E7B5D-3D5B-4F8D-9C2A-2A4F5D5D5D5D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=zhiyue-setup-{#MyAppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Languages\English.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Flutter release bundle: zhiyue.exe + dll + data + assets
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

; File associations: .epub and .pdf
[Registry]
; .epub
Root: HKA; Subkey: ".epub"; ValueType: string; ValueName: ""; ValueData: "ZhiYue.Book"; Flags: uninsdeletevalue
Root: HKA; Subkey: "ZhiYue.Book"; ValueType: string; ValueName: ""; ValueData: "智阅图书"; Flags: uninsdeletekey
Root: HKA; Subkey: "ZhiYue.Book\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "ZhiYue.Book\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
; .pdf
Root: HKA; Subkey: ".pdf"; ValueType: string; ValueName: ""; ValueData: "ZhiYue.Pdf"; Flags: uninsdeletevalue
Root: HKA; Subkey: "ZhiYue.Pdf"; ValueType: string; ValueName: ""; ValueData: "智阅 PDF"; Flags: uninsdeletekey
Root: HKA; Subkey: "ZhiYue.Pdf\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "ZhiYue.Pdf\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean bundle files (data/Flutter assets etc.) but keep user data in %APPDATA%
Type: filesandordirs; Name: "{app}"
```

- [ ] **Step 2: Document the build step in release-procedure (created in T12)**

The actual `iscc` invocation will be documented in `docs/release-procedure.md` (T12). The script itself is the deliverable here.

- [ ] **Step 3: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/windows/installer/zhiyue.iss
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m8/t9): Inno Setup installer script for Windows

zhiyue.iss features:
- AppName 智阅, version 0.5.0, 64-bit install, per-user (no admin)
- File associations .epub and .pdf via HKA registry (uninstall-safe)
- Start menu + optional desktop shortcuts
- Chinese Simplified + English languages
- LZMA2 ultra compression
- Outputs build/installer/zhiyue-setup-0.5.0.exe

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Portable zip packaging script

**Files:**
- Create: `app/windows/installer/build-portable-zip.ps1`

- [ ] **Step 1: Write PowerShell packaging script**

Create `app/windows/installer/build-portable-zip.ps1`:

```powershell
# 智阅 portable zip builder
# Usage (from app/):
#   powershell -ExecutionPolicy Bypass -File windows\installer\build-portable-zip.ps1
# Prerequisite: flutter build windows --release has been run.

param(
    [string]$Version = "0.5.0"
)

$ErrorActionPreference = "Stop"

$AppRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ReleaseDir = Join-Path $AppRoot "build\windows\x64\runner\Release"
$OutputDir = Join-Path $AppRoot "build\installer"
$ZipName = "zhiyue-portable-$Version.zip"
$ZipPath = Join-Path $OutputDir $ZipName

if (-not (Test-Path $ReleaseDir)) {
    Write-Error "Release directory not found: $ReleaseDir`nRun 'flutter build windows --release' first."
    exit 1
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

if (Test-Path $ZipPath) {
    Write-Host "Removing existing $ZipName ..."
    Remove-Item $ZipPath -Force
}

Write-Host "Zipping $ReleaseDir -> $ZipPath ..."
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal

$size = (Get-Item $ZipPath).Length / 1MB
Write-Host ("Done: {0} ({1:N1} MB)" -f $ZipPath, $size)
```

- [ ] **Step 2: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/windows/installer/build-portable-zip.ps1
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m8/t10): portable zip packaging script (PowerShell)

build-portable-zip.ps1 wraps build/windows/x64/runner/Release/ into
build/installer/zhiyue-portable-<version>.zip via Compress-Archive.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Release procedure documentation

**Files:**
- Create: `docs/release-procedure.md`

- [ ] **Step 1: Write release procedure runbook**

Create `docs/release-procedure.md`:

```markdown
# 智阅 Release 发布流程

本文档记录从源码到 Gitee Release 的完整发布步骤。每次发版（v0.5.0、v0.6.0、v1.0.0 等）都按此跑一遍。

## 前置条件

- Flutter SDK 已装（`flutter --version` 能跑）
- Android SDK 34 已装（见 [setup-android-sdk.md](setup-android-sdk.md)）
- Inno Setup 6+ 已装（[下载](https://jrsoftware.org/isdl.php)，安装后 `iscc` 在 PATH 中）
- 项目已 clone 完整，`git remote -v` 输出 Gitee 地址
- 当前在 master 分支，所有改动已 commit

## 步骤 1：版本号确认

```bash
grep "^version:" app/pubspec.yaml
# 期望：version: 0.5.0+2
```

若需 bump：
- `app/pubspec.yaml` → `version: X.Y.Z+N`
- `app/windows/installer/zhiyue.iss` → `#define MyAppVersion "X.Y.Z"`
- `CHANGELOG.md` → 新增 `[X.Y.Z]` 段落

## 步骤 2：跑测试 + 静态分析

```bash
cd app
/c/flutter/bin/dart analyze
/c/flutter/bin/dart test
```

期望：
- analyze 干净（pdfrx 已知 info-lint 除外）
- test 全部通过（≥ 575）

reader_engine / epub_view / pdf_view 包同样跑一遍：

```bash
cd reader_engine && /c/flutter/bin/dart test && cd ..
cd reader_engine_epub_view && /c/flutter/bin/dart test && cd ..
cd reader_engine_pdf_view && /c/flutter/bin/dart test && cd ..
```

## 步骤 3：构建 Windows release

```cmd
cd app
flutter build windows --release
```

产物：`build\windows\x64\runner\Release\`（zhiyue.exe + flutter_windows.dll + data/）

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

前置：`app/android/app/keys/keystore.properties` 已生成（参考 [`app/android/app/keys/README.md`](../app/android/app/keys/README.md)）。

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
2. 选择刚推送的 tag（如 `v0.5.0`）
3. 标题：`智阅 0.5.0`
4. 上传 3 个 artifact：
   - `build/installer/zhiyue-setup-0.5.0.exe`
   - `build/installer/zhiyue-portable-0.5.0.zip`
   - `build/installer/zhiyue-0.5.0.apk`
5. Release notes 内容（复制 `CHANGELOG.md` 对应版本的段落，开头加一行简短描述）
6. 发布

## 步骤 12：发布后核对

- [ ] Gitee Release 页面能看到 3 个 artifact，下载链接可访问
- [ ] 仓库根 `README.md` 下载链接指向新 release
- [ ] `CHANGELOG.md` 已更新到新版本
- [ ] tag 在 `git tag --list` 中存在，已 push 到 Gitee

完成。
```

- [ ] **Step 2: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add docs/release-procedure.md
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
docs(m8/t11): Gitee Release upload + smoke test runbook

12-step procedure:
1. Version check
2. Test + analyze
3. Windows release build
4. Inno Setup installer
5. Portable zip
6. Android signed APK
7. Android smoke test
8. Windows single-instance smoke test
9. Screenshots
10. Tag + push
11. Gitee Release upload
12. Post-release checklist

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: User-driven Android SDK install + release build + smoke test

> **⚠ USER ACTION REQUIRED.** Subagent prepares docs in T6 (done) + verifies code in T2/T3 (Dart) and T4/T5 (C++ syntax). User runs SDK install + keystore gen + actual builds + smoke test. Subagent verifies results when user reports back.

**Files:**
- (No code changes in this task — pure execution / verification)

- [ ] **Step 1: User installs Android SDK per `docs/setup-android-sdk.md`**

User follows [docs/setup-android-sdk.md](../../../docs/setup-android-sdk.md) and runs:

```cmd
flutter doctor -v
```

Expected: Android toolchain, Connected device all show `[✓]`.

- [ ] **Step 2: User generates release keystore per `app/android/app/keys/README.md`**

User follows [app/android/app/keys/README.md](../../../app/android/app/keys/README.md) — runs `keytool` (interactive password input) and creates `app/android/app/keys/zhiyue-release.jks` + `keystore.properties`.

Subagent cannot run this step (password input is interactive).

- [ ] **Step 3: User runs `flutter build apk --release`**

User runs in app/:

```cmd
flutter build apk --release
```

Expected output ends with: `Built build\app\outputs\flutter-apk\app-release.apk (X.X MB)`.

- [ ] **Step 4: User verifies APK signature**

```cmd
apksigner verify --verbose build\app\outputs\flutter-apk\app-release.apk
```

Expected output includes:
```
Verified using v1 scheme (JAR signing): true
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): true
```

If any of these say `false` or are missing, the keystore.properties path resolution failed. Check `app/android/app/build.gradle.kts` references to `rootProject.file("app/keys/keystore.properties")`.

- [ ] **Step 5: User runs Android smoke test (deep-link)**

User connects device/emulator via adb, then runs the 4 commands in `docs/release-procedure.md` step 7.

Expected behavior:
- Cold start: opening `.epub` from file manager launches app → auto-routes to reader
- Warm start: opening second `.pdf` while reader is shown pushes new reader

If smoke test fails, capture `adb logcat | grep -i zhiyue` output and report back.

- [ ] **Step 6: Subagent documents smoke test result**

Subagent (after user reports back) appends a section to `docs/release-procedure.md`:

```markdown
## v0.5.0 Smoke Test Results (filled in after T12)

- Date: YYYY-MM-DD
- Device: <model / API level>
- Android SDK version: 34.0.0
- APK signing: v1 ✓ / v2 ✓ / v3 ✓
- Cold-start deep-link (.epub): ✓ / ✗
- Cold-start deep-link (.pdf): ✓ / ✗
- Warm-start deep-link (.epub → .pdf): ✓ / ✗
- Notes: <anything unexpected>
```

- [ ] **Step 7: Commit smoke test result (if any docs updated)**

```bash
git -C "H:/projiect/电子书阅读平台" add docs/release-procedure.md
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
docs(m8/t12): v0.5.0 Android smoke test results

Signed-off-by: <user>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

(Commit only if smoke test was actually run; otherwise this task stays pending.)

---

## Task 13: User-driven Windows build + Inno Setup compile + portable zip

> **⚠ USER ACTION REQUIRED.** Subagent wrote the `.iss` (T9) and `.ps1` (T10). User runs the actual builds + script execution. Subagent verifies the produced artifacts exist.

**Files:**
- (No code changes — pure execution)

- [ ] **Step 1: User installs Inno Setup 6+**

Download from <https://jrsoftware.org/isdl.php>. Default install. Verify `iscc` is in PATH:

```cmd
iscc /?
```

Expected: prints Inno Setup version banner.

- [ ] **Step 2: User runs Windows release build**

```cmd
cd app
flutter build windows --release
```

Expected output ends with `Built build\windows\x64\runner\Release\zhihiue.exe` (no build errors).

If pdfrx native link fails, ensure Windows Developer Mode is on (Settings → For developers → Developer Mode) — pdfrx uses symbolic links.

- [ ] **Step 3: User compiles Inno Setup installer**

```cmd
cd app
iscc windows\installer\zhiyue.iss
```

Expected output ends with:
```
Successful compile...
Output: ..\..\build\installer\zhiyue-setup-0.5.0.exe
```

If the script errors on `SourceDir` or file not found, check `Release/` directory was created by step 2.

- [ ] **Step 4: User generates portable zip**

```cmd
cd app
powershell -ExecutionPolicy Bypass -File windows\installer\build-portable-zip.ps1
```

Expected output: `Done: ...\build\installer\zhiyue-portable-0.5.0.zip (XX.X MB)`.

- [ ] **Step 5: User runs installer smoke test**

1. Double-click `build\installer\zhiyue-setup-0.5.0.exe`
2. Install with default options (per-user, no admin)
3. Verify Start menu → 智阅
4. Verify file association: double-click a .epub in File Explorer → opens in 智阅
5. **Single-instance check**: with 智阅 running, double-click another .epub → opens in existing window, **no second window appears**
6. Uninstall → verify clean cleanup (no orphan registry, no orphan files)

- [ ] **Step 6: Subagent documents Windows smoke test result**

Append to `docs/release-procedure.md`:

```markdown
## v0.5.0 Windows Smoke Test Results (after T13)

- Date: YYYY-MM-DD
- Windows version: <e.g., 11 23H2>
- Installer size: XX.X MB
- Portable zip size: XX.X MB
- Install per-user: ✓ / ✗
- Start menu shortcut: ✓ / ✗
- File association .epub: ✓ / ✗
- File association .pdf: ✓ / ✗
- Single-instance deep-link: ✓ / ✗
- Uninstall cleanup: ✓ / ✗
- Notes: <anything unexpected>
```

- [ ] **Step 7: Commit smoke test result**

```bash
git -C "H:/projiect/电子书阅读平台" add docs/release-procedure.md
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
docs(m8/t13): v0.5.0 Windows installer + portable smoke test results

Signed-off-by: <user>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Screenshots + final tag

**Files:**
- Create: `docs/screenshots/library.png`
- Create: `docs/screenshots/epub_reader.png`
- Create: `docs/screenshots/pdf_reader.png`
- Create: `docs/screenshots/notes.png`

> **⚠ USER ACTION REQUIRED** for screenshots (manual capture).

- [ ] **Step 1: User runs Windows app and captures 4 screenshots**

User follows `docs/release-procedure.md` step 9 to:
1. Import a fixture EPUB and PDF
2. Capture 4 screenshots (Win + Shift + S):
   - Library with at least 2 books visible → `docs/screenshots/library.png`
   - EPUB reader with a highlight → `docs/screenshots/epub_reader.png`
   - PDF reader with a highlight → `docs/screenshots/pdf_reader.png`
   - Notes page (per-book) with at least one note → `docs/screenshots/notes.png`
3. Save as PNGs (each < 500KB ideally — resize if huge)

Subagent cannot capture screenshots — Windows UI capture requires manual interaction.

- [ ] **Step 2: Verify README references match filenames**

```bash
grep "docs/screenshots" H:/projiect/电子书阅读平台/README.md
```

Expected: 4 references, matching `library.png` / `epub_reader.png` / `pdf_reader.png` / `notes.png`.

- [ ] **Step 3: Commit screenshots**

```bash
git -C "H:/projiect/电子书阅读平台" add docs/screenshots/*.png
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
docs(m8/t14): v0.5.0 release screenshots

4 main UI screens for README + Gitee Release:
- library.png
- epub_reader.png (with highlight)
- pdf_reader.png (with highlight)
- notes.png (per-book notes page)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Final integration test**

Run all 4 packages:

```bash
cd app && /c/flutter/bin/dart test 2>&1 | tail -5
cd ../reader_engine && /c/flutter/bin/dart test 2>&1 | tail -3
cd ../reader_engine_epub_view && /c/flutter/bin/dart test 2>&1 | tail -3
cd ../reader_engine_pdf_view && /c/flutter/bin/dart test 2>&1 | tail -3
```

Expected: total ≥ 575 + 4 (new bridge error tests) = ~579 passing, 2 skipped.

- [ ] **Step 5: Tag m8-complete + v0.5.0**

```bash
git -C "H:/projiect/电子书阅读平台" tag m8-complete
git -C "H:/projiect/电子书阅读平台" tag v0.5.0
git -C "H:/projiect/电子书阅读平台" push origin master --tags
```

Expected: both tags pushed to Gitee.

- [ ] **Step 6: Update memory file**

Subagent updates `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_m8_complete.md` with M8 completion summary (14 tasks, ~579 tests, tag, deferred items for v1.0). Updates `MEMORY.md` index.

---

## Self-Review

After writing this plan, I reviewed it against the spec. Findings:

**1. Spec coverage** (checked each spec section against tasks):
- §3.1 Windows 双分发 → T9 (Inno Setup) + T10 (portable zip) ✓
- §3.2 Android fat APK → T12 (user build) ✓
- §3.3 Delete GitHub Actions CI → T1 ✓
- §3.4 Android SDK 必装 + 真机 smoke test → T6 (docs) + T12 (user runs) ✓
- §3.5 Bridge 错误回调 → T2 (options + tests) + T3 (wire SnackBar) ✓
- §3.6 Windows 单实例 → T4 (mutex) + T5 (WM_COPYDATA) ✓
- §3.7 CHANGELOG/NOTICE/LICENSE → T7 (CHANGELOG + NOTICE; LICENSE already exists in M0) ✓
- §4.2 dart_test.yaml → T1 ✓
- §4.3 版本号 bump → T1 ✓
- §4.7 README rewrite → T8 ✓
- §4.8 截图 → T14 ✓
- §10 风险：Android SDK 安装失败 / Inno Setup 未装 → mitigated by T6 + T13 step 1 user action

No gaps.

**2. Placeholder scan**: No TBD / TODO / "implement later" / "similar to" — every step has actual code or actual commands.

**3. Type consistency**: 
- `BookOpenBridgeOptions` defined in T2 step 3, used in T2 step 4/5 and T3 step 1 — same name, same signature ✓
- `scaffoldMessengerKey` declared in T3 step 1 (`main.dart`), imported in T3 step 2 (`app.dart` via `show`) — consistent ✓
- C++ constants `kZhiYueWindowProp` and `kCopyDataArgvTag` defined in both T4 (main.cpp namespace) and T5 (flutter_window.cpp namespace) — same string/value (`L"ZhiYueWindowProp"` / `1`) — duplicated deliberately with comment to keep modules decoupled ✓
- `IsSupportedBookPath` C++ helper in T5 mirrors `BookOpenBridge.isSupportedBookPath` Dart logic — same behavior ✓
- Inno Setup script version `0.5.0` matches pubspec `0.5.0+2` (the +2 build number isn't visible to user; semantic version 0.5.0 matches) ✓

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-28-m8-release-packaging.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Tasks 12-14 require user collaboration for builds/screenshots; subagent prepares and user executes.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
