#include "mpv_player.h"

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <dwmapi.h>

#include <iterator>

// libmpv chargée à l'exécution : les fonctions mpv_* deviennent des pointeurs (pfn_mpv_*),
// renseignés par LoadLibmpv. Aucune bibliothèque d'import à lier.
#define MPV_CPLUGIN_DYNAMIC_SYM
#include <mpv/client.h>

namespace optifin {

namespace {

constexpr wchar_t kVideoClass[] = L"OptiFinVideo";
constexpr wchar_t kSettingsKey[] = L"Software\\OptiFin";
constexpr wchar_t kLayoutValue[] = L"VideoLayout";

int ReadLayoutMode() {
  DWORD value = 1;
  DWORD size = sizeof(value);
  if (RegGetValueW(HKEY_CURRENT_USER, kSettingsKey, kLayoutValue, RRF_RT_REG_DWORD, nullptr, &value, &size) !=
      ERROR_SUCCESS) {
    return 1;
  }
  return value < 3 ? static_cast<int>(value) : 1;
}

void WriteLayoutMode(int mode) {
  const DWORD value = static_cast<DWORD>(mode);
  RegSetKeyValueW(HKEY_CURRENT_USER, kSettingsKey, kLayoutValue, REG_DWORD, &value, sizeof(value));
}
constexpr UINT kWakeup = WM_APP + 0x4F;

HMODULE g_libmpv = nullptr;

// Propriétés suivies (identifiant = rang), toutes lues en double ou en booléen.
struct Observed {
  const char* name;
  mpv_format format;
};
constexpr Observed kObserved[] = {
    {"time-pos", MPV_FORMAT_DOUBLE},       {"duration", MPV_FORMAT_DOUBLE},
    {"pause", MPV_FORMAT_FLAG},            {"paused-for-cache", MPV_FORMAT_FLAG},
    {"seeking", MPV_FORMAT_FLAG},          {"eof-reached", MPV_FORMAT_FLAG},
    {"demuxer-cache-time", MPV_FORMAT_DOUBLE}, {"speed", MPV_FORMAT_DOUBLE},
    {"dwidth", MPV_FORMAT_DOUBLE},         {"dheight", MPV_FORMAT_DOUBLE},
    {"core-idle", MPV_FORMAT_FLAG},
};

const std::string* StringArg(const flutter::EncodableMap& args, const char* key) {
  auto it = args.find(flutter::EncodableValue(key));
  return it == args.end() ? nullptr : std::get_if<std::string>(&it->second);
}

}  // namespace

bool LoadLibmpv(std::string* error) {
  if (pfn_mpv_create) return true;
  // À côté de l'exécutable (installée par le plugin).
  wchar_t exe[MAX_PATH];
  GetModuleFileNameW(nullptr, exe, MAX_PATH);
  std::wstring dir(exe);
  dir = dir.substr(0, dir.find_last_of(L"\\/") + 1);
  g_libmpv = LoadLibraryExW((dir + L"libmpv-2.dll").c_str(), nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
  if (!g_libmpv) {
    *error = "libmpv-2.dll introuvable (erreur " + std::to_string(GetLastError()) + ")";
    return false;
  }
#define OPTIFIN_MPV_SYM(name)                                                   \
  pfn_##name = reinterpret_cast<decltype(pfn_##name)>(GetProcAddress(g_libmpv, #name)); \
  if (!pfn_##name) {                                                           \
    *error = "libmpv incomplète : " #name;                                     \
    return false;                                                              \
  }
  OPTIFIN_MPV_SYM(mpv_client_api_version)
  OPTIFIN_MPV_SYM(mpv_error_string)
  OPTIFIN_MPV_SYM(mpv_free)
  OPTIFIN_MPV_SYM(mpv_create)
  OPTIFIN_MPV_SYM(mpv_initialize)
  OPTIFIN_MPV_SYM(mpv_terminate_destroy)
  OPTIFIN_MPV_SYM(mpv_set_option_string)
  OPTIFIN_MPV_SYM(mpv_command)
  OPTIFIN_MPV_SYM(mpv_set_property_string)
  OPTIFIN_MPV_SYM(mpv_get_property_string)
  OPTIFIN_MPV_SYM(mpv_observe_property)
  OPTIFIN_MPV_SYM(mpv_request_log_messages)
  OPTIFIN_MPV_SYM(mpv_wait_event)
  OPTIFIN_MPV_SYM(mpv_set_wakeup_callback)
#undef OPTIFIN_MPV_SYM
  return true;
}

// ------------------------------------------------------------------ Cycle de vie

MpvPlayer::MpvPlayer(flutter::PluginRegistrarWindows* registrar, int id, HWND parent)
    : registrar_(registrar), id_(id), parent_(parent) {}

MpvPlayer::~MpvPlayer() { Destroy(); }

bool MpvPlayer::Initialize(std::string* error) {
  if (!LoadLibmpv(error)) return false;

  static bool registered = false;
  if (!registered) {
    WNDCLASSW wc{};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = GetModuleHandle(nullptr);
    wc.lpszClassName = kVideoClass;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    RegisterClassW(&wc);
    registered = true;
  }
  // Fenêtre enfant masquée jusqu'à la première image, sous toutes ses sœurs (la vue Flutter).
  mode_ = ReadLayoutMode();
  hwnd_ = CreateWindowExW(WS_EX_NOPARENTNOTIFY, kVideoClass, L"", WS_CHILD, 0, 0, 0, 0, parent_, nullptr,
                          GetModuleHandle(nullptr), nullptr);
  if (!hwnd_) {
    *error = "fenêtre vidéo impossible à créer";
    return false;
  }
  SetWindowLongPtr(hwnd_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
  ApplyMode();

  mpv_ = mpv_create();
  if (!mpv_) {
    *error = "mpv_create a échoué";
    return false;
  }
  const std::string wid = std::to_string(reinterpret_cast<intptr_t>(hwnd_));
  auto set = [this](const char* name, const char* value) { mpv_set_option_string(mpv_, name, value); };
  set("wid", wid.c_str());
  // Rendu moderne (libplacebo) sur Direct3D 11 ; HDR et Dolby Vision transmis à l'écran
  // quand Windows est en HDR, sinon convertis proprement en SDR.
  set("vo", "gpu-next");
  set("gpu-api", "d3d11");
  set("gpu-context", "d3d11");
  set("hwdec", "auto-safe");
  set("target-colorspace-hint", "yes");
  set("video-sync", "display-resample");
  // Lecteur piloté par OptiFin : ni raccourcis, ni affichage à l'écran, ni fichiers annexes.
  set("input-default-bindings", "no");
  set("input-vo-keyboard", "no");
  set("input-cursor", "no");
  set("cursor-autohide", "no");
  set("osc", "no");
  set("osd-level", "0");
  set("idle", "yes");
  set("keep-open", "no");
  set("force-window", "no");
  set("sub-auto", "no");
  set("audio-file-auto", "no");
  set("ytdl", "no");
  set("load-scripts", "no");
  set("config", "no");
  set("terminal", "no");
  // Tampon généreux (réseau domestique, fichiers 4K à haut débit).
  set("cache", "yes");
  set("demuxer-max-bytes", "256MiB");
  set("demuxer-max-back-bytes", "64MiB");
  set("demuxer-readahead-secs", "30");
  // Sous-titres : styles ASS conservés, taille réglable.
  set("sub-ass-override", "scale");
  set("sub-font", "Segoe UI");
  set("sub-use-margins", "no");
  const int rc = mpv_initialize(mpv_);
  if (rc < 0) {
    *error = std::string("mpv_initialize : ") + mpv_error_string(rc);
    return false;
  }
  mpv_request_log_messages(mpv_, "warn");
  for (uint64_t i = 0; i < std::size(kObserved); i++) {
    mpv_observe_property(mpv_, i, kObserved[i].name, kObserved[i].format);
  }

  const std::string base = "optifin_native_player/mpv_" + std::to_string(id_);
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar_->messenger(), base, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) { HandleCall(call, std::move(result)); });

  events_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      registrar_->messenger(), "optifin_native_player/mpv_events_" + std::to_string(id_),
      &flutter::StandardMethodCodec::GetInstance());
  events_->SetStreamHandler(std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [this](const flutter::EncodableValue*, std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& sink)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        sink_ = std::move(sink);
        for (auto& e : pending_) sink_->Success(flutter::EncodableValue(e));
        pending_.clear();
        return nullptr;
      },
      [this](const flutter::EncodableValue*) -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        sink_ = nullptr;
        return nullptr;
      }));

  // Réveil de mpv (depuis ses threads) → message traité sur le thread de la plateforme.
  mpv_set_wakeup_callback(mpv_, &MpvPlayer::OnWakeup, this);
  return true;
}

void MpvPlayer::Destroy() {
  if (mpv_) {
    mpv_set_wakeup_callback(mpv_, nullptr, nullptr);
    mpv_terminate_destroy(mpv_);
    mpv_ = nullptr;
  }
  if (channel_) channel_->SetMethodCallHandler(nullptr);
  if (events_) events_->SetStreamHandler(nullptr);
  sink_ = nullptr;
  if (hwnd_) {
    SetWindowLongPtr(hwnd_, GWLP_USERDATA, 0);
    DestroyWindow(hwnd_);
    hwnd_ = nullptr;
  }
  if (popup_) {
    DestroyWindow(popup_);
    popup_ = nullptr;
  }
  SetMainTransparent(false);
}

void MpvPlayer::SetMainTransparent(bool transparent) {
  // Cadre DWM étendu à toute la fenêtre : là où Flutter ne peint rien, on voit ce qui est dessous.
  const int m = transparent ? -1 : 0;
  MARGINS margins{m, m, m, m};
  DwmExtendFrameIntoClientArea(parent_, &margins);
}

void MpvPlayer::SetLayoutMode(int mode) {
  mode_ = ((mode % kLayoutModes) + kLayoutModes) % kLayoutModes;
  WriteLayoutMode(mode_);
  ApplyMode();
}

void MpvPlayer::ApplyMode() {
  if (!hwnd_) return;
  LONG_PTR style = GetWindowLongPtr(hwnd_, GWL_STYLE);
  style = mode_ == 0 ? (style | WS_CLIPSIBLINGS) : (style & ~WS_CLIPSIBLINGS);
  SetWindowLongPtr(hwnd_, GWL_STYLE, style);
  if (mode_ == 2) {
    if (!popup_) {
      // Fenêtre sans bordure, hors barre des tâches, jamais active : la fenêtre principale garde
      // le clavier et la souris.
      popup_ = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, kVideoClass, L"OptiFin vidéo", WS_POPUP, 0, 0,
                               0, 0, nullptr, nullptr, GetModuleHandle(nullptr), nullptr);
    }
    SetParent(hwnd_, popup_);
  } else {
    SetParent(hwnd_, parent_);
    if (popup_) {
      DestroyWindow(popup_);
      popup_ = nullptr;
    }
  }
  SetMainTransparent(mode_ != 0);
  Layout();
  if (visible_) {
    ShowWindow(hwnd_, SW_SHOWNOACTIVATE);
    if (popup_) ShowWindow(popup_, SW_SHOWNOACTIVATE);
  }
}

void MpvPlayer::Layout() {
  if (!hwnd_) return;
  RECT rc;
  GetClientRect(parent_, &rc);
  const int w = rc.right - rc.left;
  const int h = rc.bottom - rc.top;
  if (mode_ == 2 && popup_) {
    // Juste derrière la fenêtre principale, sur sa zone cliente ; masquée si elle est réduite.
    POINT origin{0, 0};
    ClientToScreen(parent_, &origin);
    const bool shown = visible_ && !IsIconic(parent_);
    SetWindowPos(popup_, parent_, origin.x, origin.y, w, h,
                 SWP_NOACTIVATE | (shown ? SWP_SHOWWINDOW : SWP_HIDEWINDOW));
    SetWindowPos(hwnd_, nullptr, 0, 0, w, h, SWP_NOACTIVATE | SWP_NOZORDER);
  } else {
    SetWindowPos(hwnd_, HWND_BOTTOM, 0, 0, w, h, SWP_NOACTIVATE);
  }
}

void MpvPlayer::Show(bool visible) {
  if (!hwnd_ || visible == visible_) return;
  visible_ = visible;
  Layout();
  ShowWindow(hwnd_, visible ? SW_SHOWNOACTIVATE : SW_HIDE);
  if (popup_) ShowWindow(popup_, visible ? SW_SHOWNOACTIVATE : SW_HIDE);
}

// ------------------------------------------------------------------ Événements

void MpvPlayer::OnWakeup(void* self) {
  auto* player = static_cast<MpvPlayer*>(self);
  PostMessage(player->hwnd_, kWakeup, 0, 0);
}

LRESULT CALLBACK MpvPlayer::WndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
  switch (msg) {
    case kWakeup: {
      auto* player = reinterpret_cast<MpvPlayer*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
      if (player) player->DrainEvents();
      return 0;
    }
    case WM_ERASEBKGND: {
      RECT rc;
      GetClientRect(hwnd, &rc);
      FillRect(reinterpret_cast<HDC>(wparam), &rc, static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH)));
      return 1;
    }
    case WM_NCHITTEST:
      // Souris et clavier restent à Flutter (contrôles au-dessus).
      return HTTRANSPARENT;
  }
  return DefWindowProc(hwnd, msg, wparam, lparam);
}

void MpvPlayer::Send(flutter::EncodableMap event) {
  if (sink_) {
    sink_->Success(flutter::EncodableValue(std::move(event)));
  } else {
    pending_.push_back(std::move(event));
  }
}

void MpvPlayer::DrainEvents() {
  using flutter::EncodableMap;
  using flutter::EncodableValue;
  while (mpv_) {
    mpv_event* e = mpv_wait_event(mpv_, 0);
    if (!e || e->event_id == MPV_EVENT_NONE) break;
    switch (e->event_id) {
      case MPV_EVENT_PROPERTY_CHANGE: {
        auto* p = static_cast<mpv_event_property*>(e->data);
        EncodableValue value;
        if (p->format == MPV_FORMAT_DOUBLE && p->data) value = EncodableValue(*static_cast<double*>(p->data));
        if (p->format == MPV_FORMAT_FLAG && p->data) value = EncodableValue(*static_cast<int*>(p->data) != 0);
        Send(EncodableMap{{EncodableValue("event"), EncodableValue("prop")},
                          {EncodableValue("name"), EncodableValue(p->name)},
                          {EncodableValue("value"), value}});
        break;
      }
      case MPV_EVENT_FILE_LOADED:
        Send(EncodableMap{{EncodableValue("event"), EncodableValue("file-loaded")}});
        break;
      case MPV_EVENT_VIDEO_RECONFIG:
        // Première image : la fenêtre vidéo apparaît sous l'interface.
        Show(true);
        break;
      case MPV_EVENT_END_FILE: {
        auto* end = static_cast<mpv_event_end_file*>(e->data);
        const char* reason = end->reason == MPV_END_FILE_REASON_EOF     ? "eof"
                             : end->reason == MPV_END_FILE_REASON_ERROR ? "error"
                                                                        : "stop";
        EncodableMap m{{EncodableValue("event"), EncodableValue("end-file")},
                       {EncodableValue("reason"), EncodableValue(reason)}};
        if (end->reason == MPV_END_FILE_REASON_ERROR) {
          m[EncodableValue("error")] = EncodableValue(mpv_error_string(end->error));
        }
        Send(std::move(m));
        break;
      }
      case MPV_EVENT_LOG_MESSAGE: {
        auto* log = static_cast<mpv_event_log_message*>(e->data);
        std::string text = log->text ? log->text : "";
        while (!text.empty() && (text.back() == '\n' || text.back() == '\r')) text.pop_back();
        Send(EncodableMap{{EncodableValue("event"), EncodableValue("log")},
                          {EncodableValue("level"), EncodableValue(log->level)},
                          {EncodableValue("prefix"), EncodableValue(log->prefix)},
                          {EncodableValue("text"), EncodableValue(text)}});
        break;
      }
      case MPV_EVENT_SHUTDOWN:
        return;
      default:
        break;
    }
  }
}

// ------------------------------------------------------------------ Commandes

void MpvPlayer::HandleCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = call.method_name();
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  if (!mpv_) return result->Error("disposed", "lecteur libéré");

  if (method == "command" && args) {
    // Liste d'arguments mpv (ex. ["loadfile", url, "replace", "0", "start=12"]).
    auto it = args->find(flutter::EncodableValue("args"));
    const auto* list = it == args->end() ? nullptr : std::get_if<flutter::EncodableList>(&it->second);
    if (!list) return result->Error("args", "arguments manquants");
    std::vector<std::string> strings;
    for (const auto& v : *list) {
      const auto* s = std::get_if<std::string>(&v);
      strings.push_back(s ? *s : "");
    }
    std::vector<const char*> argv;
    for (const auto& s : strings) argv.push_back(s.c_str());
    argv.push_back(nullptr);
    const int rc = mpv_command(mpv_, argv.data());
    if (rc < 0) return result->Error("mpv", mpv_error_string(rc));
    return result->Success();
  }
  if (method == "setProperty" && args) {
    const auto* name = StringArg(*args, "name");
    const auto* value = StringArg(*args, "value");
    if (!name || !value) return result->Error("args", "nom ou valeur manquant");
    const int rc = mpv_set_property_string(mpv_, name->c_str(), value->c_str());
    if (rc < 0) return result->Error("mpv", std::string(*name) + " : " + mpv_error_string(rc));
    return result->Success();
  }
  if (method == "getProperty" && args) {
    const auto* name = StringArg(*args, "name");
    if (!name) return result->Error("args", "nom manquant");
    char* value = mpv_get_property_string(mpv_, name->c_str());
    if (!value) return result->Success();
    std::string out(value);
    mpv_free(value);
    return result->Success(flutter::EncodableValue(out));
  }
  if (method == "setLayoutMode" && args) {
    auto it = args->find(flutter::EncodableValue("mode"));
    const auto* m = it == args->end() ? nullptr : std::get_if<int>(&it->second);
    SetLayoutMode(m ? *m : mode_ + 1);
    return result->Success(flutter::EncodableValue(mode_));
  }
  if (method == "getLayoutMode") return result->Success(flutter::EncodableValue(mode_));
  if (method == "setVisible" && args) {
    auto it = args->find(flutter::EncodableValue("visible"));
    const auto* v = it == args->end() ? nullptr : std::get_if<bool>(&it->second);
    Show(v && *v);
    return result->Success();
  }
  if (method == "dispose") {
    result->Success();
    Destroy();
    return;
  }
  result->NotImplemented();
}

}  // namespace optifin
