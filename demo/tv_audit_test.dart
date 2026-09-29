import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:optifin/app/app.dart';
import 'package:optifin/app/router.dart';
import 'package:optifin/features/auth/domain/entities.dart';
import 'package:optifin/features/auth/presentation/auth_providers.dart';
import 'package:optifin/features/auth/presentation/connect_screen.dart';

import 'demo_harness.dart';

/// Interface Android TV (1080p = 960 × 540 logiques) pilotée à la télécommande simulée.
///
///   flutter test demo/tv_audit_test.dart   →  build/demo/shots/tv_*.png
void main() {
  String focused() => FocusManager.instance.primaryFocus?.toString() ?? 'aucun';

  testWidgets('Android TV : connexion', (tester) async {
    final h = DemoHarness(tester, device: const Size(540, 960), tv: true, signedIn: false);
    await h.setUp();
    h.goLandscape();
    await h.idle(const Duration(milliseconds: 1500));

    Future<void> press(LogicalKeyboardKey key, {int times = 1}) async {
      for (var i = 0; i < times; i++) {
        await tester.sendKeyEvent(key);
        await h.idle(const Duration(milliseconds: 350));
      }
    }

    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.arrowUp);
    await h.screenshot('tv_connect');
    await press(LogicalKeyboardKey.arrowDown, times: 2);
    debugPrint('connexion ▼▼ : ${focused()}');
    await h.screenshot('tv_connect_nav');

    // Écran de profil : serveur validé comme après « Continuer ».
    final context = tester.element(find.byType(ConnectScreen));
    ProviderScope.containerOf(tester.element(find.byType(OptiFinApp)))
        .read(pendingServerProvider.notifier)
        .set(
          JellyfinServer(id: 'srv', name: 'Maison', baseUrl: Uri.parse('http://192.168.1.20:8096'), version: '10.10.7'),
        );
    unawaited(GoRouter.of(context).push(Routes.login));
    await h.idle(const Duration(milliseconds: 1500));
    await h.screenshot('tv_login');
    for (var i = 0; i < 5; i++) {
      await press(LogicalKeyboardKey.arrowDown);
      debugPrint('profil ▼ ×${i + 1} : ${focused()}');
    }
    await h.screenshot('tv_login_bottom');
    await press(LogicalKeyboardKey.arrowUp, times: 5);
    debugPrint('profil ▲ ×5 : ${focused()}');
    await h.tearDown();
  }, timeout: const Timeout(Duration(minutes: 20)));

  testWidgets('Android TV : navigation et lecteur', (tester) async {
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
    debugPrint('accueil : ${focused()}');
    await h.screenshot('tv_home');
    // Retour : menu latéral ; ▼ parcourt les rubriques sans les ouvrir.
    await press(LogicalKeyboardKey.escape);
    debugPrint('menu : ${focused()}');
    await h.screenshot('tv_menu');
    await press(LogicalKeyboardKey.arrowUp);
    debugPrint('menu ▲ : ${focused()}');
    await press(LogicalKeyboardKey.arrowDown, times: 2);
    await press(LogicalKeyboardKey.arrowRight);
    debugPrint('retour page : ${focused()}');
    // Rangées puis fiche.
    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.arrowRight);
    await h.screenshot('tv_home_rows');
    await press(LogicalKeyboardKey.select);
    await h.idle(const Duration(milliseconds: 1500));
    await h.screenshot('tv_details');
    // Lecteur : OK sur Lecture.
    await press(LogicalKeyboardKey.select);
    await h.idle(const Duration(milliseconds: 1500));
    debugPrint('lecteur : ${focused()}');
    await h.screenshot('tv_player');
    await press(LogicalKeyboardKey.arrowRight, times: 2);
    debugPrint('lecteur ▶▶ : ${focused()}');
    await h.screenshot('tv_player_focus');
    for (var i = 0; i < 4; i++) {
      await press(LogicalKeyboardKey.arrowRight);
      debugPrint('lecteur ▶ ${i + 3} : ${focused()} ${FocusManager.instance.primaryFocus?.rect}');
    }
    await press(LogicalKeyboardKey.select);
    await h.idle(const Duration(milliseconds: 600));
    debugPrint('menu lecteur : ${focused()}');
    await h.screenshot('tv_player_menu');
    await press(LogicalKeyboardKey.escape);
    await press(LogicalKeyboardKey.arrowUp);
    await press(LogicalKeyboardKey.arrowRight, times: 3);
    await h.screenshot('tv_player_scrub');
    await h.tearDown();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
