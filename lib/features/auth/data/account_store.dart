import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/token_vault.dart';
import '../domain/entities.dart';

/// Compte enregistré avec son serveur (pour le sélecteur de comptes).
class StoredAccount {
  const StoredAccount({required this.account, required this.server});

  final Account account;
  final JellyfinServer server;
}

/// Persistance des serveurs, comptes et du compte actif.
class AccountStore {
  AccountStore(this._db, this._vault, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final TokenVault _vault;
  final DateTime Function() _clock;

  static const _activeKey = 'activeAccountId';

  /// Enregistre (ou met à jour) serveur + compte + token, et le rend actif.
  Future<void> saveSession(ActiveSession session) async {
    final now = _clock();
    await _vault.write(session.account.id, session.token);
    await _db.transaction(() async {
      await _db.into(_db.servers).insertOnConflictUpdate(ServersCompanion.insert(
            id: session.server.id,
            name: session.server.name,
            baseUrl: session.server.baseUrl.toString(),
            version: session.server.version,
            lastUsedAt: now,
          ));
      await _db.into(_db.accounts).insertOnConflictUpdate(AccountsCompanion.insert(
            id: session.account.id,
            serverId: session.account.serverId,
            userId: session.account.userId,
            userName: session.account.userName,
            avatarTag: Value(session.account.avatarTag),
            lastUsedAt: now,
          ));
      await _setActive(session.account.id);
    });
  }

  /// Comptes triés du plus récemment utilisé au plus ancien.
  Future<List<StoredAccount>> listAccounts() async {
    final query = _db.select(_db.accounts).join([
      innerJoin(_db.servers, _db.servers.id.equalsExp(_db.accounts.serverId)),
    ])
      ..orderBy([OrderingTerm.desc(_db.accounts.lastUsedAt)]);
    final rows = await query.get();
    return rows.map((r) {
      final a = r.readTable(_db.accounts);
      final s = r.readTable(_db.servers);
      return StoredAccount(account: _toAccount(a), server: _toServer(s));
    }).toList();
  }

  /// Restaure la session active (compte + token). Null si aucune ou token perdu.
  Future<ActiveSession?> restoreActiveSession() async {
    final activeId = await (_db.select(_db.keyValues)..where((t) => t.key.equals(_activeKey))).getSingleOrNull();
    if (activeId == null) return null;
    return sessionFor(activeId.value);
  }

  Future<ActiveSession?> sessionFor(String accountId) async {
    final row = await (_db.select(_db.accounts).join([
      innerJoin(_db.servers, _db.servers.id.equalsExp(_db.accounts.serverId)),
    ])
          ..where(_db.accounts.id.equals(accountId)))
        .getSingleOrNull();
    if (row == null) return null;
    final token = await _vault.read(accountId);
    if (token == null || token.isEmpty) return null;
    return ActiveSession(
      server: _toServer(row.readTable(_db.servers)),
      account: _toAccount(row.readTable(_db.accounts)),
      token: token,
    );
  }

  /// Bascule vers un compte existant. Null si son token n'est plus disponible.
  Future<ActiveSession?> switchTo(String accountId) async {
    final session = await sessionFor(accountId);
    if (session == null) return null;
    await _db.transaction(() async {
      await (_db.update(_db.accounts)..where((t) => t.id.equals(accountId)))
          .write(AccountsCompanion(lastUsedAt: Value(_clock())));
      await _setActive(accountId);
    });
    return session;
  }

  /// Supprime le compte et son token ; supprime le serveur s'il n'a plus de compte.
  Future<void> removeAccount(String accountId) async {
    await _vault.delete(accountId);
    await _db.transaction(() async {
      final account = await (_db.select(_db.accounts)..where((t) => t.id.equals(accountId))).getSingleOrNull();
      await (_db.delete(_db.accounts)..where((t) => t.id.equals(accountId))).go();
      await (_db.delete(_db.keyValues)..where((t) => t.key.equals(_activeKey) & t.value.equals(accountId))).go();
      if (account != null) {
        final remaining = await (_db.select(_db.accounts)..where((t) => t.serverId.equals(account.serverId))).get();
        if (remaining.isEmpty) {
          await (_db.delete(_db.servers)..where((t) => t.id.equals(account.serverId))).go();
        }
      }
    });
  }

  /// Oublie le compte actif sans supprimer le compte (retour à l'écran de choix).
  Future<void> clearActive() => (_db.delete(_db.keyValues)..where((t) => t.key.equals(_activeKey))).go();

  Future<void> _setActive(String accountId) =>
      _db.into(_db.keyValues).insertOnConflictUpdate(KeyValuesCompanion.insert(key: _activeKey, value: accountId));

  static Account _toAccount(AccountRow a) =>
      Account(serverId: a.serverId, userId: a.userId, userName: a.userName, avatarTag: a.avatarTag);

  static JellyfinServer _toServer(ServerRow s) =>
      JellyfinServer(id: s.id, name: s.name, baseUrl: Uri.parse(s.baseUrl), version: s.version);
}
