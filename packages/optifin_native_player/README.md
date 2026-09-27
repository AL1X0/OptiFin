# optifin_native_player

Plugin maison des lecteurs natifs d'OptiFin :

- **iOS** : `AVPlayer` + `AVPlayerLayer` exposé en `UiKitView` (HDR10, HLG, Dolby Vision ;
  base du PiP et d'AirPlay en phase 5).
- **Android** : Media3 / ExoPlayer + `PlayerView` (SurfaceView) en composition hybride (HDR ;
  base du PiP en phase 5).

API Dart (`lib/`) :

- `NativePlayers.capabilities()` : décodeurs, HDR, Dolby Vision, codecs audio, conteneurs ;
- `NativePlayers.create()` → `NativePlayer` : `open(url, headers, start, audioOrdinal)`,
  `play`, `pause`, `seek`, `setRate`, `selectAudio`, `setFit`, `dispose`, flux `events`
  (`state` toutes les 250 ms pendant la lecture, `error` avec code et cause, `completed`) ;
- `NativePlayerView(playerId)` : la surface vidéo.

Les sous-titres ne sont pas rendus par le plugin : OptiFin les dessine (WebVTT servi par Jellyfin).
L'app ne l'utilise jamais directement : `NativeEngine` (lib/features/player/data/engines/)
l'adapte à l'interface `PlaybackEngine`.
