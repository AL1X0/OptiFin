import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/design_system/design_system.dart';

double opacityOf(WidgetTester tester, Finder f) {
  final opacity = find.ancestor(of: f, matching: find.byType(Opacity));
  return opacity.evaluate().isEmpty ? 1 : tester.widget<Opacity>(opacity.first).opacity;
}

void main() {
  Widget app(Widget child, {bool reduceMotion = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );

  testWidgets('FadeSlideIn : part invisible, arrive après son délai', (tester) async {
    await tester.pumpWidget(app(const FadeSlideIn(delay: Duration(milliseconds: 100), child: Text('A'))));
    expect(opacityOf(tester, find.text('A')), 0);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 150));
    expect(opacityOf(tester, find.text('A')), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacityOf(tester, find.text('A')), 1, reason: 'animation terminée : plus d’Opacity');
  });

  testWidgets('« Réduire les animations » : affichage immédiat', (tester) async {
    await tester.pumpWidget(app(const FadeSlideIn(child: Text('A')), reduceMotion: true));
    expect(opacityOf(tester, find.text('A')), 1);
  });

  testWidgets('EntranceScope : pas d’animation pour ce qui arrive après la fenêtre d’entrée', (tester) async {
    final show = ValueNotifier(false);
    await tester.pumpWidget(
      app(
        EntranceScope(
          window: const Duration(milliseconds: 200),
          child: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, v, _) => Column(
              children: [
                const FadeSlideIn(child: Text('tôt')),
                if (v) const FadeSlideIn(child: Text('tard')),
              ],
            ),
          ),
        ),
      ),
    );
    expect(opacityOf(tester, find.text('tôt')), 0, reason: 'dans la fenêtre : animé');
    await tester.pump(const Duration(milliseconds: 400));
    show.value = true;
    await tester.pump();
    expect(opacityOf(tester, find.text('tard')), 1, reason: 'élément recyclé au défilement : affiché directement');
  });

  testWidgets('FadeThroughSwitcher : l’ancien contenu s’efface pendant que le nouveau arrive', (tester) async {
    Widget build(String t) => app(FadeThroughSwitcher(child: Text(t, key: ValueKey(t))));
    await tester.pumpWidget(build('squelette'));
    await tester.pumpWidget(build('contenu'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('squelette'), findsOneWidget);
    expect(find.text('contenu'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('squelette'), findsNothing);
  });
}
