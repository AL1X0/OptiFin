import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/media/media_item.dart';
import 'package:optifin/core/network/api_failure.dart';
import 'package:optifin/core/network/dio_factory.dart';
import 'package:optifin/core/network/image_url.dart';
import 'package:optifin/core/network/jellyfin_auth.dart';

import '../../helpers/fake_http.dart';

const identity = ClientIdentity(clientName: 'OptiFin', deviceName: 'iPhone de "Léa", 15', deviceId: 'dev-1', version: '1.0.0');

void main() {
  group('buildAuthorizationHeader', () {
    test('sans token', () {
      expect(
        buildAuthorizationHeader(identity),
        'MediaBrowser Client="OptiFin", Device="iPhone%20de%20%22L%C3%A9a%22%2C%2015", DeviceId="dev-1", Version="1.0.0"',
      );
    });

    test('avec token', () {
      expect(buildAuthorizationHeader(identity, token: 'tok'), endsWith(', Token="tok"'));
    });

    test('token vide ignoré', () {
      expect(buildAuthorizationHeader(identity, token: ''), isNot(contains('Token')));
    });
  });

  group('JellyfinAuthInterceptor', () {
    test('ajoute l’en-tête et lit le token à chaque requête', () async {
      String? token;
      final dio = createJellyfinDio(baseUrl: Uri.parse('http://s'), identity: identity, tokenProvider: () => token);
      final adapter = FakeHttpAdapter({'GET http://s/ping': const FakeResponse(200, {})});
      dio.httpClientAdapter = adapter;

      await dio.get<Object>('/ping');
      token = 'abc';
      await dio.get<Object>('/ping');

      expect(adapter.requests[0].headers['Authorization'], isNot(contains('Token')));
      expect(adapter.requests[1].headers['Authorization'], contains('Token="abc"'));
    });

    test('401 avec token → onUnauthorized ; sans token → rien', () async {
      var calls = 0;
      String? token = 't';
      final dio = createJellyfinDio(
        baseUrl: Uri.parse('http://s'),
        identity: identity,
        tokenProvider: () => token,
        onUnauthorized: () => calls++,
      );
      dio.httpClientAdapter = FakeHttpAdapter({'GET http://s/x': const FakeResponse(401, {})});

      await expectLater(dio.get<Object>('/x'), throwsA(isA<DioException>()));
      token = null;
      await expectLater(dio.get<Object>('/x'), throwsA(isA<DioException>()));
      expect(calls, 1);
    });
  });

  group('ApiFailure.from', () {
    DioException http(int status) => DioException(
          requestOptions: RequestOptions(),
          response: Response<Object>(requestOptions: RequestOptions(), statusCode: status),
          type: DioExceptionType.badResponse,
        );
    DioException net(DioExceptionType t) => DioException(requestOptions: RequestOptions(), type: t);

    test('statuts HTTP', () {
      expect(ApiFailure.from(http(401)), isA<UnauthorizedFailure>());
      expect(ApiFailure.from(http(403)), isA<ForbiddenFailure>());
      expect(ApiFailure.from(http(503)), isA<ServerFailure>());
      expect(ApiFailure.from(http(404)), isA<UnexpectedFailure>());
    });

    test('erreurs réseau', () {
      expect(ApiFailure.from(net(DioExceptionType.connectionTimeout)), isA<TimeoutFailure>());
      expect(ApiFailure.from(net(DioExceptionType.receiveTimeout)), isA<TimeoutFailure>());
      expect(ApiFailure.from(net(DioExceptionType.connectionError)), isA<UnreachableFailure>());
      expect(ApiFailure.from(net(DioExceptionType.badCertificate)), isA<CertificateFailure>());
    });

    test('messages utilisateur non vides et sans détail technique', () {
      const failures = <ApiFailure>[
        UnreachableFailure(),
        TimeoutFailure(),
        UnauthorizedFailure(),
        ServerFailure(500),
        UnsupportedVersionFailure('10.8.0'),
        UnexpectedFailure('stack trace secrète'),
      ];
      for (final f in failures) {
        expect(f.userMessage, isNotEmpty);
        expect(f.userMessage, isNot(contains('secrète')));
      }
    });
  });

  group('JellyfinImageUrlBuilder', () {
    final builder = JellyfinImageUrlBuilder(Uri(scheme: 'https', host: 'h', path: '/jf'));

    test('palier de largeur supérieur à la taille physique', () {
      expect(JellyfinImageUrlBuilder.bucketFor(112, 3), 480); // 336 px → 480
      expect(JellyfinImageUrlBuilder.bucketFor(100, 1), 120);
      expect(JellyfinImageUrlBuilder.bucketFor(2000, 3), 3840);
    });

    test('poster : maxWidth, qualité, WebP, tag, sous-chemin conservé', () {
      final uri = builder.image(
        const ImageRef(itemId: 'i1', type: ImageKind.primary, tag: 't'),
        logicalWidth: 112,
        devicePixelRatio: 3,
      );
      expect(uri.path, '/jf/Items/i1/Images/Primary');
      expect(uri.queryParameters, {'maxWidth': '480', 'quality': '90', 'format': 'Webp', 'tag': 't'});
    });

    test('backdrop indexé', () {
      final uri = builder.image(
        const ImageRef(itemId: 'i', type: ImageKind.backdrop, tag: 'b', index: 2),
        logicalWidth: 400,
        devicePixelRatio: 2,
      );
      expect(uri.path, '/jf/Items/i/Images/Backdrop/2');
    });

    test('maybe : null sans image', () {
      expect(builder.maybe(null, logicalWidth: 100, devicePixelRatio: 2), isNull);
    });

    test('avatar utilisateur', () {
      final uri = builder.userAvatar(userId: 'u', logicalWidth: 40, devicePixelRatio: 2);
      expect(uri.path, '/jf/Users/u/Images/Primary');
      expect(uri.queryParameters['maxWidth'], '120');
    });
  });
}
