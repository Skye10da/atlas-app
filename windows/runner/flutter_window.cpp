#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <dwmapi.h>
#include <string>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {
// Extract an integer from an EncodableValue that may be stored as int, int32_t, or int64_t.
bool GetInt(const flutter::EncodableValue& val, int64_t* out) {
  if (const auto* i = std::get_if<int>(&val)) { *out = *i; return true; }
  if (const auto* i32 = std::get_if<int32_t>(&val)) { *out = *i32; return true; }
  if (const auto* i64 = std::get_if<int64_t>(&val)) { *out = *i64; return true; }
  return false;
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

  // Bridge that lets a later-launched Atlas hand this window a document opened
  // via the shell. Dart listens on this channel (FileOpenController).
  file_open_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "com.atlasapp/file_open",
          &flutter::StandardMethodCodec::GetInstance());

  // Bridge for Dart to set the window title bar theme (dark mode, brand color).
  window_theme_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.atlasapp/window_theme",
          &flutter::StandardMethodCodec::GetInstance());

  window_theme_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        this->HandleThemeMethodCall(call, std::move(result));
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

void FlutterWindow::HandleThemeMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "setTheme") {
    HWND hwnd = GetHandle();
    if (!hwnd) {
      result->Error("no_window", "Window handle is null");
      return;
    }

    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Success();
      return;
    }

    // Dark mode
    auto dark_it = args->find(flutter::EncodableValue("dark"));
    if (dark_it != args->end()) {
      const auto* darkVal = std::get_if<bool>(&dark_it->second);
      if (darkVal != nullptr) {
        SetDarkMode(hwnd, *darkVal);
      }
    }

    // Caption color (Win11+ only, silently ignored on Win10)
    auto bg_it = args->find(flutter::EncodableValue("captionBg"));
    auto fg_it = args->find(flutter::EncodableValue("captionFg"));
    if (bg_it != args->end()) {
      int64_t bgRaw = 0;
      if (GetInt(bg_it->second, &bgRaw)) {
        COLORREF bgRef = static_cast<COLORREF>(bgRaw);
        COLORREF fgRef = 0x00FFFFFF;
        if (fg_it != args->end()) {
          int64_t fgRaw = 0;
          if (GetInt(fg_it->second, &fgRaw)) {
            fgRef = static_cast<COLORREF>(fgRaw);
          }
        }
        SetCaptionColor(hwnd, bgRef, fgRef);
      }
    }

    result->Success();
  } else {
    result->NotImplemented();
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
    case WM_COPYDATA: {
      // A second Atlas instance handed us a document to open. The payload is
      // only valid for the duration of this call, so copy it out immediately
      // before forwarding it to Dart.
      const auto* data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
      if (data != nullptr && data->cbData > 0 && data->lpData != nullptr) {
        const auto* bytes = static_cast<const char*>(data->lpData);
        std::string path(bytes, data->cbData - 1);
        if (!path.empty() && file_open_channel_ != nullptr) {
          file_open_channel_->InvokeMethod(
              "onFileOpened",
              std::make_unique<flutter::EncodableValue>(path));
        }
      }
      return TRUE;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
