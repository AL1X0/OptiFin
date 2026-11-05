import 'package:flutter/services.dart';

/// Appareil Chromecast trouvé sur le réseau.
class CastDevice {
  const CastDevice(this.id, this.name);
  final String id;
  final String name;
}

/// État de la diffusion en cours.
class CastState {
  const CastState({
    this.connected = false,
    this.device,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.paused = false,
    this.finished = false,
    this.failed = false,
  });

  final bool connected;
  final String? device;
  final Duration position;
  final Duration duration;
  final bool paused;
  final bool finished;
  final bool failed;
}

/// Chromecast par le SDK Google Cast. Android uniquement pour l'instant : ailleurs [available]
/// renvoie faux (iOS a AirPlay) et les fonctions ne sont pas appelées.
abstract final class Chromecast {
  static const _channel = MethodChannel('optifin_native_player/cast');

  static Future<bool> available() async {
    try {
      return await _channel.invokeMethod<bool>('available') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> startDiscovery() => _channel.invokeMethod<void>('startDiscovery');
  static Future<void> stopDiscovery() => _channel.invokeMethod<void>('stopDiscovery');

  static Future<List<CastDevice>> devices() async {
    final list = await _channel.invokeListMethod<Map<Object?, Object?>>('devices') ?? const [];
    return [for (final d in list) CastDevice('${d['id']}', '${d['name']}')];
  }

  static Future<bool> connect(String id) async => await _channel.invokeMethod<bool>('connect', {'id': id}) ?? false;

  /// Faux tant que la session n'est pas ouverte : à réessayer.
  static Future<bool> load({
    required Uri url,
    required String contentType,
    required String title,
    Uri? image,
    Duration position = Duration.zero,
  }) async =>
      await _channel.invokeMethod<bool>('load', {
        'url': url.toString(),
        'contentType': contentType,
        'title': title,
        'image': image?.toString(),
        'positionMs': position.inMilliseconds,
      }) ??
      false;

  static Future<CastState> state() async {
    final m = await _channel.invokeMapMethod<String, Object?>('state') ?? const {};
    return CastState(
      connected: m['connected'] == true,
      device: m['device'] as String?,
      position: Duration(milliseconds: (m['positionMs'] as num?)?.toInt() ?? 0),
      duration: Duration(milliseconds: (m['durationMs'] as num?)?.toInt() ?? 0),
      paused: m['paused'] == true,
      finished: m['finished'] == true,
      failed: m['error'] == true,
    );
  }

  static Future<void> play() => _channel.invokeMethod<void>('play');
  static Future<void> pause() => _channel.invokeMethod<void>('pause');
  static Future<void> seek(Duration position) => _channel.invokeMethod<void>('seek', {'ms': position.inMilliseconds});
  static Future<void> disconnect() => _channel.invokeMethod<void>('disconnect');
}
