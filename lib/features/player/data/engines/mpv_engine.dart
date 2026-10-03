import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:optifin_native_player/optifin_native_player.dart' show MpvSurfaceView, NativePlayers;

import '../../../../core/design_system/device.dart';
import '../../../../core/logging/app_log.dart';
import '../../domain/playback_engine.dart';

/// Moteur libmpv (via media_kit) : lit quasiment tout (MKV, HEVC, AV1, DTS,
/// TrueHD, ASS, PGS…). Décodage matériel VideoToolbox / MediaCodec.
///
/// libmpv n'est chargé qu'à la première création d'un [MpvEngine] (jamais au
/// démarrage de l'app) : voir [MpvEngine.create].
class MpvEngine implements PlaybackEngine {
  MpvEngine._(this._player, this._video, {this.surfaceHwdec}) {
    _subscriptions.addAll([
      _player.stream.playing.listen((v) => _emit(_snapshot.copyWith(playing: v))),
      _player.stream.buffering.listen((v) => _emit(_snapshot.copyWith(buffering: v))),
      _player.stream.position.listen((v) => _emit(_snapshot.copyWith(position: v))),
      _player.stream.buffer.listen((v) => _emit(_snapshot.copyWith(buffered: v))),
      _player.stream.rate.listen((v) => _emit(_snapshot.copyWith(rate: v))),
      _player.stream.duration.listen((v) {
        if (v <= Duration.zero) return;
        if (_started || _checkingOutput) {
          _emit(_snapshot.copyWith(duration: v));
          return;
        }
        // Téléviseurs : « prêt » seulement une fois la sortie vidéo réellement ouverte. Sur
        // certaines box, mpv lit le son mais n'affiche rien (écran noir) : la lecture échoue
        // alors au démarrage et le lecteur bascule sur l'autre moteur au lieu de rester noir.
        if (OFDevice.tv && Platform.isAndroid) {
          _emit(_snapshot.copyWith(duration: v));
          unawaited(_checkVideoOutput());
          return;
        }
        _started = true;
        _emit(_snapshot.copyWith(duration: v, status: PlaybackStatus.ready));
      }),
      _player.stream.width.listen((_) => _updateSize()),
      _player.stream.height.listen((_) => _updateSize()),
      _player.stream.completed.listen((done) {
        if (!done) return;
        _emit(_snapshot.copyWith(status: PlaybackStatus.ended, playing: false));
        _events.add(const PlaybackCompleted());
      }),
      _player.stream.log.listen(
        (log) => AppLog.instance.add(
          switch (log.level) {
            'fatal' || 'error' => LogLevel.error,
            'warn' => LogLevel.warning,
            'info' => LogLevel.info,
            _ => LogLevel.debug,
          },
          'mpv',
          '[${log.prefix}] ${log.text.trim()}',
        ),
      ),
      _player.stream.error.listen((message) {
        AppLog.w('mpv', 'Erreur : $message');
        // mpv signale aussi des erreurs non fatales (piste illisible…) une fois la lecture lancée.
        if (_started) return;
        _emit(_snapshot.copyWith(status: PlaybackStatus.error, error: message));
        _events.add(PlaybackFailed(message, duringStartup: true));
      }),
    ]);
    // Images perdues (overlay de debug) : lues toutes les 2 s, seulement pendant la lecture.
    _dropTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollDroppedFrames());
  }

  Timer? _dropTimer;
  bool _checkingOutput = false;

  /// Vérifie que mpv affiche bien la vidéo (sortie configurée) avant de déclarer la lecture
  /// prête ; sinon échec au démarrage (repli automatique). Fichier sans vidéo : prêt aussitôt.
  Future<void> _checkVideoOutput() async {
    final native = _native;
    if (native == null) {
      _ready();
      return;
    }
    _checkingOutput = true;
    Future<String> get(String name) async {
      try {
        return await native.getProperty(name);
      } catch (_) {
        return '';
      }
    }

    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!_events.isClosed && DateTime.now().isBefore(deadline)) {
      final vid = await get('vid');
      if (vid == 'no' || vid == '' && (await get('track-list/count')) == '0') {
        _checkingOutput = false;
        _ready();
        return;
      }
      if (await get('vo-configured') == 'yes') {
        AppLog.i(
          'mpv',
          'Sortie vidéo prête : décodage ${await get('hwdec-current')}, '
              'format ${await get('video-params/pixelformat')}, ${await get('video-params/gamma')}',
        );
        _checkingOutput = false;
        _ready();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    _checkingOutput = false;
    if (_events.isClosed || _started) return;
    final detail = 'décodage ${await get('hwdec-current')}, format ${await get('video-params/pixelformat')}';
    AppLog.w('mpv', 'Aucune image affichée après 10 s (sortie vidéo non configurée ; $detail)');
    _emit(_snapshot.copyWith(status: PlaybackStatus.error, error: 'mpv n’affiche pas la vidéo sur cet appareil'));
    _events.add(const PlaybackFailed('mpv n’affiche pas la vidéo sur cet appareil', duringStartup: true));
  }

  void _ready() {
    if (_started || _events.isClosed) return;
    _started = true;
    _emit(_snapshot.copyWith(status: PlaybackStatus.ready));
  }

  Future<void> _pollDroppedFrames() async {
    final native = _native;
    if (native == null || !_snapshot.playing) return;
    try {
      final vo = int.tryParse(await native.getProperty('frame-drop-count')) ?? 0;
      final decoder = int.tryParse(await native.getProperty('decoder-frame-drop-count')) ?? 0;
      if (!_snapshots.isClosed) _emit(_snapshot.copyWith(droppedFrames: vo + decoder));
    } catch (_) {
      // Propriété indisponible : on n'affiche rien.
    }
  }

  static bool _initialized = false;

  /// Charge libmpv à la demande puis crée le moteur.
  /// [verbose] : logs mpv détaillés (mode debug).
  static Future<MpvEngine> create({bool verbose = false}) async {
    if (!_initialized) {
      MediaKit.ensureInitialized();
      _initialized = true;
    }
    // Téléviseurs : copie des images décodées plutôt que l'échange direct avec le GPU
    // (AImageReader), qui fait planter les pilotes graphiques de nombreuses box.
    final hwdec = OFDevice.tv ? 'mediacodec-copy' : 'auto-safe';
    AppLog.i('mpv', 'Création du moteur (libmpv, décodage matériel $hwdec)');
    final player = Player(
      configuration: PlayerConfiguration(
        title: 'OptiFin',
        // Sous-titres rendus par mpv/libass dans l'image : styles ASS et PGS fidèles.
        libass: true,
        // Tampon démuxeur généreux : remux 4K à haut débit sans à-coups (réduit sur les box TV,
        // souvent limitées à 1,5 Go de mémoire).
        bufferSize: (OFDevice.tv ? 32 : 96) * 1024 * 1024,
        logLevel: verbose ? MPVLogLevel.info : MPVLogLevel.warn,
      ),
    );
    // Téléviseurs Android : mpv dessine dans sa propre SurfaceView (comme mpv-android). La
    // texture de media_kit reste noire sur certains modèles alors que la vidéo est décodée.
    if (OFDevice.tv && Platform.isAndroid) {
      final engine = MpvEngine._(player, null, surfaceHwdec: hwdec);
      await engine._configureSurfaceOutput();
      await engine._configure();
      return engine;
    }
    final video = VideoController(
      player,
      configuration: VideoControllerConfiguration(enableHardwareAcceleration: true, hwdec: hwdec),
    );
    final engine = MpvEngine._(player, video);
    await engine._configure();
    return engine;
  }

  final Player _player;
  /// Texture media_kit (null : sortie sur [MpvSurfaceView], téléviseurs Android).
  final VideoController? _video;

  /// Décodage matériel de la sortie sur surface (null : texture media_kit).
  final String? surfaceHwdec;

  /// Surface reçue de [MpvSurfaceView] (0 : aucune).
  int _wid = 0;
  BoxFit _surfaceFit = BoxFit.contain;

  /// Mêmes réglages que le VideoController Android de media_kit, sans sa texture.
  Future<void> _configureSurfaceOutput() async {
    await _set('vo', 'null');
    await _set('hwdec', surfaceHwdec!);
    await _set('vid', 'auto');
    await _set('opengl-es', 'yes');
    await _set('force-window', 'yes');
    await _set('gpu-context', 'android');
    await _set('sub-use-margins', 'no');
    await _set('sub-font-provider', 'none');
    await _set('sub-scale-with-window', 'yes');
    await _set('hwdec-codecs', 'h264,hevc,mpeg4,mpeg2video,vp8,vp9,av1');
  }

  /// Surface créée, redimensionnée ou détruite (wid 0) : ordre imposé par mpv
  /// (vo=null, taille, wid, puis vo=gpu), comme media_kit.
  Future<void> _onSurface(int wid, int width, int height) async {
    if (_events.isClosed) return;
    _wid = wid;
    await _set('vo', 'null');
    if (wid == 0) {
      await _set('wid', '0');
      AppLog.i('mpv', 'Surface vidéo retirée');
      return;
    }
    await _set('android-surface-size', '${width}x$height');
    await _set('wid', '$wid');
    await _set('vo', 'gpu');
    AppLog.i('mpv', 'Surface vidéo Android : $width×$height');
  }

  Future<void> _applySurfaceFit(BoxFit fit) async {
    if (fit == _surfaceFit) return;
    _surfaceFit = fit;
    await _set('keepaspect', fit == BoxFit.fill ? 'no' : 'yes');
    await _set('panscan', fit == BoxFit.cover ? '1.0' : '0.0');
  }
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
      // Même sortie audio que le lecteur natif : les formats que Media3 envoie tels quels à la TV
      // ou à l'ampli (Dolby, DTS) sont transmis de la même façon par mpv. Sinon mpv les décodait
      // lui-même et le volume différait d'un moteur à l'autre.
      final passthrough = await _passthrough();
      if (passthrough.isNotEmpty) {
        await _set('audio-spdif', passthrough.join(','));
        AppLog.i('mpv', 'Audio transmis tel quel : ${passthrough.join(', ')}');
      }
    }
    await _set('sub-ass-override', 'scale'); // garde les styles ASS, applique la taille choisie
    await _set('demuxer-readahead-secs', '30');
    await _set('cache', 'yes');
    if (OFDevice.tv) {
      // Box TV (1,5 à 2 Go de mémoire) : tampons bornés.
      await _set('demuxer-max-back-bytes', '${16 * 1024 * 1024}');
      await _set('demuxer-readahead-secs', '15');
    }
  }

  static List<String>? _passthroughCache;

  /// Formats audio transmis tels quels par Media3 sur cet appareil (sondé une fois).
  static Future<List<String>> _passthrough() async {
    final cached = _passthroughCache;
    if (cached != null) return cached;
    try {
      final caps = await NativePlayers.capabilities();
      return _passthroughCache = [
        for (final c in (caps?['passthrough'] as List<Object?>?) ?? const <Object?>[])
          if (c is String) c,
      ];
    } catch (_) {
      return _passthroughCache = const [];
    }
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
  EngineCapabilities get capabilities => EngineCapabilities(
    // Android : PiP de l'activité entière, indépendant du moteur. iOS : réservé à AVPlayer.
    pictureInPicture: Platform.isAndroid,
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
    _checkingOutput = false;
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
  Future<bool> enterPictureInPicture() async {
    if (!Platform.isAndroid) return false;
    return NativePlayers.enterPictureInPicture(width: _player.state.width ?? 16, height: _player.state.height ?? 9);
  }

  @override
  Future<void> setSubtitleDelay(Duration delay) => _set('sub-delay', (delay.inMilliseconds / 1000).toStringAsFixed(3));

  @override
  Future<void> setAudioDelay(Duration delay) => _set('audio-delay', (delay.inMilliseconds / 1000).toStringAsFixed(3));

  @override
  Widget buildView({BoxFit fit = BoxFit.contain}) {
    if (_video == null) {
      unawaited(_applySurfaceFit(fit));
      return ExcludeFocus(
        child: ColoredBox(
          color: Colors.black,
          child: MpvSurfaceView(onSurface: (wid, w, h) => unawaited(_onSurface(wid, w, h))),
        ),
      );
    }
    return _textureView(_video, fit);
  }

  Widget _textureView(VideoController video, BoxFit fit) => ExcludeFocus(
    child: Video(
      controller: video,
      controls: (_) => const SizedBox.shrink(),
      fit: fit,
      fill: Colors.black,
      // Rendu des sous-titres délégué à libass (dans l'image).
      subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
    ),
  );

  @override
  Future<void> dispose() async {
    // Sortie sur surface : mpv lâche la surface avant la destruction du lecteur.
    if (_video == null && _wid != 0) {
      _wid = 0;
      await _set('vo', 'null');
    }
    _dropTimer?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _snapshots.close();
    await _events.close();
    await _player.dispose();
  }
}
