import 'dart:async';

import 'playback_plan.dart';

/// Rapport envoyé au serveur (start / progress / stop).
class PlaybackReport {
  const PlaybackReport({
    required this.itemId,
    required this.mediaSourceId,
    required this.playSessionId,
    required this.method,
    required this.position,
    this.isPaused = false,
    this.audioIndex,
    this.subtitleIndex,
    this.failed = false,
  });

  final String itemId;
  final String mediaSourceId;
  final String? playSessionId;
  final PlayMethod method;
  final Duration position;
  final bool isPaused;
  final int? audioIndex;
  final int? subtitleIndex;
  final bool failed;

  int get positionTicks => position.inMicroseconds * 10;
}

abstract interface class PlaybackReportSink {
  Future<void> start(PlaybackReport report);
  Future<void> progress(PlaybackReport report);
  Future<void> stopped(PlaybackReport report);
}

/// Cadence les rapports de lecture vers le serveur.
///
/// - `start` à l'ouverture ;
/// - `progress` toutes les [interval], et immédiatement à chaque pause/reprise
///   et après un seek (les autres appareils voient l'état à jour) ;
/// - `stopped` à la fermeture, avec la dernière position connue.
///
/// Les erreurs réseau sont avalées : le reporting ne doit jamais interrompre la lecture.
class PlaybackReporter {
  PlaybackReporter(this._sink, {this.interval = const Duration(seconds: 10)});

  final PlaybackReportSink _sink;
  final Duration interval;

  PlaybackPlan? _plan;
  Timer? _timer;
  Duration _position = Duration.zero;
  bool _paused = false;
  bool _stopped = true;

  bool get isActive => !_stopped;

  void started(PlaybackPlan plan, {Duration position = Duration.zero}) {
    _plan = plan;
    _position = position;
    _paused = false;
    _stopped = false;
    _send(_sink.start);
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _send(_sink.progress));
  }

  /// Nouveau plan (changement de piste avec rechargement) : même session de lecture.
  void planChanged(PlaybackPlan plan) {
    _plan = plan;
    if (!_stopped) _send(_sink.progress);
  }

  /// À appeler à chaque instantané du moteur.
  void update({required Duration position, required bool paused}) {
    if (_stopped) return;
    _position = position;
    if (paused != _paused) {
      _paused = paused;
      _send(_sink.progress);
    }
  }

  void seeked(Duration position) {
    if (_stopped) return;
    _position = position;
    _send(_sink.progress);
  }

  Future<void> stop({bool failed = false}) async {
    if (_stopped) return;
    _stopped = true;
    _timer?.cancel();
    _timer = null;
    await _send(_sink.stopped, failed: failed);
  }

  Future<void> _send(Future<void> Function(PlaybackReport) call, {bool failed = false}) async {
    final plan = _plan;
    if (plan == null) return;
    try {
      await call(
        PlaybackReport(
          itemId: plan.itemId,
          mediaSourceId: plan.mediaSourceId,
          playSessionId: plan.playSessionId,
          method: plan.method,
          position: _position,
          isPaused: _paused,
          audioIndex: plan.audioIndex,
          subtitleIndex: plan.subtitleIndex,
          failed: failed,
        ),
      );
    } catch (_) {
      // Serveur injoignable pendant la lecture : on réessaiera au prochain tick.
    }
  }
}
