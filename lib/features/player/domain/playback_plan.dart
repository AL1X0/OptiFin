/// Plan de lecture : ce que le serveur a accepté et comment le lire.
///
/// Construit à partir de la réponse `PlaybackInfo` ; pur et testé.
library;

enum PlayMethod {
  directPlay('DirectPlay', 'Lecture directe'),
  directStream('DirectStream', 'Remux (Direct Stream)'),
  transcode('Transcode', 'Transcodage');

  const PlayMethod(this.apiName, this.label);
  final String apiName;
  final String label;
}

enum TrackType { audio, subtitle }

/// Piste audio ou sous-titre telle que décrite par Jellyfin.
class MediaTrack {
  const MediaTrack({
    required this.index,
    required this.type,
    required this.label,
    this.language,
    this.codec,
    this.isDefault = false,
    this.isForced = false,
    this.isExternal = false,
    this.isTextBased = true,
    this.deliveryUrl,
    this.channels,
  });

  /// Index global Jellyfin (`MediaStream.Index`), identifiant stable côté serveur.
  final int index;
  final TrackType type;
  final String label;
  final String? language;
  final String? codec;
  final bool isDefault;
  final bool isForced;
  final bool isExternal;

  /// Texte (SRT, ASS, VTT…) par opposition à image (PGS, VobSub).
  final bool isTextBased;

  /// URL (relative au serveur) d'un sous-titre servi séparément.
  final String? deliveryUrl;
  final int? channels;

  bool get isAss => codec == 'ass' || codec == 'ssa';
  bool get isBitmap => !isTextBased;
}

class PlaybackPlan {
  const PlaybackPlan({
    required this.itemId,
    required this.mediaSourceId,
    required this.playSessionId,
    required this.method,
    required this.streamUrl,
    required this.audioTracks,
    required this.subtitleTracks,
    this.audioIndex,
    this.subtitleIndex,
    this.container,
    this.bitrate,
    this.videoCodec,
    this.startPosition = Duration.zero,
    this.runtime,
  });

  final String itemId;
  final String mediaSourceId;
  final String? playSessionId;
  final PlayMethod method;

  /// URL absolue du flux.
  final Uri streamUrl;
  final List<MediaTrack> audioTracks;
  final List<MediaTrack> subtitleTracks;

  /// Pistes actives (index Jellyfin). null = aucune (sous-titres) / défaut (audio).
  final int? audioIndex;
  final int? subtitleIndex;
  final String? container;
  final int? bitrate;
  final String? videoCodec;
  final Duration startPosition;
  final Duration? runtime;

  /// En lecture directe, le moteur a toutes les pistes : changement instantané.
  /// Sinon le serveur n'envoie que la piste choisie : il faut recharger le flux.
  bool get canSwitchTracksLocally => method == PlayMethod.directPlay;

  MediaTrack? get currentAudio => audioTracks.where((t) => t.index == audioIndex).firstOrNull;
  MediaTrack? get currentSubtitle => subtitleTracks.where((t) => t.index == subtitleIndex).firstOrNull;

  PlaybackPlan withTracks({int? audioIndex, int? Function()? subtitleIndex}) => PlaybackPlan(
    itemId: itemId,
    mediaSourceId: mediaSourceId,
    playSessionId: playSessionId,
    method: method,
    streamUrl: streamUrl,
    audioTracks: audioTracks,
    subtitleTracks: subtitleTracks,
    audioIndex: audioIndex ?? this.audioIndex,
    subtitleIndex: subtitleIndex != null ? subtitleIndex() : this.subtitleIndex,
    container: container,
    bitrate: bitrate,
    videoCodec: videoCodec,
    startPosition: startPosition,
    runtime: runtime,
  );
}

/// Position d'une piste embarquée **parmi les pistes du même type** du fichier,
/// telle que la numérotent les moteurs (1re piste audio = 0).
///
/// Les pistes externes n'existent pas dans le fichier : elles n'ont pas d'ordinal.
int? embeddedOrdinal(List<MediaTrack> tracks, int? index) {
  if (index == null) return null;
  final embedded = tracks.where((t) => !t.isExternal).toList()..sort((a, b) => a.index.compareTo(b.index));
  final i = embedded.indexWhere((t) => t.index == index);
  return i < 0 ? null : i;
}
