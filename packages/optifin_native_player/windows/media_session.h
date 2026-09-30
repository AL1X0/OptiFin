#ifndef OPTIFIN_MEDIA_SESSION_H_
#define OPTIFIN_MEDIA_SESSION_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <optional>
#include <string>

namespace optifin {

// Intégration de la lecture à Windows :
// - contrôles multimédias du système (touches média du clavier, encart de volume et
//   centre de notifications : titre, sous-titre, affiche, lecture/pause, suivant) ;
// - barre des tâches : boutons précédent (−10 s), lecture/pause et suivant dans la
//   vignette de la fenêtre, progression de la lecture sur l'icône.
//
// Les boutons pressés remontent par [on_button] : "play", "pause", "toggle", "next",
// "back10".
class MediaSession {
 public:
  explicit MediaSession(std::function<void(const std::string&)> on_button);
  ~MediaSession();

  // Fenêtre principale (une fois connue). Sans elle, rien n'est affiché.
  void Attach(HWND window);

  // Titre, sous-titre (série, épisode), affiche (URL http(s), sans secret), état.
  void Update(const std::string& title, const std::string& subtitle, const std::string& artwork,
              bool playing, double position_s, double duration_s, bool has_next);
  void Clear();

  // Messages de la fenêtre principale (boutons de la vignette). true si traité.
  std::optional<LRESULT> HandleWindowMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace optifin

#endif  // OPTIFIN_MEDIA_SESSION_H_
