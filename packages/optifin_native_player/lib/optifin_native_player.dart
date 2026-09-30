/// Lecteurs natifs d'OptiFin : AVPlayer (iOS), Media3/ExoPlayer (Android), libmpv (Windows).
///
/// API volontairement minimale et indépendante de l'app : l'adaptation au
/// contrat `PlaybackEngine` se fait côté app (`NativeEngine`).
library;

export 'src/airplay_button.dart';
export 'src/native_player.dart';
export 'src/native_player_view.dart';
export 'src/native_glass_view.dart';
export 'src/windows_mpv.dart';
