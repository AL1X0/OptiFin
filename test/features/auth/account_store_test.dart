import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifin/core/storage/app_database.dart';
import 'package:optifin/core/storage/token_vault.dart';
import 'package:optifin/features/auth/data/account_store.dart';
import 'package:optifin/features/auth/domain/entities.dart';

class MemoryVault implements TokenVault {
  final values = <String, String>{};
  @override
  Future<void> delete(String accountId) async => values.remove(accountId);
  @override
  Future<String?> read(String accountId) async => values[accountId];
  @override
  Future<void> write(String accountId, String token) async => values[accountId] = token;
}

ActiveSession session(String server, String user, {String token = 't'}) => ActiveSession(
      server: JellyfinServer(id: server, name: 'Srv $server', baseUrl: Uri.parse('http://$server'), version: '10.10.0'),
      account: Account(serverId: server, userId: user, userName: 'User $user'),
      token: token,
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late MemoryVault vault;
  late AccountStore store;
  var now = DateTime(2026);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vault = MemoryVault();
    now = DateTime(2026);
    store = AccountStore(db, vault, clock: () => now = now.add(const Duration(minutes: 1)));
  });
  tearDown(() => db.close());

  test('saveSession persiste et active ; token hors DB', () async {
    await store.saveSession(session('a', '1', token: 'secret'));
    final restored = await store.restoreActiveSession();
    expect(restored!.account.id, 'a:1');
    expect(restored.token, 'secret');
    expect(vault.values, {'a:1': 'secret'});

    // Aucune colonne ne contient le token.
    final rows = await db.customSelect('SELECT * FROM accounts').get();
    expect(rows.single.data.values, isNot(contains('secret')));
  });

  test('plusieurs comptes, tri par dernière utilisation, bascule', () async {
    await store.saveSession(session('a', '1'));
    await store.saveSession(session('b', '2'));
    expect((await store.listAccounts()).map((s) => s.account.id), ['b:2', 'a:1']);

    final switched = await store.switchTo('a:1');
    expect(switched!.account.id, 'a:1');
    expect((await store.restoreActiveSession())!.account.id, 'a:1');
    expect((await store.listAccounts()).first.account.id, 'a:1');
  });

  test('bascule impossible si le token a disparu', () async {
    await store.saveSession(session('a', '1'));
    vault.values.clear();
    expect(await store.switchTo('a:1'), isNull);
    expect(await store.restoreActiveSession(), isNull);
  });

  test('suppression : compte, token, actif, et serveur orphelin', () async {
    await store.saveSession(session('a', '1'));
    await store.saveSession(session('a', '2'));
    await store.removeAccount('a:2');
    expect(await store.restoreActiveSession(), isNull);
    expect(vault.values.keys, ['a:1']);
    expect((await db.select(db.servers).get()), hasLength(1));

    await store.removeAccount('a:1');
    expect(await db.select(db.servers).get(), isEmpty);
  });

  test('clearActive garde le compte', () async {
    await store.saveSession(session('a', '1'));
    await store.clearActive();
    expect(await store.restoreActiveSession(), isNull);
    expect(await store.listAccounts(), hasLength(1));
  });

  test('re-login met à jour le compte sans doublon', () async {
    await store.saveSession(session('a', '1', token: 'old'));
    await store.saveSession(session('a', '1', token: 'new'));
    expect(await store.listAccounts(), hasLength(1));
    expect(vault.values['a:1'], 'new');
  });
}
