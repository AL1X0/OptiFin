import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/app/router.dart';

import 'demo_harness.dart';

/// Tournage de la démo : scènes image par image dans `build/demo/frames/<scène>/`,
/// captures du README dans `build/demo/shots/`.
///
///   flutter test demo/capture_test.dart
void main() {
  testWidgets('tournage de la démo OptiFin', (tester) async {
    final h = DemoHarness(tester);
    await h.setUp();

    Finder visibleText(List<String> candidates) {
      for (final c in candidates) {
        for (final f in [find.text(c), find.bySemanticsLabel(RegExp('^${RegExp.escape(c)}'))]) {
          final hit = f.hitTestable();
          if (hit.evaluate().isNotEmpty) return hit;
        }
      }
      throw StateError('Aucun de ces textes n’est visible : $candidates');
    }

    // ---------------------------------------------------------------- Accueil
    h.begin('home');
    await h.hold(const Duration(milliseconds: 1500));
    await h.screenshot('home');
    await h.drag(const Offset(330, 330), const Offset(-300, 0), const Duration(milliseconds: 300), fling: true);
    await h.hold(const Duration(milliseconds: 1300));
    await h.drag(const Offset(200, 700), const Offset(0, -520), const Duration(milliseconds: 900));
    await h.hold(const Duration(milliseconds: 900));
    await h.screenshot('home_rows');

    // ---------------------------------------------------------------- Fiche film
    h.begin('details');
    await h.tap(visibleText(['Horizon perdu', 'Ville néon', 'Nébuleuse']));
    await h.hold(const Duration(milliseconds: 1600));
    await h.screenshot('details');
    await h.drag(const Offset(200, 650), const Offset(0, -430), const Duration(milliseconds: 900));
    await h.hold(const Duration(milliseconds: 1100));
    await h.screenshot('details_cast');

    // ---------------------------------------------------------------- Fiche série
    h.begin('series');
    await h.drag(const Offset(3, 420), const Offset(330, 0), const Duration(milliseconds: 420), fling: true);
    await h.hold(const Duration(milliseconds: 400));
    unawaited(h.router.push<void>('/home/item/veilleurs'));
    await h.hold(const Duration(milliseconds: 1400));
    await h.screenshot('series');
    await h.drag(const Offset(200, 720), const Offset(0, -560), const Duration(milliseconds: 1000));
    await h.hold(const Duration(milliseconds: 1200));
    await h.screenshot('series_episodes');

    // ---------------------------------------------------------------- Bibliothèques
    h.begin('library');
    await h.tap(find.text('Bibliothèques'));
    await h.hold(const Duration(milliseconds: 700));
    await h.tap(find.text('Films'));
    await h.hold(const Duration(milliseconds: 1700));
    await h.screenshot('library');

    // ---------------------------------------------------------------- Recherche
    h.begin('search');
    await h.tap(find.text('Recherche'));
    await h.hold(const Duration(milliseconds: 400));
    await h.tap(find.byType(EditableText));
    await h.type(find.byType(EditableText), 'nébu');
    await h.hold(const Duration(milliseconds: 1500));
    await h.screenshot('search');

    // ---------------------------------------------------------------- Lecteur (paysage)
    h.goLandscape();
    unawaited(h.router.push<void>(Routes.play('veilleurs-s2e3', start: const Duration(seconds: 66))));
    await h.idle(const Duration(milliseconds: 200));
    h.begin('player');
    await h.hold(const Duration(milliseconds: 1500));
    await h.screenshot('player');
    await h.tap(find.text('Passer l’intro'));
    await h.hold(const Duration(milliseconds: 900));
    await h.tap(find.bySemanticsLabel('Audio et sous-titres'));
    await h.hold(const Duration(milliseconds: 1800));
    await h.screenshot('player_tracks');
    await h.tapAt(const Offset(80, 40));
    await h.hold(const Duration(milliseconds: 500));
    final engine = h.engine!;
    engine.jumpTo(engine.snapshot.duration - const Duration(seconds: 88));
    await h.hold(const Duration(milliseconds: 2600));
    await h.screenshot('player_upnext');

    await h.tearDown();
  }, timeout: const Timeout(Duration(minutes: 40)));
}
