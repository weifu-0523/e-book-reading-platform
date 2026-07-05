#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <cstdio>
#include <ctime>
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

// M4.6-fix6: Diagnostic logging to %TEMP%\zhiyue_runner.log + OutputDebugString.
// Helps diagnose "exe won't open" — logs every critical decision point in
// wWinMain so we can see exactly where the launch path stalls.
void DiagLog(const std::string& msg) {
  OutputDebugStringA(msg.c_str());
  OutputDebugStringA("\n");
  static FILE* f = nullptr;
  if (!f) {
    char temp_path[MAX_PATH];
    if (GetTempPathA(MAX_PATH, temp_path)) {
      std::string path = std::string(temp_path) + "zhiyue_runner.log";
      fopen_s(&f, path.c_str(), "a");
    }
  }
  if (f) {
    std::time_t now = std::time(nullptr);
    std::fprintf(f, "[%lld] %s\n", static_cast<long long>(now), msg.c_str());
    std::fflush(f);
  }
}

// Callback for EnumWindows. If we find a window marked with
// kZhiYueWindowProp, raise it to the foreground and forward argv (if any).
// Sets *found_out = true when target window located.
struct EnumContext {
  const std::string& argv;
  bool* found_out;
};

BOOL CALLBACK FindZhiYueWindow(HWND hwnd, LPARAM lparam) {
  auto* ctx = reinterpret_cast<EnumContext*>(lparam);
  HANDLE marker = GetPropW(hwnd, kZhiYueWindowProp);
  if (marker != nullptr) {
    // M4.6-fix4: Always surface the existing window when a second instance
    // starts (the user's expectation when launching from the desktop icon
    // again is to surface the running window, not silently exit).
    WINDOWPLACEMENT placement = {sizeof(WINDOWPLACEMENT)};
    if (GetWindowPlacement(hwnd, &placement)) {
      if (placement.showCmd == SW_SHOWMINIMIZED ||
          placement.showCmd == SW_SHOWMINNOACTIVE) {
        ShowWindow(hwnd, SW_RESTORE);
      }
    }
    SetForegroundWindow(hwnd);
    if (!ctx->argv.empty()) {
      COPYDATASTRUCT cds = {};
      cds.dwData = kCopyDataArgvTag;
      cds.cbData = static_cast<DWORD>(ctx->argv.size() + 1);
      cds.lpData = const_cast<char*>(ctx->argv.c_str());
      SendMessageW(hwnd, WM_COPYDATA, 0,
                   reinterpret_cast<LPARAM>(&cds));
    }
    if (ctx->found_out) *ctx->found_out = true;
    return FALSE;  // stop enumeration
  }
  return TRUE;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  DiagLog("=== zhiyue.exe wWinMain start ===");

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // M8 + M4.6-fix6: Single-instance gate with takeover fallback.
  //
  // Named mutex `Local\ZhiYueApp` is the standard Win32 way. First instance
  // owns it for process lifetime; second instance tries to surface the
  // existing window and exits.
  //
  // M4.6-fix6 critical fix: if mutex says "already exists" but EnumWindows
  // finds NO window marked with kZhiYueWindowProp, the previous instance's
  // process is a zombie still holding the mutex (window destroyed but
  // process still alive — Flutter engine + native plugins can block
  // Flutter engine + native plugins can block GetMessage from exiting).
  // Pre-fix: second instance would silently exit → user sees "icon flashes
  // then disappears, can't open". Post-fix: this instance takes over by
  // re-creating the mutex (old holder died → kernel releases ownership)
  // and proceeds as a new first instance, opening a fresh window.
  HANDLE mutex = CreateMutexW(nullptr, TRUE, L"Local\\ZhiYueApp");
  DWORD mutex_err = GetLastError();
  bool is_first_instance =
      (mutex != nullptr) && (mutex_err != ERROR_ALREADY_EXISTS);
  DiagLog(std::string("mutex: first_instance=") +
          (is_first_instance ? "true" : "false") +
          " err=" + std::to_string(mutex_err));

  // Capture argv before potentially short-circuiting on second instance.
  std::vector<std::string> argv_utf8 = GetCommandLineArguments();

  if (!is_first_instance) {
    DiagLog("second instance: looking for existing window to surface");
    if (mutex) CloseHandle(mutex);

    bool found_window = false;
    EnumContext ctx{argv_utf8.empty() ? std::string() : argv_utf8.front(),
                    &found_window};
    EnumWindows(FindZhiYueWindow, reinterpret_cast<LPARAM>(&ctx));
    DiagLog(std::string("EnumWindows: found_existing_window=") +
            (found_window ? "true" : "false"));

    if (found_window) {
      // Existing window surfaced + argv forwarded (if any). Exit cleanly.
      DiagLog("second instance: surfaced existing window, exiting");
      ::CoUninitialize();
      return EXIT_SUCCESS;
    }

    // M4.6-fix6: mutex said "exists" but no window found → previous process
    // is a zombie (window destroyed, process still holds mutex). Take over
    // as new first instance. Re-creating the mutex works because the OS
    // releases kernel objects when their last handle closes; if the zombie
    // is truly still alive, this re-create will also fail and we exit.
    DiagLog("second instance: NO window found, attempting takeover");
    mutex = CreateMutexW(nullptr, TRUE, L"Local\\ZhiYueApp");
    mutex_err = GetLastError();
    is_first_instance = (mutex != nullptr) &&
                        (mutex_err != ERROR_ALREADY_EXISTS);
    DiagLog(std::string("takeover attempt: first_instance=") +
            (is_first_instance ? "true" : "false") +
            " err=" + std::to_string(mutex_err));
    if (!is_first_instance) {
      // Genuine race — another living instance holds the mutex. Give up.
      DiagLog("takeover FAILED: real living instance holds mutex, exiting");
      if (mutex) CloseHandle(mutex);
      ::CoUninitialize();
      return EXIT_SUCCESS;
    }
    // Fell through: this is now the new first instance.
    DiagLog("takeover SUCCESS: proceeding as new first instance");
  }

  DiagLog("first instance: creating Flutter project + window");
  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(std::move(argv_utf8));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"智阅", origin, size)) {
    DiagLog("ERROR: window.Create() failed — aborting");
    if (mutex) CloseHandle(mutex);
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  DiagLog("window created OK, entering message loop");
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }
  DiagLog("message loop exited (WM_QUIT received)");

  // M4.6-fix4: Force-exit the process after the message loop exits.
  //
  // Pre-fix: zhiyue.exe could stay alive after window close (Flutter engine +
  // native plugins holding resources can stall the GetMessage loop so this
  // point is never reached). The kernel mutex stays alive → next launch sees
  // ERROR_ALREADY_EXISTS → second instance bails out → "exe won't open".
  //
  // ExitProcess hard-terminates: skips Dart dispose / C++ destructors, but
  // the OS reclaims kernel mutex + COM resources, guaranteeing the next
  // launch gets a fresh state. Side effect: drift may skip the last WAL
  // checkpoint, but WAL mode never loses committed transactions.
  if (mutex) CloseHandle(mutex);
  ::CoUninitialize();
  DiagLog("calling ExitProcess");
  ::ExitProcess(EXIT_SUCCESS);
}
