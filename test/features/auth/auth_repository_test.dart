import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:optifin/core/network/api_failure.dart';
import 'package:optifin/core/network/dio_factory.dart';
import 'package:optifin/core/network/jellyfin_auth.dart';
import 'package:optifin/features/auth/data/auth_repository.dart';
import 'package:optifin/features/auth/domain/entities.dart';

import '../../helpers/fake_http.dart';

const _identity = ClientIdentity(clientName: 'OptiFin', deviceName: 'Test', deviceId: 'd', version: '1');

Map<String, Object?> publicInfo({String version = '10.10.3', String? product = 'Jellyfin Server'}) => {
      'Id': 'srv1',
      'ServerName': 'Maison',
      'Version': version,
      'ProductName': product,
    };

Map<String, Object?> authResult() => {
      'User': {'Id': 'u1', 'Name': 'lea', 'PrimaryImageTag': 'img'},
      'AccessToken': 'secret-token',
      'ServerId': 'srv1',
    };

void main() {
  late FakeHttpAdapter adapter;
  late AuthRepository repo;

  AuthRepository build(Map<String, Object> routes) {
    adapter = FakeHttpAdapter(routes);
    return AuthRepository((Uri baseUrl, {String? token}) {
      final dio = createJellyfinDio(baseUrl: baseUrl, identity: _identity, tokenProvider: () => token);
      dio.httpClientAdapter = adapter;
      return JellyfinClient(dio);
    });
  }

  final server = JellyfinServer(id: 'srv1', name: 'Maison', baseUrl: Uri.parse('http://nas:8096'), version: '10.10.3');

  group('probe', () {
    test('essaie https puis se rabat sur http:8096', () async {
      repo = build({
        'GET https://nas/System/Info/Public': const FakeResponse.error(DioExceptionType.connectionError),
        'GET http://nas/System/Info/Public': const FakeResponse.error(DioExceptionType.connectionError),
        'GET http://nas:8096/System/Info/Public': FakeResponse(200, publicInfo()),
      });
      final s = await repo.probe('nas');
      expect(s.baseUrl, Uri.parse('http://nas:8096'));
      expect(s.id, 'srv1');
      expect(s.name, 'Maison');
      expect(adapter.requests, hasLength(3));
    });

    test('version trop ancienne : échec immédiat', () async {
      repo = build({'GET https://h/System/Info/Public': FakeResponse(200, publicInfo(version: '10.8.13'))});
      await expectLater(repo.probe('https://h'), throwsA(isA<UnsupportedVersionFailure>()));
    });

    test('autre produit → NotJellyfin', () async {
      repo = build({'GET https://h/System/Info/Public': FakeResponse(200, publicInfo(product: 'Emby Server'))});
      await expectLater(repo.probe('https://h'), throwsA(isA<NotJellyfinFailure>()));
    });

    test('page HTML (pas Jellyfin) → NotJellyfin', () async {
      repo = build({'GET https://h/System/Info/Public': const FakeResponse(200, '<html></html>')});
      await expectLater(repo.probe('https://h'), throwsA(isA<NotJellyfinFailure>()));
    });

    test('injoignable', () async {
      repo = build({});
      await expectLater(repo.probe('https://h'), throwsA(isA<UnreachableFailure>()));
    });

    test('saisie vide', () async {
      repo = build({});
      await expectLater(repo.probe(''), throwsA(isA<UnreachableFailure>()));
    });
  });

  group('login', () {
    test('succès → session complète, identifiants envoyés dans le corps', () async {
      repo = build({'POST http://nas:8096/Users/AuthenticateByName': FakeResponse(200, authResult())});
      final session = await repo.login(server, username: 'lea', password: 'pw');
      expect(session.token, 'secret-token');
      expect(session.account.id, 'srv1:u1');
      expect(session.account.avatarTag, 'img');
      expect(adapter.requests.single.data, {'Username': 'lea', 'Pw': 'pw'});
      expect(adapter.requests.single.headers['Authorization'], isNot(contains('Token')));
    });

    test('401 → UnauthorizedFailure', () async {
      repo = build({'POST http://nas:8096/Users/AuthenticateByName': const FakeResponse(401, {})});
      await expectLater(repo.login(server, username: 'x', password: 'y'), throwsA(isA<UnauthorizedFailure>()));
    });

    test('réponse sans token → erreur', () async {
      repo = build({
        'POST http://nas:8096/Users/AuthenticateByName': const FakeResponse(200, {
          'User': {'Id': 'u1'},
        }),
      });
      await expectLater(repo.login(server, username: 'x', password: 'y'), throwsA(isA<UnexpectedFailure>()));
    });
  });

  group('Quick Connect', () {
    test('activé / désactivé / erreur', () async {
      repo = build({'GET http://nas:8096/QuickConnect/Enabled': const FakeResponse(200, true)});
      expect(await repo.isQuickConnectEnabled(server), isTrue);
      repo = build({});
      expect(await repo.isQuickConnectEnabled(server), isFalse);
    });

    test('initiate 401 → QuickConnectDisabled', () async {
      repo = build({'POST http://nas:8096/QuickConnect/Initiate': const FakeResponse(401, {})});
      await expectLater(repo.initiateQuickConnect(server), throwsA(isA<QuickConnectDisabledFailure>()));
    });

    test('sondage jusqu’à autorisation puis échange du secret', () async {
      repo = build({
        'POST http://nas:8096/QuickConnect/Initiate': const FakeResponse(200, {'Code': '123456', 'Secret': 's3', 'Authenticated': false}),
        'GET http://nas:8096/QuickConnect/Connect': [
          const FakeResponse(200, {'Secret': 's3', 'Authenticated': false}),
          const FakeResponse.error(DioExceptionType.connectionTimeout), // transitoire : ignorée
          const FakeResponse(200, {'Secret': 's3', 'Authenticated': true}),
        ],
        'POST http://nas:8096/Users/AuthenticateWithQuickConnect': FakeResponse(200, authResult()),
      });
      final ticket = await repo.initiateQuickConnect(server);
      expect(ticket.code, '123456');
      final session = await repo.awaitQuickConnect(server, ticket, interval: Duration.zero);
      expect(session.token, 'secret-token');
      final polls = adapter.requests.where((r) => r.path == '/QuickConnect/Connect');
      expect(polls, hasLength(3));
      expect(polls.first.queryParameters['secret'], 's3');
    });

    test('ticket expiré (404) → arrêt', () async {
      repo = build({'GET http://nas:8096/QuickConnect/Connect': const FakeResponse(404, {})});
      await expectLater(
        repo.awaitQuickConnect(server, const QuickConnectTicket(code: '1', secret: 's'), interval: Duration.zero),
        throwsA(isA<UnexpectedFailure>()),
      );
    });

    test('timeout', () async {
      repo = build({'GET http://nas:8096/QuickConnect/Connect': const FakeResponse(200, {'Authenticated': false})});
      await expectLater(
        repo.awaitQuickConnect(server, const QuickConnectTicket(code: '1', secret: 's'),
            interval: const Duration(milliseconds: 5), timeout: const Duration(milliseconds: 30)),
        throwsA(isA<StateError>()),
      );
    });
  });

  test('logout envoie le token et ne lève jamais', () async {
    repo = build({'POST http://nas:8096/Sessions/Logout': const FakeResponse(204, '')});
    final session = ActiveSession(
      server: server,
      account: const Account(serverId: 'srv1', userId: 'u1', userName: 'lea'),
      token: 'tok',
    );
    await repo.logout(session);
    expect(adapter.requests.single.headers['Authorization'], contains('Token="tok"'));

    repo = build({});
    await repo.logout(session); // injoignable : silencieux
  });
}
