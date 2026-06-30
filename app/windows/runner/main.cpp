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
    COPYDATASTRUCT cds = {};
    cds.dwData = kCopyDataArgvTag;
    cds.cbData = static_cast<DWORD>(ctx->argv.size() + 1);  // include trailing null
    cds.lpData = const_cast<char*>(ctx->argv.c_str());
    SendMessageW(hwnd, WM_COPYDATA, 0,
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
