import 'package:dio/dio.dart';

import 'jellyfin_auth.dart';

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
  // Pas de LogInterceptor en release : les en-têtes contiennent le token.
  return dio;
}
