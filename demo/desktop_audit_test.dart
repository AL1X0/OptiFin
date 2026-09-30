import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_harness.dart';

/// Interface Windows (1440 × 900) pilotée à la souris et au clavier simulés.
///
///   flutter test demo/desktop_audit_test.dart   →  build/demo/shots/desktop_*.png
void main() {
  testWidgets('Ordinateur (Windows)', (tester) async {
    final h = DemoHarness(tester, device: const Size(900, 1440), desktop: true);
    await h.setUp();
    h.goLandscape();
    await h.idle(const Duration(milliseconds: 1500));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    Future<void> hover(Offset at) async {
      await mouse.moveTo(at);
      await h.idle(const Duration(milliseconds: 500));
    }

    await h.screenshot('desktop_home');
    // Survol d'une carte de la rangée « Reprendre » : zoom, bouton lecture, flèches de la rangée.
    final row = find.text('Reprendre');
    await tester.ensureVisible(row);
    await h.idle(const Duration(milliseconds: 600));
    final rowTop = tester.getBottomLeft(row);
    await hover(rowTop + const Offset(160, 120));
    await h.screenshot('desktop_hover');

    // Fiche : clic sur la carte survolée.
    await mouse.down(rowTop + const Offset(160, 120));
    await mouse.up();
    await h.idle(const Duration(milliseconds: 1500));
    await h.screenshot('desktop_details');

    // Lecteur : clic sur « Reprendre » / « Lecture ».
    final play = find.text('Reprendre').evaluate().isNotEmpty ? find.text('Reprendre') : find.text('Lecture');
    await tester.tap(play.first);
    await h.idle(const Duration(milliseconds: 1500));
    await hover(const Offset(720, 450));
    await h.screenshot('desktop_player');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await h.idle(const Duration(milliseconds: 300));
    await h.screenshot('desktop_player_volume');
    // Échap : quitte le lecteur.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await h.idle(const Duration(milliseconds: 1500));

    // Bibliothèques, puis Recherche au clavier (Ctrl+F).
    final libraries = find.text('Bibliothèques');
    if (libraries.evaluate().isNotEmpty) {
      await tester.tap(libraries.first);
      await h.idle(const Duration(milliseconds: 1200));
      await h.screenshot('desktop_libraries');
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await h.idle(const Duration(milliseconds: 1000));
    await h.screenshot('desktop_search');

    // Fenêtre étroite : barre latérale réduite aux icônes.
    tester.view.physicalSize = const Size(1000, 700);
    await h.idle(const Duration(milliseconds: 800));
    await tester.tap(find.byIcon(Icons.home_outlined));
    await h.idle(const Duration(milliseconds: 1200));
    await h.screenshot('desktop_narrow');
    await mouse.removePointer();
    await h.tearDown();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
