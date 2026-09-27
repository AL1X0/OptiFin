import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/design_system/design_system.dart';
import 'package:optifin/core/media/media_item.dart';
import 'package:optifin/core/network/jellyfin_auth.dart';
import 'package:optifin/core/network/retry_policy.dart';
import 'package:optifin/core/providers.dart';
import 'package:optifin/features/auth/domain/entities.dart';
import 'package:optifin/features/player/data/playback_repository.dart';
import 'package:optifin/features/player/domain/playback_engine.dart';
import 'package:optifin/features/player/domain/playback_plan.dart';
import 'package:optifin/features/player/presentation/player_controller.dart';
import 'package:optifin/features/player/presentation/player_screen.dart';

import 'fakes.dart';

const movie = MediaItem(
  id: 'm',
  name: 'Horizon perdu',
  kind: MediaKind.movie,
  user: UserState(positionTicks: 6000000000), // 10 min
);

void main() {
  late FakeEngine engine;
  late FakePlaybackRepository playback;
  late ProviderContainer container;

  ProviderContainer build({PlayMethod method = PlayMethod.directPlay, int? defaultSubtitle}) {
    engine = FakeEngine();
    playback = FakePlaybackRepository(
      ({int? audioIndex, int? subtitleIndex}) =>
          plan(method: method, audioIndex: audioIndex ?? 1, subtitleIndex: subtitleIndex ?? defaultSubtitle),
    );
    return ProviderContainer(retry: networkRetry, overrides: [
      initialSessionProvider.overrideWithValue(ActiveSession(
        server: JellyfinServer(id: 's', name: 'S', baseUrl: Uri.parse('http://s/jf'), version: '10.10.7'),
        account: const Account(serverId: 's', userId: 'u', userName: 'Léa'),
        token: 'secret',
      )),
      clientIdentityProvider.overrideWithValue(const ClientIdentity(clientName: 'OptiFin', deviceName: 'T', deviceId: 'd', version: '1')),
      playbackRepositoryProvider.overrideWithValue(playback),
      mediaRepositoryProvider.overrideWithValue(FakeMediaRepository(movie)),
      playbackEngineFactoryProvider.overrideWithValue(() async => engine),
    ]);
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
    expect(playback.prepareCalls.last, (2, null));
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

  testWidgets('écran : titre, play/pause pilote le moteur, feuille des pistes', (tester) async {
    container = build();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: OFTheme.dark(), home: const PlayerScreen(args: PlayerArgs('m'))),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const ValueKey('video')), findsOneWidget);
    expect(find.text('Horizon perdu'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump();
    expect(engine.commands, contains('pause'));

    await tester.tap(find.bySemanticsLabel('Audio et sous-titres'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('English 7.1'), findsOneWidget);
    expect(find.text('Externe SRT'), findsOneWidget);

    // Démonte l'écran puis le conteneur : aucune minuterie ne doit survivre (cache 2 min, masquage).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
    container.dispose();
    await tester.pump(const Duration(minutes: 3));
  });
}
