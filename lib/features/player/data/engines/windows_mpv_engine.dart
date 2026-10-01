import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:optifin_native_player/optifin_native_player.dart' show WindowsMpv;

import '../../../../core/logging/app_log.dart';
import '../../domain/playback_engine.dart';

/// Moteur de Windows : libmpv pilotée en natif (plugin `optifin_native_player`).
///
/// Contrairement à media_kit (image copiée dans une texture Flutter, toujours en SDR), la
/// vidéo est affichée par mpv lui-même (gpu-next, Direct3D 11) dans une fenêtre placée sous
/// l'interface : HDR10, HLG et Dolby Vision partent tels quels vers un écran HDR, et le
/// décodage matériel (D3D11VA) n'a aucune copie à faire. [buildView] n'est qu'une zone
/// transparente : c'est à travers elle que la vidéo se voit.
class WindowsMpvEngine implements PlaybackEngine, VolumeControl {
  WindowsMpvEngine._(this._mpv) {
    _subscription = _mpv.events.listen(_onEvent);
    _dropTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollDroppedFrames());
  }

  static Future<WindowsMpvEngine> create() async {
    final engine = WindowsMpvEngine._(await WindowsMpv.create());
    final mode = await engine._mpv.layoutMode();
    AppLog.i('mpv', 'Création du moteur Windows (libmpv natif, gpu-next Direct3D 11, assemblage mode $mode)');
    // Volume retenu d'une lecture à l'autre (le temps de la session).
    await engine.setVolume(_lastVolume);
    return engine;
  }

  final WindowsMpv _mpv;
  late final StreamSubscription<Map<String, Object?>> _subscription;
  Timer? _dropTimer;
  final _snapshots = StreamController<PlayerSnapshot>.broadcast();
  final _events = StreamController<PlaybackEvent>.broadcast();
  PlayerSnapshot _snapshot = const PlayerSnapshot();
  bool _started = false;
  bool _paused = false;
  bool _cache = false;
  bool _seeking = false;
  double? _width;
  double? _height;
  EngineMedia? _media;
  BoxFit? _fit;

  void _emit(PlayerSnapshot s) {
    _snapshot = s;
    if (!_snapshots.isClosed) _snapshots.add(s);
  }

  static Duration _seconds(Object? v) =>
      v is double && v.isFinite ? Duration(microseconds: (v * 1e6).round()) : Duration.zero;

  void _onEvent(Map<String, Object?> e) {
    switch (e['event']) {
      case 'prop':
        _onProperty(e['name'] as String?, e['value']);
      case 'file-loaded':
        unawaited(_selectInitialTracks());
      case 'end-file':
        final reason = e['reason'];
        if (reason == 'eof') {
          _emit(_snapshot.copyWith(status: PlaybackStatus.ended, playing: false));
          _events.add(const PlaybackCompleted());
        } else if (reason == 'error') {
          final message = '${e['error'] ?? 'lecture impossible'}';
          AppLog.w('mpv', 'Erreur : $message');
          _emit(_snapshot.copyWith(status: PlaybackStatus.error, error: message));
          _events.add(PlaybackFailed(message, duringStartup: !_started));
        }
      case 'log':
        final level = switch (e['level']) {
          'fatal' || 'error' => LogLevel.error,
          'warn' => LogLevel.warning,
          _ => LogLevel.info,
        };
        AppLog.instance.add(level, 'mpv', '[${e['prefix']}] ${e['text']}');
    }
  }

  void _onProperty(String? name, Object? value) {
    switch (name) {
      case 'time-pos':
        _emit(_snapshot.copyWith(position: _seconds(value)));
      case 'duration':
        final d = _seconds(value);
        if (d > Duration.zero) {
          _started = true;
          _emit(_snapshot.copyWith(duration: d, status: PlaybackStatus.ready));
        }
      case 'pause':
        _paused = value == true;
        _emit(_snapshot.copyWith(playing: !_paused));
      case 'paused-for-cache':
        _cache = value == true;
        _emit(_snapshot.copyWith(buffering: _cache || _seeking));
      case 'seeking':
        _seeking = value == true;
        _emit(_snapshot.copyWith(buffering: _cache || _seeking));
      case 'demuxer-cache-time':
        _emit(_snapshot.copyWith(buffered: _seconds(value)));
      case 'speed':
        if (value is double) _emit(_snapshot.copyWith(rate: value));
      case 'dwidth':
        _width = value is double ? value : null;
        _updateSize();
      case 'dheight':
        _height = value is double ? value : null;
        _updateSize();
    }
  }

  void _updateSize() {
    final w = _width;
    final h = _height;
    if (w != null && h != null && w > 0 && h > 0) _emit(_snapshot.copyWith(videoSize: Size(w, h)));
  }

  Future<void> _pollDroppedFrames() async {
    if (!_snapshot.playing) return;
    try {
      final vo = int.tryParse(await _mpv.getProperty('frame-drop-count') ?? '') ?? 0;
      final decoder = int.tryParse(await _mpv.getProperty('decoder-frame-drop-count') ?? '') ?? 0;
      _emit(_snapshot.copyWith(droppedFrames: vo + decoder));
    } catch (_) {
      // Propriété indisponible : rien à afficher.
    }
  }

  Future<void> _set(String name, String value) async {
    try {
      await _mpv.setProperty(name, value);
    } catch (e) {
      AppLog.d('mpv', 'Propriété $name refusée : $e');
    }
  }

  // ------------------------------------------------------------ Pistes

  /// Identifiants mpv des pistes d'un type, dans l'ordre du fichier (hors pistes externes).
  Future<List<String>> _trackIds(String type) async {
    final count = int.tryParse(await _mpv.getProperty('track-list/count') ?? '') ?? 0;
    final ids = <String>[];
    for (var i = 0; i < count; i++) {
      if (await _mpv.getProperty('track-list/$i/type') != type) continue;
      if (await _mpv.getProperty('track-list/$i/external') == 'yes') continue;
      final id = await _mpv.getProperty('track-list/$i/id');
      if (id != null) ids.add(id);
    }
    return ids;
  }

  Future<void> _selectInitialTracks() async {
    final media = _media;
    if (media == null) return;
    if (media.audioOrdinal != null) await selectAudio(media.audioOrdinal);
    final external = media.externalSubtitle;
    if (external != null) {
      await addExternalSubtitle(external.url, title: external.title, language: external.language);
    } else {
      await selectSubtitle(media.subtitleOrdinal);
    }
  }

  // ------------------------------------------------------------ PlaybackEngine

  @override
  String get name => 'mpv';

  @override
  EngineCapabilities get capabilities => const EngineCapabilities(
    hdr: true,
    dolbyVision: true,
    assRendering: true,
    bitmapSubtitles: true,
    externalSubtitles: true,
    subtitleStyling: true,
    subtitleDelay: true,
    audioDelay: true,
  );

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<PlaybackEvent> get events => _events.stream;

  @override
  Future<void> open(EngineMedia media) async {
    _media = media;
    _started = false;
    _paused = false;
    // mpv ne renvoie une propriété que si elle change : l'état connu est conservé.
    _emit(PlayerSnapshot(status: PlaybackStatus.loading, playing: true, rate: _snapshot.rate));
    // En-têtes (Authorization) ajoutés un par un : aucune découpe sur les virgules, et
    // jamais de token dans l'URL ni dans les journaux.
    await _mpv.command(['change-list', 'http-header-fields', 'clr', '']);
    for (final h in media.headers.entries) {
      await _mpv.command(['change-list', 'http-header-fields', 'append', '${h.key}: ${h.value}']);
    }
    await _set('user-agent', 'OptiFin');
    await _set('pause', 'no');
    if (media.title != null) await _set('force-media-title', media.title!);
    final start = (media.start.inMilliseconds / 1000).toStringAsFixed(3);
    await _mpv.command(['loadfile', media.url.toString(), 'replace', '-1', 'start=$start']);
  }

  @override
  Future<void> play() => _set('pause', 'no');

  @override
  Future<void> pause() => _set('pause', 'yes');

  @override
  Future<void> seek(Duration position) =>
      _mpv.command(['seek', (position.inMilliseconds / 1000).toStringAsFixed(3), 'absolute']);

  @override
  Future<void> setRate(double rate) => _set('speed', rate.toStringAsFixed(2));

  @override
  Future<void> selectAudio(int? ordinal) async {
    final ids = await _trackIds('audio');
    await _set('aid', ordinal == null || ordinal >= ids.length ? 'auto' : ids[ordinal]);
  }

  @override
  Future<void> selectSubtitle(int? ordinal) async {
    final ids = await _trackIds('sub');
    await _set('sid', ordinal == null || ordinal >= ids.length ? 'no' : ids[ordinal]);
  }

  @override
  Future<void> addExternalSubtitle(Uri url, {String? title, String? language}) =>
      _mpv.command(['sub-add', url.toString(), 'select', title ?? '', language ?? '']);

  @override
  Future<void> setSubtitleStyle(SubtitleStyle style) async {
    String hex(Color c) =>
        '#${[c.a, c.r, c.g, c.b].map((v) => (v * 255).round().toRadixString(16).padLeft(2, '0')).join()}';
    await _set('sub-scale', style.scale.toStringAsFixed(2));
    await _set('sub-color', hex(style.color));
    await _set('sub-margin-y', (style.bottomMargin * 720).round().toString());
    switch (style.background) {
      case SubtitleBackground.none:
        await _set('sub-border-style', 'outline-and-shadow');
        await _set('sub-border-size', '2.5');
        await _set('sub-shadow-offset', '0');
      case SubtitleBackground.shadow:
        await _set('sub-border-style', 'outline-and-shadow');
        await _set('sub-border-size', '1.5');
        await _set('sub-shadow-offset', '2');
      case SubtitleBackground.box:
        await _set('sub-border-style', 'opaque-box');
        await _set('sub-back-color', '#99000000');
    }
  }

  @override
  Future<void> setSubtitleDelay(Duration delay) => _set('sub-delay', (delay.inMilliseconds / 1000).toStringAsFixed(3));

  @override
  Future<void> setAudioDelay(Duration delay) => _set('audio-delay', (delay.inMilliseconds / 1000).toStringAsFixed(3));

  @override
  Future<bool> enterPictureInPicture() async => false;

  static double _lastVolume = 1;
  double _volume = 1;
  bool _muted = false;

  @override
  double get volume => _volume;

  @override
  bool get muted => _muted;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    _lastVolume = _volume;
    await _set('volume', (_volume * 100).toStringAsFixed(0));
    if (_muted && _volume > 0) await setMuted(false);
  }

  @override
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    await _set('mute', muted ? 'yes' : 'no');
  }

  /// Assemblage de la vidéo et de l'interface suivant (touche V) : selon le pilote graphique,
  /// un seul des modes affiche l'image ; il est retenu pour les lectures suivantes.
  Future<int> cycleVideoLayout() async {
    final mode = await _mpv.cycleLayoutMode();
    AppLog.i('mpv', 'Assemblage vidéo : mode $mode');
    return mode;
  }

  /// Format de l'image : fait par mpv (la vidéo n'est pas une texture Flutter).
  void _applyFit(BoxFit fit) {
    if (fit == _fit) return;
    _fit = fit;
    unawaited(_set('keepaspect', fit == BoxFit.fill ? 'no' : 'yes'));
    unawaited(_set('panscan', fit == BoxFit.cover ? '1.0' : '0.0'));
  }

  @override
  Widget buildView({BoxFit fit = BoxFit.contain}) => _MpvWindowSurface(engine: this, fit: fit);

  @override
  Future<void> dispose() async {
    _dropTimer?.cancel();
    await _subscription.cancel();
    try {
      await _mpv.setVisible(false);
      await _mpv.command(['stop']);
    } catch (_) {}
    await _mpv.dispose();
    await _snapshots.close();
    await _events.close();
  }
}

/// Zone transparente : la vidéo native est dessous. Applique le format demandé.
class _MpvWindowSurface extends StatelessWidget {
  const _MpvWindowSurface({required this.engine, required this.fit});

  final WindowsMpvEngine engine;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    engine._applyFit(fit);
    return const SizedBox.expand();
  }
}
