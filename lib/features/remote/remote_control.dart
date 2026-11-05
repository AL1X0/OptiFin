import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optifin_native_player/optifin_native_player.dart';

import '../../core/design_system/design_system.dart';
import '../../core/l10n/l.dart';
import '../../core/media/formatters.dart';
import '../../core/media/media_item.dart';
import '../../core/network/api_failure.dart';
import '../../core/providers.dart';
import '../player/domain/playback_plan.dart';
import '../player/domain/playback_reporter.dart';
import '../player/presentation/playback_providers.dart';
import '../syncplay/domain/syncplay_models.dart';
import 'cast_stream.dart';

/// Autre appareil connecté au même compte, pilotable, et ce qu'il est en train de lire.
class RemoteDevice {
  const RemoteDevice({
    required this.sessionId,
    required this.name,
    this.client,
    this.nowPlaying,
    this.position = Duration.zero,
    this.runtime,
    this.paused = false,
  });

  final String sessionId;
  final String name;
  final String? client;
  final String? nowPlaying;
  final Duration position;
  final Duration? runtime;
  final bool paused;
}

/// Réponse du serveur → appareils pilotables capables de lire une vidéo, sauf celui-ci.
List<RemoteDevice> parseRemoteDevices(List<dynamic> sessions, String ownDeviceId) => [
  for (final s in sessions)
    if (s is Map<String, dynamic> &&
        s['Id'] is String &&
        s['DeviceId'] != ownDeviceId &&
        s['SupportsRemoteControl'] == true &&
        (s['PlayableMediaTypes'] is! List ||
            (s['PlayableMediaTypes'] as List).isEmpty ||
            (s['PlayableMediaTypes'] as List).contains('Video')))
      RemoteDevice(
        sessionId: s['Id'] as String,
        name: s['DeviceName'] as String? ?? s['Client'] as String? ?? s['Id'] as String,
        client: s['Client'] as String?,
        nowPlaying: (s['NowPlayingItem'] as Map<String, dynamic>?)?['Name'] as String?,
        position: ticksToDuration((s['PlayState'] as Map<String, dynamic>?)?['PositionTicks']),
        runtime: (s['NowPlayingItem'] as Map<String, dynamic>?)?['RunTimeTicks'] == null
            ? null
            : ticksToDuration((s['NowPlayingItem'] as Map<String, dynamic>)['RunTimeTicks']),
        paused: (s['PlayState'] as Map<String, dynamic>?)?['IsPaused'] == true,
      ),
];

/// « Lire sur… » : lancer et piloter la lecture d'un autre appareil par le serveur Jellyfin.
class RemoteControlClient {
  RemoteControlClient(this._dio, this._userId, this._deviceId);

  final Dio _dio;
  final String _userId;
  final String _deviceId;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  Future<List<RemoteDevice>> devices() => _guard(() async {
    final r = await _dio.get<List<dynamic>>(
      '/Sessions',
      queryParameters: {'controllableByUserId': _userId, 'activeWithinSeconds': 960},
    );
    return parseRemoteDevices(r.data ?? const [], _deviceId);
  });

  Future<void> play(String sessionId, String itemId, Duration start) => _guard(
    () => _dio.post<void>(
      '/Sessions/$sessionId/Playing',
      queryParameters: {'playCommand': 'PlayNow', 'itemIds': itemId, 'startPositionTicks': durationToTicks(start)},
    ),
  );

  Future<void> command(String sessionId, String command, {Duration? seek}) => _guard(
    () => _dio.post<void>(
      '/Sessions/$sessionId/Playing/$command',
      queryParameters: seek == null ? null : {'seekPositionTicks': durationToTicks(seek)},
    ),
  );
}

final remoteControlProvider = Provider<RemoteControlClient>((ref) {
  final session = ref.watch(sessionControllerProvider)!;
  return RemoteControlClient(
    ref.watch(jellyfinDioProvider),
    session.account.userId,
    ref.watch(clientIdentityProvider).deviceId,
  );
});

/// Choix de l'appareil, lancement du titre, puis télécommande.
Future<void> showPlayOnSheet(BuildContext context, {required MediaItem item, required Duration start}) =>
    showOFSheet<void>(context, builder: (_) => _PlayOnSheet(item: item, start: start));

class _PlayOnSheet extends ConsumerStatefulWidget {
  const _PlayOnSheet({required this.item, required this.start});
  final MediaItem item;
  final Duration start;

  @override
  ConsumerState<_PlayOnSheet> createState() => _PlayOnSheetState();
}

class _PlayOnSheetState extends ConsumerState<_PlayOnSheet> {
  List<RemoteDevice>? _devices;
  RemoteDevice? _active;
  String? _error;
  Timer? _timer;

  // Chromecast (Android).
  bool _castAvailable = false;
  List<CastDevice> _castDevices = const [];
  Timer? _discovery;
  String? _connecting;
  CastState? _castState;
  PlaybackPlan? _castPlan;
  int _castTicks = 0;

  RemoteControlClient get _remote => ref.read(remoteControlProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_startDiscovery());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _discovery?.cancel();
    if (_castAvailable) unawaited(Chromecast.stopDiscovery());
    super.dispose();
  }

  Future<void> _startDiscovery() async {
    if (!await Chromecast.available() || !mounted) return;
    _castAvailable = true;
    await Chromecast.startDiscovery();
    Future<void> poll() async {
      final found = await Chromecast.devices();
      if (mounted) setState(() => _castDevices = found);
    }

    await poll();
    _discovery = Timer.periodic(const Duration(seconds: 2), (_) => unawaited(poll()));
  }

  /// Prépare un flux que le Chromecast sait lire, se connecte, puis lance le titre.
  Future<void> _chooseCast(CastDevice device) async {
    setState(() {
      _connecting = device.name;
      _error = null;
    });
    try {
      final repository = ref.read(playbackRepositoryProvider);
      final plan = await repository.prepare(
        itemId: widget.item.id,
        start: widget.start,
        subtitleIndex: -1,
        options: castRequestOptions(),
        maxStreamingBitrate: 20000000,
      );
      await Chromecast.connect(device.id);
      final poster = ref
          .read(imageUrlBuilderProvider)
          .maybe(widget.item.poster, logicalWidth: 300, devicePixelRatio: 1);
      var started = false;
      // La session s'ouvre en quelques secondes après le choix de l'appareil.
      for (var i = 0; i < 30 && !started && mounted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!(await Chromecast.state()).connected) continue;
        started = await Chromecast.load(
          url: castUrl(plan, ref.read(sessionControllerProvider)!.token),
          contentType: castContentType(plan),
          title: widget.item.name,
          image: poster == null ? null : Uri.parse('$poster'),
          position: widget.start,
        );
      }
      if (!mounted) return;
      if (!started) {
        setState(() {
          _connecting = null;
          _error = L.f('Connexion à {0} impossible.', [device.name]);
        });
        return;
      }
      _castPlan = plan;
      unawaited(repository.start(_castReport(plan, widget.start, false)).catchError((Object _) {}));
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(_refreshCast()));
      setState(() => _connecting = null);
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          _connecting = null;
          _error = e.userMessage;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _connecting = null;
          _error = e.message ?? L.f('Connexion à {0} impossible.', [device.name]);
        });
      }
    }
  }

  PlaybackReport _castReport(PlaybackPlan plan, Duration position, bool paused) => PlaybackReport(
    itemId: plan.itemId,
    mediaSourceId: plan.mediaSourceId,
    playSessionId: plan.playSessionId,
    method: plan.method,
    position: position,
    isPaused: paused,
  );

  /// État de la diffusion ; la position part au serveur toutes les 10 s, pour la reprise.
  Future<void> _refreshCast() async {
    final plan = _castPlan;
    if (plan == null) return;
    final state = await Chromecast.state();
    if (!mounted) return;
    setState(() {
      _castState = state;
      if (state.failed) _error = L.t('Le Chromecast n’a pas pu lire ce titre.');
    });
    if (state.finished || !state.connected && _castTicks > 5) {
      await _stopCast(position: state.position);
      return;
    }
    if (++_castTicks % 10 == 0) {
      unawaited(ref.read(playbackRepositoryProvider).progress(_castReport(plan, state.position, state.paused)).catchError((Object _) {}));
    }
  }

  Future<void> _stopCast({Duration? position}) async {
    final plan = _castPlan;
    _timer?.cancel();
    _castPlan = null;
    if (plan != null) {
      unawaited(
        ref
            .read(playbackRepositoryProvider)
            .stopped(_castReport(plan, position ?? _castState?.position ?? widget.start, false))
            .catchError((Object _) {}),
      );
    }
    await Chromecast.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _load() async {
    try {
      final devices = await _remote.devices();
      if (mounted) setState(() => _devices = devices);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    }
  }

  Future<void> _choose(RemoteDevice device) async {
    try {
      await _remote.play(device.sessionId, widget.item.id, widget.start);
      if (!mounted) return;
      setState(() => _active = device);
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => unawaited(_refresh()));
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    }
  }

  Future<void> _refresh() async {
    final id = _active?.sessionId;
    if (id == null) return;
    try {
      final devices = await _remote.devices();
      final now = devices.where((d) => d.sessionId == id).firstOrNull;
      if (mounted && now != null) setState(() => _active = now);
    } on ApiFailure {
      // Coupure passagère : nouvel essai au prochain passage.
    }
  }

  void _send(String command, {Duration? seek}) {
    final id = _active?.sessionId;
    if (id == null) return;
    unawaited(
      _remote.command(id, command, seek: seek).catchError((Object e) {
        if (mounted) setState(() => _error = e is ApiFailure ? e.userMessage : '$e');
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final cast = _castState;
    return Padding(
      padding: const EdgeInsets.fromLTRB(OFSpacing.xl, OFSpacing.sm, OFSpacing.xl, OFSpacing.xl),
      child: _castPlan != null
          ? _panel(
              device: cast?.device ?? L.t('Chromecast'),
              title: widget.item.name,
              position: cast?.position ?? widget.start,
              runtime: cast == null || cast.duration == Duration.zero ? _castPlan!.runtime : cast.duration,
              paused: cast?.paused ?? false,
              onSeek: (p) => unawaited(Chromecast.seek(p)),
              onPlayPause: () => unawaited((cast?.paused ?? false) ? Chromecast.play() : Chromecast.pause()),
              onStop: () => unawaited(_stopCast()),
            )
          : active == null
          ? _list()
          : _controls(active),
    );
  }

  Widget _list() {
    final devices = _devices;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(L.t('Lire sur…'), style: OFTypography.title2),
        const SizedBox(height: OFSpacing.md),
        if (_error != null) ...[
          Text(_error!, style: OFTypography.callout),
          const SizedBox(height: OFSpacing.sm),
        ],
        if (_connecting != null)
          Row(
            children: [
              const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: OFSpacing.md),
              Expanded(child: Text(L.f('Connexion à {0}…', [_connecting!]), style: OFTypography.callout)),
            ],
          )
        else if (devices == null)
          const Center(child: CircularProgressIndicator())
        else if (devices.isEmpty && _castDevices.isEmpty)
          Text(
            L.t('Aucun autre appareil disponible. Ouvrez OptiFin ou Jellyfin sur l’autre écran, puis réessayez.'),
            style: OFTypography.callout,
          )
        else ...[
          for (final d in devices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tv_rounded),
              title: Text(d.name),
              subtitle: d.client == null ? null : Text(d.client!),
              onTap: () => unawaited(_choose(d)),
            ),
          for (final c in _castDevices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cast_rounded),
              title: Text(c.name),
              subtitle: Text(L.t('Chromecast')),
              onTap: () => unawaited(_chooseCast(c)),
            ),
        ],
      ],
    );
  }

  Widget _controls(RemoteDevice device) => _panel(
    device: device.name,
    title: device.nowPlaying ?? widget.item.name,
    position: device.position,
    runtime: device.runtime,
    paused: device.paused,
    onSeek: (p) => _send('Seek', seek: p),
    onPlayPause: () => _send(device.paused ? 'Unpause' : 'Pause'),
    onStop: () => _send('Stop'),
  );

  Widget _panel({
    required String device,
    required String title,
    required Duration position,
    required Duration? runtime,
    required bool paused,
    required ValueChanged<Duration> onSeek,
    required VoidCallback onPlayPause,
    required VoidCallback onStop,
  }) {
    final progress = runtime == null || runtime == Duration.zero
        ? 0.0
        : (position.inMilliseconds / runtime.inMilliseconds).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(L.f('Sur {0}', [device]), style: OFTypography.caption.copyWith(color: OFColors.textSecondary)),
        const SizedBox(height: OFSpacing.xs),
        Text(title, style: OFTypography.title2, maxLines: 2),
        const SizedBox(height: OFSpacing.md),
        LinearProgressIndicator(value: progress),
        const SizedBox(height: OFSpacing.xs),
        if (runtime != null)
          Text(
            '${MediaFormat.clock(position)} / ${MediaFormat.clock(runtime)}',
            style: OFTypography.caption.copyWith(color: OFColors.textSecondary),
          ),
        if (_error != null) Text(_error!, style: OFTypography.caption),
        const SizedBox(height: OFSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OFIconButton(
              icon: Icons.replay_10_rounded,
              tooltip: L.t('Reculer de 10 s'),
              onPressed: () => onSeek(
                position < const Duration(seconds: 10) ? Duration.zero : position - const Duration(seconds: 10),
              ),
            ),
            OFIconButton(
              icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              tooltip: L.t('Lecture / pause'),
              onPressed: onPlayPause,
            ),
            OFIconButton(
              icon: Icons.forward_10_rounded,
              tooltip: L.t('Avancer de 10 s'),
              onPressed: () => onSeek(position + const Duration(seconds: 10)),
            ),
            OFIconButton(icon: Icons.stop_rounded, tooltip: L.t('Arrêter'), onPressed: onStop),
          ],
        ),
      ],
    );
  }
}
