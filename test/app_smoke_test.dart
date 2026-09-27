import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:optifin/app/app.dart';
import 'package:optifin/core/network/dio_factory.dart';
import 'package:optifin/core/network/jellyfin_auth.dart';
import 'package:optifin/core/providers.dart';
import 'package:optifin/core/storage/app_database.dart';
import 'package:optifin/features/auth/domain/entities.dart';

import 'features/auth/account_store_test.dart' show MemoryVault;
import 'helpers/fake_http.dart';
import 'helpers/fixtures.dart';

/// Parcours de bout en bout sans serveur : accueil → fiche → onglets.
/// Les fixtures n'ont pas d'images (pas d'accès réseau/plugins en test).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const identity = ClientIdentity(clientName: 'OptiFin', deviceName: 'Test', deviceId: 'd', version: '1');
  final session = ActiveSession(
    server: JellyfinServer(id: 's', name: 'Maison', baseUrl: Uri.parse('http://s'), version: '10.10.7'),
    account: const Account(serverId: 's', userId: 'u', userName: 'Léa'),
    token: 't',
  );

  final dune = dtoJson(id: 'm1', name: 'Dune', extra: {
    'ProductionYear': 2021,
    'Overview': 'Sur Arrakis.',
    'UserData': {'Key': 'k', 'PlayedPercentage': 40.0, 'PlaybackPositionTicks': 10, 'IsFavorite': true},
  });
  final moviesLib = dtoJson(id: 'lib', type: 'CollectionFolder', name: 'Films', extra: {'CollectionType': 'movies'});

  Future<void> pumpApp(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dio = createJellyfinDio(baseUrl: Uri.parse('http://s'), identity: identity, tokenProvider: () => 't');
    dio.httpClientAdapter = FakeHttpAdapter({
      'GET http://s/UserViews': FakeResponse(200, queryResult([moviesLib])),
      // /Items sert à la fois l'accueil (favoris, à la une) et la fiche.
      'GET http://s/Items': FakeResponse(200, queryResult([dune])),
      'GET http://s/UserItems/Resume': FakeResponse(200, queryResult([dune])),
      'GET http://s/Shows/NextUp': FakeResponse(200, queryResult(const [])),
      'GET http://s/Items/Latest': FakeResponse(200, [dune]),
      'GET http://s/Items/m1/Similar': FakeResponse(200, queryResult(const [])),
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tokenVaultProvider.overrideWithValue(MemoryVault()),
        clientIdentityProvider.overrideWithValue(identity),
        initialSessionProvider.overrideWithValue(session),
        jellyfinClientProvider.overrideWithValue(JellyfinClient(dio)),
      ],
      child: const OptiFinApp(),
    ));
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
}
