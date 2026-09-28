import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/app/router.dart';

import 'demo_harness.dart';

/// Captures iPad (11 pouces, portrait et paysage) pour vérifier la mise en page tablette.
///
///   flutter test demo/ipad_audit_test.dart   → build/demo/shots/ipad_*.png
void main() {
  for (final landscape in [true, false]) {
    final o = landscape ? 'land' : 'port';
    testWidgets('iPad $o', (tester) async {
      final h = DemoHarness(tester, device: const Size(834, 1194), tablet: true);
      await h.setUp();
      if (landscape) h.goLandscape();
      await h.idle(const Duration(milliseconds: 1500));
      await h.screenshot('ipad_${o}_home');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await h.idle(const Duration(milliseconds: 800));
      await h.screenshot('ipad_${o}_home_rows');

      unawaited(h.router.push<void>('/home/item/horizon'));
      await h.idle(const Duration(milliseconds: 1500));
      await h.screenshot('ipad_${o}_details');

      unawaited(h.router.push<void>('/home/item/veilleurs'));
      await h.idle(const Duration(milliseconds: 1500));
      await h.screenshot('ipad_${o}_series');

      await tester.tap(find.text('Bibliothèques').first);
      await h.idle(const Duration(milliseconds: 800));
      await h.screenshot('ipad_${o}_libraries');
      await tester.tap(find.text('Films').first);
      await h.idle(const Duration(milliseconds: 1500));
      await h.screenshot('ipad_${o}_library');

      await tester.tap(find.text('Recherche').first);
      await h.idle(const Duration(milliseconds: 600));
      await tester.enterText(find.byType(EditableText), 'nébu');
      await h.idle(const Duration(milliseconds: 1500));
      await h.screenshot('ipad_${o}_search');

      if (landscape) {
        unawaited(h.router.push<void>(Routes.play('veilleurs-s2e3', start: const Duration(seconds: 66))));
        await h.idle(const Duration(milliseconds: 1500));
        await h.screenshot('ipad_${o}_player');
        await tester.tap(find.bySemanticsLabel('Réglages'));
        await h.idle(const Duration(milliseconds: 600));
        await h.screenshot('ipad_${o}_player_menu');
        await tester.tap(find.bySemanticsLabel(RegExp('^Sous-titres, ')));
        await h.idle(const Duration(milliseconds: 600));
        await h.screenshot('ipad_${o}_player_subs');
      }
      await h.tearDown();
    }, timeout: const Timeout(Duration(minutes: 20)));
  }

  testWidgets('iPhone lecteur', (tester) async {
    final h = DemoHarness(tester);
    await h.setUp();
    await h.idle(const Duration(milliseconds: 800));
    h.goLandscape();
    unawaited(h.router.push<void>(Routes.play('veilleurs-s2e3', start: const Duration(seconds: 66))));
    await h.idle(const Duration(milliseconds: 1500));
    await h.screenshot('phone_player');
    await tester.tap(find.bySemanticsLabel('Réglages'));
    await h.idle(const Duration(milliseconds: 600));
    await h.screenshot('phone_player_menu');
    await tester.tap(find.bySemanticsLabel(RegExp('^Audio, ')));
    await h.idle(const Duration(milliseconds: 600));
    await h.screenshot('phone_player_audio');
    await h.tearDown();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
