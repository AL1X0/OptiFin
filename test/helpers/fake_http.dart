import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Réponse simulée : statut + corps JSON, ou exception réseau.
class FakeResponse {
  const FakeResponse(this.status, [this.body]) : error = null;
  const FakeResponse.error(DioExceptionType this.error)
      : status = 0,
        body = null;

  final int status;
  final Object? body;
  final DioExceptionType? error;
}

/// Adaptateur HTTP en mémoire : route « METHOD host/path » → réponse(s).
/// Une liste de réponses est consommée dans l'ordre (la dernière est répétée).
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.routes);

  final Map<String, Object> routes;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final key = '${options.method} ${options.uri.scheme}://${options.uri.authority}${options.uri.path}';
    var route = routes[key];
    if (route is List<FakeResponse>) {
      route = route.length > 1 ? route.removeAt(0) : route.first;
    }
    if (route is! FakeResponse) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError, message: 'no route $key');
    }
    if (route.error != null) {
      throw DioException(requestOptions: options, type: route.error!);
    }
    final body = route.body is String ? route.body! as String : jsonEncode(route.body);
    return ResponseBody.fromString(body, route.status, headers: {
      Headers.contentTypeHeader: [route.body is String ? 'text/plain' : Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
