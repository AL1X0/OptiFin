#ifndef OPTIFIN_MPV_PLAYER_H_
#define OPTIFIN_MPV_PLAYER_H_

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include <memory>
#include <string>
#include <vector>

struct mpv_handle;

namespace optifin {

// Un lecteur libmpv (Windows) piloté depuis Dart.
//
// La vidéo est dessinée par mpv (gpu-next, Direct3D 11, décodage matériel, HDR transmis
// à l'écran) dans sa propre fenêtre enfant, placée SOUS la vue Flutter : l'interface
// d'OptiFin, transparente là où passe la vidéo, se superpose par DirectComposition.
//
// Commandes sur `optifin_native_player/mpv_<id>`, événements sur
// `optifin_native_player/mpv_events_<id>` : `prop` (propriétés observées), `file-loaded`,
// `end-file`, `log`.
class MpvPlayer {
 public:
  MpvPlayer(flutter::PluginRegistrarWindows* registrar, int id, HWND parent);
  ~MpvPlayer();

  bool Initialize(std::string* error);

  // Ajuste la fenêtre vidéo à la zone cliente de la fenêtre principale.
  void Layout();
  HWND hwnd() const { return hwnd_; }

 private:
  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);
  static void OnWakeup(void* self);

  void DrainEvents();
  void Send(flutter::EncodableMap event);
  void HandleCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Show(bool visible);
  void Destroy();

  flutter::PluginRegistrarWindows* registrar_;
  const int id_;
  HWND parent_;
  HWND hwnd_ = nullptr;
  mpv_handle* mpv_ = nullptr;
  bool visible_ = false;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> events_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  std::vector<flutter::EncodableMap> pending_;
};

// Chargement dynamique de libmpv-2.dll (une seule fois par processus).
bool LoadLibmpv(std::string* error);

}  // namespace optifin

#endif  // OPTIFIN_MPV_PLAYER_H_
