import 'dart:async';

import 'package:flutter/services.dart';

/// Point d'entrée du plugin : détection des capacités, création de lecteurs.
abstract final class NativePlayers {
  static const _channel = MethodChannel('optifin_native_player');

  /// Capacités de décodage et d'affichage de l'appareil (voir `DeviceCapabilities`
  /// côté app). null si le plugin n'est pas disponible sur cette plateforme.
  static Future<Map<String, Object?>?> capabilities() async {
    try {
      return await _channel.invokeMapMethod<String, Object?>('capabilities');
    } on MissingPluginException {
      return null;
    }
  }

  /// Crée un lecteur natif. Ses événements sont écoutés immédiatement (aucun
  /// état n'est perdu entre la création et l'ouverture du média).
  static Future<NativePlayer> create() async {
    final id = await _channel.invokeMethod<int>('create');
    if (id == null) throw PlatformException(code: 'create', message: 'Lecteur natif indisponible');
    return NativePlayer._(id);
  }
}

/// Lecteur natif piloté par identifiant. Les commandes sont asynchrones ; l'état
/// remonte par [events] (maps `{'event': 'state' | 'error' | 'completed', ...}`).
class NativePlayer {
  NativePlayer._(this.id) : _channel = MethodChannel('optifin_native_player/player_$id') {
    _subscription = EventChannel('optifin_native_player/events_$id').receiveBroadcastStream().listen((e) {
      if (e is Map) _events.add(Map<String, Object?>.from(e));
    }, onError: (Object e) => _events.add({'event': 'error', 'message': '$e', 'startup': false}));
  }

  final int id;
  final MethodChannel _channel;
  final _events = StreamController<Map<String, Object?>>.broadcast();
  StreamSubscription<Object?>? _subscription;
  bool _disposed = false;

  Stream<Map<String, Object?>> get events => _events.stream;

  Future<void> _call(String method, [Map<String, Object?>? args]) async {
    if (_disposed) return;
    await _channel.invokeMethod<void>(method, args);
  }

  /// Ouvre [url] (en-têtes HTTP transmis à chaque requête, jamais dans l'URL)
  /// et démarre la lecture à [start].
  Future<void> open({
    required Uri url,
    Map<String, String> headers = const {},
    Duration start = Duration.zero,
    int? audioOrdinal,
  }) => _call('open', {
    'url': url.toString(),
    'headers': headers,
    'startMs': start.inMilliseconds,
    'audioOrdinal': audioOrdinal,
  });

  Future<void> play() => _call('play');
  Future<void> pause() => _call('pause');
  Future<void> seek(Duration position) => _call('seek', {'positionMs': position.inMilliseconds});
  Future<void> setRate(double rate) => _call('setRate', {'rate': rate});

  /// Piste audio par position parmi les pistes audio (null = choix automatique).
  Future<void> selectAudio(int? ordinal) => _call('selectAudio', {'ordinal': ordinal});

  /// Cadrage : `contain`, `cover` (zoom) ou `fill` (étirer).
  Future<void> setFit(String fit) => _call('setFit', {'fit': fit});

  Future<void> dispose() async {
    if (_disposed) return;
    try {
      await _call('dispose');
    } finally {
      _disposed = true;
      await _subscription?.cancel();
      await _events.close();
    }
  }
}
