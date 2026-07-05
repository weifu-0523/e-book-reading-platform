#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

// Deep-link URI parsing ("zhiyue://book/<id>") lives in
// deep_link_parser.{h,cpp} so it can be unit-tested without booting
// Flutter. The Windows runner does not yet wire up scheme activation
// (argv file forwarding is the current path); when scheme activation
// lands, call zhiyue::parseBookIdFromDeepLink from this file.
// See test_main.cpp + run_smoke_test.bat for the regression test.
#include "deep_link_parser.h"

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
    // M4.6-fix4: 找到已有实例窗口后，先把它拉到前台（用户从桌面图标二次
    // 启动时最期望的行为是已有窗口前置，而不是无反应闪退）。
    // WINDOWPLACEMENT + ShowWindow(SW_RESTORE) 处理最小化/最大化的恢复；
    // SetForegroundWindow 尝试切到前台（不一定每次都成功，但足够常见场景）。
    WINDOWPLACEMENT placement = {sizeof(WINDOWPLACEMENT)};
    if (GetWindowPlacement(hwnd, &placement)) {
      if (placement.showCmd == SW_SHOWMINIMIZED ||
          placement.showCmd == SW_SHOWMINNOACTIVE) {
        ShowWindow(hwnd, SW_RESTORE);
      }
    }
    // 即使 argv 为空（桌面图标双击启动），也尝试前置；argv 非空时再发
    // WM_COPYDATA 把书籍路径转给已运行实例打开。
    SetForegroundWindow(hwnd);
    if (!ctx->argv.empty()) {
      COPYDATASTRUCT cds = {};
      cds.dwData = kCopyDataArgvTag;
      cds.cbData = static_cast<DWORD>(ctx->argv.size() + 1);  // include trailing null
      cds.lpData = const_cast<char*>(ctx->argv.c_str());
      SendMessageW(hwnd, WM_COPYDATA, 0,
                   reinterpret_cast<LPARAM>(&cds));
    }
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
    // M4.6-fix4: 第二实例发现已有实例时，无论 argv 是否为空都尝试把已有
    // 窗口前置（之前仅 argv 非空时转发，桌面图标双击启动 argv 空 → 直接
    // 退出 → 用户看到"图标闪一下就没了"）。FindZhiYueWindow 内部已处理：
    // 总是 SetForegroundWindow，仅 argv 非空时再 WM_COPYDATA 转发书路径。
    EnumContext ctx{argv_utf8.empty() ? std::string() : argv_utf8.front()};
    EnumWindows(FindZhiYueWindow, reinterpret_cast<LPARAM>(&ctx));
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

  // M4.6-fix4: message loop 退出后强制终止进程。
  //
  // 根因：用户报告"exe 关掉后不能打开"——tasklist 显示 zhiyue.exe 进程
  // 在窗口关闭后仍残留（656MB），mutex 永远 ALREADY_EXISTS，第二实例直接
  // 退出。残留源于 Flutter engine 关窗时若 native plugin（pdfrx PDFium /
  // window_manager）持有未释放资源，message loop 的 GetMessage 链可能挂
  // 在某个消息处理里出不来，但即便 return 路径走不到，进程仍需退出。
  //
  // ExitProcess 是 Win32 兜底强制终止：跳过 Dart dispose / C++ 析构，但
  // kernel mutex / COM 资源由 OS 回收，确保下次启动能拿到 fresh 状态。
  // 副作用：drift 数据库可能跳过最后一次 WAL checkpoint，但 WAL 模式下
  // 已提交事务不会丢（仅可能丢尚未 flush 的 page cache，下次启动
  // recovery 即可）。比"进程永远不退出"严重得多。
  if (mutex) CloseHandle(mutex);
  ::CoUninitialize();
  ::ExitProcess(EXIT_SUCCESS);
}
