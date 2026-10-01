import 'dart:async';

import 'package:flutter/services.dart';

/// Lecteur libmpv natif de Windows : la vidéo est dessinée par mpv (gpu-next, Direct3D 11,
/// HDR) dans une fenêtre placée **sous** la vue Flutter. L'interface doit donc rester
/// transparente là où la vidéo doit se voir.
///
/// Événements ([events]) : `{'event': 'prop', 'name', 'value'}` (propriétés observées :
/// time-pos, duration, pause, paused-for-cache, seeking, eof-reached, demuxer-cache-time,
/// speed, dwidth, dheight, core-idle), `file-loaded`, `end-file` (`reason` : eof / error /
/// stop, `error`), `log` (`level`, `prefix`, `text`).
class WindowsMpv {
  WindowsMpv._(this.id) : _channel = MethodChannel('optifin_native_player/mpv_$id') {
    _subscription = EventChannel('optifin_native_player/mpv_events_$id').receiveBroadcastStream().listen((e) {
      if (e is Map) _events.add(Map<String, Object?>.from(e));
    }, onError: (Object e) => _events.add({'event': 'end-file', 'reason': 'error', 'error': '$e'}));
  }

  static const _plugin = MethodChannel('optifin_native_player');

  /// Crée le lecteur (charge libmpv à la première fois). Un seul lecteur à la fois.
  static Future<WindowsMpv> create() async {
    final id = await _plugin.invokeMethod<int>('mpvCreate');
    if (id == null) throw PlatformException(code: 'mpv', message: 'Lecteur mpv indisponible');
    return WindowsMpv._(id);
  }

  final int id;
  final MethodChannel _channel;
  late final StreamSubscription<Object?> _subscription;
  final _events = StreamController<Map<String, Object?>>.broadcast();
  bool _disposed = false;

  Stream<Map<String, Object?>> get events => _events.stream;

  /// Commande mpv (ex. `['loadfile', url, 'replace', '0', 'start=12']`).
  Future<void> command(List<String> args) async {
    if (_disposed) return;
    await _channel.invokeMethod<void>('command', {'args': args});
  }

  Future<void> setProperty(String name, String value) async {
    if (_disposed) return;
    await _channel.invokeMethod<void>('setProperty', {'name': name, 'value': value});
  }

  Future<String?> getProperty(String name) async {
    if (_disposed) return null;
    return _channel.invokeMethod<String>('getProperty', {'name': name});
  }

  /// Assemblage vidéo / interface suivant (0 → 1 → 2 → 0), mémorisé pour les lectures
  /// suivantes ; renvoie le mode actif. Voir `MpvPlayer::SetLayoutMode` côté C++.
  Future<int> cycleLayoutMode() async {
    if (_disposed) return 0;
    return await _channel.invokeMethod<int>('setLayoutMode', <String, Object?>{}) ?? 0;
  }

  Future<int> layoutMode() async {
    if (_disposed) return 0;
    return await _channel.invokeMethod<int>('getLayoutMode') ?? 0;
  }

  /// Affiche ou masque la fenêtre vidéo (affichée d'elle-même à la première image).
  Future<void> setVisible(bool visible) async {
    if (_disposed) return;
    await _channel.invokeMethod<void>('setVisible', {'visible': visible});
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _channel.invokeMethod<void>('dispose');
    } finally {
      await _subscription.cancel();
      await _events.close();
    }
  }
}
