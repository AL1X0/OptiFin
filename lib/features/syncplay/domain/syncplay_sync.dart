import 'dart:async';

import 'syncplay_models.dart';

/// Horloge du serveur (comme NTP) : décalage estimé à partir de /GetUtcTime. On garde
/// l'échantillon au plus court aller-retour parmi les derniers, le plus fiable.
class TimeSync {
  TimeSync({DateTime Function()? now}) : _now = now ?? (() => DateTime.now().toUtc());

  final DateTime Function() _now;
  final _samples = <(Duration offset, Duration delay)>[];

  /// Heure du serveur moins heure locale.
  Duration offset = Duration.zero;

  /// Aller-retour réseau du meilleur échantillon.
  Duration roundTrip = Duration.zero;

  bool get hasSamples => _samples.isNotEmpty;

  /// t0 : envoi (local), t1 : réception (serveur), t2 : réponse (serveur), t3 : réception (local).
  void addSample(DateTime t0, DateTime t1, DateTime t2, DateTime t3) {
    final o = Duration(microseconds: (t1.difference(t0) + t2.difference(t3)).inMicroseconds ~/ 2);
    var delay = t3.difference(t0) - t2.difference(t1);
    if (delay < Duration.zero) delay = Duration.zero;
    _samples.add((o, delay));
    if (_samples.length > 8) _samples.removeAt(0);
    final best = _samples.reduce((a, b) => a.$2 <= b.$2 ? a : b);
    offset = best.$1;
    roundTrip = best.$2;
  }

  DateTime get localNow => _now();
  DateTime get serverNow => _now().add(offset);

  /// Heure locale correspondant à une heure du serveur.
  DateTime toLocal(DateTime server) => server.subtract(offset);
}

/// Lecteur piloté par une soirée (adaptateur vers le moteur de lecture).
abstract interface class SyncTarget {
  Duration get position;
  bool get paused;
  void play();
  void pause();
  void seek(Duration position);
  void setRate(double rate);
}

/// Ce que le lecteur envoie au serveur.
abstract interface class SyncRequests {
  Future<void> ready(Duration position, {required bool isPlaying, required String playlistItemId});
  Future<void> buffering(Duration position, {required bool isPlaying, required String playlistItemId});
  Future<void> pause();
  Future<void> unpause();
  Future<void> seek(Duration position);
}

/// Synchronise un lecteur avec la soirée (même logique que l'appli Windows) : ordres appliqués à
/// l'heure prévue, « prêt » et mise en mémoire tampon signalés, dérive rattrapée par la vitesse ou
/// par un saut. Les actions de l'utilisateur deviennent des demandes au groupe.
class SyncPlayPlayback {
  SyncPlayPlayback(this.target, this.requests, this.time, this.playlistItemId);

  /// Au-delà : saut direct à la bonne position.
  static const skipThreshold = Duration(milliseconds: 800);

  /// Au-delà : rattrapage en douceur par la vitesse de lecture.
  static const speedThreshold = Duration(milliseconds: 120);

  /// Une coupure plus courte n'est pas signalée au groupe.
  static const stallThreshold = Duration(milliseconds: 700);

  /// Temps laissé au lecteur après un départ ou un saut avant de mesurer la dérive.
  static const settleTime = Duration(seconds: 2);

  final SyncTarget target;
  final SyncRequests requests;
  final TimeSync time;
  String playlistItemId;

  (DateTime when, Duration position)? _playingFrom;
  DateTime? _pendingUnpause;
  DateTime? _stallSince;
  DateTime _settleUntil = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  bool _speedAdjusted = false;
  bool _buffering = false;
  bool _waitingForSeek = false;
  bool _readyAfterSeekPlaying = false;

  /// Écart mesuré au dernier contrôle (positif : en avance sur le groupe).
  Duration drift = Duration.zero;

  /// Le groupe attend (préparation, mise en tampon d'un participant…).
  bool waiting = true;

  /// Titre chargé et position de départ atteinte : prêt pour le groupe.
  Future<void> loaded({required bool isPlaying}) =>
      requests.ready(target.position, isPlaying: isPlaying, playlistItemId: playlistItemId);

  void apply(SyncCommand command) {
    if (command.kind != SyncCommandKind.stop && command.playlistItemId != playlistItemId) {
      return;
    }
    switch (command.kind) {
      case SyncCommandKind.unpause:
        waiting = false;
        _playingFrom = (command.when, command.position);
        final start = time.toLocal(command.when);
        final now = time.localNow;
        if (start.isAfter(now)) {
          // Départ dans le futur : en pause à la bonne position jusqu'à l'heure prévue.
          target.pause();
          _seekIfFar(command.position, const Duration(milliseconds: 250));
          _pendingUnpause = start;
        } else {
          // En retard : on part directement là où en est le groupe.
          _seekIfFar(command.position + now.difference(start), const Duration(milliseconds: 250));
          target.play();
          _pendingUnpause = null;
          _settleUntil = now.add(settleTime);
        }
      case SyncCommandKind.pause:
        _playingFrom = null;
        _pendingUnpause = null;
        _resetSpeed();
        target.pause();
        _seekIfFar(command.position, const Duration(milliseconds: 200));
      case SyncCommandKind.seek:
        _readyAfterSeekPlaying = _playingFrom != null || !target.paused;
        _playingFrom = null;
        _pendingUnpause = null;
        _resetSpeed();
        waiting = true;
        target.pause();
        target.seek(command.position);
        _waitingForSeek = true;
      case SyncCommandKind.stop:
        _playingFrom = null;
        _pendingUnpause = null;
        _resetSpeed();
        target.pause();
    }
  }

  /// Le lecteur a fini de se positionner après un saut demandé par le groupe.
  void onSeekCompleted() {
    if (!_waitingForSeek) return;
    _waitingForSeek = false;
    unawaited(requests.ready(target.position, isPlaying: _readyAfterSeekPlaying, playlistItemId: playlistItemId));
  }

  /// Lecture arrêtée faute de données : au-delà de [stallThreshold], le groupe attend ce participant.
  void onBuffering(bool stalled) {
    if (stalled) {
      _stallSince ??= time.localNow;
      return;
    }
    _stallSince = null;
    if (!_buffering) return;
    _buffering = false;
    _settleUntil = time.localNow.add(settleTime);
    unawaited(requests.ready(target.position, isPlaying: _playingFrom != null, playlistItemId: playlistItemId));
  }

  /// À appeler régulièrement (≈ 4 fois par seconde) : départ programmé et rattrapage de dérive.
  void tick() {
    final now = time.localNow;
    final since = _stallSince;
    if (since != null && !_buffering && now.difference(since) >= stallThreshold) {
      _buffering = true;
      unawaited(requests.buffering(target.position, isPlaying: _playingFrom != null, playlistItemId: playlistItemId));
    }
    final at = _pendingUnpause;
    if (at != null && !now.isBefore(at)) {
      _pendingUnpause = null;
      target.play();
      _settleUntil = now.add(settleTime);
      return;
    }
    final from = _playingFrom;
    if (from == null || _buffering || target.paused || _pendingUnpause != null || now.isBefore(_settleUntil)) {
      return;
    }
    final expected = from.$2 + time.serverNow.difference(from.$1);
    drift = target.position - expected;
    final gap = drift.abs();
    if (gap > skipThreshold) {
      _resetSpeed();
      target.seek(expected);
      _settleUntil = now.add(settleTime);
    } else if (gap > speedThreshold) {
      // En avance : on ralentit un peu ; en retard : on accélère un peu (imperceptible).
      target.setRate(drift > Duration.zero ? 0.95 : 1.05);
      _speedAdjusted = true;
    } else if (_speedAdjusted && gap < const Duration(milliseconds: 40)) {
      _resetSpeed();
    }
  }

  void _resetSpeed() {
    if (!_speedAdjusted) return;
    _speedAdjusted = false;
    target.setRate(1);
  }

  void _seekIfFar(Duration position, Duration tolerance) {
    if ((target.position - position).abs() > tolerance) target.seek(position);
  }

  // ------------------------------------------------------------ Actions de l'utilisateur

  Future<void> requestTogglePlay() =>
      _playingFrom != null || _pendingUnpause != null ? requests.pause() : requests.unpause();
  Future<void> requestSeek(Duration position) => requests.seek(position);

  void onGroupState(GroupState state) => waiting = state == GroupState.waiting;

  /// Le groupe passe à un autre élément de la file.
  void changeItem(String id) {
    playlistItemId = id;
    _playingFrom = null;
    _pendingUnpause = null;
    waiting = true;
    _resetSpeed();
  }
}
