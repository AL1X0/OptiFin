import 'package:dio/dio.dart';

import 'jellyfin_auth.dart';
import 'logging_interceptor.dart';

/// Crée une instance Dio configurée pour un serveur Jellyfin.
///
/// Les timeouts sont courts à la connexion (serveur lent ≠ app figée) mais
/// tolérants en réception (grosses listes de bibliothèque).
Dio createJellyfinDio({
  required Uri baseUrl,
  required ClientIdentity identity,
  required String? Function() tokenProvider,
  void Function()? onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl.toString(),
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    JellyfinAuthInterceptor(identity: identity, tokenProvider: tokenProvider, onUnauthorized: onUnauthorized),
  );
  // Journal maison : jamais d'en-têtes (token), secrets masqués.
  dio.interceptors.add(LoggingInterceptor());
  return dio;
}
