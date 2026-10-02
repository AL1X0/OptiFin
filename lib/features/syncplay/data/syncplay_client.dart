import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/logging/app_log.dart';
import '../../player/data/playback_repository.dart';
import '../domain/syncplay_models.dart';
import '../domain/syncplay_sync.dart';

/// Soirées (SyncPlay de Jellyfin) : connexion temps réel au serveur (/socket, jeton dans l'en-tête
/// Authorization, jamais dans l'URL), maintien et reconnexion automatique, horloge du serveur, et
/// requêtes du groupe. Les messages reçus sont diffusés par [messages].
class SyncPlayClient implements SyncRequests {
  SyncPlayClient({
    required this.dio,
    required this.baseUrl,
    required this.authorization,
    TimeSync? time,
  }) : time = time ?? TimeSync();

  /// Requêtes authentifiées de la session.
  final Dio dio;
  final Uri baseUrl;

  /// En-tête Authorization (avec le jeton) de la connexion temps réel.
  final String Function() authorization;
  final TimeSync time;

  final _messages = StreamController<SyncPlayMessage>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  WebSocket? _socket;
  Timer? _keepAlive;
  bool _closed = false;
  bool connected = false;
  int _keepAliveSeconds = 30;

  /// Soirée rejointe (null hors soirée).
  GroupInfo? group;

  Stream<SyncPlayMessage> get messages => _messages.stream;
  Stream<bool> get connectionChanges => _connection.stream;

  /// Lance la connexion temps réel (en arrière-plan, avec reconnexion).
  void start() => unawaited(_run());

  // ------------------------------------------------------------ Requêtes

  Future<List<GroupInfo>> list() async {
    final r = await dio.get<List<dynamic>>('/SyncPlay/List');
    return [
      for (final g in r.data ?? const [])
        if (g is Map<String, dynamic>) GroupInfo.fromJson(g),
    ];
  }

  Future<void> create(String name) =>
      _post('/SyncPlay/New', {'GroupName': name});
  Future<void> join(String groupId) =>
      _post('/SyncPlay/Join', {'GroupId': groupId});

  Future<void> leave() async {
    await _post('/SyncPlay/Leave');
    group = null;
  }

  /// Nouvelle file partagée : tous les participants ouvrent le titre à cette position.
  Future<void> setQueue(
    List<String> itemIds, {
    int index = 0,
    Duration start = Duration.zero,
  }) => _post('/SyncPlay/SetNewQueue', {
    'PlayingQueue': itemIds,
    'PlayingItemPosition': index,
    'StartPositionTicks': durationToTicks(start),
  });

  @override
  Future<void> pause() => _post('/SyncPlay/Pause');

  @override
  Future<void> unpause() => _post('/SyncPlay/Unpause');

  /// Arrêt de la lecture pour tout le groupe.
  Future<void> stop() => _post('/SyncPlay/Stop');

  @override
  Future<void> seek(Duration position) =>
      _post('/SyncPlay/Seek', {'PositionTicks': durationToTicks(position)});

  @override
  Future<void> ready(
    Duration position, {
    required bool isPlaying,
    required String playlistItemId,
  }) => _post('/SyncPlay/Ready', _state(position, isPlaying, playlistItemId));

  @override
  Future<void> buffering(
    Duration position, {
    required bool isPlaying,
    required String playlistItemId,
  }) =>
      _post('/SyncPlay/Buffering', _state(position, isPlaying, playlistItemId));

  Map<String, Object> _state(
    Duration position,
    bool isPlaying,
    String playlistItemId,
  ) => {
    'When': time.serverNow.toIso8601String(),
    'PositionTicks': durationToTicks(position),
    'IsPlaying': isPlaying,
    'PlaylistItemId': playlistItemId,
  };

  Future<void> _post(String path, [Map<String, Object>? body]) async {
    try {
      await dio.post<void>(path, data: body);
    } on DioException catch (e) {
      AppLog.w('syncplay', '$path : ${e.response?.statusCode ?? e.type.name}');
      rethrow;
    }
  }

  /// Mesure l'horloge du serveur (plusieurs allers-retours, le plus court gagne).
  Future<void> syncTime({int samples = 4}) async {
    for (var i = 0; i < samples; i++) {
      final t0 = time.localNow;
      final r = await dio.get<Map<String, dynamic>>('/GetUtcTime');
      final t3 = time.localNow;
      final data = r.data ?? const {};
      time.addSample(
        t0,
        parseServerTime(data['RequestReceptionTime']),
        parseServerTime(data['ResponseTransmissionTime']),
        t3,
      );
      if (i + 1 < samples) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
  }

  // ------------------------------------------------------------ Connexion temps réel

  Future<void> _run() async {
    var backoff = const Duration(seconds: 2);
    while (!_closed) {
      try {
        final url = PlaybackRepository.resolve(
          baseUrl,
          'socket',
        ).replace(scheme: baseUrl.scheme == 'https' ? 'wss' : 'ws');
        final socket = await WebSocket.connect(
          url.toString(),
          headers: {'Authorization': authorization()},
        ).timeout(const Duration(seconds: 15));
        if (_closed) {
          await socket.close();
          return;
        }
        _socket = socket;
        _setConnected(true);
        backoff = const Duration(seconds: 2);
        AppLog.i('syncplay', 'Connexion temps réel établie');
        unawaited(
          syncTime().catchError(
            (Object e) =>
                AppLog.d('syncplay', 'Horloge du serveur indisponible : $e'),
          ),
        );
        _scheduleKeepAlive();
        await for (final data in socket) {
          if (data is String) _handle(data);
        }
      } catch (e) {
        AppLog.d('syncplay', 'Connexion temps réel interrompue : $e');
      }
      _keepAlive?.cancel();
      _socket = null;
      _setConnected(false);
      if (_closed) return;
      await Future<void>.delayed(backoff);
      backoff = Duration(seconds: (backoff.inSeconds * 2).clamp(2, 30));
    }
  }

  void _scheduleKeepAlive() {
    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(Duration(seconds: _keepAliveSeconds), (_) {
      try {
        _socket?.add(jsonEncode({'MessageType': 'KeepAlive'}));
      } catch (_) {
        // Fin de connexion : la boucle principale reconnecte.
      }
    });
  }

  void _setConnected(bool value) {
    if (connected == value) return;
    connected = value;
    if (!_connection.isClosed) _connection.add(value);
  }

  void _handle(String raw) {
    final msg = parseSyncPlayMessage(raw);
    final current = group;
    switch (msg) {
      case null:
        return;
      case KeepAliveRequest(:final seconds):
        _keepAliveSeconds = (seconds ~/ 2).clamp(5, 60);
        _scheduleKeepAlive();
        return;
      case GroupJoined(group: final g):
        group = g;
      case GroupLeft():
        group = null;
      case UserJoined(:final userName)
          when current != null && !current.participants.contains(userName):
        group = current.copyWith(
          participants: [...current.participants, userName],
        );
      case UserLeft(:final userName) when current != null:
        group = current.copyWith(
          participants: [
            for (final p in current.participants)
              if (p != userName) p,
          ],
        );
      case StateChanged(:final state) when current != null:
        group = current.copyWith(state: state);
      case SyncPlayError(:final kind)
          when kind == 'NotInGroup' || kind == 'GroupDoesNotExist':
        group = null;
      default:
        break;
    }
    if (!_messages.isClosed) _messages.add(msg);
  }

  Future<void> dispose() async {
    _closed = true;
    _keepAlive?.cancel();
    try {
      await _socket?.close();
    } catch (_) {}
    await _messages.close();
    await _connection.close();
  }
}
