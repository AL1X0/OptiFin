import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:optifin/core/media/media_item.dart';
import 'package:optifin/core/media/media_repository.dart';
import 'package:optifin/core/network/api_failure.dart';
import 'package:optifin/core/network/dio_factory.dart';
import 'package:optifin/core/network/jellyfin_auth.dart';
import 'package:optifin/features/library/domain/library_query.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/fixtures.dart';

const _identity = ClientIdentity(clientName: 'OptiFin', deviceName: 'T', deviceId: 'd', version: '1');

void main() {
  late FakeHttpAdapter adapter;

  MediaRepository repo(Map<String, Object> routes) {
    adapter = FakeHttpAdapter(routes);
    final dio = createJellyfinDio(baseUrl: Uri.parse('http://s'), identity: _identity, tokenProvider: () => 't');
    dio.httpClientAdapter = adapter;
    return MediaRepository(JellyfinClient(dio), 'user1');
  }

  group('page', () {
    test('traduit la requête en paramètres Jellyfin', () async {
      final r = repo({'GET http://s/Items': FakeResponse(200, queryResult([dtoJson(id: 'a')], total: 1234))});
      final page = await r.page(
        const LibraryQuery(
          parentId: 'lib',
          kinds: [MediaKind.movie],
          sort: LibrarySort.dateAdded,
          descending: true,
          played: false,
          genreIds: ['g1', 'g2'],
          resolution: ResolutionFilter.uhd,
        ),
        200,
        100,
      );
      expect(page.total, 1234);
      expect(page.items.single.id, 'a');

      final uri = adapter.requests.single.uri;
      final q = uri.queryParametersAll;
      expect(q['userId'], ['user1']);
      expect(q['parentId'], ['lib']);
      expect(q['includeItemTypes'], ['Movie']);
      expect(q['sortBy'], ['DateCreated', 'SortName']);
      expect(q['sortOrder'], ['Descending']);
      expect(q['isPlayed'], ['false']);
      expect(q['genreIds'], ['g1', 'g2']);
      expect(q['is4K'], ['true']);
      expect(q['startIndex'], ['200']);
      expect(q['limit'], ['100']);
      // Les enums sont sérialisés avec leur nom serveur (et non « ItemFields.xxx »).
      expect(q['fields'], ['PrimaryImageAspectRatio', 'ChildCount']);
      expect(q.containsKey('isFavorite'), isFalse);
    });

    test('erreur réseau → ApiFailure', () async {
      final r = repo({'GET http://s/Items': const FakeResponse(503, {})});
      await expectLater(r.page(const LibraryQuery(), 0, 10), throwsA(isA<ServerFailure>()));
    });
  });

  test('indexOfLetter : comptage via nameLessThan sans charger d’éléments', () async {
    final r = repo({'GET http://s/Items': FakeResponse(200, queryResult(const [], total: 412))});
    final index = await r.indexOfLetter(const LibraryQuery(parentId: 'lib', kinds: [MediaKind.series]), 'M');
    expect(index, 412);
    final q = adapter.requests.single.uri.queryParameters;
    expect(q['nameLessThan'], 'M');
    expect(q['limit'], '0');
    expect(q['enableImages'], 'false');
    expect(await r.indexOfLetter(const LibraryQuery(), '#'), 0);
    expect(adapter.requests, hasLength(1), reason: '# ne requête pas le serveur');
  });

  test('item : /Items?ids= avec les champs de fiche', () async {
    final r = repo({'GET http://s/Items': FakeResponse(200, queryResult([dtoJson(id: 'x', name: 'Dune')]))});
    final item = await r.item('x');
    expect(item.name, 'Dune');
    final q = adapter.requests.single.uri.queryParametersAll;
    expect(q['ids'], ['x']);
    expect(q['fields'], containsAll(['Overview', 'People', 'MediaSources']));
  });

  test('item introuvable → erreur', () async {
    final r = repo({'GET http://s/Items': FakeResponse(200, queryResult(const []))});
    await expectLater(r.item('x'), throwsA(isA<UnexpectedFailure>()));
  });

  test('favori / vu : bons verbes et bonnes routes', () async {
    final r = repo({
      'POST http://s/UserFavoriteItems/x': const FakeResponse(200, {'Key': 'k', 'IsFavorite': true}),
      'DELETE http://s/UserFavoriteItems/x': const FakeResponse(200, {'Key': 'k', 'IsFavorite': false}),
      'POST http://s/UserPlayedItems/x': const FakeResponse(200, {'Key': 'k', 'Played': true}),
    });
    expect((await r.setFavorite('x', true)).favorite, isTrue);
    expect((await r.setFavorite('x', false)).favorite, isFalse);
    expect((await r.setPlayed('x', true)).played, isTrue);
    expect(adapter.requests.map((r) => r.method), ['POST', 'DELETE', 'POST']);
  });

  test('recherche : requêtes parallèles groupées par type', () async {
    final r = repo({
      'GET http://s/Items': FakeResponse(200, queryResult([dtoJson(id: 'm1')])),
      'GET http://s/Persons': FakeResponse(200, queryResult([dtoJson(id: 'p1', type: 'Person')])),
    });
    final results = await r.search('dune');
    expect(results.movies.single.id, 'm1');
    expect(results.people.single.kind, MediaKind.person);
    expect(adapter.requests.where((q) => q.path == '/Items'), hasLength(7));
    expect(adapter.requests.first.uri.queryParameters['searchTerm'], 'dune');
    expect(results.isEmpty, isFalse);
  });

  test('filtres : genres (ids) + années triées', () async {
    final r = repo({
      'GET http://s/Items/Filters2': const FakeResponse(200, {
        'Genres': [
          {'Name': 'Drame', 'Id': 'g2'},
          {'Name': 'action', 'Id': 'g1'},
        ],
      }),
      'GET http://s/Items/Filters': const FakeResponse(200, {
        'Years': [1999, 2021, 2010],
      }),
    });
    final options = await r.filterOptions(const LibraryQuery(parentId: 'lib'));
    expect(options.genres.map((g) => g.name), ['action', 'Drame']);
    expect(options.years, [2021, 2010, 1999]);
  });
}
