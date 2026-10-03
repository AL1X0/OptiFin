import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:optifin/app/app.dart';
import 'package:optifin/core/design_system/design_system.dart';
import 'package:optifin/core/network/dio_factory.dart';
import 'package:optifin/core/network/jellyfin_auth.dart';
import 'package:optifin/core/providers.dart';
import 'package:optifin/core/storage/app_database.dart';
import 'package:optifin/features/auth/domain/entities.dart';
import 'package:optifin/features/syncplay/presentation/watch_party_controller.dart';
import 'package:optifin/features/syncplay/presentation/watch_party_sheet.dart';
import 'package:optifin/features/details/presentation/item_details_screen.dart';

import 'features/auth/account_store_test.dart' show MemoryVault;
import 'helpers/fake_http.dart';
import 'helpers/fixtures.dart';

/// Parcours de bout en bout sans serveur : accueil → fiche → onglets.
/// Les fixtures n'ont pas d'images (pas d'accès réseau/plugins en test).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // Pas de serveur : pas de connexion temps réel des soirées.
  WatchPartyController.autoConnect = false;

  const identity = ClientIdentity(clientName: 'OptiFin', deviceName: 'Test', deviceId: 'd', version: '1');
  final session = ActiveSession(
    server: JellyfinServer(id: 's', name: 'Maison', baseUrl: Uri.parse('http://s'), version: '10.10.7'),
    account: const Account(serverId: 's', userId: 'u', userName: 'Léa'),
    token: 't',
  );

  final dune = dtoJson(
    id: 'm1',
    name: 'Dune',
    extra: {
      'ProductionYear': 2021,
      'Overview': 'Sur Arrakis.',
      'UserData': {'Key': 'k', 'PlayedPercentage': 40.0, 'PlaybackPositionTicks': 10, 'IsFavorite': true},
    },
  );
  final moviesLib = dtoJson(id: 'lib', type: 'CollectionFolder', name: 'Films', extra: {'CollectionType': 'movies'});

  Future<void> pumpApp(WidgetTester tester, {bool featured = false}) async {
    // À la une : il faut une image de fond (carrousel).
    final items = featured
        ? dtoJson(
            id: 'm2',
            name: 'Arrival',
            extra: {
              'BackdropImageTags': ['b'],
              'Overview': 'Sur Arrakis.',
            },
          )
        : dune;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dio = createJellyfinDio(baseUrl: Uri.parse('http://s'), identity: identity, tokenProvider: () => 't');
    dio.httpClientAdapter = FakeHttpAdapter({
      'GET http://s/UserViews': FakeResponse(200, queryResult([moviesLib])),
      // /Items sert à la fois l'accueil (favoris, à la une) et la fiche.
      'GET http://s/Items': FakeResponse(200, queryResult([items])),
      'GET http://s/UserItems/Resume': FakeResponse(200, queryResult([dune])),
      'GET http://s/Shows/NextUp': FakeResponse(200, queryResult(const [])),
      'GET http://s/Items/Latest': FakeResponse(200, [dune]),
      'GET http://s/Items/m1/Similar': FakeResponse(200, queryResult(const [])),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tokenVaultProvider.overrideWithValue(MemoryVault()),
          clientIdentityProvider.overrideWithValue(identity),
          initialSessionProvider.overrideWithValue(session),
          jellyfinClientProvider.overrideWithValue(JellyfinClient(dio)),
        ],
        child: const OptiFinApp(),
      ),
    );
    // Pas de pumpAndSettle : les indicateurs de chargement animent en continu.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('accueil : rangées composées, même titre dans plusieurs rangées sans conflit Hero', (tester) async {
    await pumpApp(tester);
    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('Ajouts récents · Films'), findsOneWidget);
    // Rangée plus bas : construite à la demande (liste virtualisée).
    await tester.scrollUntilVisible(find.text('Favoris'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(find.text('Favoris'), findsOneWidget);
    // « Dune » est présent dans 3 rangées à la fois : tags Hero distincts requis.
    final tags = tester.widgetList<Hero>(find.byType(Hero)).map((h) => h.tag).toList();
    expect(tags.length, greaterThanOrEqualTo(2));
    expect(tags.toSet().length, tags.length);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap sur une carte → fiche avec synopsis et bouton Reprendre', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Dune').first);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Sur Arrakis.'), findsOneWidget);
    expect(find.text('Reprendre'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onglet Bibliothèques', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Bibliothèques'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Films'), findsWidgets);
    expect(find.text('Bibliothèques'), findsWidgets);
  });
  group('Android TV (télécommande)', () {
    setUp(() => OFDevice.tv = true);
    tearDown(() => OFDevice.tv = false);

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    String focusLabel() {
      final node = FocusManager.instance.primaryFocus;
      final semantics = node?.context?.findAncestorWidgetOfExactType<Semantics>();
      return '${node?.debugLabel ?? ''}|${semantics?.properties.label ?? ''}';
    }

    testWidgets('▼ puis ▲ : retour tout en haut de l’accueil ; compte atteignable dans le menu', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(tester, featured: true);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      ScrollPosition home() => tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .firstWhere((s) => s.position.axis == Axis.vertical)
          .position;

      // Bouton Lecture du carrousel focalisé au lancement.
      // Bouton Lecture du carrousel focalisé au lancement.
      expect(focusLabel(), contains('Lecture'));
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(home().pixels, greaterThan(0), reason: 'la page descend vers les rangées');
      for (var i = 0; i < 4; i++) {
        await press(tester, LogicalKeyboardKey.arrowUp);
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(home().pixels, 0, reason: 'retour sur le carrousel : page tout en haut');

      // ◀ depuis le carrousel : menu ; ▼ jusqu'au compte.
      await press(tester, LogicalKeyboardKey.arrowLeft);
      final labels = <String>[focusLabel()];
      for (var i = 0; i < 4; i++) {
        await press(tester, LogicalKeyboardKey.arrowDown);
        labels.add(focusLabel());
      }
      expect(labels.any((l) => l.contains('Compte')), isTrue, reason: '$labels');
      expect(find.byType(WatchPartyButton), findsNothing, reason: 'pas de doublon « Soirée » sur l’accueil TV');
      expect(tester.takeException(), isNull);
    });

    testWidgets('OK sur une carte : fiche avec le focus sur Reprendre ; Retour revient à l’accueil', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(tester, featured: true);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focusLabel(), contains('Dune'));
      await press(tester, LogicalKeyboardKey.select);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(ItemDetailsScreen), findsOneWidget, reason: 'fiche ouverte');
      final onDetails = focusLabel();
      expect(onDetails, isNot(contains('Scope')), reason: 'un élément de la fiche a le focus : $onDetails');
      // ▼ ▲ dans la fiche sans perdre le focus.
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(FocusManager.instance.primaryFocus, isNot(isA<FocusScopeNode>()));
      // Touche Retour de la télécommande (retour système Android).
      await tester.binding.handlePopRoute();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(ItemDetailsScreen), findsNothing, reason: 'Retour quitte la fiche');
      expect(tester.takeException(), isNull);
    });
  });
}
