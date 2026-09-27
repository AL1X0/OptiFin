import 'package:dio/dio.dart';

/// Identité du client envoyée au serveur dans l'en-tête `Authorization`.
class ClientIdentity {
  const ClientIdentity({
    required this.clientName,
    required this.deviceName,
    required this.deviceId,
    required this.version,
  });

  final String clientName;
  final String deviceName;
  final String deviceId;
  final String version;
}

/// Construit l'en-tête `Authorization: MediaBrowser …` attendu par Jellyfin 10.9+.
///
/// Les valeurs sont encodées (le serveur les URL-décode) pour supporter les noms
/// d'appareil contenant guillemets, virgules ou caractères non ASCII.
String buildAuthorizationHeader(ClientIdentity identity, {String? token}) {
  String q(String v) => '"${Uri.encodeComponent(v)}"';
  final parts = [
    'Client=${q(identity.clientName)}',
    'Device=${q(identity.deviceName)}',
    'DeviceId=${q(identity.deviceId)}',
    'Version=${q(identity.version)}',
    if (token != null && token.isNotEmpty) 'Token=${q(token)}',
  ];
  return 'MediaBrowser ${parts.join(', ')}';
}

/// Ajoute l'en-tête d'auth à chaque requête. Le token est lu à la volée pour
/// qu'une bascule de compte ne nécessite pas de recréer Dio.
class JellyfinAuthInterceptor extends Interceptor {
  JellyfinAuthInterceptor({required this.identity, required this.tokenProvider, this.onUnauthorized});

  final ClientIdentity identity;
  final String? Function() tokenProvider;

  /// Appelé sur un 401 quand un token était présent (token révoqué côté serveur).
  final void Function()? onUnauthorized;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = buildAuthorizationHeader(identity, token: tokenProvider());
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final hadToken = tokenProvider()?.isNotEmpty ?? false;
    if (err.response?.statusCode == 401 && hadToken) onUnauthorized?.call();
    handler.next(err);
  }
}
