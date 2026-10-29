import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/app/router.dart';

import 'demo_harness.dart';
import 'server_snapshot.dart';

/// Captures de l'app réelle sur le serveur Jellyfin de démonstration public (copie locale :
/// demo/server_snapshot.py), dans build/demo/shots/ — reprises par demo/appstore_test.dart.
///
///   python demo/server_snapshot.py && flutter test demo/server_capture_test.dart
/// (à répéter tant que le test signale des éléments manquants).
const dracula = 'c002f0f88ee970cce7f138bbc925de64';
const nightOfTheLivingDead = '5e6e8380563c5211106652362c5c6843';
const jungleBook = 'e16725e2c1c4367ec596cf93c38bbe4f';
const pioneerOne = '9bd5926326d651153928e0d11c6ee7cb';
const pioneerOneE2 = 'b80159226d16576d4c0613750e27c072';

void main() {
  testWidgets('captures sur le serveur de démonstration', (tester) async {
    final server = ServerSnapshot.load();
    // « Reprendre » : le compte public n'a rien en cours.
    server.progress.addAll({dracula: 0.42, pioneerOneE2: 0.31, jungleBook: 0.12});
    final h = DemoHarness(tester, server: server);
    // Passe de collecte (copie incomplète) : un élément absent de l'écran ne bloque pas la suite.
    Future<void> tapIfAny(Finder f) async {
      if (f.hitTestable().evaluate().isNotEmpty) await h.tap(f);
    }

    await h.setUp();
    await h.seedServerDownloads([
      (nightOfTheLivingDead, 'complete', 1.0, 1630),
      (jungleBook, 'running', 0.46, 1210),
      ('f717d85df782816c2ab75423e32f740b', 'complete', 1.0, 540),
      (pioneerOneE2, 'complete', 1.0, 610),
      ('173a94d516c79947da16ba9b1b84a4e0', 'paused', 0.18, 530),
    ]);

    h.begin('home');
    await h.hold(const Duration(milliseconds: 1600));
    await h.screenshot('home');

    h.begin('details');
    unawaited(h.router.push<void>('/home/item/$nightOfTheLivingDead'));
    await h.hold(const Duration(milliseconds: 1700));
    await h.screenshot('details');

    h.begin('series');
    h.router.pop();
    await h.hold(const Duration(milliseconds: 500));
    unawaited(h.router.push<void>('/home/item/$pioneerOne'));
    await h.hold(const Duration(milliseconds: 1300));
    await h.drag(const Offset(200, 720), const Offset(0, -520), const Duration(milliseconds: 1000));
    await h.hold(const Duration(milliseconds: 1300));
    await h.screenshot('series');

    h.begin('downloads');
    await tapIfAny(find.text('Téléchargements'));
    await h.hold(const Duration(milliseconds: 2600));
    await h.screenshot('downloads');

    h.goLandscape();
    unawaited(h.router.push<void>(Routes.play(dracula, start: const Duration(minutes: 31))));
    await h.idle(const Duration(milliseconds: 200));
    h.begin('player');
    await h.hold(const Duration(milliseconds: 1600));
    await h.screenshot('player');
    await tapIfAny(find.bySemanticsLabel('Réglages'));
    await h.hold(const Duration(milliseconds: 1000));
    await tapIfAny(find.bySemanticsLabel(RegExp('^Audio, ')));
    await h.hold(const Duration(milliseconds: 1500));
    await h.screenshot('player_menu');

    await h.tearDown();
    expect(server.complete, isTrue, reason: 'Éléments absents de la copie : python demo/server_snapshot.py, puis relancer.');
  }, timeout: const Timeout(Duration(minutes: 40)));
}
