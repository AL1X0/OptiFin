import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/logging/app_log.dart';
import '../../domain/playback_engine.dart';

/// Moteur libmpv (via media_kit) : lit quasiment tout (MKV, HEVC, AV1, DTS,
/// TrueHD, ASS, PGS…). Décodage matériel VideoToolbox / MediaCodec.
///
/// libmpv n'est chargé qu'à la première création d'un [MpvEngine] (jamais au
/// démarrage de l'app) : voir [MpvEngine.create].
class MpvEngine implements PlaybackEngine {
  MpvEngine._(this._player, this._video) {
    _subscriptions.addAll([
      _player.stream.playing.listen((v) => _emit(_snapshot.copyWith(playing: v))),
      _player.stream.buffering.listen((v) => _emit(_snapshot.copyWith(buffering: v))),
      _player.stream.position.listen((v) => _emit(_snapshot.copyWith(position: v))),
      _player.stream.buffer.listen((v) => _emit(_snapshot.copyWith(buffered: v))),
      _player.stream.rate.listen((v) => _emit(_snapshot.copyWith(rate: v))),
      _player.stream.duration.listen((v) {
        if (v > Duration.zero) {
          _started = true;
          _emit(_snapshot.copyWith(duration: v, status: PlaybackStatus.ready));
        }
      }),
      _player.stream.width.listen((_) => _updateSize()),
      _player.stream.height.listen((_) => _updateSize()),
      _player.stream.completed.listen((done) {
        if (!done) return;
        _emit(_snapshot.copyWith(status: PlaybackStatus.ended, playing: false));
        _events.add(const PlaybackCompleted());
      }),
      _player.stream.log.listen((log) => AppLog.instance.add(
            switch (log.level) {
              'fatal' || 'error' => LogLevel.error,
              'warn' => LogLevel.warning,
              'info' => LogLevel.info,
              _ => LogLevel.debug,
            },
            'mpv',
            '[${log.prefix}] ${log.text.trim()}',
          )),
      _player.stream.error.listen((message) {
        AppLog.w('mpv', 'Erreur : $message');
        // mpv signale aussi des erreurs non fatales (piste illisible…) une fois la lecture lancée.
        if (_started) return;
        _emit(_snapshot.copyWith(status: PlaybackStatus.error, error: message));
        _events.add(PlaybackFailed(message, duringStartup: true));
      }),
    ]);
  }

  static bool _initialized = false;

  /// Charge libmpv à la demande puis crée le moteur.
  /// [verbose] : logs mpv détaillés (mode debug).
  static Future<MpvEngine> create({bool verbose = false}) async {
    if (!_initialized) {
      MediaKit.ensureInitialized();
      _initialized = true;
    }
    AppLog.i('mpv', 'Création du moteur (libmpv, décodage matériel auto-safe)');
    final player = Player(
      configuration: PlayerConfiguration(
        title: 'OptiFin',
        // Sous-titres rendus par mpv/libass dans l'image : styles ASS et PGS fidèles.
        libass: true,
        // Tampon démuxeur généreux : remux 4K à haut débit sans à-coups.
        bufferSize: 96 * 1024 * 1024,
        logLevel: verbose ? MPVLogLevel.info : MPVLogLevel.warn,
      ),
    );
    final video = VideoController(
      player,
      configuration: const VideoControllerConfiguration(enableHardwareAcceleration: true, hwdec: 'auto-safe'),
    );
    final engine = MpvEngine._(player, video);
    await engine._configure();
    return engine;
  }

  final Player _player;
  final VideoController _video;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _snapshots = StreamController<PlayerSnapshot>.broadcast();
  final _events = StreamController<PlaybackEvent>.broadcast();
  PlayerSnapshot _snapshot = const PlayerSnapshot();
  bool _started = false;

  NativePlayer? get _native => _player.platform is NativePlayer ? _player.platform! as NativePlayer : null;

  Future<void> _set(String property, String value) async {
    try {
      await _native?.setProperty(property, value);
    } catch (_) {
      // Propriété inconnue de cette version de mpv : ignorée.
    }
  }

  Future<void> _configure() async {
    // libass sur Android n'a pas d'accès fontconfig : on lui donne les polices système,
    // sinon les sous-titres texte seraient invisibles.
    if (Platform.isAndroid) {
      await _set('sub-fonts-dir', '/system/fonts');
      await _set('sub-font', 'Roboto');
    }
    await _set('sub-ass-override', 'scale'); // garde les styles ASS, applique la taille choisie
    await _set('demuxer-readahead-secs', '30');
    await _set('cache', 'yes');
  }

  void _updateSize() {
    final w = _player.state.width;
    final h = _player.state.height;
    if (w != null && h != null && w > 0 && h > 0) {
      _emit(_snapshot.copyWith(videoSize: Size(w.toDouble(), h.toDouble())));
    }
  }

  void _emit(PlayerSnapshot s) {
    _snapshot = s;
    if (!_snapshots.isClosed) _snapshots.add(s);
  }

  @override
  String get name => 'mpv';

  @override
  EngineCapabilities get capabilities => const EngineCapabilities(
    hdr: true, // tone-mapping / passthrough selon l'appareil
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
    _started = false;
    _emit(const PlayerSnapshot(status: PlaybackStatus.loading));
    final tracksReady = _player.stream.tracks
        .firstWhere((t) => t.audio.length > 2 || t.video.length > 2)
        .timeout(const Duration(seconds: 20), onTimeout: () => _player.state.tracks);
    await _player.open(Media(media.url.toString(), httpHeaders: media.headers, start: media.start), play: true);
    // Les pistes ne sont connues qu'après le démuxage : sélection initiale ensuite.
    unawaited(
      tracksReady.then((_) async {
        if (media.audioOrdinal != null) await selectAudio(media.audioOrdinal);
        final external = media.externalSubtitle;
        if (external != null) {
          await addExternalSubtitle(external.url, title: external.title, language: external.language);
        } else {
          await selectSubtitle(media.subtitleOrdinal);
        }
      }),
    );
  }

  static bool _isPseudo(String id) => id == 'auto' || id == 'no';

  /// Pistes réelles du fichier (sans les pseudo-pistes « auto » / « no » de mpv ni les externes).
  List<AudioTrack> get _audioTracks => [
    for (final t in _player.state.tracks.audio)
      if (!_isPseudo(t.id) && !t.uri) t,
  ];

  List<SubtitleTrack> get _subtitleTracks => [
    for (final t in _player.state.tracks.subtitle)
      if (!_isPseudo(t.id) && !t.uri && !t.data) t,
  ];

  @override
  Future<void> selectAudio(int? ordinal) async {
    final tracks = _audioTracks;
    if (ordinal == null || ordinal >= tracks.length) {
      await _player.setAudioTrack(AudioTrack.auto());
    } else {
      await _player.setAudioTrack(tracks[ordinal]);
    }
  }

  @override
  Future<void> selectSubtitle(int? ordinal) async {
    final tracks = _subtitleTracks;
    if (ordinal == null || ordinal >= tracks.length) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
    } else {
      await _player.setSubtitleTrack(tracks[ordinal]);
    }
  }

  @override
  Future<void> addExternalSubtitle(Uri url, {String? title, String? language}) =>
      _player.setSubtitleTrack(SubtitleTrack.uri(url.toString(), title: title, language: language));

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  Future<void> setSubtitleStyle(SubtitleStyle style) async {
    String hex(Color c) =>
        '#${[c.a, c.r, c.g, c.b].map((v) => (v * 255).round().toRadixString(16).padLeft(2, '0')).join()}';
    await _set('sub-scale', style.scale.toStringAsFixed(2));
    await _set('sub-color', hex(style.color));
    // Marge exprimée dans la résolution de script de mpv (720 lignes).
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
  Widget buildView({BoxFit fit = BoxFit.contain}) => Video(
    controller: _video,
    controls: (_) => const SizedBox.shrink(),
    fit: fit,
    fill: Colors.black,
    // Rendu des sous-titres délégué à libass (dans l'image).
    subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
  );

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _snapshots.close();
    await _events.close();
    await _player.dispose();
  }
}
