#include "flutter_window.h"

#include <optional>

namespace {

constexpr wchar_t kPlacementKey[] = L"Software\\OptiFin";
constexpr wchar_t kPlacementValue[] = L"WindowPlacement";

// Taille minimale (pixels logiques) : en dessous, la mise en page bureau n'a plus de sens.
constexpr int kMinWidth = 960;
constexpr int kMinHeight = 600;

}  // namespace

#include "flutter/generated_plugin_registrant.h"

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

  const bool maximized = RestorePlacement();
  flutter_controller_->engine()->SetNextFrameCallback([this, maximized]() {
    ShowWindow(GetHandle(), maximized ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL);
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
    case WM_GETMINMAXINFO: {
      const double scale = FlutterDesktopGetDpiForHWND(hwnd) / 96.0;
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      info->ptMinTrackSize.x = static_cast<LONG>(kMinWidth * scale);
      info->ptMinTrackSize.y = static_cast<LONG>(kMinHeight * scale);
      return 0;
    }
    case WM_CLOSE:
      SavePlacement();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

bool FlutterWindow::RestorePlacement() {
  WINDOWPLACEMENT placement{};
  DWORD size = sizeof(placement);
  if (RegGetValue(HKEY_CURRENT_USER, kPlacementKey, kPlacementValue, RRF_RT_REG_BINARY,
                  nullptr, &placement, &size) != ERROR_SUCCESS ||
      size != sizeof(placement) || placement.length != sizeof(placement)) {
    return false;
  }
  // Écran débranché depuis : on garde la position par défaut.
  if (!MonitorFromRect(&placement.rcNormalPosition, MONITOR_DEFAULTTONULL)) return false;
  const bool maximized = placement.showCmd == SW_SHOWMAXIMIZED;
  placement.showCmd = SW_HIDE;
  SetWindowPlacement(GetHandle(), &placement);
  return maximized;
}

void FlutterWindow::SavePlacement() {
  WINDOWPLACEMENT placement{};
  placement.length = sizeof(placement);
  if (!GetWindowPlacement(GetHandle(), &placement)) return;
  if (placement.showCmd == SW_SHOWMINIMIZED) placement.showCmd = SW_SHOWNORMAL;
  RegSetKeyValue(HKEY_CURRENT_USER, kPlacementKey, kPlacementValue, REG_BINARY, &placement,
                 sizeof(placement));
}
