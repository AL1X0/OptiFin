#include "media_session.h"

#include <objbase.h>
#include <shobjidl.h>
#include <systemmediatransportcontrolsinterop.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Storage.Streams.h>

#include <gdiplus.h>

#pragma comment(lib, "gdiplus.lib")

namespace optifin {

namespace {

using winrt::Windows::Media::MediaPlaybackStatus;
using winrt::Windows::Media::MediaPlaybackType;
using winrt::Windows::Media::SystemMediaTransportControls;
using winrt::Windows::Media::SystemMediaTransportControlsButton;
using winrt::Windows::Media::SystemMediaTransportControlsButtonPressedEventArgs;
using winrt::Windows::Media::SystemMediaTransportControlsTimelineProperties;

constexpr UINT kBackId = 0x4F01;
constexpr UINT kPlayId = 0x4F02;
constexpr UINT kNextId = 0x4F03;

std::wstring Wide(const std::string& s) {
  if (s.empty()) return {};
  const int n = MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0);
  std::wstring out(n, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), out.data(), n);
  return out;
}

winrt::Windows::Foundation::TimeSpan Seconds(double s) {
  return std::chrono::duration_cast<winrt::Windows::Foundation::TimeSpan>(
      std::chrono::duration<double>(s < 0 ? 0 : s));
}

// Icône blanche dessinée depuis la police d'icônes de Windows (Segoe Fluent Icons sur
// Windows 11, Segoe MDL2 Assets sur Windows 10) : nette à toutes les échelles.
HICON GlyphIcon(wchar_t glyph, int size) {
  Gdiplus::Bitmap bitmap(size, size, PixelFormat32bppARGB);
  Gdiplus::Graphics g(&bitmap);
  g.Clear(Gdiplus::Color(0, 0, 0, 0));
  g.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);
  Gdiplus::FontFamily fluent(L"Segoe Fluent Icons");
  Gdiplus::FontFamily mdl2(L"Segoe MDL2 Assets");
  const Gdiplus::FontFamily* family = fluent.IsAvailable() ? &fluent : &mdl2;
  Gdiplus::Font font(family, size * 0.75f, Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
  Gdiplus::SolidBrush brush(Gdiplus::Color(255, 255, 255, 255));
  Gdiplus::StringFormat format;
  format.SetAlignment(Gdiplus::StringAlignmentCenter);
  format.SetLineAlignment(Gdiplus::StringAlignmentCenter);
  const wchar_t text[2] = {glyph, 0};
  g.DrawString(text, 1, &font, Gdiplus::RectF(0, 0, static_cast<float>(size), static_cast<float>(size)), &format,
               &brush);
  HICON icon = nullptr;
  bitmap.GetHICON(&icon);
  return icon;
}

}  // namespace

struct MediaSession::Impl {
  std::function<void(const std::string&)> on_button;
  HWND window = nullptr;
  SystemMediaTransportControls smtc{nullptr};
  winrt::event_token button_token{};
  winrt::com_ptr<ITaskbarList3> taskbar;
  UINT taskbar_created = RegisterWindowMessageW(L"TaskbarButtonCreated");
  bool buttons_added = false;
  bool playing = false;
  bool has_next = false;
  bool active = false;
  std::string artwork;
  ULONG_PTR gdiplus = 0;
  HICON back_icon = nullptr, play_icon = nullptr, pause_icon = nullptr, next_icon = nullptr;

  void EnsureTaskbar() {
    if (!window || taskbar) return;
    if (FAILED(CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(taskbar.put())))) {
      taskbar = nullptr;
      return;
    }
    if (FAILED(taskbar->HrInit())) taskbar = nullptr;
  }

  void EnsureIcons() {
    if (back_icon) return;
    const int size = GetSystemMetrics(SM_CXSMICON);
    back_icon = GlyphIcon(0xED3C, size);   // SkipBack10
    play_icon = GlyphIcon(0xE768, size);   // Play
    pause_icon = GlyphIcon(0xE769, size);  // Pause
    next_icon = GlyphIcon(0xE893, size);   // Next
  }

  THUMBBUTTON Button(UINT id, HICON icon, const wchar_t* tip, bool enabled) {
    THUMBBUTTON b{};
    b.dwMask = THB_ICON | THB_TOOLTIP | THB_FLAGS;
    b.iId = id;
    b.hIcon = icon;
    wcsncpy_s(b.szTip, tip, _TRUNCATE);
    b.dwFlags = enabled ? THBF_ENABLED : THBF_DISABLED;
    if (!active) b.dwFlags = THBF_HIDDEN;
    return b;
  }

  void UpdateThumbButtons() {
    EnsureTaskbar();
    if (!taskbar || !window) return;
    EnsureIcons();
    THUMBBUTTON buttons[3] = {
        Button(kBackId, back_icon, L"Reculer de 10 secondes", true),
        Button(kPlayId, playing ? pause_icon : play_icon, playing ? L"Pause" : L"Lecture", true),
        Button(kNextId, next_icon, L"Épisode suivant", has_next),
    };
    if (!buttons_added) {
      if (SUCCEEDED(taskbar->ThumbBarAddButtons(window, 3, buttons))) buttons_added = true;
    } else {
      taskbar->ThumbBarUpdateButtons(window, 3, buttons);
    }
  }
};

MediaSession::MediaSession(std::function<void(const std::string&)> on_button) : impl_(std::make_unique<Impl>()) {
  impl_->on_button = std::move(on_button);
  Gdiplus::GdiplusStartupInput input;
  Gdiplus::GdiplusStartup(&impl_->gdiplus, &input, nullptr);
}

MediaSession::~MediaSession() {
  Clear();
  if (impl_->smtc) impl_->smtc.ButtonPressed(impl_->button_token);
  for (HICON icon : {impl_->back_icon, impl_->play_icon, impl_->pause_icon, impl_->next_icon}) {
    if (icon) DestroyIcon(icon);
  }
  if (impl_->gdiplus) Gdiplus::GdiplusShutdown(impl_->gdiplus);
}

void MediaSession::Attach(HWND window) {
  if (impl_->window == window) return;
  impl_->window = window;
  try {
    auto interop = winrt::get_activation_factory<SystemMediaTransportControls, ISystemMediaTransportControlsInterop>();
    SystemMediaTransportControls smtc{nullptr};
    winrt::check_hresult(interop->GetForWindow(window, winrt::guid_of<SystemMediaTransportControls>(),
                                               winrt::put_abi(smtc)));
    impl_->smtc = smtc;
    impl_->smtc.IsPlayEnabled(true);
    impl_->smtc.IsPauseEnabled(true);
    impl_->smtc.IsStopEnabled(false);
    impl_->button_token = impl_->smtc.ButtonPressed(
        [this](const SystemMediaTransportControls&, const SystemMediaTransportControlsButtonPressedEventArgs& args) {
          const char* name = nullptr;
          switch (args.Button()) {
            case SystemMediaTransportControlsButton::Play: name = "play"; break;
            case SystemMediaTransportControlsButton::Pause: name = "pause"; break;
            case SystemMediaTransportControlsButton::Next: name = "next"; break;
            case SystemMediaTransportControlsButton::Previous: name = "back10"; break;
            default: break;
          }
          // Événement reçu sur un thread WinRT : renvoyé vers le thread de la fenêtre.
          if (name && impl_->window) {
            PostMessage(impl_->window, WM_APP + 0x4E, 0, reinterpret_cast<LPARAM>(name));
          }
        });
  } catch (...) {
    // Windows sans contrôles multimédias (Server Core…) : la barre des tâches suffit.
    impl_->smtc = nullptr;
  }
}

void MediaSession::Update(const std::string& title, const std::string& subtitle, const std::string& artwork,
                          bool playing, double position_s, double duration_s, bool has_next) {
  const bool changed = !impl_->active || impl_->playing != playing || impl_->has_next != has_next;
  impl_->active = true;
  impl_->playing = playing;
  impl_->has_next = has_next;
  if (impl_->smtc) {
    try {
      impl_->smtc.IsEnabled(true);
      impl_->smtc.IsNextEnabled(has_next);
      impl_->smtc.IsPreviousEnabled(true);
      impl_->smtc.PlaybackStatus(playing ? MediaPlaybackStatus::Playing : MediaPlaybackStatus::Paused);
      auto updater = impl_->smtc.DisplayUpdater();
      updater.Type(MediaPlaybackType::Video);
      updater.VideoProperties().Title(Wide(title));
      updater.VideoProperties().Subtitle(Wide(subtitle));
      if (artwork != impl_->artwork) {
        impl_->artwork = artwork;
        if (artwork.rfind("http", 0) == 0) {
          updater.Thumbnail(winrt::Windows::Storage::Streams::RandomAccessStreamReference::CreateFromUri(
              winrt::Windows::Foundation::Uri(Wide(artwork))));
        } else {
          updater.Thumbnail(nullptr);
        }
      }
      updater.Update();
      SystemMediaTransportControlsTimelineProperties timeline;
      timeline.StartTime(Seconds(0));
      timeline.MinSeekTime(Seconds(0));
      timeline.Position(Seconds(position_s));
      timeline.MaxSeekTime(Seconds(duration_s));
      timeline.EndTime(Seconds(duration_s));
      impl_->smtc.UpdateTimelineProperties(timeline);
    } catch (...) {
    }
  }
  if (impl_->window) {
    impl_->EnsureTaskbar();
    if (impl_->taskbar) {
      if (duration_s > 0) {
        impl_->taskbar->SetProgressState(impl_->window, playing ? TBPF_NORMAL : TBPF_PAUSED);
        impl_->taskbar->SetProgressValue(impl_->window, static_cast<ULONGLONG>(position_s * 1000),
                                         static_cast<ULONGLONG>(duration_s * 1000));
      }
      if (changed) impl_->UpdateThumbButtons();
    }
  }
}

void MediaSession::Clear() {
  if (!impl_->active) return;
  impl_->active = false;
  impl_->artwork.clear();
  if (impl_->smtc) {
    try {
      impl_->smtc.DisplayUpdater().ClearAll();
      impl_->smtc.PlaybackStatus(MediaPlaybackStatus::Closed);
      impl_->smtc.IsEnabled(false);
    } catch (...) {
    }
  }
  if (impl_->taskbar && impl_->window) {
    impl_->taskbar->SetProgressState(impl_->window, TBPF_NOPROGRESS);
    if (impl_->buttons_added) impl_->UpdateThumbButtons();  // boutons masqués
  }
}

std::optional<LRESULT> MediaSession::HandleWindowMessage(HWND, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == impl_->taskbar_created) {
    // Explorateur redémarré : les boutons de la vignette sont à recréer.
    impl_->taskbar = nullptr;
    impl_->buttons_added = false;
    if (impl_->active) impl_->UpdateThumbButtons();
    return std::nullopt;
  }
  if (message == WM_APP + 0x4E && lparam) {
    impl_->on_button(reinterpret_cast<const char*>(lparam));
    return 0;
  }
  if (message == WM_COMMAND && HIWORD(wparam) == THBN_CLICKED) {
    switch (LOWORD(wparam)) {
      case kBackId: impl_->on_button("back10"); return 0;
      case kPlayId: impl_->on_button("toggle"); return 0;
      case kNextId: impl_->on_button("next"); return 0;
    }
  }
  return std::nullopt;
}

}  // namespace optifin
