# optifin_native_player

Plugin maison des lecteurs natifs d'OptiFin (phase 4) :

- **iOS** — `AVPlayer` + `AVPlayerLayer` exposé en `UiKitView` (PiP, AirPlay, HDR10, Dolby Vision).
- **Android** — Media3 / ExoPlayer + `SurfaceView` exposé en `AndroidView` (HDR, PiP), extension FFmpeg audio si nécessaire.

L'app ne l'utilise jamais directement : `NativeEngine` (lib/features/player/data/engines/)
l'adapte à l'interface `PlaybackEngine`. État actuel : squelette généré, implémenté en phase 4.
