#include "include/optifin_native_player/optifin_native_player_plugin_c_api.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <map>
#include <memory>

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
    // Fenêtre redimensionnée : les vidéos suivent.
    window_proc_ = registrar->RegisterTopLevelWindowProcDelegate(
        [this](HWND, UINT message, WPARAM, LPARAM) -> std::optional<LRESULT> {
          if (message == WM_SIZE) {
            for (auto& [id, player] : players_) player->Layout();
          }
          return std::nullopt;
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
    result->NotImplemented();
  }

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
