import 'dart:convert';

import 'package:dio/dio.dart';

import '../logging/app_log.dart';

/// Journalise les échanges réseau : méthode, chemin, statut, durée ; en cas
/// d'erreur, le début de la réponse du serveur (précieux pour un 400/500).
/// Jamais d'en-têtes (ils contiennent le token) ; le reste passe par [AppLog.redact].
class LoggingInterceptor extends Interceptor {
  static const _startKey = 'optifin.start';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    AppLog.d('http', '${response.requestOptions.method} ${_path(response.requestOptions)} → ${response.statusCode} (${_ms(response.requestOptions)} ms)');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    final status = err.response?.statusCode;
    final body = _snippet(err.response?.data);
    AppLog.w(
      'http',
      '${o.method} ${_path(o)} → ${status ?? err.type.name} (${_ms(o)} ms)'
      '${err.message != null && status == null ? ' ${err.message}' : ''}'
      '${body.isEmpty ? '' : '\n  réponse : $body'}',
    );
    handler.next(err);
  }

  static String _path(RequestOptions o) => o.uri.replace(host: '').toString().replaceFirst(RegExp(r'^[a-z]+://(:\d+)?'), '');

  static int _ms(RequestOptions o) {
    final start = o.extra[_startKey];
    return start is DateTime ? DateTime.now().difference(start).inMilliseconds : -1;
  }

  static String _snippet(Object? data) {
    if (data == null) return '';
    final text = data is String ? data : jsonEncode(data);
    return text.length > 600 ? '${text.substring(0, 600)}…' : text;
  }
}
