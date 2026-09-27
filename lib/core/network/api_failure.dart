import 'dart:io';

import 'package:dio/dio.dart';

/// Erreurs réseau/API traduites en cas métier, avec message utilisateur clair.
abstract class ApiFailure implements Exception {
  const ApiFailure();

  String get userMessage;

  static ApiFailure from(Object error) {
    if (error is ApiFailure) return error;
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) return const UnauthorizedFailure();
      if (status == 403) return const ForbiddenFailure();
      if (status != null && status >= 500) return ServerFailure(status);
      if (status != null) {
        final data = error.response?.data;
        final text = data == null ? '' : ': ${data is String ? data : data.toString()}';
        return UnexpectedFailure('HTTP $status${text.length > 300 ? text.substring(0, 300) : text}');
      }
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          const TimeoutFailure(),
        DioExceptionType.badCertificate => const CertificateFailure(),
        DioExceptionType.connectionError => const UnreachableFailure(),
        _ when error.error is SocketException => const UnreachableFailure(),
        _ => UnexpectedFailure(error.message ?? error.type.name),
      };
    }
    if (error is SocketException) return const UnreachableFailure();
    return UnexpectedFailure(error.toString());
  }
}

class UnreachableFailure extends ApiFailure {
  const UnreachableFailure();
  @override
  String get userMessage => 'Serveur injoignable. Vérifiez l’adresse et votre connexion.';
}

class TimeoutFailure extends ApiFailure {
  const TimeoutFailure();
  @override
  String get userMessage => 'Le serveur met trop de temps à répondre.';
}

class CertificateFailure extends ApiFailure {
  const CertificateFailure();
  @override
  String get userMessage => 'Certificat HTTPS invalide pour ce serveur.';
}

class UnauthorizedFailure extends ApiFailure {
  const UnauthorizedFailure();
  @override
  String get userMessage => 'Identifiant ou mot de passe incorrect.';
}

class ForbiddenFailure extends ApiFailure {
  const ForbiddenFailure();
  @override
  String get userMessage => 'Accès refusé par le serveur.';
}

class ServerFailure extends ApiFailure {
  const ServerFailure(this.statusCode);
  final int statusCode;
  @override
  String get userMessage => 'Erreur du serveur ($statusCode). Réessayez plus tard.';
}

class NotJellyfinFailure extends ApiFailure {
  const NotJellyfinFailure();
  @override
  String get userMessage => 'Cette adresse ne correspond pas à un serveur Jellyfin.';
}

class UnsupportedVersionFailure extends ApiFailure {
  const UnsupportedVersionFailure(this.version);
  final String version;
  @override
  String get userMessage => 'Jellyfin $version n’est pas pris en charge (10.9 minimum).';
}

class QuickConnectDisabledFailure extends ApiFailure {
  const QuickConnectDisabledFailure();
  @override
  String get userMessage => 'Quick Connect est désactivé sur ce serveur.';
}

class UnexpectedFailure extends ApiFailure {
  const UnexpectedFailure(this.detail);
  final String detail;
  @override
  String get userMessage => 'Une erreur inattendue est survenue.';

  /// Détail technique (statut HTTP, début de réponse) : affiché en mode debug.
  String get technicalDetail => detail;
  @override
  String toString() => 'UnexpectedFailure($detail)';
}
