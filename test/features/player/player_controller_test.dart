import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/design_system/design_system.dart';
import 'package:optifin/core/media/media_item.dart';
import 'package:optifin/core/network/jellyfin_auth.dart';
import 'package:optifin/core/network/retry_policy.dart';
import 'package:optifin/core/providers.dart';
import 'package:optifin/features/auth/domain/entities.dart';
import 'package:optifin/features/player/data/device_profiles.dart';
import 'package:optifin/features/player/data/playback_repository.dart';
import 'package:optifin/features/player/domain/device_capabilities.dart';
import 'package:optifin/features/player/domain/playback_engine.dart';
import 'package:optifin/features/player/domain/playback_extras.dart';
import 'package:optifin/features/player/domain/playback_plan.dart';
import 'package:optifin/features/player/presentation/player_controller.dart';
import 'package:optifin/features/player/presentation/player_screen.dart';
import 'package:optifin/features/settings/domain/app_settings.dart';
import 'package:optifin/features/settings/presentation/settings_providers.dart';

import 'fakes.dart';

const downloadedSub = MediaTrack(
  index: 9,
  type: TrackType.subtitle,
  label: 'Français (OpenSubtitles)',
  codec: 'srt',
  isExternal: true,
  deliveryUrl: '/Videos/m/src/Subtitles/9/0/Stream.srt',
);

const nextEpisode = MediaItem(id: 'e2', name: 'La suite', kind: MediaKind.episode);

const movie = MediaItem(
  id: 'm',
  name: 'Horizon perdu',
  kind: MediaKind.movie,
  user: UserState(positionTicks: 6000000000), // 10 min
);

void main() {
  late FakeEngine engine;
  late FakePlaybackRepository playback;
  late FakeExtrasRepository extras;
  late ProviderContainer container;

  ProviderContainer build({
    PlayMethod method = PlayMethod.directPlay,
    int? defaultSubtitle,
    AppSettings settings = const AppSettings(),
  }) {
    engine = FakeEngine();
    extras = FakeExtrasRepository();
    playback = FakePlaybackRepository(({int? audioIndex, int? subtitleIndex, PlaybackRequestOptions? options}) {
      final p = plan(
        method: method,
        audioIndex: audioIndex ?? 1,
        subtitleIndex: subtitleIndex == null || subtitleIndex < 0 ? defaultSubtitle : subtitleIndex,
      );
      // Après un téléchargement, le serveur expose le nouveau sous-titre externe.
      return extras.downloads.isEmpty ? p : p.withSubtitleTracks([...p.subtitleTracks, downloadedSub]);
    });
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
        playbackExtrasRepositoryProvider.overrideWithValue(extras),
        mediaRepositoryProvider.overrideWithValue(FakeMediaRepository(movie)),
        playbackEngineFactoryProvider.overrideWithValue((_) async => engine),
        deviceCapabilitiesProvider.overrideWith((ref) async => DeviceCapabilities.fallback(DevicePlatform.other)),
        maxBitrateResolverProvider.overrideWithValue(() async => 40000000),
        initialSettingsProvider.overrideWithValue(settings),
      ],
    );
  }

  Future<PlayerController> start(ProviderContainer c, {Duration? at}) async {
    final args = PlayerArgs('m', start: at);
    c.listen(playerControllerProvider(args), (_, _) {});
    final controller = c.read(playerControllerProvider(args).notifier);
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return controller;
  }

  tearDown(() {
    try {
      container.dispose();
    } catch (_) {}
  });

  test('démarrage : reprise serveur, en-tête d’auth, piste audio mappée, rapport start', () async {
    container = build();
    final c = await start(container);
    expect(c.state.phase, PlayerPhase.playing);
    final media = engine.opened.single;
    expect(media.start, const Duration(minutes: 10));
    expect(media.headers['Authorization'], contains('Token="secret"'));
    expect(media.url.queryParameters.keys, isNot(contains('api_key')));
    expect(media.audioOrdinal, 0, reason: 'index Jellyfin 1 = 1re piste audio du fichier');
    expect(media.subtitleOrdinal, isNull);
    expect(playback.reports.first, 'start@600');
    expect(engine.commands, contains('style:1.0'));
  });

  test('« depuis le début » ignore la position serveur', () async {
    container = build();
    await start(container, at: Duration.zero);
    expect(engine.opened.single.start, Duration.zero);
  });

  test('Direct Play : changement de piste instantané, sans recharger', () async {
    container = build();
    final c = await start(container);
    await c.selectAudio(audioEn);
    await c.selectSubtitle(subPgs);
    expect(engine.commands, containsAllInOrder(['audio:1', 'sub:1']));
    expect(engine.opened, hasLength(1));
    expect(playback.prepareCalls, hasLength(1));
    expect(c.state.plan!.audioIndex, 2);
    expect(c.state.plan!.subtitleIndex, 4);
  });

  test('sous-titre externe : chargé depuis le serveur (URL résolue)', () async {
    container = build();
    final c = await start(container);
    await c.selectSubtitle(subExt);
    expect(engine.commands.last, 'extsub:http://s/jf/Videos/m/src/Subtitles/5/0/Stream.srt');
  });

  test('Transcodage : changer d’audio recharge le flux à la position courante', () async {
    container = build(method: PlayMethod.transcode);
    final c = await start(container);
    engine.emit(engine.snapshot.copyWith(position: const Duration(minutes: 42)));
    await c.selectAudio(audioEn);
    expect(playback.prepareCalls.last, (2, -1));
    expect(engine.opened, hasLength(2));
    expect(engine.opened.last.start, const Duration(minutes: 42));
    expect(engine.opened.last.audioOrdinal, isNull, reason: 'le serveur ne muxe que la piste choisie');
  });

  test('Transcodage : sous-titre image → incrustation serveur (rechargement)', () async {
    container = build(method: PlayMethod.transcode);
    final c = await start(container);
    await c.selectSubtitle(subPgs);
    expect(playback.prepareCalls.last, (1, 4));
    expect(engine.opened, hasLength(2));
  });

  test('refus serveur → écran d’erreur avec le message précis', () async {
    container = build();
    playback.prepareError = const PlaybackDeniedFailure('NotAllowed');
    final c = await start(container);
    expect(c.state.phase, PlayerPhase.error);
    expect(c.state.error, contains('pas autorisée'));
  });

  test('fin de lecture → rapport stop, moteur libéré, phase closed', () async {
    container = build();
    final c = await start(container);
    engine.fire(const PlaybackCompleted());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(c.state.phase, PlayerPhase.closed);
    expect(playback.reports.last, startsWith('stopped@'));
    expect(engine.disposed, isTrue);
  });

  test('fermeture instantanée : l'
      'écran n'
      'attend ni le serveur ni la libération du moteur', () async {
    container = build();
    final c = await start(container);
    playback.stopDelay = const Duration(milliseconds: 500);
    unawaited(c.close());
    await Future<void>.delayed(Duration.zero);
    expect(
      c.state.phase,
      PlayerPhase.closed,
      reason:
          'l'
          'écran se ferme au toucher de la croix',
    );
    expect(
      engine.commands.last,
      'pause',
      reason:
          'le son s'
          'arrête immédiatement',
    );
    expect(playback.reports.last, isNot(startsWith('stopped')), reason: 'rapport encore en cours');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(playback.reports.last, startsWith('stopped@'));
    expect(engine.disposed, isTrue);
  });

  testWidgets('écran : titre, play/pause pilote le moteur, feuille des pistes', (tester) async {
    container = build();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: OFTheme.dark(),
          home: const PlayerScreen(args: PlayerArgs('m')),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const ValueKey('video')), findsOneWidget);
    expect(find.text('Horizon perdu'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump();
    expect(engine.commands, contains('pause'));

    // Réglages → Audio : pistes audio ; retour → Sous-titres : pistes de sous-titres.
    await tester.tap(find.bySemanticsLabel('Réglages'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Audio, ')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('English 7.1'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Retour'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Sous-titres, ')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Externe SRT'), findsOneWidget);

    // Démonte l'écran puis le conteneur : aucune minuterie ne doit survivre (cache 2 min, masquage).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
    container.dispose();
    await tester.pump(const Duration(minutes: 3));
  });


  group('Phase 5 : segments, épisode suivant, décalages, sous-titres', () {
    const intro = MediaSegment(type: SegmentType.intro, start: Duration(minutes: 1), end: Duration(minutes: 2));
    const outro = MediaSegment(
      type: SegmentType.outro,
      start: Duration(hours: 1, minutes: 55),
      end: Duration(hours: 2),
    );

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('segment en cours → bouton « Passer », puis saut à la fin du segment', () async {
      container = build();
      extras.extras = const PlaybackExtras(segments: [intro]);
      final c = await start(container, at: Duration.zero);
      engine.emit(engine.snapshot.copyWith(position: const Duration(seconds: 70)));
      await settle();
      expect(c.state.segment, intro);
      await c.skipSegment();
      expect(engine.commands.last, 'seek:120');
      expect(c.state.segment, isNull);
    });

    test('saut automatique (réglage) : une seule fois par segment', () async {
      container = build(settings: const AppSettings(autoSkipSegments: true));
      extras.extras = const PlaybackExtras(segments: [intro]);
      await start(container, at: Duration.zero);
      engine.emit(engine.snapshot.copyWith(position: const Duration(seconds: 61)));
      await settle();
      expect(engine.commands.where((c) => c == 'seek:120'), hasLength(1));
      // Retour volontaire dans l'intro : pas de nouveau saut.
      engine.emit(engine.snapshot.copyWith(position: const Duration(seconds: 65)));
      await settle();
      expect(engine.commands.where((c) => c == 'seek:120'), hasLength(1));
    });

    test('générique → carte épisode suivant ; « Lire » enchaîne (fin de session propre)', () async {
      container = build();
      extras.extras = const PlaybackExtras(segments: [outro], nextEpisode: nextEpisode);
      final c = await start(container, at: Duration.zero);
      engine.emit(engine.snapshot.copyWith(position: const Duration(hours: 1, minutes: 56)));
      await settle();
      expect(c.state.upNext, isTrue);
      expect(c.state.segment, isNull, reason: 'le générique est géré par la carte, pas par « Passer »');
      await c.playNext();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(c.state.nextItemId, 'e2');
      expect(c.state.phase, PlayerPhase.closed);
      expect(playback.reports.last, startsWith('stopped@'));
    });

    test('carte fermée : pas d’enchaînement automatique en fin de lecture', () async {
      container = build();
      extras.extras = const PlaybackExtras(nextEpisode: nextEpisode);
      final c = await start(container, at: Duration.zero);
      engine.emit(engine.snapshot.copyWith(position: const Duration(hours: 1, minutes: 59, seconds: 40)));
      await settle();
      expect(c.state.upNext, isTrue);
      c.dismissUpNext();
      engine.fire(const PlaybackCompleted());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(c.state.phase, PlayerPhase.closed);
      expect(c.state.nextItemId, isNull);
    });

    test('fin de l’épisode sans intervention → épisode suivant', () async {
      container = build();
      extras.extras = const PlaybackExtras(nextEpisode: nextEpisode);
      final c = await start(container, at: Duration.zero);
      engine.fire(const PlaybackCompleted());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(c.state.nextItemId, 'e2');
    });

    test('décalages audio et sous-titres transmis au moteur', () async {
      container = build();
      final c = await start(container);
      await c.setSubtitleDelay(const Duration(milliseconds: 300));
      await c.setAudioDelay(const Duration(milliseconds: -200));
      expect(engine.commands, containsAll(['subdelay:300', 'audiodelay:-200']));
      expect(c.state.subtitleDelay, const Duration(milliseconds: 300));
    });

    test('sous-titre téléchargé depuis le serveur : ajouté et affiché sans recharger', () async {
      container = build();
      final c = await start(container);
      await c.downloadSubtitle(const RemoteSubtitle(id: 'os-42', name: 'Français'));
      expect(extras.downloads, ['os-42']);
      expect(c.state.plan!.subtitleTracks.map((t) => t.index), contains(9));
      expect(c.state.plan!.subtitleIndex, 9);
      expect(engine.commands.last, 'extsub:http://s/jf/Videos/m/src/Subtitles/9/0/Stream.srt');
      expect(engine.opened, hasLength(1));
    });
  });

  testWidgets('écran : « Passer l’intro », verrouillage, carte épisode suivant', (tester) async {
    container = build();
    extras.extras = const PlaybackExtras(
      segments: [MediaSegment(type: SegmentType.intro, start: Duration(minutes: 9), end: Duration(minutes: 11))],
      nextEpisode: nextEpisode,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: OFTheme.dark(),
          home: const PlayerScreen(args: PlayerArgs('m')),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    // Reprise à 10 min : dans l'intro.
    engine.emit(engine.snapshot.copyWith(position: const Duration(minutes: 10)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Passer l’intro'), findsOneWidget);
    await tester.tap(find.text('Passer l’intro'));
    await tester.pump();
    expect(engine.commands, contains('seek:660'));

    // Verrou : les contrôles disparaissent, seul « Déverrouiller » peut revenir.
    await tester.tap(find.bySemanticsLabel('Réglages'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.bySemanticsLabel('Verrouiller l’écran'));
    await tester.pump(const Duration(milliseconds: 400));
    // Contrôles encore présents (fondu) mais plus touchables.
    expect(find.bySemanticsLabel('Pause').hitTestable(), findsNothing);
    expect(find.text('Déverrouiller'), findsOneWidget);
    await tester.tap(find.text('Déverrouiller'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.bySemanticsLabel('Pause').hitTestable(), findsOneWidget);

    // Générique (30 s avant la fin) : carte épisode suivant.
    engine.emit(engine.snapshot.copyWith(position: const Duration(hours: 1, minutes: 59, seconds: 45)));
    await tester.pump();
    await tester.pump();
    expect(find.text('ÉPISODE SUIVANT'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400)); // fin de l'entrée animée
    await tester.tap(find.bySemanticsLabel('Continuer le générique'));
    await tester.pump();
    expect(find.text('ÉPISODE SUIVANT'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
    container.dispose();
    await tester.pump(const Duration(minutes: 3));
  });
}
