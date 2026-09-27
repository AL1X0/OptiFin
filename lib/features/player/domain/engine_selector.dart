/// Choix du moteur de lecture et du mode de livraison, avant chaque lecture.
///
/// Logique la plus critique du lecteur : pure, déterministe, testée de façon
/// exhaustive (voir `test/features/player/engine_selector_test.dart` et la
/// matrice `docs/TEST_MATRIX.md`).
///
/// Règles, par ordre de priorité :
/// 1. **Transcodage** si le débit source dépasse la limite (ou s'il est demandé).
/// 2. Préférence explicite de l'utilisateur (Natif / mpv), si elle est possible.
/// 3. **HDR / Dolby Vision** → lecteur natif (Dolby Vision toujours), en lecture
///    directe si conteneur et audio passent, sinon **remux** serveur (vidéo copiée,
///    audio converti si besoin) plutôt que mpv. Exceptions : sous-titres image
///    (ou ASS sur du HDR10) → mpv, qui les rend fidèlement ; sinon incrustation.
/// 4. **SDR** → natif si tout est lisible tel quel (vidéo, audio, conteneur,
///    sous-titres texte simples), sinon **mpv** en lecture directe.
/// 5. Transcodage serveur en dernier recours (aucun moteur ne sait décoder).
///
/// Chaque décision est accompagnée de replis (bascule automatique si le moteur
/// échoue au démarrage) : l'autre moteur, puis le transcodage.
library;

import 'device_capabilities.dart';
import 'source_profile.dart';

enum EngineKind {
  native('Natif'),
  mpv('mpv');

  const EngineKind(this.label);
  final String label;
}

enum Delivery {
  directPlay('Lecture directe'),
  remux('Remux'),
  transcode('Transcodage');

  const Delivery(this.label);
  final String label;
}

/// Comment le sous-titre choisi sera affiché.
enum SubtitleRoute {
  none,

  /// Rendu par le moteur (mpv : pistes intégrées ou fichier externe, libass).
  engine,

  /// Texte servi par Jellyfin (WebVTT) et dessiné par OptiFin au-dessus de la vidéo native.
  overlay,

  /// Incrusté dans l'image par le serveur (transcodage vidéo).
  burnIn,
}

/// Réglage « Moteur de lecture » (global ou pour une lecture).
enum EnginePreference {
  auto('Automatique'),
  native('Natif'),
  mpv('mpv');

  const EnginePreference(this.label);
  final String label;
}

/// Sous-titres image (PGS, VobSub) sur une vidéo que le lecteur natif devrait lire.
enum ImageSubtitlePolicy {
  /// mpv s'il peut lire la vidéo, sinon incrustation serveur.
  auto('Automatique'),

  /// Incrustation par le serveur (garde le lecteur natif, coûte du CPU serveur).
  burnIn('Incruster (serveur)');

  const ImageSubtitlePolicy(this.label);
  final String label;
}

class EngineDecision {
  const EngineDecision(
    this.engine,
    this.delivery, {
    this.subtitles = SubtitleRoute.none,
    this.reencodeVideo = false,
    required this.reason,
  });

  final EngineKind engine;
  final Delivery delivery;
  final SubtitleRoute subtitles;

  /// La vidéo doit être ré-encodée (incrustation, codec illisible) : copie interdite.
  final bool reencodeVideo;

  /// Raison lisible (overlay de debug, journaux).
  final String reason;

  bool get isNative => engine == EngineKind.native;
  String get label => '${engine.label} · ${delivery.label}';

  bool sameRoute(EngineDecision other) =>
      engine == other.engine && delivery == other.delivery && subtitles == other.subtitles;

  @override
  String toString() => '$label (${subtitles.name}) — $reason';
}

class EngineSelection {
  const EngineSelection(this.primary, {this.fallbacks = const [], this.trace = const []});

  final EngineDecision primary;

  /// Replis successifs si [primary] échoue au démarrage.
  final List<EngineDecision> fallbacks;

  /// Détail de l'analyse (overlay de debug, journaux).
  final List<String> trace;

  List<EngineDecision> get chain => [primary, ...fallbacks];
}

class SelectionRequest {
  const SelectionRequest({
    required this.source,
    required this.device,
    this.audioIndex,
    this.subtitleIndex,
    this.maxBitrate = 120000000,
    this.preference = EnginePreference.auto,
    this.imageSubtitles = ImageSubtitlePolicy.auto,
    this.forceTranscode = false,
  });

  final SourceProfile source;
  final DeviceCapabilities device;

  /// Pistes choisies (index Jellyfin). Audio null = piste par défaut ; sous-titres null = aucun.
  final int? audioIndex;
  final int? subtitleIndex;
  final int maxBitrate;
  final EnginePreference preference;
  final ImageSubtitlePolicy imageSubtitles;
  final bool forceTranscode;
}

abstract final class EngineSelector {
  static EngineSelection select(SelectionRequest r) => _Analysis(r).select();
}

class _Analysis {
  _Analysis(this.r)
    : video = r.source.video,
      audio = r.source.audioAt(r.audioIndex),
      subtitle = r.source.subtitleAt(r.subtitleIndex);

  final SelectionRequest r;
  final VideoInfo? video;
  final AudioInfo? audio;
  final SubtitleInfo? subtitle;
  final trace = <String>[];

  DeviceCapabilities get device => r.device;
  bool get nativeAvailable => device.nativeAvailable;

  // ------------------------------------------------------------ Analyses

  /// La vidéo est-elle décodable **et affichable correctement** par le lecteur natif ?
  String? get nativeVideoProblem {
    if (!nativeAvailable) return 'lecteur natif indisponible';
    final v = video;
    if (v == null) return null;
    if (!device.videoCodecs.contains(v.codec)) return 'codec vidéo ${v.codec.toUpperCase()} non pris en charge';
    if (v.codec == 'hevc' && v.is10Bit && !device.hevcMain10) return 'HEVC 10 bits non pris en charge';
    if ((v.width ?? 0) > device.maxWidth) return 'résolution ${v.width} px > ${device.maxWidth} px';
    if (v.isDolbyVision) {
      if (device.dolbyVisionProfiles.contains(v.dvProfile)) return null;
      final bl = v.dvBaseLayer;
      if (bl != null && (bl == DynamicRange.sdr || device.ranges.contains(bl))) return null;
      return 'Dolby Vision profil ${v.dvProfile ?? '?'} sans couche de base compatible';
    }
    if (v.isHdr && !_rangeSupported(v.range)) return '${v.range.label} non affichable';
    return null;
  }

  bool _rangeSupported(DynamicRange range) =>
      device.ranges.contains(range) || (range == DynamicRange.hdr10Plus && device.ranges.contains(DynamicRange.hdr10));

  /// Le Dolby Vision sera-t-il vraiment rendu en DV (et pas via sa couche de base) ?
  bool get nativeDolbyVision => video?.isDolbyVision == true && device.dolbyVisionProfiles.contains(video!.dvProfile);

  /// mpv peut-il lire la vidéo correctement et assez vite ?
  String? get mpvVideoProblem {
    final v = video;
    if (v == null) return null;
    if (v.isDolbyVision && v.dvBaseLayer == null) {
      return 'Dolby Vision profil ${v.dvProfile ?? '?'} : couleurs faussées hors lecteur Dolby Vision';
    }
    final hardware = device.videoCodecs.contains(v.codec) && !(v.codec == 'hevc' && v.is10Bit && !device.hevcMain10);
    if (hardware && (v.width ?? 0) <= device.maxWidth) return null;
    // Décodage logiciel (ffmpeg) : fluide jusqu'en 1080p sur un appareil récent, pas au-delà.
    if (v.isUhd) return '${v.codec.toUpperCase()} ${v.width} px sans décodage matériel';
    return null;
  }

  String? get nativeAudioProblem {
    final a = audio;
    if (a == null || device.audioCodecs.contains(a.codec)) return null;
    return 'audio ${a.profile ?? a.codec.toUpperCase()}';
  }

  String? get nativeContainerProblem {
    final containers = r.source.containers;
    if (containers.isEmpty || containers.any(device.containers.contains)) return null;
    return 'conteneur ${containers.first.toUpperCase()}';
  }

  bool get imageSubtitle => subtitle?.isBitmap ?? false;
  bool get assSubtitle => subtitle?.isAss ?? false;

  // ------------------------------------------------------------ Décisions

  SubtitleRoute _subtitlesFor(EngineKind engine, Delivery delivery) {
    final s = subtitle;
    if (s == null) return SubtitleRoute.none;
    if (s.isBitmap) {
      // Direct Play mpv : rendu natif des PGS. Sinon, seul le serveur sait les incruster.
      return engine == EngineKind.mpv && delivery == Delivery.directPlay ? SubtitleRoute.engine : SubtitleRoute.burnIn;
    }
    return engine == EngineKind.mpv ? SubtitleRoute.engine : SubtitleRoute.overlay;
  }

  EngineDecision _decision(EngineKind engine, Delivery delivery, String reason, {bool reencode = false}) {
    // Une incrustation impose de ré-encoder la vidéo.
    final route = _subtitlesFor(engine, delivery);
    final burnIn = route == SubtitleRoute.burnIn;
    return EngineDecision(
      engine,
      burnIn ? Delivery.transcode : delivery,
      subtitles: route,
      reencodeVideo: reencode || burnIn,
      reason: reason,
    );
  }

  /// Livraison native quand la vidéo passe : directe si conteneur et audio passent, sinon remux.
  Delivery get nativeDelivery =>
      nativeContainerProblem == null && nativeAudioProblem == null ? Delivery.directPlay : Delivery.remux;

  String get _remuxWhy {
    final why = [?nativeContainerProblem, if (nativeAudioProblem != null) '${nativeAudioProblem!} converti'];
    return why.isEmpty ? '' : ' (remux : ${why.join(', ')})';
  }

  EngineDecision _native(String reason) {
    final delivery = nativeDelivery;
    return _decision(EngineKind.native, delivery, delivery == Delivery.remux ? '$reason$_remuxWhy' : reason);
  }

  EngineSelection select() {
    _traceAnalysis();
    final primary = _primary();
    final selection = EngineSelection(primary, fallbacks: _fallbacks(primary), trace: trace);
    trace.add('→ ${primary.label} : ${primary.reason}');
    return selection;
  }

  void _traceAnalysis() {
    final v = video;
    trace.add('Source : ${r.source.container}${r.source.bitrate == null ? '' : ', ${_mbps(r.source.bitrate!)}'}');
    if (v != null) trace.add('Vidéo : ${v.summary}');
    final a = audio;
    if (a != null) {
      trace.add(
        'Audio : ${a.profile ?? a.codec.toUpperCase()}${a.channels == null ? '' : ' ${a.channels} can.'}'
        '${a.atmos ? ' Atmos' : ''}',
      );
    }
    final s = subtitle;
    if (s != null) trace.add('Sous-titres : ${s.codec.toUpperCase()}${s.isBitmap ? ' (image)' : ''}');
    String ok(String? problem) => problem == null ? 'oui' : 'non ($problem)';
    trace.add(
      'Natif — vidéo : ${ok(nativeVideoProblem)}, audio : ${ok(nativeAudioProblem)}, '
      'conteneur : ${ok(nativeContainerProblem)}',
    );
    trace.add('mpv — vidéo : ${ok(mpvVideoProblem)}');
  }

  EngineDecision _primary() {
    final nativeVideo = nativeVideoProblem;
    final mpvVideo = mpvVideoProblem;
    final bitrate = r.source.bitrate;

    // 1. Débit : rien ne sert de tenter la lecture directe d'un flux trop lourd.
    if (r.forceTranscode || (bitrate != null && bitrate > r.maxBitrate)) {
      final engine = r.preference == EnginePreference.mpv || !nativeAvailable ? EngineKind.mpv : EngineKind.native;
      return _decision(
        engine,
        Delivery.transcode,
        r.forceTranscode
            ? 'Transcodage demandé'
            : 'Débit source ${_mbps(bitrate!)} supérieur à la limite (${_mbps(r.maxBitrate)})',
      );
    }

    // 2. Préférence explicite.
    if (r.preference == EnginePreference.mpv) {
      return mpvVideo == null
          ? _decision(EngineKind.mpv, Delivery.directPlay, 'Moteur mpv choisi dans les réglages')
          : _decision(EngineKind.mpv, Delivery.transcode, 'mpv choisi, mais $mpvVideo : transcodage');
    }
    if (r.preference == EnginePreference.native && nativeAvailable) {
      return nativeVideo == null
          ? _native('Lecteur natif choisi dans les réglages')
          : _decision(EngineKind.native, Delivery.transcode, 'Lecteur natif choisi, mais $nativeVideo : transcodage');
    }

    final v = video;
    // 3. HDR / Dolby Vision : le lecteur natif garde le HDR (et le DV) intacts.
    if (v != null && v.isHdr) {
      final kind = v.isDolbyVision
          ? (nativeDolbyVision ? 'Dolby Vision' : 'Dolby Vision (couche de base ${v.dvBaseLayer?.label})')
          : v.range.label;
      if (nativeVideo == null) {
        if (imageSubtitle) {
          if (r.imageSubtitles == ImageSubtitlePolicy.auto && mpvVideo == null) {
            return _decision(
              EngineKind.mpv,
              Delivery.directPlay,
              'Sous-titres image sur du $kind : rendus par mpv (sinon incrustation serveur)',
            );
          }
          return _decision(EngineKind.native, Delivery.transcode, 'Sous-titres image incrustés par le serveur ($kind)');
        }
        if (assSubtitle && !v.isDolbyVision && mpvVideo == null) {
          return _decision(EngineKind.mpv, Delivery.directPlay, 'Sous-titres ASS stylés sur du $kind : mpv (libass)');
        }
        final assNote = assSubtitle ? ', sous-titres ASS simplifiés' : '';
        return _native('$kind : lecteur natif$assNote');
      }
      if (mpvVideo == null) return _decision(EngineKind.mpv, Delivery.directPlay, '$kind, mais natif : $nativeVideo');
      return _transcode('$nativeVideo ; $mpvVideo');
    }

    // 4. SDR (ou audio seul) : natif seulement si tout passe tel quel.
    final blockers = [
      ?nativeVideo,
      ?nativeContainerProblem,
      ?nativeAudioProblem,
      if (assSubtitle) 'sous-titres ASS',
      if (imageSubtitle) 'sous-titres image',
    ];
    if (blockers.isEmpty) {
      return _decision(EngineKind.native, Delivery.directPlay, 'Lecture directe native');
    }
    if (mpvVideo == null) return _decision(EngineKind.mpv, Delivery.directPlay, 'mpv : ${blockers.join(', ')}');
    if (nativeVideo == null) return _native('Natif (mpv : $mpvVideo)');
    return _transcode('$nativeVideo ; $mpvVideo');
  }

  EngineDecision _transcode(String why) => _decision(
    nativeAvailable ? EngineKind.native : EngineKind.mpv,
    Delivery.transcode,
    'Aucun moteur ne lit ce fichier tel quel ($why) : transcodage',
    reencode: true,
  );

  List<EngineDecision> _fallbacks(EngineDecision primary) {
    final out = <EngineDecision>[];
    void add(EngineDecision d) {
      if (d.engine == EngineKind.native && !nativeAvailable) return;
      if (primary.sameRoute(d) || out.any(d.sameRoute)) return;
      out.add(d);
    }

    final otherEngine = primary.isNative ? EngineKind.mpv : EngineKind.native;
    if (primary.delivery != Delivery.transcode) {
      if (primary.isNative) {
        if (mpvVideoProblem == null) add(_decision(EngineKind.mpv, Delivery.directPlay, 'Repli : mpv'));
      } else if (nativeVideoProblem == null) {
        add(_native('Repli : lecteur natif'));
      }
      // Le moteur principal a échoué : le transcodage passe par l'autre moteur si possible.
      final transcodeEngine = otherEngine == EngineKind.native && !nativeAvailable ? EngineKind.mpv : otherEngine;
      add(_decision(transcodeEngine, Delivery.transcode, 'Repli : transcodage serveur'));
    } else {
      add(_decision(otherEngine, Delivery.transcode, 'Repli : transcodage avec ${otherEngine.label}'));
    }
    return out;
  }
}

String _mbps(int bps) => '${(bps / 1e6).toStringAsFixed(bps >= 10e6 ? 0 : 1)} Mb/s';
