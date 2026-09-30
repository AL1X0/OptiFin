import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../core/logging/app_log.dart';

/// Nouvelle version publiée dans les Releases GitHub.
class AppUpdate {
  const AppUpdate({required this.version, required this.url, required this.size, this.sha256, this.notes});

  final String version;
  final Uri url;
  final int size;

  /// Empreinte de l'installateur annoncée par GitHub (`sha256:…`) : vérifiée avant de l'ouvrir.
  final String? sha256;
  final String? notes;
}

/// Mise à jour automatique de la version Windows.
///
/// Les builds de la branche principale sont publiées par la CI dans les Releases GitHub
/// (`OptiFin <version>`, installateur `OptiFin-windows-setup.exe`). Au lancement, l'appli
/// compare la dernière version à la sienne ; si elle est plus récente, elle la propose,
/// la télécharge, vérifie son empreinte puis lance l'installation silencieuse, qui
/// ferme et relance OptiFin.
class AppUpdater {
  AppUpdater({Dio? dio, this.repository = 'AL1X0/OptiFin'})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'OptiFin'},
            ),
          );

  final Dio _dio;
  final String repository;

  static const assetName = 'OptiFin-windows-setup.exe';

  /// Version plus récente que [current], ou null (à jour, hors ligne, pas d'installateur).
  Future<AppUpdate?> check(String current) async {
    try {
      final response = await _dio.get<Map<String, Object?>>('https://api.github.com/repos/$repository/releases/latest');
      final release = response.data;
      if (release == null) return null;
      final version = _version(release);
      if (version == null || compareVersions(version, current) <= 0) return null;
      final assets = (release['assets'] as List<Object?>? ?? const []).whereType<Map<String, Object?>>();
      final asset = assets.where((a) => a['name'] == assetName).firstOrNull;
      final url = asset?['browser_download_url'];
      if (asset == null || url is! String) return null;
      final digest = asset['digest'];
      AppLog.i('update', 'Nouvelle version disponible : $version (installée : $current)');
      return AppUpdate(
        version: version,
        url: Uri.parse(url),
        size: (asset['size'] as num?)?.toInt() ?? 0,
        sha256: digest is String && digest.startsWith('sha256:') ? digest.substring(7) : null,
        notes: release['body'] as String?,
      );
    } catch (e) {
      AppLog.d('update', 'Vérification des mises à jour impossible : $e');
      return null;
    }
  }

  /// Télécharge l'installateur, vérifie son empreinte et le lance (installation silencieuse,
  /// fermeture puis relance de l'appli). Ne revient pas si tout se passe bien.
  Future<void> install(AppUpdate update, {void Function(double progress)? onProgress}) async {
    final file = File('${Directory.systemTemp.path}\\OptiFin-${update.version}-setup.exe');
    await _dio.downloadUri(
      update.url,
      file.path,
      onReceiveProgress: (received, total) {
        final size = total > 0 ? total : update.size;
        if (size > 0) onProgress?.call(received / size);
      },
    );
    final expected = update.sha256;
    if (expected != null) {
      final actual = sha256.convert(await file.readAsBytes()).toString();
      if (actual != expected.toLowerCase()) {
        await file.delete();
        throw StateError('Installateur corrompu (empreinte inattendue) : téléchargement annulé.');
      }
    }
    AppLog.i('update', 'Installation de la version ${update.version}');
    await Process.start(file.path, const [
      '/VERYSILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
    ], mode: ProcessStartMode.detached);
    exit(0);
  }

  /// « OptiFin 1.0.34 » → « 1.0.34 ».
  static String? _version(Map<String, Object?> release) {
    final name = release['name'];
    final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(name is String ? name : '');
    return match?.group(1);
  }

  /// Comparaison numérique « 1.0.9 » < « 1.0.10 ».
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v.split(RegExp(r'[.+]')).map((p) => int.tryParse(p) ?? 0).toList();
    final pa = parts(a);
    final pb = parts(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}
