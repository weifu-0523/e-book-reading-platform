#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // v1.14.0-alpha T2: test seams for cached_argv_ (only compiled when
  // -DZHIYUE_TESTING is defined, which it isn't in production builds).
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

  // v1.14.0-alpha T2: dedicated MethodChannel so Dart can drain cached_argv_
  // via popPendingArgv without colliding with the Dart-side openBook handler
  // on dev.zhiyue.bookopen (a MethodChannel only allows one handler).
  std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>> argv_channel_;

  // v1.14.0-alpha T2: caches the most recent argv forwarded by a second
  // instance via WM_COPYDATA. Read + cleared by Dart via popPendingArgv
  // MethodChannel call. Defends against the race where WM_COPYDATA arrives
  // before Dart's setMethodCallHandler has registered (channel_->InvokeMethod
  // would silently drop).
  std::string cached_argv_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
