import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:optifin/app/app_shell.dart';
import 'package:optifin/app/route_titles.dart';
import 'package:optifin/app/router.dart';
import 'package:optifin/core/design_system/design_system.dart';

/// Navigation façon iOS : retour par glissé depuis le bord, bouton retour titré,
/// remontée en haut (barre d'état, onglet actif).
void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  /// Coquille à 4 onglets comme l'app ; l'accueil défile, la fiche est [details].
  Future<GoRouter> pumpShell(WidgetTester tester, Widget details) async {
    StatefulShellBranch branch(String path, Widget root) => StatefulShellBranch(
      routes: [
        appRoute(path, (_) => root, routes: [appRoute('item', (_) => details)]),
      ],
    );
    final router = GoRouter(
      initialLocation: '/home',
      observers: [OFNavObserver()],
      routes: [
        StatefulShellRoute(
          builder: (_, _, shell) => AppShell(shell: shell),
          navigatorContainerBuilder: (_, shell, children) =>
              FadingBranches(index: shell.currentIndex, children: children),
          branches: [
            branch(
              '/home',
              OFRouteTitle(
                title: 'Accueil',
                child: ScrollToTopListener(
                  child: Scaffold(
                    body: ListView.builder(
                      itemCount: 100,
                      itemBuilder: (_, i) => SizedBox(height: 80, child: Text('ligne $i')),
                    ),
                  ),
                ),
              ),
            ),
            for (final path in ['/libraries', '/search', '/downloads']) branch(path, const SizedBox()),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(theme: OFTheme.dark(), routerConfig: router));
    return router;
  }

  Future<void> openDetails(WidgetTester tester, GoRouter router) async {
    unawaited(router.push('/home/item'));
    await tester.pumpAndSettle();
    expect(find.text('fiche'), findsOneWidget);
  }

  Future<void> swipeFromEdge(WidgetTester tester, double y) async {
    final gesture = await tester.startGesture(Offset(4, y));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  ScrollPosition homePosition(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  testWidgets('glissé depuis le bord : la fiche se ferme', (tester) async {
    final router = await pumpShell(tester, const Scaffold(body: Center(child: Text('fiche'))));
    await openDetails(tester, router);
    await swipeFromEdge(tester, 300);
    expect(find.text('fiche'), findsNothing);
    expect(find.text('ligne 0'), findsOneWidget);
  }, variant: ios);

  testWidgets('glissé depuis le bord sur une rangée horizontale', (tester) async {
    final router = await pumpShell(
      tester,
      Scaffold(
        body: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 100, child: Text('fiche'))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 30,
                  itemBuilder: (_, i) => SizedBox(width: 120, child: Text('carte $i')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await openDetails(tester, router);
    await swipeFromEdge(tester, 200); // en plein sur la rangée
    expect(find.text('fiche'), findsNothing);
  }, variant: ios);

  testWidgets('la fiche connaît le titre de l\'écran précédent', (tester) async {
    final router = await pumpShell(
      tester,
      Scaffold(
        body: Builder(builder: (context) => Center(child: Text('fiche ${OFRouteTitles.previousOf(context)}'))),
      ),
    );
    unawaited(router.push('/home/item'));
    await tester.pumpAndSettle();
    expect(find.text('fiche Accueil'), findsOneWidget);
  }, variant: ios);

  testWidgets('toucher la barre d\'état remonte en haut', (tester) async {
    await pumpShell(tester, const SizedBox());
    homePosition(tester).jumpTo(2000);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.statusBar.name,
      SystemChannels.statusBar.codec.encodeMethodCall(const MethodCall('handleScrollToTop')),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(homePosition(tester).pixels, 0);
  }, variant: ios);

  testWidgets('onglet actif : retour à la racine, puis remontée en haut', (tester) async {
    final router = await pumpShell(tester, const Scaffold(body: Center(child: Text('fiche'))));
    homePosition(tester).jumpTo(2000);
    await openDetails(tester, router);

    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(find.text('fiche'), findsNothing);
    expect(homePosition(tester).pixels, 2000); // la racine garde sa position

    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(homePosition(tester).pixels, 0);
  }, variant: ios);
}
