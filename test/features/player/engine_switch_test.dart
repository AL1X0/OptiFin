import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/media/media_item.dart';
import 'package:optifin/core/network/jellyfin_auth.dart';
import 'package:optifin/core/network/retry_policy.dart';
import 'package:optifin/core/providers.dart';
import 'package:optifin/features/auth/domain/entities.dart';
import 'package:optifin/features/player/data/device_profiles.dart';
import 'package:optifin/features/player/domain/engine_selector.dart';
import 'package:optifin/features/player/domain/playback_engine.dart';
import 'package:optifin/features/player/domain/playback_plan.dart';
import 'package:optifin/features/player/domain/source_profile.dart';
import 'package:optifin/features/player/presentation/player_controller.dart';
import 'package:optifin/features/settings/presentation/settings_providers.dart';

import 'engine_matrix.dart';
import 'fakes.dart';

const movie = MediaItem(id: 'm', name: 'Horizon perdu', kind: MediaKind.movie);

/// Source cohérente avec les pistes des fakes : MP4 H.264 SDR, E-AC3 (1) / TrueHD (2),
/// ASS (3), PGS (4), SRT externe (5). Sur iPhone : natif en lecture directe.
const source = SourceProfile(
  container: 'mp4',
  bitrate: 8000000,
  video: VideoInfo(codec: 'h264', width: 1920, height: 1080),
  audio: [
    AudioInfo(index: 1, codec: 'eac3', channels: 6),
    AudioInfo(index: 2, codec: 'truehd', profile: 'TrueHD Atmos', channels: 8),
  ],
  subtitles: [
    SubtitleInfo(index: 3, codec: 'ass'),
    SubtitleInfo(index: 4, codec: 'pgssub', isText: false),
    SubtitleInfo(index: 5, codec: 'srt', isExternal: true),
  ],
);

/// Sous-titres tels que les livre le serveur au lecteur natif (WebVTT séparé).
const nativeSubFr = MediaTrack(
  index: 3,
  type: TrackType.subtitle,
  label: 'Français (ASS)',
  codec: 'ass',
  deliveryUrl: '/Videos/m/src/Subtitles/3/0/Stream.vtt',
);

PlaybackPlan sourcedPlan({int? audioIndex = 1, int? subtitleIndex, PlaybackRequestOptions? options}) {
  final native = options?.deviceProfile['Name'] != 'OptiFin (mpv)' && options != null;
  final transcode = options != null && !options.enableDirectStream;
  return PlaybackPlan(
    itemId: 'm',
    mediaSourceId: 'src',
    playSessionId: 'ps',
    method: transcode ? PlayMethod.transcode : PlayMethod.directPlay,
    streamUrl: Uri.parse('http://s/jf/Videos/m/stream?static=true'),
    audioTracks: const [audioFr, audioEn],
    subtitleTracks: native ? const [nativeSubFr, subPgs, subExt] : const [subFr, subPgs, subExt],
    audioIndex: audioIndex,
    subtitleIndex: subtitleIndex,
    source: source,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePlaybackRepository playback;
  late ProviderContainer container;
  late List<FakeEngine> engines;

  ProviderContainer build({Set<EngineKind> failing = const {}, Set<EngineKind> silent = const {}}) {
    engines = [];
    playback = FakePlaybackRepository(
      ({int? audioIndex, int? subtitleIndex, PlaybackRequestOptions? options}) => sourcedPlan(
        audioIndex: audioIndex ?? 1,
        subtitleIndex: subtitleIndex == null || subtitleIndex < 0 ? null : subtitleIndex,
        options: options,
      ),
    );
    return ProviderContainer(
      retry: networkRetry,
      overrides: [
        initialSessionProvider.overrideWithValue(
          ActiveSession(
            server: JellyfinServer(id: 's', name: 'S', baseUrl: Uri.parse('http://s/jf'), version: '10.10.7'),
            account: const Account(serverId: 's', userId: 'u', userName: 'Léa'),
            token: 'secret',
          ),
        ),
        clientIdentityProvider.overrideWithValue(
          const ClientIdentity(clientName: 'OptiFin', deviceName: 'T', deviceId: 'd', version: '1'),
        ),
        playbackRepositoryProvider.overrideWithValue(playback),
        playbackExtrasRepositoryProvider.overrideWithValue(FakeExtrasRepository()),
        mediaRepositoryProvider.overrideWithValue(FakeMediaRepository(movie)),
        deviceCapabilitiesProvider.overrideWith((ref) async => iphone15Pro.caps),
        maxBitrateResolverProvider.overrideWithValue(() async => 120000000),
        playbackEngineFactoryProvider.overrideWithValue((kind) async {
          final e = FakeEngine(
            name: kind.name,
            failOnOpen: failing.contains(kind),
            readyOnOpen: !silent.contains(kind),
            capabilities: kind == EngineKind.native
                ? const EngineCapabilities(subtitleStyling: true, embeddedSubtitles: false)
                : const EngineCapabilities(subtitleStyling: true),
          );
          engines.add(e);
          return e;
        }),
      ],
    );
  }

  Future<PlayerController> start(ProviderContainer c) async {
    const args = PlayerArgs('m', start: Duration.zero);
    c.listen(playerControllerProvider(args), (_, _) {});
    final controller = c.read(playerControllerProvider(args).notifier);
    await settle();
    return controller;
  }

  tearDown(() {
    PlayerController.startupTimeout = const Duration(seconds: 25);
    try {
      container.dispose();
    } catch (_) {}
  });

  test('décision principale : lecteur natif en lecture directe', () async {
    container = build();
    final c = await start(container);
    expect(c.state.phase, PlayerPhase.playing);
    expect(c.state.decision!.label, 'Natif · Lecture directe');
    expect(engines.map((e) => e.name), ['native']);
    expect(playback.prepareOptions.last!.deviceProfile['Name'], 'OptiFin (AVPlayer)');
  });

  test('échec du natif au démarrage → bascule automatique sur mpv', () async {
    container = build(failing: {EngineKind.native});
    final c = await start(container);
    expect(engines.map((e) => e.name), ['native', 'mpv']);
    expect(engines.first.disposed, isTrue);
    expect(c.state.phase, PlayerPhase.playing);
    expect(c.state.decision!.engine, EngineKind.mpv);
    expect(c.state.notice, isNull, reason: 'message effacé à la première image');
    expect(playback.reports.first, startsWith('start@'), reason: 'un seul « start » pour la session');
  });

  test('tous les moteurs échouent → erreur avec le détail de chaque tentative', () async {
    container = build(failing: {EngineKind.native, EngineKind.mpv});
    final c = await start(container);
    expect(c.state.phase, PlayerPhase.error);
    final detail = c.state.technicalError!;
    expect(detail, contains('Natif · Lecture directe : format refusé'));
    expect(detail, contains('mpv · Lecture directe : format refusé'));
    expect(detail, contains('mpv · Transcodage : format refusé'));
  });

  test('aucune image dans le délai → repli', () async {
    PlayerController.startupTimeout = const Duration(milliseconds: 30);
    container = build(silent: {EngineKind.native});
    final c = await start(container);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await settle();
    expect(c.state.decision!.engine, EngineKind.mpv);
    expect(engines.last.opened, hasLength(1));
  });

  test('sous-titre texte simple sur le natif : dessiné par OptiFin, sans recharger', () async {
    container = build();
    final c = await start(container);
    await c.selectSubtitle(subExt);
    expect(engines.single.commands.last, 'extsub:http://s/jf/Videos/m/src/Subtitles/5/0/Stream.srt');
    expect(engines.single.opened, hasLength(1));
    expect(c.state.plan!.subtitleIndex, 5);
    expect(c.state.decision!.subtitles, SubtitleRoute.overlay);
    // Désactivation : locale aussi.
    await c.selectSubtitle(null);
    expect(engines.single.commands.last, 'sub:null');
    expect(engines, hasLength(1));
  });

  test('sous-titres ASS sur du SDR : mpv pour garder les styles', () async {
    container = build();
    final c = await start(container);
    await c.selectSubtitle(nativeSubFr);
    await settle();
    expect(engines.map((e) => e.name), ['native', 'mpv']);
    expect(c.state.decision!.subtitles, SubtitleRoute.engine);
    expect(engines.last.opened.single.subtitleOrdinal, 0);
  });

  test('choisir des PGS bascule du natif vers mpv, à la position courante', () async {
    container = build();
    final c = await start(container);
    engines.single.emit(engines.single.snapshot.copyWith(position: const Duration(minutes: 7)));
    await c.selectSubtitle(subPgs);
    await settle();
    expect(engines.map((e) => e.name), ['native', 'mpv']);
    expect(engines.first.disposed, isTrue);
    final media = engines.last.opened.single;
    expect(media.start, const Duration(minutes: 7));
    expect(media.subtitleOrdinal, 1, reason: 'PGS rendus par mpv (2e sous-titre intégré)');
    expect(c.state.decision!.engine, EngineKind.mpv);
  });

  test('choisir une piste TrueHD bascule vers mpv', () async {
    container = build();
    final c = await start(container);
    await c.selectAudio(audioEn);
    await settle();
    expect(engines.last.name, 'mpv');
    expect(engines.last.opened.single.audioOrdinal, 1);
  });

  test('moteur imposé pour la lecture (feuille) puis retour en automatique', () async {
    container = build();
    final c = await start(container);
    await c.setEnginePreference(EnginePreference.mpv);
    await settle();
    expect(c.state.preference, EnginePreference.mpv);
    expect(engines.map((e) => e.name), ['native', 'mpv']);
    await c.setEnginePreference(EnginePreference.auto);
    await settle();
    expect(engines.map((e) => e.name), ['native', 'mpv', 'native']);
  });
}

Future<void> settle() async {
  // Laisse passer les remplacements de moteur (50 ms chacun) et les microtâches.
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
