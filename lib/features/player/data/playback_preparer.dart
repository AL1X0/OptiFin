import '../../../core/logging/app_log.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/device_capabilities.dart';
import '../domain/engine_selector.dart';
import '../domain/playback_plan.dart';
import '../domain/track_preferences.dart';
import '../../downloads/data/downloads_repository.dart';
import 'device_profiles.dart';
import 'playback_repository.dart';

/// Lecture prête à démarrer : plan du serveur + décision de moteur (et ses replis).
class PreparedPlayback {
  const PreparedPlayback({
    required this.plan,
    required this.selection,
    this.attempt = 0,
    this.audioIndex,
    this.subtitleIndex,
  });

  final PlaybackPlan plan;
  final EngineSelection selection;

  /// Position dans [EngineSelection.chain] (0 = décision principale).
  final int attempt;

  /// Pistes choisies (index Jellyfin), conservées d'un repli à l'autre.
  final int? audioIndex;
  final int? subtitleIndex;

  EngineDecision get decision => selection.chain[attempt];
  bool get hasFallback => attempt + 1 < selection.chain.length;
}

/// Prépare une lecture en trois temps :
/// 1. **analyse** : `PlaybackInfo` avec le profil mpv (qui accepte tout en lecture
///    directe) pour obtenir la description complète de la source ;
/// 2. **pistes** : langues préférées (Paramètres) ;
/// 3. **décision** : [EngineSelector], puis plan définitif demandé avec le profil
///    du moteur choisi — sauf si c'est mpv en lecture directe : l'analyse suffit
///    (une seule requête, démarrage plus rapide).
class PlaybackPreparer {
  const PlaybackPreparer({
    required this.repository,
    required this.device,
    required this.settings,
    required this.maxBitrate,
    this.local,
  });

  final PlaybackRepository repository;
  final DeviceCapabilities device;
  final AppSettings settings;
  final int maxBitrate;

  /// Fichier téléchargé de l'élément, s'il existe : lu en priorité (hors connexion,
  /// sans consommer de débit).
  final Future<LocalMedia?> Function(String itemId)? local;

  EngineSelection select(PlaybackPlan probe, {int? audioIndex, int? subtitleIndex, EnginePreference? preference}) {
    final source = probe.source;
    if (source == null) {
      // Sans description, on suit le serveur : s'il transcode, mpv lit son flux transcodé.
      if (probe.method != PlayMethod.directPlay) {
        return const EngineSelection(
          EngineDecision(EngineKind.mpv, Delivery.transcode, reason: 'Source non décrite : flux du serveur, mpv'),
        );
      }
      return const EngineSelection(
        EngineDecision(EngineKind.mpv, Delivery.directPlay, reason: 'Source non décrite par le serveur : mpv'),
        fallbacks: [EngineDecision(EngineKind.mpv, Delivery.transcode, reason: 'Repli : transcodage serveur')],
      );
    }
    return EngineSelector.select(
      SelectionRequest(
        source: source,
        device: device,
        audioIndex: audioIndex,
        subtitleIndex: subtitleIndex,
        maxBitrate: maxBitrate,
        preference: preference ?? settings.enginePreference,
        imageSubtitles: settings.imageSubtitles,
      ),
    );
  }

  /// Analyse la source puis prépare la décision principale.
  ///
  /// [explicitTracks] : pistes choisies par l'utilisateur (sinon préférences de langue).
  Future<PreparedPlayback> prepare(
    String itemId, {
    Duration start = Duration.zero,
    PlaybackPlan? probe,
    bool explicitTracks = false,
    int? audioIndex,
    int? subtitleIndex,
    EnginePreference? preference,
  }) async {
    final downloaded = probe == null ? await local?.call(itemId) : null;
    if (downloaded != null) {
      return _prepareLocal(
        itemId,
        downloaded,
        start: start,
        explicitTracks: explicitTracks,
        audioIndex: audioIndex,
        subtitleIndex: subtitleIndex,
        preference: preference,
      );
    }
    // Analyse avec le profil natif quand il existe : si le natif est retenu (cas le plus
    // courant), la réponse sert directement de plan — une seule requête avant la première image.
    final analysisEngine = device.nativeAvailable ? EngineKind.native : EngineKind.mpv;
    final analysis =
        probe ??
        await repository.prepare(
          itemId: itemId,
          start: start,
          maxStreamingBitrate: maxBitrate,
          options: analysisEngine == EngineKind.native
              ? PlaybackRequestOptions(deviceProfile: nativeDeviceProfile(device, maxStreamingBitrate: maxBitrate))
              : null,
        );
    final (audio, subtitle) = explicitTracks ? (audioIndex, subtitleIndex) : preferredTracks(analysis, settings);
    final selection = select(analysis, audioIndex: audio, subtitleIndex: subtitle, preference: preference);
    for (final line in selection.trace) {
      AppLog.i('selector', line);
    }
    return planFor(
      itemId,
      selection,
      0,
      probe: analysis,
      audioIndex: audio,
      subtitleIndex: subtitle,
      start: start,
      mediaSourceId: analysis.mediaSourceId,
      probeEngine: probe == null ? analysisEngine : null,
    );
  }

  /// Plan du serveur pour la décision n° [attempt] (décision principale ou repli).
  Future<PreparedPlayback> planFor(
    String itemId,
    EngineSelection selection,
    int attempt, {
    PlaybackPlan? probe,
    int? audioIndex,
    int? subtitleIndex,
    Duration start = Duration.zero,
    String? mediaSourceId,
    EngineKind? probeEngine,
  }) async {
    final decision = selection.chain[attempt];
    // Fichier téléchargé : le repli change de moteur, jamais de source.
    if (probe != null && probe.streamUrl.isScheme('file')) {
      return PreparedPlayback(
        plan: probe.withTracks(audioIndex: audioIndex, subtitleIndex: () => subtitleIndex),
        selection: selection,
        attempt: attempt,
        audioIndex: audioIndex ?? probe.audioIndex,
        subtitleIndex: subtitleIndex,
      );
    }
    final reused = probe == null ? null : _reuse(probe, decision, probeEngine, audioIndex, subtitleIndex);
    if (reused != null) AppLog.d('player', 'Plan d’analyse réutilisé pour ${decision.label} (aucune requête de plus)');
    final plan =
        reused ??
        await repository.prepare(
          itemId: itemId,
          start: start,
          mediaSourceId: mediaSourceId,
          audioIndex: audioIndex,
          // -1 explicite : sans cela le serveur pourrait incruster un sous-titre par défaut.
          subtitleIndex: subtitleIndex ?? -1,
          options: PlaybackRequestOptions.forDecision(decision, device, maxBitrate),
          maxStreamingBitrate: maxBitrate,
        );
    return PreparedPlayback(
      plan: plan,
      selection: selection,
      attempt: attempt,
      audioIndex: audioIndex ?? plan.audioIndex,
      subtitleIndex: subtitleIndex,
    );
  }

  /// La réponse d'analyse suffit-elle pour cette décision ?
  /// - mpv en lecture directe : toujours (le flux statique se lit tel quel, quel que soit le profil) ;
  /// - natif : si l'analyse a été faite avec le profil natif, que le serveur a choisi le même
  ///   mode (direct / remux) et que les pistes voulues sont celles du flux (un remux ne contient
  ///   que la piste audio choisie ; une incrustation impose une nouvelle demande).
  PlaybackPlan? _reuse(
    PlaybackPlan probe,
    EngineDecision decision,
    EngineKind? probeEngine,
    int? audioIndex,
    int? subtitleIndex,
  ) {
    PlaybackPlan withTracks(PlaybackPlan p) => p.withTracks(audioIndex: audioIndex, subtitleIndex: () => subtitleIndex);
    if (decision.engine == EngineKind.mpv) {
      return decision.delivery == Delivery.directPlay ? withTracks(repository.asDirectPlay(probe)) : null;
    }
    if (probeEngine != EngineKind.native || decision.subtitles == SubtitleRoute.burnIn) return null;
    final sameMethod = switch (decision.delivery) {
      Delivery.directPlay => probe.method == PlayMethod.directPlay,
      Delivery.remux => probe.method == PlayMethod.directStream && (audioIndex ?? probe.audioIndex) == probe.audioIndex,
      Delivery.transcode => false,
    };
    return sameMethod ? withTracks(probe) : null;
  }
}

extension on PlaybackPreparer {
  /// Lecture d'un fichier téléchargé : plan construit depuis le `PlaybackInfo` conservé,
  /// flux = fichier local. Seule la lecture directe est possible (remux, transcodage et
  /// sous-titres servis par Jellyfin demandent le serveur) : mpv reste en dernier recours.
  PreparedPlayback _prepareLocal(
    String itemId,
    LocalMedia media, {
    required Duration start,
    required bool explicitTracks,
    int? audioIndex,
    int? subtitleIndex,
    EnginePreference? preference,
  }) {
    final base = PlaybackRepository.planFromResponse(
      media.playbackInfo,
      itemId: itemId,
      baseUrl: repository.baseUrl,
      start: start,
    );
    final plan = PlaybackPlan(
      itemId: itemId,
      mediaSourceId: base.mediaSourceId,
      playSessionId: null,
      method: PlayMethod.directPlay,
      streamUrl: Uri.file(media.file.path),
      audioTracks: base.audioTracks,
      // Sous-titres externes : servis par le serveur, indisponibles hors connexion.
      subtitleTracks: [
        for (final t in base.subtitleTracks)
          if (!t.isExternal) t,
      ],
      audioIndex: base.audioIndex,
      container: base.container,
      bitrate: base.bitrate,
      videoCodec: base.videoCodec,
      startPosition: start,
      runtime: base.runtime,
      source: base.source,
    );
    final (audio, subtitle) = explicitTracks ? (audioIndex, subtitleIndex) : preferredTracks(plan, settings);
    final selection = select(plan, audioIndex: audio, subtitleIndex: subtitle, preference: preference);
    final usable = [
      for (final d in selection.chain)
        if (d.delivery == Delivery.directPlay &&
            (d.subtitles == SubtitleRoute.none || d.subtitles == SubtitleRoute.engine))
          d,
    ];
    if (!usable.any((d) => d.engine == EngineKind.mpv)) {
      usable.add(
        EngineDecision(
          EngineKind.mpv,
          Delivery.directPlay,
          subtitles: subtitle == null ? SubtitleRoute.none : SubtitleRoute.engine,
          reason: 'Fichier téléchargé : mpv',
        ),
      );
    }
    final local = EngineSelection(
      usable.first,
      fallbacks: usable.skip(1).toList(),
      trace: ['Fichier téléchargé : ${media.file.path.split('/').last}', ...selection.trace],
    );
    for (final line in local.trace) {
      AppLog.i('selector', line);
    }
    return PreparedPlayback(
      plan: plan.withTracks(audioIndex: audio, subtitleIndex: () => subtitle),
      selection: local,
      audioIndex: audio ?? plan.audioIndex,
      subtitleIndex: subtitle,
    );
  }
}
