import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage sécurisé des tokens d'accès, par compte.
abstract interface class TokenVault {
  Future<String?> read(String accountId);
  Future<void> write(String accountId, String token);
  Future<void> delete(String accountId);
}

class SecureTokenVault implements TokenVault {
  SecureTokenVault([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
          );

  final FlutterSecureStorage _storage;

  static String _key(String accountId) => 'token.$accountId';

  @override
  Future<String?> read(String accountId) => _storage.read(key: _key(accountId));

  @override
  Future<void> write(String accountId, String token) => _storage.write(key: _key(accountId), value: token);

  @override
  Future<void> delete(String accountId) => _storage.delete(key: _key(accountId));
}
