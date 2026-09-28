import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optifin_native_player/optifin_native_player.dart' show NativePlayers;

import '../../../core/logging/app_log.dart';
import '../../../core/media/media_item.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers.dart';
import '../../details/presentation/details_providers.dart';
import '../../home/presentation/home_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/playback_preparer.dart';
import '../data/playback_repository.dart';
import '../domain/engine_selector.dart';
import '../domain/playback_engine.dart';
import '../domain/playback_extras.dart';
import '../domain/playback_plan.dart';
import '../domain/playback_reporter.dart';
import 'playback_providers.dart';

export 'playback_providers.dart';

enum PlayerPhase { preparing, playing, error, closed }

class PlayerUiState {
  const PlayerUiState({
    this.phase = PlayerPhase.preparing,
    this.item,
    this.plan,
    this.engine,
    this.decision,
    this.selection,
    this.preference,
    this.error,
    this.subtitleStyle = const SubtitleStyle(),
    this.reloading = false,
    this.notice,
    this.technicalError,
    this.extras = PlaybackExtras.empty,
    this.segment,
    this.upNext = false,
    this.nextItemId,
    this.subtitleDelay = Duration.zero,
    this.audioDelay = Duration.zero,
    this.pictureInPicture = false,
  });

  final PlayerPhase phase;
  final MediaItem? item;
  final PlaybackPlan? plan;
  final PlaybackEngine? engine;

  /// Décision de l'EngineSelector en cours (moteur, livraison, sous-titres, raison).
  final EngineDecision? decision;
  final EngineSelection? selection;

  /// Moteur imposé pour cette lecture (null = réglage global).
  final EnginePreference? preference;
  final String? error;
  final SubtitleStyle subtitleStyle;

  /// Rechargement du flux en cours (changement de piste, de moteur, bascule).
  final bool reloading;

  /// Message discret affiché pendant une bascule automatique.
  final String? notice;

  /// Détail technique de l'erreur (affiché en mode debug).
  final String? technicalError;

  /// Chapitres, trickplay, segments, épisode suivant (chargés après le démarrage).
  final PlaybackExtras extras;

  /// Segment (intro, récap…) en cours que l'on peut passer.
  final MediaSegment? segment;

  /// Carte « Épisode suivant » affichée (générique en cours).
  final bool upNext;

  /// Élément à lire à la fermeture (enchaînement d'épisodes) : l'écran remplace
  /// le lecteur par celui de cet élément au lieu de revenir en arrière.
  final String? nextItemId;
  final Duration subtitleDelay;
  final Duration audioDelay;

  /// Android : l'activité est en Picture-in-Picture (contrôles masqués).
  final bool pictureInPicture;

  PlayerUiState copyWith({
    PlayerPhase? phase,
    MediaItem? item,
    PlaybackPlan? plan,
    PlaybackEngine? engine,
    EngineDecision? decision,
    EngineSelection? selection,
    EnginePreference? Function()? preference,
    String? error,
    SubtitleStyle? subtitleStyle,
    bool? reloading,
    String? Function()? notice,
    String? technicalError,
    PlaybackExtras? extras,
    MediaSegment? Function()? segment,
    bool? upNext,
    String? nextItemId,
    Duration? subtitleDelay,
    Duration? audioDelay,
    bool? pictureInPicture,
  }) => PlayerUiState(
    phase: phase ?? this.phase,
    item: item ?? this.item,
    plan: plan ?? this.plan,
    engine: engine ?? this.engine,
    decision: decision ?? this.decision,
    selection: selection ?? this.selection,
    preference: preference != null ? preference() : this.preference,
    error: error ?? this.error,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    reloading: reloading ?? this.reloading,
    notice: notice != null ? notice() : this.notice,
    technicalError: technicalError ?? this.technicalError,
    extras: extras ?? this.extras,
    segment: segment != null ? segment() : this.segment,
    upNext: upNext ?? this.upNext,
    nextItemId: nextItemId ?? this.nextItemId,
    subtitleDelay: subtitleDelay ?? this.subtitleDelay,
    audioDelay: audioDelay ?? this.audioDelay,
    pictureInPicture: pictureInPicture ?? this.pictureInPicture,
  );
}

/// Arguments d'une lecture : élément + position de départ.
class PlayerArgs {
  const PlayerArgs(this.itemId, {this.start});

  final String itemId;

  /// null = reprendre à la position enregistrée sur le serveur.
  final Duration? start;

  @override
  bool operator ==(Object other) => other is PlayerArgs && other.itemId == itemId && other.start == start;

  @override
  int get hashCode => Object.hash(itemId, start);
}

final playerControllerProvider = NotifierProvider.autoDispose.family<PlayerController, PlayerUiState, PlayerArgs>(
  PlayerController.new,
);

/// Orchestration d'une lecture, indépendante du moteur.
///
/// Démarre la décision principale de l'EngineSelector ; si le moteur échoue avant
/// la première image (erreur ou délai dépassé), bascule automatiquement sur le
/// repli suivant (autre moteur, puis transcodage) sans intervention.
class PlayerController extends Notifier<PlayerUiState> {
  PlayerController(this.args);

  final PlayerArgs args;

  /// Délai max avant la première image : au-delà, le moteur est considéré en échec.
  static Duration startupTimeout = const Duration(seconds: 25);

  // Créé dans build() : ref n'est plus utilisable pendant la destruction du provider.
  late PlaybackReporter _reporter;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Abonnements indépendants du moteur (PiP Android), annulés à la fermeture.
  final _subscriptionsForever = <StreamSubscription<Object?>>[];
  bool _closed = false;
  bool _disposing = false;
  bool _reported = false;

  /// Références conservées hors de `state` : l'état n'est plus lisible pendant la
  /// destruction du provider (sortie du lecteur par « retour »), le moteur doit
  /// pourtant être libéré.
  PlaybackEngine? _engine;
  EngineKind? _engineKind;
  PreparedPlayback? _prepared;
  PlaybackPreparer? _preparer;

  /// Démarrage en cours : première image pas encore affichée.
  bool _starting = false;
  Timer? _startupTimer;
  Duration _startPosition = Duration.zero;
  final _failures = <String>[];

  /// Segments déjà passés automatiquement (une seule fois chacun, même après un retour en arrière).
  final _autoSkipped = <MediaSegment>{};

  /// L'utilisateur a fermé la carte « Épisode suivant » : elle ne revient pas.
  bool _upNextDismissed = false;

  @override
  PlayerUiState build() {
    _reporter = PlaybackReporter(ref.read(playbackRepositoryProvider));
    final settings = ref.read(settingsProvider);
    ref.onDispose(() {
      _disposing = true;
      unawaited(close());
    });
    Future.microtask(_start);
    _subscriptionsForever.add(
      NativePlayers.pictureInPictureChanges.listen((active) {
        if (!_closed) state = state.copyWith(pictureInPicture: active);
      }),
    );
    return PlayerUiState(subtitleStyle: settings.subtitleStyle);
  }

  PlaybackEngine? get engine => state.engine;

  Future<PlaybackPreparer> _getPreparer() async => _preparer ??= await ref.read(playbackPreparerProvider)();

  Future<void> _start() async {
    try {
      final media = ref.read(mediaRepositoryProvider);
      final itemFuture = media.item(args.itemId);
      // Plan et décision préchargés par la fiche si disponibles, sinon calculés maintenant.
      final preparedFuture = ref.read(playbackPrefetchProvider(args.itemId).future);
      // Future.wait relance l'erreur d'origine (ApiFailure et son message précis).
      final results = await Future.wait<Object>([itemFuture, preparedFuture]);
      final item = results[0] as MediaItem;
      final prepared = results[1] as PreparedPlayback;
      if (_closed) return;
      state = state.copyWith(item: item);
      unawaited(_loadExtras(item, prepared.plan.mediaSourceId));
      await _launch(prepared, start: args.start ?? item.resumePosition);
    } catch (e, stack) {
      _fail(e, stack);
    }
  }

  /// Démarre (ou redémarre) la lecture d'un plan avec le moteur de sa décision.
  /// Le moteur courant est réutilisé s'il est du bon type.
  Future<void> _launch(PreparedPlayback prepared, {required Duration start}) async {
    _prepared = prepared;
    _startPosition = start;
    final plan = prepared.plan;
    _logPlan(prepared);
    state = state.copyWith(plan: plan, decision: prepared.decision, selection: prepared.selection);

    final kind = prepared.decision.engine;
    var engine = _engine;
    if (engine == null || _engineKind != kind) {
      await _releaseEngine();
      // Lecteur fermé pendant le remplacement : ref n'est plus utilisable.
      if (_closed) return;
      engine = await ref.read(playbackEngineFactoryProvider)(kind);
      if (_closed) {
        await engine.dispose();
        return;
      }
      _engine = engine;
      _engineKind = kind;
      await engine.setSubtitleStyle(state.subtitleStyle);
      if (state.subtitleDelay != Duration.zero) await engine.setSubtitleDelay(state.subtitleDelay);
      if (state.audioDelay != Duration.zero) await engine.setAudioDelay(state.audioDelay);
      _subscriptions.addAll([engine.snapshots.listen(_onSnapshot), engine.events.listen(_onEvent)]);
    }
    state = state.copyWith(engine: engine, phase: PlayerPhase.playing);

    _starting = true;
    _startupTimer?.cancel();
    _startupTimer = Timer(startupTimeout, () {
      if (_starting) _onStartupFailure('aucune image après ${startupTimeout.inSeconds} s');
    });
    try {
      await engine.open(engineMediaFor(prepared, start: start));
    } catch (e) {
      await _onStartupFailure('$e');
      return;
    }
    if (!_reported) {
      _reported = true;
      _reporter.started(plan, position: start);
    } else {
      _reporter.planChanged(plan);
    }
  }

  Future<void> _loadExtras(MediaItem item, String mediaSourceId) async {
    final extras = await ref.read(playbackExtrasRepositoryProvider).load(item, mediaSourceId: mediaSourceId);
    if (_closed) return;
    AppLog.i(
      'extras',
      '${extras.chapters.length} chapitres, trickplay ${extras.trickplay == null ? 'absent' : '${extras.trickplay!.width} px'}, '
          '${extras.segments.length} segments${extras.nextEpisode == null ? '' : ', suivant : « ${extras.nextEpisode!.name} »'}',
    );
    state = state.copyWith(extras: extras);
  }

  /// Segments et épisode suivant, à chaque instantané du moteur.
  void _trackPosition(PlayerSnapshot s) {
    if (_starting || s.status != PlaybackStatus.ready) return;
    final extras = state.extras;
    final segment = extras.skippableAt(s.position);
    if (segment != state.segment) state = state.copyWith(segment: () => segment);
    if (segment != null && ref.read(settingsProvider).autoSkipSegments && _autoSkipped.add(segment)) {
      AppLog.i('player', 'Segment passé automatiquement : ${segment.type.name}');
      unawaited(seek(segment.end));
    }
    final upNextAt = extras.upNextAt(s.duration);
    final showUpNext = upNextAt != null && s.position >= upNextAt && !_upNextDismissed;
    if (showUpNext != state.upNext) {
      state = state.copyWith(upNext: showUpNext);
      // Plan et moteur de l'épisode suivant préparés pendant le générique.
      if (showUpNext) ref.read(playbackPrefetchProvider(extras.nextEpisode!.id));
    }
  }

  Future<void> skipSegment() async {
    final segment = state.segment;
    if (segment != null) await seek(segment.end);
  }

  void dismissUpNext() {
    _upNextDismissed = true;
    state = state.copyWith(upNext: false);
  }

  /// Enchaîne l'épisode suivant : fin de session propre, puis l'écran remplace le lecteur.
  Future<void> playNext() async {
    final next = state.extras.nextEpisode;
    if (next == null || _closed) return;
    AppLog.i('player', 'Épisode suivant : « ${next.name} »');
    state = state.copyWith(nextItemId: next.id);
    await close();
  }

  /// Recherche de sous-titres via les fournisseurs du serveur (langue ISO 639-2).
  Future<List<RemoteSubtitle>> searchSubtitles(String language) =>
      ref.read(playbackExtrasRepositoryProvider).searchSubtitles(args.itemId, language);

  /// Télécharge un sous-titre sur le serveur puis l'affiche, sans interrompre la lecture.
  Future<void> downloadSubtitle(RemoteSubtitle subtitle) async {
    final prepared = _prepared;
    final plan = state.plan;
    if (prepared == null || plan == null) return;
    await ref.read(playbackExtrasRepositoryProvider).downloadSubtitle(args.itemId, subtitle.id);
    final known = {for (final t in plan.subtitleTracks) t.index};
    final preparer = await _getPreparer();
    MediaTrack? added;
    PlaybackPlan? refreshed;
    // Le serveur enregistre le fichier puis rafraîchit l'élément : on laisse une seconde chance.
    for (var attempt = 0; attempt < 3 && added == null; attempt++) {
      if (attempt > 0) await Future<void>.delayed(const Duration(seconds: 2));
      final next = await preparer.planFor(
        args.itemId,
        prepared.selection,
        prepared.attempt,
        audioIndex: plan.audioIndex,
        subtitleIndex: plan.subtitleIndex,
        start: engine?.snapshot.position ?? Duration.zero,
        mediaSourceId: plan.mediaSourceId,
      );
      refreshed = next.plan;
      added = refreshed.subtitleTracks.where((t) => !known.contains(t.index)).firstOrNull;
    }
    if (_closed || refreshed == null) return;
    if (added == null) throw const UnexpectedFailure('Le serveur n’a pas encore ajouté ce sous-titre. Réessayez.');
    AppLog.i('player', 'Sous-titre téléchargé : ${added.label} (index ${added.index})');
    final updated = state.plan!.withSubtitleTracks(refreshed.subtitleTracks);
    _prepared = PreparedPlayback(
      plan: updated,
      selection: prepared.selection,
      attempt: prepared.attempt,
      audioIndex: prepared.audioIndex,
      subtitleIndex: prepared.subtitleIndex,
    );
    state = state.copyWith(plan: updated);
    await selectSubtitle(added);
  }

  Future<bool> enterPictureInPicture() async => await engine?.enterPictureInPicture() ?? false;

  Future<void> setSubtitleDelay(Duration delay) async {
    state = state.copyWith(subtitleDelay: delay);
    await engine?.setSubtitleDelay(delay);
  }

  Future<void> setAudioDelay(Duration delay) async {
    state = state.copyWith(audioDelay: delay);
    await engine?.setAudioDelay(delay);
  }

  void _onSnapshot(PlayerSnapshot s) {
    if (_starting && s.status == PlaybackStatus.ready) {
      _starting = false;
      _startupTimer?.cancel();
      // Android : quitter l'app pendant la lecture la réduit en Picture-in-Picture.
      if (_engine?.capabilities.pictureInPicture ?? false) {
        final size = s.videoSize;
        unawaited(
          NativePlayers.setAutoPictureInPicture(
            true,
            width: size?.width.round() ?? 16,
            height: size?.height.round() ?? 9,
          ),
        );
      }
      if (state.notice != null) state = state.copyWith(notice: () => null);
    }
    _reporter.update(position: s.position, paused: !s.playing);
    _trackPosition(s);
  }

  /// Échec avant la première image : repli suivant de la chaîne, sinon erreur.
  Future<void> _onStartupFailure(String message) async {
    if (_closed || !_starting) return;
    _starting = false;
    _startupTimer?.cancel();
    final prepared = _prepared;
    if (prepared == null) return;
    final attempt = '${prepared.decision.label} : $message';
    _failures.add(attempt);
    AppLog.w('player', 'Échec au démarrage — $attempt');
    if (!prepared.hasFallback) {
      unawaited(_reporter.stop(failed: true));
      state = state.copyWith(
        phase: PlayerPhase.error,
        error: 'Le lecteur n’a pas pu lire ce fichier.',
        technicalError: _failures.join('\n'),
        notice: () => null,
      );
      return;
    }
    try {
      final preparer = await _getPreparer();
      final next = await preparer.planFor(
        args.itemId,
        prepared.selection,
        prepared.attempt + 1,
        probe: prepared.plan,
        audioIndex: prepared.audioIndex,
        subtitleIndex: prepared.subtitleIndex,
        start: _startPosition,
        mediaSourceId: prepared.plan.mediaSourceId,
      );
      if (_closed) return;
      AppLog.i('player', 'Bascule automatique → ${next.decision.label} (${next.decision.reason})');
      state = state.copyWith(notice: () => 'Bascule vers ${next.decision.label}…');
      await _launch(next, start: _startPosition);
    } catch (e, stack) {
      _fail(e, stack);
    }
  }

  void _logPlan(PreparedPlayback prepared) {
    final plan = prepared.plan;
    final d = prepared.decision;
    AppLog.i(
      'player',
      '« ${state.item?.name ?? plan.itemId} » → ${d.label}${prepared.attempt > 0 ? ' (repli n° ${prepared.attempt})' : ''} : '
          '${d.reason}\n'
          '  serveur : ${plan.method.label}, conteneur ${plan.container ?? '?'}, vidéo ${plan.videoCodec ?? '?'}, '
          'débit ${plan.bitrate == null ? '?' : '${(plan.bitrate! / 1e6).toStringAsFixed(1)} Mb/s'}\n'
          '  URL : ${plan.streamUrl}\n'
          '  audio : ${plan.currentAudio?.label ?? '—'} (index ${plan.audioIndex}), '
          'sous-titres : ${plan.currentSubtitle?.label ?? 'aucun'} (index ${plan.subtitleIndex}, ${d.subtitles.name})',
    );
  }

  void _fail(Object error, [StackTrace? stack]) {
    AppLog.e('player', 'Échec du démarrage de la lecture', error, stack);
    if (_closed) return;
    state = state.copyWith(
      phase: PlayerPhase.error,
      error: error is ApiFailure ? error.userMessage : 'La lecture n’a pas pu démarrer.',
      technicalError: error is UnexpectedFailure ? error.technicalDetail : error.toString(),
      notice: () => null,
    );
  }

  void _onEvent(PlaybackEvent event) {
    switch (event) {
      case PlaybackCompleted():
        final autoNext = ref.read(settingsProvider).autoPlayNext && !_upNextDismissed;
        unawaited(state.extras.nextEpisode != null && autoNext ? playNext() : close());
      case PlaybackFailed(:final message):
        if (_starting) {
          unawaited(_onStartupFailure(message));
          return;
        }
        AppLog.e('player', 'Le moteur ${_engine?.name} a échoué : $message');
        unawaited(_reporter.stop(failed: true));
        state = state.copyWith(
          phase: PlayerPhase.error,
          error: 'Le lecteur n’a pas pu lire ce fichier.',
          technicalError: '${_engine?.name} : $message',
        );
    }
  }

  /// Traduit un plan en média pour le moteur (URL, en-têtes, pistes initiales).
  EngineMedia engineMediaFor(PreparedPlayback prepared, {required Duration start}) {
    final plan = prepared.plan;
    final headers = ref.read(playbackHeadersProvider);
    final embeddedSubtitles = _engine?.capabilities.embeddedSubtitles ?? true;
    final sub = plan.currentSubtitle;
    ExternalSubtitle? external;
    int? subtitleOrdinal;
    if (sub != null) {
      final local = plan.canSwitchTracksLocally && embeddedSubtitles;
      if (sub.deliveryUrl != null && (sub.isExternal || !local)) {
        external = ExternalSubtitle(
          url: PlaybackRepository.resolve(ref.read(playbackRepositoryProvider).baseUrl, sub.deliveryUrl!),
          title: sub.label,
          language: sub.language,
        );
      } else if (local) {
        subtitleOrdinal = embeddedOrdinal(plan.subtitleTracks, sub.index);
      }
      // Sinon : sous-titre incrusté par le serveur, rien à faire côté client.
    }
    return EngineMedia(
      url: plan.streamUrl,
      headers: headers,
      start: start,
      audioOrdinal: plan.canSwitchTracksLocally ? embeddedOrdinal(plan.audioTracks, plan.audioIndex) : null,
      subtitleOrdinal: subtitleOrdinal,
      externalSubtitle: external,
      title: state.item?.name,
    );
  }

  // ------------------------------------------------------------ Commandes

  Future<void> togglePlay() async {
    final e = engine;
    if (e == null) return;
    e.snapshot.playing ? await e.pause() : await e.play();
  }

  Future<void> seek(Duration position) async {
    final e = engine;
    if (e == null) return;
    final duration = e.snapshot.duration;
    final target = position < Duration.zero
        ? Duration.zero
        : (duration > Duration.zero && position > duration ? duration : position);
    await e.seek(target);
    _reporter.seeked(target);
  }

  Future<void> seekBy(Duration delta) async {
    final e = engine;
    if (e == null) return;
    await seek(e.snapshot.position + delta);
  }

  Future<void> setRate(double rate) async => engine?.setRate(rate);

  Future<void> selectAudio(MediaTrack track) async {
    final plan = state.plan;
    if (plan == null || track.index == plan.audioIndex) return;
    await _changeTracks(audio: track.index, subtitle: plan.subtitleIndex);
  }

  /// [track] null = désactiver les sous-titres.
  Future<void> selectSubtitle(MediaTrack? track) async {
    final plan = state.plan;
    if (plan == null || track?.index == plan.subtitleIndex) return;
    await _changeTracks(audio: plan.audioIndex, subtitle: track?.index);
  }

  /// Impose un moteur pour cette lecture (feuille « Audio et sous-titres »).
  Future<void> setEnginePreference(EnginePreference preference) async {
    final plan = state.plan;
    if (plan == null || preference == (state.preference ?? EnginePreference.auto)) return;
    state = state.copyWith(preference: () => preference);
    await _changeTracks(audio: plan.audioIndex, subtitle: plan.subtitleIndex);
  }

  /// Nouvelles pistes : on relance l'EngineSelector. Même moteur et même mode de
  /// livraison en lecture directe → changement instantané ; sinon, nouveau plan
  /// (et nouveau moteur si besoin) à la position courante, sans que l'utilisateur
  /// ait à comprendre pourquoi (ex. choisir des PGS bascule du natif vers mpv).
  Future<void> _changeTracks({required int? audio, required int? subtitle}) async {
    final prepared = _prepared;
    final plan = state.plan;
    final e = engine;
    if (prepared == null || plan == null || e == null) return;
    try {
      final preparer = await _getPreparer();
      final selection = preparer.select(plan, audioIndex: audio, subtitleIndex: subtitle, preference: state.preference);
      final next = selection.primary;
      final current = prepared.decision;
      final sameRoute = next.engine == current.engine && next.delivery == current.delivery;
      if (sameRoute && plan.canSwitchTracksLocally && await _applyLocally(plan, audio: audio, subtitle: subtitle)) {
        final updated = plan.withTracks(audioIndex: audio, subtitleIndex: () => subtitle);
        _prepared = PreparedPlayback(plan: updated, selection: selection, audioIndex: audio, subtitleIndex: subtitle);
        state = state.copyWith(plan: updated, decision: next, selection: selection);
        _reporter.planChanged(updated);
        return;
      }
      await _switch(selection, audio: audio, subtitle: subtitle);
    } on ApiFailure catch (f) {
      state = state.copyWith(error: f.userMessage);
    }
  }

  /// Applique un changement de pistes sans recharger. false si impossible localement.
  Future<bool> _applyLocally(PlaybackPlan plan, {required int? audio, required int? subtitle}) async {
    final e = engine!;
    if (audio != plan.audioIndex) await e.selectAudio(embeddedOrdinal(plan.audioTracks, audio));
    if (subtitle == plan.subtitleIndex) return true;
    final track = plan.subtitleTracks.where((t) => t.index == subtitle).firstOrNull;
    if (track == null) {
      await e.selectSubtitle(null);
      return true;
    }
    final embedded = e.capabilities.embeddedSubtitles;
    if (track.deliveryUrl != null && (track.isExternal || !embedded)) {
      final base = ref.read(playbackRepositoryProvider).baseUrl;
      await e.addExternalSubtitle(
        PlaybackRepository.resolve(base, track.deliveryUrl!),
        title: track.label,
        language: track.language,
      );
      return true;
    }
    if (embedded && !track.isExternal) {
      await e.selectSubtitle(embeddedOrdinal(plan.subtitleTracks, track.index));
      return true;
    }
    return false;
  }

  /// Recharge à la position courante avec une nouvelle décision (et ses replis).
  Future<void> _switch(EngineSelection selection, {required int? audio, required int? subtitle}) async {
    final plan = state.plan!;
    final position = engine?.snapshot.position ?? _startPosition;
    state = state.copyWith(reloading: true);
    try {
      AppLog.i('player', 'Rechargement : ${selection.primary.label} (audio $audio, sous-titres $subtitle)');
      final preparer = await _getPreparer();
      final next = await preparer.planFor(
        args.itemId,
        selection,
        0,
        probe: plan,
        audioIndex: audio,
        subtitleIndex: subtitle,
        start: position,
        mediaSourceId: plan.mediaSourceId,
      );
      if (_closed) return;
      _failures.clear();
      await _launch(next, start: position);
    } finally {
      if (!_closed) state = state.copyWith(reloading: false);
    }
  }

  Future<void> setSubtitleStyle(SubtitleStyle style) async {
    state = state.copyWith(subtitleStyle: style);
    await engine?.setSubtitleStyle(style);
  }

  Future<void> _releaseEngine() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    final e = _engine;
    _engine = null;
    _engineKind = null;
    if (e == null) return;
    if (!_disposing && !_closed) {
      // La surface ne doit jamais pointer vers un moteur détruit : l'écran affiche
      // l'état « préparation » le temps du remplacement.
      state = state.copyWith(phase: PlayerPhase.preparing);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await e.dispose();
  }

  /// Termine la lecture : rapport final, libération du moteur, rafraîchissement
  /// des écrans qui affichent la progression.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _startupTimer?.cancel();
    unawaited(NativePlayers.setAutoPictureInPicture(false));
    for (final s in _subscriptionsForever) {
      unawaited(s.cancel());
    }
    // Le travail de fond (rapport au serveur, libération du moteur) se poursuit après la
    // fermeture de l'écran : le contrôleur reste en vie jusqu'à la fin.
    final link = _disposing ? null : ref.keepAlive();
    final e = _engine;
    _engine = null;
    // Le son s'arrête au toucher de la croix, sans attendre la suite.
    if (e != null) unawaited(e.pause().catchError((Object _) {}));
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    // L'écran se ferme tout de suite (phase closed) : ni le rapport « stop » (aller-retour
    // réseau, plus long si le serveur transcode) ni la libération du lecteur ne le retardent.
    if (!_disposing) state = state.copyWith(phase: PlayerPhase.closed);
    final report = _reporter.stop();
    // La surface vidéo est retirée de l'écran avant la destruction du lecteur.
    if (!_disposing) await Future<void>.delayed(const Duration(milliseconds: 50));
    await e?.dispose();
    await report;
    if (!_disposing) {
      // Après le rapport : l'accueil et la fiche affichent la nouvelle progression.
      ref.invalidate(homeProvider);
      ref.invalidate(itemProvider(args.itemId));
    }
    link?.close();
  }
}
