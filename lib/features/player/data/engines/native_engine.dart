import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:optifin_native_player/optifin_native_player.dart';

import '../../../../core/logging/app_log.dart';
import '../../domain/device_capabilities.dart';
import '../../domain/playback_engine.dart';
import '../../domain/subtitle_cues.dart';
import 'subtitle_overlay.dart';

/// Télécharge un fichier de sous-titres (avec l'authentification du serveur).
typedef SubtitleLoader = Future<String> Function(Uri url);

/// Moteur natif : AVPlayer (iOS) ou Media3/ExoPlayer (Android), via le plugin
/// `optifin_native_player`. Rendu HDR10 / Dolby Vision par le système, décodage
/// matériel, faible consommation.
///
/// Les sous-titres texte sont servis par Jellyfin en WebVTT et dessinés par
/// [SubtitleOverlay] : même style que mpv, décalage réglable, sur les deux plateformes.
class NativeEngine implements PlaybackEngine {
  NativeEngine._(this._player, this._device, this._loadSubtitle) {
    _subscription = _player.events.listen(_onEvent);
  }

  static Future<NativeEngine> create({required DeviceCapabilities device, required SubtitleLoader loadSubtitle}) async {
    final player = await NativePlayers.create();
    AppLog.i('native', 'Création du moteur ${_nameFor(device)} (lecteur #${player.id})');
    return NativeEngine._(player, device, loadSubtitle);
  }

  final NativePlayer _player;
  final DeviceCapabilities _device;
  final SubtitleLoader _loadSubtitle;
  StreamSubscription<Object?>? _subscription;
  final _snapshots = StreamController<PlayerSnapshot>.broadcast();
  final _events = StreamController<PlaybackEvent>.broadcast();
  PlayerSnapshot _snapshot = const PlayerSnapshot();
  bool _completed = false;

  final _cues = ValueNotifier<CueTrack?>(null);
  final _clock = ValueNotifier<PlaybackClock>(PlaybackClock(Duration.zero, at: monotonicMicros()));
  final _style = ValueNotifier<SubtitleStyle>(const SubtitleStyle());
  final _subtitleDelay = ValueNotifier<Duration>(Duration.zero);
  int _subtitleRequest = 0;
  String? _fit;

  static String _nameFor(DeviceCapabilities d) => d.platform == DevicePlatform.ios ? 'AVPlayer' : 'Media3';

  @override
  String get name => _nameFor(_device);

  @override
  EngineCapabilities get capabilities => EngineCapabilities(
    hdr: true,
    dolbyVision: _device.supportsDolbyVision,
    externalSubtitles: true,
    subtitleStyling: true,
    subtitleDelay: true,
    embeddedSubtitles: false,
  );

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<PlaybackEvent> get events => _events.stream;

  void _emit(PlayerSnapshot s) {
    _snapshot = s;
    _clock.value = PlaybackClock(s.position, playing: s.playing && !s.buffering, rate: s.rate, at: monotonicMicros());
    if (!_snapshots.isClosed) _snapshots.add(s);
  }

  void _onEvent(Map<String, Object?> e) {
    switch (e['event']) {
      case 'state':
        final next = snapshotFromEvent(e, _snapshot);
        _emit(next);
      case 'completed':
        if (_completed) return;
        _completed = true;
        _emit(_snapshot.copyWith(status: PlaybackStatus.ended, playing: false));
        if (!_events.isClosed) _events.add(const PlaybackCompleted());
      case 'error':
        final message = '${e['message'] ?? 'erreur inconnue'}';
        final startup = e['startup'] == true;
        AppLog.w('native', '$name : $message');
        _emit(_snapshot.copyWith(status: PlaybackStatus.error, error: message));
        if (!_events.isClosed) _events.add(PlaybackFailed(message, duringStartup: startup));
    }
  }

  /// Traduit un événement `state` du plugin en [PlayerSnapshot]. Pur, testé.
  static PlayerSnapshot snapshotFromEvent(Map<String, Object?> e, PlayerSnapshot previous) {
    Duration ms(String key) => Duration(milliseconds: (e[key] as num?)?.round() ?? 0);
    final width = (e['width'] as num?)?.toDouble() ?? 0;
    final height = (e['height'] as num?)?.toDouble() ?? 0;
    return PlayerSnapshot(
      status: switch (e['status']) {
        'ready' => PlaybackStatus.ready,
        'ended' => PlaybackStatus.ended,
        _ => PlaybackStatus.loading,
      },
      playing: e['playing'] == true,
      buffering: e['buffering'] == true,
      position: ms('positionMs'),
      duration: ms('durationMs'),
      buffered: ms('bufferedMs'),
      rate: (e['rate'] as num?)?.toDouble() ?? previous.rate,
      videoSize: width > 0 && height > 0 ? Size(width, height) : previous.videoSize,
      droppedFrames: (e['droppedFrames'] as num?)?.toInt(),
    );
  }

  @override
  Future<void> open(EngineMedia media) async {
    _completed = false;
    _cues.value = null;
    _emit(PlayerSnapshot(status: PlaybackStatus.loading, position: media.start, rate: _snapshot.rate));
    final external = media.externalSubtitle;
    if (external != null) unawaited(addExternalSubtitle(external.url));
    await _player.open(url: media.url, headers: media.headers, start: media.start, audioOrdinal: media.audioOrdinal);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) async {
    final c = _clock.value;
    _clock.value = PlaybackClock(position, playing: c.playing, rate: c.rate, at: monotonicMicros());
    await _player.seek(position);
  }

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  Future<void> selectAudio(int? ordinal) => _player.selectAudio(ordinal);

  /// Seul « aucun » a un sens ici : les pistes intégrées passent par [addExternalSubtitle].
  @override
  Future<void> selectSubtitle(int? ordinal) async {
    _subtitleRequest++;
    _cues.value = null;
  }

  @override
  Future<void> addExternalSubtitle(Uri url, {String? title, String? language}) async {
    final request = ++_subtitleRequest;
    try {
      final cues = parseSubtitles(await _loadSubtitle(asWebVtt(url)));
      // Un autre choix a pu être fait pendant le téléchargement.
      if (request != _subtitleRequest) return;
      _cues.value = CueTrack(cues);
      AppLog.i('native', 'Sous-titres chargés : ${cues.length} répliques');
    } catch (e) {
      AppLog.w('native', 'Sous-titres illisibles ($url) : $e');
      if (request == _subtitleRequest) _cues.value = null;
    }
  }

  /// Le serveur convertit à la volée selon l'extension demandée : un ASS (styles
  /// non gérés ici) est redemandé en WebVTT ; SRT et VTT sont lus tels quels.
  static Uri asWebVtt(Uri url) {
    final segments = [...url.pathSegments];
    if (segments.isEmpty) return url;
    final last = segments.last;
    final match = RegExp(r'^Stream\.(\w+)$', caseSensitive: false).firstMatch(last);
    if (match == null) return url;
    final ext = match.group(1)!.toLowerCase();
    if (ext == 'vtt' || ext == 'srt') return url;
    segments[segments.length - 1] = 'Stream.vtt';
    return url.replace(pathSegments: segments);
  }

  @override
  Future<void> setSubtitleStyle(SubtitleStyle style) async => _style.value = style;

  @override
  Future<void> setSubtitleDelay(Duration delay) async => _subtitleDelay.value = delay;

  @override
  Future<void> setAudioDelay(Duration delay) async {}

  @override
  Widget buildView({BoxFit fit = BoxFit.contain}) {
    final mode = switch (fit) {
      BoxFit.cover => 'cover',
      BoxFit.fill => 'fill',
      _ => 'contain',
    };
    if (mode != _fit) {
      _fit = mode;
      unawaited(_player.setFit(mode));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF000000)),
        NativePlayerView(playerId: _player.id),
        SubtitleOverlay(track: _cues, clock: _clock, style: _style, delay: _subtitleDelay),
      ],
    );
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _player.dispose();
    await _snapshots.close();
    await _events.close();
    _cues.dispose();
    _clock.dispose();
    _style.dispose();
    _subtitleDelay.dispose();
  }
}
