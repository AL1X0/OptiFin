import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optifin_native_player/optifin_native_player.dart' show NativePlayers;

import '../../../core/media/media_item.dart';
import '../../../core/providers.dart';
import '../domain/playback_engine.dart';
import 'player_controller.dart';

/// Ordinateur (Windows) : la lecture en cours est connue du système.
///
/// - touches multimédias du clavier, encart de Windows (titre, affiche) et boutons de la
///   vignette dans la barre des tâches pilotent le lecteur ;
/// - progression de la lecture sur l'icône de la barre des tâches.
///
/// Mise à jour à chaque changement d'état (lecture/pause) et toutes les 5 s pour la position.
class PlayerMediaSession extends ConsumerStatefulWidget {
  const PlayerMediaSession({super.key, required this.args, required this.child});

  final PlayerArgs args;
  final Widget child;

  @override
  ConsumerState<PlayerMediaSession> createState() => _PlayerMediaSessionState();
}

class _PlayerMediaSessionState extends ConsumerState<PlayerMediaSession> {
  StreamSubscription<String>? _buttons;
  StreamSubscription<PlayerSnapshot>? _snapshots;
  PlaybackEngine? _engine;
  Timer? _tick;
  bool? _playing;

  PlayerController get _controller => ref.read(playerControllerProvider(widget.args).notifier);

  @override
  void initState() {
    super.initState();
    _buttons = NativePlayers.mediaButtons.listen(_onButton);
    _tick = Timer.periodic(const Duration(seconds: 5), (_) => _publish());
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_buttons?.cancel());
    unawaited(_snapshots?.cancel());
    unawaited(NativePlayers.clearMediaSession().catchError((Object _) {}));
    super.dispose();
  }

  void _onButton(String button) {
    final engine = _engine;
    if (engine == null) return;
    switch (button) {
      case 'play':
        unawaited(engine.play());
      case 'pause':
        unawaited(engine.pause());
      case 'toggle':
        unawaited(_controller.togglePlay());
      case 'next':
        unawaited(_controller.playNext());
      case 'back10':
        unawaited(_controller.seekBy(const Duration(seconds: -10)));
    }
  }

  void _watch(PlaybackEngine? engine) {
    if (identical(engine, _engine)) return;
    _engine = engine;
    unawaited(_snapshots?.cancel());
    _snapshots = engine?.snapshots.listen((s) {
      if (s.playing != _playing) {
        _playing = s.playing;
        _publish();
      }
    });
  }

  void _publish() {
    final engine = _engine;
    final state = ref.read(playerControllerProvider(widget.args));
    final item = state.item;
    if (engine == null || item == null) return;
    final s = engine.snapshot;
    final episode = item.kind == MediaKind.episode;
    final image = item.poster ?? item.primary;
    final artwork = ref.read(imageUrlBuilderProvider).maybe(image, logicalWidth: 300, devicePixelRatio: 1);
    unawaited(
      NativePlayers.updateMediaSession(
        title: episode ? (item.seriesName ?? item.name) : item.name,
        subtitle: episode ? [?item.episodeLabel, item.name].join(' · ') : '',
        artwork: artwork,
        playing: s.playing,
        position: s.position,
        duration: s.duration > Duration.zero ? s.duration : (state.plan?.runtime ?? Duration.zero),
        hasNext: state.extras.nextEpisode != null,
      ).catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    _watch(ref.watch(playerControllerProvider(widget.args).select((s) => s.engine)));
    return widget.child;
  }
}
