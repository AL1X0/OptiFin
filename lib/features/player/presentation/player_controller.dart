import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_item.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/jellyfin_auth.dart';
import '../../../core/providers.dart';
import '../../details/presentation/details_providers.dart';
import '../../home/presentation/home_providers.dart';
import '../data/engines/mpv_engine.dart';
import '../data/playback_repository.dart';
import '../domain/playback_engine.dart';
import '../domain/playback_plan.dart';
import '../domain/playback_reporter.dart';

final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session == null) throw StateError('Aucune session active');
  return PlaybackRepository(
    ref.watch(jellyfinClientProvider),
    userId: session.account.userId,
    baseUrl: session.server.baseUrl,
  );
});

/// Fabrique du moteur. Phase 3 : libmpv. Phase 4 : choisi par l'EngineSelector.
final playbackEngineFactoryProvider = Provider<Future<PlaybackEngine> Function()>((ref) => MpvEngine.create);

/// En-têtes d'authentification transmis au moteur (jamais le token dans l'URL).
final playbackHeadersProvider = Provider<Map<String, String>>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return {'Authorization': buildAuthorizationHeader(ref.watch(clientIdentityProvider), token: session?.token)};
});

/// `PlaybackInfo` demandé dès l'ouverture de la fiche : quand l'utilisateur appuie
/// sur Lecture, le plan est déjà prêt et la première image arrive plus vite.
/// Conservé 2 minutes après la fermeture de la fiche.
final playbackPrefetchProvider = FutureProvider.autoDispose.family<PlaybackPlan, String>((ref, itemId) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 2), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(playbackRepositoryProvider).prepare(itemId: itemId);
});

enum PlayerPhase { preparing, playing, error, closed }

class PlayerUiState {
  const PlayerUiState({
    this.phase = PlayerPhase.preparing,
    this.item,
    this.plan,
    this.engine,
    this.error,
    this.subtitleStyle = const SubtitleStyle(),
    this.reloading = false,
  });

  final PlayerPhase phase;
  final MediaItem? item;
  final PlaybackPlan? plan;
  final PlaybackEngine? engine;
  final String? error;
  final SubtitleStyle subtitleStyle;

  /// Rechargement du flux en cours (changement de piste en transcodage).
  final bool reloading;

  PlayerUiState copyWith({
    PlayerPhase? phase,
    MediaItem? item,
    PlaybackPlan? plan,
    PlaybackEngine? engine,
    String? error,
    SubtitleStyle? subtitleStyle,
    bool? reloading,
  }) => PlayerUiState(
    phase: phase ?? this.phase,
    item: item ?? this.item,
    plan: plan ?? this.plan,
    engine: engine ?? this.engine,
    error: error ?? this.error,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    reloading: reloading ?? this.reloading,
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
class PlayerController extends Notifier<PlayerUiState> {
  PlayerController(this.args);

  final PlayerArgs args;

  // Créé dans build() : ref n'est plus utilisable pendant la destruction du provider.
  late PlaybackReporter _reporter;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _closed = false;
  bool _disposing = false;

  /// Référence conservée hors de `state` : l'état n'est plus lisible pendant la
  /// destruction du provider (sortie du lecteur par « retour »), le moteur doit
  /// pourtant être libéré.
  PlaybackEngine? _engine;

  @override
  PlayerUiState build() {
    _reporter = PlaybackReporter(ref.read(playbackRepositoryProvider));
    ref.onDispose(() {
      _disposing = true;
      unawaited(close());
    });
    Future.microtask(_start);
    return const PlayerUiState();
  }

  PlaybackEngine? get engine => state.engine;

  Future<void> _start() async {
    try {
      final media = ref.read(mediaRepositoryProvider);
      final itemFuture = media.item(args.itemId);
      // Plan préchargé par la fiche si disponible, sinon demandé maintenant.
      final planFuture = ref.read(playbackPrefetchProvider(args.itemId).future);
      // Future.wait relance l'erreur d'origine (ApiFailure et son message précis).
      final results = await Future.wait<Object>([itemFuture, planFuture]);
      final item = results[0] as MediaItem;
      final plan = results[1] as PlaybackPlan;
      if (_closed) return;
      state = state.copyWith(item: item, plan: plan);

      final engine = await ref.read(playbackEngineFactoryProvider)();
      if (_closed) {
        await engine.dispose();
        return;
      }
      _engine = engine;
      await engine.setSubtitleStyle(state.subtitleStyle);
      _subscriptions.addAll([
        engine.snapshots.listen((s) => _reporter.update(position: s.position, paused: !s.playing)),
        engine.events.listen(_onEvent),
      ]);
      final start = args.start ?? item.resumePosition;
      state = state.copyWith(engine: engine, phase: PlayerPhase.playing);
      await engine.open(engineMediaFor(plan, start: start));
      _reporter.started(plan, position: start);
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object error) {
    if (_closed) return;
    state = state.copyWith(
      phase: PlayerPhase.error,
      error: error is ApiFailure ? error.userMessage : 'La lecture n’a pas pu démarrer.',
    );
  }

  void _onEvent(PlaybackEvent event) {
    switch (event) {
      case PlaybackCompleted():
        // Phase 5 : épisode suivant avec compte à rebours.
        unawaited(close());
      case PlaybackFailed(:final message):
        unawaited(_reporter.stop(failed: true));
        state = state.copyWith(phase: PlayerPhase.error, error: 'Lecture impossible : $message');
    }
  }

  /// Traduit un plan en média pour le moteur (URL, en-têtes, pistes initiales).
  EngineMedia engineMediaFor(PlaybackPlan plan, {required Duration start}) {
    final headers = ref.read(playbackHeadersProvider);
    final sub = plan.currentSubtitle;
    ExternalSubtitle? external;
    int? subtitleOrdinal;
    if (sub != null) {
      final deliverable = sub.deliveryUrl != null && (sub.isExternal || !plan.canSwitchTracksLocally);
      if (deliverable) {
        external = ExternalSubtitle(
          url: PlaybackRepository.resolve(ref.read(playbackRepositoryProvider).baseUrl, sub.deliveryUrl!),
          title: sub.label,
          language: sub.language,
        );
      } else if (plan.canSwitchTracksLocally) {
        subtitleOrdinal = embeddedOrdinal(plan.subtitleTracks, sub.index);
      }
      // Sinon : sous-titre image incrusté par le serveur, rien à faire côté client.
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
    final e = engine;
    if (plan == null || e == null || track.index == plan.audioIndex) return;
    if (plan.canSwitchTracksLocally) {
      await e.selectAudio(embeddedOrdinal(plan.audioTracks, track.index));
      _applyPlan(plan.withTracks(audioIndex: track.index));
    } else {
      await _reload(audioIndex: track.index, subtitleIndex: plan.subtitleIndex);
    }
  }

  /// [track] null = désactiver les sous-titres.
  Future<void> selectSubtitle(MediaTrack? track) async {
    final plan = state.plan;
    final e = engine;
    if (plan == null || e == null || track?.index == plan.subtitleIndex) return;
    final current = plan.currentSubtitle;
    final burnedIn = !plan.canSwitchTracksLocally && current != null && current.deliveryUrl == null;

    if (track == null) {
      if (burnedIn) return _reload(audioIndex: plan.audioIndex, subtitleIndex: -1);
      await e.selectSubtitle(null);
      _applyPlan(plan.withTracks(subtitleIndex: () => null));
      return;
    }
    if (track.deliveryUrl != null && (track.isExternal || !plan.canSwitchTracksLocally) && !burnedIn) {
      final base = ref.read(playbackRepositoryProvider).baseUrl;
      await e.addExternalSubtitle(
        PlaybackRepository.resolve(base, track.deliveryUrl!),
        title: track.label,
        language: track.language,
      );
      _applyPlan(plan.withTracks(subtitleIndex: () => track.index));
    } else if (plan.canSwitchTracksLocally && !track.isExternal) {
      await e.selectSubtitle(embeddedOrdinal(plan.subtitleTracks, track.index));
      _applyPlan(plan.withTracks(subtitleIndex: () => track.index));
    } else {
      // Transcodage : le serveur doit préparer un nouveau flux (incrustation d'un sous-titre image).
      await _reload(audioIndex: plan.audioIndex, subtitleIndex: track.index);
    }
  }

  Future<void> setSubtitleStyle(SubtitleStyle style) async {
    state = state.copyWith(subtitleStyle: style);
    await engine?.setSubtitleStyle(style);
  }

  void _applyPlan(PlaybackPlan plan) {
    state = state.copyWith(plan: plan);
    _reporter.planChanged(plan);
  }

  /// Recharge le flux à la position courante avec d'autres pistes.
  Future<void> _reload({int? audioIndex, int? subtitleIndex}) async {
    final plan = state.plan;
    final e = engine;
    if (plan == null || e == null) return;
    final position = e.snapshot.position;
    state = state.copyWith(reloading: true);
    try {
      final next = await ref
          .read(playbackRepositoryProvider)
          .prepare(
            itemId: plan.itemId,
            mediaSourceId: plan.mediaSourceId,
            audioIndex: audioIndex,
            subtitleIndex: subtitleIndex,
          );
      if (_closed) return;
      await e.open(engineMediaFor(next, start: position));
      _applyPlan(next);
    } on ApiFailure catch (f) {
      state = state.copyWith(error: f.userMessage);
    } finally {
      if (!_closed) state = state.copyWith(reloading: false);
    }
  }

  /// Termine la lecture : rapport final, libération du moteur, rafraîchissement
  /// des écrans qui affichent la progression.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _reporter.stop();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    final e = _engine;
    _engine = null;
    if (!_disposing) {
      // L'écran cesse d'afficher la vidéo (phase closed) avant la libération du
      // moteur : la surface ne doit jamais pointer vers un lecteur détruit.
      state = state.copyWith(phase: PlayerPhase.closed);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!_disposing) {
      ref.invalidate(homeProvider);
      ref.invalidate(itemProvider(args.itemId));
    }
    await e?.dispose();
  }
}
