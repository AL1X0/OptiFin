#include "include/optifin_native_player/optifin_native_player_plugin_c_api.h"

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <map>
#include <memory>

#include "capabilities_probe.h"
#include "media_session.h"
#include "mpv_player.h"

namespace optifin {

// Plugin Windows : lecteurs libmpv (fenêtres vidéo sous la vue Flutter).
//
// Canal `optifin_native_player` : `mpvCreate` → identifiant du lecteur. Les autres
// méthodes (capacités des lecteurs natifs, PiP…) n'existent pas sur Windows : le Dart
// retombe alors sur ses valeurs par défaut.
class OptifinNativePlayerPlugin : public flutter::Plugin {
 public:
  explicit OptifinNativePlayerPlugin(flutter::PluginRegistrarWindows* registrar) : registrar_(registrar) {
    channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(), "optifin_native_player", &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler([this](const auto& call, auto result) { HandleCall(call, std::move(result)); });
    // Boutons multimédias (clavier, Windows, vignette de la barre des tâches) → Dart.
    media_ = std::make_unique<MediaSession>([this](const std::string& button) {
      if (buttons_sink_) buttons_sink_->Success(flutter::EncodableValue(button));
    });
    buttons_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
        registrar->messenger(), "optifin_native_player/media_buttons", &flutter::StandardMethodCodec::GetInstance());
    buttons_->SetStreamHandler(std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
        [this](const flutter::EncodableValue*, std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& sink)
            -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
          buttons_sink_ = std::move(sink);
          return nullptr;
        },
        [this](const flutter::EncodableValue*) -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
          buttons_sink_ = nullptr;
          return nullptr;
        }));
    // Fenêtre redimensionnée : les vidéos suivent.
    window_proc_ = registrar->RegisterTopLevelWindowProcDelegate(
        [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) -> std::optional<LRESULT> {
          if (message == WM_SIZE) {
            for (auto& [id, player] : players_) player->Layout();
          }
          return media_->HandleWindowMessage(hwnd, message, wparam, lparam);
        });
  }

  ~OptifinNativePlayerPlugin() override { registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_); }

 private:
  void HandleCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() == "mpvCreate") {
      // Fenêtre principale : parent de la vue Flutter.
      HWND view = registrar_->GetView() ? registrar_->GetView()->GetNativeWindow() : nullptr;
      HWND parent = view ? GetAncestor(view, GA_PARENT) : nullptr;
      if (!parent) return result->Error("window", "fenêtre principale introuvable");
      // Un lecteur à la fois : l'ancien (s'il reste) est libéré.
      players_.clear();
      const int id = next_id_++;
      auto player = std::make_unique<MpvPlayer>(registrar_, id, parent);
      std::string error;
      if (!player->Initialize(&error)) return result->Error("mpv", error);
      players_[id] = std::move(player);
      return result->Success(flutter::EncodableValue(id));
    }
    if (call.method_name() == "capabilities") {
      // Mesuré à la première lecture (quelques millisecondes), puis gardé côté Dart.
      return result->Success(flutter::EncodableValue(ProbeCapabilities()));
    }
    if (call.method_name() == "mediaSession") {
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      if (!args) return result->Error("args", "arguments manquants");
      auto str = [&](const char* key) {
        auto it = args->find(flutter::EncodableValue(key));
        const auto* v = it == args->end() ? nullptr : std::get_if<std::string>(&it->second);
        return v ? *v : std::string();
      };
      auto num = [&](const char* key) {
        auto it = args->find(flutter::EncodableValue(key));
        const auto* v = it == args->end() ? nullptr : std::get_if<double>(&it->second);
        return v ? *v : 0.0;
      };
      auto flag = [&](const char* key) {
        auto it = args->find(flutter::EncodableValue(key));
        const auto* v = it == args->end() ? nullptr : std::get_if<bool>(&it->second);
        return v && *v;
      };
      if (HWND window = TopLevel()) media_->Attach(window);
      media_->Update(str("title"), str("subtitle"), str("artwork"), flag("playing"), num("position"),
                     num("duration"), flag("hasNext"));
      return result->Success();
    }
    if (call.method_name() == "mediaSessionClear") {
      media_->Clear();
      return result->Success();
    }
    if (call.method_name() == "setFullscreen") {
      const auto* enabled = std::get_if<bool>(call.arguments());
      SetFullscreen(enabled && *enabled);
      return result->Success();
    }
    if (call.method_name() == "isFullscreen") {
      return result->Success(flutter::EncodableValue(fullscreen_));
    }
    if (call.method_name() == "keepAwake") {
      // Pas de mise en veille ni d'écran éteint pendant la lecture.
      const auto* enabled = std::get_if<bool>(call.arguments());
      SetThreadExecutionState(enabled && *enabled ? ES_CONTINUOUS | ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED
                                                  : ES_CONTINUOUS);
      return result->Success();
    }
    result->NotImplemented();
  }

  HWND TopLevel() {
    HWND view = registrar_->GetView() ? registrar_->GetView()->GetNativeWindow() : nullptr;
    return view ? GetAncestor(view, GA_ROOT) : nullptr;
  }

  // Plein écran « fenêtre sans bordure » sur l'écran courant (le HDR de Windows reste actif,
  // pas de changement de mode d'affichage) ; la taille et la position sont restaurées ensuite.
  void SetFullscreen(bool enabled) {
    HWND window = TopLevel();
    if (!window || enabled == fullscreen_) return;
    if (enabled) {
      saved_style_ = GetWindowLongPtr(window, GWL_STYLE);
      saved_placement_.length = sizeof(saved_placement_);
      GetWindowPlacement(window, &saved_placement_);
      MONITORINFO monitor{sizeof(monitor)};
      GetMonitorInfo(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST), &monitor);
      SetWindowLongPtr(window, GWL_STYLE, saved_style_ & ~WS_OVERLAPPEDWINDOW);
      const RECT& r = monitor.rcMonitor;
      SetWindowPos(window, HWND_TOP, r.left, r.top, r.right - r.left, r.bottom - r.top,
                   SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    } else {
      SetWindowLongPtr(window, GWL_STYLE, saved_style_);
      SetWindowPlacement(window, &saved_placement_);
      SetWindowPos(window, nullptr, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    }
    fullscreen_ = enabled;
  }

  std::unique_ptr<MediaSession> media_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> buttons_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> buttons_sink_;
  bool fullscreen_ = false;
  LONG_PTR saved_style_ = 0;
  WINDOWPLACEMENT saved_placement_{};

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::map<int, std::unique_ptr<MpvPlayer>> players_;
  int next_id_ = 1;
  int window_proc_ = 0;
};

}  // namespace optifin

void OptifinNativePlayerPluginCApiRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  auto* windows = flutter::PluginRegistrarManager::GetInstance()->GetRegistrar<flutter::PluginRegistrarWindows>(
      registrar);
  windows->AddPlugin(std::make_unique<optifin::OptifinNativePlayerPlugin>(windows));
}
