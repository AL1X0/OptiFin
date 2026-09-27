import 'package:flutter/foundation.dart';
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

    testWidgets('Hero seulement avec un tag explicite (unicité par page)', (tester) async {
      await tester.pumpWidget(host(const PosterCard(width: 100, data: MediaCardData(id: 'abc', title: 'X'))));
      expect(find.byType(Hero), findsNothing);
      await tester.pumpWidget(host(const PosterCard(width: 100, heroTag: 'row1:abc', data: MediaCardData(id: 'abc', title: 'X'))));
      expect(tester.widget<Hero>(find.byType(Hero)).tag, 'row1:abc');
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

  group('dominantAccent', () {
    Uint8List image(List<Color> pixels) {
      final data = Uint8List(pixels.length * 4);
      for (final (i, c) in pixels.indexed) {
        data[i * 4] = (c.r * 255).round();
        data[i * 4 + 1] = (c.g * 255).round();
        data[i * 4 + 2] = (c.b * 255).round();
        data[i * 4 + 3] = 255;
      }
      return data;
    }

    test('teinte vive dominante malgré un fond sombre', () {
      final pixels = [
        ...List.filled(300, const Color(0xFF050505)), // noir majoritaire ignoré
        ...List.filled(80, const Color(0xFFE05A10)), // orange vif
        ...List.filled(20, const Color(0xFF2050C0)), // bleu minoritaire
      ];
      final accent = dominantAccent(image(pixels))!;
      final hue = HSLColor.fromColor(accent).hue;
      expect(hue, inInclusiveRange(10, 40), reason: 'orange attendu');
    });

    test('image monochrome → null', () {
      expect(dominantAccent(image(List.filled(400, const Color(0xFF808080)))), isNull);
      expect(dominantAccent(Uint8List(0)), isNull);
    });
  });

  test('normalizeAccent reste lisible sur noir', () {
    for (final c in const [Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFF0A0A40), Color(0xFFFFFF00)]) {
      final l = HSLColor.fromColor(OFColors.normalizeAccent(c)).lightness;
      expect(l, inInclusiveRange(0.54, 0.73)); // tolérance d'arrondi 8 bits
    }
  });
}
