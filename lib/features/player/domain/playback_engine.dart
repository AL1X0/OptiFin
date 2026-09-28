import 'package:flutter/widgets.dart';

/// Interface unique des moteurs de lecture (libmpv, AVPlayer, Media3).
///
/// L'UI du lecteur ne connaît que ce contrat : elle lit [snapshots], envoie des
/// commandes et affiche [buildView]. Chaque moteur déclare ses [capabilities]
/// et l'UI masque ce qui n'est pas supporté.
abstract interface class PlaybackEngine {
  /// Identifiant lisible (overlay de debug) : « mpv », « AVPlayer », « Media3 ».
  String get name;

  EngineCapabilities get capabilities;

  /// État courant (dernière valeur de [snapshots]).
  PlayerSnapshot get snapshot;

  /// Flux d'états, émis à chaque changement significatif.
  Stream<PlayerSnapshot> get snapshots;

  /// Événements ponctuels (fin de lecture, erreur fatale, changement de piste).
  Stream<PlaybackEvent> get events;

  /// Ouvre un média et démarre la lecture à `request.start`.
  Future<void> open(EngineMedia media);

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);

  /// Sélectionne une piste audio embarquée par son index **parmi les pistes audio**
  /// du fichier (0 = première), ou null pour la piste par défaut.
  Future<void> selectAudio(int? ordinal);

  /// Sélectionne un sous-titre embarqué (index parmi les sous-titres), ou null = aucun.
  Future<void> selectSubtitle(int? ordinal);

  /// Charge et sélectionne un sous-titre externe (URL servie par Jellyfin).
  Future<void> addExternalSubtitle(Uri url, {String? title, String? language});

  Future<void> setSubtitleStyle(SubtitleStyle style);
  Future<void> setSubtitleDelay(Duration delay);
  Future<void> setAudioDelay(Duration delay);

  /// Passe en Picture-in-Picture (si [EngineCapabilities.pictureInPicture]). false si refusé.
  Future<bool> enterPictureInPicture();

  /// Surface vidéo. [fit] : contain (défaut) / cover (zoom) / fill (étirer).
  Widget buildView({BoxFit fit = BoxFit.contain});

  Future<void> dispose();
}

/// Ce que sait faire un moteur : l'UI et l'EngineSelector s'y adaptent.
class EngineCapabilities {
  const EngineCapabilities({
    this.pictureInPicture = false,
    this.airPlay = false,
    this.hdr = false,
    this.dolbyVision = false,
    this.assRendering = false,
    this.bitmapSubtitles = false,
    this.externalSubtitles = true,
    this.subtitleStyling = false,
    this.subtitleDelay = false,
    this.audioDelay = false,
    this.playbackSpeed = true,
    this.embeddedTrackSwitching = true,
    this.embeddedSubtitles = true,
  });

  final bool pictureInPicture;
  final bool airPlay;
  final bool hdr;
  final bool dolbyVision;

  /// Rendu fidèle des sous-titres ASS/SSA (styles, positions).
  final bool assRendering;

  /// Sous-titres image (PGS, VobSub, DVB).
  final bool bitmapSubtitles;
  final bool externalSubtitles;
  final bool subtitleStyling;
  final bool subtitleDelay;
  final bool audioDelay;
  final bool playbackSpeed;

  /// Changement de piste sans recharger le flux (lecture directe uniquement).
  final bool embeddedTrackSwitching;

  /// Rendu des sous-titres intégrés au fichier. Sinon (lecteurs natifs), le texte
  /// est demandé au serveur en WebVTT et dessiné par OptiFin.
  final bool embeddedSubtitles;
}

enum PlaybackStatus { idle, loading, ready, ended, error }

class PlayerSnapshot {
  const PlayerSnapshot({
    this.status = PlaybackStatus.idle,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.rate = 1,
    this.videoSize,
    this.error,
    this.droppedFrames,
  });

  final PlaybackStatus status;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final double rate;
  final Size? videoSize;
  final String? error;

  /// Images perdues depuis l'ouverture (overlay de debug), si le moteur le mesure.
  final int? droppedFrames;

  PlayerSnapshot copyWith({
    PlaybackStatus? status,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    double? rate,
    Size? videoSize,
    String? error,
    int? droppedFrames,
  }) => PlayerSnapshot(
    status: status ?? this.status,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffered: buffered ?? this.buffered,
    rate: rate ?? this.rate,
    videoSize: videoSize ?? this.videoSize,
    error: error ?? this.error,
    droppedFrames: droppedFrames ?? this.droppedFrames,
  );
}

sealed class PlaybackEvent {
  const PlaybackEvent();
}

class PlaybackCompleted extends PlaybackEvent {
  const PlaybackCompleted();
}

class PlaybackFailed extends PlaybackEvent {
  const PlaybackFailed(this.message, {this.duringStartup = false});

  final String message;

  /// Échec avant la première image : déclenche la bascule automatique (phase 4).
  final bool duringStartup;
}

/// Ce que le moteur doit ouvrir. Le contrôleur a déjà résolu URL et pistes.
class EngineMedia {
  const EngineMedia({
    required this.url,
    this.headers = const {},
    this.start = Duration.zero,
    this.audioOrdinal,
    this.subtitleOrdinal,
    this.externalSubtitle,
    this.title,
  });

  final Uri url;
  final Map<String, String> headers;
  final Duration start;

  /// Pistes à sélectionner à l'ouverture (index par type, cf. [PlaybackEngine.selectAudio]).
  final int? audioOrdinal;
  final int? subtitleOrdinal;
  final ExternalSubtitle? externalSubtitle;
  final String? title;
}

class ExternalSubtitle {
  const ExternalSubtitle({required this.url, this.title, this.language});

  final Uri url;
  final String? title;
  final String? language;
}

/// Style des sous-titres (appliqué par les moteurs qui le supportent).
class SubtitleStyle {
  const SubtitleStyle({
    this.scale = 1,
    this.color = const Color(0xFFFFFFFF),
    this.background = SubtitleBackground.none,
    this.bottomMargin = 0.06,
  });

  /// Taille relative (1 = défaut, 0.6 → 2).
  final double scale;
  final Color color;
  final SubtitleBackground background;

  /// Distance au bas de l'image (fraction de la hauteur).
  final double bottomMargin;

  SubtitleStyle copyWith({double? scale, Color? color, SubtitleBackground? background, double? bottomMargin}) =>
      SubtitleStyle(
        scale: scale ?? this.scale,
        color: color ?? this.color,
        background: background ?? this.background,
        bottomMargin: bottomMargin ?? this.bottomMargin,
      );
}

enum SubtitleBackground { none, shadow, box }

/// Moteur dont la vue vidéo sait dessiner elle-même le verre des commandes
/// (iOS : Liquid Glass natif dans la vue AVPlayer, voir `NativeGlassScope`).
abstract interface class NativeGlassHost {
  /// false : pas de verre natif sur cette plateforme (Android).
  bool get nativeGlass;

  /// Formes de verre à dessiner (`{id, x, y, w, h, r, visible}`, repère de la vue vidéo).
  void setGlass(List<Map<String, Object>> items);
}
