import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:optifin/core/media/media_repository.dart';
import 'package:optifin/core/network/api_failure.dart';
import 'package:optifin/core/network/dio_factory.dart';
import 'package:optifin/core/network/jellyfin_auth.dart';
import 'package:optifin/core/storage/app_database.dart';
import 'package:optifin/features/home/data/home_repository.dart';
import 'package:optifin/features/home/domain/home_data.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/fixtures.dart';

BaseItemDto dto(String id, {String type = 'Movie', Map<String, Object?> extra = const {}}) =>
    BaseItemDto.fromJson(dtoJson(id: id, type: type, extra: extra));

HomeSnapshot snapshot({
  List<BaseItemDto> views = const [],
  List<BaseItemDto> featured = const [],
  List<BaseItemDto> resume = const [],
  List<BaseItemDto> nextUp = const [],
  Map<String, List<BaseItemDto>> latest = const {},
  List<BaseItemDto> favorites = const [],
}) =>
    HomeSnapshot(views: views, featured: featured, resume: resume, nextUp: nextUp, latest: latest, favorites: favorites);

void main() {
  group('buildHome', () {
    final movies = dto('lib-m', type: 'CollectionFolder', extra: {'Name': 'Films', 'CollectionType': 'movies'});
    final music = dto('lib-a', type: 'CollectionFolder', extra: {'Name': 'Musique', 'CollectionType': 'music'});

    test('ordre des rangées et rangées vides omises', () {
      final home = buildHome(
        snapshot(
          views: [movies, music],
          resume: [dto('r1')],
          nextUp: [dto('n1', type: 'Episode')],
          latest: {
            'lib-m': [dto('m1')],
            'lib-a': [dto('al1', type: 'MusicAlbum')],
          },
          favorites: const [],
        ),
        fromCache: false,
      );
      expect(home.sections.map((s) => s.id), ['resume', 'nextUp', 'latest-lib-m', 'latest-lib-a']);
      expect(home.sections[2].title, 'Ajouts récents · Films');
      expect(home.sections[2].style, CardStyle.poster);
      expect(home.sections[3].style, CardStyle.square);
      expect(home.sections[2].library!.id, 'lib-m');
    });

    test('À suivre exclut ce qui est déjà dans Reprendre', () {
      final home = buildHome(
        snapshot(resume: [dto('e1', type: 'Episode')], nextUp: [dto('e1', type: 'Episode'), dto('e2', type: 'Episode')]),
        fromCache: false,
      );
      expect(home.sections.firstWhere((s) => s.id == 'nextUp').items.map((i) => i.id), ['e2']);
    });

    test('à la une : uniquement les éléments avec backdrop', () {
      final home = buildHome(
        snapshot(featured: [
          dto('a', extra: {'BackdropImageTags': ['b']}),
          dto('b'),
        ]),
        fromCache: true,
      );
      expect(home.featured.map((i) => i.id), ['a']);
      expect(home.fromCache, isTrue);
    });

    test('accueil vide', () => expect(buildHome(snapshot(), fromCache: false).isEmpty, isTrue));
  });

  test('HomeSnapshot : aller-retour JSON sans perte (cache)', () {
    final original = snapshot(
      views: [dto('v', type: 'CollectionFolder', extra: {'CollectionType': 'tvshows'})],
      resume: [
        dto('r', type: 'Episode', extra: {
          'UserData': {'Key': 'k', 'PlaybackPositionTicks': 42, 'PlayedPercentage': 12.5},
          'ImageTags': {'Primary': 'p'},
        }),
      ],
      latest: {
        'v': [dto('x', type: 'Series')],
      },
    );
    final restored = HomeSnapshot.tryParse(jsonEncode(original.toJson()))!;
    expect(restored.resume.single.userData!.playbackPositionTicks, 42);
    expect(restored.resume.single.imageTags, {'Primary': 'p'});
    expect(restored.views.single.collectionType, BaseItemDtoCollectionType.tvshows);
    expect(restored.latest['v']!.single.type, BaseItemDtoType.series);
  });

  test('HomeSnapshot : cache corrompu ou obsolète ignoré', () {
    expect(HomeSnapshot.tryParse('pas du json'), isNull);
    expect(HomeSnapshot.tryParse('{"v": 0}'), isNull);
  });

  group('HomeRepository.watch', () {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    late AppDatabase db;
    late ResponseCache cache;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      cache = ResponseCache(db);
    });
    tearDown(() => db.close());

    HomeRepository build(Map<String, Object> routes) {
      final dio = createJellyfinDio(
        baseUrl: Uri.parse('http://s'),
        identity: const ClientIdentity(clientName: 'c', deviceName: 'd', deviceId: 'i', version: '1'),
        tokenProvider: () => 't',
      );
      dio.httpClientAdapter = FakeHttpAdapter(routes);
      return HomeRepository(MediaRepository(JellyfinClient(dio), 'u'), cache, 'acc');
    }

    final okRoutes = <String, Object>{
      'GET http://s/UserViews': FakeResponse(200, queryResult([dtoJson(id: 'lib', type: 'CollectionFolder', extra: {'CollectionType': 'movies'})])),
      'GET http://s/Items': FakeResponse(200, queryResult([dtoJson(id: 'f1')])),
      'GET http://s/UserItems/Resume': FakeResponse(200, queryResult([dtoJson(id: 'r1')])),
      'GET http://s/Shows/NextUp': FakeResponse(200, queryResult(const [])),
      'GET http://s/Items/Latest': FakeResponse(200, [dtoJson(id: 'l1')]),
    };

    test('sans cache : réseau seul, puis mis en cache', () async {
      final emitted = await build(okRoutes).watch().toList();
      expect(emitted, hasLength(1));
      expect(emitted.single.fromCache, isFalse);
      expect(emitted.single.sections.map((s) => s.id), ['resume', 'latest-lib', 'favorites']);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await cache.read('acc/home'), isNotNull);
    });

    test('avec cache : cache immédiat puis réseau', () async {
      await build(okRoutes).watch().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final emitted = await build(okRoutes).watch().toList();
      expect(emitted.map((e) => e.fromCache), [true, false]);
    });

    test('réseau en échec avec cache : pas d’erreur (hors ligne)', () async {
      await build(okRoutes).watch().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final emitted = await build({}).watch().toList();
      expect(emitted.single.fromCache, isTrue);
    });

    test('réseau en échec sans cache : erreur', () async {
      await expectLater(build({}).watch().toList(), throwsA(isA<ApiFailure>()));
    });

    Map<String, Object?> withBackdrop(String id) => dtoJson(id: id, extra: {'BackdropImageTags': ['t']});

    test('carrousel : tirage au sort parmi les non vus de toutes les bibliothèques', () async {
      final dio = createJellyfinDio(
        baseUrl: Uri.parse('http://s'),
        identity: const ClientIdentity(clientName: 'c', deviceName: 'd', deviceId: 'i', version: '1'),
        tokenProvider: () => 't',
      );
      final adapter = FakeHttpAdapter(okRoutes);
      dio.httpClientAdapter = adapter;
      await HomeRepository(MediaRepository(JellyfinClient(dio), 'u'), cache, 'acc').fetch();
      final featured = adapter.requests.firstWhere(
        (r) => r.path == '/Items' && (r.queryParameters['imageTypes']?.toString().contains('Backdrop') ?? false),
      );
      expect(featured.queryParameters['sortBy'].toString(), contains('Random'));
      expect(featured.queryParameters['filters'].toString(), contains('IsUnplayed'));
      expect(featured.queryParameters['recursive'], true);
      expect(featured.queryParameters.containsKey('parentId'), isFalse, reason: 'toutes les bibliothèques');
    });

    test('carrousel : les titres déjà commencés (Reprendre) sont exclus', () async {
      final routes = Map<String, Object>.of(okRoutes)
        ..['GET http://s/Items'] = FakeResponse(200, queryResult([withBackdrop('r1'), withBackdrop('a')]));
      final home = await build(routes).fetch();
      expect(home.featured.map((i) => i.id), ['a']);
    });

    test('carrousel : sélection stable pendant l’ouverture, nouvelle sélection à la suivante', () async {
      Map<String, Object> draw(List<String> ids) => Map<String, Object>.of(okRoutes)
        ..['GET http://s/Items'] = FakeResponse(200, queryResult([for (final id in ids) withBackdrop(id)]));
      await build(draw(['a', 'b'])).watch().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 2e ouverture : le serveur tire c, d mais l'écran garde a, b (pas de changement sous les yeux).
      final second = await build(draw(['c', 'd'])).watch().toList();
      expect(second.last.featured.map((i) => i.id), ['a', 'b']);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 3e ouverture : la sélection tirée précédemment (c, d) est affichée d'emblée.
      final third = await build(draw(['e'])).watch().toList();
      expect(third.first.featured.map((i) => i.id), ['c', 'd']);
    });

    test('une bibliothèque en échec n’empêche pas l’accueil', () async {
      final routes = Map<String, Object>.of(okRoutes)..['GET http://s/Items/Latest'] = const FakeResponse(500, {});
      final emitted = await build(routes).watch().toList();
      expect(emitted.single.sections.map((s) => s.id), isNot(contains('latest-lib')));
    });
  });
}
