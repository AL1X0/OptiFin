import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_harness.dart';

/// Interface Android TV (1080p = 960 × 540 logiques) pilotée à la télécommande simulée.
///
///   flutter test demo/tv_audit_test.dart   →  build/demo/shots/tv_*.png
void main() {
  testWidgets('Android TV', (tester) async {
    final h = DemoHarness(tester, device: const Size(540, 960), tv: true);
    await h.setUp();
    h.goLandscape();
    await h.idle(const Duration(milliseconds: 1500));

    Future<void> press(LogicalKeyboardKey key, {int times = 1}) async {
      for (var i = 0; i < times; i++) {
        await tester.sendKeyEvent(key);
        await h.idle(const Duration(milliseconds: 350));
      }
    }

    // Accueil : focus sur « Lecture » du carrousel (la première touche active la surbrillance).
    await press(LogicalKeyboardKey.arrowRight);
    await press(LogicalKeyboardKey.arrowLeft);
    await h.screenshot('tv_home');
    // Titre suivant (▶ sur « Infos »), puis descente dans les rangées.
    await press(LogicalKeyboardKey.arrowRight);
    await press(LogicalKeyboardKey.arrowRight);
    await h.idle(const Duration(milliseconds: 600));
    await h.screenshot('tv_home_next');
    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.arrowRight);
    await h.screenshot('tv_home_rows');
    // Menu du haut.
    await press(LogicalKeyboardKey.arrowUp, times: 3);
    await h.screenshot('tv_menu');
    // Fiche : OK sur une carte.
    await press(LogicalKeyboardKey.arrowDown, times: 2);
    await press(LogicalKeyboardKey.select);
    await h.idle(const Duration(milliseconds: 1500));
    await h.screenshot('tv_details');
    // Lecteur : OK sur Lecture.
    await press(LogicalKeyboardKey.select);
    await h.idle(const Duration(milliseconds: 1500));
    await h.screenshot('tv_player');
    await press(LogicalKeyboardKey.arrowUp);
    await press(LogicalKeyboardKey.arrowRight, times: 3);
    await h.screenshot('tv_player_focus');
    await h.tearDown();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
