import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/features/auth/domain/server_address.dart';

void main() {
  group('ServerAddress.candidates', () {
    test('URL complète utilisée telle quelle, normalisée', () {
      expect(ServerAddress.candidates('HTTPS://Media.Example.com:8920/'), [Uri.parse('https://media.example.com:8920')]);
    });

    test('hôte seul : https, http puis http:8096', () {
      expect(ServerAddress.candidates('192.168.1.10'), [
        Uri.parse('https://192.168.1.10'),
        Uri.parse('http://192.168.1.10'),
        Uri.parse('http://192.168.1.10:8096'),
      ]);
    });

    test('hôte avec port : pas de variante 8096', () {
      expect(ServerAddress.candidates('nas.local:8096'), [
        Uri.parse('https://nas.local:8096'),
        Uri.parse('http://nas.local:8096'),
      ]);
    });

    test('sous-chemin conservé, slash final retiré', () {
      expect(ServerAddress.candidates('https://exemple.fr/jellyfin/'), [Uri.parse('https://exemple.fr/jellyfin')]);
    });

    test('query et fragment supprimés', () {
      expect(ServerAddress.candidates('http://h:1/a?x=1#y'), [Uri.parse('http://h:1/a')]);
    });

    test('espaces ignorés', () {
      expect(ServerAddress.candidates('  https://h  '), [Uri.parse('https://h')]);
    });

    test('saisies invalides', () {
      expect(ServerAddress.candidates(''), isEmpty);
      expect(ServerAddress.candidates('   '), isEmpty);
      expect(ServerAddress.candidates('ftp://h'), isEmpty);
      expect(ServerAddress.candidates('https://'), isEmpty);
    });

    test('IPv6', () {
      expect(ServerAddress.candidates('http://[::1]:8096'), [Uri.parse('http://[::1]:8096')]);
    });
  });

  group('versions', () {
    test('parse', () {
      expect(ServerAddress.parseVersion('10.10.3'), (10, 10, 3));
      expect(ServerAddress.parseVersion('10.11.0-rc1'), (10, 11, 0));
      expect(ServerAddress.parseVersion('10.9'), (10, 9, 0));
      expect(ServerAddress.parseVersion('abc'), isNull);
      expect(ServerAddress.parseVersion(null), isNull);
    });

    test('support minimum 10.9', () {
      expect(ServerAddress.isSupportedVersion('10.8.13'), isFalse);
      expect(ServerAddress.isSupportedVersion('10.9.0'), isTrue);
      expect(ServerAddress.isSupportedVersion('10.10.7'), isTrue);
      expect(ServerAddress.isSupportedVersion('12.1.0'), isTrue);
      expect(ServerAddress.isSupportedVersion(null), isFalse);
    });
  });
}
