import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/features/settings/data/app_updater.dart';

/// Réponse fixe de l'API GitHub (aucun accès réseau).
class _FakeGitHub implements HttpClientAdapter {
  _FakeGitHub(this.body, {this.status = 200});

  final Map<String, Object?> body;
  final int status;
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _release(String name, {bool withInstaller = true, String? digest}) => {
  'tag_name': 'build-40',
  'name': name,
  'body': 'Notes',
  'assets': [
    {'name': 'OptiFin.ipa', 'browser_download_url': 'https://example.invalid/OptiFin.ipa', 'size': 1},
    if (withInstaller)
      {
        'name': 'OptiFin-windows-setup.exe',
        'browser_download_url': 'https://github.com/AL1X0/OptiFin/releases/download/build-40/OptiFin-windows-setup.exe',
        'size': 45670472,
        'digest': ?digest,
      },
  ],
};

AppUpdater _updater(_FakeGitHub github) => AppUpdater(dio: Dio()..httpClientAdapter = github);

void main() {
  group('Comparaison des versions', () {
    test('numérique, pas alphabétique', () {
      expect(AppUpdater.compareVersions('1.0.10', '1.0.9'), greaterThan(0));
      expect(AppUpdater.compareVersions('1.0.9', '1.0.10'), lessThan(0));
      expect(AppUpdater.compareVersions('1.1.0', '1.0.99'), greaterThan(0));
      expect(AppUpdater.compareVersions('1.0.33', '1.0.33'), 0);
      expect(AppUpdater.compareVersions('1.0.33+33', '1.0.33'), 0);
    });
  });

  group('Vérification', () {
    test('version plus récente avec installateur Windows : proposée, empreinte lue', () async {
      final github = _FakeGitHub(_release('OptiFin 1.0.40', digest: 'sha256:ABCDEF'));
      final update = await _updater(github).check('1.0.33');
      expect(update, isNotNull);
      expect(update!.version, '1.0.40');
      expect(update.url.path, endsWith('/OptiFin-windows-setup.exe'));
      expect(update.sha256, 'ABCDEF');
      expect(update.size, 45670472);
      expect(github.requests.single.toString(), 'https://api.github.com/repos/AL1X0/OptiFin/releases/latest');
    });

    test('déjà à jour (ou version plus ancienne publiée) : rien', () async {
      expect(await _updater(_FakeGitHub(_release('OptiFin 1.0.33'))).check('1.0.33'), isNull);
      expect(await _updater(_FakeGitHub(_release('OptiFin 1.0.30'))).check('1.0.33'), isNull);
    });

    test('release sans installateur Windows : rien', () async {
      expect(await _updater(_FakeGitHub(_release('OptiFin 1.0.40', withInstaller: false))).check('1.0.33'), isNull);
    });

    test('GitHub injoignable ou en erreur : rien, sans exception', () async {
      expect(await _updater(_FakeGitHub(const {}, status: 503)).check('1.0.33'), isNull);
    });
  });
}
