import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/design_system/design_system.dart';

Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
      theme: OFTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('OFMotion', () {
    testWidgets('durées nulles quand « Réduire les animations » est actif', (tester) async {
      late OFMotion motion;
      await tester.pumpWidget(host(Builder(builder: (c) {
        motion = OFMotion.of(c);
        return const SizedBox();
      }), disableAnimations: true));
      expect(motion.enabled, isFalse);
      expect(motion.standard, Duration.zero);
      expect(motion.emphasized, Duration.zero);
    });

    testWidgets('durées ≤ 300 ms sinon', (tester) async {
      late OFMotion motion;
      await tester.pumpWidget(host(Builder(builder: (c) {
        motion = OFMotion.of(c);
        return const SizedBox();
      })));
      expect(motion.emphasized.inMilliseconds, lessThanOrEqualTo(300));
      expect(motion.fast, greaterThan(Duration.zero));
    });
  });

  group('OFButton', () {
    testWidgets('tap déclenche onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(OFButton(label: 'Lecture', onPressed: () => taps++)));
      await tester.tap(find.text('Lecture'));
      expect(taps, 1);
    });

    testWidgets('loading : pas de tap, spinner visible', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(OFButton(label: 'Go', loading: true, onPressed: () => taps++)));
      await tester.tap(find.text('Go'));
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('sémantique bouton', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(OFButton(label: 'Continuer', onPressed: () {})));
      expect(
        tester.getSemantics(find.byType(OFButton)),
        matchesSemantics(label: 'Continuer', isButton: true, hasEnabledState: true, isEnabled: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });

  group('PosterCard', () {
    testWidgets('sans image : titre en repli, barre de progression, label accessible', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(PosterCard(
        width: 120,
        data: const MediaCardData(id: '1', title: 'Dune', subtitle: '2021', progress: 0.42),
        onTap: () {},
      )));
      expect(find.text('Dune'), findsWidgets); // repli + titre sous la carte
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Dune, 2021, 42 % regardé'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('vu : pastille, pas de barre ; ratio 2:3', (tester) async {
      await tester.pumpWidget(host(const PosterCard(
        width: 120,
        showTitle: false,
        data: MediaCardData(id: '1', title: 'X', played: true, progress: 1),
      )));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.getSize(find.byType(AspectRatio)), const Size(120, 180));
    });

    testWidgets('Hero tag stable pour la transition vers la fiche', (tester) async {
      await tester.pumpWidget(host(const PosterCard(width: 100, data: MediaCardData(id: 'abc', title: 'X'))));
      expect(tester.widget<Hero>(find.byType(Hero)).tag, 'poster-abc');
    });
  });

  group('AvatarChip', () {
    testWidgets('initiales', (tester) async {
      await tester.pumpWidget(host(const Column(children: [
        AvatarChip(name: 'léa martin'),
        AvatarChip(name: 'bob'),
        AvatarChip(name: '  '),
      ])));
      expect(find.text('LM'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('MediaRow', () {
    testWidgets('virtualisée : ne construit que les éléments visibles', (tester) async {
      var built = 0;
      await tester.pumpWidget(host(MediaRow(
        title: 'Reprendre',
        itemCount: 500,
        itemExtent: 130,
        height: 200,
        itemBuilder: (_, i) {
          built++;
          return SizedBox(width: 120, child: Text('item $i'));
        },
      )));
      expect(find.text('Reprendre'), findsOneWidget);
      expect(built, lessThan(30));
    });
  });

  test('normalizeAccent reste lisible sur noir', () {
    for (final c in const [Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFF0A0A40), Color(0xFFFFFF00)]) {
      final l = HSLColor.fromColor(OFColors.normalizeAccent(c)).lightness;
      expect(l, inInclusiveRange(0.54, 0.73)); // tolérance d'arrondi 8 bits
    }
  });
}
