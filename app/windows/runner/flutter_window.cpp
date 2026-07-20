#include "flutter_window.h"

#include <optional>
#include <string>
#include <windows.h>

#include "default_reader_registry.h"
#include "flutter/generated_plugin_registrant.h"

namespace {

// UTF-8 <-> UTF-16 conversion helpers. The naive byte-copy range constructor
// std::wstring(s.begin(), s.end()) is ASCII-only AND triggers C4244 (wchar_t
// -> char truncation) under /WX, so do it properly with the Win32 API.
std::wstring Utf8ToWide(const std::string& s) {
  if (s.empty()) return std::wstring();
  int needed = MultiByteToWideChar(CP_UTF8, 0, s.c_str(),
                                   static_cast<int>(s.size()), nullptr, 0);
  std::wstring out(needed, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()),
                      out.data(), needed);
  return out;
}

std::string WideToUtf8(const std::wstring& ws) {
  if (ws.empty()) return std::string();
  int needed = WideCharToMultiByte(CP_UTF8, 0, ws.c_str(),
                                   static_cast<int>(ws.size()), nullptr, 0,
                                   nullptr, nullptr);
  std::string out(needed, '\0');
  WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), static_cast<int>(ws.size()),
                      out.data(), needed, nullptr, nullptr);
  return out;
}

}  // namespace

namespace {

// Same constant as in main.cpp. Duplicated to keep modules decoupled.
constexpr const wchar_t* kZhiYueWindowProp = L"ZhiYueWindowProp";
constexpr ULONG_PTR kCopyDataArgvTag = 1;

// Check whether a file path is one we should forward to Dart BookOpenBridge.
// Mirrors BookOpenBridge.isSupportedBookPath on Dart side.
// M4.5: add .md / .markdown / .mdown / .txt support.
bool IsSupportedBookPath(const std::string& path) {
  // shortest valid: "x.md" (4 chars). Guard against degenerate paths.
  if (path.size() < 4) return false;
  auto pos = path.find_last_of('.');
  if (pos == std::string::npos) return false;
  std::string ext = path.substr(pos);
  // lowercase
  for (auto& c : ext) {
    if (c >= 'A' && c <= 'Z') c = c - 'A' + 'a';
  }
  return ext == ".epub" || ext == ".pdf" || ext == ".md" ||
         ext == ".markdown" || ext == ".mdown" || ext == ".txt";
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
           reinterpret_cast<HANDLE>(static_cast<uintptr_t>(1)));

  // M8: Open the MethodChannel that forwards argv to Dart BookOpenBridge
  // when the second instance sends WM_COPYDATA. Mirrors Android side
  // (dev.zhiyue.bookopen / "openBook").
  channel_ = std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "dev.zhiyue.bookopen",
      &flutter::StandardMethodCodec::GetInstance());

  // v1.14.0-alpha T2: dedicated channel for popPendingArgv so we don't
  // collide with the Dart-side openBook handler on dev.zhiyue.bookopen
  // (a MethodChannel only allows one handler at a time).
  argv_channel_ = std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "dev.zhiyue.bookopen.argv",
      &flutter::StandardMethodCodec::GetInstance());
  argv_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "popPendingArgv") {
          if (cached_argv_.empty()) {
            result->Success(flutter::EncodableValue(std::string()));
          } else {
            std::string out = cached_argv_;
            cached_argv_.clear();
            result->Success(flutter::EncodableValue(out));
          }
          return;
        }
        result->NotImplemented();
      });

  // v1.14.0-alpha T4: dedicated channel for default-reader registry methods.
  // Methods: readAssoc(ext) -> string, set_default_reader(exe_path) -> bool.
  default_reader_channel_ = std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "dev.zhiyue.default_reader",
      &flutter::StandardMethodCodec::GetInstance());
  default_reader_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "readAssoc") {
          const auto* args = call.arguments();
          if (args != nullptr &&
              std::holds_alternative<flutter::EncodableMap>(*args)) {
            const auto& m = std::get<flutter::EncodableMap>(*args);
            auto it = m.find(flutter::EncodableValue("ext"));
            if (it != m.end() && std::holds_alternative<std::string>(it->second)) {
              const auto& ext_utf8 = std::get<std::string>(it->second);
              std::wstring ext_w = Utf8ToWide(ext_utf8);
              auto cmd = zhiyue::ReadAssocForExtension(ext_w);
              if (cmd) {
                std::string utf8 = WideToUtf8(*cmd);
                result->Success(flutter::EncodableValue(utf8));
              } else {
                result->Success(flutter::EncodableValue(std::string()));
              }
              return;
            }
          }
          result->Error("invalid_argument", "ext required");
          return;
        }
        if (call.method_name() == "set_default_reader") {
          const auto* args = call.arguments();
          if (args != nullptr &&
              std::holds_alternative<flutter::EncodableMap>(*args)) {
            const auto& m = std::get<flutter::EncodableMap>(*args);
            auto it = m.find(flutter::EncodableValue("exe_path"));
            if (it != m.end() && std::holds_alternative<std::string>(it->second)) {
              const auto& exe_utf8 = std::get<std::string>(it->second);
              std::wstring exe_w = Utf8ToWide(exe_utf8);
              bool ok = zhiyue::SetDefaultReaderForExtension(L".epub", exe_w)
                     && zhiyue::SetDefaultReaderForExtension(L".pdf", exe_w);
              result->Success(flutter::EncodableValue(ok));
              return;
            }
          }
          result->Error("invalid_argument", "exe_path required");
          return;
        }
        result->NotImplemented();
      });

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
    if (cds != nullptr && cds->dwData == kCopyDataArgvTag) {
      // cbData includes trailing null; size the string without it.
      std::string arg(reinterpret_cast<const char*>(cds->lpData),
                      cds->cbData > 0 ? cds->cbData - 1 : 0);
      if (IsSupportedBookPath(arg)) {
        // v1.14.0-alpha T2: cache regardless of channel_ readiness so Dart
        // can drain via popPendingArgv even if this InvokeMethod silently
        // drops (handler not yet registered).
        cached_argv_ = arg;
        if (channel_) {
          channel_->InvokeMethod(
              "openBook",
              std::make_unique<flutter::EncodableValue>(arg));
        }
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
